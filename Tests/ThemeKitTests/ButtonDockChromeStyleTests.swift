//
//  ButtonDockChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 18.09.2026.
//
//  `buttonDock` + `ButtonDockChromeStyle`: the built-in bar still draws the
//  1.7.0 pixels, the stock style draws the same pixels through `makeBody`, a
//  custom style receives the dock's content unpainted together with the
//  environment control size and the bottom safe-area inset, and ThemeKit keeps
//  the pinning on both paths.
//

import XCTest
import SwiftUI
@testable import ThemeKit

#if canImport(UIKit)
import UIKit
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ButtonDockChromeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for (label, content) in contentCases {
            XCTAssertNotNil(render(staged(docked(content))), label)
            XCTAssertTrue(drawsInk(staged(docked(content))), "\(label): the fixture renders blank")
        }
    }

    /// The built-in bar draws the 1.7.0 pixels: the style hook is additive, so
    /// a dock with no style set must not move.
    func testBuiltInDockDrawsThe170Pixels() {
        for (label, content) in contentCases {
            let delta = pixelDelta(staged(docked(content)), staged(recipe(content)))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): the built-in dock drifted from 1.7.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(staged(docked(content)), staged(recipe(content.opacity(0.6)))),
                          "\(label) (control): the comparison saw no difference")
        }
    }

    /// `.buttonDockChromeStyle(.default)` goes through `makeBody`, yet must
    /// draw the same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for (label, content) in contentCases {
            let styled = staged(docked(content).buttonDockChromeStyle(.default))
            let delta = pixelDelta(staged(docked(content)), styled)
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in dock")
            XCTAssertTrue(drawsInk(styled), "\(label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(staged(docked(content)),
                                  staged(docked(content).buttonDockChromeStyle(DimmedDefaultDockStyle()))),
                          "\(label) (control): the comparison saw no difference")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().buttonDockChromeStyle.isDefault)
        XCTAssertFalse(AnyButtonDockChromeStyle(DefaultButtonDockChromeStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesContentAndControlSize() throws {
        let recorder = DockConfigurationRecorder()
        _ = render(staged(docked(AnyView(Text("Continue")))
            .buttonDockChromeStyle(RecordingDockStyle(recorder: recorder))
            .controlSize(.small)))

        let configuration = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(configuration.controlSize, .small)
        XCTAssertEqual(configuration.safeAreaBottomInset, 0,
                       "no layout loop in an ImageRenderer render — the inset stays at its 0 floor")
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = DockConfigurationRecorder()
        _ = render(staged(docked(AnyView(Text("Continue")))
            .buttonDockChromeStyle(RecordingDockStyle(recorder: recorder))))
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).controlSize, .regular)
    }

    /// The dock's content reaches the style with none of the stock bar's
    /// padding, surface or rule around it: a style that draws nothing but the
    /// content renders exactly the content, pinned.
    func testContentArrivesUnpainted() {
        let styled = staged(docked(AnyView(fixtureButtons)).buttonDockChromeStyle(BareContentDockStyle()))
        let bare = staged(Color.clear.safeAreaInset(edge: .bottom, spacing: 0) { fixtureButtons })
        let delta = pixelDelta(styled, bare)
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "the content arrived painted")
        XCTAssertTrue(drawsInk(styled), "the fixture renders blank")
        // Control: the stock bar's padding and surface are a visible difference.
        XCTAssertTrue(differs(styled, staged(docked(AnyView(fixtureButtons)))),
                      "control: the comparison saw no difference")
    }

    /// ThemeKit keeps the pinning on the style path too: the bar still comes
    /// out of the content's bottom safe area rather than sitting over it.
    func testThemeKeepsThePinningOnTheStylePath() {
        let styledDock = staged(Color.blue.buttonDock { fixtureButtons }
            .buttonDockChromeStyle(BareContentDockStyle()))
        let overlaid = staged(Color.blue.overlay(alignment: .bottom) { fixtureButtons })
        XCTAssertTrue(differs(styledDock, overlaid), "a styled dock must inset the content, not overlay it")
        let inset = staged(Color.blue.safeAreaInset(edge: .bottom, spacing: 0) { fixtureButtons })
        let delta = pixelDelta(styledDock, inset)
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "the styled dock isn't pinned the way the built-in one is")
    }

    /// A style set on a container reaches the docks below it.
    func testContainerStyleReachesNestedDocks() {
        let recorder = DockConfigurationRecorder()
        let stack = VStack {
            Color.clear.buttonDock { Text("First") }
            Color.clear.buttonDock { Text("Second") }
        }
        _ = render(stack.buttonDockChromeStyle(RecordingDockStyle(recorder: recorder)).frame(width: 320, height: 240))
        XCTAssertGreaterThanOrEqual(recorder.values.count, 2, "both docks asked the style to draw them")
    }

    // MARK: Safe-area inset

    #if canImport(UIKit)
    /// The inset a style pads the home indicator with is the one SwiftUI hands
    /// the bar — measured by ThemeKit, so the style never reads the geometry.
    /// Measured as a difference, so it holds on any simulator: the bar's own
    /// inset tracks the screen's, point for point.
    func testStyleReceivesTheBottomSafeAreaInset() {
        let flat = hostedDockInset(additionalBottom: 0)
        let indented = hostedDockInset(additionalBottom: 34)
        XCTAssertEqual(indented - flat, 34, accuracy: 0.5,
                       "the dock's own bottom inset must reach the style")
    }

    /// Hosts a styled dock in a window with the given extra bottom inset and
    /// returns the inset the style was handed, after one settled layout pass.
    private func hostedDockInset(additionalBottom: CGFloat) -> CGFloat {
        let recorder = DockConfigurationRecorder()
        let root = Color.clear
            .buttonDock { Text("Continue") }
            .buttonDockChromeStyle(RecordingDockStyle(recorder: recorder))

        let controller = UIHostingController(rootView: root)
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottom, right: 0)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        window.isHidden = true
        return recorder.values.last?.safeAreaBottomInset ?? -1
    }
    #endif

    // MARK: Fixtures

    private var contentCases: [(String, AnyView)] {
        [
            ("two buttons", AnyView(fixtureButtons)),
            ("price beside a button", AnyView(HStack {
                PriceTag(1249)
                Spacer(minLength: Theme.SpacingKey.md.value)
                PrimaryButton("Continue") {}
            })),
            ("content above a button", AnyView(VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                Text("Free cancellation until 24 h before departure").textStyle(.bodySm400)
                PrimaryButton("Continue") {}
            })),
        ]
    }

    private var fixtureButtons: some View {
        ButtonGroup(.horizontal) {
            SecondaryButton("Cancel") {}
            PrimaryButton("Continue") {}
        }
    }

    private func docked(_ content: AnyView) -> some View {
        Color.clear.buttonDock { content }
    }

    /// `buttonDock`'s 1.7.0 bar, pinned the same way.
    private func recipe(_ content: some View) -> some View {
        Color.clear.safeAreaInset(edge: .bottom, spacing: 0) { V170ButtonDockBar { content } }
    }

    /// A fixed box, so the dock has a screen to sit at the bottom of.
    private func staged(_ view: some View) -> some View {
        view.frame(width: 320, height: 160)
    }

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// `true` when the render is not one flat colour — a docked bar inside a
    /// `ScrollView` renders as nothing under `ImageRenderer`, and two blank
    /// renders would otherwise compare equal.
    private func drawsInk(_ view: some View) -> Bool {
        _ = render(view)
        guard let image = render(view), let data = image.dataProvider?.data as Data?, let first = data.first
        else { return false }
        return data.contains { $0 != first }
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second (the first render of new glyphs can antialias a few
    /// bytes differently); callers treat a delta up to `pixelNoise` as identical.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// `true` when two renders are visibly different — either their sizes
    /// differ or a channel moved past the antialiasing noise floor. The
    /// controls use it so "same size, no change" and "different size" can't
    /// both read as "no difference".
    private func differs<A: View, B: View>(_ a: A, _ b: B) -> Bool {
        guard let delta = pixelDelta(a, b) else { return true }
        return delta > pixelNoise
    }

    private let pixelNoise = 2
}

// MARK: - The 1.7.0 recipe (verbatim bar)

/// `buttonDock`'s 1.7.0 bar, written out: the reference the built-in path must
/// still draw.
@available(iOS 16.0, macOS 13.0, *)
private struct V170ButtonDockBar<DockContent: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder let content: DockContent

    var body: some View {
        VStack(spacing: 0) {
            DividerView().size(.small)
            content
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.top, Theme.SpacingKey.sm.value)
        }
        .background(theme.background(.bgWhite))
    }
}

// MARK: - Fixture styles

@MainActor
private final class DockConfigurationRecorder {
    var values: [ButtonDockChromeStyleConfiguration] = []
}

private struct RecordingDockStyle: ButtonDockChromeStyle {
    let recorder: DockConfigurationRecorder

    @MainActor
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return configuration.content
    }
}

/// Draws the content and nothing else — the proof that it arrives unpainted.
private struct BareContentDockStyle: ButtonDockChromeStyle {
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        configuration.content
    }
}

/// The stock dock at 60% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultDockStyle: ButtonDockChromeStyle {
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        DefaultButtonDockChromeStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}
