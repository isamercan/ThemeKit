//
//  TimeField.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//

import SwiftUI

/// Which hour cycle the field's displayed time uses.
public enum TimeFieldHourCycle: Equatable, Sendable {
    case locale   // follow the locale (default) — e.g. 3:30 PM (en) / 15:30 (tr)
    case h12      // force 12-hour with an AM/PM marker
    case h24      // force 24-hour
}

/// Molecule. A time input field that presents a theme-tinted time picker in a
/// popover. The time-only counterpart to `DateField` (which can also show time via
/// `.components(.time)`, but `TimeField` is the dedicated, time-first control: an
/// `hourCycle` (12/24h), a `minuteInterval` step, and a clock-first chrome).
///
/// Presentation mirrors `DateField`/`TextInput` form chrome — info/error messages
/// with a matching border, an optional clear button, a disabled state, and a leading
/// icon. The field chrome (fill + border) is a swappable ``FieldStyle`` set with
/// `.fieldStyle(_:)`; the default reproduces the original look.
/// Per the modifier-based architecture the init takes only its label and the
/// `time` binding; every appearance/config axis is a chainable, order-free modifier.
///
///     TimeField("Meeting time", time: $time)
///         .minuteInterval(15).hourCycle(.h24).clearable()
///         .disabled(!editable)            // native — R3
public struct TimeField: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no editing.
    @Environment(\.isReadOnly) private var isReadOnly
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.fieldDefaults) private var fieldDefaults

    private let label: String?
    @Binding private var time: Date?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholder: String { placeholderOverride ?? String(themeKit: "Select a time") }
    private var range: ClosedRange<Date>?
    private var minuteInterval: Int = 1
    private var hourCycle: TimeFieldHourCycle = .locale
    private var explicitLocale: Locale?
    private var infoMessages: [InfoMessage] = []
    /// Set only by the `.clearable(_:)` modifier, so the subtree
    /// `FieldDefaults.clearable` can fill the default without overriding an
    /// explicit per-field choice (F5): `explicitClearable ?? fieldDefaults.clearable ?? false`.
    private var explicitClearable: Bool?
    private var leadingSystemImage: String? = "clock"
    private var accessibilityID: String?
    /// Explicit `.size(_:)` preset — wins over the subtree `FieldDefaults.size`.
    private var explicitSize: TextInputSize?
    /// `.required()` — asterisk on the label + ", required" in the a11y label.
    private var isRequired = false

    // Declarative validation (daisyUI Validator) — rules run against the
    // *displayed* time string at `effectiveValidationTrigger`; failures merge
    // into the rendered messages, driving the border state automatically.
    private var validationRules: [ValidationRule] = []
    /// Set only by an explicit `on:` argument to `validate(_:on:)`; `nil` falls
    /// back to `FieldDefaults.validationTrigger`, then `.editingEnd` (F5).
    private var explicitValidationTrigger: ValidationTrigger?
    private var onValidation: ((Bool) -> Void)?
    @State private var validationMessages: [InfoMessage] = []

    @Environment(\.locale) private var environmentLocale
    @State private var showPicker = false

    public init(_ label: String? = nil, time: Binding<Date?>) {   // R1
        self.label = label
        self._time = time
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
    private var showsClear: Bool { effectiveClearable && time != nil && isEnabled && !isReadOnly }
    private var displayText: String? {
        time.map { Self.text(for: $0, hourCycle: hourCycle, locale: locale) }
    }
    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → the classic scaled 48pt.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    private var a11yLabel: String {
        let base = label ?? String(themeKit: "Time")
        return isRequired ? base + ", " + String(themeKit: "required") : base
    }

    /// Runs the declared rules over the displayed time string (first failure
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
                // Read-only keeps the normal chrome + VoiceOver value but never
                // opens the picker (E1 — distinct from `.disabled`).
                .onTapGesture { if isEnabled && !isReadOnly { showPicker = true } }
                .allowsHitTesting(!isReadOnly)
                .popover(isPresented: $showPicker) { picker }
                .a11y(A11yElement.Select.trigger, in: accessibilityID)
                .accessibilityLabel(a11yLabel)
                .accessibilityValue(displayText ?? "")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if isEnabled && !isReadOnly { showPicker = true } }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        // `.live` validates every change; other triggers re-validate once a
        // failure is visible so the error clears as the user fixes it.
        .onChange(of: time) { _, _ in
            if effectiveValidationTrigger == .live || !validationMessages.isEmpty { runValidation() }
        }
        // Dismissing the picker is this field's blur *and* submit moment.
        .onChange(of: showPicker) { _, now in
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
    /// message kind drives `hasError` / `hasWarning`. With no explicit `.size(_:)`
    /// and no subtree `FieldDefaults.size` the height stays the component's
    /// classic scaled 48pt (nominal `.medium`), carried by the content.
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
            Button { time = nil } label: {
                Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel(String(themeKit: "Clear"))
        } else {
            Icon(systemName: "clock").size(.sm).color(iconColor)
        }
    }

    // MARK: - Picker

    private var pickerBinding: Binding<Date> {
        Binding(get: { time ?? .now }, set: { time = Self.rounded($0, toMinuteInterval: minuteInterval) })
    }

    @ViewBuilder
    private var picker: some View {
        let content = Group {
            if let range {
                DatePicker("", selection: pickerBinding, in: range, displayedComponents: [.hourAndMinute])
            } else {
                DatePicker("", selection: pickerBinding, displayedComponents: [.hourAndMinute])
            }
        }
        VStack(spacing: Theme.SpacingKey.md.value) {
            content
                .datePickerStyle(.graphical)
                .environment(\.locale, pickerLocale)
                .tint(theme.foreground(.fgHero))
                .labelsHidden()
            PrimaryButton("Done") { showPicker = false }.fullWidth()
        }
        .padding()
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }

    /// The picker's locale: forced hour cycles override the locale's so the wheel
    /// shows the requested 12/24-hour layout.
    private var pickerLocale: Locale {
        switch hourCycle {
        case .locale: return locale
        case .h12: return Self.locale(locale, forcingHourCycle: "h12")
        case .h24: return Self.locale(locale, forcingHourCycle: "h23")
        }
    }

    // MARK: - Colors

    private var iconColor: Color { isEnabled ? theme.text(.textTertiary) : theme.text(.textDisabled) }

    private var textColor: Color {
        if !isEnabled { return theme.text(.textDisabled) }
        return time == nil ? theme.text(.textTertiary) : theme.text(.textPrimary)
    }

    // MARK: - Formatting & helpers (pure, extracted for testing)

    /// Renders `date`'s time-of-day per `hourCycle` / `locale`. Pure and
    /// `nonisolated` — a string formatter, callable off the main actor.
    nonisolated static func text(for date: Date, hourCycle: TimeFieldHourCycle, locale: Locale) -> String {
        switch hourCycle {
        case .locale:
            return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        case .h12:
            return fixedFormat(date, pattern: "h:mm a", locale: locale)
        case .h24:
            return fixedFormat(date, pattern: "HH:mm", locale: locale)
        }
    }

    nonisolated private static func fixedFormat(_ date: Date, pattern: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Rounds `date`'s minute to the nearest `interval` (≥ 2), carrying into the
    /// hour on overflow. `interval <= 1` returns the date unchanged.
    nonisolated static func rounded(_ date: Date, toMinuteInterval interval: Int) -> Date {
        guard interval > 1 else { return date }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let snapped = Int((Double(minute) / Double(interval)).rounded()) * interval
        comps.hour = (comps.hour ?? 0) + snapped / 60
        comps.minute = snapped % 60
        return cal.date(from: comps) ?? date
    }

    /// A copy of `base` with its hour-cycle forced via a Unicode `hc` extension
    /// (`h12` / `h23`), so a forced 12/24-hour picker doesn't fight the locale.
    nonisolated private static func locale(_ base: Locale, forcingHourCycle hc: String) -> Locale {
        var ids = base.identifier.components(separatedBy: "@")
        let head = ids.first ?? base.identifier
        return Locale(identifier: "\(head)@hours=\(hc)")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TimeField {
    /// Placeholder shown while no time is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholderOverride = text } }

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? 48pt`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Marks the field required: an error-token asterisk on the label (honoring
    /// `FieldDefaults.requiredIndicator`) and ", required" in the a11y label.
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Declarative validation (daisyUI Validator): `rules` run against the
    /// *displayed* time string (empty when no time is set) at `trigger` —
    /// `.editingEnd`/`.submit` fire when the picker is dismissed, `.live` on
    /// every change. Failures merge into the rendered messages and border state.
    /// Omitting `on:` follows the subtree `FieldDefaults.validationTrigger`
    /// default, then `.editingEnd` (F5); an explicit trigger always wins.
    ///
    ///     TimeField("Alarm", time: $alarm)
    ///         .validate([.required("Pick a time")])
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger? = nil) -> Self {
        copy { $0.validationRules = rules; if let trigger { $0.explicitValidationTrigger = trigger } }
    }

    /// Reports validity after each `validate(_:on:)` pass — `true` when no
    /// error-severity failure is present.
    func onValidation(_ handler: @escaping (Bool) -> Void) -> Self { copy { $0.onValidation = handler } }

    /// Restrict the picker to a selectable time range.
    func range(_ range: ClosedRange<Date>?) -> Self { copy { $0.range = range } }

    /// Snap the selected minute to the nearest multiple of `minutes` (e.g. 5 / 15 / 30).
    func minuteInterval(_ minutes: Int) -> Self { copy { $0.minuteInterval = max(1, minutes) } }

    /// Force the displayed hour cycle (12 / 24-hour) or follow the locale (default).
    func hourCycle(_ cycle: TimeFieldHourCycle) -> Self { copy { $0.hourCycle = cycle } }

    /// Override the formatting locale (defaults to the environment locale).
    func locale(_ locale: Locale?) -> Self { copy { $0.explicitLocale = locale } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Show a trailing clear button when a time is set. An explicit call wins
    /// over the subtree `FieldDefaults.clearable` default (F5).
    func clearable(_ on: Bool = true) -> Self { copy { $0.explicitClearable = on } }

    /// Leading SF Symbol shown inside the field (defaults to `clock`; pass `nil` to hide).
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
    @Previewable @State var meeting: Date? = .now
    @Previewable @State var alarm: Date?
    PreviewMatrix("TimeField") {
        // 15-minute steps, 24-hour, clearable.
        PreviewCase("15-min · 24h · clearable") {
            TimeField("Meeting time", time: $meeting)
                .minuteInterval(15).hourCycle(.h24).clearable()
        }
        // 12-hour with a validation error while empty.
        PreviewCase("12h + error while empty") {
            TimeField("Alarm", time: $alarm)
                .hourCycle(.h12).clearable()
                .infoMessages(alarm == nil ? [InfoMessage("Pick a time", kind: .error)] : [])
        }
        PreviewCase("Disabled") { TimeField("Locked", time: .constant(.now)).disabled(true) }
        // Read-only: normal chrome + VoiceOver value, no picker/clear (E1).
        PreviewCase("Read-only") { TimeField("Departure (read-only)", time: .constant(.now)).clearable().readOnly() }
        // Required + declarative validation (asterisk, rules on dismiss).
        PreviewCase("Required + validate") {
            TimeField("Check-in", time: $alarm)
                .required()
                .validate([.required("Pick a check-in time")])
        }
        // Size ramp — explicit `.size(_:)` wins over `FieldDefaults.size`.
        PreviewCase("Size ramp") {
            VStack(spacing: 12) {
                TimeField("Small", time: $meeting).size(.small)
                TimeField("Large", time: $meeting).size(.large)
            }
        }
        // Underlined chrome via the shared FieldStyle hook.
        PreviewCase("Underlined") {
            TimeField("Boarding", time: $meeting)
                .hourCycle(.h24)
                .fieldStyle(.underlined)
        }
    }
}
