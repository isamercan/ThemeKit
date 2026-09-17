//
//  TitleStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  `Title` + `TitleStyle`: the built-in title still draws the 1.6.0 pixels
//  (the accessibility fix moves none of them), the stock style draws the same
//  pixels as the built-in path, a custom style receives the title's content and
//  its wired action, the new `.leading { }` slot behaves, and the heading
//  decision (`.isHeader`, one element with the eyebrow and subtitle) is the
//  same on both paths.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class TitleStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(Title("Section")), "title only")
        XCTAssertNotNil(render(Title("Section").subtitle("Sub")), "subtitle")
        XCTAssertNotNil(render(Title("Section").eyebrow("New")), "eyebrow")
        XCTAssertNotNil(render(Title("Section").action("See all") {}), "action")
        XCTAssertNotNil(render(Title("Section").leading { Image(systemName: "star.fill") }), "leading slot")
    }

    /// The built-in title draws the 1.6.0 pixels: the slot and the heading
    /// semantics are additive, so a title without a slot must not move.
    func testBuiltInTitleDrawsThe160Pixels() {
        let cases: [(String, Title, V160Title)] = [
            ("plain", Title("Recently viewed"), V160Title(text: "Recently viewed")),
            ("subtitle", Title("Popular destinations").subtitle("Where travellers go"),
             V160Title(text: "Popular destinations", subtitle: "Where travellers go")),
            ("eyebrow", Title("Deals").eyebrow("Limited time"),
             V160Title(text: "Deals", eyebrow: "Limited time")),
            ("action", Title("Popular destinations").subtitle("Where travellers go").action("See all") {},
             V160Title(text: "Popular destinations", subtitle: "Where travellers go", actionTitle: "See all")),
            ("everything", Title("Deals").eyebrow("Limited time").subtitle("Ends Sunday").action("See all") {},
             V160Title(text: "Deals", subtitle: "Ends Sunday", eyebrow: "Limited time", actionTitle: "See all")),
        ]
        for (label, title, recipe) in cases {
            let delta = pixelDelta(staged(title), staged(recipe))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): the built-in title drifted from 1.6.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertGreaterThan(pixelDelta(staged(title), staged(recipe.opacity(0.6))) ?? 0, pixelNoise,
                                 "\(label) (control): the comparison saw no difference")
        }
    }

    /// `.titleStyle(.default)` goes through `makeBody`, yet must draw the same
    /// pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for (label, title) in styleCases {
            let delta = pixelDelta(staged(title), staged(title.titleStyle(.default)))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in title")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            let control = pixelDelta(staged(title), staged(title.titleStyle(DimmedDefaultTitleStyle())))
            XCTAssertNotNil(control, "\(label) (control): renders differ in size or failed")
            XCTAssertGreaterThan(control ?? 0, pixelNoise, "\(label) (control): the comparison saw no difference")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().titleStyle.isDefault)
        XCTAssertFalse(AnyTitleStyle(DefaultTitleStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesContentActionAndControlSize() throws {
        let recorder = TitleConfigurationRecorder()
        var tapped = 0
        let title = Title("Popular destinations")
            .eyebrow("This week")
            .subtitle("Where travellers go")
            .leading { Image(systemName: "sparkles") }
            .action("See all") { tapped += 1 }
        _ = render(title.titleStyle(RecordingTitleStyle(recorder: recorder)).controlSize(.small))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.text, "Popular destinations")
        XCTAssertEqual(c.eyebrow, "This week", "the eyebrow arrives as written, not uppercased")
        XCTAssertEqual(c.subtitle, "Where travellers go")
        XCTAssertEqual(c.actionTitle, "See all")
        XCTAssertNotNil(c.leading)
        XCTAssertNotNil(c.action, "the action arrives wired")
        XCTAssertNotNil(c.onAction, "…and raw, for a style that draws its own button")
        XCTAssertEqual(c.controlSize, .small)
        c.onAction?()
        XCTAssertEqual(tapped, 1, "the raw handler is the title's own")
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = TitleConfigurationRecorder()
        _ = render(Title("Plain").titleStyle(RecordingTitleStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.text, "Plain")
        XCTAssertNil(c.eyebrow)
        XCTAssertNil(c.subtitle)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.actionTitle)
        XCTAssertNil(c.action)
        XCTAssertNil(c.onAction)
        XCTAssertEqual(c.controlSize, .regular)
    }

    /// A link with no handler isn't drawn on either path.
    func testActionWithoutHandlerArrivesUnwired() throws {
        let recorder = TitleConfigurationRecorder()
        _ = render(Title("Section").action("See all").titleStyle(RecordingTitleStyle(recorder: recorder)))
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.actionTitle, "See all")
        XCTAssertNil(c.action)
        XCTAssertNil(c.onAction)
    }

    /// A style set on a container reaches the titles below it.
    func testContainerStyleReachesNestedTitles() {
        let recorder = TitleConfigurationRecorder()
        let stack = VStack {
            Title("First")
            Title("Second")
        }
        _ = render(stack.titleStyle(RecordingTitleStyle(recorder: recorder)))
        XCTAssertTrue(recorder.values.contains { $0.text == "First" })
        XCTAssertTrue(recorder.values.contains { $0.text == "Second" })
    }

    // MARK: Leading slot

    /// On the built-in path the slot sits before the title's text: a title with
    /// a slot differs from one without, and matches the same row built by hand.
    func testLeadingSlotDrawsBeforeTheText() {
        let plain = Title("Nearby")
        let withSlot = Title("Nearby").leading { Image(systemName: "location.fill") }
        XCTAssertGreaterThan(pixelDelta(staged(plain), staged(withSlot)) ?? 0, pixelNoise,
                             "the slot must show on the built-in path")
        let recipe = V160Title(text: "Nearby", leadingSystemImage: "location.fill")
        let delta = pixelDelta(staged(withSlot), staged(recipe))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "the slot isn't drawn before the text")
    }

    func testLeadingSlotReachesTheStyleUntouched() throws {
        let recorder = TitleConfigurationRecorder()
        _ = render(Title("Nearby").leading { Text("L") }
            .titleStyle(RecordingTitleStyle(recorder: recorder)))
        XCTAssertNotNil(try XCTUnwrap(recorder.values.last).leading)
    }

    // MARK: Accessibility decisions

    /// A unit-test host builds no accessibility tree, so the decisions are
    /// tested where they're made (the same helper both paths use).
    func testTitleIsAHeading() {
        XCTAssertEqual(TitleAccessibility.traits, .isHeader)
    }

    func testHeadingLabelReadsEyebrowTitleAndSubtitleAsOneElement() {
        XCTAssertEqual(TitleAccessibility.label(text: "Deals", eyebrow: "Limited time", subtitle: "Ends Sunday"),
                       "Limited time, Deals, Ends Sunday")
        XCTAssertEqual(TitleAccessibility.label(text: "Deals", eyebrow: nil, subtitle: nil), "Deals")
        XCTAssertEqual(TitleAccessibility.label(text: "Deals", eyebrow: "", subtitle: "Ends Sunday"),
                       "Deals, Ends Sunday", "empty strings are left out")
    }

    /// The heading semantics cost no pixels — the fix is additive.
    func testHeadingSemanticsDontMovePixels() {
        let title = Title("Deals").eyebrow("Limited time").subtitle("Ends Sunday").action("See all") {}
        let delta = pixelDelta(staged(title), staged(V160Title(text: "Deals", subtitle: "Ends Sunday",
                                                               eyebrow: "Limited time", actionTitle: "See all")))
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise)
    }

    // MARK: Helpers

    private var styleCases: [(String, Title)] {
        [
            ("plain", Title("Recently viewed")),
            ("subtitle", Title("Popular destinations").subtitle("Where travellers go")),
            ("eyebrow", Title("Deals").eyebrow("Limited time")),
            ("eyebrow + subtitle", Title("Deals").eyebrow("Limited time").subtitle("Ends Sunday")),
            ("action", Title("Popular destinations").action("See all") {}),
            ("everything", Title("Deals").eyebrow("Limited time").subtitle("Ends Sunday").action("See all") {}),
            ("leading slot", Title("Nearby").leading { Image(systemName: "location.fill") }),
            ("leading slot + action", Title("Nearby").subtitle("Within 50 km")
                .leading { Image(systemName: "location.fill") }.action("See all") {}),
            ("action without handler", Title("Section").action("See all")),
        ]
    }

    /// A fixed width, so the `Spacer` between the text column and the action
    /// has a width to take.
    private func staged(_ view: some View) -> some View {
        view.frame(width: 320).padding(8)
    }

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
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

    private let pixelNoise = 2
}

