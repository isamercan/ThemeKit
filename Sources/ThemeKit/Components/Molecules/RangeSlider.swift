//
//  RangeSlider.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Improved, token-bound rewrite of the reference RangeSliderView — a
/// self-contained dual-thumb slider over a numeric range (decoupled from the
/// reference's text-field wiring).
/// Reference: Ant Design `Slider` (range) / MUI `Slider` / HeroUI `Slider` —
/// optional `marks` (labeled ticks), a disabled state, an `onChangeEnd` commit
/// callback (fire the search on release, not on every drag tick), tap-to-set on
/// the track (moves the nearest thumb), a vertical axis, a semantic accent, and
/// VoiceOver-adjustable thumbs.
public struct RangeSlider: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double
    private let bounds: ClosedRange<Double>
    @Environment(\.isEnabled) private var isEnabled
    private var accessibilityID: String? = nil
    // Opt-in presentation — set via chainable modifiers.
    private var step: Double = 1
    private var marks: [Double] = []
    private var axis: Axis = .horizontal
    private var verticalHeight: CGFloat = 160
    private var accent: SemanticColor? = nil
    private var valueLabel: ((Double) -> String)? = nil
    private var onChangeEnd: ((Double, Double) -> Void)? = nil
    private var showInputs: Bool = false
    private var inputTitles: (min: String, max: String) = (String(themeKit: "Min"), String(themeKit: "Max"))

    @State private var lowerText = ""
    @State private var upperText = ""
    @FocusState private var focusedField: Field?
    private enum Field { case lower, upper }
    /// Which thumb the current track gesture is moving — chosen once at gesture
    /// start (nearest to the touch) and kept for the rest of the drag.
    @State private var activeThumb: Field? = nil

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 4
    /// Extra tappable slop around the track so tap-to-set is easy to hit.
    private let hitSlop: CGFloat = 8
    /// HeroUI-style press feedback: the active thumb scales down while dragging.
    private let pressScale: CGFloat = 0.9

    // MARK: RTL (absolute coords; `.offset(x:)`/`.position(x:)` and gesture
    // locations don't auto-mirror, so the x math is flipped by hand — the
    // ColorSlider precedent).
    private var isRTL: Bool { layoutDirection == .rightToLeft }
    /// Sign for hand-mirrored `.offset(x:)` moves from the leading edge.
    private var dir: CGFloat { isRTL ? -1 : 1 }

    public init(   // R1
        lowerValue: Binding<Double>,
        upperValue: Binding<Double>,
        in bounds: ClosedRange<Double>
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if showInputs {
                inputFields
            } else if let valueLabel {
                if axis == .vertical {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Text(valueLabel(lowerValue))
                        Text(verbatim: "–")
                        Text(valueLabel(upperValue))
                    }
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                } else {
                    HStack {
                        Text(valueLabel(lowerValue))
                        Spacer()
                        Text(valueLabel(upperValue))
                    }
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                }
            }

            if axis == .vertical { verticalTrack } else { horizontalTrack }

            if axis == .horizontal, !marks.isEmpty {
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

    // MARK: Track

    private var horizontalTrack: some View {
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
                    .fill(fillColor)
                    .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                    .offset(x: dir * (lowerX + thumbSize / 2))

                thumb(value: lowerValue, title: inputTitles.min, isLower: true)
                    .offset(x: dir * lowerX)
                thumb(value: upperValue, title: inputTitles.max, isLower: false)
                    .offset(x: dir * upperX)
            }
            .frame(height: thumbSize)
            // Tap-to-set: the whole (slop-enlarged) track accepts the drag and
            // moves the thumb nearest to the touch.
            .contentShape(Rectangle().inset(by: -hitSlop))
            .gesture(drag(usable: usable, span: span))
        }
        .frame(height: thumbSize)
        .opacity(isEnabled ? 1 : 0.6)
    }

    /// Vertical layout — same approach as `Slider.axis(.vertical)`: a fixed-height
    /// bottom-aligned track whose gesture maps the absolute touch location to a
    /// value (up = increase).
    private var verticalTrack: some View {
        GeometryReader { geo in
            let usable = max(geo.size.height - thumbSize, 1)
            let span = bounds.upperBound - bounds.lowerBound
            let lowerY = CGFloat((lowerValue - bounds.lowerBound) / span) * usable
            let upperY = CGFloat((upperValue - bounds.lowerBound) / span) * usable

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(theme.border(.borderPrimary))
                    .frame(width: trackHeight)
                Capsule()
                    .fill(fillColor)
                    .frame(width: trackHeight, height: max(upperY - lowerY, 0))
                    .offset(y: -(lowerY + thumbSize / 2))

                thumb(value: lowerValue, title: inputTitles.min, isLower: true)
                    .offset(y: -lowerY)
                thumb(value: upperValue, title: inputTitles.max, isLower: false)
                    .offset(y: -upperY)
            }
            .frame(maxWidth: .infinity)
            // Tap-to-set, vertical flavor — see `horizontalTrack`.
            .contentShape(Rectangle().inset(by: -hitSlop))
            .gesture(verticalDrag(usable: usable, span: span))
        }
        .frame(width: thumbSize, height: verticalHeight)
        .opacity(isEnabled ? 1 : 0.6)
    }

    // MARK: Colors

    /// Track-fill shade — the accent's solid shade when set, else the hero token.
    private var fillColor: Color {
        guard isEnabled else { return theme.background(.bgSecondaryLight) }
        return accent?.solid ?? theme.background(.bgHero)
    }

    /// Thumb-ring shade — the accent's solid shade when set, else the hero border.
    private var thumbRingColor: Color {
        guard isEnabled else { return theme.border(.borderPrimary) }
        return accent?.solid ?? theme.border(.borderHero)
    }

    // MARK: Marks

    private func markLabel(_ value: Double) -> String { valueLabel?(value) ?? intString(value) }

    @ViewBuilder
    private func marksRow(usable: CGFloat, span: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks, id: \.self) { mark in
                let ratio = span > 0 ? (mark - bounds.lowerBound) / span : 0
                let ltrX = thumbSize / 2 + CGFloat(ratio) * usable
                // `.position(x:)` doesn't auto-mirror: flip within the row width.
                let centerX = isRTL ? (usable + thumbSize) - ltrX : ltrX
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
            .overlay(Circle().strokeBorder(thumbRingColor, lineWidth: 2))
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
            // Press feedback while dragging — gated on microAnimations + Reduce Motion.
            .microPressScale(activeThumb == (isLower ? .lower : .upper), scale: pressScale)
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

    /// Attached to the whole track (minimumDistance 0), so a tap anywhere moves
    /// the nearest thumb to that value and a drag keeps moving the same thumb;
    /// the change-end callback fires on release either way.
    private func drag(usable: CGFloat, span: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled else { return }
                var ratio = Double(min(max(gesture.location.x - thumbSize / 2, 0), usable) / usable)
                if isRTL { ratio = 1 - ratio }   // gesture x doesn't auto-mirror
                move(toward: bounds.lowerBound + ratio * span)
            }
            .onEnded { _ in
                activeThumb = nil
                guard isEnabled else { return }
                onChangeEnd?(lowerValue, upperValue)
            }
    }

    /// Vertical variant of the track gesture (up = increase).
    private func verticalDrag(usable: CGFloat, span: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled else { return }
                let fromBottom = usable + thumbSize / 2 - gesture.location.y
                let ratio = Double(min(max(fromBottom, 0), usable) / usable)
                move(toward: bounds.lowerBound + ratio * span)
            }
            .onEnded { _ in
                activeThumb = nil
                guard isEnabled else { return }
                onChangeEnd?(lowerValue, upperValue)
            }
    }

    /// Moves the gesture's thumb — chosen once per gesture as the one nearest to
    /// the touched value — keeping the pair ordered (lower never crosses upper).
    private func move(toward raw: Double) {
        let stepped = Self.snap(raw, step: step)
        let target = activeThumb ?? nearestThumb(to: stepped)
        activeThumb = target
        if target == .lower {
            lowerValue = min(max(bounds.lowerBound, stepped), upperValue)
        } else {
            upperValue = max(min(bounds.upperBound, stepped), lowerValue)
        }
    }

    private func nearestThumb(to value: Double) -> Field {
        let lowerDistance = abs(value - lowerValue)
        let upperDistance = abs(value - upperValue)
        // Tie (including coincident thumbs): move lower when the touch is below
        // it, upper otherwise, so a stacked pair can always be pulled apart.
        if lowerDistance == upperDistance { return value < lowerValue ? .lower : .upper }
        return lowerDistance < upperDistance ? .lower : .upper
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
        @State var vLo: Double = 2
        @State var vHi: Double = 6
        var body: some View {
            // Tap-to-set: tapping anywhere on a track moves the nearest thumb.
            VStack(spacing: 32) {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .marks([0, 250, 500, 750, 1000])
                    .valueLabel { "\(Int($0)) $" }
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .accent(.success)
                    .valueLabel { "$\(Int($0))" }   // currency-style readout
                RangeSlider(lowerValue: $vLo, upperValue: $vHi, in: 0...8)
                    .axis(.vertical, height: 140)
                    .valueLabel { "\(Int($0))" }
            }
            .padding()
        }
    }
    return Demo()
}

