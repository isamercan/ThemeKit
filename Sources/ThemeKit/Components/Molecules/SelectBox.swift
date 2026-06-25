//
//  SelectBox.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A form-style dropdown field (label above, chevron, hint / error,
//  default / focused / error / disabled states). Covers Figma SelectBox /
//  Combobox / DropDown field. Single-select via native Menu.
//

import SwiftUI

public struct SelectBox<Option: Hashable>: View {
    private let label: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let optionTitle: (Option) -> String
    private let placeholder: String
    private let hint: String?
    private let errorText: String?
    private let accessibilityID: String?
    private let isEnabled: Bool

    public init(
        label: String? = nil,
        options: [Option],
        selection: Binding<Option?>,
        placeholder: String = String(themeKit: "Select"),
        hint: String? = nil,
        errorText: String? = nil,
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.placeholder = placeholder
        self.hint = hint
        self.errorText = errorText
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.optionTitle = optionTitle
    }

    private var hasError: Bool { errorText != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                HStack(spacing: 4) {
                    Text(label).textStyle(.labelSm600).foregroundStyle(labelColor)
                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(Theme.shared.text(.textTertiary))
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
                HStack {
                    Text(selection.map(optionTitle) ?? placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(selection == nil ? Theme.shared.text(.textTertiary) : Theme.shared.text(.textPrimary))
                    Spacer(minLength: 0)
                    Icon(systemName: "chevron.down", size: .sm, color: Theme.shared.text(.textTertiary))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(48)
                .frame(maxWidth: .infinity)
                .background(Theme.shared.background(isEnabled ? .bgWhite : .bgSecondaryLight),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: hasError ? 1.5 : 1)
                )
            }
            .disabled(!isEnabled)
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(selection.map(optionTitle) ?? "")

            if let message = errorText ?? hint {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(hasError ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textTertiary))
            }
        }
    }

    private var labelColor: Color {
        hasError ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary)
    }
    private var borderColor: Color {
        hasError ? Theme.shared.border(.systemcolorsBorderError) : Theme.shared.border(.borderPrimary)
    }
}

#Preview {
    struct Demo: View {
        @State var country: String?
        var body: some View {
            VStack(spacing: 16) {
                SelectBox(label: "Country", options: ["Türkiye", "Germany", "France"], selection: $country, hint: "Pick your country") { $0 }
                SelectBox(label: "City", options: ["A", "B"], selection: .constant(nil), errorText: "Required") { $0 }
            }
            .padding()
        }
    }
    return Demo()
}
