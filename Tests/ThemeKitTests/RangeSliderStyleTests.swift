//
//  RangeSliderStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `RangeSlider` + `RangeSliderStyle`: the built-in block still draws the
//  1.10.0 pixels, the stock style draws the same pixels through `makeBody`, a
//  custom style receives the pair of values with their positions along the
//  track, the readouts, the marks and the axes — and nothing that would let it
//  re-implement the behaviour — the component still sets the values while a
//  style is drawing, and a style scopes to the sliders it is set around.
//
//  What these tests don't drive: a real drag and the VoiceOver adjustments. A
//  unit-test host injects no touches and builds no accessibility tree without
//  an assistive client (the ADR-0009 rule), and both are the same code on both
//  chrome paths — one gesture, one modifier chain. What they do drive is the
//  value-setting path underneath them, which is what a drag and an adjustment
//  each call, plus the loop back into the style through the caller's binding.
//

import XCTest
import SwiftUI
@testable import ThemeKit

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class RangeSliderStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for fixture in sliderCases {
            XCTAssertNotNil(render(staged(slider(fixture))), fixture.label)
            XCTAssertTrue(drawsInk(staged(slider(fixture))), "\(fixture.label): the fixture renders blank")
        }
    }

    /// With no style set, the block draws the 1.10.0 pixels: extracting the body
    /// behind the `isDefault` branch must move nothing.
    func testBuiltInSliderDrawsTheStockPixels() {
        for fixture in sliderCases where !fixture.inputs {
            let delta = pixelDelta(staged(slider(fixture)), staged(recipe(fixture)))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): the built-in block drifted from 1.10.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(staged(slider(fixture)), staged(recipe(fixture, opacity: 0.6))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// The same, mirrored: the RTL block is hand-mirrored geometry, so it gets
    /// its own comparison against the 1.10.0 recipe.
    func testBuiltInSliderDrawsTheStockPixelsUnderRTL() {
        let fixture = sliderCases[1]   // marks + readouts: everything that mirrors
        let delta = pixelDelta(rtl(staged(slider(fixture))), rtl(staged(recipe(fixture))))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "the mirrored block drifted from 1.10.0")
        XCTAssertTrue(differs(staged(slider(fixture)), rtl(staged(slider(fixture)))),
                      "control: the comparison saw no difference between the two directions")
    }

    /// `.rangeSliderStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for fixture in sliderCases {
            let styled = AnyView(slider(fixture).rangeSliderStyle(.default))
            let delta = pixelDelta(staged(slider(fixture)), staged(styled))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): .default drifted from the built-in block")
            XCTAssertTrue(drawsInk(staged(styled)), "\(fixture.label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(staged(slider(fixture)),
                                  staged(slider(fixture).rangeSliderStyle(DimmedDefaultRangeSliderStyle()))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// …mirrored too: `DefaultRangeSliderStyle` hand-mirrors from the
    /// configuration's `offsetDirection` rather than reading the environment.
    func testDefaultStyleDrawsTheBuiltInPixelsUnderRTL() {
        let fixture = sliderCases[1]
        let styled = AnyView(slider(fixture).rangeSliderStyle(.default))
        let delta = pixelDelta(rtl(staged(slider(fixture))), rtl(staged(styled)))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, ".default drifted from the built-in block under RTL")
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().rangeSliderStyle.isDefault)
        XCTAssertFalse(AnyRangeSliderStyle(DefaultRangeSliderStyle()).isDefault)
    }

    /// With no style set up the tree, the block never asks any style to draw: a
    /// style set on a sibling isn't consulted, and the block still draws the
    /// built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let recorder = RangeSliderConfigurationRecorder()
        let fixture = sliderCases[1]
        let pair = VStack(spacing: 0) {
            slider(fixture)
            Color.clear.frame(width: 320, height: 40).rangeSliderStyle(RecordingRangeSliderStyle(recorder: recorder))
        }
        _ = render(staged(pair))
        XCTAssertTrue(recorder.values.isEmpty, "a style off the slider's path was consulted")
        XCTAssertLessThanOrEqual(pixelDelta(staged(slider(fixture)), staged(recipe(fixture))) ?? .max, pixelNoise)
    }

    // MARK: Custom style — the configuration

    func testCustomStyleReceivesTheSlidersValues() throws {
        let c = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(200), upperValue: .constant(800), in: 0...1000)
            .step(50)
            .marks([0, 250, 1000])
            .accent(.success)
            .valueLabel(money)))

        XCTAssertEqual(c.lowerValue, 200)
        XCTAssertEqual(c.upperValue, 800)
        XCTAssertEqual(c.bounds, 0...1000)
        XCTAssertEqual(c.lowerFraction, 0.2, accuracy: 0.0001, "the lower thumb's place along the track")
        XCTAssertEqual(c.upperFraction, 0.8, accuracy: 0.0001, "the upper thumb's place along the track")
        XCTAssertEqual(c.lowerLabel, "200 $", "the readout arrives formatted, not as a number")
        XCTAssertEqual(c.upperLabel, "800 $")
        XCTAssertEqual(c.marks.map(\.value), [0, 250, 1000])
        XCTAssertEqual(c.marks.map(\.label), ["0 $", "250 $", "1000 $"], "a mark takes the caller's format")
        XCTAssertEqual(c.marks.map(\.fraction), [0, 0.25, 1])
        XCTAssertEqual(c.axis, .horizontal)
        XCTAssertEqual(c.accent, .success)
        XCTAssertEqual(c.step, 50)
        XCTAssertTrue(c.isEnabled)
        XCTAssertNil(c.draggingThumb, "nothing is being dragged")
        XCTAssertNil(c.inputs, "no `.inputs()` asked for")
        XCTAssertEqual(c.thumbSize, 24, "the room the geometry keeps for a knob")
        XCTAssertNil(c.trackLength, "the horizontal track takes the width it is offered")
        XCTAssertEqual(c.offsetDirection, 1)
    }

    /// A bare slider hands the style the same fields, empty.
    func testDefaultsReachTheStyle() throws {
        let c = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(2), upperValue: .constant(6), in: 0...8)))
        XCTAssertEqual(c.lowerFraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(c.upperFraction, 0.75, accuracy: 0.0001)
        XCTAssertNil(c.lowerLabel, "no format set: the stock block draws no readout row")
        XCTAssertNil(c.upperLabel)
        XCTAssertTrue(c.marks.isEmpty)
        XCTAssertNil(c.accent, "the hero tokens")
        XCTAssertEqual(c.step, 1, "the stock step")
        XCTAssertEqual(c.axis, .horizontal)
    }

    /// The marks' captions fall back to whole numbers, exactly as the stock
    /// ticks are labelled.
    func testUnformattedMarksArriveAsWholeNumbers() throws {
        let c = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(0), upperValue: .constant(500), in: 0...1000)
            .marks([250, 750])))
        XCTAssertEqual(c.marks.map(\.label), ["250", "750"])
        XCTAssertEqual(c.marks.map(\.id), [250, 750], "a mark is identified by its value")
    }

    /// A value outside the bounds lands outside 0…1, the way the stock track
    /// draws it — the style is handed the position, not a corrected one.
    func testFractionsFollowTheValuesTheyAreGiven() throws {
        let over = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(-500), upperValue: .constant(1500),
                                                     in: 0...1000)))
        XCTAssertEqual(over.lowerFraction, -0.5, accuracy: 0.0001)
        XCTAssertEqual(over.upperFraction, 1.5, accuracy: 0.0001)

        // A collapsed range can't be divided by: both thumbs sit at the start.
        let flat = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(5), upperValue: .constant(5), in: 5...5)))
        XCTAssertEqual(flat.lowerFraction, 0)
        XCTAssertEqual(flat.upperFraction, 0)
    }

    func testTheVerticalAxisReachesTheStyle() throws {
        let c = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(2), upperValue: .constant(6), in: 0...8)
            .axis(.vertical, height: 140)))
        XCTAssertEqual(c.axis, .vertical)
        XCTAssertEqual(c.trackLength, 140, "the height the caller asked for")
        XCTAssertEqual(c.offsetDirection, 1, "the vertical axis doesn't mirror")
    }

    func testDisabledReachesTheStyle() throws {
        let off = try XCTUnwrap(capture(AnyView(RangeSlider(lowerValue: .constant(200), upperValue: .constant(800),
                                                            in: 0...1000).disabled(true))))
        XCTAssertFalse(off.isEnabled, "the environment's .disabled(_:) reaches the style")
    }

    /// The RTL maths arrives resolved: the fractions still read from the
    /// track's leading edge, and the sign for hand-mirrored moves comes with
    /// them, so a style never mirrors anything itself.
    func testTheRTLMirroringArrivesResolved() throws {
        let c = try XCTUnwrap(capture(AnyView(RangeSlider(lowerValue: .constant(200), upperValue: .constant(800),
                                                          in: 0...1000)
            .environment(\.layoutDirection, .rightToLeft))))
        XCTAssertEqual(c.lowerFraction, 0.2, accuracy: 0.0001, "the fraction is measured from the leading edge")
        XCTAssertEqual(c.offsetDirection, -1, "a mirrored layout flips hand-made x moves")
    }

    /// The linked inputs arrive as a wired view — ThemeKit keeps their
    /// keyboard, focus, parsing and commit — and a style that draws nothing but
    /// them still shows two fields.
    func testTheLinkedInputsArriveWired() throws {
        let c = try XCTUnwrap(capture(RangeSlider(lowerValue: .constant(200), upperValue: .constant(800), in: 0...1000)
            .inputs()))
        XCTAssertNotNil(c.inputs, "`.inputs()` didn't reach the style")
        XCTAssertNil(c.lowerLabel, "the stock block draws the fields instead of the readouts")
        XCTAssertTrue(drawsInk(staged(RangeSlider(lowerValue: .constant(200), upperValue: .constant(800), in: 0...1000)
            .inputs()
            .rangeSliderStyle(InputsOnlyRangeSliderStyle()))), "the wired inputs didn't reach the style")
    }

    // MARK: Custom style — the behaviour stays with the component

    /// The drag's value-setting path — what every touch on the track runs —
    /// still picks the nearer thumb, snaps to the step and clamps to the
    /// bounds while a style draws. (Which thumb a *continuing* drag keeps hold
    /// of is state the rendered view owns, so each call here reads as a fresh
    /// touch.)
    func testTheDragsValueSettingPathStillMovesTheBinding() {
        let box = ValueBox(lower: 200, upper: 800)
        let slider = RangeSlider(lowerValue: box.lowerBinding, upperValue: box.upperBinding, in: 0...1000)
            .step(50)
        XCTAssertTrue(drawsInk(staged(slider.rangeSliderStyle(SlabRangeSliderStyle(fillsWidth: true)))),
                      "the styled slider renders blank")

        slider.move(toward: 430)
        XCTAssertEqual(box.lower, 450, "the nearer thumb wasn't snapped to the step and written back")
        XCTAssertEqual(box.upper, 800, "the other thumb moved")

        slider.move(toward: 5000)
        XCTAssertEqual(box.upper, 1000, "the far thumb wasn't clamped to the upper bound")

        slider.move(toward: -200)
        XCTAssertEqual(box.lower, 0, "the near thumb wasn't clamped to the lower bound")
    }

    /// VoiceOver's adjustment — the action ThemeKit puts on each thumb on both
    /// chrome paths — moves the binding by a step and commits.
    func testTheAdjustableActionStillMovesTheBinding() {
        let box = ValueBox(lower: 200, upper: 800)
        var committed: [(Double, Double)] = []
        let slider = RangeSlider(lowerValue: box.lowerBinding, upperValue: box.upperBinding, in: 0...1000)
            .step(50)
            .onChangeEnd { committed.append(($0, $1)) }

        slider.adjust(isLower: true, increment: true)
        XCTAssertEqual(box.lower, 250, "an increment didn't move the lower thumb by a step")
        slider.adjust(isLower: false, increment: false)
        XCTAssertEqual(box.upper, 750, "a decrement didn't move the upper thumb by a step")
        XCTAssertEqual(committed.count, 2, "the change-end callback didn't fire for each adjustment")
        XCTAssertEqual(committed.last?.0, 250)
        XCTAssertEqual(committed.last?.1, 750)

        // The pair stays ordered: the lower thumb stops at its partner.
        let pair = ValueBox(lower: 700, upper: 750)
        let tight = RangeSlider(lowerValue: pair.lowerBinding, upperValue: pair.upperBinding, in: 0...1000).step(50)
        tight.adjust(isLower: true, increment: true)
        XCTAssertEqual(pair.lower, 750)
        tight.adjust(isLower: true, increment: true)
        XCTAssertEqual(pair.lower, 750, "the lower thumb crossed its partner")
        XCTAssertEqual(pair.upper, 750, "the upper thumb was pushed along")
    }

    /// The loop closes: a value the component writes reaches the style, and so
    /// does one the caller writes from outside.
    func testAStyleFollowsTheBinding() async throws {
        let box = ValueBox(lower: 200, upper: 800)
        let recorder = RangeSliderConfigurationRecorder()
        let host = SliderLiveHost(BoundSliderHost(box: box, recorder: recorder))
        defer { host.tearDown() }

        await host.settle { !recorder.values.isEmpty }
        XCTAssertEqual(recorder.values.last?.lowerValue, 200)

        box.lower = 500
        await host.settle { recorder.values.last?.lowerValue == 500 }
        XCTAssertEqual(recorder.values.last?.lowerValue, 500, "a moved value didn't reach the style")
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).lowerFraction, 0.5, accuracy: 0.0001,
                       "the style's fraction didn't follow the value")
        XCTAssertEqual(recorder.values.last?.lowerLabel, "500 $", "the readout didn't follow the value")
    }

    // MARK: Scope

    /// The style reaches the slider it's set around and nothing else.
    func testStyleReachesOnlyTheSliderItIsSetAround() {
        let recorder = RangeSliderConfigurationRecorder()
        _ = render(staged(VStack(spacing: 0) {
            RangeSlider(lowerValue: .constant(100), upperValue: .constant(200), in: 0...1000)
                .rangeSliderStyle(RecordingRangeSliderStyle(recorder: recorder))
            RangeSlider(lowerValue: .constant(300), upperValue: .constant(400), in: 0...1000)
        }))
        // A styled block measures itself, so it is drawn more than once; what
        // matters is that only the one slider was ever drawn through the style.
        XCTAssertFalse(recorder.values.isEmpty, "the style wasn't consulted at all")
        XCTAssertTrue(recorder.values.allSatisfy { $0.lowerValue == 100 },
                      "the style reached a slider it wasn't set around")
    }

    /// A style set at the root reaches the slider ThemeKit composes inside
    /// `PriceHistogram` (ADR-0009 D6).
    func testAStyleReachesThePriceHistogramsSlider() {
        let recorder = RangeSliderConfigurationRecorder()
        _ = render(staged(PriceHistogram(bins: [3, 8, 5, 2], lowerValue: .constant(200), upperValue: .constant(800),
                                         in: 0...1000)
            .rangeSliderStyle(RecordingRangeSliderStyle(recorder: recorder))))
        XCTAssertFalse(recorder.values.isEmpty, "a style set on the histogram didn't reach the slider inside it")
        XCTAssertTrue(recorder.values.allSatisfy { $0.lowerValue == 200 },
                      "the style drew something other than the histogram's slider")
    }

    // MARK: Layout

    /// ThemeKit wraps nothing around a custom body that changes its size: the
    /// measuring probe, the adjustable thumbs and the drag surface all leave
    /// the layout alone.
    func testCustomBodyGetsNoThemeKitChrome() {
        let base = RangeSlider(lowerValue: .constant(200), upperValue: .constant(800), in: 0...1000)
        let filling = staged(base.rangeSliderStyle(SlabRangeSliderStyle(fillsWidth: true)))
        let hugging = staged(base.rangeSliderStyle(SlabRangeSliderStyle(fillsWidth: false)))
        XCTAssertTrue(drawsInk(filling), "the fixture renders blank")
        let wide = pixelDelta(filling, staged(SlabRangeSliderStyle.slab(fillsWidth: true)))
        XCTAssertNotNil(wide, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(wide ?? .max, pixelNoise, "ThemeKit changed the custom body's width")
        XCTAssertLessThanOrEqual(pixelDelta(hugging, staged(SlabRangeSliderStyle.slab(fillsWidth: false))) ?? .max,
                                 pixelNoise, "ThemeKit stretched a custom body that hugs its content")
        XCTAssertTrue(differs(filling, hugging), "control: the comparison saw no difference")
    }

    // MARK: Fixtures

    private var sliderCases: [SliderCase] {
        [
            SliderCase(label: "readouts"),
            SliderCase(label: "marks + readouts", marks: [0, 250, 500, 750, 1000]),
            SliderCase(label: "bare", labels: false),
            SliderCase(label: "success accent", accent: .success),
            SliderCase(label: "disabled", enabled: false),
            SliderCase(label: "coincident thumbs", lower: 500, upper: 500),
            SliderCase(label: "vertical", axis: .vertical),
            SliderCase(label: "linked inputs", labels: false, inputs: true),
        ]
    }

    /// The fixture as the component draws it.
    private func slider(_ fixture: SliderCase) -> AnyView {
        var slider = RangeSlider(lowerValue: .constant(fixture.lower), upperValue: .constant(fixture.upper),
                                 in: fixture.bounds)
            .step(50)
        if fixture.labels { slider = slider.valueLabel(money) }
        if !fixture.marks.isEmpty { slider = slider.marks(fixture.marks) }
        if let accent = fixture.accent { slider = slider.accent(accent) }
        if fixture.inputs { slider = slider.inputs() }
        if fixture.axis == .vertical { slider = slider.axis(.vertical, height: 140) }
        return fixture.enabled ? AnyView(slider) : AnyView(slider.disabled(true))
    }

    /// The same fixture as 1.10.0 drew it: the old body written out.
    private func recipe(_ fixture: SliderCase, opacity: Double = 1) -> some View {
        var format: ((Double) -> String)?
        if fixture.labels { format = money }
        return V1100RangeSlider(lowerValue: fixture.lower, upperValue: fixture.upper, bounds: fixture.bounds,
                                valueLabel: format, marks: fixture.marks, accent: fixture.accent,
                                isEnabled: fixture.enabled, axis: fixture.axis)
            .opacity(opacity)
    }

    /// The configuration a style is handed for `slider`.
    private func capture(_ slider: some View) -> RangeSliderStyleConfiguration? {
        let recorder = RangeSliderConfigurationRecorder()
        _ = render(staged(slider.rangeSliderStyle(RecordingRangeSliderStyle(recorder: recorder))))
        return recorder.values.last
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 320).padding(8)
    }

    private func rtl(_ view: some View) -> some View {
        view.environment(\.layoutDirection, .rightToLeft)
    }

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func drawsInk(_ view: some View) -> Bool {
        _ = render(view)
        guard let image = render(view), let data = image.dataProvider?.data as Data?, let first = data.first
        else { return false }
        return data.contains { $0 != first }
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second; callers treat a delta up to `pixelNoise` as
    /// identical.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// `true` when two renders are visibly different — either their sizes
    /// differ or a channel moved past the antialiasing noise floor.
    private func differs<A: View, B: View>(_ a: A, _ b: B) -> Bool {
        guard let delta = pixelDelta(a, b) else { return true }
        return delta > pixelNoise
    }

    private let pixelNoise = 2
}

