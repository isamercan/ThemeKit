//
//  CardStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `Card`. Appearance (surface fill,
//  border, shadow, radius) lives in a `CardStyle` you set with `.cardStyle(_:)`,
//  so the card's container can be reskinned — outlined, gradient, glass — without
//  editing `Card`. `Card`'s content/header/loading API is unchanged; the default
//  style reproduces the original look, so this is additive and non-breaking.
//
//      Card(title: "…") { body }
//          .cardStyle(.outlined)        // or a custom CardStyle
//

import SwiftUI

/// The inputs a `CardStyle` renders: the card's already-composed content (header +
/// body, padded) and its elevation, so a style can vary chrome by elevation.
public struct CardStyleConfiguration {
    /// The card's content, type-erased (mirrors `ButtonStyleConfiguration.label`).
    public let content: AnyView
    /// The requested elevation, for styles that key shadow/border off it.
    public let elevation: CardElevation
}

/// Defines a card's container appearance. Implement `makeBody` to wrap the
/// configuration's content with a surface (background, border, shadow). Set one
/// with `.cardStyle(_:)`; the default is ``DefaultCardStyle``.
public protocol CardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CardStyleConfiguration) -> Body
}

/// The stock card surface: white fill, a hairline border only at `.none`
/// elevation, and a token shadow for `.soft` / `.elevated`. Reads the active
/// `\.theme`, so an injected theme re-skins it too.
public struct DefaultCardStyle: CardStyle {
    public init() {}
    public func makeBody(configuration: CardStyleConfiguration) -> some View {
        DefaultCardSurface(configuration: configuration)
    }
}

private struct DefaultCardSurface: View {
    let configuration: CardStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .background(theme.background(.bgWhite),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .strokeBorder(theme.border(.borderPrimary), lineWidth: configuration.elevation == .none ? 1 : 0)
            )
            .modifier(CardShadow(elevation: configuration.elevation))
    }
}

/// A flat, always-outlined card: transparent surface, full border, no shadow.
/// An example custom `CardStyle` consumers can use directly or model their own on.
public struct OutlinedCardStyle: CardStyle {
    public init() {}
    public func makeBody(configuration: CardStyleConfiguration) -> some View {
        OutlinedCardSurface(configuration: configuration)
    }
}

private struct OutlinedCardSurface: View {
    let configuration: CardStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .strokeBorder(theme.border(.borderPrimary), lineWidth: 1.5)
            )
    }
}

public extension CardStyle where Self == DefaultCardStyle {
    /// The stock card surface (white fill + elevation shadow).
    static var `default`: DefaultCardStyle { DefaultCardStyle() }
}

public extension CardStyle where Self == OutlinedCardStyle {
    /// A flat, outlined card (transparent fill, full border, no shadow).
    static var outlined: OutlinedCardStyle { OutlinedCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCardStyle: CardStyle {
    private let _makeBody: @MainActor (CardStyleConfiguration) -> AnyView
    init<S: CardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CardStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CardStyleKey: EnvironmentKey {
    static let defaultValue = AnyCardStyle(DefaultCardStyle())
}

extension EnvironmentValues {
    var cardStyle: AnyCardStyle {
        get { self[CardStyleKey.self] }
        set { self[CardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CardStyle`` for `Card`s in this view and its descendants.
    func cardStyle<S: CardStyle>(_ style: sending S) -> some View {
        environment(\.cardStyle, AnyCardStyle(style))
    }
}
