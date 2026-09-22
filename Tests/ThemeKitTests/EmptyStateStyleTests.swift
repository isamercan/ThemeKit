//
//  EmptyStateStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 22.09.2026.
//
//  `EmptyState` + `EmptyStateStyle`: the built-in block still draws the 1.9.0
//  pixels, the stock style draws the same pixels through `makeBody`, a custom
//  style receives the block's content — strings, links, media, actions and the
//  custom actions slot — the actions run the caller's handlers, and a style
//  scopes to the empty states it is set around.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class EmptyStateStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for fixture in emptyStateCases {
            XCTAssertNotNil(render(staged(block(fixture))), fixture.label)
            XCTAssertTrue(drawsInk(staged(block(fixture))), "\(fixture.label): the fixture renders blank")
        }
    }

    /// With no style set, the block draws the 1.9.0 pixels: extracting the body
    /// behind the `isDefault` branch must move nothing.
    func testBuiltInBlockDrawsThe190Pixels() {
        for fixture in emptyStateCases {
            let delta = pixelDelta(staged(block(fixture)), staged(recipe(fixture)))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): the built-in block drifted from 1.9.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(staged(block(fixture)), staged(recipe(fixture, opacity: 0.6))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// The illustration media — an `Image` and an animated URL — draws the
    /// 1.9.0 pixels too.
    func testBuiltInIllustrationMediaDrawsThe190Pixels() {
        let image = EmptyState(image: Image(systemName: "photo"), title: "Nothing here")
            .message("Add your first photo.")
            .imageMaxHeight(72)
        let imageRecipe = V190EmptyState(media: .image(Image(systemName: "photo")), title: "Nothing here",
                                         message: "Add your first photo.", imageMaxHeight: 72)
        XCTAssertTrue(drawsInk(staged(image)), "the image fixture renders blank")
        XCTAssertLessThanOrEqual(pixelDelta(staged(image), staged(imageRecipe)) ?? .max, pixelNoise,
                                 "the image block drifted from 1.9.0")

        let animated = EmptyState(animatedURL: nil, title: "Nothing here").message("Check back later.")
        let animatedRecipe = V190EmptyState(media: .animated(nil), title: "Nothing here", message: "Check back later.")
        XCTAssertLessThanOrEqual(pixelDelta(staged(animated), staged(animatedRecipe)) ?? .max, pixelNoise,
                                 "the animated block drifted from 1.9.0")
    }

    /// `.emptyStateStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for fixture in emptyStateCases {
            let styled = block(fixture).emptyStateStyle(.default)
            let delta = pixelDelta(staged(block(fixture)), staged(styled))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): .default drifted from the built-in block")
            XCTAssertTrue(drawsInk(staged(styled)), "\(fixture.label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(staged(block(fixture)), staged(block(fixture).emptyStateStyle(DimmedDefaultEmptyStateStyle()))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// The same parity for the media variants and for the icon axes a style
    /// could quietly drop: the tints, the circle's diameter and the
    /// illustration's height.
    func testDefaultStyleDrawsTheBuiltInMediaAndIconPixels() {
        let cases: [(String, AnyView)] = [
            ("custom image", AnyView(EmptyState(image: Image(systemName: "photo"), title: "Nothing here")
                .message("Add your first photo.").imageMaxHeight(72))),
            ("animated URL", AnyView(EmptyState(animatedURL: nil, title: "Nothing here"))),
            ("token tints", AnyView(EmptyState("No results").icon("magnifyingglass")
                .iconForeground(.systemcolorsFgError).iconBackground(.bgSecondaryLight))),
            ("tight circle", AnyView(EmptyState("No results").icon("magnifyingglass").iconCircleSize(48))),
        ]
        for (label, view) in cases {
            XCTAssertTrue(drawsInk(staged(view)), "\(label): the fixture renders blank")
            let delta = pixelDelta(staged(view), staged(view.emptyStateStyle(.default)))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in block")
        }
    }

    /// A half-set action (a title with no handler) draws no button on either
    /// path, so `.default` matches the built-in block there too.
    func testDefaultStyleMatchesTheBuiltInForAHalfSetAction() {
        let halved = EmptyState("Nothing here").message("Try another search.").primaryAction("Go", action: nil)
        XCTAssertTrue(drawsInk(staged(halved)), "the fixture renders blank")
        XCTAssertLessThanOrEqual(pixelDelta(staged(halved), staged(halved.emptyStateStyle(.default))) ?? .max,
                                 pixelNoise, ".default drifted on a half-set action")
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().emptyStateStyle.isDefault)
        XCTAssertFalse(AnyEmptyStateStyle(DefaultEmptyStateStyle()).isDefault)
    }

    /// With no style set up the tree, the block never asks any style to draw:
    /// a style set on a sibling isn't consulted, and the block still draws the
    /// built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let recorder = EmptyStateConfigurationRecorder()
        let fixture = emptyStateCases[2]
        let pair = VStack(spacing: 0) {
            block(fixture)
            Color.clear.frame(width: 320, height: 40).emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))
        }
        _ = render(staged(pair))
        XCTAssertTrue(recorder.values.isEmpty, "a style off the empty state's path was consulted")
        XCTAssertLessThanOrEqual(pixelDelta(staged(block(fixture)), staged(recipe(fixture))) ?? .max, pixelNoise)
    }

    // MARK: Custom style — the configuration

    func testCustomStyleReceivesTheBlocksContent() throws {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(EmptyState("No results found")
            .icon("magnifyingglass")
            .message("Try adjusting your search or filters.")
            .primaryAction("Clear filters") {}
            .secondaryAction("Browse all") {}
            .emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "No results found")
        XCTAssertEqual(c.message, "Try adjusting your search or filters.")
        XCTAssertTrue(c.messageLinks.isEmpty)
        XCTAssertNotNil(c.messageContent, "a message reaches the style ready to paint")
        XCTAssertEqual(symbolName(c.mediaKind), "magnifyingglass")
        XCTAssertEqual(c.primaryAction?.title, "Clear filters")
        XCTAssertEqual(c.secondaryAction?.title, "Browse all")
        XCTAssertNil(c.actions, "no `.actions { }` slot set")
        XCTAssertEqual(c.iconCircleSize, 88)
        XCTAssertEqual(c.imageMaxHeight, 160)
        XCTAssertEqual(c.iconForeground, Theme.shared.foreground(.fgHero))
        XCTAssertEqual(c.iconBackground, Theme.shared.background(.bgElevatorTertiary))
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(EmptyState().emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNil(c.title, "no title → none reaches the style")
        XCTAssertNil(c.message)
        XCTAssertNil(c.messageContent)
        XCTAssertTrue(c.messageLinks.isEmpty)
        XCTAssertEqual(symbolName(c.mediaKind), "tray", "the stock SF Symbol")
        XCTAssertNil(c.primaryAction)
        XCTAssertNil(c.secondaryAction)
        XCTAssertNil(c.actions)
    }

    /// Each media overload reaches the style as its own variant.
    func testMediaKindFollowsTheChosenOverload() throws {
        let symbol = try XCTUnwrap(capture(EmptyState("A").icon("airplane")))
        XCTAssertEqual(symbolName(symbol.mediaKind), "airplane")

        let image = try XCTUnwrap(capture(EmptyState(image: Image(systemName: "photo"), title: "A")))
        guard case .image = image.mediaKind else { return XCTFail("the Image overload didn't reach the style as .image") }

        let url = URL(string: "https://example.com/empty.gif")
        let animated = try XCTUnwrap(capture(EmptyState(animatedURL: url, title: "A")))
        guard case .animated(let carried) = animated.mediaKind else {
            return XCTFail("the animatedURL overload didn't reach the style as .animated")
        }
        XCTAssertEqual(carried, url)
    }

    /// An action needs both halves: a title with no handler draws no button on
    /// the stock block, so it reaches no style either.
    func testAnActionNeedsATitleAndAHandler() throws {
        let titleOnly = try XCTUnwrap(capture(EmptyState("A").primaryAction("Go", action: nil)
            .secondaryAction("Back", action: nil)))
        XCTAssertNil(titleOnly.primaryAction, "a primary title with no handler reaches no style")
        XCTAssertNil(titleOnly.secondaryAction, "a secondary title with no handler reaches no style")

        let handlerOnly = try XCTUnwrap(capture(EmptyState("A").primaryAction(nil) {}.secondaryAction(nil) {}))
        XCTAssertNil(handlerOnly.primaryAction, "a primary handler with no title reaches no style")
        XCTAssertNil(handlerOnly.secondaryAction, "a secondary handler with no title reaches no style")
    }

    /// The icon axes a style may want to redraw itself arrive resolved against
    /// the environment theme — both the token-bound and the raw spelling.
    func testIconAxesReachTheStyleResolved() throws {
        let tokens = try XCTUnwrap(capture(EmptyState("A").icon("star")
            .iconForeground(.systemcolorsFgError).iconBackground(.bgSecondaryLight).iconCircleSize(56)))
        XCTAssertEqual(tokens.iconForeground, Theme.shared.foreground(.systemcolorsFgError))
        XCTAssertEqual(tokens.iconBackground, Theme.shared.background(.bgSecondaryLight))
        XCTAssertEqual(tokens.iconCircleSize, 56)

        let raw = try XCTUnwrap(capture(EmptyState("A").icon("star").imageMaxHeight(72)))
        XCTAssertEqual(raw.imageMaxHeight, 72)
    }

    /// A message with inline links reaches the style as the raw string, the
    /// links themselves, and a ready-made view that routes a tapped link to
    /// its handler.
    func testMessageLinksReachTheStyleAndStillRoute() throws {
        var opened = 0
        let c = try XCTUnwrap(capture(EmptyState("Nothing yet")
            .message("Read the docs.", links: [("docs", { opened += 1 })])))
        XCTAssertEqual(c.message, "Read the docs.", "the message arrives raw, links and all")
        XCTAssertEqual(c.messageLinks.count, 1)
        XCTAssertEqual(c.messageLinks.first?.substring, "docs")
        XCTAssertNotNil(c.messageContent)
        c.messageLinks.first?.action()
        XCTAssertEqual(opened, 1, "the link's handler reaches the style intact")

        // The ready-made content carries the marking a plain `Text` of the same
        // string doesn't: the link run is tinted and underlined, so the two
        // render differently under the same paint.
        let linked = EmptyState("Nothing yet").message("Read the docs.", links: [("docs", {})])
        let plain = EmptyState("Nothing yet").message("Read the docs.")
        XCTAssertTrue(drawsInk(staged(linked.emptyStateStyle(MessageOnlyEmptyStateStyle()))),
                      "the message content renders blank")
        XCTAssertTrue(differs(staged(linked.emptyStateStyle(MessageOnlyEmptyStateStyle())),
                              staged(plain.emptyStateStyle(MessageOnlyEmptyStateStyle()))),
                      "the ready-made message content lost its link marking")
    }

    /// A message with no links still arrives ready to paint, and a style's own
    /// type style and colour take on it (it carries neither).
    func testMessageContentTakesTheStylesPaint() throws {
        let state = EmptyState("Nothing yet").message("Try another search.")
        XCTAssertTrue(drawsInk(staged(state.emptyStateStyle(MessageOnlyEmptyStateStyle()))))
        XCTAssertTrue(differs(staged(state.emptyStateStyle(MessageOnlyEmptyStateStyle())),
                              staged(state.emptyStateStyle(MessageOnlyEmptyStateStyle(tinted: true)))),
                      "the message content ignored the style's paint")
    }

    /// The custom `.actions { }` slot reaches the style as it was written, and
    /// the stock actions stay beside it (the slot replaces them — that rule is
    /// the style's to apply, as on the stock block).
    func testCustomActionsSlotReachesTheStyle() throws {
        let c = try XCTUnwrap(capture(EmptyState("Nothing yet")
            .primaryAction("Search") {}
            .actions { Text("Slot") }))
        XCTAssertNotNil(c.actions, "the `.actions { }` slot reaches the style")
        XCTAssertEqual(c.primaryAction?.title, "Search", "the stock action is still carried beside the slot")

        // The slot's content is what the caller wrote: a style that draws it
        // draws that text.
        XCTAssertTrue(drawsInk(staged(EmptyState("Nothing yet")
            .actions { Text("Slot") }
            .emptyStateStyle(ActionsOnlyEmptyStateStyle()))))
    }

    /// Each action runs the caller's handler, once per call.
    func testActionsRunTheCallersHandlers() throws {
        var primaryRan = 0
        var secondaryRan = 0
        let c = try XCTUnwrap(capture(EmptyState("Nothing yet")
            .primaryAction("Retry") { primaryRan += 1 }
            .secondaryAction("Cancel") { secondaryRan += 1 }))

        try XCTUnwrap(c.primaryAction).perform()
        XCTAssertEqual(primaryRan, 1, "the caller's primary handler ran")
        XCTAssertEqual(secondaryRan, 0, "the primary ran the secondary's handler")

        try XCTUnwrap(c.secondaryAction).perform()
        XCTAssertEqual(secondaryRan, 1, "the caller's secondary handler ran")
        XCTAssertEqual(primaryRan, 1, "the secondary ran the primary's handler")
    }

    // MARK: Scope

    /// The style reaches the empty state it's set around and nothing else: not
    /// a sibling, and not a `ResultView`, which generalizes the same shape with
    /// its own slots.
    func testStyleReachesOnlyTheEmptyStateItIsSetAround() {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(VStack(spacing: 0) {
            EmptyState("Styled").emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))
            EmptyState("Sibling")
        }))
        XCTAssertEqual(recorder.values.compactMap(\.title).filter { $0 != "Styled" }, [],
                       "the style reached an empty state it wasn't set around")
        XCTAssertTrue(recorder.values.contains { $0.title == "Styled" })

        let others = EmptyStateConfigurationRecorder()
        _ = render(staged(ResultView(.notFound, title: "Nothing here")
            .message("Try another search.")
            .primaryAction("Retry") {}
            .emptyStateStyle(RecordingEmptyStateStyle(recorder: others))))
        XCTAssertTrue(others.values.isEmpty, "ResultView doesn't consult EmptyStateStyle")
    }

    /// A style set *inside* an empty state's slot styles that slot's own empty
    /// states, never the one that owns the slot.
    func testAStyleInsideASlotDoesNotReachTheBlockThatOwnsIt() {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(EmptyState("Owner")
            .actions {
                EmptyState("Inside the slot")
                    .emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))
            }))
        XCTAssertEqual(recorder.values.compactMap(\.title), ["Inside the slot"],
                       "a style scoped to the slot leaked out to the block that owns it")
    }

    /// A style set at a container reaches every empty state below it —
    /// including the ones ThemeKit composes inside its own components
    /// (ADR-0009 D6).
    func testContainerStyleReachesNestedAndComposedEmptyStates() {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(VStack(spacing: 0) {
            EmptyState("First")
            EmptyState("Second").actions { EmptyState("Inside a slot") }
        }
        .emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))))
        for title in ["First", "Second", "Inside a slot"] {
            XCTAssertTrue(recorder.values.contains { $0.title == title }, "\(title) didn't reach the style")
        }

        let composed = EmptyStateConfigurationRecorder()
        _ = render(staged(Agenda([])
            .emptyStateStyle(RecordingEmptyStateStyle(recorder: composed))))
        XCTAssertFalse(composed.values.isEmpty, "the empty state Agenda composes didn't reach the style")
    }

    // MARK: Layout

    /// ThemeKit wraps nothing around a custom body: a style that fills its
    /// width spans the container, and one that hugs its content doesn't.
    func testCustomBodyGetsNoThemeKitLayout() {
        let filling = staged(EmptyState("Edge").emptyStateStyle(SlabEmptyStateStyle(fillsWidth: true)))
        let hugging = staged(EmptyState("Edge").emptyStateStyle(SlabEmptyStateStyle(fillsWidth: false)))
        XCTAssertTrue(drawsInk(filling), "the fixture renders blank")
        let wide = pixelDelta(filling, staged(SlabEmptyStateStyle.slab(fillsWidth: true)))
        XCTAssertNotNil(wide, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(wide ?? .max, pixelNoise, "ThemeKit changed the custom body's width")
        XCTAssertLessThanOrEqual(pixelDelta(hugging, staged(SlabEmptyStateStyle.slab(fillsWidth: false))) ?? .max,
                                 pixelNoise, "ThemeKit stretched a custom body that hugs its content")
        XCTAssertTrue(differs(filling, hugging), "control: the comparison saw no difference")
    }

    // MARK: Fixtures

    private var emptyStateCases: [EmptyStateCase] {
        [
            EmptyStateCase(label: "title only", title: "Nothing here"),
            EmptyStateCase(label: "no title", title: nil, message: "Try another search."),
            EmptyStateCase(label: "message + primary", message: "Try adjusting your search or filters."),
            EmptyStateCase(label: "primary + secondary", message: "Check your connection and try again.",
                           icon: "wifi.slash", primary: "Retry", secondary: "Use offline mode"),
            EmptyStateCase(label: "linked message", message: "Read the docs.", links: [("docs", {})]),
            EmptyStateCase(label: "custom actions slot", message: "Plan your first trip to get started.",
                           icon: "airplane", primary: "Search", slot: true),
            EmptyStateCase(label: "tinted, tight circle", icon: "star", foreground: .systemcolorsFgError,
                           background: .bgSecondaryLight, circleSize: 56),
        ]
    }

    /// The fixture as the component draws it.
    private func block(_ fixture: EmptyStateCase) -> AnyView {
        var state = EmptyState(fixture.title).icon(fixture.icon).iconCircleSize(fixture.circleSize)
        if let message = fixture.message {
            state = fixture.links.isEmpty ? state.message(message) : state.message(message, links: fixture.links)
        }
        if let primary = fixture.primary { state = state.primaryAction(primary) {} }
        if let secondary = fixture.secondary { state = state.secondaryAction(secondary) {} }
        if let foreground = fixture.foreground { state = state.iconForeground(foreground) }
        if let background = fixture.background { state = state.iconBackground(background) }
        return fixture.slot ? AnyView(state.actions { SlotActions() }) : AnyView(state)
    }

    /// The same fixture as 1.9.0 drew it: the old body written out.
    private func recipe(_ fixture: EmptyStateCase, opacity: Double = 1) -> some View {
        V190EmptyState(media: .symbol(fixture.icon), title: fixture.title, message: fixture.message,
                       links: fixture.links, primary: fixture.primary, secondary: fixture.secondary,
                       slot: fixture.slot, circleSize: fixture.circleSize,
                       foregroundKey: fixture.foreground, backgroundKey: fixture.background)
            .opacity(opacity)
    }

    /// The configuration a style is handed for `state`.
    private func capture(_ state: some View) -> EmptyStateStyleConfiguration? {
        let recorder = EmptyStateConfigurationRecorder()
        _ = render(staged(state.emptyStateStyle(RecordingEmptyStateStyle(recorder: recorder))))
        return recorder.values.last
    }

    private func symbolName(_ media: EmptyStateMedia) -> String? {
        guard case .symbol(let name) = media else { return nil }
        return name
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 320).padding(8)
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

// MARK: - The 1.9.0 recipe (the block written out)

/// `EmptyState`'s 1.9.0 body, written out: the reference the built-in path must
/// still draw.
@available(iOS 16.0, macOS 13.0, *)
private struct V190EmptyState: View {
    enum Media { case symbol(String), image(Image), animated(URL?) }

    @Environment(\.theme) private var theme

    var media: Media = .symbol("tray")
    var title: String?
    var message: String?
    var links: [(substring: String, action: () -> Void)] = []
    var primary: String?
    var secondary: String?
    var slot = false
    var circleSize: CGFloat = 88
    var imageMaxHeight: CGFloat = 160
    var foregroundKey: Theme.ForegroundColorKey?
    var backgroundKey: Theme.BackgroundColorKey?

    /// The recipe's buttons do nothing; the pixels are what matter.
    private func noop() {}

    var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            switch media {
            case .animated(let url):
                AnimatedImage(url)
                    .contentMode(.fit)
                    .frame(maxHeight: imageMaxHeight)
            case .image(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: imageMaxHeight)
            case .symbol(let systemImage):
                ZStack {
                    Circle()
                        .fill(backgroundKey.map { theme.background($0) } ?? theme.background(.bgElevatorTertiary))
                        .frame(width: circleSize, height: circleSize)
                    Image(systemName: systemImage)
                        .font(.system(size: circleSize * 0.36))
                        .foregroundStyle(foregroundKey.map { theme.foreground($0) } ?? theme.foreground(.fgHero))
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let title {
                    Text(title)
                        .textStyle(.headingBase)
                        .foregroundStyle(theme.text(.textPrimary))
                        .multilineTextAlignment(.center)
                }
                if let message {
                    Group {
                        if links.isEmpty {
                            Text(message)
                                .textStyle(.bodyBase400)
                                .foregroundStyle(theme.text(.textSecondary))
                        } else {
                            InlineText(message, links: links)
                                .inlineStyle(.bodyBase400)
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }

            if slot {
                SlotActions()
            } else if primary != nil || secondary != nil {
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    if let primary {
                        PrimaryButton(primary, action: noop)
                    }
                    if let secondary {
                        SecondaryButton(secondary, action: noop)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fixtures

private struct EmptyStateCase {
    let label: String
    var title: String? = "Nothing here"
    var message: String?
    var icon = "tray"
    var links: [(substring: String, action: () -> Void)] = []
    var primary: String? = "Retry"
    var secondary: String?
    var slot = false
    var foreground: Theme.ForegroundColorKey?
    var background: Theme.BackgroundColorKey?
    var circleSize: CGFloat = 88
}

/// The `.actions { }` slot's content, shared by the component fixture and the
/// 1.9.0 recipe so the two draw the same thing.
private struct SlotActions: View {
    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ThemeButton("Search flights") {}.size(.small)
            ThemeButton("Explore deals") {}.variant(.ghost).size(.small)
        }
    }
}

@MainActor
private final class EmptyStateConfigurationRecorder {
    var values: [EmptyStateStyleConfiguration] = []
}

private struct RecordingEmptyStateStyle: EmptyStateStyle {
    let recorder: EmptyStateConfigurationRecorder

    @MainActor
    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return VStack {
            configuration.title.map { Text($0) }
            configuration.actions
        }
    }
}

/// The stock block at 60% opacity — the control for the pixel-parity loops.
private struct DimmedDefaultEmptyStateStyle: EmptyStateStyle {
    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        DefaultEmptyStateStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// Draws the custom actions slot and nothing else.
private struct ActionsOnlyEmptyStateStyle: EmptyStateStyle {
    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        configuration.actions
    }
}

/// A flat slab, either filling its container's width or hugging its content —
/// the layout proof.
private struct SlabEmptyStateStyle: EmptyStateStyle {
    let fillsWidth: Bool

    @MainActor static func slab(fillsWidth: Bool) -> some View {
        Rectangle().fill(Color.red)
            .frame(width: fillsWidth ? nil : 120, height: 60)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }

    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        Self.slab(fillsWidth: fillsWidth)
    }
}

/// Draws nothing but the ready-made message content, optionally painted — the
/// proof that it arrives unpainted and keeps its link marking.
private struct MessageOnlyEmptyStateStyle: EmptyStateStyle {
    var tinted = false

    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        configuration.messageContent?
            .textStyle(.bodyBase400)
            .foregroundStyle(tinted ? Color.green : Color.black)
    }
}
