//
//  L10nResolverTests.swift
//  ThemeKit
//
//  ADR-0003 phase 1 — the resolver, exercised against a hand-compiled fixture
//  bundle (en/tr/ru `.lproj`s with `.strings` + `.stringsdict`, exactly the
//  form Xcode compiles a consumer's `ThemeKit.xcstrings` into). Covers the
//  resolution-chain order, sentinel miss-through, BCP-47 matching, positional
//  reordering, `%%` escaping, crash-safe rejection of unsatisfiable
//  translations, live locale flips, revision bumps, and — mechanism-level —
//  that plural expansion follows the TARGET locale's categories (ru: 2 → few,
//  5 → many), which `String.localizedStringWithFormat` would get wrong.
//

import XCTest
import SwiftUI
@testable import ThemeKitCore
import ThemeKitTravel

final class L10nResolverTests: XCTestCase {
    private var fixture: Bundle!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "L10nFixture", withExtension: "bundle", subdirectory: "Fixtures"),
            "fixture bundle missing from test resources"
        )
        fixture = try XCTUnwrap(Bundle(url: url))
    }

    override func tearDown() {
        // The resolver is process-global state — always restore zero-config.
        ThemeKitStrings.locale = nil
        ThemeKitStrings.register()
    }

    // MARK: - No-config path (today's behavior, byte-identical)

    func testNoConfigOutputMatchesToday() {
        XCTAssertEqual(String(themeKit: "Hue"), "Hue")
        XCTAssertEqual(String(themeKit: "At least \(6) characters"), "At least 6 characters")
        XCTAssertEqual(String(themeKit: "Between \(1) and \(10)"), "Between 1 and 10")
        XCTAssertEqual(String(themeKitTravel: "Nonstop"), "Nonstop")
        XCTAssertEqual(String(themeKitTravel: "\(2) adults"), "2 adults")
    }

    // MARK: - Chain order

    func testConsumerEffectiveLanguageWins() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Hue"), "Ton")
    }

    func testBCP47RegionQualifiedMatching() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr-TR")
        XCTAssertEqual(String(themeKit: "Hue"), "Ton", "tr-TR must match the tr.lproj")
        ThemeKitStrings.locale = Locale(identifier: "tr_TR")
        XCTAssertEqual(String(themeKit: "Hue"), "Ton", "tr_TR must match the tr.lproj")
    }

    func testConsumerEnglishRewordingFallback() {
        // Key untranslated in tr but reworded in the consumer's en → the
        // rewording shows in every language (D1 step 3).
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Digits only"), "Numbers only, please")
    }

    func testSentinelMissThroughToEnglishSource() {
        // Key absent from every fixture lproj → module catalog (raw .xcstrings
        // under swift test → miss) → the English source text.
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Completed"), "Completed")
        XCTAssertEqual(String(themeKitTravel: "Nonstop"), "Nonstop")
    }

    func testUnsupportedLanguageDegradesToConsumerEnglish() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "de")
        XCTAssertEqual(String(themeKit: "Hue"), "Hue")
        XCTAssertEqual(String(themeKit: "Digits only"), "Numbers only, please")
    }

    // MARK: - Interpolation through the consumer catalog

    func testPositionalReorderingInTranslation() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        let score = "4.5"
        let maxValue = 5
        // Rating.swift's exact call-site shape → key "%@ out of %@".
        XCTAssertEqual(String(themeKit: "\(score) out of \(maxValue)"), "5 üzerinden 4.5")
    }

    func testPercentEscapedKeyRoundTrip() {
        // PriceTag's "\(percent)% off" → key "%@%% off"; the tr value renders
        // a leading percent sign ("%25 indirim").
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "\(25)% off"), "%25 indirim")
    }

    func testUnsatisfiableTranslationFallsThroughSafely() {
        // The fixture's tr value for "Resend code in %@" is "%lld saniye…" —
        // unsatisfiable by a String argument. It must be discarded (no crash,
        // no garbage), landing on the English source.
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Resend code in \(30)"), "Resend code in 30")
    }

    // MARK: - Live switching

    func testLiveLocaleFlipIsRestartFree() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "en")
        XCTAssertEqual(String(themeKit: "Hue"), "Hue")
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Hue"), "Ton")
        ThemeKitStrings.locale = Locale(identifier: "ru")
        XCTAssertEqual(String(themeKit: "Hue"), "Тон")
        ThemeKitStrings.locale = Locale(identifier: "en")
        XCTAssertEqual(String(themeKit: "Hue"), "Hue")
    }

    @MainActor
    func testLocaleSetBumpsRevision() {
        let before = ThemeKitStrings.observable.value
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertGreaterThan(ThemeKitStrings.observable.value, before,
                             "the .themeKitLocalized() root observes this bump")
    }

    @MainActor
    func testLanguageBindingDrivesLocale() {
        ThemeKitStrings.languageBinding.wrappedValue = "tr"
        XCTAssertEqual(ThemeKitStrings.locale?.identifier, "tr")
        XCTAssertEqual(ThemeKitStrings.languageBinding.wrappedValue, "tr")
    }

    // MARK: - Plural mechanism (spike #4, verified against ru categories)

    func testPluralExpansionFollowsTargetLocale() throws {
        let ru = try XCTUnwrap(Bundle(url: fixture.bundleURL.appendingPathComponent("ru.lproj")))
        let format = ru.localizedString(forKey: "plural.seats", value: nil, table: "ThemeKit")
        let ruLocale = Locale(identifier: "ru")
        // Russian: 2 → few, 5 → many — only when the TARGET locale drives the
        // rules (String.localizedStringWithFormat would use Locale.current).
        XCTAssertEqual(String(format: format, locale: ruLocale, arguments: [Int64(2)]), "2 места (few)")
        XCTAssertEqual(String(format: format, locale: ruLocale, arguments: [Int64(5)]), "5 мест (many)")
        // Same format, English rules: 2 → other. Proves locale-driven selection.
        XCTAssertEqual(String(format: format, locale: Locale(identifier: "en"), arguments: [Int64(2)]),
                       "2 мест (other)")
    }

    // MARK: - Format validator (crash safety)

    func testFormatValidator() {
        XCTAssertTrue(ThemeKitStrings.isSatisfiable("%@ x %@", argumentCount: 2))
        XCTAssertTrue(ThemeKitStrings.isSatisfiable("%2$@ üzerinden %1$@", argumentCount: 2))
        XCTAssertTrue(ThemeKitStrings.isSatisfiable("%%%1$@ indirim", argumentCount: 1))
        XCTAssertTrue(ThemeKitStrings.isSatisfiable("100%% free", argumentCount: 0))
        XCTAssertTrue(ThemeKitStrings.isSatisfiable("%#@seats@", argumentCount: 1))
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("%lld saniye", argumentCount: 1))
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("%s crash", argumentCount: 1))
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("%3$@", argumentCount: 2))
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("%@ %@ %@", argumentCount: 2))
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("%1$@ %@", argumentCount: 2), "mixed forms rejected")
        XCTAssertFalse(ThemeKitStrings.isSatisfiable("dangling %", argumentCount: 0))
    }

    // MARK: - Capture type (D2)

    func testCaptureTypeIsTypeIndependent() {
        let value: ThemeKitLocalizationValue = "\(5) x \("a") y \(2.5) z \(true)"
        XCTAssertEqual(value.key, "%@ x %@ y %@ z %@")
        XCTAssertEqual(value.arguments, ["5", "a", "2.5", "true"])
        XCTAssertEqual(value.defaultText, "5 x a y 2.5 z true")
    }

    func testPlainKeyKeepsPercentVerbatim() {
        // Plain keys never pass through String(format:) → no %% escaping.
        let value: ThemeKitLocalizationValue = "100% free"
        XCTAssertEqual(value.key, "100% free")
        XCTAssertTrue(value.arguments.isEmpty)
    }

    func testTernaryOfLiteralsCompilesAndResolves() {
        // CalendarView.swift:152's exact shape.
        let direction = -1
        XCTAssertEqual(String(themeKit: direction < 0 ? "Previous month" : "Next month"), "Previous month")
        XCTAssertEqual(String(themeKit: direction > 0 ? "Previous month" : "Next month"), "Next month")
    }

    @available(*, deprecated)   // silences the intentional deprecated-API use
    func testExplicitLocalizationValueOverloadStillCompiles() {
        let legacy: String.LocalizationValue = "Hue"
        XCTAssertEqual(String(themeKit: legacy), "Hue")
    }

    func testRegisterInvalidatesCaches() {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "tr")
        XCTAssertEqual(String(themeKit: "Hue"), "Ton")
        ThemeKitStrings.register()   // back to Bundle.main — no catalog
        XCTAssertEqual(String(themeKit: "Hue"), "Hue")
    }
}
