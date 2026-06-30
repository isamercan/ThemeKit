//
//  RadialProgress.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Circular determinate progress with status colors and an optional
/// dashboard (gapped) variant. (Ant Progress type="circle"/"dashboard".)
public struct RadialProgress: View {
    @Environment(\.theme) private var theme

    private let value: Double

    // Appearance/state/config — mutated only through the modifiers below (R2).
    private var size: CGFloat = 64
    private var lineWidth: CGFloat = 6
    private var showLabel: Bool = true
    private var status: ProgressStatus = .normal
    private var dashboard: Bool = false
    private var tint: Color?
    private var accessibilityLabelText: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ value: Double) {   // R1
        self.value = min(max(value, 0), 1)
    }

    /// Percentage rounded mid-range, but capped at 99% until the value is
    /// actually complete — so the ring never reads "100%" while it's not full and
    /// the success checkmark (value >= 1) hasn't appeared.
    private var percent: Int { value >= 1 ? 100 : min(99, Int((value * 100).rounded())) }

    private var gap: CGFloat { dashboard ? 0.25 : 0 }            // fraction left open
    private var rotation: Double { dashboard ? 90 + Double(gap) * 180 : -90 }
    private var color: Color { tint ?? status.semantic.solid }

    public var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1 - gap)
                .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            Circle()
                .trim(from: 0, to: value * (1 - gap))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .animation(motion, value: value)
            if showLabel {
                if status == .success && value >= 1 {
                    Image(systemName: "checkmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(status.semantic.accent)
                } else if status == .exception {
                    Image(systemName: "xmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(status.semantic.accent)
                } else {
                    Text("\(percent)%")
                        .font(.system(size: size * 0.26, weight: .semibold))
                        .foregroundStyle(theme.text(.textPrimary))
                }
            }
        }
        .frame(width: size, height: size)
        // The ring fill is purely visual; speak the percentage to VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelText ?? String(themeKit: "Progress")))
        .accessibilityValue(Text("\(percent)%"))
        .accessibilityAddTraits(status == .active ? .updatesFrequently : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RadialProgress {
    /// Diameter of the ring, in points.
    func size(_ s: CGFloat) -> Self { copy { $0.size = s } }

    /// Stroke width of the ring.
    func lineWidth(_ w: CGFloat) -> Self { copy { $0.lineWidth = w } }

    /// Show or hide the center label (percentage / success-fail glyph).
    func showsLabel(_ on: Bool = true) -> Self { copy { $0.showLabel = on } }

    /// Semantic status driving the fill color and success/exception glyphs.
    func status(_ s: ProgressStatus) -> Self { copy { $0.status = s } }

    /// Dashboard (gapped) ring variant.
    func dashboard(_ on: Bool = true) -> Self { copy { $0.dashboard = on } }

    /// Override the ring fill color (otherwise derived from `status`).
    func ringColor(_ c: Color?) -> Self { copy { $0.tint = c } }

    /// Spoken VoiceOver label for the ring (the value is announced separately).
    func a11yLabel(_ text: String?) -> Self { copy { $0.accessibilityLabelText = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    HStack(spacing: 20) {
        RadialProgress(0.25)
        RadialProgress(0.7).size(80).lineWidth(8).dashboard()
        RadialProgress(1.0).status(.success)
        RadialProgress(0.4).status(.exception)
    }
    .padding()
}
