//
//  AccordionStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `Accordion` + `AccordionStyle`: the built-in row still draws the 1.10.0
//  pixels, the stock style draws the same pixels through `makeBody`, a custom
//  style receives the row's content — strings, slots, axes and the live
//  expanded state — `toggle` opens and closes the section on both the seeded
//  and the bound path, and a style scopes to the accordions it is set around.
//
//  The expansion tests host the row in a real window: `toggle` writes to the
//  component's state, and a state update is something an `ImageRenderer` render
//  never runs (the `DialogStyleTests` precedent).
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
final class AccordionStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for fixture in accordionCases {
            XCTAssertNotNil(render(staged(row(fixture))), fixture.label)
            XCTAssertTrue(drawsInk(staged(row(fixture))), "\(fixture.label): the fixture renders blank")
        }
    }

    /// With no style set, the row draws the 1.10.0 pixels: extracting the body
    /// behind the `isDefault` branch must move nothing.
    func testBuiltInRowDrawsTheStockPixels() {
        for fixture in accordionCases {
            let delta = pixelDelta(staged(row(fixture)), staged(recipe(fixture)))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): the built-in row drifted from 1.10.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(staged(row(fixture)), staged(recipe(fixture, opacity: 0.6))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// `.accordionStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for fixture in accordionCases {
            let styled = row(fixture).accordionStyle(.default)
            let delta = pixelDelta(staged(row(fixture)), staged(styled))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): .default drifted from the built-in row")
            XCTAssertTrue(drawsInk(staged(styled)), "\(fixture.label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(staged(row(fixture)),
                                  staged(row(fixture).accordionStyle(DimmedDefaultAccordionStyle()))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().accordionStyle.isDefault)
        XCTAssertFalse(AnyAccordionStyle(DefaultAccordionStyle()).isDefault)
    }

    /// With no style set up the tree, the row never asks any style to draw: a
    /// style set on a sibling isn't consulted, and the row still draws the
    /// built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let recorder = AccordionConfigurationRecorder()
        let fixture = accordionCases[2]
        let pair = VStack(spacing: 0) {
            row(fixture)
            Color.clear.frame(width: 320, height: 40).accordionStyle(RecordingAccordionStyle(recorder: recorder))
        }
        _ = render(staged(pair))
        XCTAssertTrue(recorder.values.isEmpty, "a style off the accordion's path was consulted")
        XCTAssertLessThanOrEqual(pixelDelta(staged(row(fixture)), staged(recipe(fixture))) ?? .max, pixelNoise)
    }

    // MARK: Custom style — the configuration

    func testCustomStyleReceivesTheRowsContent() throws {
        let c = try XCTUnwrap(capture(Accordion("Baggage allowance", initiallyExpanded: true) {
            Text("One carry-on and one personal item.")
        }
        .subtitle("Applies to standard fares")
        .icon("questionmark.circle")
        .number(2)))

        XCTAssertEqual(c.title, "Baggage allowance")
        XCTAssertEqual(c.subtitle, "Applies to standard fares")
        XCTAssertEqual(c.icon, "questionmark.circle", "the leading symbol arrives as a name, not a view")
        XCTAssertEqual(c.number, 2)
        XCTAssertNil(c.leading, "no `.leading { }` slot set")
        XCTAssertNil(c.trailing, "no `.trailing { }` slot set")
        XCTAssertTrue(c.isExpanded, "`initiallyExpanded:` reaches the style")
        XCTAssertEqual(c.expansionValue, String(themeKit: "Expanded"))
        XCTAssertTrue(c.showsDivider, "the stock row asks for its rule")
        XCTAssertFalse(c.truncatesSubtitle)
        XCTAssertTrue(drawsInk(staged(Accordion("Baggage allowance") { Text("One carry-on.") }
            .accordionStyle(ContentOnlyAccordionStyle()))), "the section's content didn't reach the style")
    }

    /// A row with nothing but a title hands the style the same fields, empty.
    func testDefaultsReachTheStyle() throws {
        let c = try XCTUnwrap(capture(Accordion("Bare") { Text("Body") }))
        XCTAssertEqual(c.title, "Bare")
        XCTAssertNil(c.subtitle)
        XCTAssertNil(c.icon)
        XCTAssertNil(c.number)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.trailing)
        XCTAssertFalse(c.isExpanded)
        XCTAssertEqual(c.expansionValue, String(themeKit: "Collapsed"))
        XCTAssertEqual(c.titleSize, .medium, "the stock title size")
        XCTAssertEqual(c.density, .default)
        XCTAssertTrue(c.showsDivider)
        if case .chevron = c.indicator {} else { XCTFail("the stock indicator didn't reach the style as .chevron") }
    }

    /// Every axis the modifiers set, and both slots, reach the style as they
    /// were written — the trailing one already given the expanded state.
    func testSlotsAndAxesReachTheStyle() throws {
        let c = try XCTUnwrap(capture(Accordion("Priority support", initiallyExpanded: true) { Text("Body") }
            .subtitle("Pro plans only")
            .indicator(.custom(expand: "plus.circle", collapse: "minus.circle"))
            .titleSize(.large)
            .density(.large)
            .truncateSubtitle()
            .divider(false)
            .leading { Text("★") }
            .trailing { isOpen in Text(isOpen ? "open" : "closed") }))

        XCTAssertEqual(c.titleSize, .large)
        XCTAssertEqual(c.density, .large)
        XCTAssertTrue(c.truncatesSubtitle)
        XCTAssertFalse(c.showsDivider, "`divider(false)` reaches the style")
        XCTAssertNotNil(c.leading, "the `.leading { }` slot reaches the style")
        XCTAssertNotNil(c.trailing, "the `.trailing { }` slot reaches the style")
        guard case .custom(let expand, let collapse) = c.indicator else {
            return XCTFail("the custom indicator didn't reach the style")
        }
        XCTAssertEqual(expand, "plus.circle")
        XCTAssertEqual(collapse, "minus.circle")

        // The trailing slot is handed the state it was asked for: open here,
        // closed on the same row collapsed.
        XCTAssertTrue(differs(staged(trailingOnly(expanded: true)), staged(trailingOnly(expanded: false))),
                      "the trailing slot ignored the expanded state it was given")
    }

    // MARK: Custom style — expansion

    /// `toggle` opens and closes a row that keeps its own state, exactly as the
    /// stock header button does.
    func testToggleOpensAndClosesAnUncontrolledRow() async throws {
        let recorder = AccordionConfigurationRecorder()
        let host = LiveHost(Accordion("Baggage") { Text("One carry-on.") }
            .accordionStyle(RecordingAccordionStyle(recorder: recorder)))
        defer { host.tearDown() }

        await host.settle { !recorder.values.isEmpty }
        XCTAssertEqual(recorder.values.last?.isExpanded, false, "a seeded row starts closed")

        try XCTUnwrap(recorder.values.last).toggle()
        await host.settle { recorder.values.last?.isExpanded == true }
        XCTAssertEqual(recorder.values.last?.isExpanded, true, "toggle didn't open the row")
        XCTAssertEqual(recorder.values.last?.expansionValue, String(themeKit: "Expanded"),
                       "the announcement didn't follow the state")

        try XCTUnwrap(recorder.values.last).toggle()
        await host.settle { recorder.values.last?.isExpanded == false }
        XCTAssertEqual(recorder.values.last?.isExpanded, false, "toggle didn't close the row again")
        XCTAssertEqual(recorder.values.last?.expansionValue, String(themeKit: "Collapsed"))
    }

    /// The controlled init still works on the style path: `toggle` writes
    /// through the caller's binding, and a change the caller makes reaches the
    /// style.
    func testABoundIsExpandedDrivesAndFollowsTheStyle() async throws {
        let box = ExpansionBox()
        let recorder = AccordionConfigurationRecorder()
        let host = LiveHost(BoundAccordionHost(box: box, recorder: recorder))
        defer { host.tearDown() }

        await host.settle { !recorder.values.isEmpty }
        XCTAssertEqual(recorder.values.last?.isExpanded, false)

        try XCTUnwrap(recorder.values.last).toggle()
        await host.settle { box.isOpen }
        XCTAssertTrue(box.isOpen, "toggle didn't write through the caller's binding")
        XCTAssertEqual(recorder.values.last?.isExpanded, true)

        // The other direction: the caller closes it and the style follows.
        box.isOpen = false
        await host.settle { recorder.values.last?.isExpanded == false }
        XCTAssertEqual(recorder.values.last?.isExpanded, false, "a bound change didn't reach the style")
    }

    // MARK: Scope

    /// The style reaches the accordion it's set around and nothing else.
    func testStyleReachesOnlyTheAccordionItIsSetAround() {
        let recorder = AccordionConfigurationRecorder()
        _ = render(staged(VStack(spacing: 0) {
            Accordion("Styled") { Text("Body") }
                .accordionStyle(RecordingAccordionStyle(recorder: recorder))
            Accordion("Sibling") { Text("Body") }
        }))
        XCTAssertEqual(recorder.values.map(\.title), ["Styled"],
                       "the style reached an accordion it wasn't set around")
    }

    /// A style set on an `AccordionGroup` reaches the `Accordion`s below it
    /// through the environment (ADR-0009 D6) — the group's own rows are drawn
    /// by the group, which is a component of its own.
    func testAGroupLevelStyleReachesTheAccordionsBelowIt() {
        let recorder = AccordionConfigurationRecorder()
        let faqs = [FAQ(id: 0, q: "Can I cancel?", a: "Yes."), FAQ(id: 1, q: "Payment?", a: "Card.")]
        _ = render(staged(AccordionGroup(faqs, initiallyExpanded: [0]) { $0.q } content: { faq in
            Accordion("Nested in \(faq.id)") { Text(faq.a) }
        }
        .accordionStyle(RecordingAccordionStyle(recorder: recorder))))

        XCTAssertTrue(recorder.values.contains { $0.title == "Nested in 0" },
                      "a style set on the group didn't reach the accordion inside it")
        XCTAssertTrue(recorder.values.allSatisfy { $0.title.hasPrefix("Nested in ") },
                      "the group's own rows were drawn through AccordionStyle")
    }

    /// …and it leaves the group alone: the group draws its own rows, its own
    /// surface and its own dividers, styled or not.
    func testAGroupLevelStyleLeavesTheGroupsOwnRowsUnchanged() {
        let faqs = [FAQ(id: 0, q: "Can I cancel?", a: "Yes, free up to 24 hours before."),
                    FAQ(id: 1, q: "Payment options?", a: "Credit card and bank transfer.")]
        let group = AccordionGroup(faqs, initiallyExpanded: [0]) { $0.q } content: {
            Text($0.a).textStyle(.bodyBase400)
        }
        XCTAssertTrue(drawsInk(staged(group)), "the group renders blank")
        let delta = pixelDelta(staged(group), staged(group.accordionStyle(SlabAccordionStyle(fillsWidth: true))))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "an AccordionStyle changed the group's own rows")
    }

    // MARK: Layout

    /// ThemeKit wraps nothing around a custom body but the component's
    /// animation: a style that fills its width spans the container, and one
    /// that hugs its content doesn't.
    func testCustomBodyGetsNoThemeKitChrome() {
        let section = Accordion("Edge") { Text("Body") }
        let filling = staged(section.accordionStyle(SlabAccordionStyle(fillsWidth: true)))
        let hugging = staged(section.accordionStyle(SlabAccordionStyle(fillsWidth: false)))
        XCTAssertTrue(drawsInk(filling), "the fixture renders blank")
        let wide = pixelDelta(filling, staged(SlabAccordionStyle.slab(fillsWidth: true)))
        XCTAssertNotNil(wide, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(wide ?? .max, pixelNoise, "ThemeKit changed the custom body's width")
        XCTAssertLessThanOrEqual(pixelDelta(hugging, staged(SlabAccordionStyle.slab(fillsWidth: false))) ?? .max,
                                 pixelNoise, "ThemeKit stretched a custom body that hugs its content")
        XCTAssertTrue(differs(filling, hugging), "control: the comparison saw no difference")
    }

    // MARK: Fixtures

    private var accordionCases: [AccordionCase] {
        [
            AccordionCase(label: "collapsed"),
            AccordionCase(label: "expanded", expanded: true),
            AccordionCase(label: "subtitle + number", subtitle: "Applies to standard fares", number: 2),
            AccordionCase(label: "icon, expanded", icon: "questionmark.circle", expanded: true),
            AccordionCase(label: "plus/minus, no divider", indicator: .plusMinus, divider: false),
            AccordionCase(label: "custom indicator", indicator: .custom(expand: "plus.circle", collapse: "minus.circle")),
            AccordionCase(label: "large, dense", titleSize: .large, density: .large),
            AccordionCase(label: "truncated subtitle", subtitle: "A long line that the stock row clamps while closed",
                          truncate: true),
        ]
    }

    /// The fixture as the component draws it.
    private func row(_ fixture: AccordionCase) -> AnyView {
        var section = Accordion(fixture.title, initiallyExpanded: fixture.expanded) { AccordionFixtureContent() }
            .indicator(fixture.indicator)
            .titleSize(fixture.titleSize)
            .density(fixture.density)
            .divider(fixture.divider)
        if let subtitle = fixture.subtitle { section = section.subtitle(subtitle) }
        if let icon = fixture.icon { section = section.icon(icon) }
        if let number = fixture.number { section = section.number(number) }
        if fixture.truncate { section = section.truncateSubtitle() }
        return AnyView(section)
    }

    /// The same fixture as 1.10.0 drew it: the old body written out.
    private func recipe(_ fixture: AccordionCase, opacity: Double = 1) -> some View {
        V1100Accordion(title: fixture.title, subtitle: fixture.subtitle, icon: fixture.icon, number: fixture.number,
                       expanded: fixture.expanded, indicator: fixture.indicator, titleSize: fixture.titleSize,
                       density: fixture.density, truncate: fixture.truncate, showDivider: fixture.divider)
            .opacity(opacity)
    }

    /// A row whose trailing slot is all a style draws — the proof that the slot
    /// is handed the expanded state.
    private func trailingOnly(expanded: Bool) -> some View {
        Accordion("Trailing", initiallyExpanded: expanded) { Text("Body") }
            .trailing { isOpen in Text(isOpen ? "open" : "closed").textStyle(.bodyBase400) }
            .accordionStyle(TrailingOnlyAccordionStyle())
    }

    /// The configuration a style is handed for `section`.
    private func capture(_ section: some View) -> AccordionStyleConfiguration? {
        let recorder = AccordionConfigurationRecorder()
        _ = render(staged(section.accordionStyle(RecordingAccordionStyle(recorder: recorder))))
        return recorder.values.last
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

// MARK: - The 1.10.0 recipe (the row written out)

/// `Accordion`'s 1.10.0 body, written out: the reference the built-in path must
/// still draw. Its expansion is a constant — the pixels are what matter.
@available(iOS 16.0, macOS 13.0, *)
private struct V1100Accordion: View {
    @Environment(\.theme) private var theme

    var title: String
    var subtitle: String?
    var icon: String?
    var number: Int?
    var expanded = false
    var indicator: AccordionIndicator = .chevron
    var titleSize: AccordionTitleSize = .medium
    var density: AccordionPaddingSize = .default
    var truncate = false
    var showDivider = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Button {} label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let number {
                        Text(zeroPad2(number))
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                            .monospacedDigit()
                    }
                    if let icon {
                        Icon(systemName: icon).size(.sm).colorOverride(titleColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                        if let subtitle {
                            Text(subtitle)
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary))
                                .lineLimit(truncate && !expanded ? 1 : nil)
                        }
                    }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    indicatorIcon
                }
                .padding(.vertical, density.value)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? String(themeKit: "Expanded") : String(themeKit: "Collapsed"))

            if expanded {
                AccordionFixtureContent()
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showDivider {
                DividerView().size(.small)
            }
        }
    }

    private var titleColor: Color {
        expanded ? theme.text(.textHero) : theme.text(.textPrimary)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        switch indicator {
        case .chevron:
            Icon(systemName: "chevron.down").size(.sm).colorOverride(theme.text(.textTertiary))
                .rotationEffect(.degrees(expanded ? 180 : 0))
        case .plusMinus:
            Icon(systemName: expanded ? "minus" : "plus").size(.sm).colorOverride(theme.text(.textTertiary))
        case .custom(let expand, let collapse):
            Icon(systemName: expanded ? collapse : expand).size(.sm).colorOverride(theme.text(.textTertiary))
        }
    }
}

