//
//  RollingNumber.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Odometer / slot-machine number — each digit column rolls vertically to its
//  new value when `value` changes (reference `RollingText`). Good for prices,
//  counters, live stats.
//

import SwiftUI

public struct RollingNumber: View {
    private let value: Int
    private let size: CGFloat
    private let weight: Font.Weight
    private let color: Color?

    public init(_ value: Int, size: CGFloat = 28, weight: Font.Weight = .bold, color: Color? = nil) {
        self.value = value
        self.size = size
        self.weight = weight
        self.color = color
    }

    private var digits: [Int] { String(abs(value)).compactMap(\.wholeNumberValue) }

    public var body: some View {
        HStack(spacing: 0) {
            if value < 0 { Text("-").rollingFont(size, weight, color) }
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                DigitColumn(digit: digit, size: size, weight: weight, color: color)
            }
        }
    }
}

private struct DigitColumn: View {
    let digit: Int
    let size: CGFloat
    let weight: Font.Weight
    let color: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.microAnimations) private var micro

    private var rowHeight: CGFloat { size * 1.25 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0...9, id: \.self) { n in
                Text("\(n)").rollingFont(size, weight, color).frame(height: rowHeight)
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
    func rollingFont(_ size: CGFloat, _ weight: Font.Weight, _ color: Color?) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
            .foregroundStyle(color ?? Theme.shared.text(.textPrimary))
    }
}

#Preview {
    struct Demo: View {
        @State var n = 1234
        var body: some View {
            VStack(spacing: 20) {
                RollingNumber(n, size: 40)
                Button("Roll") { n = Int.random(in: 100...99999) }
            }
            .padding()
        }
    }
    return Demo()
}
