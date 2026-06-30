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
/// icon. Per the modifier-based architecture the init takes only its label and the
/// `time` binding; every appearance/config axis is a chainable, order-free modifier.
///
///     TimeField("Meeting time", time: $time)
///         .minuteInterval(15).hourCycle(.h24).clearable()
///         .disabled(!editable)            // native — R3
public struct TimeField: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    private let label: String?
    @Binding private var time: Date?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholder: String = String(themeKit: "Select a time")
    private var range: ClosedRange<Date>?
    private var minuteInterval: Int = 1
    private var hourCycle: TimeFieldHourCycle = .locale
    private var explicitLocale: Locale?
    private var infoMessages: [InfoMessage] = []
    private var allowClear = false
    private var leadingSystemImage: String? = "clock"
    private var accessibilityID: String?

    @Environment(\.locale) private var environmentLocale
    @State private var showPicker = false

    public init(_ label: String? = nil, time: Binding<Date?>) {   // R1
        self.label = label
        self._time = time
    }

    // MARK: - Derived state

    private var locale: Locale { explicitLocale ?? environmentLocale }
    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    private var showsClear: Bool { allowClear && time != nil && isEnabled }
    private var displayText: String? {
        time.map { Self.text(for: $0, hourCycle: hourCycle, locale: locale) }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label).hasError(hasError) }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let leadingSystemImage {
                    Icon(systemName: leadingSystemImage, size: .sm, color: iconColor)
                }
                Text(displayText ?? placeholder)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(textColor)
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(48)
            .frame(maxWidth: .infinity)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: showPicker || hasError || hasWarning ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { showPicker = true } }
            .popover(isPresented: $showPicker) { picker }
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            .accessibilityLabel(label ?? String(themeKit: "Time"))
            .accessibilityValue(displayText ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if isEnabled { showPicker = true } }

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if showsClear {
            Button { time = nil } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel(String(themeKit: "Clear"))
        } else {
            Icon(systemName: "clock", size: .sm, color: iconColor)
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
            PrimaryButton("Done", block: true) { showPicker = false }
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

    private var backgroundColor: Color { theme.background(isEnabled ? .bgWhite : .bgSecondaryLight) }

    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if showPicker { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
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
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

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

    /// Show a trailing clear button when a time is set.
    func clearable(_ on: Bool = true) -> Self { copy { $0.allowClear = on } }

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
    struct Demo: View {
        @State var meeting: Date? = .now
        @State var alarm: Date?
        var body: some View {
            VStack(spacing: 16) {
                // 15-minute steps, 24-hour, clearable.
                TimeField("Meeting time", time: $meeting)
                    .minuteInterval(15).hourCycle(.h24).clearable()
                // 12-hour with a validation error while empty.
                TimeField("Alarm", time: $alarm)
                    .hourCycle(.h12).clearable()
                    .infoMessages(alarm == nil ? [InfoMessage("Pick a time", kind: .error)] : [])
                // Disabled.
                TimeField("Locked", time: .constant(.now)).disabled(true)
            }
            .padding()
        }
    }
    return Demo()
}
