//
//  FormatDefaults.swift
//  ThemeKit
//
//  A subtree-level "house style" for formatting — the app-wide currency code that
//  price-bearing components use when a call site doesn't pass one. Set it once with
//  `.formatDefaults(...)` and components read it as their default. Additive and
//  Open/Closed: a per-call argument still wins; this only fills the default.
//
//  Resolution chain (per §10): explicit argument > formatDefaults.currencyCode
//  > locale.themeKitCurrencyCode > "USD".
//
//  ```swift
//  BookingScreen()
//      .formatDefaults(currencyCode: "EUR")
//  ```
//

import SwiftUI

public struct FormatDefaults: Equatable, Sendable {
    /// ISO-4217 code price components use when a call site doesn't pass one.
    public var currencyCode: String?
    public init(currencyCode: String? = nil) { self.currencyCode = currencyCode }
}

private struct FormatDefaultsKey: EnvironmentKey {
    static let defaultValue = FormatDefaults()
}

public extension EnvironmentValues {
    var formatDefaults: FormatDefaults {
        get { self[FormatDefaultsKey.self] }
        set { self[FormatDefaultsKey.self] = newValue }
    }
}

public extension View {
    /// House formatting defaults for this subtree. Per-call arguments still win.
    func formatDefaults(currencyCode: String? = nil) -> some View {
        transformEnvironment(\.formatDefaults) { d in
            if let currencyCode { d.currencyCode = currencyCode }
        }
    }
}
