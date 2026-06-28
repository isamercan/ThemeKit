//
//  ThemeInjectionTests.swift
//  ThemeKit
//
//  Regression guard for the `\.theme` rollout: components read their palette from
//  `@Environment(\.theme)`, so injecting a different `Theme` into a subtree with
//  `.theme(_:)` MUST change what they render — and injecting the same theme must be
//  deterministic. Asserted end-to-end (modifier → environment → resolved color →
//  pixels) without golden images, so it runs in plain `swift test` / CI. If
//  `.theme(_:)` ever stops propagating, or a component reverts to `Theme.shared`,
//  these fail.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
final class ThemeInjectionTests: XCTestCase {

    /// Reads the brand color straight from the injected environment, so a render of
    /// it is a pure, deterministic probe of `.theme(_:)` propagation (no shadows /
    /// materials / semantic-enum statics to add noise).
    private struct ThemeSwatch: View {
        @Environment(\.theme) private var theme
        var body: some View {
            Rectangle().fill(theme.foreground(.fgHero)).frame(width: 48, height: 48)
        }
    }

    /// Raw rendered pixels of a view, via `ImageRenderer` (host-independent: macOS
    /// and the Simulator both back `cgImage`). Two renders of the same view at the
    /// same size share a byte layout, so `==`/`!=` on the data is a valid pixel diff.
    @MainActor
    private func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage, let data = cg.dataProvider?.data else { return nil }
        return data as Data
    }

    /// The headline guarantee: the brand color a subtree resolves from `\.theme`
    /// follows the injected `Theme` — four themes (default, two bundled, one
    /// generated on-device) give four distinct renders; the same theme is identical.
    @MainActor
    func testThemeEnvironmentPropagates() throws {
        let def    = Theme(); def.loadTheme(named: "defaultTheme")
        let ocean  = Theme(); ocean.loadTheme(named: "oceanTheme")
        let sunset = Theme(); sunset.loadTheme(named: "sunsetTheme")
        let grape  = Theme(); grape.applyGenerated(primaryHex: "7C3AED")   // generated purple brand

        func swatch(_ theme: Theme) throws -> Data { try XCTUnwrap(pixels(ThemeSwatch().theme(theme))) }
        let d = try swatch(def), d2 = try swatch(def)
        let o = try swatch(ocean), s = try swatch(sunset), g = try swatch(grape)

        XCTAssertEqual(d, d2, "Same injected theme must render deterministically.")
        XCTAssertNotEqual(d, o, "Injecting the bundled ocean theme must change the resolved color.")
        XCTAssertNotEqual(d, s, "Injecting the bundled sunset theme must change the resolved color.")
        XCTAssertNotEqual(d, g, "Injecting an on-device-generated theme must change the resolved color.")
        XCTAssertNotEqual(o, s, "Two different bundled themes must resolve differently.")
        XCTAssertNotEqual(o, g, "Bundled vs generated themes must resolve differently.")
        XCTAssertNotEqual(s, g, "Bundled vs generated themes must resolve differently.")
    }

    /// A real component end-to-end: the Hero generic fix means the convenience
    /// `Hero(title:)` defaults its background to a `HeroSurface` View (not a
    /// `Theme.shared` Color), so the default surface follows the injected theme.
    ///
    /// Hero embeds a shadowed CTA, so its render carries a little sub-pixel noise —
    /// we compare the *magnitude* of change instead of exact bytes: an injected
    /// theme must alter far more pixels (whole-surface brand recolor) than the noise
    /// between two renders of the same theme.
    @MainActor
    func testRealComponentReskinsUnderInjectedTheme() throws {
        let def   = Theme(); def.loadTheme(named: "defaultTheme")
        let grape = Theme(); grape.applyGenerated(primaryHex: "7C3AED")
        let make: () -> AnyView = { AnyView(Hero(title: "Stay", ctaTitle: "Book", action: {}).frame(width: 240, height: 130)) }

        let d  = try XCTUnwrap(pixels(make().theme(def)),   "no Hero render under default")
        let d2 = try XCTUnwrap(pixels(make().theme(def)),   "no Hero render under default (#2)")
        let g  = try XCTUnwrap(pixels(make().theme(grape)), "no Hero render under generated")

        let noise = differingBytes(d, d2)   // sub-pixel render noise under the SAME theme
        let themed = differingBytes(d, g)   // pixels the injected theme changed
        XCTAssertGreaterThan(
            themed, max(noise * 20, 1_000),
            "Injecting a different theme must change far more pixels than render noise — Hero ignored `.theme(_:)`."
        )
    }

    private func differingBytes(_ a: Data, _ b: Data) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) }
        return zip(a, b).reduce(into: 0) { acc, pair in if pair.0 != pair.1 { acc += 1 } }
    }

    /// Per-subtree theming is additive: injecting `.theme(_:)` into one subtree must
    /// not mutate `Theme.shared`, so the rest of the app keeps its theme.
    @MainActor
    func testInjectionDoesNotTouchSharedSingleton() throws {
        Theme.shared.loadTheme(named: "defaultTheme")
        let before = try XCTUnwrap(pixels(ThemeSwatch()))

        let grape = Theme(); grape.applyGenerated(primaryHex: "7C3AED")
        _ = pixels(ThemeSwatch().theme(grape))   // render a subtree under an injected theme

        let after = try XCTUnwrap(pixels(ThemeSwatch()))
        XCTAssertEqual(before, after, "Injecting `.theme(_:)` must not change `Theme.shared` rendering.")
    }

    /// `revision` (read by the root's `.id(theme.revision)`) must bump on every theme
    /// application — the data-layer trigger for the full-subtree repaint. Guards the
    /// @Observable Theme migration: if it stops bumping, runtime theme switches stop
    /// repainting.
    func testThemeApplicationBumpsRevision() {
        let theme = Theme()
        let r0 = theme.revision
        theme.loadTheme(named: "oceanTheme")
        XCTAssertGreaterThan(theme.revision, r0, "loadTheme must bump revision (drives the .id repaint).")
        let r1 = theme.revision
        theme.applyGenerated(primaryHex: "7C3AED")
        XCTAssertGreaterThan(theme.revision, r1, "apply must bump revision.")
    }
}
