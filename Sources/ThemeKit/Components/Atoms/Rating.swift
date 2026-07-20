//
//  Rating.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Rating presentation. (Reference RatingType parity.)
public enum RatingLayout {
    /// A row of (fractionally filled) stars.
    case stars
    /// A bold number + a single star glyph.
    case numberRate
    /// A bold number + a sentiment word (e.g. "8.4 Excellent"). `sentiment` text.
    case rateNumberText
}

/// Star rating with two layouts (stars / numeric-leading), continuous fractional
/// fill (display) or half-step interaction, a tappable review count, a custom
/// character and a disabled state. (Reference RatingView parity + interactive.)
public struct Rating: View {
    @Environment(\.theme) private var theme

    private let value: Double
    @Environment(\.isEnabled) private var isEnabled
    // Appearance/config — mutated only through the modifiers below (R2).
    private var layout: RatingLayout = .stars
    private var countLabel: String? = nil
    private var maxValue: Int = 5
    private var size: CGFloat = 16
    private var allowHalf: Bool = false
    private var allowClear: Bool = false
    private var systemImage: String = "star"
    private var sentiment: String? = nil
    private var onRate: ((Double) -> Void)? = nil
    private var onReviewTap: (() -> Void)? = nil

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    public init(value: Double) {   // R1
        self.value = value
    }

    private var interactive: Bool { onRate != nil && isEnabled }

    /// The score rendered with the captured locale (e.g. "4.3" / "4,3").
    private var scoreText: String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// Default sentiment word from the score band when none is supplied.
    private var resolvedSentiment: String {
        if let sentiment { return sentiment }
        let pct = value / Double(maxValue)
        switch pct {
        case 0.9...: return String(themeKit: "Excellent")
        case 0.75..<0.9: return String(themeKit: "Very good")
        case 0.6..<0.75: return String(themeKit: "Good")
        case 0.4..<0.6: return String(themeKit: "Average")
        default: return String(themeKit: "Poor")
        }
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            accessibleRating
            review
        }
        .opacity(isEnabled ? 1 : 0.5)
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: value)
    }

    /// The visual rating glyphs (the star row / number layouts), before any
    /// accessibility treatment.
    @ViewBuilder
    private var ratingGlyphs: some View {
        switch layout {
        case .stars:
            stars
        case .numberRate:
            Text(scoreText)
                .font(.system(size: size * 1.15, weight: .bold))
                .foregroundStyle(theme.text(.textPrimary))
            Image(systemName: "\(systemImage).fill")
                .font(.system(size: size))
                .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
        case .rateNumberText:
            Text(scoreText)
                .font(.system(size: size * 1.15, weight: .bold))
                .foregroundStyle(theme.foreground(.fgSecondary))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(theme.background(.bgHero), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            Text(resolvedSentiment)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(theme.text(.textPrimary))
        }
    }

    /// Collapses the glyph row into one VoiceOver element ("Rating: 4.3 out of
    /// 5"). When interactive, it becomes an adjustable control so VoiceOver users
    /// can swipe up/down to set the score instead of hunting for invisible tap
    /// targets. The color-only fill is never the sole signal.
    @ViewBuilder
    private var accessibleRating: some View {
        let labelled = HStack(spacing: Theme.SpacingKey.xs.value) { ratingGlyphs }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(themeKit: "Rating")))
            .accessibilityValue(Text(accessibilityValueText))
        // Only the star layout has a maxValue-bounded grid and tap targets; the
        // number layouts are display-only (and may carry a 0–10 score that
        // maxValue=5 would wrongly clamp), so they get no adjustable action.
        if interactive && layout == .stars {
            labelled.accessibilityAdjustableAction { direction in
                // Step along the same whole/half-star grid the tap targets use.
                // Direction-aware rounding keeps increment and decrement
                // symmetric for a fractional current value (4.3 → 5 up, → 4 down).
                let step = allowHalf ? 0.5 : 1
                switch direction {
                case .increment:
                    onRate?(min(((value / step).rounded(.down) + 1) * step, Double(maxValue)))
                case .decrement:
                    onRate?(max(((value / step).rounded(.up) - 1) * step, 0))
                @unknown default: break
                }
            }
        } else {
            labelled
        }
    }

    /// Spoken value. Star layouts read "4.3 out of 5"; the number layouts carry a
    /// standalone score (often 0–10), so they read just the score (plus the
    /// sentiment word for `.rateNumberText`) — never a contradictory "/ maxValue".
    /// The review count is intentionally omitted: the sibling `review` element
    /// announces it, so including it here would double it.
    private var accessibilityValueText: String {
        let score = scoreText
        switch layout {
        case .stars:
            return String(themeKit: "\(score) out of \(maxValue)")
        case .numberRate:
            return score
        case .rateNumberText:
            return "\(score), \(resolvedSentiment)"
        }
    }

    // MARK: Stars

    @ViewBuilder
    private var stars: some View {
        if interactive {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(1...maxValue, id: \.self) { index in
                    star(for: index)
                        .font(.system(size: size))
                        .foregroundStyle(color(for: index))
                        .overlay { tapTargets(for: index) }
                }
            }
        } else {
            // Continuous fractional fill for display.
            ZStack(alignment: .leading) {
                row(filled: false)
                row(filled: true).mask(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle().frame(width: geo.size.width * CGFloat(min(max(value / Double(maxValue), 0), 1)))
                    }
                }
            }
        }
    }

    private func row(filled: Bool) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(1...maxValue, id: \.self) { _ in
                Image(systemName: filled ? "\(systemImage).fill" : systemImage)
                    .font(.system(size: size))
                    .foregroundStyle(filled ? theme.foreground(.systemcolorsFgWarning) : theme.border(.borderPrimary))
            }
        }
    }

    @ViewBuilder
    private var review: some View {
        if let countLabel {
            let text = Text(countLabel).textStyle(.bodySm400)
            if let onReviewTap {
                Button(action: onReviewTap) {
                    text.underline().foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
            } else {
                text.foregroundStyle(theme.text(.textTertiary))
            }
        }
    }

    @ViewBuilder
    private func tapTargets(for index: Int) -> some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle())
                .onTapGesture { rate(allowHalf ? Double(index) - 0.5 : Double(index)) }
            Color.clear.contentShape(Rectangle())
                .onTapGesture { rate(Double(index)) }
        }
    }

    /// Routes a tap through the clear-on-repeat rule: re-tapping the current
    /// value resets to 0 when `allowClear` is on (Ant Rate `allowClear`).
    private func rate(_ newValue: Double) {
        onRate?(allowClear && value == newValue ? 0 : newValue)
    }

    private func color(for index: Int) -> Color {
        value >= Double(index) - 0.5
            ? theme.foreground(.systemcolorsFgWarning)
            : theme.border(.borderPrimary)
    }

    private func star(for index: Int) -> Image {
        let v = Double(index)
        if value >= v { return Image(systemName: "\(systemImage).fill") }
        if value >= v - 0.5 {
            return Image(systemName: systemImage == "star" ? "star.leadinghalf.filled" : "\(systemImage).fill")
        }
        return Image(systemName: systemImage)
    }
}

