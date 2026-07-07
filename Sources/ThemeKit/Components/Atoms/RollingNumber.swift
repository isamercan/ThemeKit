//
//  RollingNumber.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Odometer / slot-machine number — each digit column rolls vertically to its
/// new value when `value` changes (reference `RollingText`). Good for prices,
/// counters, live stats.
public struct RollingNumber: View {
    // Appearance — mutated only through the modifiers below (R2).
    private var size: CGFloat = 28
    private var weight: Font.Weight = .bold
    private var color: Color?

    private let value: Int

    @Environment(\.theme) private var theme

    public init(_ value: Int) {   // R1
        self.value = value
    }

    private var digits: [Int] { String(abs(value)).compactMap(\.wholeNumberValue) }

    public var body: some View {
        HStack(spacing: 0) {
            if value < 0 { Text("-").rollingFont(size, weight, color ?? theme.text(.textPrimary)) }
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                DigitColumn(digit: digit, size: size, weight: weight, color: color)
            }
        }
        // VoiceOver reads the value, not the 0-9 digit skeleton behind the roll.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.formatted())
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RollingNumber {
    /// Digit point size.
    func size(_ s: CGFloat) -> Self { copy { $0.size = s } }

    /// Font weight of the rolling digits.
    func weight(_ w: Font.Weight) -> Self { copy { $0.weight = w } }

    /// Semantic digit color; `nil` (default) uses `textPrimary`.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.color = color?.base } }

    /// Raw digit color override (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: Color?) -> Self { copy { $0.color = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

private struct DigitColumn: View {
    let digit: Int
    let size: CGFloat
    let weight: Font.Weight
    let color: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.microAnimations) private var micro
    @Environment(\.theme) private var theme

    private var rowHeight: CGFloat { size * 1.25 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0...9, id: \.self) { n in
                Text("\(n)").rollingFont(size, weight, color ?? theme.text(.textPrimary)).frame(height: rowHeight)
            }
        }
        .offset(y: -CGFloat(digit) * rowHeight)
        .frame(height: rowHeight, alignment: .top)
        .clipped()
        // Honor the micro-animations switch + Reduce Motion: snap instead of rolling.
        .animation((micro && !reduceMotion) ? Motion.base.spring : nil, value: digit)
    }
}

private extension Text {
    func rollingFont(_ size: CGFloat, _ weight: Font.Weight, _ color: Color) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
    }
}

#Preview {
    struct Demo: View {
        @State var n = 1234
        var body: some View {
            VStack(spacing: 20) {
                RollingNumber(n).size(40)
                Button("Roll") { n = Int.random(in: 100...99999) }
            }
            .padding()
        }
    }
    return Demo()
}
