//
//  RadioButtonChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The styling door for `RadioButton`'s chrome. RadioButton keeps the
//  behaviour — select-only vs toggle, read-only, the native `.disabled(_:)`
//  gate, the accessibility label / value / hint / traits / identifier and the
//  validation message list under the control. A `RadioButtonChromeStyle`
//  draws the rest: the indicator, the label and description, and how the two
//  sit next to each other.
//
//      PaymentOptions()
//          .radioButtonChromeStyle(MyRadioChrome())   // every RadioButton inside
//
//  While nobody sets a style, RadioButton draws its built-in chrome exactly as
//  before. ``DefaultRadioButtonChromeStyle`` (`.default`) draws that same look,
//  so a custom chrome can hand some cases back to it; setting `.default`
//  explicitly restores the built-in path for a subtree.
//
//  (`RadioButtonStyle` is the older enum behind `.radioStyle(_:)`, which picks
//  the `.check` indicator. It stays, and a chrome reads it from the
//  configuration.)
//

import SwiftUI

/// The inputs a ``RadioButtonChromeStyle`` renders: RadioButton's raw content,
/// its resolved state, and the axes the chrome keys off.
public struct RadioButtonChromeStyleConfiguration {
    /// The label passed to ``RadioButton/init(_:isSelected:)``, as plain text so
    /// the chrome sets its own font and color. `nil` for a label-less radio.
    public let label: String?
    /// The ``RadioButton/label(_:)`` slot, when set. It replaces `label` on
    /// screen; `label` still names the control for VoiceOver.
    public let customLabel: AnyView?
    /// The ``RadioButton/description(_:)`` text, drawn under the label.
    /// RadioButton already reads it as the accessibility hint.
    public let description: String?
    /// Whether the radio is selected.
    public let isSelected: Bool
    /// Whether the radio is enabled (native `.disabled(_:)`); `false` draws the
    /// disabled chrome. RadioButton already blocks the taps.
    public let isEnabled: Bool
    /// Whether the radio is being pressed — the live `ButtonStyle` state.
    public let isPressed: Bool
    /// Whether the subtree is read-only (`.readOnly(_:)`). RadioButton already
    /// ignores taps; the built-in chrome looks the same as when editable.
    public let isReadOnly: Bool
    /// Tap behaviour and indicator family: `.select` (dot, select-only) or
    /// `.check` (glyph, toggles).
    public let type: RadioButtonType
    /// The `.check` indicator from ``RadioButton/radioStyle(_:)``: `.plain`
    /// checkmark or `.inner` dot.
    public let radioStyle: RadioButtonStyle
    /// The most severe ``RadioButton/infoMessages(_:)`` kind, or `nil`.
    /// RadioButton renders the messages under the chrome.
    public let validation: InfoMessage.Kind?
    /// ``RadioButton/accent(_:)``; `nil` means the hero tokens.
    public let accent: SemanticColor?
    /// The native `.controlSize(_:)` in effect.
    public let controlSize: ControlSize
    /// Which side of the label the indicator sits on
    /// (``RadioButton/controlPlacement(_:)``).
    public let controlPlacement: HorizontalEdge
    /// Vertical alignment of the indicator against the label
    /// (``RadioButton/alignment(_:)``).
    public let alignment: VerticalAlignment
    /// Gap between the indicator and the label (``RadioButton/gap(_:)``).
    public let gap: RadioButtonPadding
    /// The selection animation, resolved by RadioButton (`microAnimations` ∧
    /// ¬Reduce Motion); `nil` when motion is off. Use it for selection changes
    /// and never read the motion environment yourself.
    public let animation: Animation?

    /// The deprecated raw ``RadioButton/fillColor(_:)`` override, kept for the
    /// default chrome only.
    let fillColorOverride: Color?

    /// This configuration with the live `ButtonStyle` press state filled in.
    func pressing(_ isPressed: Bool) -> Self {
        Self(
            label: label, customLabel: customLabel, description: description,
            isSelected: isSelected, isEnabled: isEnabled, isPressed: isPressed,
            isReadOnly: isReadOnly, type: type, radioStyle: radioStyle,
            validation: validation, accent: accent, controlSize: controlSize,
            controlPlacement: controlPlacement, alignment: alignment, gap: gap,
            animation: animation, fillColorOverride: fillColorOverride
        )
    }
}

