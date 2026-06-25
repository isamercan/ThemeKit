//
//  Rating.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Star rating with two layouts (stars / numeric-leading), continuous fractional
//  fill (display) or half-step interaction, a tappable review count, a custom
//  character and a disabled state. (Reference RatingView parity + interactive.)
//

import SwiftUI

/// Rating presentation. (Reference RatingType parity.)
public enum RatingLayout {
    /// A row of (fractionally filled) stars.
    case stars
    /// A bold number + a single star glyph.
    case numberRate
    /// A bold number + a sentiment word (e.g. "8.4 Mükemmel"). `sentiment` text.
    case rateNumberText
}

public struct Rating: View {
    private let value: Double
    private let maxValue: Int
    private let size: CGFloat
    private let layout: RatingLayout
    private let allowHalf: Bool
    private let isEnabled: Bool
    private let systemImage: String
    private let countLabel: String?
    private let sentiment: String?
    private let onRate: ((Double) -> Void)?
    private let onReviewTap: (() -> Void)?

    public init(
        value: Double,
        maxValue: Int = 5,
        size: CGFloat = 16,
        layout: RatingLayout = .stars,
        allowHalf: Bool = false,
        isEnabled: Bool = true,
        systemImage: String = "star",
        countLabel: String? = nil,
        sentiment: String? = nil,
        onRate: ((Double) -> Void)? = nil,
        onReviewTap: (() -> Void)? = nil
    ) {
        self.value = value
        self.maxValue = maxValue
        self.size = size
        self.layout = layout
        self.allowHalf = allowHalf
        self.isEnabled = isEnabled
        self.systemImage = systemImage
        self.countLabel = countLabel
        self.sentiment = sentiment
        self.onRate = onRate
        self.onReviewTap = onReviewTap
    }

    private var interactive: Bool { onRate != nil && isEnabled }

    /// Default sentiment word from the score band when none is supplied.
    private var resolvedSentiment: String {
        if let sentiment { return sentiment }
        let pct = value / Double(maxValue)
        switch pct {
        case 0.9...: return String(globalUIComponents: "Excellent")
        case 0.75..<0.9: return String(globalUIComponents: "Very good")
        case 0.6..<0.75: return String(globalUIComponents: "Good")
        case 0.4..<0.6: return String(globalUIComponents: "Average")
        default: return String(globalUIComponents: "Poor")
        }
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            accessibleRating
            review
        }
        .opacity(isEnabled ? 1 : 0.5)
    }

    /// The visual rating glyphs (the star row / number layouts), before any
    /// accessibility treatment.
    @ViewBuilder
    private var ratingGlyphs: some View {
        switch layout {
        case .stars:
            stars
        case .numberRate:
            Text(String(format: "%.1f", value))
                .font(.system(size: size * 1.15, weight: .bold))
                .foregroundStyle(Theme.shared.text(.textPrimary))
            Image(systemName: "\(systemImage).fill")
                .font(.system(size: size))
                .foregroundStyle(Theme.shared.foreground(.systemcolorsFgWarning))
        case .rateNumberText:
            Text(String(format: "%.1f", value))
                .font(.system(size: size * 1.15, weight: .bold))
                .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.shared.background(.bgHero), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            Text(resolvedSentiment)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.shared.text(.textPrimary))
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
            .accessibilityLabel(Text(String(globalUIComponents: "Rating")))
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
        let score = String(format: "%.1f", value)
        switch layout {
        case .stars:
            return String(globalUIComponents: "\(score) out of \(maxValue)")
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
                    .foregroundStyle(filled ? Theme.shared.foreground(.systemcolorsFgWarning) : Theme.shared.border(.borderPrimary))
            }
        }
    }

    @ViewBuilder
    private var review: some View {
        if let countLabel {
            let text = Text(countLabel).textStyle(.bodySm400)
            if let onReviewTap {
                Button(action: onReviewTap) {
                    text.underline().foregroundStyle(Theme.shared.text(.textHero))
                }
                .buttonStyle(.plain)
            } else {
                text.foregroundStyle(Theme.shared.text(.textTertiary))
            }
        }
    }

    @ViewBuilder
    private func tapTargets(for index: Int) -> some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle())
                .onTapGesture { onRate?(allowHalf ? Double(index) - 0.5 : Double(index)) }
            Color.clear.contentShape(Rectangle())
                .onTapGesture { onRate?(Double(index)) }
        }
    }

    private func color(for index: Int) -> Color {
        value >= Double(index) - 0.5
            ? Theme.shared.foreground(.systemcolorsFgWarning)
            : Theme.shared.border(.borderPrimary)
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

#Preview {
    struct Demo: View {
        @State var v = 3.5
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Rating(value: 4.3, countLabel: "(128)")                                  // continuous fill
                Rating(value: 4.3, layout: .numberRate, countLabel: "1.284 yorum", onReviewTap: {})  // numeric + tappable review
                Rating(value: v, allowHalf: true) { v = $0 }                              // interactive
                Rating(value: 3, systemImage: "heart")
            }
            .padding()
        }
    }
    return Demo()
}