#Preview("RTL") {
    struct Demo: View {
        @State var lo: Double = 200
        @State var hi: Double = 800
        var body: some View {
            // Mirrored geometry: the range fill spans right-to-left between the
            // thumbs, marks flip, and dragging tracks the finger correctly.
            VStack(spacing: 32) {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .marks([0, 250, 500, 750, 1000])
                    .valueLabel { "\(Int($0)) $" }
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .accent(.success)
                    .valueLabel { "$\(Int($0))" }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
    return Demo()
}

public extension RangeSlider {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Snap increment for dragging, typed input and VoiceOver adjustments (default 1).
    func step(_ step: Double) -> Self { copy { $0.step = step } }
    /// Labeled tick marks at the given values (horizontal axis only).
    func marks(_ marks: [Double]) -> Self { copy { $0.marks = marks } }
    /// Lays the slider out vertically with the given track height (default 160).
    func axis(_ axis: Axis, height: CGFloat = 160) -> Self {
        copy { $0.axis = axis; $0.verticalHeight = height }
    }
    /// Semantic tint for the range fill and thumb rings; `nil` (default) keeps
    /// the hero tokens.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Shows linked numeric min/max input fields above the track.
    func inputs(_ on: Bool = true, titles: (min: String, max: String) = (String(themeKit: "Min"), String(themeKit: "Max"))) -> Self {
        copy { $0.showInputs = on; $0.inputTitles = titles }
    }
    /// Fires with the snapped (lower, upper) pair when a drag ends.
    func onChangeEnd(_ action: ((Double, Double) -> Void)?) -> Self { copy { $0.onChangeEnd = action } }
    /// Formats the value readout shown above each thumb (e.g. "$500").
    func valueLabel(_ format: ((Double) -> String)?) -> Self { copy { $0.valueLabel = format } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