// MARK: - The 1.10.0 recipe (the block written out)

/// `RangeSlider`'s 1.10.0 body, written out: the reference the built-in path
/// must still draw. It sets no value — the pixels are what matter — so it
/// carries neither the gesture nor the thumbs' accessibility.
@available(iOS 16.0, macOS 13.0, *)
private struct V1100RangeSlider: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    var lowerValue: Double
    var upperValue: Double
    var bounds: ClosedRange<Double>
    var valueLabel: ((Double) -> String)?
    var marks: [Double] = []
    var accent: SemanticColor?
    var isEnabled = true
    var axis: Axis = .horizontal
    var verticalHeight: CGFloat = 140

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 4
    private var isRTL: Bool { layoutDirection == .rightToLeft }
    private var dir: CGFloat { isRTL ? -1 : 1 }

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if let valueLabel {
                if axis == .vertical {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Text(valueLabel(lowerValue))
                        Text(verbatim: "–")
                        Text(valueLabel(upperValue))
                    }
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                } else {
                    HStack {
                        Text(valueLabel(lowerValue))
                        Spacer()
                        Text(valueLabel(upperValue))
                    }
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                }
            }

            if axis == .vertical { verticalTrack } else { horizontalTrack }

            if axis == .horizontal, !marks.isEmpty {
                GeometryReader { geo in
                    marksRow(usable: max(geo.size.width - thumbSize, 1), span: bounds.upperBound - bounds.lowerBound)
                }
                .frame(height: 22)
            }
        }
    }

    private var horizontalTrack: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumbSize, 1)
            let span = bounds.upperBound - bounds.lowerBound
            let lowerX = CGFloat((lowerValue - bounds.lowerBound) / span) * usable
            let upperX = CGFloat((upperValue - bounds.lowerBound) / span) * usable

            ZStack(alignment: .leading) {
                Capsule().fill(theme.border(.borderPrimary)).frame(height: trackHeight)
                Capsule().fill(fillColor)
                    .frame(width: max(upperX - lowerX, 0), height: trackHeight)
                    .offset(x: dir * (lowerX + thumbSize / 2))
                thumb.offset(x: dir * lowerX)
                thumb.offset(x: dir * upperX)
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
        .opacity(isEnabled ? 1 : 0.6)
    }

    private var verticalTrack: some View {
        GeometryReader { geo in
            let usable = max(geo.size.height - thumbSize, 1)
            let span = bounds.upperBound - bounds.lowerBound
            let lowerY = CGFloat((lowerValue - bounds.lowerBound) / span) * usable
            let upperY = CGFloat((upperValue - bounds.lowerBound) / span) * usable

            ZStack(alignment: .bottom) {
                Capsule().fill(theme.border(.borderPrimary)).frame(width: trackHeight)
                Capsule().fill(fillColor)
                    .frame(width: trackHeight, height: max(upperY - lowerY, 0))
                    .offset(y: -(lowerY + thumbSize / 2))
                thumb.offset(y: -lowerY)
                thumb.offset(y: -upperY)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: thumbSize, height: verticalHeight)
        .opacity(isEnabled ? 1 : 0.6)
    }

    private var thumb: some View {
        Circle()
            .fill(theme.background(.bgWhite))
            .overlay(Circle().strokeBorder(thumbRingColor, lineWidth: 2))
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
    }

    private func marksRow(usable: CGFloat, span: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks, id: \.self) { mark in
                let ratio = span > 0 ? (mark - bounds.lowerBound) / span : 0
                let ltrX = thumbSize / 2 + CGFloat(ratio) * usable
                let centerX = isRTL ? (usable + thumbSize) - ltrX : ltrX
                VStack(spacing: 2) {
                    Capsule().fill(theme.border(.borderPrimary)).frame(width: 1, height: 5)
                    Text(valueLabel?(mark) ?? String(Int(mark.rounded())))
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textTertiary))
                        .fixedSize()
                }
                .position(x: centerX, y: 11)
            }
        }
    }

    private var fillColor: Color {
        guard isEnabled else { return theme.background(.bgSecondaryLight) }
        return accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero)
    }

    private var thumbRingColor: Color {
        guard isEnabled else { return theme.border(.borderPrimary) }
        return accent.map { theme.resolve($0).solid } ?? theme.border(.borderHero)
    }
}

