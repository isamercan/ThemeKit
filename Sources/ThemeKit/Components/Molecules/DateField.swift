//
//  DateField.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// How the chosen date renders inside the field.
public enum DateFieldStyle: Equatable, Sendable {
    case numeric        // 1/5/2026
    case abbreviated    // Jan 5, 2026   (default)
    case long           // January 5, 2026
    case full           // Monday, January 5, 2026
    case relative       // today · tomorrow · Jan 5
    case custom(String) // Unicode date pattern, e.g. "EEE, d MMM"
}

/// Which components the field shows and the picker edits.
public enum DateFieldComponents {
    case date, dateAndTime, time
}

/// Molecule. A date input field that presents a theme-tinted graphical calendar
/// in a popover. (Form-field wrapper around the system date picker.)
/// Presentation mirrors TextInput's form chrome — info/error messages with a
/// matching border, an optional clear button, a disabled state, and a leading
/// icon. The displayed value is formatter-driven: pick a `DateFieldStyle` (or a
/// custom pattern), a `locale`, and which `components` (date / time) to show.
/// The field chrome (fill + border) is a swappable ``FieldStyle`` set with
/// `.fieldStyle(_:)`; the default reproduces the original look.
public struct DateField: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.fieldDefaults) private var fieldDefaults
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let label: String?
    @Binding private var date: Date?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholder: String { placeholderOverride ?? String(themeKit: "Select a date") }
    private var range: ClosedRange<Date>?
    private var style: DateFieldStyle = .abbreviated
    private var explicitLocale: Locale?
    private var components: DateFieldComponents = .date
    private var infoMessages: [InfoMessage] = []
    /// Set only by the `.clearable(_:)` modifier, so the subtree
    /// `FieldDefaults.clearable` can fill the default without overriding an
    /// explicit per-field choice (F5): `explicitClearable ?? fieldDefaults.clearable ?? false`.
    private var explicitClearable: Bool?
    private var leadingSystemImage: String?
    private var accessibilityID: String?
    /// `.required()` — asterisk on the label + ", required" in the a11y label.
    private var isRequired = false

    // Declarative validation (daisyUI Validator) — rules run against the
    // *displayed* date string at `effectiveValidationTrigger`; failures merge
    // into the rendered messages, driving the border state automatically.
    private var validationRules: [ValidationRule] = []
    /// Set only by an explicit `on:` argument to `validate(_:on:)`; `nil` falls
    /// back to `FieldDefaults.validationTrigger`, then `.editingEnd` (F5).
    private var explicitValidationTrigger: ValidationTrigger?
    private var onValidation: ((Bool) -> Void)?
    @State private var validationMessages: [InfoMessage] = []

    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`).
    /// DateField's focus analog is its picker popover: a `true` write opens the
    /// picker (`showPicker` already reads as `isFocused` in the `FieldStyle`
    /// configuration); dismissing it resets the binding.
    private var externalFocus: Binding<Bool>?
    /// Internal editing-end hook (form wiring): fires with the displayed value
    /// (empty when no date is set) when the picker is dismissed.
    private var onEditingEnd: ((String) -> Void)?

    @Environment(\.locale) private var environmentLocale
    @State private var showPicker = false

    public init(_ label: String? = nil, date: Binding<Date?>) {   // R1
        self.label = label
        self._date = date
    }

    // MARK: - Derived state

    private var locale: Locale { explicitLocale ?? environmentLocale }
    /// Explicit `infoMessages(_:)` plus any current `validate(_:on:)` failures.
    private var messages: [InfoMessage] { infoMessages + validationMessages }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    /// Explicit `.clearable(_:)` → subtree `FieldDefaults.clearable` → off (F5).
    private var effectiveClearable: Bool { explicitClearable ?? fieldDefaults.clearable ?? false }
    /// Explicit `on:` argument → subtree `FieldDefaults.validationTrigger` → `.editingEnd` (F5).
    private var effectiveValidationTrigger: ValidationTrigger {
        explicitValidationTrigger ?? fieldDefaults.validationTrigger ?? .editingEnd
    }
    private var showsClear: Bool { effectiveClearable && date != nil && isEnabled }
    private var displayText: String? {
        date.map { Self.text(for: $0, style: style, locale: locale, components: components) }
    }
    /// DateField has no `TextInputSize` modifier of its own; the subtree
    /// `FieldDefaults.size` maps onto its control height (nil keeps the
    /// component's classic scaled 48pt / nominal `.medium`).
    private var explicitSize: TextInputSize?
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    /// Message rows animate only when the subtree `FieldDefaults.messagesAnimated`
    /// opts in (DateField historically snaps) — still gated by `microAnimations`
    /// + Reduce Motion.
    private var messagesAnimated: Bool { micro && (fieldDefaults.messagesAnimated ?? false) }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    private var a11yLabel: String {
        // Fall back to a generic field name — never "" (which would blank the
        // control's name) and never the placeholder. The chosen date is carried
        // by accessibilityValue.
        let base = label ?? String(themeKit: "Date")
        return isRequired ? base + ", " + String(themeKit: "required") : base
    }

    /// Runs the declared rules over the displayed date string (first failure
    /// only, via `Validator`); publishes the result and reports validity.
    private func runValidation() {
        guard !validationRules.isEmpty else { return }
        let failures = Validator.validate(displayText ?? "", validationRules)
        if failures != validationMessages { validationMessages = failures }
        onValidation?(!failures.contains { $0.kind == .error })
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                InputLabel(label).required(isRequired && showsRequiredIndicator).hasError(hasError)
            }

            fieldBox
                .contentShape(Rectangle())
                .onTapGesture { if isEnabled { showPicker = true } }
                .popover(isPresented: $showPicker) { picker }
                .a11y(A11yElement.Select.trigger, in: accessibilityID)
                .accessibilityLabel(a11yLabel)
                .accessibilityValue(displayText ?? "")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if isEnabled { showPicker = true } }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        // Message rows animate only when `fieldDefaults(messagesAnimated: true)`
        // opts this field family in; `microAnimations` + Reduce Motion still win.
        .animation(MicroMotion.animation(.fast, enabled: messagesAnimated, reduceMotion: reduceMotion), value: messages)
        // `.live` validates every change; other triggers re-validate once a
        // failure is visible so the error clears as the user fixes it.
        .onChange(of: date) { _, _ in
            if effectiveValidationTrigger == .live || !validationMessages.isEmpty { runValidation() }
        }
        // External focus bridge (TextInput parity, popover-flavored): a `true`
        // write opens the picker; dismissing it resets the external binding.
        .onChange(of: externalFocus?.wrappedValue ?? false) { _, want in
            if want && !showPicker && isEnabled { showPicker = true }
        }
        // Dismissing the picker is this field's blur *and* submit moment.
        .onChange(of: showPicker) { _, now in
            if !now, externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
            if !now { onEditingEnd?(displayText ?? "") }   // form-wiring hook (`.field(_:in:)`)
            if !now, effectiveValidationTrigger != .live { runValidation() }
        }
    }

    /// The composed field row (icon + value + trailing accessory), sized —
    /// everything the active ``FieldStyle`` receives as `configuration.content`.
    private var fieldCore: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let leadingSystemImage {
                Icon(systemName: leadingSystemImage).size(.sm).color(iconColor)
            }
            Text(displayText ?? placeholder)
                .textStyle(.bodyBase400)
                .foregroundStyle(textColor)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .scaledControlHeight(effectiveSize?.height ?? 48)
        .frame(maxWidth: .infinity)
    }

    /// The field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: the open popover reads as `isFocused`; the dominant
    /// message kind drives `hasError` / `hasWarning`. `size` is nominal
    /// `.medium` — `DateField` has no `TextInputSize` axis; its height stays the
    /// component's own scaled 48pt, carried by the content — unless the subtree
    /// `FieldDefaults.size` remaps both the height and the reported preset.
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: showPicker,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize ?? .medium
        ))
    }

    @ViewBuilder
    private var trailing: some View {
        if showsClear {
            Button { date = nil } label: {
                Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel(String(themeKit: "Clear"))
        } else {
            Icon(systemName: components == .time ? "clock" : "calendar").size(.sm).color(iconColor)
        }
    }

    // MARK: - Picker

    private var pickerBinding: Binding<Date> {
        Binding(get: { date ?? .now }, set: { date = $0 })
    }

    private var pickerComponents: DatePickerComponents {
        switch components {
        case .date: return [.date]
        case .dateAndTime: return [.date, .hourAndMinute]
        case .time: return [.hourAndMinute]
        }
    }

    @ViewBuilder
    private var picker: some View {
        let content = Group {
            if let range {
                DatePicker("", selection: pickerBinding, in: range, displayedComponents: pickerComponents)
            } else {
                DatePicker("", selection: pickerBinding, displayedComponents: pickerComponents)
            }
        }
        VStack(spacing: Theme.SpacingKey.md.value) {
            content
                .datePickerStyle(.graphical)
                .environment(\.locale, locale)
                .tint(theme.foreground(.fgHero))
                .labelsHidden()
            PrimaryButton("Done") { showPicker = false }.fullWidth()
        }
        .padding()
        .frame(minWidth: 320)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Colors

    private var iconColor: Color {
        isEnabled ? theme.text(.textTertiary) : theme.text(.textDisabled)
    }

    private var textColor: Color {
        if !isEnabled { return theme.text(.textDisabled) }
        return date == nil ? theme.text(.textTertiary) : theme.text(.textPrimary)
    }

    // MARK: - Formatting

    /// Renders `date` per `style` / `locale` / `components`. Pure (extracted for
    /// testing) and `nonisolated` — a string formatter, callable off the main actor.
    nonisolated static func text(for date: Date, style: DateFieldStyle, locale: Locale, components: DateFieldComponents) -> String {
        switch style {
        case .relative:
            return date.formatted(.relative(presentation: .named).locale(locale))
        case .custom(let pattern):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        case .numeric, .abbreviated, .long, .full:
            let dateStyle: Date.FormatStyle.DateStyle
            switch style {
            case .numeric: dateStyle = .numeric
            case .long: dateStyle = .long
            case .full: dateStyle = .complete
            default: dateStyle = .abbreviated
            }
            let effectiveDate: Date.FormatStyle.DateStyle
            let time: Date.FormatStyle.TimeStyle
            switch components {
            case .date: (effectiveDate, time) = (dateStyle, .omitted)
            case .dateAndTime: (effectiveDate, time) = (dateStyle, .shortened)
            case .time: (effectiveDate, time) = (.omitted, .shortened)
            }
            return date.formatted(Date.FormatStyle(date: effectiveDate, time: time).locale(locale))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DateField {
    /// Placeholder shown while no date is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholderOverride = text } }

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default.
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Marks the field required: an error-token asterisk on the label (honoring
    /// `FieldDefaults.requiredIndicator`) and ", required" in the a11y label.
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Declarative validation (daisyUI Validator): `rules` run against the
    /// *displayed* date string (empty when no date is set) at `trigger` —
    /// `.editingEnd`/`.submit` fire when the picker is dismissed, `.live` on
    /// every change. Failures merge into the rendered messages and border state.
    /// Omitting `on:` follows the subtree `FieldDefaults.validationTrigger`
    /// default, then `.editingEnd` (F5); an explicit trigger always wins.
    ///
    ///     DateField("Check-in", date: $checkIn)
    ///         .validate([.required("Pick a check-in date")])
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger? = nil) -> Self {
        copy { $0.validationRules = rules; if let trigger { $0.explicitValidationTrigger = trigger } }
    }

    /// Reports validity after each `validate(_:on:)` pass — `true` when no
    /// error-severity failure is present.
    func onValidation(_ handler: @escaping (Bool) -> Void) -> Self { copy { $0.onValidation = handler } }

    /// Restrict the picker to a selectable date range.
    func range(_ range: ClosedRange<Date>?) -> Self { copy { $0.range = range } }

    /// How the chosen date renders in the field (numeric / abbreviated / long / full / relative / custom).
    func style(_ style: DateFieldStyle) -> Self { copy { $0.style = style } }

    /// Override the formatting locale (defaults to the environment locale).
    func locale(_ locale: Locale?) -> Self { copy { $0.explicitLocale = locale } }

    /// Which components the field shows and the picker edits (date / dateAndTime / time).
    func components(_ components: DateFieldComponents) -> Self { copy { $0.components = components } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Show a trailing clear button when a date is set. An explicit call wins
    /// over the subtree `FieldDefaults.clearable` default (F5).
    func clearable(_ on: Bool = true) -> Self { copy { $0.explicitClearable = on } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`). DateField's
    /// focus analog is its picker popover: a `true` write opens the picker (which
    /// also renders the `FieldStyle` focus border); dismissal resets the binding.
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Internal editing-end hook used by the form wiring (`.field(_:in:)`) to
    /// re-validate when the picker is dismissed. Fires with the displayed value
    /// (locale-formatted; empty when no date is set — pair with `.required()`-style rules).
    internal func onEditingEnd(_ handler: ((String) -> Void)?) -> Self { copy { $0.onEditingEnd = handler } }

    /// Leading SF Symbol shown inside the field.
    func icon(_ systemImage: String?) -> Self { copy { $0.leadingSystemImage = systemImage } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var checkIn: Date? = .now
        @State var meeting: Date?
        var body: some View {
            PreviewMatrix("DateField") {
                // Weekday-style display + clear + leading icon.
                PreviewCase("Custom pattern + clear + icon") {
                    DateField("Check-in", date: $checkIn)
                        .style(.custom("EEE, d MMM")).clearable().icon("calendar")
                }
                // Date + time, with a validation error.
                PreviewCase("Date + time · error") {
                    DateField("Meeting", date: $meeting)
                        .style(.long).components(.dateAndTime).clearable()
                        .infoMessages(meeting == nil ? [InfoMessage("Pick a time", kind: .error)] : [])
                }
                PreviewCase("Disabled") {
                    DateField("Locked", date: .constant(.now)).disabled(true)
                }
                // Required + declarative validation (asterisk, rules on dismiss).
                PreviewCase("Required + validation") {
                    DateField("Check-out", date: $meeting)
                        .required()
                        .validate([.required("Pick a check-out date")])
                }
                // Underlined chrome via the shared FieldStyle hook.
                PreviewCase("Underlined field style") {
                    DateField("Departure", date: $checkIn)
                        .icon("calendar")
                        .fieldStyle(.underlined)
                }
            }
        }
    }
    return Demo()
}
