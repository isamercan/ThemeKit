//
//  StepperRow.swift
//  ThemeKit
//
//  Molecule. A labelled counter row — a title (+ optional subtitle / icon) on the
//  left and a circular − / + stepper on the right, bounded by a range. The building
//  block of a passenger / room / quantity selector. Token-bound.
//
//  ```swift
//  StepperRow("Adult", value: $adults).subtitle("+12 yrs").range(1...9)
//  ```
//

import SwiftUI

public struct StepperRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let label: String
    @Binding private var value: Int
    // Appearance/config — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var range: ClosedRange<Int> = 0...9
    private var step = 1
    private var systemImage: String?
    private var accent: SemanticColor?

    public init(_ label: String, value: Binding<Int>) {   // R1
        self.label = label
        self._value = value
    }

    private var accentBase: Color { theme.resolve(accent ?? .primary).base }

    public var body: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 16)).foregroundStyle(theme.text(.textSecondary)).frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
            }
            Spacer(minLength: 8)
            stepper
        }
        .frame(minHeight: 44)
    }

    private var stepper: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            circleButton("minus", enabled: value > range.lowerBound) { value = max(range.lowerBound, value - step) }
            Text("\(value)").textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 24).monospacedDigit()
            circleButton("plus", enabled: value < range.upperBound) { value = min(range.upperBound, value + step) }
        }
    }

    private func circleButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? accentBase : theme.text(.textDisabled))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(enabled ? accentBase : theme.border(.borderPrimary), lineWidth: 1.5))
                .frame(width: 44, height: 44)          // 44pt tap target (visual stays 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(icon == "minus" ? String(themeKit: "Decrease \(label)") : String(themeKit: "Increase \(label)"))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension StepperRow {
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func range(_ range: ClosedRange<Int>) -> Self { copy { $0.range = range } }
    func step(_ value: Int) -> Self { copy { $0.step = max(1, value) } }
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var adults = 2
        @State var children = 1
        @State var babies = 0
        var body: some View {
            PreviewMatrix("StepperRow") {
                PreviewCase("Default") { StepperRow("Adult", value: $adults).subtitle("+12 yrs").range(1...9) }
                PreviewCase("Zero floor") { StepperRow("Child", value: $children).subtitle("2–11 yrs").range(0...8) }
                PreviewCase("Icon + accent") { StepperRow("Infant", value: $babies).subtitle("0–2 yrs").range(0...4).icon("figure.child").accent(.success) }
                PreviewCase("Disabled") { StepperRow("Locked", value: .constant(1)).disabled(true) }
            }
        }
    }
    return Demo()
}
