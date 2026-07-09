//
//  Slider.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Single-thumb value slider with optional labeled marks, a drag
/// value tooltip, tap-to-set on the track, a persistent formatted value readout,
/// a semantic accent and a disabled state. (Ant / HeroUI Slider parity.) Shares
/// the visual language of RangeSlider (token track / fill / thumb).
public struct Slider: View {
    @Environment(\.theme) private var theme

    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let label: String?
    private var accessibilityID: String? = nil
    @Environment(\.isEnabled) private var isEnabled
    // Opt-in presentation — set via chainable modifiers.
    private var step: Double = 1
    private var marks: [Double: String] = [:]
    private var axis: Axis = .horizontal
    private var verticalHeight: CGFloat = 160
    private var showValueTooltip: Bool = false
    private var valueLabel: ((Double) -> String)? = nil
    private var accent: SemanticColor? = nil
    private var onChangeEnd: ((Double) -> Void)? = nil

    @State private var dragging = false

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 4
    /// Extra tappable slop around the track so tap-to-set is easy to hit.
    private let hitSlop: CGFloat = 8
    /// HeroUI-style press feedback: the thumb scales down while dragging.
    private let pressScale: CGFloat = 0.9

    public init(   // R1
        value: Binding<Double>,
        in bounds: ClosedRange<Double>,
        label: String? = nil
    ) {
        self._value = value
        self.bounds = bounds
        self.label = label
    }

    /// Clamp + snap to step, commit, and fire the change-end callback (used by the
    /// VoiceOver adjustable action).
    private func commit(_ raw: Double) {
        let snapped = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
        value = snapped
        onChangeEnd?(snapped)
    }

    private var span: Double { bounds.upperBound - bounds.lowerBound }

    /// One formatting point for the label row, the drag tooltip and the
    /// accessibility value — the `valueLabel` closure wins when provided.
    private func valueText(_ v: Double) -> String {
        if let valueLabel { return valueLabel(v) }
        return step.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    public var body: some View {
        if axis == .vertical { verticalBody } else { horizontalBody }
    }

    private var verticalBody: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            if label != nil || valueLabel != nil {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let label { Text(label) }
                    if valueLabel != nil { Text(valueText(value)) }
                }
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
            }
            GeometryReader { geo in
                let usable = max(geo.size.height - thumbSize, 1)
                let y = CGFloat((value - bounds.lowerBound) / span) * usable
                ZStack(alignment: .bottom) {
                    Capsule().fill(theme.border(.borderPrimary)).frame(width: trackHeight)
                    Capsule().fill(fillColor).frame(width: trackHeight, height: y + thumbSize / 2)
                    thumb.offset(y: -y)
                }
                .frame(maxWidth: .infinity)
                // Tap-to-set: the whole (slop-enlarged) track accepts the drag,
                // so a tap anywhere jumps the thumb to that value.
                .contentShape(Rectangle().inset(by: -hitSlop))
                .gesture(verticalDrag(usable: usable))
            }
            .frame(width: thumbSize, height: verticalHeight)
        }
        .opacity(isEnabled ? 1 : 0.5)
        .a11y(A11yElement.Control.slider, in: accessibilityID)
        .accessibilityLabel(label ?? "")
        .accessibilityValue(valueText(value))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: commit(value + step)
            case .decrement: commit(value - step)
            @unknown default: break
            }
        }
    }

    private var horizontalBody: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if label != nil || valueLabel != nil {
                HStack {
                    if let label { Text(label) }
                    Spacer()
                    if valueLabel != nil { Text(valueText(value)) }
                }
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
            }
            GeometryReader { geo in
                let usable = max(geo.size.width - thumbSize, 1)
                let x = CGFloat((value - bounds.lowerBound) / span) * usable

                ZStack(alignment: .leading) {
                    Capsule().fill(theme.border(.borderPrimary)).frame(height: trackHeight)
                    Capsule().fill(fillColor)
                        .frame(width: x + thumbSize / 2, height: trackHeight)

                    ForEach(marks.keys.sorted(), id: \.self) { mark in
                        Circle()
                            .fill(mark <= value ? theme.foreground(.fgSecondary) : theme.border(.borderPrimary))
                            .frame(width: 6, height: 6)
                            .offset(x: CGFloat((mark - bounds.lowerBound) / span) * usable + thumbSize / 2 - 3)
                    }

                    thumb
                        .offset(x: x)
                        .overlay(alignment: .top) { tooltip.offset(x: x, y: -thumbSize) }
                }
                .frame(height: thumbSize)
                // Tap-to-set: the whole (slop-enlarged) track accepts the drag,
                // so a tap anywhere jumps the thumb to that value.
                .contentShape(Rectangle().inset(by: -hitSlop))
                .gesture(drag(usable: usable))
            }
            .frame(height: thumbSize)

            if !marks.isEmpty {
                GeometryReader { geo in
                    let usable = max(geo.size.width - thumbSize, 1)
                    ForEach(marks.keys.sorted(), id: \.self) { mark in
                        Text(marks[mark] ?? "")
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textTertiary))
                            .fixedSize()
                            .position(x: CGFloat((mark - bounds.lowerBound) / span) * usable + thumbSize / 2, y: 8)
                    }
                }
                .frame(height: 18)
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .a11y(A11yElement.Control.slider, in: accessibilityID)
        .accessibilityLabel(label ?? "")
        .accessibilityValue(valueText(value))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: commit(value + step)
            case .decrement: commit(value - step)
            @unknown default: break
            }
        }
    }

    private var thumb: some View {
        Circle()
            .fill(fillColor)
            .overlay(Circle().strokeBorder(theme.foreground(.fgSecondary), lineWidth: 2))
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
            // Press feedback while dragging — gated on microAnimations + Reduce Motion.
            .microPressScale(dragging, scale: pressScale)
    }

    @ViewBuilder
    private var tooltip: some View {
        if showValueTooltip && dragging {
            Text(valueText(value))
                .textStyle(.labelSm600)
                .foregroundStyle(theme.foreground(.fgSecondary))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, 2)
                .background(theme.background(.bgTertiary), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value))
                .fixedSize()
        }
    }

    private var fillColor: Color {
        guard isEnabled else { return theme.background(.bgSecondary) }
        return accent?.solid ?? theme.background(.bgHero)
    }

    /// Attached to the whole track (minimumDistance 0), so a tap anywhere sets
    /// the value from its absolute location and a drag keeps tracking it; the
    /// change-end callback fires on release either way.
    private func drag(usable: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                guard isEnabled else { return }
                dragging = true
                let ratio = Double(min(max(g.location.x - thumbSize / 2, 0), usable) / usable)
                let raw = bounds.lowerBound + ratio * span
                value = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
            }
            .onEnded { _ in dragging = false; onChangeEnd?(value) }
    }

    /// Vertical variant of the track gesture — the track is a fixed coordinate
    /// space, so the value maps from the absolute touch location (up = increase).
    private func verticalDrag(usable: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                guard isEnabled else { return }
                dragging = true
                let fromBottom = usable + thumbSize / 2 - g.location.y
                let ratio = Double(min(max(fromBottom, 0), usable) / usable)
                let raw = bounds.lowerBound + ratio * span
                value = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
            }
            .onEnded { _ in dragging = false; onChangeEnd?(value) }
    }
}

