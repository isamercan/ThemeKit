//
//  ThemeKitRootObservationTests.swift
//  ThemeKitTests
//
//  ADR-0007 §D3 runtime proof (the ADR's open question): `ThemeKitModifier`
//  holds `Theme.shared` as `@ObservedObject`, and a `ViewModifier` participates
//  in `DynamicProperty` updates — so a `Theme.shared` mutation (a `@Published`
//  `revision` bump) must re-run the modifier body and re-apply the `.id`,
//  repainting a LIVE hosted tree with no external re-render. This is the
//  regression gate for the runtime root theme swap (ADR-0006 invariant #2)
//  after the `@Observable` → `ObservableObject` downgrade.
//
//  Uses a window-hosted NSHostingView (macOS `swift test`): unlike an
//  `ImageRenderer` re-render — which re-evaluates bodies unconditionally and
//  therefore proves nothing about invalidation — a hosted view only repaints
//  when SwiftUI's own dependency graph invalidates it.
//

#if canImport(AppKit)
import XCTest
import SwiftUI
@testable import ThemeKit

@MainActor
final class ThemeKitRootObservationTests: XCTestCase {

    override func tearDown() {
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)   // restore
        super.tearDown()
    }

    /// A leaf that reads the environment theme — repainting it on a
    /// `Theme.shared` swap is exactly what `.themeKit()`'s `.id(revision)` +
    /// `@ObservedObject` re-run guarantees.
    private struct Swatch: View {
        @Environment(\.theme) private var theme
        var body: some View {
            Rectangle().fill(theme.foreground(.fgHero)).frame(width: 32, height: 32)
        }
    }

    func testRuntimeThemeSwapRepaintsHostedThemeKitRoot() throws {
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)

        let hosting = NSHostingView(rootView: Swatch().themeKit())
        hosting.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        defer { window.orderOut(nil) }

        func pixels() throws -> Data {
            hosting.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            return try XCTUnwrap(rep.tiffRepresentation)
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let before = try pixels()

        // The runtime root swap: mutate the SINGLETON (no view is re-created).
        Theme.shared.applyGenerated(primaryHex: "7C3AED")   // grape brand
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let after = try pixels()

        XCTAssertNotEqual(
            before, after,
            "Theme.shared.applyGenerated must repaint a live .themeKit() tree — "
            + "the @ObservedObject in ThemeKitModifier stopped re-running its body "
            + "(ADR-0007 §D3 fallback: move it into a ThemeKitRoot wrapper View)."
        )
    }
}
#endif