// MARK: - Fixtures

private struct AccordionCase {
    let label: String
    var title = "What is your refund policy?"
    var subtitle: String?
    var icon: String?
    var number: Int?
    var expanded = false
    var indicator: AccordionIndicator = .chevron
    var titleSize: AccordionTitleSize = .medium
    var density: AccordionPaddingSize = .default
    var truncate = false
    var divider = true
}

private struct FAQ: Identifiable {
    let id: Int
    let q: String
    let a: String
}

/// The section's content, shared by the component fixture and the 1.10.0
/// recipe so the two draw the same thing.
private struct AccordionFixtureContent: View {
    var body: some View {
        Text("You can request a refund within 14 days of purchase.")
    }
}

@MainActor
private final class AccordionConfigurationRecorder {
    var values: [AccordionStyleConfiguration] = []
}

private struct RecordingAccordionStyle: AccordionStyle {
    let recorder: AccordionConfigurationRecorder

    @MainActor
    func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return VStack(alignment: .leading) {
            Text(configuration.title)
            if configuration.isExpanded { configuration.content }
        }
    }
}

/// The stock row at 60% opacity — the control for the pixel-parity loops.
private struct DimmedDefaultAccordionStyle: AccordionStyle {
    func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        DefaultAccordionStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// Draws the section's content and nothing else.
private struct ContentOnlyAccordionStyle: AccordionStyle {
    func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        configuration.content.textStyle(.bodyBase400)
    }
}