// MARK: - Fixtures

/// The readout format the fixtures share.
private func money(_ value: Double) -> String { "\(Int(value)) $" }

private struct SliderCase {
    let label: String
    var lower: Double = 200
    var upper: Double = 800
    var bounds: ClosedRange<Double> = 0...1000
    var labels = true
    var marks: [Double] = []
    var accent: SemanticColor?
    var enabled = true
    var axis: Axis = .horizontal
    var inputs = false
}

@MainActor
private final class RangeSliderConfigurationRecorder {
    var values: [RangeSliderStyleConfiguration] = []
}

private struct RecordingRangeSliderStyle: RangeSliderStyle {
    let recorder: RangeSliderConfigurationRecorder

    @MainActor
    func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return Capsule()
            .fill(Color.blue)
            .frame(height: 4)
            .frame(maxWidth: .infinity)
    }
}

/// The stock slider at 60% opacity — the control for the pixel-parity loops.
private struct DimmedDefaultRangeSliderStyle: RangeSliderStyle {
    func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
        DefaultRangeSliderStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// Draws the wired linked inputs and nothing else.
private struct InputsOnlyRangeSliderStyle: RangeSliderStyle {
    func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
        configuration.inputs
    }
}

/// A flat slab, either filling its container's width or hugging its content —
/// the layout proof.
private struct SlabRangeSliderStyle: RangeSliderStyle {
    let fillsWidth: Bool

