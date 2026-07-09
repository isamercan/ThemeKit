//
//  FieldStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `TextInput`'s field. The field's
//  *chrome* (fill, border, shape) lives in a `FieldStyle` you set with
//  `.fieldStyle(_:)`, so the field can be reskinned — bordered, underlined,
//  muted — without editing `TextInput`. The interactive content (floating label, editor,
//  icons/addons/clear/reveal and custom slots) stays in `TextInput` and arrives
//  composed; the style only wraps it. Helper/error text and the character counter
//  render *below* the field and are not part of the style. The default reproduces
//  the original field, so this is additive and non-breaking.
//
//      TextInput("Email", text: $email)
//          .fieldStyle(.underlined)     // or a custom FieldStyle
//

import SwiftUI

/// The inputs a `FieldStyle` wraps: the field's already-laid-out content plus the
/// state a chrome keys off (focus / enabled / validation / size).
public struct FieldStyleConfiguration {
    /// The field content (label + value/editor + accessories), laid out and padded.
    public let content: AnyView
    public let isFocused: Bool
    public let isEnabled: Bool
    public let hasError: Bool
    public let hasWarning: Bool
    /// The field's height preset, for styles that key chrome off it.
    public let size: TextInputSize
}

/// Defines a text field's chrome. Implement `makeBody` to wrap the
/// configuration's content with a surface (fill, border). Set one with
/// `.fieldStyle(_:)`; the default is ``DefaultFieldStyle``.
public protocol FieldStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FieldStyleConfiguration) -> Body
}

/// The stock field: white (or muted, when disabled) fill and a rounded border that
/// thickens and recolors on focus / validation. Reads `\.theme`.
public struct DefaultFieldStyle: FieldStyle {
    public init() {}
    public func makeBody(configuration: FieldStyleConfiguration) -> some View {
        DefaultFieldChrome(configuration: configuration)
    }
}

private struct DefaultFieldChrome: View {
    let configuration: FieldStyleConfiguration
    @Environment(\.theme) private var theme

    private var borderColor: Color {
        if configuration.hasError { return theme.border(.systemcolorsBorderError) }
        if configuration.hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if configuration.isFocused { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
    }

    var body: some View {
        configuration.content
            .background(theme.background(configuration.isEnabled ? .bgWhite : .bgSecondaryLight),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                    .strokeBorder(borderColor,
                                  lineWidth: configuration.isFocused || configuration.hasError || configuration.hasWarning ? 1.5 : 1)
            )
    }
}

/// An underlined field: no fill, just a 1.5pt bottom rule that recolors on
/// focus / validation. An example custom `FieldStyle` consumers can use directly
/// or model their own on.
public struct UnderlinedFieldStyle: FieldStyle {
    public init() {}
    public func makeBody(configuration: FieldStyleConfiguration) -> some View {
        UnderlinedFieldChrome(configuration: configuration)
    }
}

private struct UnderlinedFieldChrome: View {
    let configuration: FieldStyleConfiguration
    @Environment(\.theme) private var theme

    private var lineColor: Color {
        if configuration.hasError { return theme.border(.systemcolorsBorderError) }
        if configuration.hasWarning { return theme.border(.systemcolorsBorderWarning) }
        return configuration.isFocused ? theme.border(.borderHero) : theme.border(.borderPrimary)
    }

    var body: some View {
        configuration.content
            .overlay(alignment: .bottom) {
                Rectangle().fill(lineColor).frame(height: 1.5)
            }
    }
}

/// A muted, on-surface field (HeroUI Input `variant="secondary"`): secondary-light
/// fill, no shadow, and a border that stays transparent until it has something to
/// say — hero on focus, error/warning tokens on validation. For fields sitting on
/// a white card where the stock white fill + resting border would disappear.
public struct MutedFieldStyle: FieldStyle {
    public init() {}
    public func makeBody(configuration: FieldStyleConfiguration) -> some View {
        MutedFieldChrome(configuration: configuration)
    }
}

private struct MutedFieldChrome: View {
    let configuration: FieldStyleConfiguration
    @Environment(\.theme) private var theme

    /// Transparent at rest; recolors only for focus / validation.
    private var borderColor: Color {
        if configuration.hasError { return theme.border(.systemcolorsBorderError) }
        if configuration.hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if configuration.isFocused { return theme.border(.borderHero) }
        return .clear
    }

    var body: some View {
        configuration.content
            .background(theme.background(configuration.isEnabled ? .bgSecondaryLight : .bgSecondary),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                    .strokeBorder(borderColor,
                                  lineWidth: configuration.isFocused || configuration.hasError || configuration.hasWarning ? 1.5 : 1)
            )
    }
}

public extension FieldStyle where Self == DefaultFieldStyle {
    /// The stock bordered field (white fill + state-driven border).
    static var `default`: DefaultFieldStyle { DefaultFieldStyle() }
}

public extension FieldStyle where Self == MutedFieldStyle {
    /// A muted on-surface field: secondary-light fill, border only on focus / validation.
    static var muted: MutedFieldStyle { MutedFieldStyle() }
}

public extension FieldStyle where Self == UnderlinedFieldStyle {
    /// A borderless field with only a 1.5pt bottom rule.
    static var underlined: UnderlinedFieldStyle { UnderlinedFieldStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFieldStyle: FieldStyle {
    private let _makeBody: @MainActor (FieldStyleConfiguration) -> AnyView
    init<S: FieldStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FieldStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FieldStyleKey: EnvironmentKey {
    static let defaultValue = AnyFieldStyle(DefaultFieldStyle())
}

extension EnvironmentValues {
    var fieldStyle: AnyFieldStyle {
        get { self[FieldStyleKey.self] }
        set { self[FieldStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FieldStyle`` for `TextInput`s in this view and its descendants.
    func fieldStyle<S: FieldStyle>(_ style: sending S) -> some View {
        environment(\.fieldStyle, AnyFieldStyle(style))
    }
}
