//
//  L10nViewLayerTests.swift
//  ThemeKit
//
//  ADR-0003 phase 2 — proves the restart-free mechanism with a REAL hosted
//  render (NSHostingView + run-loop pumps), not assumptions:
//
//  - flipping `ThemeKitStrings.locale` re-renders a `.themeKitLocalized()`
//    tree via the Observation revision, and the `.id` reset re-runs EVERY
//    body — including a child that reads nothing from the environment (the
//    shape of the ~561 baked-string call sites) and a non-View enum string
//    (`ColorChannel.title`);
//  - the effective `\.locale` and an RTL-correct `\.layoutDirection` are
//    injected (ar → .rightToLeft, en/tr → .leftToRight);
//  - `.themeKitLocale(_:)` scopes both values to a subtree.
//
//  macOS-only (needs AppKit hosting); the iOS lane compiles it out.
//

#if os(macOS)
import AppKit
import SwiftUI
import XCTest
import ThemeKit
@testable import ThemeKitCore

@MainActor
final class L10nViewLayerTests: XCTestCase {
    /// Body-evaluation journal, written from inside child bodies.
    private enum Journal {
        nonisolated(unsafe) static var entries: [String] = []
        static func reset() { entries = [] }
        static var last: String? { entries.last }
    }

    /// Reads the environment — locale/direction assertions come from here.
    private struct EnvironmentChild: View {
        @Environment(\.locale) private var locale
        @Environment(\.layoutDirection) private var direction
        var body: some View {
            let resolved = String(themeKit: "Hue")                      // View-string path
            let enumString = ColorChannel.hue.title                     // non-View enum path
            Journal.entries.append(
                "env|\(locale.identifier)|\(direction == .rightToLeft ? "RTL" : "LTR")|\(resolved)|\(enumString)"
            )
            return Text(resolved)
        }
    }

    /// Reads NOTHING from the environment — re-runs only via the `.id` reset.
    private struct GlobalOnlyChild: View {
        var body: some View {
            let resolved = String(themeKit: "Hue")
            Journal.entries.append("global|\(resolved)")
            return Text(resolved)
        }
    }

