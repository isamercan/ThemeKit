//
//  FareFeatureRow.swift
//  ThemeKit
//
//  Atom. One icon + label line describing a fare feature or rule — baggage
//  allowances, refund/change policies, amenities. An `included` / `excluded` /
//  `info` status tints it. Composed by ``FareFamilyCard`` and fare-detail panels.
//

import SwiftUI

public struct FareFeatureRow: View {
    @Environment(\.theme) private var theme
    private let feature: FareFeature

    // Appearance — mutated only through the modifiers below (R2).
    private var iconOverride: String?
    private var accent: SemanticColor?

    public init(_ feature: FareFeature) { self.feature = feature }
    public init(_ text: String, systemImage: String, detail: String? = nil, status: FareFeatureStatus = .info) {
        self.feature = FareFeature(text, systemImage: systemImage, detail: detail, status: status)
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Image(systemName: iconOverride ?? feature.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 20)
            HStack(spacing: 4) {
                Text(feature.text).textStyle(.bodySm400).foregroundStyle(textColor)
                if let detail = feature.detail {
                    Text(detail).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feature.status == .excluded ? feature.text + ", " + String(themeKit: "not included") : feature.text)
    }

    private var iconColor: Color {
        if let accent { return theme.resolve(accent).accent }
        switch feature.status {
        case .included: return theme.foreground(.systemcolorsFgSuccess)
        case .excluded: return theme.text(.textTertiary)
        case .info: return theme.text(.textSecondary)
        }
    }
    private var textColor: Color {
        feature.status == .excluded ? theme.text(.textTertiary) : theme.text(.textPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareFeatureRow {
    /// Overrides the feature model's SF Symbol; `nil` restores the model's own icon.
    func icon(_ systemName: String?) -> Self { copy { $0.iconOverride = systemName } }
    /// Token-fed icon tint; `nil` keeps the status-driven colour.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("FareFeatureRow") {
        PreviewCase("Info + detail") {
            FareFeatureRow("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm")
        }
        PreviewCase("Included") {
            FareFeatureRow("Checked bag", systemImage: "suitcase.fill", detail: "1 × 20 kg", status: .included)
        }
        PreviewCase("Excluded") {
            FareFeatureRow("Non-refundable", systemImage: "nosign", status: .excluded)
        }
        PreviewCase("Icon override + accent") {
            FareFeatureRow("Priority boarding", systemImage: "figure.walk")
                .icon("hare.fill")
                .accent(.purple)
        }
        PreviewCase("Long text") {
            FareFeatureRow("Complimentary in-flight refreshments and beverages on all sectors", systemImage: "cup.and.saucer.fill", status: .included)
        }
    }
}
