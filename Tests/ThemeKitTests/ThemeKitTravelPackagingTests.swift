//
//  ThemeKitTravelPackagingTests.swift
//  ThemeKitTests
//
//  F0.1 smoke coverage for the ThemeKitTravel domain-edition packaging: the
//  product links, the edition marker resolves, and the edition's own String
//  Catalog bundle is wired (so `String(themeKitTravel:)` returns the source key
//  when unlocalized, which is all a plain `swift test` can assert — see the note
//  in the edition's Localization.swift).
//

import XCTest
@testable import ThemeKitTravel

final class ThemeKitTravelPackagingTests: XCTestCase {

    func testEditionMarkerLinks() {
        XCTAssertEqual(TravelEdition.name, "ThemeKitTravel")
        XCTAssertEqual(TravelEdition.clusters.first, "Flight")
    }

    func testEditionStringCatalogBundleIsWired() {
        // No key is seeded yet, so the source string round-trips — this proves
        // `Bundle.themeKitTravel` (the synthesized `.module`) exists and the
        // `String(themeKitTravel:)` bridge resolves against it rather than trapping.
        XCTAssertEqual(String(themeKitTravel: "ThemeKitTravel"), "ThemeKitTravel")
        XCTAssertNotNil(Bundle.themeKitTravel)
    }
}
