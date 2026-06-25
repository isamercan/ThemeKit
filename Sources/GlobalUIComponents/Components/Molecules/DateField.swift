//
//  DateField.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A date input field that presents a theme-tinted graphical calendar
//  in a popover. (Form-field wrapper around the system date picker.)
//

import SwiftUI

public struct DateField: View {
    private let label: String?
    @Binding private var date: Date?
    private let placeholder: String
    private let range: ClosedRange<Date>?
    private let accessibilityID: String?

    @State private var showPicker = false

    public init(
        label: String? = nil,
        date: Binding<Date?>,
        placeholder: String = String(globalUIComponents: "Select a date"),
        range: ClosedRange<Date>? = nil,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self._date = date
        self.placeholder = placeholder
        self.range = range
        self.accessibilityID = accessibilityID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label, hasInfo: true) }

            Button { showPicker = true } label: {
                HStack {
                    Text(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(date == nil ? Theme.shared.text(.textTertiary) : Theme.shared.text(.textPrimary))
                    Spacer(minLength: 0)
                    Icon(systemName: "calendar", size: .sm, color: Theme.shared.text(.textTertiary))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(48)
                .frame(maxWidth: .infinity)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker) { picker }
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            // Fall back to the placeholder (never an empty string, which would
            // blank the control's name) so the trigger always has a spoken name.
            .accessibilityLabel(label ?? placeholder)
            .accessibilityValue(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "")
        }
    }

    private var pickerBinding: Binding<Date> {
        Binding(get: { date ?? .now }, set: { date = $0 })
    }

    @ViewBuilder
    private var picker: some View {
        let content = Group {
            if let range {
                DatePicker("", selection: pickerBinding, in: range, displayedComponents: .date)
            } else {
                DatePicker("", selection: pickerBinding, displayedComponents: .date)
            }
        }
        VStack(spacing: Theme.SpacingKey.md.value) {
            content
                .datePickerStyle(.graphical)
                .tint(Theme.shared.foreground(.fgHero))
                .labelsHidden()
            PrimaryButton("Tamam", isContentWidth: true) { showPicker = false }
        }
        .padding()
        .frame(minWidth: 320)
        .presentationCompactAdaptation(.popover)
    }
}

#Preview {
    struct Demo: View {
        @State var date: Date?
        var body: some View {
            DateField(label: "Check-in", date: $date).padding()
        }
    }
    return Demo()
}