#Preview {
    struct Demo: View {
        @State var v: Double = 4
        @State var price: Double = 240
        var body: some View {
            // Tap-to-set: tapping anywhere on a track jumps the thumb there.
            VStack(spacing: 32) {
                Slider(value: $v, in: 0...8, label: "Volume \(Int(v))").showsValueTooltip()
                Slider(value: $v, in: 0...8).step(2).marks([0: "0", 4: "Mid", 8: "Max"])
                Slider(value: $price, in: 0...1000, label: "Budget")
                    .step(10)
                    .valueLabel { "$\(Int($0))" }   // currency-style readout + tooltip
                    .showsValueTooltip()
                Slider(value: $v, in: 0...8, label: "Accented")
                    .accent(.success)
                    .valueLabel { "\(Int($0))" }
                Slider(value: .constant(3), in: 0...8, label: "Disabled").disabled(true)
                Slider(value: $v, in: 0...8, label: "Vertical")
                    .axis(.vertical, height: 120)
                    .valueLabel { "\(Int($0))" }
            }
            .padding()
        }
    }
    return Demo()
}

public extension Slider {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Snap increment for dragging and VoiceOver adjustments (default 1).
    func step(_ step: Double) -> Self { copy { $0.step = step } }
    /// Labeled tick marks at the given values (e.g. `[0: "0", 4: "Mid", 8: "Max"]`).
    func marks(_ marks: [Double: String]) -> Self { copy { $0.marks = marks } }
    /// Lays the slider out vertically with the given track height (default 160).
    func axis(_ axis: Axis, height: CGFloat = 160) -> Self {
        copy { $0.axis = axis; $0.verticalHeight = height }
    }
    /// Shows a value tooltip above the thumb while dragging.
    func showsValueTooltip(_ on: Bool = true) -> Self { copy { $0.showValueTooltip = on } }
    /// Formats the persistent value readout on the label row (e.g. "$500");
    /// the same closure formats the drag tooltip and the accessibility value.
    /// `nil` (default) hides the readout and keeps plain numeric formatting.
    func valueLabel(_ format: ((Double) -> String)?) -> Self { copy { $0.valueLabel = format } }
    /// Semantic tint for the track fill and thumb; `nil` (default) keeps the
    /// hero tokens.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Fires with the snapped value when a drag ends (not on every step).
    func onChangeEnd(_ action: ((Double) -> Void)?) -> Self { copy { $0.onChangeEnd = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
