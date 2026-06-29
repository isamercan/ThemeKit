//
//  RangeSlider.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Improved, token-bound rewrite of the reference RangeSliderView — a
/// self-contained dual-thumb slider over a numeric range (decoupled from the
/// reference's text-field wiring).
/// Reference: Ant Design `Slider` (range) / MUI `Slider` — optional `marks`
/// (labeled ticks), a disabled state, an `onChangeEnd` commit callback (fire the
/// search on release, not on every drag tick), and VoiceOver-adjustable thumbs.
public struct RangeSlider: View {
    @Environment(\.theme) private var theme

    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double
    private let bounds: ClosedRange<Double>
    private let step: Double
    @Environment(\.isEnabled) private var isEnabled
    private var accessibilityID: String? = nil
    // Opt-in presentation — set via chainable modifiers.
    private var marks: [Double] = []
    private var valueLabel: ((Double) -> String)? = nil
    private var onChangeEnd: ((Double, Double) -> Void)? = nil
    private var showInputs: Bool = false
    private var inputTitles: (min: String, max: String) = (String(themeKit: "Min"), String(themeKit: "Max"))

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
        step: Double = 1
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
        self.step = step
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
                .foregroundStyle(theme.text(.textPrimary))
            }

            GeometryReader { geo in
                let usable = max(geo.size.width - thumbSize, 1)
                let span = bounds.upperBound - bounds.lowerBound
                let lowerX = CGFloat((lowerValue - bounds.lowerBound) / span) * usable
                let upperX = CGFloat((upperValue - bounds.lowerBound) / span) * usable

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.border(.borderPrimary))
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(theme.background(isEnabled ? .bgHero : .bgSecondaryLight))
                        .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                        .offset(x: lowerX + thumbSize / 2)

                    thumb(value: lowerValue, title: inputTitles.min, isLower: true)
                        .offset(x: lowerX)
                        .gesture(drag(usable: usable, span: span, isLower: true))
                    thumb(value: upperValue, title: inputTitles.max, isLower: false)
                        .offset(x: upperX)
                        .gesture(drag(usable: usable, span: span, isLower: false))
                }
                .frame(height: thumbSize)
            }
            .frame(height: thumbSize)
            .opacity(isEnabled ? 1 : 0.6)

            if !marks.isEmpty {
                GeometryReader { geo in
                    marksRow(usable: max(geo.size.width - thumbSize, 1),
                             span: bounds.upperBound - bounds.lowerBound)
                }
                .frame(height: 22)
            }
        }
        .a11y(A11yElement.Control.slider, in: accessibilityID)
        .accessibilityElement(children: .contain)
        .onAppear { syncText() }
        .onChange(of: lowerValue) { if focusedField != .lower { lowerText = intString(lowerValue) } }
        .onChange(of: upperValue) { if focusedField != .upper { upperText = intString(upperValue) } }
        .onChange(of: focusedField) { _, new in
            // Validate-on-blur: commit whichever field just lost focus.
            if new != .lower { commitLower() }
            if new != .upper { commitUpper() }
        }
    }

    // MARK: Marks

    private func markLabel(_ value: Double) -> String { valueLabel?(value) ?? intString(value) }

    @ViewBuilder
    private func marksRow(usable: CGFloat, span: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks, id: \.self) { mark in
                let ratio = span > 0 ? (mark - bounds.lowerBound) / span : 0
                let centerX = thumbSize / 2 + CGFloat(ratio) * usable
                VStack(spacing: 2) {
                    Capsule().fill(theme.border(.borderPrimary)).frame(width: 1, height: 5)
                    Text(markLabel(mark))
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textTertiary))
                        .fixedSize()
                }
                .position(x: centerX, y: 11)
            }
        }
    }

    // MARK: Linked inputs

    private var inputFields: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            field(title: inputTitles.min, text: $lowerText, field: .lower)
            Rectangle()
                .fill(theme.border(.borderPrimary))
                .frame(width: 10, height: 1)
                .padding(.top, Theme.SpacingKey.base.value)
            field(title: inputTitles.max, text: $upperText, field: .upper)
        }
    }

    private func field(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Text(title)
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textSecondary))
            Group {
                #if os(iOS)
                TextField("", text: text).keyboardType(.numberPad)
                #else
                TextField("", text: text)
                #endif
            }
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .focused($focusedField, equals: field)
                .disabled(!isEnabled)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .frame(height: 44)
                .background(theme.background(.bgWhite),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                        .strokeBorder(focusedField == field ? theme.border(.borderHero)
                                                             : theme.border(.borderPrimary), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func commitLower() {
        guard let parsed = parse(lowerText) else { lowerText = intString(lowerValue); return }
        lowerValue = min(max(bounds.lowerBound, Self.snap(parsed, step: step)), upperValue)
        lowerText = intString(lowerValue)
        onChangeEnd?(lowerValue, upperValue)
    }

    private func commitUpper() {
        guard let parsed = parse(upperText) else { upperText = intString(upperValue); return }
        upperValue = max(min(bounds.upperBound, Self.snap(parsed, step: step)), lowerValue)
        upperText = intString(upperValue)
        onChangeEnd?(lowerValue, upperValue)
    }

    private func parse(_ s: String) -> Double? { Double(s.filter(\.isNumber)) }
    private func intString(_ v: Double) -> String { String(Int(v.rounded())) }
    private func syncText() { lowerText = intString(lowerValue); upperText = intString(upperValue) }

    private func thumb(value: Double, title: String, isLower: Bool) -> some View {
        Circle()
            .fill(theme.background(.bgWhite))
            .overlay(
                Circle().strokeBorder(isEnabled ? theme.border(.borderHero)
                                                : theme.border(.borderPrimary), lineWidth: 2)
            )
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityValue(markLabel(value))
            .accessibilityAdjustableAction { direction in
                guard isEnabled else { return }
                adjust(isLower: isLower, increment: direction == .increment)
            }
    }

    private func adjust(isLower: Bool, increment: Bool) {
        let delta = increment ? step : -step
        if isLower {
            lowerValue = min(max(bounds.lowerBound, Self.snap(lowerValue + delta, step: step)), upperValue)
        } else {
            upperValue = max(min(bounds.upperBound, Self.snap(upperValue + delta, step: step)), lowerValue)
        }
        onChangeEnd?(lowerValue, upperValue)
    }

    private func drag(usable: CGFloat, span: Double, isLower: Bool) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                guard isEnabled else { return }
                let ratio = Double(min(max(gesture.location.x - thumbSize / 2, 0), usable) / usable)
                let stepped = Self.snap(bounds.lowerBound + ratio * span, step: step)
                if isLower {
                    lowerValue = min(max(bounds.lowerBound, stepped), upperValue)
                } else {
                    upperValue = max(min(bounds.upperBound, stepped), lowerValue)
                }
            }
            .onEnded { _ in
                guard isEnabled else { return }
                onChangeEnd?(lowerValue, upperValue)
            }
    }

    // MARK: - Pure helpers (extracted for testing)

    /// Rounds `value` to the nearest `step` (no-op when `step <= 0`).
    static func snap(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    /// Constrains `value` to `bounds`.
    static func clamped(_ value: Double, in bounds: ClosedRange<Double>) -> Double {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}

#Preview {
    struct Demo: View {
        @State var lo: Double = 200
        @State var hi: Double = 800
        var body: some View {
            RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50)
                .marks([0, 250, 500, 750, 1000])
                .valueLabel { "\(Int($0)) $" }
                .padding()
        }
    }
    return Demo()
}

public extension RangeSlider {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }

    /// Labeled tick marks at the given values.
    func marks(_ marks: [Double]) -> Self { var copy = self; copy.marks = marks; return copy }
    /// Shows linked numeric min/max input fields above the track.
    func inputs(_ on: Bool = true, titles: (min: String, max: String) = (String(themeKit: "Min"), String(themeKit: "Max"))) -> Self {
        var copy = self; copy.showInputs = on; copy.inputTitles = titles; return copy
    }
    /// Fires with the snapped (lower, upper) pair when a drag ends.
    func onChangeEnd(_ action: ((Double, Double) -> Void)?) -> Self { var copy = self; copy.onChangeEnd = action; return copy }
    /// Formats the value readout shown above each thumb (e.g. "$500").
    func valueLabel(_ format: ((Double) -> String)?) -> Self { var copy = self; copy.valueLabel = format; return copy }
}
