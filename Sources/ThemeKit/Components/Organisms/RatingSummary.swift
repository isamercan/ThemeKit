//
//  RatingSummary.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A review summary row: score badge + qualitative label + review
/// count link. (Star display lives in the Rating atom.)
public struct RatingSummary: View {
    @Environment(\.theme) private var theme

    private let score: Double

    // Appearance/config — mutated only through the modifiers below (R2).
    private var label: String? = nil
    private var reviewCount: Int? = nil
    private var onReviews: (() -> Void)? = nil

    public init(score: Double) {   // R1
        self.score = score
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ScoreBadge(score)
            if let label {
                Text(label)
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let reviewCount {
                Button { onReviews?() } label: {
                    HStack(spacing: 4) {
                        Text("\(reviewCount) reviews").textStyle(.linkSm)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                            .mirrorsInRTL()
                    }
                    .foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
                .disabled(onReviews == nil)
            }
        }
        // Fold the score badge, qualitative label, and review-count link into one
        // VoiceOver element so the rating is announced as a single phrase.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(themeKit: "Rating")))
        .accessibilityValue(Text(accessibilityValueText))
    }

    /// Spoken value — the numeric score, then the qualitative label and review
    /// count when present (e.g. "9.0, Excellent, 1200 reviews").
    private var accessibilityValueText: String {
        var parts: [String] = [String(format: "%.1f", score)]
        if let label { parts.append(label) }
        if let reviewCount { parts.append(String(themeKit: "\(reviewCount) reviews")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RatingSummary {
    /// Qualitative label shown next to the score badge (e.g. "Excellent").
    func label(_ text: String?) -> Self { copy { $0.label = text } }

    /// Review-count link and its tap handler (link is disabled without a handler).
    func reviews(count: Int?, onTap: (() -> Void)? = nil) -> Self {
        copy { $0.reviewCount = count; $0.onReviews = onTap }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        RatingSummary(score: 9.0).label("Excellent").reviews(count: 1200, onTap: {})
        RatingSummary(score: 8.5).label("Very Good").reviews(count: 340)
        RatingSummary(score: 9.8).label("Excellent")
    }
    .padding()
}
