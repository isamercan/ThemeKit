//
//  CheckboxChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The styling door for `Checkbox`'s chrome, the sibling of
//  ``RadioButtonChromeStyle``. Checkbox keeps the behaviour — the toggle and
//  what is hit-testable, read-only, the native `.disabled(_:)` gate, the
//  accessibility label / value / hint / traits / identifier and the validation
//  message list under the control. A `CheckboxChromeStyle` draws the rest: the
//  box, the label and description, and how the two sit next to each other.
//
//      ConsentForm()
//          .checkboxChromeStyle(MyCheckboxChrome())   // every Checkbox inside
//
//  While nobody sets a style, Checkbox draws its built-in chrome exactly as
//  before. ``DefaultCheckboxChromeStyle`` (`.default`) draws that same look, so
//  a custom chrome can hand some cases back to it; setting `.default`
//  explicitly restores the built-in path for a subtree.
//
//  (`CheckboxType` and `CheckboxVariant` are the older enums behind `.type(_:)`
//  and `.variant(_:)`; they stay, and a chrome reads both from the
//  configuration. `CheckboxStyle` is free, but it is the name a preset enum
//  would want — the position `SegmentedTabBarStyle` is already in, ADR-0009 D5
//  — and `…ChromeStyle` keeps this protocol paired with the radio's, whose
//  plain name an enum took.)
//

import SwiftUI

/// The inputs a ``CheckboxChromeStyle`` renders: Checkbox's raw content, its
/// resolved state, and the axes the chrome keys off.
///
/// The strings arrive raw, not as pre-styled `Text`, so a style picks its own
/// type styles and colors. Fields a style doesn't use are simply ignored; new
/// fields may be added in a minor release.
public struct CheckboxChromeStyleConfiguration {
    /// The label passed to ``Checkbox/init(_:isChecked:)``, as plain text so the
    /// chrome sets its own font and color. `nil` for a box-only checkbox.
    public let label: String?
    /// The ``Checkbox/label(_:)`` slot, when set. It replaces `label` on screen;
    /// `label` still names the control for VoiceOver.
    public let customLabel: AnyView?
    /// The ``Checkbox/description(_:)`` text, drawn under the label. Checkbox
    /// already reads it as the accessibility hint.
    public let description: String?
    /// The description's inline links (``Checkbox/description(_:links:)``), each
    /// a substring and the handler its tap runs; empty when the description is
    /// plain. `HelperText(description).links(descriptionLinks)` draws the stock
    /// line with its routing; a style that draws its own text routes the taps
    /// through these handlers.
    public let descriptionLinks: [(substring: String, action: () -> Void)]
    /// Whether the checkbox is on. Checkbox owns the toggle; a chrome only
    /// draws the state.
    public let isChecked: Bool
    /// Whether the mixed state is showing (``Checkbox/indeterminate(_:)``). The
    /// stock chrome draws a dash instead of a checkmark and treats the box as
    /// selected regardless of ``isChecked``.
    public let isIndeterminate: Bool
    /// Whether the checkbox is enabled (native `.disabled(_:)`); `false` draws
    /// the disabled chrome. Checkbox already blocks the taps.
    public let isEnabled: Bool
    /// Whether the checkbox is being pressed — the live `ButtonStyle` state.
    public let isPressed: Bool
    /// Whether the subtree is read-only (`.readOnly(_:)`). Checkbox already
    /// ignores taps; the built-in chrome looks the same as when editable.
    public let isReadOnly: Bool
    /// The box's visual style (``Checkbox/type(_:)``): `.plain`, `.inner`, or
    /// `.customInner(color:)`. When the caller used the token-bound
    /// ``Checkbox/customInner(_:)`` the payload here is a `.clear` placeholder
    /// and ``swatch`` carries the token — resolve that instead.
    public let type: CheckboxType
    /// The box's surface treatment (``Checkbox/variant(_:)``): `.primary`
    /// (border-only) or `.secondary` (a soft resting fill for elevated
    /// surfaces).
    public let variant: CheckboxVariant
    /// The token from ``Checkbox/customInner(_:)``, when the caller used the
    /// token-bound spelling; `nil` otherwise. It stays a token rather than a
    /// resolved `Color` so a per-subtree `.theme(_:)` re-skins it (ADR-0009 D7).
    public let swatch: SemanticColor?
    /// The most severe ``Checkbox/infoMessages(_:)`` kind, or `nil`. Checkbox
    /// renders the messages themselves under the chrome; this is the state the
    /// box and the title key off.
    public let validation: InfoMessage.Kind?
    /// ``Checkbox/accent(_:)``; `nil` means the hero tokens.
    public let accent: SemanticColor?
    /// The native `.controlSize(_:)` in effect. Prefer ``side``, which folds in
    /// ``customSize``.
    public let controlSize: ControlSize
    /// The ``Checkbox/customSize(_:)`` override, when set; it bypasses the
    /// control-size metric. Prefer ``side``.
    public let customSize: CGFloat?
    /// Which side of the label the box sits on
    /// (``Checkbox/controlPlacement(_:)``).
    public let controlPlacement: HorizontalEdge
    /// Vertical alignment of the box against the label
    /// (``Checkbox/alignment(_:)``).
    public let alignment: VerticalAlignment
    /// Whether the label is struck through while checked
    /// (``Checkbox/lineThrough(_:)``). It is the caller's flag, not the
    /// resolved one: the stock chrome strikes only when ``isChecked`` too.
    public let lineThrough: Bool
    /// The selection animation, resolved by Checkbox (`microAnimations` ∧
    /// ¬Reduce Motion); `nil` when motion is off. Use it for state changes and
    /// never read the motion environment yourself.
    public let animation: Animation?

