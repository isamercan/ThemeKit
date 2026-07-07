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
///
/// Drawing is delegated to the ``MeterStyle`` in the environment (set with
/// `.meterStyle(_:)`; default ``LinearMeterStyle`` reproduces the original bar
/// pixel-for-pixel). The component keeps the DATA: it clamps the fraction,
/// resolves the fill (explicit `accent(_:)` override > status gradient >
/// status solid), reads the track token, caps the success segment at the
/// current value, and builds the percentage/checkmark label. The label is
/// passed through `MeterStyleConfiguration.label` (not drawn here) so styles
/// control its placement — the default style trails it after the bar in the
/// same `HStack` as before, preserving today's layout exactly. Accessibility
/// (element, label, value, traits) and the value animation stay on the
/// component, so they apply uniformly to every style.
public struct ProgressBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.meterStyle) private var meterStyle

    private let value: Double
    // Appearance/config — mutated only through the modifiers below (R2).
    private var showPercentage: Bool = false
    private var status: ProgressStatus = .normal
    private var height: CGFloat = 8
    private var gradient: Bool = false
    private var steps: Int? = nil
    private var strokeColor: Color? = nil
    private var trailColor: Color? = nil
    private var successSegment: Double? = nil
    private var format: ((Double) -> String)? = nil
    private var accessibilityLabelText: String? = nil

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    /// - Parameter value: progress in 0...1.
    ///
    /// Everything else — the percentage label, status, thickness, gradient,
    /// stepped variant, color overrides, a success segment, a custom label
    /// formatter, the VoiceOver name — is set via chainable modifiers:
    /// `.showsPercentage(_:) .status(_:) .barHeight(_:) .gradient(_:) .steps(_:)
    /// .accent(_:) .successSegment(_:) .valueFormat(_:) .progressLabel(_:)`.
    public init(value: Double) {   // R1
        self.value = min(max(value, 0), 1)
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
        meterStyle.makeBody(configuration: configuration)
            // The bar's fill is purely visual; expose the progress to VoiceOver as a
            // spoken percentage. `.updatesFrequently` tells VoiceOver to re-read it
            // while an active task advances.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabelText ?? String(themeKit: "Progress")))
            .accessibilityValue(Text(percentText))
            .accessibilityAddTraits(status == .active ? .updatesFrequently : [])
            .animation(motion, value: value)
    }

    /// The resolved inputs handed to the active ``MeterStyle`` — data here,
    /// geometry there. `successFraction` is pre-capped at the current value
    /// (the original `min(successSegment, value)` overlay width rule).
    private var configuration: MeterStyleConfiguration {
        MeterStyleConfiguration(
            fraction: value,
            status: status,
            steps: steps,
            height: height,
            fill: fillStyle,
            track: trackColor,
            successFraction: successSegment.map { min($0, value) },
            label: labelView
        )
    }

    /// The trailing label block: success checkmark once complete, else the
    /// (optionally custom-formatted) percentage; nil when neither applies.
    private var labelView: AnyView? {
        if status == .success && value >= 1 {
            return AnyView(
                Icon(systemName: "checkmark.circle.fill").size(.sm).colorOverride(status.semantic.accent)
            )
        }
        if showPercentage {
            return AnyView(
                Text(percentText)
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textPrimary))
                    .frame(minWidth: 40, alignment: .trailing)
            )
        }
        return nil
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

public extension ProgressBar {
    /// Draw the percentage label next to the bar.
    func showsPercentage(_ on: Bool = true) -> Self { copy { $0.showPercentage = on } }
    /// Semantic state driving the fill color (normal / success / exception / active).
    func status(_ s: ProgressStatus) -> Self { copy { $0.status = s } }
    /// Bar thickness in points (default 8).
    func barHeight(_ points: CGFloat) -> Self { copy { $0.height = points } }
    /// Fill with a status gradient instead of a solid color.
    func gradient(_ on: Bool = true) -> Self { copy { $0.gradient = on } }
    /// Render as a segmented (stepped) bar with this many segments.
    func steps(_ count: Int?) -> Self { copy { $0.steps = count } }
    /// Semantic fill override; `nil` (default) keeps the status-derived fill.
    /// Drives only the fill — the track keeps its token default.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.strokeColor = color?.base } }
    /// Raw fill/track overrides (back-compat); prefer `accent(_:)` for the fill.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func colors(fill: Color? = nil, track: Color? = nil) -> Self {
        copy {
            if let fill { $0.strokeColor = fill }
            if let track { $0.trailColor = track }
        }
    }
    /// A 0...1 portion drawn in the success color on top of the fill (Ant `success.percent`).
    func successSegment(_ portion: Double?) -> Self { copy { $0.successSegment = portion.map { min(max($0, 0), 1) } } }
    /// Custom formatter for the percentage label (receives the 0...1 value).
    func valueFormat(_ format: ((Double) -> String)?) -> Self { copy { $0.format = format } }
    /// VoiceOver name for the bar (e.g. "Upload") so several bars can be told
    /// apart. Defaults to "Progress".
    func progressLabel(_ label: String?) -> Self { copy { $0.accessibilityLabelText = label } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
        ProgressBar(value: 0.3).showsPercentage()
        ProgressBar(value: 0.7).showsPercentage().gradient()
        ProgressBar(value: 0.5).showsPercentage().status(.exception)
        ProgressBar(value: 1.0).showsPercentage().status(.success)
        ProgressBar(value: 0.6).steps(5)
        ProgressBar(value: 0.65).showsPercentage().meterStyle(.striped)
        ProgressBar(value: 0.6).steps(5).meterStyle(.striped)
        StepIndicator(current: 2, total: 5)
    }
    .padding()
}
