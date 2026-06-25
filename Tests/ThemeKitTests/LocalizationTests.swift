//
//  LocalizationTests.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Verifies the String Catalog wiring: shipped defaults are English, a Turkish
//  translation is bundled, interpolation works, and callers can still override.
//

import XCTest
import Foundation
@testable import ThemeKit

final class LocalizationTests: XCTestCase {
    // The bundled catalog ships correct Turkish translations. (We parse the
    // resource directly: a plain `swift test` doesn't compile `.xcstrings`, so we
    // can't rely on runtime `tr` resolution here — that's verified in the Demo
    // under Xcode. This proves the translations are present and correct.)
    func testTurkishTranslationsShipInCatalog() throws {
        // This test reads the RAW .xcstrings. SwiftPM (`swift test`) copies it
        // verbatim, so it's present; Xcode (`xcodebuild`) compiles it into a
        // .loctable and drops the source, so under that toolchain there is
        // nothing to parse — skip rather than fail.
        guard let url = Bundle.globalUIComponents.url(forResource: "Localizable", withExtension: "xcstrings") else {
            throw XCTSkip("Raw .xcstrings is only present under SwiftPM; Xcode compiles it away.")
        }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(json?["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(json?["strings"] as? [String: Any])

        func turkish(_ key: String) -> String? {
            ((((strings[key] as? [String: Any])?["localizations"] as? [String: Any])?["tr"]
                as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
        }
        XCTAssertEqual(turkish("This field is required"), "Bu alan zorunlu")
        XCTAssertEqual(turkish("Enter a valid email"), "Geçerli bir e-posta girin")
        XCTAssertEqual(turkish("At least %lld characters"), "En az %lld karakter")
    }

    // Default validation messages resolve to the English source strings.
    func testDefaultMessagesAreEnglish() {
        XCTAssertEqual(ValidationRule.required().message, "This field is required")
        XCTAssertEqual(ValidationRule.email().message, "Enter a valid email")
        XCTAssertEqual(ValidationRule.numeric().message, "Digits only")
        XCTAssertEqual(ValidationRule.match("x").message, "Doesn't match")
    }

    // Interpolated keys resolve and embed their numbers.
    func testInterpolatedMessages() {
        XCTAssertEqual(ValidationRule.minLength(6).message, "At least 6 characters")
        XCTAssertEqual(ValidationRule.range(1...10).message, "Between 1 and 10")
    }

    // The public bridge initializer resolves from the bundle.
    func testPublicBridgeInitializer() {
        XCTAssertEqual(String(globalUIComponents: "Digits only"), "Digits only")
    }

    // Callers can still override every default (non-breaking).
    func testOverrideWins() {
        XCTAssertEqual(ValidationRule.required("Zorunlu").message, "Zorunlu")
        XCTAssertEqual(ValidationRule.email("Custom").message, "Custom")
    }
}
