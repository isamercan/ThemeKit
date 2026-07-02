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
    }
}

/// Organisms. Card-shaped selectable controls (radio / checkbox) — selected
/// state raises a hero border + tinted surface. State owned by the caller.
public struct RadioCard: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    // Appearance/config — mutated only through the modifiers below (R2).
    private var description: String? = nil

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {   // R1
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        SelectionCard(title: title, description: description, isSelected: isSelected, action: action) {
            RadioButton(isSelected: .constant(isSelected))
        }
    }
}

public struct CheckboxCard: View {
    private let title: String
    private let isChecked: Bool
    private let action: () -> Void

    // Appearance/config — mutated only through the modifiers below (R2).
    private var description: String? = nil

    public init(_ title: String, isChecked: Bool, action: @escaping () -> Void) {   // R1
        self.title = title
        self.isChecked = isChecked
        self.action = action
    }

    public var body: some View {
        SelectionCard(title: title, description: description, isSelected: isChecked, action: action) {
            Checkbox(isChecked: .constant(isChecked))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RadioCard {
    /// Secondary description line under the title.
    func description(_ text: String?) -> Self { copy { $0.description = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension CheckboxCard {
    /// Secondary description line under the title.
    func description(_ text: String?) -> Self { copy { $0.description = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var radio = "std"
        @State var bag = true
        var body: some View {
            VStack(spacing: 12) {
                RadioCard("Standard", isSelected: radio == "std") { radio = "std" }
                    .description("Free delivery in 3–5 days")
                RadioCard("Express", isSelected: radio == "exp") { radio = "exp" }
                    .description("Next-day delivery")
                CheckboxCard("Add checked bag", isChecked: bag) { bag.toggle() }
                    .description("+$250")
            }
            .padding()
        }
    }
    return Demo()
}
