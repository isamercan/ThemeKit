//
//  SelectBox.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A form-style dropdown field (label above, chevron, hint / error,
/// default / focused / error / disabled states). Covers Figma SelectBox /
/// Combobox / DropDown field. Single-select via native Menu.
public struct SelectBox<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    private let label: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let optionTitle: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholder: String { placeholderOverride ?? String(themeKit: "Select") }
    private var hint: String? = nil
    private var errorText: String? = nil
    private var infoMessages: [InfoMessage] = []
    private var accessibilityID: String? = nil
    /// Set only by the `.size(_:)` modifier — an explicit size wins over the
    /// subtree `FieldDefaults.size` default (`explicitSize ?? fieldDefaults.size`;
    /// with neither set, the field keeps its original 48pt height). C1.
    private var explicitSize: TextInputSize?
    /// Marks the field as required: asterisk after the label + ", required"
    /// appended to the accessibility label (E2, HeroUI `isRequired`).
    private var isRequired = false
    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`).
    /// The native `Menu` cannot be opened programmatically, so a `true` write
    /// renders the `FieldStyle` focus border (drawing the eye to the field);
    /// picking an option resets the binding.
    private var externalFocus: Binding<Bool>?
    /// Internal editing-end hook (form wiring): fires with the selected option's
    /// title (empty when nothing is selected) when the selection changes.
    private var onEditingEnd: ((String) -> Void)?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — set by `.readOnly(_:)`
    @Environment(\.fieldDefaults) private var fieldDefaults

    public init(   // R1
        _ label: String? = nil,
        options: [Option],
        selection: Binding<Option?>,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.optionTitle = optionTitle
    }

    /// `infoMessages` plus the `errorText` convenience (computed merge, same
    /// idiom as `TextInput`). Structured messages render as an `InfoMessageList`;
    /// with none set, the legacy single hint/error line renders unchanged.
    private var messages: [InfoMessage] {
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        return messages
    }
    private var hasError: Bool { messages.dominantKind == .error }
    private var hasWarning: Bool { messages.dominantKind == .warning }

    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → `nil` (the field's
    /// own 48pt default height, kept for source-visual compatibility).
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                HStack(spacing: 4) {
                    Text(label).textStyle(.labelSm600).foregroundStyle(labelColor)
                    if isRequired && showsRequiredIndicator {
                        // Same treatment as `InputLabel.required()` — error-token asterisk.
                        Text(verbatim: "*")
                            .textStyle(.labelSm600)
                            .foregroundStyle(theme.foreground(.systemcolorsFgError))
                            .accessibilityHidden(true)   // spoken via the trigger's label suffix
                    }
                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(theme.text(.textTertiary))
                }
            }

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if selection == option {
                            Label(optionTitle(option), systemImage: "checkmark")
                        } else {
                            Text(optionTitle(option))
                        }
                    }
                }
            } label: {
                fieldBox
            }
            .disabled(!isEnabled)
            // E1 — read-only keeps the normal (non-dimmed) chrome + value +
            // VoiceOver value, but the menu can't be opened. NOT `.disabled` (dims).
            .allowsHitTesting(!isReadOnly)
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            .accessibilityLabel(isRequired ? (label ?? "") + ", " + String(themeKit: "required") : (label ?? ""))
            .accessibilityValue(selection.map(optionTitle) ?? "")

            if !infoMessages.isEmpty {
                // Structured messages (e.g. from `.field(_:in:)`) — family-standard list.
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            } else if let message = errorText ?? hint {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
            }
        }
        // Selection = editing end: sync the external focus off and fire the
        // form-wiring hook (`.field(_:in:)`) with the chosen option's title.
        .onChange(of: selection) { _, newValue in
            if externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
            onEditingEnd?(newValue.map(optionTitle) ?? "")
        }
    }

    /// The composed trigger row — everything a `FieldStyle` receives as
    /// `configuration.content`. The control height lives here (the family
    /// `TextInputSize` ramp when a `.size(_:)` / `FieldDefaults.size` is set,
    /// the original 48pt otherwise), so the style only supplies the surface
    /// (fill + border + corner).
    private var fieldContent: some View {
        HStack {
            Text(selection.map(optionTitle) ?? placeholder)
                .textStyle(.bodyBase400)
                .foregroundStyle(selection == nil ? theme.text(.textTertiary) : theme.text(.textPrimary))
            Spacer(minLength: 0)
            Icon(systemName: "chevron.down").size(.sm).color(theme.text(.textTertiary))
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .scaledControlHeight(effectiveSize?.height ?? 48)   // C1 — family size ramp
        .frame(maxWidth: .infinity)
    }

    /// The trigger wrapped in the active ``FieldStyle`` chrome. Configuration
    /// mapping: the native `Menu` exposes no open state, so `isFocused` reflects
    /// only the external focus binding (a `FormValidator` focusing this field
    /// renders the focus border; user taps draw no ring, as before); `hasWarning`
    /// follows the dominant message severity; and `size` reports the resolved
    /// `TextInputSize` axis (`.medium` while unset — advisory for styles that
    /// key off it; the row then keeps its own 48pt height).
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldContent),
            isFocused: externalFocus?.wrappedValue ?? false,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize ?? .medium
        ))
    }

    private var labelColor: Color {
        hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SelectBox {
    /// Placeholder shown while no option is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholderOverride = text } }

    /// Control height on the field family's `TextInputSize` ramp (C1). An
    /// explicit size wins over the subtree `FieldDefaults.size` default; with
    /// neither set the field keeps its original 48pt height.
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Marks the field as required: renders an error-token asterisk after the
    /// label (the `InputLabel` treatment, honoring the subtree
    /// `FieldDefaults.requiredIndicator`) and appends ", required" to the
    /// trigger's accessibility label (E2, HeroUI `isRequired`).
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Helper text rendered under the field (hidden while an error is shown).
    func hint(_ text: String?) -> Self { copy { $0.hint = text } }

    /// Error message rendered under the field (drives the error border / label color).
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Validation / info messages rendered under the field as an
    /// `InfoMessageList` (their dominant severity drives the `FieldStyle`
    /// error / warning border, as in `TextInput`). With none set, the legacy
    /// `hint` / `errorText` single line renders unchanged.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`). The native
    /// `Menu` cannot be opened programmatically, so a `true` write renders the
    /// `FieldStyle` focus border instead; picking an option resets the binding.
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Internal editing-end hook used by the form wiring (`.field(_:in:)`) to
    /// re-validate when the selection changes. Fires with the chosen option's
    /// title (empty when nothing is selected).
    internal func onEditingEnd(_ handler: ((String) -> Void)?) -> Self { copy { $0.onEditingEnd = handler } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var country: String?
    PreviewMatrix("SelectBox") {
        PreviewCase("Hint") {
            SelectBox("Country", options: ["Turkey", "Germany", "France"], selection: $country) { $0 }
                .hint("Pick your country")
        }
        PreviewCase("Error") {
            SelectBox("City", options: ["A", "B"], selection: .constant(nil)) { $0 }
                .errorText("Required")
        }
        // Chrome via the shared FieldStyle axis.
        PreviewCase("Underlined") {
            SelectBox("Underlined", options: ["Turkey", "Germany"], selection: $country) { $0 }
                .fieldStyle(.underlined)
        }
        // Family size ramp (C1) — aligns with a `.small` TextInput beside it.
        PreviewCase("Compact (C1)") {
            SelectBox("Compact", options: ["Turkey", "Germany"], selection: $country) { $0 }
                .size(.small)
        }
        // Required indicator (E2) — asterisk + ", required" for VoiceOver.
        PreviewCase("Required (E2)") {
            SelectBox("Region", options: ["EMEA", "APAC"], selection: $country) { $0 }
                .required()
        }
        // Read-only (E1): normal chrome + value, menu blocked.
        PreviewCase("Read-only (E1)") {
            SelectBox("Country (submitted)", options: ["Turkey", "Germany"], selection: .constant("Turkey")) { $0 }
                .readOnly()
        }
    }
}
