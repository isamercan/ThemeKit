//
//  SelectionCards.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

private struct SelectionCard<Control: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    let description: String?
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    let control: () -> Control

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                control()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.text(.textPrimary))
                    if let description {
                        Text(description)
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.SpacingKey.md.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.background(.bgElevatorTertiary) : theme.background(.bgWhite),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Organisms. Card-shaped selectable controls (radio / checkbox) — selected
/// state raises a hero border + tinted surface. State owned by the caller.
public struct RadioCard: View {
    private let title: String
    private let description: String?
    private let isSelected: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(_ title: String, description: String? = nil, isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        SelectionCard(title: title, description: description, isSelected: isSelected, isEnabled: isEnabled, action: action) {
            RadioButton(isSelected: .constant(isSelected))
        }
    }
}

public struct CheckboxCard: View {
    private let title: String
    private let description: String?
    private let isChecked: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(_ title: String, description: String? = nil, isChecked: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        SelectionCard(title: title, description: description, isSelected: isChecked, isEnabled: isEnabled, action: action) {
            Checkbox(isChecked: .constant(isChecked))
        }
    }
}

#Preview {
    struct Demo: View {
        @State var radio = "std"
        @State var bag = true
        var body: some View {
            VStack(spacing: 12) {
                RadioCard("Standard", description: "Free delivery in 3–5 days", isSelected: radio == "std") { radio = "std" }
                RadioCard("Express", description: "Next-day delivery", isSelected: radio == "exp") { radio = "exp" }
                CheckboxCard("Add checked bag", description: "+₺250", isChecked: bag) { bag.toggle() }
            }
            .padding()
        }
    }
    return Demo()
}
