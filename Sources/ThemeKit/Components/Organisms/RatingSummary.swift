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
    private let label: String?
    private let reviewCount: Int?
    private let onReviews: (() -> Void)?

    public init(score: Double, label: String? = nil, reviewCount: Int? = nil, onReviews: (() -> Void)? = nil) {
        self.score = score
        self.label = label
        self.reviewCount = reviewCount
        self.onReviews = onReviews
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
    }
}

#Preview {
    VStack(spacing: 12) {
        RatingSummary(score: 9.0, label: "Excellent", reviewCount: 1200, onReviews: {})
        RatingSummary(score: 8.5, label: "Very Good", reviewCount: 340)
        RatingSummary(score: 9.8, label: "Excellent")
    }
    .padding()
}