    /// The box's side length as Checkbox resolves it: ``customSize`` when the
    /// caller set one, else the Figma "Control Items" metric for
    /// ``controlSize`` (Small 20 / Medium 24 / Large 28).
    public var side: CGFloat { customSize ?? controlSize.checkboxSide }

    /// This configuration with the live `ButtonStyle` press state filled in.
    func pressing(_ isPressed: Bool) -> Self {
        Self(
            label: label, customLabel: customLabel, description: description,
            descriptionLinks: descriptionLinks, isChecked: isChecked,
            isIndeterminate: isIndeterminate, isEnabled: isEnabled, isPressed: isPressed,
            isReadOnly: isReadOnly, type: type, variant: variant, swatch: swatch,
            validation: validation, accent: accent, controlSize: controlSize,
            customSize: customSize, controlPlacement: controlPlacement,
            alignment: alignment, lineThrough: lineThrough, animation: animation
        )
    }
}

/// Defines ``Checkbox``'s chrome. Implement `makeBody` to draw the box and lay
/// it out with the label and description. Set one with
/// `.checkboxChromeStyle(_:)` on a checkbox or any ancestor; without one,
/// Checkbox draws its built-in chrome.
///
/// The style draws; Checkbox keeps the rest. A tap still toggles the binding,
/// read-only still ignores taps, `.disabled(_:)` still blocks them, the
/// accessibility label, value, hint, traits and identifier stay on the control,
/// and validation messages still render under the chrome. Checkbox adds no
/// dimming or press effect on this path, so the style draws the disabled and
/// pressed looks. The style's output is the hit area, so add a `contentShape`
/// if the whole row should respond.
///
/// The style reaches every ``Checkbox`` in the subtree, including those ThemeKit
/// components compose. The boxes inside ``CheckboxGroup``, ``ControlRow``
/// (`.control(.checkbox)`), ``FilterRow``, ``FilterList``, ``MultiSelect``,
/// ``TreeSelect``, ``SelectionCards`` and ``ListRow`` (`.checkbox`) carry no
/// label of their own, so a style should draw just the box when `label`,
/// `customLabel` and `description` are all `nil`.
///
///     struct TokenCheckboxChrome: CheckboxChromeStyle {
///         func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
///             TokenCheckboxChromeBody(configuration: configuration)
///         }
///     }
///
///     private struct TokenCheckboxChromeBody: View {
///         let configuration: CheckboxChromeStyleConfiguration
///         @Environment(\.theme) private var theme
///
///         var body: some View {
///             let c = configuration
///             let accent = theme.resolve(c.accent ?? .primary)
///             HStack(spacing: Theme.SpacingKey.sm.value) {
///                 RoundedRectangle(cornerRadius: 6, style: .continuous)
///                     .fill(c.isChecked || c.isIndeterminate ? accent.solid : theme.background(.bgWhite))
///                     .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(accent.border, lineWidth: 1.5) }
///                     .frame(width: c.side, height: c.side)
///                     .animation(c.animation, value: c.isChecked)
///                 if let label = c.label {
///                     Text(label).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
///                 }
///             }
///             .opacity(c.isEnabled ? (c.isPressed ? 0.8 : 1) : 0.4)
///             .contentShape(Rectangle())
///         }
///     }
public protocol CheckboxChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CheckboxChromeStyleConfiguration) -> Body
}