// MARK: - The 1.6.0 recipe (verbatim title)

/// `Title`'s 1.6.0 body, written out: the reference the built-in path must
/// still draw. The leading row is the 1.7.0 slot's documented placement.
@available(iOS 16.0, macOS 13.0, *)
private struct V160Title: View {
    @Environment(\.theme) private var theme

    let text: String
    var subtitle: String?
    var eyebrow: String?
    var actionTitle: String?
    var leadingSystemImage: String?

    /// The recipe's button does nothing; the pixels are what matter.
    private func noop() {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .textStyle(.overline500)
                        .foregroundStyle(theme.text(.textHero))
                }
                if let leadingSystemImage {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Image(systemName: leadingSystemImage)
                        Text(text)
                            .textStyle(.headingBase)
                            .foregroundStyle(theme.text(.textPrimary))
                    }
                } else {
                    Text(text)
                        .textStyle(.headingBase)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let actionTitle {
                Button(action: noop) {
                    Text(actionTitle).textStyle(.linkBase).foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Fixture styles

@MainActor
private final class TitleConfigurationRecorder {
    var values: [TitleStyleConfiguration] = []
}

private struct RecordingTitleStyle: TitleStyle {
    let recorder: TitleConfigurationRecorder

    @MainActor
    func makeBody(configuration: TitleStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return VStack(alignment: .leading) {
            configuration.leading
            configuration.content
            configuration.action
        }
    }
}

/// The stock title at 60% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultTitleStyle: TitleStyle {
    func makeBody(configuration: TitleStyleConfiguration) -> some View {
        DefaultTitleStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}
