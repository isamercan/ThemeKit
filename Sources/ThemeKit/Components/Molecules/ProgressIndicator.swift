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
/// dot-style `StepIndicator` and the value-driven `ProgressBar`.
public struct ProgressIndicator: View {
    private let variant: ProgressIndicatorVariant
    private let current: Int   // 1-based active step
    private let total: Int
    private let size: ProgressIndicatorSize
    private let videoProgress: Double
    private let stepText: ProgressStepText
    private let cornerRadius: Bool

    public init(
        variant: ProgressIndicatorVariant = .carousel,
        current: Int,
        total: Int,
        size: ProgressIndicatorSize = .medium,
        videoProgress: Double = 1,
        stepText: ProgressStepText = .none,
        cornerRadius: Bool = true
    ) {
        self.variant = variant
        self.current = max(0, min(current, total))
        self.total = max(total, 1)
        self.size = size
        self.videoProgress = min(max(videoProgress, 0), 1)
        self.stepText = stepText
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: Theme.SpacingKey.xs.value) {
            if stepText != .none {
                Text(stepLabel)
                    .textStyle(.labelSm700)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            bar
        }
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
        if index == current { return variant == .video ? videoProgress : 1 }
        return 0
    }

    private func segment(fill: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                shape.fill(Theme.shared.border(.borderPrimary))
                shape.fill(Theme.shared.background(.bgHero))
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
        case .padded: return String(format: "%02d | %02d", current, total)
        }
    }
}

#Preview {
    VStack(spacing: 28) {
        ProgressIndicator(variant: .carousel, current: 2, total: 5, stepText: .slash)
        ProgressIndicator(variant: .video, current: 3, total: 5, videoProgress: 0.5, stepText: .padded)
        ProgressIndicator(variant: .progress, current: 7, total: 10, size: .large, stepText: .slash)
        ProgressIndicator(variant: .carousel, current: 1, total: 4, size: .xsmall)
    }
    .padding()
}