/// Draws the trailing slot and nothing else.
private struct TrailingOnlyAccordionStyle: AccordionStyle {
    func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        configuration.trailing
    }
}

/// A flat slab, either filling its container's width or hugging its content —
/// the layout proof.
private struct SlabAccordionStyle: AccordionStyle {
    let fillsWidth: Bool

    @MainActor static func slab(fillsWidth: Bool) -> some View {
        Rectangle().fill(Color.red)
            .frame(width: fillsWidth ? nil : 120, height: 60)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }

    func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        Self.slab(fillsWidth: fillsWidth)
    }
}

/// The caller-owned expansion of the controlled fixture.
private final class ExpansionBox: ObservableObject {
    @Published var isOpen = false
}

/// A controlled row: the box owns the state, so the test can drive it from
/// outside and watch what reaches the style.
@available(iOS 16.0, macOS 13.0, *)
private struct BoundAccordionHost: View {
    @ObservedObject var box: ExpansionBox
    let recorder: AccordionConfigurationRecorder

    var body: some View {
        Accordion("Bound", isExpanded: $box.isOpen) { Text("Body") }
            .accordionStyle(RecordingAccordionStyle(recorder: recorder))
    }
}

// MARK: - Live host (state updates an `ImageRenderer` render never runs)

@available(iOS 16.0, macOS 13.0, *)
@MainActor
private final class LiveHost {
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
