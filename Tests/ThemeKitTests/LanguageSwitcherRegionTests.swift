//
//  LanguageSwitcherRegionTests.swift
//  ThemeKitTests
//
//  Pins the named legacy unit behind `AppLanguage.resolvedFlag` (ADR-0007 §D2
//  rule 3): below iOS 16 there is no likely-subtags API, so the pre-16 parse
//  must honor explicit region subtags exactly and yield nil (no flag) for bare
//  language codes — never a wrong flag.
//

import XCTest
@testable import ThemeKit

final class LanguageSwitcherRegionTests: XCTestCase {

    func testLegacyRegionSubtagParsesExplicitRegions() {
        XCTAssertEqual(AppLanguage.legacyRegionSubtag(of: "en-GB"), "GB")
        XCTAssertEqual(AppLanguage.legacyRegionSubtag(of: "en_GB"), "GB")
        XCTAssertEqual(AppLanguage.legacyRegionSubtag(of: "zh-Hant-TW"), "TW")
        XCTAssertEqual(AppLanguage.legacyRegionSubtag(of: "es-419"), "419")   // UN M.49
        XCTAssertEqual(AppLanguage.legacyRegionSubtag(of: "pt-br"), "BR")     // case-normalized
    }

    func testLegacyRegionSubtagYieldsNilForBareLanguageCodes() {
        XCTAssertNil(AppLanguage.legacyRegionSubtag(of: "en"))
        XCTAssertNil(AppLanguage.legacyRegionSubtag(of: "de"))
        XCTAssertNil(AppLanguage.legacyRegionSubtag(of: "zh-Hant"))   // script, not region
        XCTAssertNil(AppLanguage.legacyRegionSubtag(of: ""))
    }

    /// The modern path (always taken on macOS 14 test hosts) still maximizes
    /// bare codes — the degrade only ever costs the flag below iOS 16.
    func testModernRegionSubtagMaximizesBareCodes() {
        XCTAssertEqual(AppLanguage.regionSubtag(of: "en"), "US")
        XCTAssertEqual(AppLanguage.regionSubtag(of: "en-GB"), "GB")
    }
}