/// Defines ``RadioButton``'s chrome. Implement `makeBody` to draw the
/// indicator and lay it out with the label and description. Set one with
/// `.radioButtonChromeStyle(_:)` on a radio or any ancestor; without one,
/// RadioButton draws its built-in chrome.
///
/// The style draws; RadioButton keeps the rest. A `.select` radio only
/// selects and a `.check` radio toggles, read-only still ignores taps,
/// `.disabled(_:)` still blocks them, the accessibility label, value, hint,
/// traits and identifier stay on the control, and validation messages still
/// render under the chrome. RadioButton adds no dimming or press effect on this
/// path, so the style draws the disabled and pressed looks. The style's output
/// is the hit area, so add a `contentShape` if the whole row should respond.
///
/// The style reaches every ``RadioButton`` in the subtree, including those
/// ThemeKit components compose. ``RadioGroup`` hands the style whole rows
/// (label and option description included) and no longer fades disabled
/// options. The indicator-only radios inside ``ControlRow`` (`.control(.radio)`),
/// ``RadioCard`` and ``ListRow`` (`.leadingSelection`) have no label, so a style
/// should draw just the indicator when `label`, `customLabel` and
/// `description` are all `nil`.
///
///     struct TokenRadioChrome: RadioButtonChromeStyle {
///         func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
///             TokenRadioChromeBody(configuration: configuration)
///         }
///     }
///
///     private struct TokenRadioChromeBody: View {
///         let configuration: RadioButtonChromeStyleConfiguration
///         @Environment(\.theme) private var theme
///
///         var body: some View {
///             let c = configuration
///             let accent = theme.resolve(c.accent ?? .primary)
///             HStack(spacing: Theme.SpacingKey.sm.value) {
///                 Circle()
///                     .fill(c.isSelected ? accent.solid : theme.background(.bgWhite))
///                     .overlay { Circle().fill(accent.onSolid).padding(5).opacity(c.isSelected ? 1 : 0) }
///                     .overlay { Circle().strokeBorder(accent.border, lineWidth: c.isSelected ? 0 : 1) }
///                     .frame(width: 18, height: 18)
///                     .animation(c.animation, value: c.isSelected)
///                 if let label = c.label {
///                     Text(label).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
///                 }
///             }
///             .opacity(c.isEnabled ? (c.isPressed ? 0.8 : 1) : 0.4)
///             .contentShape(Rectangle())
///         }
///     }
public protocol RadioButtonChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> Body
}

/// The stock chrome — the look RadioButton draws when no style is set: a
/// 1.5pt ring (hero, accent or validation colored) sized by the control size,
/// a `.select` dot, a `.check` checkmark or inner dot, the body text label or
/// label slot, and the description as ``HelperText``. Like the built-in path's
/// plain button, it dims to 75% opacity while pressed and fades to half
/// opacity when disabled, so a custom style that hands some radios to it keeps
/// that feedback. Reads the active `\.theme`, so an injected theme re-skins it
/// too.
public struct DefaultRadioButtonChromeStyle: RadioButtonChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        DefaultRadioButtonChrome(configuration: configuration)
    }
}

