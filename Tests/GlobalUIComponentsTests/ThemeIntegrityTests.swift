//
//  ThemeIntegrityTests.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Guards the bundled theme JSON: every theme loads, defines the same token set
//  as the default (so none is missing a token), dark differs from light, and the
//  type ramp resolves cleanly.
//

import XCTest
import SwiftUI
@testable import GlobalUIComponents

final class ThemeIntegrityTests: XCTestCase {
    private let bundledThemes = ["defaultTheme", "oceanTheme", "sunsetTheme"]

    // Names of the tokens a theme actually resolves (non-clear).
    private func resolvedKeys(_ t: Theme) -> (fg: Set<String>, bg: Set<String>, border: Set<String>, text: Set<String>) {
        ( Set(Theme.ForegroundColorKey.allCases.filter { t.foreground($0) != .clear }.map(\.rawValue)),
          Set(Theme.BackgroundColorKey.allCases.filter { t.background($0) != .clear }.map(\.rawValue)),
          Set(Theme.BorderColorKey.allCases.filter { t.border($0) != .clear }.map(\.rawValue)),
          Set(Theme.TextColorKey.allCases.filter { t.text($0) != .clear }.map(\.rawValue)) )
    }

    func testEveryBundledThemeDefinesTheSameTokenSet() {
        let base = Theme(); base.loadTheme(named: "defaultTheme")
        let expected = resolvedKeys(base)
        XCTAssertFalse(expected.fg.isEmpty, "default theme resolves no foreground tokens")

        let t = Theme()
        for name in bundledThemes {
            t.loadTheme(named: name)
            let got = resolvedKeys(t)
            XCTAssertEqual(got.fg, expected.fg, "\(name) foreground tokens differ from default")
            XCTAssertEqual(got.bg, expected.bg, "\(name) background tokens differ from default")
            XCTAssertEqual(got.border, expected.border, "\(name) border tokens differ from default")
            XCTAssertEqual(got.text, expected.text, "\(name) text tokens differ from default")
        }
    }

    func testCriticalTokensResolveForEveryThemeAndVariant() {
        let t = Theme()
        for name in bundledThemes {
            for dark in [false, true] {
                t.loadTheme(named: name, dark: dark)
                let tag = "\(name)\(dark ? "Dark" : "")"
                XCTAssertNotEqual(t.foreground(.fgHero), .clear, "\(tag) fgHero")
                XCTAssertNotEqual(t.background(.bgHero), .clear, "\(tag) bgHero")
                XCTAssertNotEqual(t.text(.textPrimary), .clear, "\(tag) textPrimary")
                XCTAssertNotEqual(t.border(.borderHero), .clear, "\(tag) borderHero")
            }
        }
    }

    func testDarkVariantDiffersFromLight() {
        let t = Theme()
        t.loadTheme(named: "defaultTheme", dark: false)
        let lightWhite = t.background(.bgWhite)
        let lightText = t.text(.textPrimary)
        t.loadTheme(named: "defaultTheme", dark: true)
        XCTAssertTrue(t.background(.bgWhite) != lightWhite || t.text(.textPrimary) != lightText,
                      "dark variant must differ from light")
    }

    func testEveryTextStyleResolvesWithNonNegativeLineSpacing() {
        let t = Theme(); t.loadTheme(named: "defaultTheme")
        for style in TextStyle.allCases {
            _ = style.font                                  // must not crash
            XCTAssertGreaterThanOrEqual(style.lineSpacing, 0, "\(style) negative lineSpacing")
        }
    }
}
