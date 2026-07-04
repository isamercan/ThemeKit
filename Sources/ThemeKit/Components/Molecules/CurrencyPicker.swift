//
//  CurrencyPicker.swift
//  ThemeKit
//
//  A currency chooser — flag, ISO code, name and symbol, with the selected row ticked.
//  Token-bound. Ships a `Currency.common` list; pass your own for more.
//
//  Flexible: optional search, a Recent section, derived country flags, density-aware rows.
//

import SwiftUI

/// One currency option.
public struct Currency: Identifiable, Sendable, Hashable {
    public var id: String { code }
    public let code: String
    public let symbol: String
    public let name: String

    public init(code: String, symbol: String, name: String) {
        self.code = code
        self.symbol = symbol
        self.name = name
    }

    /// A flag emoji derived from the first two letters of the ISO code
    /// (TRY → 🇹🇷, USD → 🇺🇸, EUR → 🇪🇺).
    public var flag: String {
        let base: UInt32 = 127_397   // regional-indicator 🇦 minus ASCII 'A'
        var out = ""
        for scalar in code.prefix(2).uppercased().unicodeScalars {
            if let v = UnicodeScalar(base + scalar.value) { out.unicodeScalars.append(v) }
        }
        return out
    }

    /// A small ready-made set for quick use.
    public static let common: [Currency] = [
        Currency(code: "TRY", symbol: "₺", name: "Turkish Lira"),
        Currency(code: "USD", symbol: "$", name: "US Dollar"),
        Currency(code: "EUR", symbol: "€", name: "Euro"),
        Currency(code: "GBP", symbol: "£", name: "British Pound"),
    ]
}

/// A token-bound currency picker.
///
/// ```swift
/// CurrencyPicker(selection: $code).searchable().recents([.init(code: "USD", symbol: "$", name: "US Dollar")])
/// ```
public struct CurrencyPicker: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @State private var searchText = ""

    @Binding private var selection: String
    private let currencies: [Currency]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var showsName: Bool = true
    private var isSearchable: Bool = false
    private var recents: [Currency] = []

    public init(selection: Binding<String>, currencies: [Currency] = Currency.common) {
        self._selection = selection
        self.currencies = currencies
    }

    private var filtered: [Currency] {
        guard !searchText.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    private var showsRecents: Bool { !recents.isEmpty && searchText.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSearchable {
                SearchBar(text: $searchText).padding(.bottom, density.scale(Theme.SpacingKey.sm.value))
            }
            if showsRecents {
                sectionHeader("Recent")
                list(recents)
                sectionHeader("All currencies")
            }
            list(filtered)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            .padding(.top, density.scale(Theme.SpacingKey.sm.value))
            .padding(.bottom, 2)
    }

    private func list(_ items: [Currency]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, currency in
                if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                row(currency)
            }
        }
    }

    private func row(_ currency: Currency) -> some View {
        let selected = selection == currency.code
        return Button { selection = currency.code } label: {
            HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                Text(currency.flag).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if showsName {
                        Text(currency.name).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer()
                Text(currency.symbol).textStyle(.labelMd600).foregroundStyle(theme.text(.textSecondary))
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.foreground(.fgHero))
                }
            }
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CurrencyPicker {
    /// Shows the full currency name under the code (default true).
    func showsName(_ on: Bool) -> Self { copy { $0.showsName = on } }
    /// Adds a search field that filters by code or name.
    func searchable(_ on: Bool = true) -> Self { copy { $0.isSearchable = on } }
    /// A "Recent" section shown above the full list (hidden while searching).
    func recents(_ currencies: [Currency]) -> Self { copy { $0.recents = currencies } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var code = "TRY"
        var body: some View {
            CurrencyPicker(selection: $code)
                .searchable()
                .recents([Currency(code: "USD", symbol: "$", name: "US Dollar")])
                .padding()
        }
    }
    return Demo()
}
