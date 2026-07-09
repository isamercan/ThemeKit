//
//  ControlRow.swift
//  ThemeKit
//  Created by İsa Mercan on 09.07.2026.
//

import SwiftUI

/// Boolean control archetype rendered in a `ControlRow`'s trailing slot.
/// (Reference ControlField.Indicator `variant` parity.)
public enum ControlRowControl: Equatable {
    /// A `ThemeToggle` switch (the default).
    case toggle
    /// A `Checkbox` box.
    case checkbox
    /// A `RadioButton` dot.
    case radio
}

/// Molecule. A single form field fusing an `InputLabel`, optional supporting
/// text and a boolean control (toggle / checkbox / radio) into one pressable
/// row with validation. (Reference ControlField parity.) Per the modifier-based
/// architecture (COMPONENT_REFACTOR_RULES R1–R7) the init takes only its title
/// and the `isOn` binding; every appearance/validation axis is a chainable,
/// order-free modifier. `disabled` is native (`@Environment(\.isEnabled)`, R3);
/// the indicator inherits the native `.controlSize(_:)` cascade.
///
///     ControlRow("I agree to the terms", isOn: $accepted)
///         .control(.checkbox)
///         .description("By checking this box, you agree to our Terms of Service.")
///         .required()
///         .hasError(showErrors && !accepted)
///         .errorText("This field is required.")
///         .disabled(!editable)            // native — R3
public struct ControlRow: View {
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    @Binding private var isOn: Bool
    private let title: String

    // Appearance/validation — mutated only through the modifiers below (R2).
    private var description: String?
    private var control: ControlRowControl = .toggle
    private var customIndicator: AnyView?
    private var isRequired = false
    private var hasError = false
    private var errorText: String?
    private var accessibilityID: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ title: String, isOn: Binding<Bool>) {   // R1 — content + binding
        self.title = title
        self._isOn = isOn
    }

    /// The error line renders only while `hasError` is on (the recolor axis
    /// gates the message, TextInput `errorText` convention).
    private var showsError: Bool { hasError && errorText != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                withAnimation(motion) { isOn.toggle() }
            } label: {
                HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                        InputLabel(title)
                            .required(isRequired)
                            .hasError(hasError)
                        if let description {
                            HelperText(description)
                                .hasError(hasError)
                        }
                    }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    indicator
                        .accessibilityHidden(true)   // the row is the single a11y element
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressFeedbackStyle())   // subtle press scale, gated by microAnimations + Reduce Motion
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.6)
            .a11y(controlElement, in: accessibilityID)
            .accessibilityLabel(isRequired ? title + ", " + String(themeKit: "required") : title)
            .accessibilityValue(isOn ? String(themeKit: "on") : String(themeKit: "off"))
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            if showsError, let errorText {
                InfoMessageList([InfoMessage(errorText, kind: .error)])
                    .transition(.opacity)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        .animation(motion, value: showsError)
    }

    /// Trailing boolean control: the custom slot when set, else the archetype
    /// from `control(_:)` — all driven by the same `isOn` binding, so a tap on
    /// the indicator and a tap on the row stay in sync.
    @ViewBuilder
    private var indicator: some View {
        if let customIndicator {
            customIndicator
        } else {
            switch control {
            case .toggle: ThemeToggle(isOn: $isOn)
            case .checkbox: Checkbox(isChecked: $isOn)
            case .radio: RadioButton(isSelected: $isOn)
            }
        }
    }

    private var controlElement: A11yElement.Control {
        switch control {
        case .toggle: return .toggle
        case .checkbox: return .checkbox
        case .radio: return .radio
        }
    }

    /// Description + (while errored) the error text, so VoiceOver reads the
    /// supporting copy and the validation message on the single row element.
    private var accessibilityHint: String {
        var parts: [String] = []
        if let description { parts.append(description) }
        if showsError, let errorText { parts.append(errorText) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ControlRow {
    /// Supporting text rendered under the label.
    func description(_ text: String?) -> Self { copy { $0.description = text } }

    /// Which boolean control renders in the trailing slot: `.toggle` (default),
    /// `.checkbox`, or `.radio`. Ignored when a custom `indicator` is set.
    func control(_ kind: ControlRowControl) -> Self { copy { $0.control = kind } }

    /// Replaces the built-in control with a custom trailing indicator view.
    /// The row press still toggles `isOn`; keep the slot purely visual.
    func indicator(@ViewBuilder _ content: () -> some View) -> Self {
        copy { $0.customIndicator = AnyView(content()) }
    }

    /// Append a required asterisk after the label text (via `InputLabel`).
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Render the label + description in the error color and unlock the
    /// `errorText(_:)` line.
    func hasError(_ on: Bool = true) -> Self { copy { $0.hasError = on } }

    /// Validation message rendered under the row — shown only while `hasError`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview("States") {
    struct Demo: View {
        @State var notifications = true
        @State var terms = false
        @State var remember = true
        @State var marketing = false
        @State var starred = true
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                ControlRow("Enable notifications", isOn: $notifications)
                    .description("Receive push notifications about your account activity.")
                ControlRow("I agree to the terms", isOn: $terms)
                    .control(.checkbox)
                    .description("By checking this box, you agree to our Terms of Service.")
                    .required()
                    .hasError(!terms)
                    .errorText("This field is required.")
                    .a11yID("terms")
                ControlRow("Remember me", isOn: $remember)
                    .control(.radio)
                ControlRow("Marketing emails", isOn: $marketing)
                    .description("Occasional product updates and offers.")
                    .disabled(true)
                ControlRow("Star this item", isOn: $starred)
                    .indicator {
                        Image(systemName: starred ? "star.fill" : "star")
                            .foregroundStyle(Theme.shared.foreground(.fgHero))
                    }
            }
            .padding()
        }
    }
    return Demo().environment(Theme.shared)
}

#Preview("Dark / themed") {
    struct Demo: View {
        @State var notifications = true
        @State var terms = false
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                ControlRow("Enable notifications", isOn: $notifications)
                    .description("Receive push notifications about your account activity.")
                ControlRow("I agree to the terms", isOn: $terms)
                    .control(.checkbox)
                    .required()
                    .hasError(!terms)
                    .errorText("This field is required.")
                ControlRow("Small control", isOn: $notifications)
                    .controlSize(.small)
            }
            .padding()
        }
    }
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return Demo()
        .background(dark.background(.bgBase))
        .theme(dark)
}
