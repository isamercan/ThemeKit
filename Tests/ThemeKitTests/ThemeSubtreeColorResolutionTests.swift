//
//  ThemeSubtreeColorResolutionTests.swift
//  ThemeKit
//
//  ADR-0006 — the acceptance gate: a REAL hosted render (NSHostingView, like
//  `L10nViewLayerTests`) with TWO subtrees under DIFFERENT `.theme(_:)`
//  overrides, each reading its role's accent through the new resolver.
//
//  The same probe view records BOTH the new API (`theme.resolve(_:)`, reading
//  `@Environment(\.theme)`) and the still-shipping deprecated-free zero-arg
//  accessor (`SemanticColor.accent`, reading `Theme.shared`) for the same
//  role, in the same render — so one test demonstrates both halves of the
//  ADR's claim without needing two separate builds:
//
//  - `theme.resolve(.accent).solid` DIFFERS between the two subtrees — the
//    per-subtree isolation `.theme(_:)` advertises, now actually true.
//  - `SemanticColor.accent.solid` is IDENTICAL between the two subtrees (both
//    collapse to `Theme.shared`'s own accent, regardless of which brand each
//    subtree requested) — this is the split-brain bug ADR-0006 fixes,
//    reproduced live: if this test's first assertion were run against the old
//    (pre-ADR-0006) `SemanticColor.accent.solid`-only code path, it would FAIL
//    (no isolation); against `theme.resolve(_:)` it PASSES.
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
final class ThemeSubtreeColorResolutionTests: XCTestCase {
    /// Colors captured from inside the rendered subtrees' bodies.
    private enum Journal {
        nonisolated(unsafe) static var newAPI: [String: Color] = [:]
        nonisolated(unsafe) static var oldAPI: [String: Color] = [:]
        static func reset() { newAPI = [:]; oldAPI = [:] }
    }

    /// Reads the environment theme and records both the new (env-correct) and
    /// old (singleton) accessor for the SAME role, keyed by which subtree it's in.
    private struct AccentProbe: View {
        let key: String
        @Environment(\.theme) private var theme
        var body: some View {
            Journal.newAPI[key] = theme.resolve(.accent).solid
            Journal.oldAPI[key] = SemanticColor.accent.solid
            return Color.clear.frame(width: 2, height: 2)
        }
    }

    private var hosting: NSHostingView<AnyView>!

    override func tearDown() {
        hosting = nil
    }

    private func host(_ view: some View) {
        _ = NSApplication.shared
        hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = .init(x: 0, y: 0, width: 240, height: 120)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    /// sRGB components for a reliable `Color` equality check.
    private func rgba(_ c: Color) -> [Double] {
        let r = c.resolve(in: EnvironmentValues())
        return [Double(r.red), Double(r.green), Double(r.blue), Double(r.opacity)]
    }

    // MARK: - The acceptance gate

    func testTwoSubtreesResolveDistinctAccentsViaTheNewResolver() throws {
        let brandA = Theme()
        brandA.apply(ThemeConfig(primaryHex: "d81b60", accentHex: "d81b60"))
        let brandB = Theme()
        brandB.apply(ThemeConfig(primaryHex: "1e88e5", accentHex: "1e88e5"))
        // Sanity: the two brands really are different (else the test proves nothing).
        XCTAssertNotEqual(rgba(brandA.resolve(.accent).solid), rgba(brandB.resolve(.accent).solid))

        Journal.reset()
        host(
            HStack {
                AccentProbe(key: "A").theme(brandA)
                AccentProbe(key: "B").theme(brandB)
            }
        )

        let newA = try XCTUnwrap(Journal.newAPI["A"])
        let newB = try XCTUnwrap(Journal.newAPI["B"])
        XCTAssertNotEqual(rgba(newA), rgba(newB),
                          "theme.resolve(.accent).solid must differ per subtree — the ADR-0006 promise (PASSES with the new resolver)")

        // The still-shipping deprecated-free zero-arg accessor ignores
        // `.theme(_:)` and reads `Theme.shared` regardless of which subtree
        // it's called from — both entries collapse to the SAME color even
        // though brand A and brand B are different. This is the split-brain
        // this ADR fixes; documented here as still-true FOR THE OLD PATH
        // (Phase 2 migrates call sites off it; Phase 0 only adds the resolver).
        let oldA = try XCTUnwrap(Journal.oldAPI["A"])
        let oldB = try XCTUnwrap(Journal.oldAPI["B"])
        XCTAssertEqual(rgba(oldA), rgba(oldB),
                       "SemanticColor.accent ignores .theme(_:) and always reads Theme.shared — " +
                       "an isolation assertion on THIS path would FAIL (no per-subtree isolation)")
        // …by construction: the old path always equals Theme.shared's own
        // resolution, whichever subtree it happens to be read from.
        XCTAssertEqual(rgba(oldA), rgba(Theme.shared.resolve(.accent).solid),
                       "the old accessor always resolves against Theme.shared, never the subtree's .theme(_:)")
    }
}
#endif
