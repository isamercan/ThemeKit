//
//  AdaptiveFitTests.swift
//  ThemeKitTests
//
//  ADR-0007 Phase 3c pin for `AdaptiveFit` (the iOS 15.6-floor replacement for
//  two-candidate `ViewThatFits(in: .horizontal)`): the measured choice must
//  (a) pick the preferred candidate when its ideal width fits the proposal,
//  (b) fall to the compact candidate when it doesn't, (c) settle without
//  oscillating (no measurement loop — the plan's §3c risk), and (d) re-evaluate
//  when the available width changes.
//
//  Uses the window-hosted NSHostingView technique from `OnChangeCompatTests`.
//  NSHostingView proposes its *intrinsic* content size to the root (not the
//  window frame), so the proposed width under test is pinned with an explicit
//  `.frame(width:)` driven by an observable model — that frame is the
//  proposal `AdaptiveFit` measures, exactly as a parent container would
//  propose it in an app. The compact candidate is the observation point —
//  unlike the preferred one it is never duplicated into the helper's hidden
//  measurement probe, so its appearance count is a faithful "which child is
//  displayed" signal.
//

#if canImport(AppKit)
import XCTest
import SwiftUI
@testable import ThemeKit

@MainActor
final class AdaptiveFitTests: XCTestCase {

    /// Appearance ledger for the compact candidate. An oscillating (looping)
    /// layout would rack up appear/disappear cycles; a settled one shows at
    /// most one appearance and zero disappearances.
    private final class Recorder {
        var compactAppeared = 0
        var compactDisappeared = 0
    }

    /// The width proposed to the fit under test; mutable mid-test.
    private final class WidthModel: ObservableObject {
        @Published var width: CGFloat
        init(width: CGFloat) { self.width = width }
    }

    /// Preferred candidate: two fixed 100pt blocks (ideal width 200).
    /// Compact candidate: the same blocks stacked. The outer `.frame(width:)`
    /// is the pinned proposal.
    private struct Probe: View {
        @ObservedObject var model: WidthModel
        let recorder: Recorder
        var body: some View {
            AdaptiveFit {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 100, height: 20)
                    Color.clear.frame(width: 100, height: 20)
                }
            } compact: {
                VStack(spacing: 0) {
                    Color.clear.frame(width: 100, height: 20)
                    Color.clear.frame(width: 100, height: 20)
                }
                .onAppear { recorder.compactAppeared += 1 }
                .onDisappear { recorder.compactDisappeared += 1 }
            }
            .frame(width: model.width, alignment: .leading)
        }
    }

    /// Hosts the probe in a borderless window and returns a run-loop pump.
    private func host(model: WidthModel, recorder: Recorder)
        -> (window: NSWindow, pump: () -> Void) {
        let hosting = NSHostingView(rootView: Probe(model: model, recorder: recorder))
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        return (window, { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05)) })
    }

    func testPreferredWinsWhenItFits_andCompactNeverFlashes() {
        let recorder = Recorder()
        let (window, pump) = host(model: WidthModel(width: 300), recorder: recorder)
        defer { window.orderOut(nil) }
        pump(); pump(); pump()
        // Wide proposal: the 200pt row fits 300pt — the compact candidate must
        // never have been displayed, not even for the first frame (the helper
        // defaults to the preferred candidate until measured).
        XCTAssertEqual(recorder.compactAppeared, 0)
        XCTAssertEqual(recorder.compactDisappeared, 0)
    }

    func testCompactWinsWhenPreferredOverflows_andSettlesWithoutOscillating() {
        let recorder = Recorder()
        let (window, pump) = host(model: WidthModel(width: 120), recorder: recorder)
        defer { window.orderOut(nil) }
        pump(); pump(); pump(); pump()
        // Narrow proposal: the 200pt row overflows 120pt — compact must be
        // chosen, once, and stay (a measurement loop would keep cycling
        // appear/disappear; §3c's named risk).
        XCTAssertEqual(recorder.compactAppeared, 1)
        XCTAssertEqual(recorder.compactDisappeared, 0)
    }

    func testChoiceReevaluatesOnWidthChange() {
        let recorder = Recorder()
        let model = WidthModel(width: 300)
        let (window, pump) = host(model: model, recorder: recorder)
        defer { window.orderOut(nil) }
        pump(); pump()
        XCTAssertEqual(recorder.compactAppeared, 0)

        // Shrink below the preferred candidate's 200pt ideal width…
        model.width = 120
        pump(); pump()
        XCTAssertEqual(recorder.compactAppeared, 1, "narrowing must re-run the fit decision")

        // …and widen back: the preferred candidate returns, compact leaves once.
        model.width = 300
        pump(); pump()
        XCTAssertEqual(recorder.compactDisappeared, 1, "widening must re-run the fit decision")
        XCTAssertEqual(recorder.compactAppeared, 1, "no extra cycles — the choice settles")
    }
}
#endif