    @MainActor static func slab(fillsWidth: Bool) -> some View {
        Rectangle().fill(Color.red)
            .frame(width: fillsWidth ? nil : 120, height: 60)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }

    func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
        Self.slab(fillsWidth: fillsWidth)
    }
}

/// The caller-owned pair of the controlled fixtures.
private final class ValueBox: ObservableObject {
    @Published var lower: Double
    @Published var upper: Double

    init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }

    var lowerBinding: Binding<Double> { Binding(get: { self.lower }, set: { self.lower = $0 }) }
    var upperBinding: Binding<Double> { Binding(get: { self.upper }, set: { self.upper = $0 }) }
}

/// A slider whose values the test owns, so it can drive them from outside and
/// watch what reaches the style.
@available(iOS 16.0, macOS 13.0, *)
private struct BoundSliderHost: View {
    @ObservedObject var box: ValueBox
    let recorder: RangeSliderConfigurationRecorder

    var body: some View {
        RangeSlider(lowerValue: $box.lower, upperValue: $box.upper, in: 0...1000)
            .step(50)
            .valueLabel(money)
            .rangeSliderStyle(RecordingRangeSliderStyle(recorder: recorder))
            .frame(width: 320)
    }
}

// MARK: - Live host (state updates an `ImageRenderer` render never runs)

@available(iOS 16.0, macOS 13.0, *)
@MainActor
private final class SliderLiveHost {
    #if canImport(UIKit)
    private let controller: UIHostingController<AnyView>
    private let window: UIWindow
    #else
    private let view: NSHostingView<AnyView>
    private let window: NSWindow
    #endif

    init(_ root: some View) {
        let size = CGSize(width: 360, height: 480)
        #if canImport(UIKit)
        controller = UIHostingController(rootView: AnyView(root))
        window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view = NSHostingView(rootView: AnyView(root))
        view.frame = CGRect(origin: .zero, size: size)
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        #endif
        pump()
    }

    /// Runs the main loop (layout, updates, animations) until `condition`
    /// holds, or for half a second when it never does.
    func settle(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(condition() ? 0 : 0.5)
        repeat {
            pump()
            try? await Task.sleep(nanoseconds: 10_000_000)
        } while !condition() && Date() < deadline
        pump()
    }

    func tearDown() {
        #if canImport(UIKit)
        window.isHidden = true
        #else
        window.orderOut(nil)
        window.contentView = nil
        #endif
    }

    private func pump() {
        #if canImport(UIKit)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        #endif
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
}
