//
//  OnChangeCompatTests.swift
//  ThemeKitTests
//
//  ADR-0007 Phase 2 pressure test (the plan's open item): `onChangeCompat`
//  must report the same `(oldValue, newValue)` pairs as the native iOS 17
//  two-parameter `.onChange` — including under rapid sequential updates and
//  under updates SwiftUI coalesces into a single change — and the `@State`
//  previous-value capture in the named `LegacyOnChange` unit (§D2 rule 3) is
//  what makes that hold below iOS 17.
//
//  Uses the window-hosted NSHostingView technique from
//  `ThemeKitRootObservationTests`: a hosted tree only re-evaluates when
//  SwiftUI's own dependency graph invalidates it, so the recorded pairs are
//  the pairs a real app would see. On macOS 14 the `#available(iOS 17, *)`
//  check is statically true, so `onChangeCompat` exercises the NATIVE branch
//  here and `LegacyOnChange` is instantiated directly — exactly the §D5
//  rule-3 verification story (the legacy branch is a first-class test unit).
//

#if canImport(AppKit)
import XCTest
import SwiftUI
@testable import ThemeKit

@MainActor
final class OnChangeCompatTests: XCTestCase {

    private final class Source: ObservableObject {
        @Published var value = 0
    }

    /// Hosts `content` in a borderless window and returns a pump that spins the
    /// main run loop long enough for SwiftUI to deliver updates.
    private func host<V: View>(_ content: V) -> (window: NSWindow, pump: () -> Void) {
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 8, height: 8)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        return (window, { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05)) })
    }

    // MARK: Legacy unit (the <iOS 17 branch, instantiated directly)

    private struct LegacyProbe: View {
        @ObservedObject var source: Source
        let initial: Bool
        let record: (Int, Int) -> Void
        var body: some View {
            Color.clear
                .modifier(LegacyOnChange(value: source.value, initial: initial, action: record))
        }
    }

    func testLegacyOnChangeReportsOldAndNewUnderRapidSequentialUpdates() {
        let source = Source()
        nonisolated(unsafe) var pairs: [[Int]] = []
        let (window, pump) = host(LegacyProbe(source: source, initial: false) { pairs.append([$0, $1]) })
        defer { window.orderOut(nil) }
        pump()

        source.value = 1; pump()
        source.value = 2; pump()
        source.value = 3; pump()

        XCTAssertEqual(pairs, [[0, 1], [1, 2], [2, 3]],
                       "LegacyOnChange must thread the previous value through rapid updates in order")
    }

    func testLegacyOnChangeCoalescedUpdatesReportOneSpanningPair() {
        let source = Source()
        nonisolated(unsafe) var pairs: [[Int]] = []
        let (window, pump) = host(LegacyProbe(source: source, initial: false) { pairs.append([$0, $1]) })
        defer { window.orderOut(nil) }
        pump()

        // Two synchronous mutations inside one run-loop tick: SwiftUI coalesces
        // them into a single change — native two-param onChange reports (0, 2),
        // and so must the legacy capture.
        source.value = 1
        source.value = 2
        pump()

        XCTAssertEqual(pairs, [[0, 2]],
                       "Coalesced updates must produce one pair spanning old→latest, like native onChange")
    }

    func testLegacyOnChangeInitialFiresOnceWithEqualOldAndNew() {
        let source = Source()
        source.value = 7
        nonisolated(unsafe) var pairs: [[Int]] = []
        let (window, pump) = host(LegacyProbe(source: source, initial: true) { pairs.append([$0, $1]) })
        defer { window.orderOut(nil) }
        pump(); pump()

        XCTAssertEqual(pairs, [[7, 7]],
                       "initial: true must fire exactly once on appearance with old == new == current")
    }

    // MARK: Native branch (what iOS 17+/macOS callers get from onChangeCompat)

    private struct CompatProbe: View {
        @ObservedObject var source: Source
        let record: (Int, Int) -> Void
        var body: some View {
            Color.clear.onChangeCompat(of: source.value) { old, new in record(old, new) }
        }
    }

    func testOnChangeCompatNativeBranchMatchesLegacyPairs() {
        let source = Source()
        nonisolated(unsafe) var pairs: [[Int]] = []
        let (window, pump) = host(CompatProbe(source: source) { pairs.append([$0, $1]) })
        defer { window.orderOut(nil) }
        pump()

        source.value = 1; pump()
        source.value = 2
        source.value = 3
        pump()

        XCTAssertEqual(pairs, [[0, 1], [1, 3]],
                       "The native branch is the reference behavior the legacy unit must match")
    }
}
#endif
