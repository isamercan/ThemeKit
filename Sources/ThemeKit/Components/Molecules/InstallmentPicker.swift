//
//  InstallmentPicker.swift
//  ThemeKit
//
//  Molecule. An instalment ("taksit") selector — a radio list of options, each with
//  a title, a per-month amount and a total. Selection is a single `Int` (the chosen
//  instalment count) owned by the caller. Token-bound.
//
//  ```swift
//  InstallmentPicker([InstallmentOption(count: 1, total: 9_600),
//                     InstallmentOption(count: 3, total: 9_900, monthly: 3_300)],
//                    selection: $count).currency("USD")
//  ```
//

import SwiftUI

/// One instalment plan in an ``InstallmentPicker``.
public struct InstallmentOption: Identifiable, Sendable {
    public var id: Int { count }
    public let count: Int          // 1 = single payment
    public let total: Decimal
    public let monthly: Decimal?
    public let label: String?
    public init(count: Int, total: Decimal, monthly: Decimal? = nil, label: String? = nil) {
        self.count = count
        self.total = total
        self.monthly = monthly
        self.label = label
    }
}

public struct InstallmentPicker: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let options: [InstallmentOption]
    @Binding private var selection: Int
    // Config — mutated only through the modifiers below (R2).
    private var currencyCode: String?
    private var accent: SemanticColor?

    public init(_ options: [InstallmentOption], selection: Binding<Int>) {   // R1
        self.options = options
        self._selection = selection
    }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private var accentBase: Color { (accent ?? .primary).base }
    private func money(_ d: Decimal) -> String { d.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale)) }
    private func title(_ o: InstallmentOption) -> String { o.label ?? (o.count <= 1 ? String(themeKit: "Single payment") : String(themeKit: "\(o.count) installments")) }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            ForEach(options) { option in row(option) }
        }
    }

    private func row(_ option: InstallmentOption) -> some View {
        let isOn = option.count == selection
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        return Button { selection = option.count } label: {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(isOn ? accentBase : theme.text(.textTertiary))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(option)).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if let monthly = option.monthly, option.count > 1 {
                        Text("\(money(monthly)) × \(option.count)").textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer()
                Text(money(option.total)).textStyle(.labelBase700).foregroundStyle(isOn ? accentBase : theme.text(.textPrimary))
            }
            .padding(.horizontal, density.scale(Theme.SpacingKey.md.value))
            .frame(minHeight: 56)
            .background(isOn ? (accent ?? .primary).bg : theme.background(.bgBase), in: shape)
            .overlay(shape.stroke(isOn ? accentBase : theme.border(.borderPrimary), lineWidth: isOn ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(option)), \(money(option.total))")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InstallmentPicker {
    /// Currency code for the amounts. Unset, it resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel = 1
        var body: some View {
            InstallmentPicker([
                InstallmentOption(count: 1, total: 9_600),
                InstallmentOption(count: 3, total: 9_900, monthly: 3_300),
                InstallmentOption(count: 6, total: 10_200, monthly: 1_700),
            ], selection: $sel).padding()
        }
    }
    return Demo()
}