/// The stock chrome — the look Checkbox draws when no style is set: a rounded
/// 1.5pt box sized by the control size (hero, accent, swatch or validation
/// colored), a checkmark, a dash for the mixed state or the inset `.inner`
/// square, the body text label or label slot, and the description as
/// ``HelperText``. Like the built-in path's plain button, it dims to 75%
/// opacity while pressed and fades to half opacity when disabled, so a custom
/// style that hands some checkboxes to it keeps that feedback. Reads the active
/// `\.theme`, so an injected theme re-skins it too.
public struct DefaultCheckboxChromeStyle: CheckboxChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
        DefaultCheckboxChrome(configuration: configuration)
    }
}

/// Mirrors Checkbox's built-in body. `CheckboxChromeStyleTests` renders both and
/// compares the pixels, so the two can't drift apart unnoticed.
private struct DefaultCheckboxChrome: View {
    let configuration: CheckboxChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: configuration.alignment, spacing: Theme.SpacingKey.sm.value) {
            if configuration.controlPlacement == .leading {
                box
                labelView
            } else {
                labelView
                box
            }
        }
        .contentShape(Rectangle())
        // The built-in path's `.buttonStyle(.plain)` dims a pressed label to
        // 75% and halves a disabled one; the style path's bridge adds nothing,
        // so the chrome does both.
        .opacity(configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
    }

    private var side: CGFloat { configuration.side }
    private var radius: CGFloat { Theme.RadiusRole.selector.value }
    private var selected: Bool { configuration.isChecked || configuration.isIndeterminate }

    private var selectedFill: Color {
        if configuration.isEnabled, let accent = configuration.accent { return theme.resolve(accent).solid }
        return theme.background(configuration.isEnabled ? .bgHero : .bgSecondary)
    }

    private var glyphColor: Color {
        if configuration.isEnabled, let accent = configuration.accent { return theme.resolve(accent).onSolid }
        return theme.foreground(.fgSecondary)
    }

    private var fill: Color {
        if let swatch = configuration.swatch { return theme.resolve(swatch).solid }
        switch configuration.type {
        case .customInner(let color):
            return color
        case .plain, .inner:
            guard selected else { return restingFill }
            // `.inner` keeps the outer box transparent; the inset square is the fill.
            if case .inner = configuration.type { return .clear }
            return selectedFill
        }
    }

    private var restingFill: Color {
        configuration.variant == .secondary ? theme.background(.bgSecondaryLight) : .clear
    }

    private var stroke: Color {
        if case .customInner = configuration.type { return .clear }
        if !configuration.isEnabled { return theme.border(.borderPrimary) }
        if configuration.validation == .error { return theme.border(.systemcolorsBorderError) }
        if configuration.validation == .warning { return theme.border(.systemcolorsBorderWarning) }
        guard selected else { return theme.border(.borderPrimary) }
        return configuration.accent.map { theme.resolve($0).border } ?? theme.border(.borderHero)
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1.5)
            )
            .frame(width: side, height: side)
            .overlay(glyph.transition(.scale(scale: 0.7).combined(with: .opacity)))
            .animation(configuration.animation, value: selected)
    }

    @ViewBuilder private var glyph: some View {
        if case .inner = configuration.type {
            if selected {
                RoundedRectangle(cornerRadius: max(radius - 2, 1), style: .continuous)
                    .fill(selectedFill)
                    .padding(side * 0.2)
                    .overlay {
                        if configuration.isIndeterminate {
                            Image(systemName: "minus")
                                .font(.system(size: side * 0.34, weight: .bold))
                                .foregroundStyle(glyphColor)
                        }
                    }
            }
        } else if selected {
            Image(systemName: configuration.isIndeterminate ? "minus" : "checkmark")
                .font(.system(size: side * 0.6, weight: .bold))
                .foregroundStyle(glyphColor)
        }
    }

    private var labelView: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            titleView
            if let description = configuration.description {
                HelperText(description).links(configuration.descriptionLinks)
            }
        }
    }

    @ViewBuilder private var titleView: some View {
        if let customLabel = configuration.customLabel {
            customLabel
                .strikethroughCompat(configuration.lineThrough && configuration.isChecked)
        } else if let label = configuration.label {
            Text(label)
                .strikethrough(configuration.lineThrough && configuration.isChecked)
                .textStyle(.bodyBase400)
                .foregroundStyle(titleColor)
        }
    }

    private var titleColor: Color {
        if !configuration.isEnabled { return theme.text(.textDisabled) }
        if configuration.validation == .error { return theme.foreground(.systemcolorsFgError) }
        return theme.text(.textPrimary)
    }
}

