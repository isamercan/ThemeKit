//
//  RadialProgress.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Circular determinate progress with status colors and an optional
/// dashboard (gapped) variant. (Ant Progress type="circle"/"dashboard".)
///
/// Drawing is delegated to a ``MeterStyle`` — the component keeps the DATA
/// (fraction clamping, the fill priority `ringColor` > `accent` > `status`,
/// the track token, the center label) and the style draws the GEOMETRY.
/// When no `.meterStyle(_:)` is set, the component uses ``RadialMeterStyle``
/// built from its own `size` / `lineWidth` / `dashboard` — *not* the
/// environment's `LinearMeterStyle` default, which would flatten the ring
/// into a bar. An explicit `.meterStyle(_:)` (detected via
/// `AnyMeterStyle.isDefault == false`) replaces the ring geometry entirely.
/// Accessibility and the value animation stay on the component, so they apply
/// uniformly to every style.
public struct RadialProgress: View {
    @Environment(\.theme) private var theme
    @Environment(\.meterStyle) private var meterStyle

    private let value: Double

    // Appearance/state/config — mutated only through the modifiers below (R2).
    private var size: CGFloat = 64
    private var lineWidth: CGFloat = 6
    private var showLabel: Bool = true
    private var status: ProgressStatus = .normal
    private var dashboard: Bool = false
    private var tint: Color?
    private var semantic: SemanticColor?
    private var accessibilityLabelText: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ value: Double) {   // R1
        self.value = min(max(value, 0), 1)
    }

    /// Percentage rounded mid-range, but capped at 99% until the value is
    /// actually complete — so the ring never reads "100%" while it's not full and
    /// the success checkmark (value >= 1) hasn't appeared.
    private var percent: Int { value >= 1 ? 100 : min(99, Int((value * 100).rounded())) }

    /// Locale-correct percent string — the `%` sits where the locale puts it
    /// (e.g. Turkish "%50" prefix vs English "50%"), preserving the cap above.
    private var percentText: String {
        (Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    // Raw override wins, then the semantic accent, then the status color.
    private var color: Color { tint ?? semantic.map { theme.resolve($0).solid } ?? theme.resolve(status.semantic).solid }
    /// Semantic driving the success / exception glyph tint (accent-aware).
    private var glyphSemantic: SemanticColor { semantic ?? status.semantic }

    public var body: some View {
        meter
            // The ring fill is purely visual; speak the percentage to VoiceOver.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabelText ?? String(themeKit: "Progress")))
            .accessibilityValue(Text(percentText))
            .accessibilityAddTraits(status == .active ? .updatesFrequently : [])
            .animation(motion, value: value)
    }

    /// The active geometry. `isDefault` bridges the shared `\.meterStyle`
    /// environment (whose default is `LinearMeterStyle`, for `ProgressBar`) to
    /// this component's own ring default: only an *explicitly set* style
    /// replaces `RadialMeterStyle`.
    @ViewBuilder
    private var meter: some View {
        if meterStyle.isDefault {
            RadialMeterStyle(size: size, lineWidth: lineWidth, dashboard: dashboard)
                .makeBody(configuration: configuration)
        } else {
            meterStyle.makeBody(configuration: configuration)
        }
    }

    /// The resolved inputs handed to the active ``MeterStyle`` — data here,
    /// geometry there. `height` carries the stroke width so linear styles draw
    /// at a sensible thickness; ``RadialMeterStyle`` gets `size` / `lineWidth`
    /// / `dashboard` through its init instead (the shared configuration has no
    /// radial fields).
    private var configuration: MeterStyleConfiguration {
        MeterStyleConfiguration(
            fraction: value,
            status: status,
            steps: nil,
            height: lineWidth,
            fill: AnyShapeStyle(color),
            track: theme.border(.borderPrimary),
            successFraction: nil,
            label: labelView
        )
    }

    /// The center label block: success checkmark / exception cross / percent;
    /// nil when `showsLabel(false)`.
    private var labelView: AnyView? {
        guard showLabel else { return nil }
        if status == .success && value >= 1 {
            return AnyView(
                Image(systemName: "checkmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(theme.resolve(glyphSemantic).accent)
            )
        }
        if status == .exception {
            return AnyView(
                Image(systemName: "xmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(theme.resolve(glyphSemantic).accent)
            )
        }
        return AnyView(
            Text(percentText)
                .font(.system(size: size * 0.26, weight: .semibold))
                .foregroundStyle(theme.text(.textPrimary))
        )
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

    /// Semantic tint for the ring fill and glyphs; `nil` (default) derives from
    /// `status`. (daisyUI radial-progress colors.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.semantic = color } }

    /// Raw ring fill override (back-compat); prefer `accent(_:)`. Wins over `accent`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
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
    PreviewMatrix("RadialProgress") {
        PreviewCase("Default") { RadialProgress(0.25) }
        PreviewCase("Dashboard") { RadialProgress(0.7).size(80).lineWidth(8).dashboard() }
        PreviewCase("Success") { RadialProgress(1.0).status(.success) }
        PreviewCase("Exception") { RadialProgress(0.4).status(.exception) }
        PreviewCase("Accent") { RadialProgress(0.6).accent(.purple) }
        // An explicit custom MeterStyle replaces the ring geometry entirely.
        PreviewCase("Custom meter style") { RadialProgress(0.6).meterStyle(.striped) }
    }
}
