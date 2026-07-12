//
//  L10nSnapshotTests.swift
//  ThemeKitTests
//
//  ADR-0003 phase 2 — the forced-locale snapshot lane. Scoped to prove the
//  MECHANISM (not to re-snapshot every screen):
//  (a) a fixture-registered Turkish translation renders through
//      `.themeKitLocalized()` — the consumer-catalog path end to end;
//  (b) an Arabic locale flips the injected `\.layoutDirection` to
//      `.rightToLeft` (leading-aligned chrome mirrors).
//
//  Opt-in like the rest of the visual suite (RUN_SNAPSHOTS=1, pinned
//  simulator — docs/SNAPSHOT-TESTING.md). The process-global is restored in
//  tearDown so sibling suites stay order-independent.
//

#if canImport(UIKit)
import SwiftUI
import ThemeKit
import ThemeKitCore
import XCTest

final class L10nSnapshotTests: SnapshotTestCase {
    private var fixture: Bundle!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "L10nFixture", withExtension: "bundle", subdirectory: "Fixtures")
        )
        fixture = try XCTUnwrap(Bundle(url: url))
    }

    override func tearDown() {
        ThemeKitStrings.locale = nil
        ThemeKitStrings.register()
        super.tearDown()
    }

    /// A small stage exercising both string classes: a View-string default
    /// ("Hue" placeholder text) and the non-View `ColorChannel` enum titles.
    private var stage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(themeKit: "Hue"))
                .textStyle(.headingSm)
            HStack(spacing: 8) {
                ForEach(ColorChannel.allCases, id: \.self) { channel in
                    Badge(channel.title)
                }
            }
        }
        .padding(4)
    }

    /// (a) fixture-registered `tr` renders Turkish through the root provider.
    func testForcedTurkishRendersConsumerCatalog() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        assertComponentSnapshot(stage.themeKitLocalized())
    }

    /// (b) Arabic flips the injected layout direction — mirrored chrome.
    func testArabicFlipsLayoutDirection() {
        ThemeKitStrings.locale = Locale(identifier: "ar")
        assertComponentSnapshot(stage.themeKitLocalized(), layoutDirection: .rightToLeft)
    }
}
#endif