public extension CheckboxChromeStyle where Self == DefaultCheckboxChromeStyle {
    /// The stock chrome — Checkbox's built-in look. Setting it with
    /// `.checkboxChromeStyle(.default)` restores the built-in path.
    static var `default`: DefaultCheckboxChromeStyle { DefaultCheckboxChromeStyle() }
}

// MARK: - ButtonStyle bridge

/// Hands Checkbox's chrome to the environment ``CheckboxChromeStyle`` through a
/// real SwiftUI `ButtonStyle`, so `isPressed` is the live press state. Draws
/// nothing of its own: no dimming when disabled, no press effect. Used only on
/// the custom-style path; the built-in chrome keeps `.plain`.
struct CheckboxChromeBridge: ButtonStyle {
    let style: AnyCheckboxChromeStyle
    /// Everything but the press state, resolved by Checkbox.
    let template: CheckboxChromeStyleConfiguration

    func makeBody(configuration: Configuration) -> some View {
        style.makeBody(configuration: template.pressing(configuration.isPressed))
    }
}

// MARK: - Type erasure + environment plumbing

struct AnyCheckboxChromeStyle: CheckboxChromeStyle {
    /// `true` for the environment key's stock default below, and for
    /// ``DefaultCheckboxChromeStyle`` set explicitly. While it is set, Checkbox
    /// draws its built-in path (unchanged from before this door existed),
    /// `.plain` press and disabled feedback included. Any other style routes
    /// through `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (CheckboxChromeStyleConfiguration) -> AnyView
    init<S: CheckboxChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault || S.self == DefaultCheckboxChromeStyle.self
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CheckboxChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CheckboxChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyCheckboxChromeStyle(DefaultCheckboxChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var checkboxChromeStyle: AnyCheckboxChromeStyle {
        get { self[CheckboxChromeStyleKey.self] }
        set { self[CheckboxChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CheckboxChromeStyle`` for `Checkbox`es in this view and its
    /// descendants — including the checkboxes inside ThemeKit components.
    func checkboxChromeStyle<S: CheckboxChromeStyle>(_ style: sending S) -> some View {
        environment(\.checkboxChromeStyle, AnyCheckboxChromeStyle(style))
    }
}
