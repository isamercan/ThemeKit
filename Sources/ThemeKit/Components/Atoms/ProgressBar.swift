//
//  ProgressBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ProgressStatus {
    case normal, success, exception, active

    var semantic: SemanticColor {
        switch self {
        case .normal, .active: return .primary
        case .success: return .success
        case .exception: return .error
        }
    }
}

/// Linear determinate progress with status colors, an optional ladder gradient,
/// a segmented (steps) variant and a custom format label. (Ant Progress parity.)
/// Plus a segmented `StepIndicator`.
public struct ProgressBar: View {
    @Environment(\.theme) private var theme

    private let value: Double
    private let height: CGFloat
    private let showPercentage: Bool
    private let status: ProgressStatus
    private let gradient: Bool
    private let steps: Int?
    private let strokeColor: Color?
    private let trailColor: Color?
    private let successSegment: Double?
    private let format: ((Double) -> String)?
    private let accessibilityLabelText: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    /// - Parameters:
    ///   - value: progress in 0...1.
    ///   - height: bar thickness in points.
    ///   - showPercentage: draw the percentage label next to the bar.
    ///   - status: semantic state driving the fill color (normal / success / exception …).
    ///   - gradient: fill with a gradient instead of a solid color.
    ///   - steps: render as a segmented (stepped) bar with this many segments.
    ///   - strokeColor: overrides the fill color.
    ///   - trailColor: overrides the track color.
    ///   - successSegment: 0...1 portion drawn in the success color on top of the fill (Ant `success.percent`).
    ///   - format: custom formatter for the percentage label (receives the 0...1 value).
    ///   - accessibilityLabel: VoiceOver name for the bar (e.g. "Upload"); lets
    ///     several bars on one screen be told apart. Defaults to "Progress".
    public init(
        value: Double,
        height: CGFloat = 8,
        showPercentage: Bool = false,
        status: ProgressStatus = .normal,
        gradient: Bool = false,
        steps: Int? = nil,
        strokeColor: Color? = nil,
        trailColor: Color? = nil,
        successSegment: Double? = nil,
        format: ((Double) -> String)? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.value = min(max(value, 0), 1)
        self.height = height
        self.showPercentage = showPercentage
        self.status = status
        self.gradient = gradient
        self.steps = steps
        self.strokeColor = strokeColor
        self.trailColor = trailColor
        self.successSegment = successSegment.map { min(max($0, 0), 1) }
        self.format = format
        self.accessibilityLabelText = accessibilityLabel
    }

    private var trackColor: Color { trailColor ?? theme.border(.borderPrimary) }

    /// Spoken/displayed percentage. Rounded mid-range (0.756 → "76%", not "75%"),
    /// but capped at 99% until the value is actually complete, so the label can
    /// never claim "100%" while the fill is short and the success checkmark
    /// (which gates on value >= 1) is absent.
    private var percentText: String {
        if let format { return format(value) }
        let pct = value >= 1 ? 100 : min(99, Int((value * 100).rounded()))
        return "%\(pct)"
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let steps {
                HStack(spacing: 4) {
                    ForEach(0..<max(steps, 1), id: \.self) { i in
                        Capsule()
                            .fill(Double(i) < value * Double(steps) ? AnyShapeStyle(fillStyle) : AnyShapeStyle(trackColor))
                            .frame(height: height)
                    }
                }
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackColor)
                        Capsule().fill(fillStyle).frame(width: geo.size.width * value)
                        if let successSegment {
                            Capsule().fill(SemanticColor.success.solid)
                                .frame(width: geo.size.width * min(successSegment, value))
                        }
                    }
                }
                .frame(height: height)
            }

            label
        }
        // The bar's fill is purely visual; expose the progress to VoiceOver as a
        // spoken percentage. `.updatesFrequently` tells VoiceOver to re-read it
        // while an active task advances.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelText ?? String(themeKit: "Progress")))
        .accessibilityValue(Text(percentText))
        .accessibilityAddTraits(status == .active ? .updatesFrequently : [])
        .animation(motion, value: value)
    }

    @ViewBuilder
    private var label: some View {
        if status == .success && value >= 1 {
            Icon(systemName: "checkmark.circle.fill", size: .sm, color: status.semantic.accent)
        } else if showPercentage {
            Text(percentText)
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 40, alignment: .trailing)
        }
    }

    private var fillStyle: AnyShapeStyle {
        if let strokeColor {
            return AnyShapeStyle(strokeColor)
        }
        if gradient {
            return AnyShapeStyle(LinearGradient(colors: [status.semantic.base, status.semantic.hover], startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(status.semantic.solid)
    }
}

/// Segmented step indicator (e.g. carousels / onboarding).
public struct StepIndicator: View {
    @Environment(\.theme) private var theme

    private let current: Int
    private let total: Int

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index == current ? theme.background(.bgHero) : theme.border(.borderPrimary))
                    .frame(width: index == current ? 20 : 6, height: 6)
                    .animation(motion, value: current)
            }
        }
        // Position is conveyed only by the highlighted dot; speak it instead.
        // Hidden entirely when there are no steps so VoiceOver never reads an
        // impossible "1 of 0".
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(total <= 0)
        .accessibilityLabel(Text(String(themeKit: "Step")))
        .accessibilityValue(Text(stepValueText))
    }

    /// Clamped "position of total"; empty when there are no steps.
    private var stepValueText: String {
        guard total > 0 else { return "" }
        let position = min(max(current + 1, 1), total)
        return String(themeKit: "\(position) of \(total)")
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressBar(value: 0.3, showPercentage: true)
        ProgressBar(value: 0.7, showPercentage: true, gradient: true)
        ProgressBar(value: 0.5, showPercentage: true, status: .exception)
        ProgressBar(value: 1.0, showPercentage: true, status: .success)
        ProgressBar(value: 0.6, steps: 5)
        StepIndicator(current: 2, total: 5)
    }
    .padding()
}
