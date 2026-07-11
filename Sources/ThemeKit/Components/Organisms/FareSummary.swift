//
//  FareSummary.swift
//  ThemeKit
//
//  An itemised price breakdown — base fare, taxes/fees, discounts, and an emphasised
//  total. Token-bound; discounts read green, the total is a hero PriceTag.
//
//  Flexible: per-line info buttons (.onInfo), a footer slot (a note or CTA), an
//  animated total, and density-aware spacing. Honours `.redacted(.placeholder)`.
//

import SwiftUI

/// A token-bound fare breakdown.
///
/// ```swift
/// FareSummary([
///     .item("Base fare", 1_100),
///     .item("Taxes & fees", 199, info: "Airport tax + carrier surcharge"),
///     .discount("Member discount", 100),
///     .total("Total", 1_199),
/// ]).onInfo { line in showSheet(line.info) } footer: { TermsLink() }
/// ```
public struct FareSummary: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let lines: [FareLine]
    private let currencyCode: String?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var onInfoHandler: ((FareLine) -> Void)?
    private var footerSlot: AnyView?

    public init(_ lines: [FareLine], currencyCode: String = "USD") {   // R1 — content
        self.lines = lines
        self.currencyCode = currencyCode
    }

    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    public init(_ lines: [FareLine]) {   // R1 — content
        self.lines = lines
        self.currencyCode = nil
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            // Position-keyed: robust to duplicate labels (two "Fee" lines) which would
            // collide on the content-derived `id`. Fare lists are fixed-order, so index is stable.
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line.kind {
                case .item:     itemRow(line, value: formatted(line.amount), color: theme.text(.textSecondary), valueColor: theme.text(.textPrimary))
                case .discount: itemRow(line, value: "-\(formatted(line.amount))", color: theme.foreground(.systemcolorsFgSuccess), valueColor: theme.foreground(.systemcolorsFgSuccess))
                case .total:    totalRow(line)
                }
            }
            if let footerSlot { footerSlot }
        }
    }

    private func itemRow(_ line: FareLine, value: String, color: Color, valueColor: Color) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(line.label).textStyle(.bodyBase400).foregroundStyle(color)
            if line.info != nil, let onInfoHandler {
                Button { onInfoHandler(line) } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "More about \(line.label)"))
            }
            Spacer()
            Text(value).textStyle(.bodyBase500).foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.label) \(value)")
    }

    private func totalRow(_ line: FareLine) -> some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Divider().overlay(theme.border(.borderPrimary))
            HStack {
                Text(line.label).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                PriceTag(line.amount, currencyCode: resolvedCurrency).size(.large).emphasis(.hero).animatesValue()
            }
        }
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareSummary {
    /// Called when a line's info button is tapped (only lines created with `info:` show one).
    func onInfo(_ handler: @escaping (FareLine) -> Void) -> Self { copy { $0.onInfoHandler = handler } }
    /// A footer slot under the total — a terms link, a CTA, a note.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    FareSummary([
        .item("Base fare", 1_100),
        .item("Taxes & fees", 199, info: "Airport tax + carrier surcharge"),
        .discount("Member discount", 100),
        .total("Total", 1_199),
    ])
    .onInfo { _ in }
    .padding()
}
