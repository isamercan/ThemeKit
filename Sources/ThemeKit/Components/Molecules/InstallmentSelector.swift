//
//  InstallmentSelector.swift
//  ThemeKit
//
//  Pick an instalment plan for a total (single payment · 3 · 6 · 12…). Each option
//  shows the per-month amount and an optional interest-free tag. Token-bound; the
//  selected option is accent-outlined.
//

import SwiftUI

/// A token-bound instalment plan picker.
///
/// ```swift
/// InstallmentSelector(total: 12_000, options: [1, 3, 6, 12], selection: $months)
///     .interestFreeUpTo(3)
/// ```
public struct InstallmentSelector: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let total: Decimal
    private let options: [Int]
    @Binding private var selection: Int
    private let currencyCode: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var interestFreeUpTo: Int = 0
    private var recommendedCount: Int?
    private var surcharge: [Int: Decimal] = [:]

    public init(total: Decimal, options: [Int], selection: Binding<Int>, currencyCode: String = "TRY") {
        self.total = total
        self.options = options
        self._selection = selection
        self.currencyCode = currencyCode
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(options, id: \.self) { count in
                row(count)
            }
        }
    }

    private func row(_ count: Int) -> some View {
        let selected = selection == count
        let planTotal = effectiveTotal(count)
        let interestFree = count > 1 && count <= interestFreeUpTo && (surcharge[count] ?? 0) == 0
        return Button {
            withAnimation(Animation.snappy.ifMotionAllowed(reduceMotion)) { selection = count }
        } label: {
            HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.foreground(.fgHero) : theme.text(.textTertiary))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Text(count <= 1 ? "Single payment" : "\(count) installments")
                            .textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                        if count == recommendedCount {
                            Badge("Recommended").badgeStyle(.success).size(.small)
                        }
                    }
                    if interestFree {
                        Text("Interest-free").textStyle(.bodySm400).foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if count > 1 {
                        Text("\(formatted(planTotal / Decimal(count)))/mo")
                            .textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    }
                    Text(formatted(planTotal)).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                }
            }
            .padding(density.scale(Theme.SpacingKey.md.value))
            .background(selected ? theme.background(.bgHero) : theme.background(.bgBase),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                .stroke(selected ? theme.foreground(.fgHero) : theme.border(.borderPrimary), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    /// The plan's grand total — base plus any per-plan surcharge (interest).
    private func effectiveTotal(_ count: Int) -> Decimal { total + (surcharge[count] ?? 0) }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InstallmentSelector {
    /// Instalment counts up to (and including) this are tagged "Interest-free".
    func interestFreeUpTo(_ count: Int) -> Self { copy { $0.interestFreeUpTo = count } }
    /// Flags one plan as recommended with a badge.
    func recommended(_ count: Int) -> Self { copy { $0.recommendedCount = count } }
    /// Per-plan surcharge (interest) added to the base total, keyed by instalment count.
    func surcharge(_ amounts: [Int: Decimal]) -> Self { copy { $0.surcharge = amounts } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var months = 3
        var body: some View {
            InstallmentSelector(total: 12_000, options: [1, 3, 6, 12], selection: $months)
                .interestFreeUpTo(3)
                .padding()
        }
    }
    return Demo()
}
