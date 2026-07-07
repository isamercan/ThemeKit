//
//  SelectStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `Select`'s trigger field. The field's
//  *chrome* (fill, border, shape) lives in a `SelectStyle` you set with
//  `.selectStyle(_:)`, so the field can be reskinned — filled, underlined, pill —
//  without editing `Select`. The interactive content (floating label, value,
//  chevron/clear) stays in `Select` and arrives composed; the style only wraps it.
//  The default reproduces the original field, so this is additive and non-breaking.
//
//      Select("City", options: cities, selection: $city) { $0 }
//          .selectStyle(.filled)
//

import SwiftUI

/// The inputs a `SelectStyle` wraps: the field's already-laid-out content plus the
/// state a chrome keys off (open / enabled / validation).
public struct SelectStyleConfiguration {
    /// The field content (floating label + value + chevron/clear), padded + sized.
    public let content: AnyView
    public let isOpen: Bool
    public let isEnabled: Bool
    public let hasError: Bool
    public let hasWarning: Bool
}

/// Defines a `Select` field's chrome. Implement `makeBody` to wrap the
/// configuration's content with a surface (fill, border). Set one with
/// `.selectStyle(_:)`; the default is ``DefaultSelectStyle``.
public protocol SelectStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SelectStyleConfiguration) -> Body
}

/// The stock field: white (or muted, when disabled) fill and a rounded border that
/// thickens and recolors on focus / validation. Reads `\.theme`.
public struct DefaultSelectStyle: SelectStyle {
    public init() {}
    public func makeBody(configuration: SelectStyleConfiguration) -> some View {
        DefaultSelectField(configuration: configuration)
    }
}

private struct DefaultSelectField: View {
    let configuration: SelectStyleConfiguration
    @Environment(\.theme) private var theme

    private var borderColor: Color {
        if configuration.hasError { return theme.border(.systemcolorsBorderError) }
        if configuration.hasWarning { return theme.border(.systemcolorsBorderWarning) }
        return configuration.isOpen ? theme.border(.borderHero) : theme.border(.borderPrimary)
    }

    var body: some View {
        configuration.content
            .background(theme.background(configuration.isEnabled ? .bgWhite : .bgSecondaryLight),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(borderColor,
                                  lineWidth: configuration.isOpen || configuration.hasError || configuration.hasWarning ? 1.5 : 1)
            )
    }
}

/// A filled field: a tinted surface and no border (a Material-style look). An
/// example custom `SelectStyle` consumers can use or model their own on.
public struct FilledSelectStyle: SelectStyle {
    public init() {}
    public func makeBody(configuration: SelectStyleConfiguration) -> some View {
        FilledSelectField(configuration: configuration)
    }
}

private struct FilledSelectField: View {
    let configuration: SelectStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .background(theme.background(.bgBase),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(alignment: .bottom) {
                if configuration.hasError {
                    Rectangle().fill(theme.border(.systemcolorsBorderError)).frame(height: 1.5)
                } else if configuration.isOpen {
                    Rectangle().fill(theme.border(.borderHero)).frame(height: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

public extension SelectStyle where Self == DefaultSelectStyle {
    /// The stock bordered field.
    static var `default`: DefaultSelectStyle { DefaultSelectStyle() }
}

public extension SelectStyle where Self == FilledSelectStyle {
    /// A filled, borderless field (tinted surface).
    static var filled: FilledSelectStyle { FilledSelectStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySelectStyle: SelectStyle {
    private let _makeBody: @MainActor (SelectStyleConfiguration) -> AnyView
    init<S: SelectStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SelectStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SelectStyleKey: EnvironmentKey {
    static let defaultValue = AnySelectStyle(DefaultSelectStyle())
}

extension EnvironmentValues {
    var selectStyle: AnySelectStyle {
        get { self[SelectStyleKey.self] }
        set { self[SelectStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SelectStyle`` for `Select`s in this view and its descendants.
    func selectStyle<S: SelectStyle>(_ style: sending S) -> some View {
        environment(\.selectStyle, AnySelectStyle(style))
    }
}