public extension Rating {
    /// Rating presentation: stars / numberRate / rateNumberText (default .stars).
    func layout(_ l: RatingLayout) -> Self { copy { $0.layout = l } }
    /// Review count label shown next to the rating (e.g. "(128)"); `nil` hides it.
    func countLabel(_ text: String?) -> Self { copy { $0.countLabel = text } }
    /// Number of glyphs / the score denominator (default 5).
    func maxValue(_ max: Int) -> Self { copy { $0.maxValue = max } }
    /// Glyph point size (default 16).
    func starSize(_ points: CGFloat) -> Self { copy { $0.size = points } }
    /// Enables half-step interaction (and half-star tap targets).
    func allowHalf(_ on: Bool = true) -> Self { copy { $0.allowHalf = on } }
    /// Re-tapping the current value clears the rating to 0 (Ant Rate
    /// `allowClear`) — interactive star layout only; VoiceOver users reach 0
    /// through the adjustable decrement as before.
    func allowClear(_ on: Bool = true) -> Self { copy { $0.allowClear = on } }
    /// Overrides the SF Symbol used for the glyph (default "star").
    func symbol(_ systemImage: String) -> Self { copy { $0.systemImage = systemImage } }
    /// Sentiment word for the `.rateNumberText` layout (otherwise score-derived).
    func sentiment(_ text: String?) -> Self { copy { $0.sentiment = text } }
    /// Makes the rating interactive: the closure receives the newly tapped value.
    func onRate(_ action: ((Double) -> Void)?) -> Self { copy { $0.onRate = action } }
    /// Makes the review count label a tappable link.
    func onReviewTap(_ action: (() -> Void)?) -> Self { copy { $0.onReviewTap = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var v = 3.5
        var body: some View {
            PreviewMatrix("Rating") {
                PreviewCase("Stars") { Rating(value: 4.3).countLabel("(128)") }                  // continuous fill
                PreviewCase("Number rate") { Rating(value: 4.3).layout(.numberRate).countLabel("1,284 reviews").onReviewTap {} }
                PreviewCase("Rate + sentiment") { Rating(value: 8.4).layout(.rateNumberText).maxValue(10) }
                PreviewCase("Interactive (half)") { Rating(value: v).allowHalf().onRate { v = $0 } }
                PreviewCase("Clear on re-tap") { Rating(value: v).allowClear().onRate { v = $0 } }  // re-tap current value → 0
                PreviewCase("Custom symbol") { Rating(value: 3).symbol("heart") }
            }
        }
    }
    return Demo()
}
