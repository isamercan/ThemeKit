//
//  Slider.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Single-thumb value slider with optional labeled marks, a drag
/// value tooltip and a disabled state. (Ant Slider parity.) Shares the visual
/// language of RangeSlider (token track / fill / thumb).
public struct Slider: View {
    @Environment(\.theme) private var theme

    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let step: Double
    private let label: String?
    private let marks: [Double: String]
    private let axis: Axis
    private let verticalHeight: CGFloat
    private var accessibilityID: String? = nil
    @Environment(\.isEnabled) private var isEnabled
    private let showValueTooltip: Bool
    private let onChangeEnd: ((Double) -> Void)?

    @State private var dragging = false
    @State private var dragStartValue: Double?

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 4

    public init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double>,
        step: Double = 1,
        label: String? = nil,
        marks: [Double: String] = [:],
        axis: Axis = .horizontal,
        verticalHeight: CGFloat = 160,
        showValueTooltip: Bool = false,
        onChangeEnd: ((Double) -> Void)? = nil
    ) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.label = label
        self.marks = marks
        self.axis = axis
        self.verticalHeight = verticalHeight
        self.showValueTooltip = showValueTooltip
        self.onChangeEnd = onChangeEnd
    }

    /// Clamp + snap to step, commit, and fire the change-end callback (used by the
    /// VoiceOver adjustable action).
    private func commit(_ raw: Double) {
        let snapped = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
        value = snapped
        onChangeEnd?(snapped)
    }

    private var span: Double { bounds.upperBound - bounds.lowerBound }

    private func valueText(_ v: Double) -> String {
        step.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    public var body: some View {
        if axis == .vertical { verticalBody } else { horizontalBody }
    }

    private var verticalBody: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            if let label {
                Text(label).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            }
            GeometryReader { geo in
                let usable = max(geo.size.height - thumbSize, 1)
                let y = CGFloat((value - bounds.lowerBound) / span) * usable
                ZStack(alignment: .bottom) {
                    Capsule().fill(theme.border(.borderPrimary)).frame(width: trackHeight)
                    Capsule().fill(fillColor).frame(width: trackHeight, height: y + thumbSize / 2)
                    thumb
                        .offset(y: -y)
                        .gesture(verticalDrag(usable: usable))
                }
                .frame(maxWidth: .infinity)
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
            if let label {
                Text(label)
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
                        .gesture(drag(usable: usable))
                }
                .frame(height: thumbSize)
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
        theme.background(isEnabled ? .bgHero : .bgSecondary)
    }

    private func drag(usable: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { g in
                guard isEnabled else { return }
                dragging = true
                let ratio = Double(min(max(g.location.x - thumbSize / 2, 0), usable) / usable)
                let raw = bounds.lowerBound + ratio * span
                value = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
            }
            .onEnded { _ in dragging = false; onChangeEnd?(value) }
    }

    /// Vertical drag uses translation (up = increase) so the math stays correct
    /// regardless of the thumb-local gesture coordinate space.
    private func verticalDrag(usable: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { g in
                guard isEnabled else { return }
                dragging = true
                let start = dragStartValue ?? value
                if dragStartValue == nil { dragStartValue = value }
                let deltaRatio = Double(-g.translation.height / usable)
                let raw = start + deltaRatio * span
                value = min(max(bounds.lowerBound, (raw / step).rounded() * step), bounds.upperBound)
            }
            .onEnded { _ in dragging = false; dragStartValue = nil; onChangeEnd?(value) }
    }
}

#Preview {
    struct Demo: View {
        @State var v: Double = 4
        var body: some View {
            VStack(spacing: 32) {
                Slider(value: $v, in: 0...8, label: "Volume \(Int(v))", showValueTooltip: true)
                Slider(value: $v, in: 0...8, step: 2, marks: [0: "0", 4: "Mid", 8: "Max"])
                Slider(value: .constant(3), in: 0...8, label: "Disabled").disabled(true)
            }
            .padding()
        }
    }
    return Demo()
}

public extension Slider {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
