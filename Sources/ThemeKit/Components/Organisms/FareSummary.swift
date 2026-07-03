//
//  FareSummary.swift
//  ThemeKit
//
//  An itemised price breakdown — base fare, taxes/fees, discounts, and an emphasised
//  total. Token-bound; discounts read green, the total is a hero PriceTag.
//

import SwiftUI

/// One line of a ``FareSummary``.
public struct FareLine: Identifiable, Sendable {
    public enum Kind: Sendable { case item, discount, total }
    public let id = UUID()
    let label: String
    let amount: Decimal
    let kind: Kind

    /// A regular charge (base fare, taxes, a service fee…).
    public static func item(_ label: String, _ amount: Decimal) -> FareLine { .init(label: label, amount: amount, kind: .item) }
    /// A saving — rendered green with a leading minus.
    public static func discount(_ label: String, _ amount: Decimal) -> FareLine { .init(label: label, amount: amount, kind: .discount) }
    /// The emphasised total — rendered as a hero `PriceTag` under a divider.
    public static func total(_ label: String, _ amount: Decimal) -> FareLine { .init(label: label, amount: amount, kind: .total) }
}

/// A token-bound fare breakdown.
///
/// ```swift
/// FareSummary([
///     .item("Base fare", 1_100),
///     .item("Taxes & fees", 199),
///     .discount("Member discount", 100),
///     .total("Total", 1_199),
/// ])
/// ```
public struct FareSummary: View {
    @Environment(\.theme) private var theme

    private let lines: [FareLine]
    private let currencyCode: String

    public init(_ lines: [FareLine], currencyCode: String = "TRY") {   // R1 — content
        self.lines = lines
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(lines) { line in
                switch line.kind {
                case .item:     row(line.label, formatted(line.amount), labelColor: theme.text(.textSecondary), valueColor: theme.text(.textPrimary))
                case .discount: row(line.label, "-\(formatted(line.amount))", labelColor: theme.foreground(.systemcolorsFgSuccess), valueColor: theme.foreground(.systemcolorsFgSuccess))
                case .total:    totalRow(line)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String, labelColor: Color, valueColor: Color) -> some View {
        HStack {
            Text(label).textStyle(.bodyBase400).foregroundStyle(labelColor)
            Spacer()
            Text(value).textStyle(.bodyBase500).foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func totalRow(_ line: FareLine) -> some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            Divider().overlay(theme.border(.borderPrimary))
            HStack {
                Text(line.label).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                PriceTag(line.amount, currencyCode: currencyCode).size(.large).emphasis(.hero)
            }
        }
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }
}

#Preview {
    FareSummary([
        .item("Base fare", 1_100),
        .item("Taxes & fees", 199),
        .discount("Member discount", 100),
        .total("Total", 1_199),
    ])
    .padding()
}
