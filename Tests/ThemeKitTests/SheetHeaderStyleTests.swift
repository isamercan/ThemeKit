//
//  SheetHeaderStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 18.09.2026.
//
//  `SheetHeader` + `SheetHeaderStyle`: the built-in header still draws the
//  1.7.0 pixels (the heading trait moves none of them), the stock style draws
//  the same pixels through `makeBody` and still follows the ambient `BarStyle`,
//  a custom style receives the header's content, its wired buttons and its
//  slots, and the accessibility decisions are the same on both paths.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class SheetHeaderStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for (label, header, _) in headerCases {
            XCTAssertNotNil(render(staged(header)), label)
            XCTAssertTrue(drawsInk(staged(header)), "\(label): the fixture renders blank")
        }
    }

    /// The built-in header draws the 1.7.0 pixels: the heading trait and the
    /// shared centre block are additive, so nothing may move.
    func testBuiltInHeaderDrawsThe170Pixels() {
        for (label, header, recipe) in headerCases {
            let delta = pixelDelta(staged(header), staged(recipe))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): the built-in header drifted from 1.7.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertGreaterThan(pixelDelta(staged(header), staged(recipe.opacity(0.6))) ?? 0, pixelNoise,
                                 "\(label) (control): the comparison saw no difference")
        }
    }

    /// `.sheetHeaderStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for (label, header, _) in headerCases {
            let styled = staged(header.sheetHeaderStyle(.default))
            let delta = pixelDelta(staged(header), styled)
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in header")
            XCTAssertTrue(drawsInk(styled), "\(label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            let control = pixelDelta(staged(header), staged(header.sheetHeaderStyle(DimmedDefaultSheetHeaderStyle())))
            XCTAssertNotNil(control, "\(label) (control): renders differ in size or failed")
            XCTAssertGreaterThan(control ?? 0, pixelNoise, "\(label) (control): the comparison saw no difference")
        }
    }

    /// The stock style routes through the ambient `BarStyle`, so a floating bar
    /// stays floating when a style hands the header back to `.default`.
    func testDefaultStyleFollowsTheAmbientBarStyle() {
        let header = SheetHeader("Passengers").onBack {}.onClose {}
        let floating = staged(header.barStyle(.floating))
        let styledFloating = staged(header.barStyle(.floating).sheetHeaderStyle(.default))
        let delta = pixelDelta(floating, styledFloating)
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, ".default ignored the ambient BarStyle")
        XCTAssertTrue(differs(floating, staged(header)), "control: the floating bar is a visible difference")
    }

    /// `surface(_:)` and `showsDivider(_:)` keep winning on the style path —
    /// they ride `\.barChromeOverrides`, which the stock chrome reads.
    func testComponentOverridesStillReachTheStockChrome() {
        let header = SheetHeader("Filters").onClose {}
        let stock = staged(header.sheetHeaderStyle(.default))
        XCTAssertTrue(differs(stock, staged(header.surface(.bgSecondaryLight).sheetHeaderStyle(.default))),
                      "the surface override must still paint the stock chrome")
        XCTAssertTrue(differs(stock, staged(header.showsDivider(false).sheetHeaderStyle(.default))),
                      "the divider override must still reach the stock chrome")
    }

    /// A custom style can read the same overrides from the public environment
    /// value the component sets on both paths.
    func testComponentOverridesReachACustomStyle() throws {
        let box = OverridesBox()
        _ = render(staged(SheetHeader("Filters")
            .surface(.bgSecondaryLight)
            .showsDivider(false)
            .sheetHeaderStyle(OverrideReadingSheetHeaderStyle(box: box))))
        let overrides = try XCTUnwrap(box.values.last)
        XCTAssertEqual(overrides.surface, .bgSecondaryLight)
        XCTAssertFalse(overrides.showsHairline)
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().sheetHeaderStyle.isDefault)
        XCTAssertFalse(AnySheetHeaderStyle(DefaultSheetHeaderStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesContentButtonsAndControlSize() throws {
        let recorder = SheetHeaderConfigurationRecorder()
        var back = 0
        var closed = 0
        let header = SheetHeader("Passengers")
            .subtitle("Who is travelling?")
            .onBack { back += 1 }
            .onClose { closed += 1 }
            .progress(0.4)
            .accent(.success)
            .showsDivider(false)
        _ = render(staged(header.sheetHeaderStyle(RecordingSheetHeaderStyle(recorder: recorder))
            .controlSize(.small)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "Passengers")
        XCTAssertEqual(c.subtitle, "Who is travelling?")
        XCTAssertEqual(c.progress ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(c.accent, .success)
        XCTAssertFalse(c.showsDivider, "the axis arrives as the modifier set it")
        XCTAssertEqual(c.controlSize, .small)
        XCTAssertNotNil(c.backButton, "the back button arrives wired")
        XCTAssertNotNil(c.closeButton, "…and so does the close button")
        XCTAssertNotNil(c.onBack, "…and raw, for a style that draws its own")
        XCTAssertNotNil(c.onClose)
        c.onBack?()
        c.onClose?()
        XCTAssertEqual(back, 1, "the raw handler is the header's own")
        XCTAssertEqual(closed, 1)
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = SheetHeaderConfigurationRecorder()
        _ = render(staged(SheetHeader("Filters").sheetHeaderStyle(RecordingSheetHeaderStyle(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "Filters")
        XCTAssertNil(c.subtitle)
        XCTAssertNil(c.backButton)
        XCTAssertNil(c.onBack)
        XCTAssertNil(c.closeButton)
        XCTAssertNil(c.onClose)
        XCTAssertNil(c.progress)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.trailing)
        XCTAssertNil(c.accent)
        XCTAssertTrue(c.showsDivider)
        XCTAssertEqual(c.controlSize, .regular)
    }

    /// The slots arrive exactly as written, beside the wired buttons they
    /// replace — the style decides which to draw.
    func testSlotsReachTheStyleBesideTheWiredButtons() throws {
        let recorder = SheetHeaderConfigurationRecorder()
        _ = render(staged(SheetHeader("Passengers")
            .onBack {}
            .onClose {}
            .leading { Text("L") }
            .trailing { Text("T") }
            .sheetHeaderStyle(RecordingSheetHeaderStyle(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNotNil(c.leading)
        XCTAssertNotNil(c.trailing)
        XCTAssertNotNil(c.backButton, "the wired button is still there — the slot replaces it, the style chooses")
        XCTAssertNotNil(c.closeButton)
    }

    /// The stock chrome draws the slot in place of the wired button, exactly as
    /// the built-in path does.
    func testDefaultStyleDrawsTheSlotsInsteadOfTheButtons() {
        let header = SheetHeader("Passengers").onBack {}.onClose {}
            .leading { Text("L") }
            .trailing { Text("T") }
        XCTAssertTrue(drawsInk(staged(header)), "the slot fixture renders nothing")
        let delta = pixelDelta(staged(header), staged(header.sheetHeaderStyle(.default)))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, ".default drifted on the slot path")
        // The control: a header without the slots must not match this one, so a
        // pair of blank renders can't pass the comparison above.
        XCTAssertTrue(differs(staged(header), staged(SheetHeader("Passengers").onBack {}.onClose {})),
                      "the control sees no change")
    }

    /// The wired buttons arrive with no font and no colour of their own, so the
    /// style's type and tokens take effect.
    func testWiredButtonsArriveUnpainted() {
        let header = SheetHeader("Passengers").onBack {}.onClose {}
        let small = staged(header.sheetHeaderStyle(GlyphSizedSheetHeaderStyle(points: 10)))
        let large = staged(header.sheetHeaderStyle(GlyphSizedSheetHeaderStyle(points: 28)))
        XCTAssertTrue(differs(small, large), "the style's font must reach the wired buttons' glyphs")
        XCTAssertTrue(drawsInk(small), "the fixture renders blank")
    }

    /// A style set on a container reaches the headers below it.
    func testContainerStyleReachesNestedHeaders() {
        let recorder = SheetHeaderConfigurationRecorder()
        let stack = VStack {
            SheetHeader("First")
            SheetHeader("Second")
        }
        _ = render(staged(stack.sheetHeaderStyle(RecordingSheetHeaderStyle(recorder: recorder))))
        XCTAssertTrue(recorder.values.contains { $0.title == "First" })
        XCTAssertTrue(recorder.values.contains { $0.title == "Second" })
    }

    // MARK: Accessibility decisions

    /// A unit-test host builds no accessibility tree, so the decisions are
    /// tested where they're made (the same helper both paths use).
    func testTitleIsTheHeadersHeading() {
        XCTAssertEqual(SheetHeaderAccessibility.traits, .isHeader)
    }

    func testBackAndCloseKeepTheirLabels() {
        XCTAssertEqual(SheetHeaderAccessibility.label(forGlyph: "xmark"), SheetHeaderAccessibility.closeLabel)
        XCTAssertEqual(SheetHeaderAccessibility.label(forGlyph: "chevron.left"), SheetHeaderAccessibility.backLabel)
        XCTAssertFalse(SheetHeaderAccessibility.backLabel.isEmpty)
        XCTAssertFalse(SheetHeaderAccessibility.closeLabel.isEmpty)
        XCTAssertNotEqual(SheetHeaderAccessibility.backLabel, SheetHeaderAccessibility.closeLabel)
    }

    /// A progress value is a fraction of the flow: anything outside 0…1 clamps
    /// rather than overflowing the line.
    func testProgressValueIsAClampedFraction() {
        XCTAssertEqual(SheetHeaderAccessibility.clamped(0.4), 0.4, accuracy: 0.0001)
        XCTAssertEqual(SheetHeaderAccessibility.clamped(-2), 0, accuracy: 0.0001)
        XCTAssertEqual(SheetHeaderAccessibility.clamped(9), 1, accuracy: 0.0001)
        XCTAssertEqual(SheetHeaderAccessibility.progressValue(0.75, locale: Locale(identifier: "en_US")), "75%")
        XCTAssertEqual(SheetHeaderAccessibility.progressValue(4, locale: Locale(identifier: "en_US")), "100%",
                       "an out-of-range value speaks its clamped self")
        XCTAssertFalse(SheetHeaderAccessibility.progressLabel.isEmpty)
    }

    /// The heading semantics cost no pixels — the fix is additive.
    func testHeadingSemanticsDontMovePixels() {
        let header = SheetHeader("Payment").subtitle("Step 3 of 4").onBack {}.onClose {}
        let recipe = V170SheetHeader(title: "Payment", subtitle: "Step 3 of 4", hasBack: true, hasClose: true)
        XCTAssertLessThanOrEqual(pixelDelta(staged(header), staged(recipe)) ?? .max, pixelNoise)
    }

    // MARK: Fixtures

    private var headerCases: [(String, SheetHeader, V170SheetHeader)] {
        [
            ("title only", SheetHeader("Filters"), V170SheetHeader(title: "Filters")),
            ("back + close", SheetHeader("Passengers").onBack {}.onClose {},
             V170SheetHeader(title: "Passengers", hasBack: true, hasClose: true)),
            ("close only", SheetHeader("Filters").onClose {},
             V170SheetHeader(title: "Filters", hasClose: true)),
            ("subtitle", SheetHeader("Payment").subtitle("Step 3 of 4").onBack {},
             V170SheetHeader(title: "Payment", subtitle: "Step 3 of 4", hasBack: true)),
            ("progress", SheetHeader("Payment").subtitle("Step 3 of 4").onBack {}.onClose {}.progress(0.75),
             V170SheetHeader(title: "Payment", subtitle: "Step 3 of 4", hasBack: true, hasClose: true, progress: 0.75)),
            ("accented progress", SheetHeader("Payment").onClose {}.progress(0.4).accent(.success),
             V170SheetHeader(title: "Payment", hasClose: true, progress: 0.4, accent: .success)),
            ("no divider", SheetHeader("Filters").onClose {}.showsDivider(false),
             V170SheetHeader(title: "Filters", hasClose: true, showsDivider: false)),
            ("tinted surface", SheetHeader("Filters").onClose {}.surface(.bgSecondaryLight),
             V170SheetHeader(title: "Filters", hasClose: true, surface: .bgSecondaryLight)),
        ]
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 360).padding(8)
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

    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// `true` when two renders are visibly different — either their sizes
    /// differ (a hairline dropped, a bar inset) or a channel moved past the
    /// antialiasing noise floor. The controls use it so "same size, no change"
    /// and "different size" can't both read as "no difference".
    private func differs<A: View, B: View>(_ a: A, _ b: B) -> Bool {
        guard let delta = pixelDelta(a, b) else { return true }
        return delta > pixelNoise
    }

    private let pixelNoise = 2
}

// MARK: - The 1.7.0 recipe (verbatim header)

/// `SheetHeader`'s 1.7.0 body, written out: the reference the built-in path
/// must still draw — the centre block composed inline and handed to the
/// ambient `BarStyle`, with the component's overrides on the environment.
@available(iOS 16.0, macOS 13.0, *)
private struct V170SheetHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.barStyle) private var barStyle
    @Environment(\.locale) private var locale

    let title: String
    var subtitle: String?
    var hasBack = false
    var hasClose = false
    var progress: Double?
    var showsDivider = true
    var accent: SemanticColor?
    var surface: Theme.BackgroundColorKey?

    /// The recipe's buttons do nothing; the pixels are what matter.
    private func noop() {}

    private var accentBase: Color { theme.resolve(accent ?? .primary).base }

    var body: some View {
        barStyle.makeBody(configuration: configuration)
            .environment(\.barChromeOverrides,
                         BarChromeOverrides(surface: surface,
                                            showsHairline: showsDivider && progress == nil))
    }

    private var configuration: BarStyleConfiguration {
        BarStyleConfiguration(leading: leadingView,
                              content: AnyView(contentStack),
                              trailing: trailingView,
                              edge: .top)
    }

    private var leadingView: AnyView? {
        hasBack ? AnyView(iconButton("chevron.left", noop).mirrorsInRTL()) : nil
    }

    private var trailingView: AnyView? {
        hasClose ? AnyView(iconButton("xmark", noop)) : nil
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(title).textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
            }
            .padding(.horizontal, BarMetrics.contentInset(density))
            .frame(maxWidth: .infinity)
            .frame(height: BarMetrics.rowHeight)

            if let progress {
                progressBar(progress)
            }
        }
    }

    private func iconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.text(.textPrimary))
                .frame(width: BarMetrics.slotSize, height: BarMetrics.slotSize)
        }
        .buttonStyle(.plain)
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.border(.borderPrimary))
                Rectangle().fill(accentBase).frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Fixture styles

@MainActor
private final class SheetHeaderConfigurationRecorder {
    var values: [SheetHeaderStyleConfiguration] = []
}

private struct RecordingSheetHeaderStyle: SheetHeaderStyle {
    let recorder: SheetHeaderConfigurationRecorder

    @MainActor
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return HStack {
            configuration.leading ?? configuration.backButton
            configuration.content
            configuration.trailing ?? configuration.closeButton
        }
    }
}

/// Draws the wired buttons at a caller-chosen point size — the proof that they
/// arrive un-fonted.
private struct GlyphSizedSheetHeaderStyle: SheetHeaderStyle {
    let points: CGFloat

    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        HStack {
            configuration.backButton
            configuration.content
            configuration.closeButton
        }
        .font(.system(size: points, weight: .semibold))
    }
}

@MainActor
private final class OverridesBox {
    var values: [BarChromeOverrides] = []
}

/// Records the component overrides the header puts on the environment for the
/// style, then draws the stock header.
private struct OverrideReadingSheetHeaderStyle: SheetHeaderStyle {
    let box: OverridesBox

    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        OverrideReadingBody(box: box, configuration: configuration)
    }
}

private struct OverrideReadingBody: View {
    let box: OverridesBox
    let configuration: SheetHeaderStyleConfiguration
    @Environment(\.barChromeOverrides) private var overrides

    var body: some View {
        box.values.append(overrides)
        return DefaultSheetHeaderStyle().makeBody(configuration: configuration)
    }
}

/// The stock header at 60% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultSheetHeaderStyle: SheetHeaderStyle {
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        DefaultSheetHeaderStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}
