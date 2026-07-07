//
//  DemoControls.swift
//  Demo
//
//  Small reusable knob controls shared across the interactive demos.
//

import SwiftUI

/// A slider paired with a precise numeric field — for money/points/total knobs
/// where a bare slider is too coarse to dial in an exact value.
struct NumberKnob: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            SwiftUI.Slider(value: $value, in: range, step: step)
            TextField("", value: $value, format: .number)
                .frame(width: 68)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
        }
    }
}

/// A segmented SF Symbol picker — swaps a component's fixed icon for a chosen one.
struct IconKnob: View {
    let title: String
    @Binding var symbol: String
    let options: [String]

    var body: some View {
        Picker(title, selection: $symbol) {
            ForEach(options, id: \.self) { Image(systemName: $0).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}
