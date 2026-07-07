//
//  SelectStyle.swift
//  ThemeKit
//
//  DEPRECATED — folded into `FieldStyle` (see `FieldStyle.swift`). `SelectStyle`
//  was the `ButtonStyle`-shaped styling hook for `Select`'s trigger field; the
//  generalized `FieldStyle` now plays that role for every form field (TextInput,
//  Select, MultiSelect, TreeSelect, …), so field chromas are themed from a single
//  `.fieldStyle(_:)` axis.
//
//  Backward compatibility: everything here keeps compiling and working. When a
//  custom style is injected with `.selectStyle(_:)`, `Select` renders through it
//  exactly as before. Only when the environment still holds the *default*
//  `SelectStyle` (nobody injected one — tracked by `AnySelectStyle.isDefault`)
//  does `Select` draw its chrome through `\.fieldStyle` instead.
//
//      Select("City", options: cities, selection: $city) { $0 }
//          .fieldStyle(.underlined)     // preferred
//          .selectStyle(.filled)        // legacy — still works, now deprecated
//

import SwiftUI

/// The inputs a `SelectStyle` wraps: the field's already-laid-out content plus the
/// state a chrome keys off (open / enabled / validation).
///
/// Kept non-deprecated: it is the payload of the legacy path and internal plumbing
/// (`AnySelectStyle`, `Select`'s legacy branch) still constructs it warning-free.
/// New code should implement ``FieldStyle`` / ``FieldStyleConfiguration`` instead.
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
@available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead.")
public protocol SelectStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SelectStyleConfiguration) -> Body
}

/// The stock field: white (or muted, when disabled) fill and a rounded border that
/// thickens and recolors on focus / validation. Same chroma family as
/// ``DefaultFieldStyle``, which replaces it.
@available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead.")
public struct DefaultSelectStyle: SelectStyle {
    public init() {}
    public func makeBody(configuration: SelectStyleConfiguration) -> some View {
        DefaultSelectField(configuration: configuration)
    }
}

/// The legacy default chrome, kept as a plain (non-deprecated) private view so the
/// internal fallback in ``AnySelectStyle/environmentDefault`` can reference it
/// without tripping deprecation warnings.
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
@available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead (port this chroma to a custom FieldStyle).")
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
            .background(theme.background(.bgElevatorPrimary),
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

@available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead.")
public extension SelectStyle where Self == DefaultSelectStyle {
    /// The stock bordered field.
    static var `default`: DefaultSelectStyle { DefaultSelectStyle() }
}

@available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead (port this chroma to a custom FieldStyle).")
public extension SelectStyle where Self == FilledSelectStyle {
    /// A filled, borderless field (tinted surface).
    static var filled: FilledSelectStyle { FilledSelectStyle() }
}

// MARK: - Type erasure + environment plumbing

/// Internal type-eraser for the legacy `SelectStyle` environment slot.
///
/// No longer conforms to `SelectStyle` (the protocol is deprecated; conforming
/// would raise a warning at an internal, non-deprecated site) — it only needs the
/// `makeBody` shape. The `isDefault` flag is how `Select` tells "nobody injected a
/// style" (chrome routes to `\.fieldStyle`) apart from "a custom `SelectStyle` is
/// installed" (legacy path, byte-for-byte unchanged).
struct AnySelectStyle {
    /// `true` only for the environment's untouched default value. `.selectStyle(_:)`
    /// always installs `isDefault: false`, keeping the legacy render path alive.
    let isDefault: Bool
    private let _makeBody: @MainActor (SelectStyleConfiguration) -> AnyView

    private init(isDefault: Bool, makeBody: @escaping @MainActor (SelectStyleConfiguration) -> AnyView) {
        self.isDefault = isDefault
        self._makeBody = makeBody
    }

    /// Wraps a user-supplied style — only reachable from the (deprecated)
    /// `.selectStyle(_:)` modifier, so it carries the same deprecation and its
    /// reference to the deprecated protocol stays warning-free.
    @available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead.")
    init<S: SelectStyle>(_ style: sending S) {
        self.init(isDefault: false) { AnyView(style.makeBody(configuration: $0)) }
    }

    /// The environment's default value: flagged `isDefault` so `Select` routes its
    /// chrome through `\.fieldStyle`. Its `makeBody` still renders the legacy
    /// default chrome as a safety net (it is not reached by `Select` today).
    static var environmentDefault: AnySelectStyle {
        AnySelectStyle(isDefault: true) { AnyView(DefaultSelectField(configuration: $0)) }
    }

    func makeBody(configuration: SelectStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SelectStyleKey: EnvironmentKey {
    static let defaultValue = AnySelectStyle.environmentDefault
}

extension EnvironmentValues {
    var selectStyle: AnySelectStyle {
        get { self[SelectStyleKey.self] }
        set { self[SelectStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SelectStyle`` for `Select`s in this view and its descendants.
    @available(*, deprecated, message: "Adopt FieldStyle / .fieldStyle(_:) instead.")
    func selectStyle<S: SelectStyle>(_ style: sending S) -> some View {
        environment(\.selectStyle, AnySelectStyle(style))
    }
}
