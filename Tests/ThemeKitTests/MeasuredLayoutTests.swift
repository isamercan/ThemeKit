//
//  MeasuredLayoutTests.swift
//  ThemeKitTests
//
//  ADR-0007 Phase 3a pin for the measured layout containers (`FlowLayout`,
//  `Masonry`, `Flex`) — the iOS 15.6-floor replacements for their former
//  `Layout` conformances. The packing math must reproduce the old
//  `placeSubviews` results once measurement settles: row wrapping at the
//  proposed width, shortest-column masonry filling, flex main-axis
//  distribution, and RTL mirroring (both the explicit `layoutDirection`
//  parameter and the environment-direction path).
//
//  Uses the window-hosted NSHostingView technique from `AdaptiveFitTests`:
//  the proposal under test is pinned with an explicit `.frame(width:)`, and
//  each child records its settled frame in a shared named coordinate space
//  via `onAppear`/`onChange` (no preferences, so the harness can't collide
//  with the containers' own measurement preferences).
//

#if canImport(AppKit)
import XCTest
import SwiftUI
@testable import ThemeKit

@MainActor
final class MeasuredLayoutTests: XCTestCase {

    /// Settled child frames (by index) + the container's own frame, all in
    /// the harness coordinate space.
    private final class FrameRecorder {
        var frames: [Int: CGRect] = [:]
        var container: CGRect = .zero
    }

    private static let space = "measured-layout-harness"

