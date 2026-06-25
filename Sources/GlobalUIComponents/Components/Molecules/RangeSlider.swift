//
//  RangeSlider.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference RangeSliderView — a
//  self-contained dual-thumb slider over a numeric range (decoupled from the
//  reference's text-field wiring).
//

import SwiftUI

public struct RangeSlider: View {
    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double
    private let bounds: ClosedRange<Double>
    private let step: Double
    private let valueLabel: ((Double) -> String)?
    private let accessibilityID: String?

    // Linked numeric inputs (validate-on-blur). Reference RangeSliderView parity.
    private let showInputs: Bool
    private let inputTitles: (min: String, max: String)
    @State private var lowerText = ""
    @State private var upperText = ""
    @FocusState private var focusedField: Field?
    private enum Field { case lower, upper }

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 4

    public init(
        lowerValue: Binding<Double>,
        upperValue: Binding<Double>,
        in bounds: ClosedRange<Double>,
        step: Double = 1,
        showInputs: Bool = false,
        inputTitles: (min: String, max: String) = (String(globalUIComponents: "Min"), String(globalUIComponents: "Max")),
        accessibilityID: String? = nil,
        valueLabel: ((Double) -> String)? = nil
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
        self.step = step
        self.showInputs = showInputs
        self.inputTitles = inputTitles
        self.accessibilityID = accessibilityID
        self.valueLabel = valueLabel
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if showInputs {
                inputFields
            } else if let valueLabel {
                HStack {
                    Text(valueLabel(lowerValue))
                    Spacer()
                    Text(valueLabel(upperValue))
                }
                .textStyle(.labelBase600)
                .foregroundStyle(Theme.shared.text(.textPrimary))
            }

            GeometryReader { geo in
                let usable = max(geo.size.width - thumbSize, 1)
                let span = bounds.upperBound - bounds.lowerBound
                let lowerX = CGFloat((lowerValue - bounds.lowerBound) / span) * usable
                let upperX = CGFloat((upperValue - bounds.lowerBound) / span) * usable

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.shared.border(.borderPrimary))
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(Theme.shared.background(.bgHero))
                        .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                        .offset(x: lowerX + thumbSize / 2)

                    thumb
                        .offset(x: lowerX)
                        .gesture(drag(usable: usable, span: span, isLower: true))
                    thumb
                        .offset(x: upperX)
                        .gesture(drag(usable: usable, span: span, isLower: false))
                }
                .frame(height: thumbSize)
            }
            .frame(height: thumbSize)
        }
        .a11y(A11yElement.Control.slider, in: accessibilityID)
        .accessibilityValue(valueLabel.map { "\($0(lowerValue)) - \($0(upperValue))" } ?? "")
        .onAppear { syncText() }
        .onChange(of: lowerValue) { if focusedField != .lower { lowerText = intString(lowerValue) } }
        .onChange(of: upperValue) { if focusedField != .upper { upperText = intString(upperValue) } }
        .onChange(of: focusedField) { _, new in
            // Validate-on-blur: commit whichever field just lost focus.
            if new != .lower { commitLower() }
            if new != .upper { commitUpper() }
        }
    }

    // MARK: Linked inputs

    private var inputFields: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            field(title: inputTitles.min, text: $lowerText, field: .lower)
            Rectangle()
                .fill(Theme.shared.border(.borderPrimary))
                .frame(width: 10, height: 1)
                .padding(.top, Theme.SpacingKey.base.value)
            field(title: inputTitles.max, text: $upperText, field: .upper)
        }
    }

    private func field(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Text(title)
                .textStyle(.labelSm600)
                .foregroundStyle(Theme.shared.text(.textSecondary))
            Group {
                #if os(iOS)
                TextField("", text: text).keyboardType(.numberPad)
                #else
                TextField("", text: text)
                #endif
            }
                .textStyle(.bodyBase400)
                .foregroundStyle(Theme.shared.text(.textPrimary))
                .focused($focusedField, equals: field)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .frame(height: 44)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                        .strokeBorder(focusedField == field ? Theme.shared.border(.borderHero) : Theme.shared.border(.borderPrimary), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func commitLower() {
        guard let parsed = parse(lowerText) else { lowerText = intString(lowerValue); return }
        lowerValue = min(max(bounds.lowerBound, snap(parsed)), upperValue)
        lowerText = intString(lowerValue)
    }

    private func commitUpper() {
        guard let parsed = parse(upperText) else { upperText = intString(upperValue); return }
        upperValue = max(min(bounds.upperBound, snap(parsed)), lowerValue)
        upperText = intString(upperValue)
    }

    private func parse(_ s: String) -> Double? { Double(s.filter(\.isNumber)) }
    private func snap(_ v: Double) -> Double { (v / step).rounded() * step }
    private func intString(_ v: Double) -> String { String(Int(v.rounded())) }
    private func syncText() { lowerText = intString(lowerValue); upperText = intString(upperValue) }

    private var thumb: some View {
        Circle()
            .fill(Theme.shared.background(.bgWhite))
            .overlay(Circle().strokeBorder(Theme.shared.border(.borderHero), lineWidth: 2))
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
    }

    private func drag(usable: CGFloat, span: Double, isLower: Bool) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                let ratio = Double(min(max(gesture.location.x - thumbSize / 2, 0), usable) / usable)
                let raw = bounds.lowerBound + ratio * span
                let stepped = (raw / step).rounded() * step
                if isLower {
                    lowerValue = min(max(bounds.lowerBound, stepped), upperValue)
                } else {
                    upperValue = max(min(bounds.upperBound, stepped), lowerValue)
                }
            }
    }
}

#Preview {
    struct Demo: View {
        @State var lo: Double = 200
        @State var hi: Double = 800
        var body: some View {
            RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50) { "\(Int($0)) ₺" }
                .padding()
        }
    }
    return Demo()
}
