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
//      Card("…") { body }
//          .cardStyle(.outlined)        // or a custom CardStyle
//

import SwiftUI

/// The inputs a `CardStyle` renders: the card's already-composed content (header +
/// body, padded) plus the chrome knobs — elevation, selection/press state, surface
/// fill token and radius role — so a style can draw the whole shell from tokens.
public struct CardStyleConfiguration {
    /// The card's content, type-erased (mirrors `ButtonStyleConfiguration.label`).
    public let content: AnyView
    /// The requested elevation, for styles that key shadow/border off it.
    public let elevation: CardElevation
    /// Whether the card is selected. The default style marks this with a hero border.
    public let isSelected: Bool
    /// Whether the card is being pressed, for styles that add press feedback.
    public let isPressed: Bool
    /// Token key for the surface fill. Defaults to the classic white card surface.
    public let surfaceKey: Theme.BackgroundColorKey
    /// Radius role for the container corner. Defaults to the large box corner.
    public let radius: Theme.RadiusRole

    /// The new parameters default to the pre-existing chrome (`.bgWhite` / `.box`,
    /// unselected, unpressed), so `CardStyleConfiguration(content:elevation:)`
    /// call sites keep compiling and rendering identically.
    public init(content: AnyView,
                elevation: CardElevation,
                isSelected: Bool = false,
                isPressed: Bool = false,
                surfaceKey: Theme.BackgroundColorKey = .bgWhite,
                radius: Theme.RadiusRole = .box) {
        self.content = content
        self.elevation = elevation
        self.isSelected = isSelected
        self.isPressed = isPressed
        self.surfaceKey = surfaceKey
        self.radius = radius
    }
}

/// Defines a card's container appearance. Implement `makeBody` to wrap the
/// configuration's content with a surface (background, border, shadow). Set one
/// with `.cardStyle(_:)`; the default is ``DefaultCardStyle``.
public protocol CardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CardStyleConfiguration) -> Body
}

/// The stock card surface: the configuration's surface fill (white by default),
/// corner clipping from its radius role, a hairline border only at `.none`
/// elevation, a token shadow for `.soft` / `.elevated`, and a 1.5pt hero border
/// when selected. Reads the active `\.theme`, so an injected theme re-skins it too.
public struct DefaultCardStyle: CardStyle {
    public init() {}
    public func makeBody(configuration: CardStyleConfiguration) -> some View {
        DefaultCardSurface(configuration: configuration)
    }
}

private struct DefaultCardSurface: View {
    let configuration: CardStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radius.value, style: .continuous)
    }

    /// Selection promotes the border to the hero token; otherwise the original
    /// hairline appears only at `.none` elevation (shadow carries the other levels).
    private var borderColor: Color {
        theme.border(configuration.isSelected ? .borderHero : .borderPrimary)
    }
    private var borderWidth: CGFloat {
        if configuration.isSelected { return 1.5 }
        return configuration.elevation == .none ? 1 : 0
    }

    var body: some View {
        configuration.content
            .background(theme.background(configuration.surfaceKey), in: shape)
            .clipShape(shape)   // keeps edge-to-edge content (e.g. media) inside the corner
            .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
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

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radius.value, style: .continuous)
    }

    var body: some View {
        configuration.content
            .clipShape(shape)   // keeps edge-to-edge content (e.g. media) inside the corner
            .overlay(shape.strokeBorder(theme.border(configuration.isSelected ? .borderHero : .borderPrimary), lineWidth: 1.5))
    }
}

/// A flat card: the surface fill with rounded corners, no border and no shadow —
/// the HeroUI `flat` variant. Honors the configuration's `surfaceKey`, `radius`
/// and (when selected) a hero border.
public struct FlatCardStyle: CardStyle {
    public init() {}
    public func makeBody(configuration: CardStyleConfiguration) -> some View {
        FlatCardSurface(configuration: configuration)
    }
}

private struct FlatCardSurface: View {
    let configuration: CardStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radius.value, style: .continuous)
    }

    var body: some View {
        configuration.content
            .background(theme.background(configuration.surfaceKey), in: shape)
            .clipShape(shape)
            .overlay {
                if configuration.isSelected {
                    shape.strokeBorder(theme.border(.borderHero), lineWidth: 1.5)
                }
            }
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

public extension CardStyle where Self == FlatCardStyle {
    /// A flat card (surface fill, no border, no shadow) — the HeroUI `flat` variant.
    static var flat: FlatCardStyle { FlatCardStyle() }
}

// MARK: - Type erasure + environment plumbing

public struct AnyCardStyle: CardStyle {
    private let _makeBody: @MainActor (CardStyleConfiguration) -> AnyView
    public init<S: CardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    public func makeBody(configuration: CardStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CardStyleKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = AnyCardStyle(DefaultCardStyle())
}

public extension EnvironmentValues {
    var cardStyle: AnyCardStyle {
        get { self[CardStyleKey.self] }
        set { self[CardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CardStyle`` for `Card`s (and card-shaped organisms such as
    /// `HotelResultCard`) in this view and its descendants.
    func cardStyle<S: CardStyle>(_ style: sending S) -> some View {
        environment(\.cardStyle, AnyCardStyle(style))
    }
}