    private var fixture: Bundle!
    private var hosting: NSHostingView<AnyView>!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "L10nFixture", withExtension: "bundle", subdirectory: "Fixtures")
        )
        fixture = try XCTUnwrap(Bundle(url: url))
        Journal.reset()
    }

    override func tearDown() {
        hosting = nil
        ThemeKitStrings.locale = nil
        ThemeKitStrings.register()
    }

    private func host(_ view: some View) {
        _ = NSApplication.shared
        hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = .init(x: 0, y: 0, width: 320, height: 240)
        hosting.layoutSubtreeIfNeeded()
        pump()
    }

    private func pump() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        hosting?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    // MARK: - Restart-free switch (the phase-2 acceptance evidence)

    func testLiveSwitchRerendersViewAndNonViewStringsWithoutRestart() throws {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "en")

        host(VStack { EnvironmentChild(); GlobalOnlyChild() }.themeKitLocalized())
        XCTAssertTrue(Journal.entries.contains("env|en|LTR|Hue|Hue"), "initial en render: \(Journal.entries)")
        XCTAssertTrue(Journal.entries.contains("global|Hue"))

        Journal.reset()
        ThemeKitStrings.locale = Locale(identifier: "tr")   // the LanguageSwitcher binding's effect
        pump()

        // Both children re-ran and BOTH string classes flipped — no restart.
        XCTAssertTrue(Journal.entries.contains("env|tr|LTR|Ton|Ton"),
                      "View + non-View strings must flip to Turkish live: \(Journal.entries)")
        XCTAssertTrue(Journal.entries.contains("global|Ton"),
                      "the .id reset must re-run bodies that read no environment: \(Journal.entries)")

        Journal.reset()
        ThemeKitStrings.locale = Locale(identifier: "en")   // and back
        pump()
        XCTAssertTrue(Journal.entries.contains("global|Hue"), "flip back: \(Journal.entries)")
    }

    // MARK: - RTL

    func testArabicLocaleInjectsRightToLeftLayoutDirection() throws {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "ar")

        host(EnvironmentChild().themeKitLocalized())
        let entry = try XCTUnwrap(Journal.last)
        XCTAssertTrue(entry.hasPrefix("env|ar|RTL|"), "ar must flip layoutDirection: \(entry)")

        Journal.reset()
        ThemeKitStrings.locale = Locale(identifier: "tr")
        pump()
        XCTAssertTrue(try XCTUnwrap(Journal.last).hasPrefix("env|tr|LTR|"),
                      "tr must flip back to LTR: \(Journal.entries)")
    }

    // MARK: - Subtree convenience

    func testThemeKitLocaleScopesLocaleAndDirectionOnly() throws {
        // No global locale: the subtree modifier scopes formatting env only.
        host(EnvironmentChild().themeKitLocale(Locale(identifier: "ar-SA")))
        let entry = try XCTUnwrap(Journal.last)
        XCTAssertTrue(entry.hasPrefix("env|ar-SA|RTL|"), "locale + direction scoped: \(entry)")
        // …and, per the documented limitation, catalog strings do NOT change:
        XCTAssertTrue(entry.hasSuffix("|Hue|Hue"), "catalog strings stay process-language: \(entry)")
    }

    // MARK: - Stored-default freeze regression (ADR-0003 phase 4)

    /// The FIXED pattern every component default uses now: override stored,
    /// default resolved at render time (`labelOverride ?? String(themeKit:)`).
    private struct RenderTimeDefaultChild: View {
        private var titleOverride: String?
        private var title: String { titleOverride ?? String(themeKit: "Hue") }
        var body: some View {
            Journal.entries.append("renderTime|\(title)")
            return Text(title)
        }
    }

    /// The ANTI-PATTERN this phase removed: the default resolved once into a
    /// stored property at init. Kept here as executable documentation of WHY
    /// stored localized defaults are forbidden.
    private struct InitStoredDefaultChild: View {
        private var title = String(themeKit: "Hue")
        var body: some View {
            Journal.entries.append("initStored|\(title)")
            return Text(title)
        }
    }

    /// The exact shape the user hit in the demo: components placed as DIRECT
    /// children of a raw container (`VStack { … }.themeKitLocalized()`). The
    /// container's content closure is captured once, so child INITS never
    /// re-run on a switch — only render-time defaults can flip there.
    func testRenderTimeDefaultFlipsAsRawContainerDirectChild() throws {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "en")

        host(VStack {
            RenderTimeDefaultChild()
            InitStoredDefaultChild()
        }.themeKitLocalized())
        XCTAssertTrue(Journal.entries.contains("renderTime|Hue"), "en baseline: \(Journal.entries)")
        XCTAssertTrue(Journal.entries.contains("initStored|Hue"))

        Journal.reset()
        ThemeKitStrings.locale = Locale(identifier: "tr")
        pump()

        // The regression: render-time defaults flip even in this nesting…
        XCTAssertTrue(Journal.entries.contains("renderTime|Ton"),
                      "render-time default must flip under a raw container: \(Journal.entries)")
        // …while an init-stored default is frozen (bodies re-run, inits don't).
        XCTAssertTrue(Journal.entries.contains("initStored|Hue"),
                      "init-stored default stays frozen — the documented anti-pattern: \(Journal.entries)")
        XCTAssertFalse(Journal.entries.contains("initStored|Ton"))
    }

    /// The real component from the demo report: Coupon's built-in
    /// "Promo code:" label, as a direct child of the raw container — asserted
    /// on RENDERED PIXELS. A frozen label renders identical bitmaps before
    /// and after the flip (exactly the pre-fix bug); a render-time label
    /// changes the pixels, and the flipped render matches a hosting that was
    /// created natively under Turkish.
    func testCouponBuiltInLabelFlipsLive() throws {
        ThemeKitStrings.register(bundle: fixture)
        ThemeKitStrings.locale = Locale(identifier: "en")

        host(VStack { Coupon(code: "THEME25") }.themeKitLocalized())
        let english = try hostedBitmap()

        ThemeKitStrings.locale = Locale(identifier: "tr")
        pump()
        let flipped = try hostedBitmap()
        XCTAssertNotEqual(english, flipped,
                          "Coupon's built-in label froze at init — pixels did not change on the switch")

        // The live-flipped render equals a hosting CREATED under Turkish.
        host(VStack { Coupon(code: "THEME25") }.themeKitLocalized())
        let freshTurkish = try hostedBitmap()
        XCTAssertEqual(flipped, freshTurkish,
                       "the flipped render must match a natively-Turkish render")
    }

    /// Offscreen raster of the hosted view.
    private func hostedBitmap() throws -> Data {
        let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return try XCTUnwrap(rep.tiffRepresentation)
    }
}
#endif