    /// A fixed-size block that reports its settled frame.
    private struct Block: View {
        let index: Int
        let size: CGSize
        let recorder: FrameRecorder
        var body: some View {
            Color.clear
                .frame(width: size.width, height: size.height)
                .background(
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .named(MeasuredLayoutTests.space))
                        Color.clear
                            .onAppear { recorder.frames[index] = frame }
                            .onChange(of: frame) { _, new in recorder.frames[index] = new }
                    }
                )
        }
    }

    /// Pins the proposal, tags the coordinate space, and records the
    /// container frame.
    private struct Harness<Content: View>: View {
        let width: CGFloat
        let recorder: FrameRecorder
        let direction: LayoutDirection
        @ViewBuilder let content: Content
        var body: some View {
            content
                .background(
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .named(MeasuredLayoutTests.space))
                        Color.clear
                            .onAppear { recorder.container = frame }
                            .onChange(of: frame) { _, new in recorder.container = new }
                    }
                )
                .environment(\.layoutDirection, direction)
                .frame(width: width, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .coordinateSpace(name: MeasuredLayoutTests.space)
        }
    }

    /// Hosts the view in a borderless window and returns a run-loop pump.
    private func host(_ view: some View) -> (window: NSWindow, pump: () -> Void) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        return (window, { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05)) })
    }

    /// Asserts a child frame *relative to the recorded container origin* —
    /// under an RTL environment the pinned container itself sits at the
    /// trailing side of the hosting view, so absolute coordinates would skew.
    private func assertFrame(_ frame: CGRect?, in recorder: FrameRecorder, x: CGFloat, y: CGFloat,
                             _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let frame else {
            XCTFail("\(message): frame never recorded", file: file, line: line)
            return
        }
        XCTAssertEqual(frame.minX - recorder.container.minX, x, accuracy: 0.5, "\(message) (x)", file: file, line: line)
        XCTAssertEqual(frame.minY - recorder.container.minY, y, accuracy: 0.5, "\(message) (y)", file: file, line: line)
    }

    // MARK: FlowLayout

    /// Five 100×20 blocks at 250pt: 8pt spacing packs two per row →
    /// rows [0,1] / [2,3] / [4], total height 20×3 + 8×2 = 76.
    func testFlowLayoutWrapsAtProposedWidth() {
        let recorder = FrameRecorder()
        let (window, pump) = host(
            Harness(width: 250, recorder: recorder, direction: .leftToRight) {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        Block(index: i, size: CGSize(width: 100, height: 20), recorder: recorder)
                    }
                }
            }
        )
        defer { window.orderOut(nil) }
        pump(); pump(); pump()

        assertFrame(recorder.frames[0], in: recorder, x: 0, y: 0, "row 1, item 1")
        assertFrame(recorder.frames[1], in: recorder, x: 108, y: 0, "row 1, item 2")
        assertFrame(recorder.frames[2], in: recorder, x: 0, y: 28, "row 2, item 1")
        assertFrame(recorder.frames[4], in: recorder, x: 0, y: 56, "row 3, item 1")
        XCTAssertEqual(recorder.container.height, 76, accuracy: 0.5, "three rows + two line gaps")
    }

    /// The explicit `layoutDirection:` parameter mirrors the packed positions
    /// within the span (the old `placeSubviews` semantics) even in an LTR
    /// environment.
    func testFlowLayoutMirrorsWhenDirectionPassed() {
        let recorder = FrameRecorder()
        let (window, pump) = host(
            Harness(width: 250, recorder: recorder, direction: .leftToRight) {
                FlowLayout(spacing: 8, lineSpacing: 8, layoutDirection: .rightToLeft) {
                    ForEach(0..<3, id: \.self) { i in
                        Block(index: i, size: CGSize(width: 100, height: 20), recorder: recorder)
                    }
                }
            }
        )
        defer { window.orderOut(nil) }
        pump(); pump(); pump()

        // LTR packing: 0 at x0, 1 at x108, 2 wraps → mirrored: 150 / 42 / 150.
        assertFrame(recorder.frames[0], in: recorder, x: 150, y: 0, "first item starts at the trailing edge")
        assertFrame(recorder.frames[1], in: recorder, x: 42, y: 0, "second item mirrors inward")
        assertFrame(recorder.frames[2], in: recorder, x: 150, y: 28, "wrapped row restarts at the trailing edge")
    }

    // MARK: Masonry

    /// Three blocks (30/50/30 tall) in two 100pt columns at 208pt: each block
    /// drops into the shortest column → col 0: [0, 2], col 1: [1]; height
    /// (30+8+30+8) − 8 = 68.
    func testMasonryFillsShortestColumn() {
        let recorder = FrameRecorder()
        let heights: [CGFloat] = [30, 50, 30]
        let (window, pump) = host(
            Harness(width: 208, recorder: recorder, direction: .leftToRight) {
                Masonry {
                    ForEach(0..<3, id: \.self) { i in
                        Block(index: i, size: CGSize(width: 100, height: heights[i]), recorder: recorder)
                    }
                }
                .columns(2)
                .spacing(8)
            }
        )
        defer { window.orderOut(nil) }
        pump(); pump(); pump()

        assertFrame(recorder.frames[0], in: recorder, x: 0, y: 0, "column 0, first item")
        assertFrame(recorder.frames[1], in: recorder, x: 108, y: 0, "column 1, first item")
        assertFrame(recorder.frames[2], in: recorder, x: 0, y: 38, "shortest column (0) receives the third item")
        XCTAssertEqual(recorder.container.height, 68, accuracy: 0.5, "tallest column minus trailing gap")
    }

    // MARK: Flex

    /// `spaceBetween` pushes two 100pt blocks to the span's edges.
    func testFlexSpaceBetweenDistributesFreeSpace() {
        let recorder = FrameRecorder()
        let (window, pump) = host(
            Harness(width: 300, recorder: recorder, direction: .leftToRight) {
                Flex {
                    ForEach(0..<2, id: \.self) { i in
                        Block(index: i, size: CGSize(width: 100, height: 20), recorder: recorder)
                    }
                }
                .justify(.spaceBetween)
            }
        )
        defer { window.orderOut(nil) }
        pump(); pump(); pump()

        assertFrame(recorder.frames[0], in: recorder, x: 0, y: 0, "first item at the leading edge")
        assertFrame(recorder.frames[1], in: recorder, x: 200, y: 0, "second item at the trailing edge")
        XCTAssertEqual(recorder.container.height, 20, accuracy: 0.5, "single-line cross hug")
    }

    /// Under an RTL *environment* the container hands the direction to the
    /// layout (see `Flex.body`), so the first child starts at the trailing
    /// edge — this exercises the combined env-anchor + parameter-mirror path.
    func testFlexMirrorsUnderRTLEnvironment() {
        let recorder = FrameRecorder()
        let (window, pump) = host(
            Harness(width: 300, recorder: recorder, direction: .rightToLeft) {
                Flex {
                    ForEach(0..<2, id: \.self) { i in
                        Block(index: i, size: CGSize(width: 100, height: 20), recorder: recorder)
                    }
                }
                .justify(.spaceBetween)
            }
        )
        defer { window.orderOut(nil) }
        pump(); pump(); pump()

        assertFrame(recorder.frames[0], in: recorder, x: 200, y: 0, "first item starts at the trailing (right) edge")
        assertFrame(recorder.frames[1], in: recorder, x: 0, y: 0, "second item mirrors to the leading (left) edge")
    }
}
#endif
