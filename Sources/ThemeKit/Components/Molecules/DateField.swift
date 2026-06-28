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

    private let label: String?
    @Binding private var date: Date?
    private let placeholder: String
    private let range: ClosedRange<Date>?
    private let style: DateFieldStyle
    private let explicitLocale: Locale?
    private let components: DateFieldComponents
    private let infoMessages: [InfoMessage]
    private let allowClear: Bool
    private let isEnabled: Bool
    private let leadingSystemImage: String?
    private let accessibilityID: String?

    @Environment(\.locale) private var environmentLocale
    @State private var showPicker = false

    public init(
        label: String? = nil,
        date: Binding<Date?>,
        placeholder: String = String(themeKit: "Select a date"),
        range: ClosedRange<Date>? = nil,
        style: DateFieldStyle = .abbreviated,
        locale: Locale? = nil,
        components: DateFieldComponents = .date,
        infoMessages: [InfoMessage] = [],
        allowClear: Bool = false,
        isEnabled: Bool = true,
        leadingSystemImage: String? = nil,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self._date = date
        self.placeholder = placeholder
        self.range = range
        self.style = style
        self.explicitLocale = locale
        self.components = components
        self.infoMessages = infoMessages
        self.allowClear = allowClear
        self.isEnabled = isEnabled
        self.leadingSystemImage = leadingSystemImage
        self.accessibilityID = accessibilityID
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
            PrimaryButton("Tamam", block: true) { showPicker = false }
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

#Preview {
    struct Demo: View {
        @State var checkIn: Date? = .now
        @State var meeting: Date?
        var body: some View {
            VStack(spacing: 16) {
                // Weekday-style display + clear + leading icon.
                DateField(label: "Check-in", date: $checkIn, style: .custom("EEE, d MMM"),
                          allowClear: true, leadingSystemImage: "calendar")
                // Date + time, with a validation error.
                DateField(label: "Meeting", date: $meeting, style: .long, components: .dateAndTime,
                          infoMessages: meeting == nil ? [InfoMessage("Pick a time", kind: .error)] : [],
                          allowClear: true)
                // Disabled.
                DateField(label: "Locked", date: .constant(.now), isEnabled: false)
            }
            .padding()
        }
    }
    return Demo()
}