/// Mirrors RadioButton's built-in body. `RadioButtonChromeStyleTests` renders
/// both and compares the pixels, so the two can't drift apart unnoticed.
private struct DefaultRadioButtonChrome: View {
    let configuration: RadioButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: configuration.alignment, spacing: configuration.gap.value) {
            if configuration.controlPlacement == .leading {
                control
                labelView
            } else {
                labelView
                control
            }
        }
        .contentShape(Rectangle())
        // The built-in path's `.buttonStyle(.plain)` dims a pressed label to
        // 75% and halves a disabled one; the style path's button adds
        // nothing, so the chrome does both.
        .opacity(configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
    }

    private var side: CGFloat { configuration.controlSize.checkboxSide }
    private var filled: Bool {
        configuration.isSelected && configuration.type == .check && configuration.radioStyle == .plain
    }

    private var fillColor: Color {
        if let override = configuration.fillColorOverride { return override }
        if configuration.isEnabled, let accent = configuration.accent { return theme.resolve(accent).solid }
        return theme.background(configuration.isEnabled ? .bgHero : .bgSecondary)
    }

    private var stroke: Color {
        if !configuration.isEnabled { return theme.border(.borderPrimary) }
        if configuration.validation == .error { return theme.border(.systemcolorsBorderError) }
        if configuration.validation == .warning { return theme.border(.systemcolorsBorderWarning) }
        guard configuration.isSelected else { return theme.border(.borderPrimary) }
        return configuration.accent.map { theme.resolve($0).border } ?? theme.border(.borderHero)
    }

    private var checkmarkColor: Color {
        guard configuration.isEnabled, configuration.fillColorOverride == nil, let accent = configuration.accent else {
            return theme.foreground(.fgSecondary)
        }
        return theme.resolve(accent).onSolid
    }

    private var control: some View {
        Circle()
            .fill(filled ? fillColor : .clear)
            .overlay(Circle().strokeBorder(stroke, lineWidth: 1.5))
            .frame(width: side, height: side)
            .overlay(indicator.transition(.scale(scale: 0.6).combined(with: .opacity)))
            .animation(configuration.animation, value: configuration.isSelected)
    }

    @ViewBuilder private var indicator: some View {
        if configuration.isSelected {
            switch (configuration.type, configuration.radioStyle) {
            case (.select, _):
                Circle().fill(fillColor).frame(width: side * 0.5, height: side * 0.5)
            case (.check, .plain):
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.55, weight: .bold))
                    .foregroundStyle(checkmarkColor)
            case (.check, .inner):
                ZStack {
                    Circle().fill(theme.background(.bgWhite))
                    Circle().fill(fillColor).padding(side * 0.18)
                }
                .frame(width: side * 0.74, height: side * 0.74)
            }
        }
    }

    @ViewBuilder private var labelView: some View {
        if let description = configuration.description {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                titleView
                HelperText(description)
            }
        } else {
            titleView
        }
    }

    @ViewBuilder private var titleView: some View {
        if let customLabel = configuration.customLabel {
            customLabel
        } else if let label = configuration.label {
            Text(label)
                .textStyle(.bodyBase400)
                .foregroundStyle(configuration.isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
        }
    }
}

public extension RadioButtonChromeStyle where Self == DefaultRadioButtonChromeStyle {
    /// The stock chrome — RadioButton's built-in look. Setting it with
    /// `.radioButtonChromeStyle(.default)` restores the built-in path.
    static var `default`: DefaultRadioButtonChromeStyle { DefaultRadioButtonChromeStyle() }
}

// MARK: - ButtonStyle bridge

/// Hands RadioButton's chrome to the environment ``RadioButtonChromeStyle``
/// through a real SwiftUI `ButtonStyle`, so `isPressed` is the live press state.
/// Draws nothing of its own: no dimming when disabled, no press effect. Used
/// only on the custom-style path; the built-in chrome keeps `.plain`.
struct RadioButtonChromeBridge: ButtonStyle {
    let style: AnyRadioButtonChromeStyle
    /// Everything but the press state, resolved by RadioButton.
    let template: RadioButtonChromeStyleConfiguration

    func makeBody(configuration: Configuration) -> some View {
        style.makeBody(configuration: template.pressing(configuration.isPressed))
    }
}

// MARK: - Type erasure + environment plumbing

struct AnyRadioButtonChromeStyle: RadioButtonChromeStyle {
    /// `true` for the environment key's stock default below, and for
    /// ``DefaultRadioButtonChromeStyle`` set explicitly. While it is set,
    /// RadioButton and RadioGroup draw their built-in path (unchanged from
    /// before this door existed), `.plain` press and disabled feedback
    /// included. Any other style routes through `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (RadioButtonChromeStyleConfiguration) -> AnyView
    init<S: RadioButtonChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault || S.self == DefaultRadioButtonChromeStyle.self
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct RadioButtonChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyRadioButtonChromeStyle(DefaultRadioButtonChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var radioButtonChromeStyle: AnyRadioButtonChromeStyle {
        get { self[RadioButtonChromeStyleKey.self] }
        set { self[RadioButtonChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``RadioButtonChromeStyle`` for `RadioButton`s in this view and
    /// its descendants — including the radios inside ThemeKit components.
    func radioButtonChromeStyle<S: RadioButtonChromeStyle>(_ style: sending S) -> some View {
        environment(\.radioButtonChromeStyle, AnyRadioButtonChromeStyle(style))
    }
}
