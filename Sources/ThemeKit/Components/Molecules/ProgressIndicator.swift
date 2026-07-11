//
//  ProgressIndicator.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ProgressIndicatorVariant { case progress, carousel, video }

public enum ProgressIndicatorSize {
    case large, medium, small, xsmall
    var barHeight: CGFloat {
        switch self {
        case .large: return 6
        case .medium: return 4
        case .small: return 3
        case .xsmall: return 2
        }
    }
}

/// Step-count caption format. (Reference "3/10" / "01 | 05".)
public enum ProgressStepText { case none, slash, padded }

/// Segmented position/progress indicator (Reference ProgressIndicator parity).
/// `.carousel` = one segment per page (filled up to the current one); `.video` =
/// the active segment fills by `videoProgress`; `.progress` = a single
/// continuous bar. Optional "3 / 10" or "01 | 05" step text. Distinct from the
/// dot-style `StepIndicator` and the value-driven `ProgressBar`. Per the
/// modifier-based architecture (COMPONENT_REFACTOR_RULES R1–R7) the init takes only
/// the `variant` (core kind) plus the required `current`/`total` data; every other
/// axis is a chainable, order-free modifier.
///
///     ProgressIndicator(variant: .video, current: 3, total: 5)
///         .videoProgress(0.5).stepText(.slash).size(.large)
public struct ProgressIndicator: View {
    @Environment(\.theme) private var theme

    private let variant: ProgressIndicatorVariant
    private let current: Int   // 1-based active step
    private let total: Int

    // Appearance — mutated only through the modifiers below (R2).
    private var size: ProgressIndicatorSize = .medium
    private var videoProgress: Double = 1
    private var stepText: ProgressStepText = .none
    private var cornerRadius: Bool = true

    public init(
        variant: ProgressIndicatorVariant = .carousel,
        current: Int,
        total: Int
    ) {   // R1 — core kind + required data
        self.variant = variant
        self.total = max(total, 1)
        self.current = max(0, min(current, max(total, 1)))
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: Theme.SpacingKey.xs.value) {
            if stepText != .none {
                Text(stepLabel)
                    .textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textSecondary))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            bar
        }
        // One element for VoiceOver: "Progress, N of M".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKit: "Progress"))
        .accessibilityValue(String(themeKit: "\(current) of \(total)"))
    }

    @ViewBuilder
    private var bar: some View {
        switch variant {
        case .progress:
            segment(fill: Double(current) / Double(total))
        case .carousel, .video:
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(1...total, id: \.self) { index in
                    segment(fill: fillFor(index))
                }
            }
        }
    }

    private func fillFor(_ index: Int) -> Double {
        if index < current { return 1 }
        if index == current { return variant == .video ? min(max(videoProgress, 0), 1) : 1 }
        return 0
    }

    private func segment(fill: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                shape.fill(theme.border(.borderPrimary))
                shape.fill(theme.background(.bgHero))
                    .frame(width: geo.size.width * fill)
            }
        }
        .frame(height: size.barHeight)
    }

    private var shape: AnyShape {
        cornerRadius
            ? AnyShape(Capsule())
            : AnyShape(Rectangle())
    }

    private var stepLabel: String {
        switch stepText {
        case .none: return ""
        case .slash: return "\(current) / \(total)"
        case .padded: return "\(zeroPad2(current)) | \(zeroPad2(total))"
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ProgressIndicator {
    /// Bar thickness: large / medium / small / xsmall.
    func size(_ s: ProgressIndicatorSize) -> Self { copy { $0.size = s } }

    /// Fill fraction (0…1) of the active segment in the `.video` variant.
    func videoProgress(_ value: Double) -> Self { copy { $0.videoProgress = value } }

    /// Step-count caption format: `.none`, `.slash` ("3 / 10"), or `.padded` ("01 | 05").
    func stepText(_ t: ProgressStepText) -> Self { copy { $0.stepText = t } }

    /// Rounds the segment ends into a capsule (default `true`); `false` for square ends.
    func cornerRadius(_ on: Bool = true) -> Self { copy { $0.cornerRadius = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ProgressIndicator") {
        PreviewCase("Carousel + step text") { ProgressIndicator(variant: .carousel, current: 2, total: 5).stepText(.slash) }
        PreviewCase("Video (half-filled)") { ProgressIndicator(variant: .video, current: 3, total: 5).videoProgress(0.5).stepText(.padded) }
        PreviewCase("Progress, large") { ProgressIndicator(variant: .progress, current: 7, total: 10).size(.large).stepText(.slash) }
        PreviewCase("Carousel, xsmall") { ProgressIndicator(variant: .carousel, current: 1, total: 4).size(.xsmall) }
        PreviewCase("Square ends") { ProgressIndicator(variant: .carousel, current: 2, total: 4).cornerRadius(false) }
    }
}
