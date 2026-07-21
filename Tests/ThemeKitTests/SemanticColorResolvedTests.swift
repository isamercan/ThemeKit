//
//  SemanticColorResolvedTests.swift
//  ThemeKit
//
//  ADR-0006 Phase 0 — proves `SemanticColor.Resolved` / `theme.resolve(_:)`:
//  1) two independently-configured `Theme` instances resolve DIFFERENT accents
//     (the per-subtree isolation the resolver exists to deliver);
//  2) the still-shipping zero-arg `SemanticColor` accessors stay byte-identical
//     to `theme.resolve(_:)` when resolved against `Theme.shared` — the
//     backward-compatibility guarantee (no call site anywhere regresses);
//  3) `SemanticColor.Resolved` is usable across a `Sendable` boundary.
//
//  Cross-platform (iOS + macOS) — pure value-level assertions, no hosting.
//

import SwiftUI
import XCTest
@testable import ThemeKit
@testable import ThemeKitCore

@MainActor
final class SemanticColorResolvedTests: XCTestCase {
    /// sRGB components, so two `Color`s can be compared for equality reliably
    /// (mirrors `ColorContrast.components(of:)`'s platform bridge —
    /// `Color.resolve(in:)` is iOS 17+ and the test target builds at the
    /// 15.6 floor, ADR-0007 §D3).
    private func rgba(_ c: Color) -> [Double] {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map(Double.init)
        #elseif canImport(AppKit)
        guard let srgb = NSColor(c).usingColorSpace(.sRGB) else { return [0, 0, 0, 0] }
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent].map(Double.init)
        #else
        return [0, 0, 0, 0]
        #endif
    }

    private func makeTheme(primaryHex: String, accentHex: String) -> Theme {
        let theme = Theme()
        theme.apply(ThemeConfig(primaryHex: primaryHex, accentHex: accentHex))
        return theme
    }

    // MARK: - The isolation the ADR promises

    func testTwoThemesResolveDistinctAccentSolid() {
        let themeA = makeTheme(primaryHex: "d81b60", accentHex: "d81b60")
        let themeB = makeTheme(primaryHex: "1e88e5", accentHex: "1e88e5")

        XCTAssertNotEqual(rgba(themeA.resolve(.accent).solid), rgba(themeB.resolve(.accent).solid),
                          "theme.resolve(.accent).solid must vary with the theme it's resolved against")
        XCTAssertNotEqual(rgba(themeA.resolve(.primary).solid), rgba(themeB.resolve(.primary).solid),
                          "theme.resolve(.primary).solid must vary with the theme it's resolved against")
    }

    func testResolvedMatchesTheThemesOwnInstanceAccessorsForANonBrandRole() {
        // `.info` isn't brand-derived — resolving it through a specific theme
        // must equal that SAME theme's own token accessor for the mapped key.
        let themeA = makeTheme(primaryHex: "2e7d32", accentHex: "2e7d32")
        XCTAssertEqual(rgba(themeA.resolve(.info).bg), rgba(themeA.palette(.init(rawValue: "palette.info.50")!)))
    }

    // MARK: - Backward-compat guarantee (D2 / no behavior change for un-migrated call sites)

    /// Deliberately exercises the deprecated zero-arg accessors — this IS the
    /// forward-equivalence guarantee ADR-0006 (D2) promises, so the warnings
    /// here are expected, not a migration gap.
    @available(*, deprecated, message: "Intentionally tests the deprecated SemanticColor accessors — see ADR-0006 D2.")
    func testDeprecatedZeroArgAccessorsMatchResolvedAgainstThemeShared() {
        for color in SemanticColor.allCases {
            XCTAssertEqual(rgba(color.solid), rgba(Theme.shared.resolve(color).solid), "\(color).solid mismatch")
            XCTAssertEqual(rgba(color.soft), rgba(Theme.shared.resolve(color).soft), "\(color).soft mismatch")
            XCTAssertEqual(rgba(color.accent), rgba(Theme.shared.resolve(color).accent), "\(color).accent mismatch")
            XCTAssertEqual(rgba(color.border), rgba(Theme.shared.resolve(color).border), "\(color).border mismatch")
            XCTAssertEqual(rgba(color.onSolid), rgba(Theme.shared.resolve(color).onSolid), "\(color).onSolid mismatch")
            XCTAssertEqual(rgba(color.base), rgba(Theme.shared.resolve(color).base), "\(color).base mismatch")
            for step in SemanticColor.Shade.allCases {
                XCTAssertEqual(rgba(color.shade(step)), rgba(Theme.shared.resolve(color).shade(step)),
                               "\(color).shade(\(step)) mismatch")
            }
        }
    }

    // MARK: - Sendable usability (compile-time proof; Swift 6 mode)

    func testResolvedCrossesAnIsolationBoundary() async {
        let resolved = Theme.shared.resolve(.primary)
        let solid = await Task { resolved.solid }.value
        XCTAssertEqual(rgba(solid), rgba(resolved.solid))
    }
}
