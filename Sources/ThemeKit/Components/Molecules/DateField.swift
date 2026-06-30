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
public struct DateField: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    private let label: String?
    @Binding private var date: Date?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholder: String = String(themeKit: "Select a date")
    private var range: ClosedRange<Date>?
    private var style: DateFieldStyle = .abbreviated
    private var explicitLocale: Locale?
    private var components: DateFieldComponents = .date
    private var infoMessages: [InfoMessage] = []
    private var allowClear = false
    private var leadingSystemImage: String?
    private var accessibilityID: String?

    @Environment(\.locale) private var environmentLocale
    @State private var showPicker = false

    public init(_ label: String? = nil, date: Binding<Date?>) {   // R1
        self.label = label
        self._date = date
    }

    // MARK: - Derived state

    private var locale: Locale { explicitLocale ?? environmentLocale }
    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    private var showsClear: Bool { allowClear && date != nil && isEnabled }
    private var displayText: String? {
        date.map { Self.text(for: $0, style: style, locale: locale, components: components) }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label, hasError: hasError) }

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
            // Fall back to a generic field name — never "" (which would blank the
            // control's name) and never the placeholder. The chosen date is carried
            // by accessibilityValue.
            .accessibilityLabel(label ?? String(themeKit: "Date"))
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
            Button { date = nil } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel(String(themeKit: "Clear"))
        } else {
            Icon(systemName: components == .time ? "clock" : "calendar", size: .sm, color: iconColor)
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
            PrimaryButton("Done", block: true) { showPicker = false }
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

    private var backgroundColor: Color {
        theme.background(isEnabled ? .bgWhite : .bgSecondaryLight)
    }

    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if showPicker { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
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
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

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

    /// Show a trailing clear button when a date is set.
    func clearable(_ on: Bool = true) -> Self { copy { $0.allowClear = on } }

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
            VStack(spacing: 16) {
                // Weekday-style display + clear + leading icon.
                DateField("Check-in", date: $checkIn)
                    .style(.custom("EEE, d MMM")).clearable().icon("calendar")
                // Date + time, with a validation error.
                DateField("Meeting", date: $meeting)
                    .style(.long).components(.dateAndTime).clearable()
                    .infoMessages(meeting == nil ? [InfoMessage("Pick a time", kind: .error)] : [])
                // Disabled.
                DateField("Locked", date: .constant(.now)).disabled(true)
            }
            .padding()
        }
    }
    return Demo()
}
