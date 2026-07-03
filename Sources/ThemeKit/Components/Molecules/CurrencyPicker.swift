//
//  CurrencyPicker.swift
//  ThemeKit
//
//  A currency chooser — symbol badge, ISO code and name, with the selected row ticked.
//  Token-bound. Ships a `Currency.common` list; pass your own for more.
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
/// CurrencyPicker(selection: $code, currencies: Currency.common)
/// ```
public struct CurrencyPicker: View {
    @Environment(\.theme) private var theme

    @Binding private var selection: String
    private let currencies: [Currency]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var showsName: Bool = true

    public init(selection: Binding<String>, currencies: [Currency] = Currency.common) {
        self._selection = selection
        self.currencies = currencies
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(currencies.enumerated()), id: \.element.id) { index, currency in
                if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                row(currency)
            }
        }
    }

    private func row(_ currency: Currency) -> some View {
        let selected = selection == currency.code
        return Button { selection = currency.code } label: {
            HStack(spacing: Theme.SpacingKey.md.value) {
                Text(currency.symbol)
                    .textStyle(.labelMd700)
                    .foregroundStyle(theme.foreground(.fgHero))
                    .frame(width: 36, height: 36)
                    .background(theme.background(.bgSecondaryLight), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if showsName {
                        Text(currency.name).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.foreground(.fgHero))
                }
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CurrencyPicker {
    /// Shows the full currency name under the code (default true).
    func showsName(_ on: Bool) -> Self { copy { $0.showsName = on } }

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
            CurrencyPicker(selection: $code).padding()
        }
    }
    return Demo()
}
