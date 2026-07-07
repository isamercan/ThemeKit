//
//  FareFeatureRow.swift
//  ThemeKit
//
//  Atom. One icon + label line describing a fare feature or rule — baggage
//  allowances, refund/change policies, amenities. An `included` / `excluded` /
//  `info` status tints it. Composed by ``FareFamilyCard`` and fare-detail panels.
//

import SwiftUI

/// Whether a fare feature is granted, denied, or neutral info.
public enum FareFeatureStatus: Sendable { case included, excluded, info }

/// A single fare feature / rule line.
public struct FareFeature: Identifiable, Sendable {
    public var id: String { "\(systemImage):\(text)" }
    public let text: String
    public let systemImage: String
    public let detail: String?
    public let status: FareFeatureStatus
    public init(_ text: String, systemImage: String, detail: String? = nil, status: FareFeatureStatus = .info) {
        self.text = text
        self.systemImage = systemImage
        self.detail = detail
        self.status = status
    }
}

public struct FareFeatureRow: View {
    @Environment(\.theme) private var theme
    private let feature: FareFeature

    public init(_ feature: FareFeature) { self.feature = feature }
    public init(_ text: String, systemImage: String, detail: String? = nil, status: FareFeatureStatus = .info) {
        self.feature = FareFeature(text, systemImage: systemImage, detail: detail, status: status)
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Image(systemName: feature.systemImage)
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
        .accessibilityLabel("\(feature.text)\(feature.status == .excluded ? ", not included" : "")")
    }

    private var iconColor: Color {
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

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FareFeatureRow("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm")
        FareFeatureRow("Checked bag", systemImage: "suitcase.fill", detail: "1 × 20 kg", status: .included)
        FareFeatureRow("Non-refundable", systemImage: "nosign", status: .excluded)
        FareFeatureRow("Partial refund", systemImage: "arrow.uturn.backward", status: .included)
    }
    .padding()
}
