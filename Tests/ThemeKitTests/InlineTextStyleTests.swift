//
//  InlineTextStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Logic coverage for `InlineTextStyle`: the stock path still renders, the
//  explicit `.default` style draws the stock pixels, a custom style receives
//  the resolved configuration, the new slots reach it, and link taps route on
//  both paths. Pixel comparisons use `ImageRenderer`, so they run on macOS too,
//  and allow ±2 per channel: the first render of an SF Symbol can antialias a
//  few pixels one step differently (the sibling suites use the same tolerance).
//

import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias InlineNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias InlineNativeColor = NSColor
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class InlineTextStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    private let sentence = "By continuing you accept the Terms and the Privacy Policy."

    // MARK: Stock path

    func testStockPathsRender() {
        XCTAssertNotNil(bitmap(InlineText("A plain sentence.")))
        XCTAssertNotNil(bitmap(InlineText(sentence, links: [("Terms", {}), ("Privacy Policy", {})])))
        XCTAssertNotNil(bitmap(InlineText(sentence, links: [("Terms", {})]).accent(.primary).inlineStyle(.bodyBase400)))
        XCTAssertNotNil(bitmap(InlineText("Free cancellation")
            .leading { Image(systemName: "checkmark.circle") }
            .trailing { Badge("New") }))
    }

    func testExplicitDefaultStyleDrawsTheStockPixels() {
        let cases: [(String, InlineText)] = [
            ("plain", InlineText("A plain sentence with no anchors.")),
            ("links", InlineText(sentence, links: [("Terms", {}), ("Privacy Policy", {})])),
            ("accent + style", InlineText(sentence, links: [("Terms", {})]).accent(.primary).inlineStyle(.bodyBase400)),
            ("missing link", InlineText("No anchor here.", links: [("absent", {})]).accent(.error)),
        ]
        for (label, text) in cases {
            let stock = bitmap(text)
            XCTAssertNotNil(stock, label)
            XCTAssertTrue(matches(stock, bitmap(text.inlineTextStyle(.default))), "\(label): .default differs from the stock look")
        }
    }

    func testSlotsRenderAroundTheText() {
        let bare = InlineText("Free cancellation").accent(.success)
        let slotted = bare
            .leading { Image(systemName: "checkmark.circle") }
            .trailing { Image(systemName: "chevron.right") }
        XCTAssertFalse(matches(bitmap(bare), bitmap(slotted)), "slots should draw")
        XCTAssertTrue(matches(bitmap(slotted), bitmap(slotted.inlineTextStyle(.default))))
    }

    // MARK: Configuration

    func testCustomStyleReceivesTheDefaults() throws {
        let sink = InlineCapture<InlineTextStyleConfiguration>()
        render(InlineText("Plain text").inlineTextStyle(CapturingInlineTextStyle(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(configuration.text, "Plain text")
        XCTAssertTrue(configuration.links.isEmpty)
        XCTAssertEqual(configuration.textStyle, .bodySm400)
        XCTAssertNil(configuration.accent)
        XCTAssertEqual(rgb(configuration.baseColor), rgb(Theme.shared.text(.textSecondary)))
        XCTAssertEqual(rgb(configuration.linkColor), rgb(Theme.shared.text(.textHero)))
        XCTAssertNil(configuration.leading)
        XCTAssertNil(configuration.trailing)
        XCTAssertEqual(String(configuration.attributedText.characters), "Plain text")
        XCTAssertTrue(configuration.isEnabled)
    }

    func testDisabledStateReachesTheStyle() throws {
        let sink = InlineCapture<InlineTextStyleConfiguration>()
        render(InlineText("Unavailable").disabled(true).inlineTextStyle(CapturingInlineTextStyle(sink: sink)))
        XCTAssertEqual(try XCTUnwrap(sink.values.last).isEnabled, false)
    }

    func testCustomStyleReceivesTheAxes() throws {
        let sink = InlineCapture<InlineTextStyleConfiguration>()
        var tapped: [String] = []
        let text = InlineText(sentence, links: [("Terms", { tapped.append("terms") }), ("Privacy Policy", { tapped.append("privacy") })])
            .accent(.success)
            .inlineStyle(.bodyBase400)
            .leading { Image(systemName: "checkmark.circle") }
            .trailing { Badge("New") }
        render(text.inlineTextStyle(CapturingInlineTextStyle(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(configuration.text, sentence)
        XCTAssertEqual(configuration.links.map(\.substring), ["Terms", "Privacy Policy"])
        XCTAssertEqual(configuration.textStyle, .bodyBase400)
        XCTAssertEqual(configuration.accent, .success)
        XCTAssertEqual(rgb(configuration.baseColor), rgb(Theme.shared.resolve(.success).base))
        XCTAssertNotNil(configuration.leading)
        XCTAssertNotNil(configuration.trailing)

        configuration.links[1].action()
        XCTAssertEqual(tapped, ["privacy"])
    }

    func testAttributedTextMarksLinksWithoutBasePaint() throws {
        let sink = InlineCapture<InlineTextStyleConfiguration>()
        render(InlineText("Read the Terms now.", links: [("Terms", {})])
            .accent(.error)
            .inlineTextStyle(CapturingInlineTextStyle(sink: sink)))
        let attributed = try XCTUnwrap(sink.values.last).attributedText

        var linkRuns = 0
        for run in attributed.runs {
            if let link = run.link {
                linkRuns += 1
                XCTAssertEqual(link, URL(string: "inline:0"))
                XCTAssertEqual(String(attributed[run.range].characters), "Terms")
                XCTAssertEqual(run.swiftUI.underlineStyle, .single)
                XCTAssertNotNil(run.swiftUI.foregroundColor, "link runs keep their paint")
            } else {
                XCTAssertNil(run.swiftUI.foregroundColor, "non-link text must not carry a colour")
            }
            XCTAssertNil(run.swiftUI.font, "the text carries no font at all")
        }
        XCTAssertEqual(linkRuns, 1)
    }

    func testStockAttributedStringPaintsBaseBeforeLinks() {
        let hero = Theme.shared.text(.textHero)
        let base = Theme.shared.text(.textSecondary)
        let attributed = InlineText.attributedString(
            "Read the Terms now.", links: [("Terms", {}), ("absent", {})],
            font: TextStyle.bodySm400.font, baseColor: base, linkColor: hero)

        for run in attributed.runs {
            XCTAssertNotNil(run.swiftUI.font, "the stock string carries the font everywhere")
            let expected = run.link == nil ? base : hero
            XCTAssertEqual(run.swiftUI.foregroundColor.map(rgb), rgb(expected))
        }
    }

    // MARK: Link routing

    func testLinkRoutingResolvesIndexesAndForwardsTheRest() {
        var tapped: [Int] = []
        var forwarded: [URL] = []
        // The stock path passes no fallback (→ `.systemAction`); a recording
        // fallback stands in for the system here so nothing is opened.
        let fallback = OpenURLAction { url in
            forwarded.append(url)
            return .handled
        }
        let routing = InlineText.linkRouting([("a", { tapped.append(0) }), ("b", { tapped.append(1) })], fallback: fallback)
        routing(URL(string: "inline:1")!)
        routing(URL(string: "inline:0")!)
        let outOfRange = URL(string: "inline:7")!
        routing(outOfRange)
        XCTAssertEqual(tapped, [1, 0])
        XCTAssertEqual(forwarded, [outOfRange], "an unknown index is not a link tap")
    }

    func testLinkTapsRouteOnTheStylePath() throws {
        let sink = InlineCapture<OpenURLAction>()
        var tapped: [String] = []
        var forwarded: [URL] = []
        let surrounding = OpenURLAction { url in
            forwarded.append(url)
            return .handled
        }
        render(InlineText(sentence, links: [("Terms", { tapped.append("terms") }), ("Privacy Policy", { tapped.append("privacy") })])
            .inlineTextStyle(OpenURLProbeInlineTextStyle(sink: sink))
            .environment(\.openURL, surrounding))

        let openURL = try XCTUnwrap(sink.values.last)
        openURL(URL(string: "inline:1")!)
        openURL(URL(string: "inline:0")!)
        XCTAssertEqual(tapped, ["privacy", "terms"])

        let other = URL(string: "https://example.com/help")!
        openURL(other)
        XCTAssertEqual(forwarded, [other], "non-link URLs go to the surrounding action")
        XCTAssertEqual(tapped.count, 2)
    }

    // MARK: Composition

    func testEnvironmentStyleReachesComposedLinkedText() throws {
        let sink = InlineCapture<InlineTextStyleConfiguration>()
        render(HelperText("By continuing you accept the Terms.")
            .links([("Terms", {})])
            .inlineTextStyle(CapturingInlineTextStyle(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last, "HelperText's linked text should use the environment style")
        XCTAssertEqual(configuration.textStyle, .bodySm400)
        XCTAssertEqual(rgb(configuration.baseColor), rgb(Theme.shared.text(.textSecondary)),
                       "the composing component's colour reaches the style")
    }

    // MARK: Helpers

    private func render<V: View>(_ view: V) {
        _ = bitmap(view)
    }

    private func bitmap<V: View>(_ view: V) -> InlineBitmap? {
        let renderer = ImageRenderer(content: view.frame(width: 320))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        return InlineBitmap(image)
    }

    /// Same size, and no channel more than `tolerance` apart.
    private func matches(_ lhs: InlineBitmap?, _ rhs: InlineBitmap?, tolerance: Int = 2) -> Bool {
        guard let lhs, let rhs, lhs.width == rhs.width, lhs.height == rhs.height else { return false }
        return zip(lhs.bytes, rhs.bytes).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }

    private func rgb(_ color: Color) -> String {
        #if canImport(UIKit)
        let native = InlineNativeColor(color)
        #else
        let native = InlineNativeColor(color).usingColorSpace(.sRGB) ?? InlineNativeColor(color)
        #endif
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        native.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x%02x",
                      Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()), Int((a * 255).rounded()))
    }
}

// MARK: - Fixtures

/// Collects values a style or probe sees while a view renders.
@MainActor
private final class InlineCapture<Value> {
    var values: [Value] = []
}

/// Records every configuration and draws the content plainly.
private struct CapturingInlineTextStyle: InlineTextStyle {
    let sink: InlineCapture<InlineTextStyleConfiguration>

    @MainActor
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        sink.values.append(configuration)
        return HStack {
            configuration.leading
            configuration.content
            configuration.trailing
        }
    }
}

/// Draws a probe that records the `openURL` action the style's body sees.
private struct OpenURLProbeInlineTextStyle: InlineTextStyle {
    let sink: InlineCapture<OpenURLAction>

    @MainActor
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        InlineOpenURLProbe(sink: sink, content: configuration.content)
    }
}

private struct InlineOpenURLProbe: View {
    let sink: InlineCapture<OpenURLAction>
    let content: AnyView
    @Environment(\.openURL) private var openURL

    var body: some View {
        sink.values.append(openURL)
        return content
    }
}

/// A rendered image's raw RGBA bytes, for pixel comparisons.
private struct InlineBitmap {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(_ image: CGImage) {
        let w = image.width, h = image.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        bytes = buffer
    }
}
