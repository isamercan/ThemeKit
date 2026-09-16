//
//  SkeletonStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `SkeletonStyle` (1.5.0) and the skeleton motion fix:
//
//  - the stock path still renders, and `.skeletonStyle(.default)` draws the
//    same pixels as the untouched environment;
//  - a custom style receives the placeholder's shape / variant / highlight and
//    the resolved `isAnimated` from `Skeleton`, `.skeleton(_:)`, a
//    `SkeletonGroup` and ThemeKit's own placeholders (Card);
//  - `SkeletonShape.anyShape` is the stock outline;
//  - the stock fill honours `microAnimations`, and a change of variant /
//    motion after appear rebuilds the placeholder (hosted render, like
//    `OnChangeCompatTests`).
//
//  Pixel checks go through `ImageRenderer`, which renders the state after
//  `onAppear` (a running pulse shows as its dimmed target). Two renders of the
//  same view can differ by ±1 in a few antialiased pixels, so comparisons
//  allow a small per-channel tolerance. A hosted window can't be used for
//  pixels here: without a display link the animation never advances.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class SkeletonStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: - Probes

    /// What the probe style saw. Main-actor isolated, so it can travel into a
    /// `sending` style parameter and be read back by the test.
    @MainActor
    private final class Recorder {
        var configurations: [SkeletonStyleConfiguration] = []
        var appearances: [SkeletonAppearance] = []
    }

    private struct SkeletonAppearance: Hashable {
        let variant: SkeletonVariant
        let isAnimated: Bool
    }

    /// Records every configuration it is asked to draw and every appearance of
    /// the view it returns.
    private struct RecordingSkeletonStyle: SkeletonStyle {
        let recorder: Recorder
        func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
            recorder.configurations.append(configuration)
            return Color.clear.onAppear {
                recorder.appearances.append(.init(variant: configuration.variant, isAnimated: configuration.isAnimated))
            }
        }
    }

    /// A visibly different, static placeholder — proves a custom style replaces the stock paint.
    private struct FlatSkeletonStyle: SkeletonStyle {
        func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
            FlatSkeleton(shape: configuration.shape)
        }
    }

    private struct FlatSkeleton: View {
        @Environment(\.theme) private var theme
        let shape: SkeletonShape
        var body: some View { shape.anyShape.fill(theme.foreground(.fgHero)) }
    }

    // MARK: - Default path

    func testStockPlaceholdersStillRender() {
        for variant in SkeletonVariant.allCases {
            XCTAssertNotNil(pixels(Skeleton(.capsule).variant(variant).size(width: 120, height: 16)), "\(variant)")
        }
        XCTAssertNotNil(pixels(Text("Loading").skeleton(true)))
        XCTAssertNotNil(pixels(Text("Loading").skeleton(true, radius: .field, variant: .pulse, highlight: .info)))
        XCTAssertNotNil(pixels(SkeletonGroup { Text("Loading").skeleton() }.loading()))
    }

    func testDefaultStyleDrawsTheStockPixels() throws {
        let blocks: [(String, AnyView)] = [
            ("shimmer", AnyView(Skeleton(.capsule).size(width: 120, height: 16))),
            ("pulse", AnyView(Skeleton(.circle).variant(.pulse).size(width: 32, height: 32))),
            ("none", AnyView(Skeleton(.rounded(.box)).variant(.none).size(width: 120, height: 40))),
            ("highlight", AnyView(Skeleton(.rounded(6)).highlight(.info).size(width: 120, height: 24))),
            ("modifier", AnyView(Text("Loading title").skeleton(true, radius: .field))),
        ]
        for (name, block) in blocks {
            let stock = try XCTUnwrap(pixels(block), name)
            let viaDefault = try XCTUnwrap(pixels(block.skeletonStyle(.default)), name)
            XCTAssertTrue(matches(stock, viaDefault), "\(name): .skeletonStyle(.default) must draw the stock placeholder")
        }
    }

    func testCustomStyleReplacesTheStockPaint() throws {
        let block = Skeleton(.capsule).size(width: 120, height: 16)
        let stock = try XCTUnwrap(pixels(block))
        let custom = try XCTUnwrap(pixels(block.skeletonStyle(FlatSkeletonStyle())))
        XCTAssertFalse(matches(stock, custom))
    }

    // MARK: - Stock motion

    /// The stock pulse only breathes while motion is on: under
    /// `.microAnimations(false)` it draws its static first frame, like `.none`.
    /// Before 1.5.0 the fill ignored the switch.
    func testStockPulseHonoursMicroAnimations() throws {
        let pulse = Skeleton(.circle).variant(.pulse).size(width: 32, height: 32)
        let still = try XCTUnwrap(pixels(Skeleton(.circle).variant(.none).size(width: 32, height: 32)))

        XCTAssertFalse(matches(try XCTUnwrap(pixels(pulse)), still), "motion on: the pulse is dimming")
        XCTAssertTrue(matches(try XCTUnwrap(pixels(pulse.microAnimations(false))), still), "motion off: static fill")
        XCTAssertTrue(matches(try XCTUnwrap(pixels(pulse.microAnimations(false).skeletonStyle(.default))), still),
                      "the default style resolves motion the same way")
    }

    /// The stock shimmer drops its sweep layer when motion is off; at rest (and in
    /// a static render) the band sits outside the clip, so both look like `.none`.
    func testStockShimmerAtRestMatchesTheStaticFill() throws {
        let still = try XCTUnwrap(pixels(Skeleton(.capsule).variant(.none).size(width: 120, height: 16)))
        let shimmer = Skeleton(.capsule).size(width: 120, height: 16)
        XCTAssertTrue(matches(try XCTUnwrap(pixels(shimmer)), still))
        XCTAssertTrue(matches(try XCTUnwrap(pixels(shimmer.microAnimations(false))), still))
    }

    // MARK: - Configuration

    func testStandaloneSkeletonHandsItsInputsToTheStyle() throws {
        let recorder = Recorder()
        render(Skeleton(.circle).variant(.pulse).highlight(.info).size(width: 32, height: 32)
            .skeletonStyle(RecordingSkeletonStyle(recorder: recorder)))

        let configuration = try XCTUnwrap(recorder.configurations.last)
        XCTAssertEqual(configuration.shape, .circle)
        XCTAssertEqual(configuration.variant, .pulse)
        XCTAssertEqual(configuration.highlight, .info)
        XCTAssertTrue(configuration.isAnimated)
    }

    func testIsAnimatedIsResolvedBeforeTheStyleSeesIt() {
        let recorder = Recorder()
        render(VStack {
            Skeleton().variant(.shimmer)
            Skeleton().variant(.none)
            Skeleton().variant(.pulse).microAnimations(false)
            Skeleton().variant(.shimmer).microAnimations(false)
        }
        .skeletonStyle(RecordingSkeletonStyle(recorder: recorder)))

        // SwiftUI doesn't promise an evaluation order for siblings — compare as a set.
        let resolved = Set(recorder.configurations.map { SkeletonAppearance(variant: $0.variant, isAnimated: $0.isAnimated) })
        XCTAssertEqual(resolved, [
            .init(variant: .shimmer, isAnimated: true),
            .init(variant: .none, isAnimated: false),
            .init(variant: .pulse, isAnimated: false),
            .init(variant: .shimmer, isAnimated: false),
        ])
    }

    func testSkeletonModifierRoutesThroughTheStyle() {
        let recorder = Recorder()
        render(VStack {
            Text("A").skeleton(true, cornerRadius: 12)
            Text("B").skeleton(true, radius: .field, variant: .pulse)
            Text("C").skeleton(true, shape: .capsule, variant: .none, highlight: .success)
            Text("D").skeleton(false, shape: .circle)
        }
        .skeletonStyle(RecordingSkeletonStyle(recorder: recorder)))

        // SwiftUI doesn't promise an evaluation order for siblings — match by content.
        let seen = recorder.configurations
        func saw(_ shape: SkeletonShape, _ variant: SkeletonVariant, _ highlight: SemanticColor?) -> Bool {
            seen.contains { $0.shape == shape && $0.variant == variant && $0.highlight == highlight }
        }
        XCTAssertTrue(saw(.rounded(12), .shimmer, nil), "cornerRadius overload")
        XCTAssertTrue(saw(.rounded(Theme.RadiusRole.field.value), .pulse, nil), "radius-role overload")
        XCTAssertTrue(saw(.capsule, .none, .success), "shape overload")
        XCTAssertFalse(seen.contains { $0.shape == .circle }, "a loaded view draws no placeholder")
    }

    func testSkeletonGroupDrivesTheStyle() {
        let loading = Recorder()
        render(SkeletonGroup { Text("Title").skeleton(shape: .capsule) }
            .loading(true)
            .skeletonStyle(RecordingSkeletonStyle(recorder: loading)))
        XCTAssertEqual(loading.configurations.first?.shape, .capsule)
        XCTAssertEqual(loading.configurations.first?.variant, .shimmer)

        let loaded = Recorder()
        render(SkeletonGroup { Text("Title").skeleton(shape: .capsule) }
            .loading(false)
            .skeletonStyle(RecordingSkeletonStyle(recorder: loaded)))
        XCTAssertTrue(loaded.configurations.isEmpty, "a loaded group draws no placeholder")
    }

    func testThemeKitPlaceholdersPickUpTheEnvironmentStyle() {
        let recorder = Recorder()
        render(Card("Trip") { EmptyView() }
            .loading()
            .skeletonStyle(RecordingSkeletonStyle(recorder: recorder)))
        XCTAssertGreaterThanOrEqual(recorder.configurations.count, 3,
                                    "Card's three loading lines are Skeletons, so a container style reaches them")
        XCTAssertTrue(recorder.configurations.allSatisfy { $0.shape == .capsule })
    }

    // MARK: - SkeletonShape.anyShape

    func testAnyShapeIsTheStockOutline() {
        let rect = CGRect(x: 0, y: 0, width: 60, height: 24)
        XCTAssertEqual(SkeletonShape.circle.anyShape.path(in: rect), Circle().path(in: rect))
        XCTAssertEqual(SkeletonShape.capsule.anyShape.path(in: rect), Capsule().path(in: rect))
        XCTAssertEqual(SkeletonShape.rounded(6).anyShape.path(in: rect),
                       RoundedRectangle(cornerRadius: 6, style: .continuous).path(in: rect))
        XCTAssertEqual(SkeletonShape.rounded(.field).anyShape.path(in: rect),
                       RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous).path(in: rect))
    }

    // MARK: - Motion after appear (hosted)

    #if canImport(AppKit)
    private final class MotionModel: ObservableObject {
        @Published var micro = true
        @Published var variant: SkeletonVariant = .shimmer
        @Published var highlight: SemanticColor?
    }

    private struct MotionProbe: View {
        @ObservedObject var model: MotionModel
        let recorder: Recorder
        var body: some View {
            Skeleton(.rounded(4))
                .variant(model.variant)
                .highlight(model.highlight)
                .size(width: 40, height: 20)
                .microAnimations(model.micro)
                .skeletonStyle(RecordingSkeletonStyle(recorder: recorder))
                // Pin Reduce Motion off: CI runners can have it on, which
                // would keep every appearance static.
                .environment(\._accessibilityReduceMotion, false)
        }
    }

    /// Every placeholder — the stock fill and a custom style alike — sits inside
    /// the same restart wrapper, so a motion change re-appears it with the new
    /// inputs: a loop started in `onAppear` restarts or stops. Before 1.5.0 the
    /// stock loop started once and was never restarted or stopped.
    func testPlaceholderIsRebuiltWhenMotionInputsChange() {
        let model = MotionModel()
        let recorder = Recorder()
        let window = host(MotionProbe(model: model, recorder: recorder))
        defer { window.orderOut(nil) }
        XCTAssertTrue(spin { recorder.appearances.count == 1 }, "the placeholder never appeared")
        XCTAssertEqual(recorder.appearances, [.init(variant: .shimmer, isAnimated: true)])

        // Each change waits for its own re-appearance, however long the
        // update takes to arrive.
        model.micro = false
        XCTAssertTrue(spin { recorder.appearances.count == 2 }, "microAnimations(false) didn't rebuild")
        model.variant = .pulse
        XCTAssertTrue(spin { recorder.appearances.count == 3 }, "the variant change didn't rebuild")
        model.micro = true
        XCTAssertTrue(spin { recorder.appearances.count == 4 }, "microAnimations(true) didn't rebuild")
        model.variant = .none
        XCTAssertTrue(spin { recorder.appearances.count == 5 }, "the variant change didn't rebuild")

        XCTAssertEqual(recorder.appearances, [
            .init(variant: .shimmer, isAnimated: true),
            .init(variant: .shimmer, isAnimated: false),
            .init(variant: .pulse, isAnimated: false),
            .init(variant: .pulse, isAnimated: true),
            .init(variant: .none, isAnimated: false),
        ], "each motion change re-appears the placeholder with the new inputs")

        model.highlight = .info
        XCTAssertTrue(spin { recorder.configurations.last?.highlight == .info }, "the highlight never reached the style")
        // Give a (wrong) re-appearance the same chance to arrive before
        // asserting there is none.
        XCTAssertFalse(spin(timeout: 0.3) { recorder.appearances.count > 5 },
                       "a change that doesn't touch motion keeps the running view")
        XCTAssertEqual(recorder.appearances.count, 5)
    }

    /// Hosts `content` in a borderless window.
    private func host<V: View>(_ content: V) -> NSWindow {
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 64, height: 32)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        return window
    }

    /// Spins the main run loop in short steps until `condition` holds or
    /// `timeout` passes; returns whether it held.
    private func spin(timeout: TimeInterval = 5, until condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return condition()
    }
    #endif

    // MARK: - Rendering helpers

    /// Same size, and no channel of any pixel more than `tolerance` apart.
    private func matches(_ lhs: Data, _ rhs: Data, tolerance: UInt8 = 2) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { max($0, $1) - min($0, $1) <= tolerance }
    }

    /// Evaluates the view's body (and every style's `makeBody`) off-screen.
    private func render(_ view: some View) {
        _ = pixels(view)
    }

    /// Raw rendered pixels via ImageRenderer.
    private func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view.padding(4).background(Color.white))
        renderer.scale = 2
        return renderer.cgImage?.dataProvider?.data as Data?
    }
}
