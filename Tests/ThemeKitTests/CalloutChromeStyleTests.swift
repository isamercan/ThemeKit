//
//  CalloutChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Logic coverage for `CalloutChromeStyle`: the stock path still renders, the
//  explicit `.default` style draws the stock pixels, a custom style receives
//  the resolved configuration (wired buttons, status label, axes, state), the
//  new alignment / full-width / status-label modifiers behave, linked text
//  keeps the tone colour, and link taps route on the style path. Pixel
//  comparisons use `ImageRenderer`, so they run on macOS too, and allow ±2
//  per channel: the first render of an SF Symbol can antialias a few pixels
//  one step differently (the sibling suites use the same tolerance).
//

import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias CalloutNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias CalloutNativeColor = NSColor
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class CalloutChromeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    // MARK: Stock path

    func testStockPathsRender() {
        XCTAssertNotNil(bitmap(Callout("Heads up").variant(.warning)))
        XCTAssertNotNil(bitmap(Callout("See the docs for details.").links([("docs", {})])))
        XCTAssertNotNil(bitmap(Callout("Checking…").variant(.accent).calloutStyle(.soft)
            .leading { Image(systemName: "hourglass") }
            .statusLabel("Loading")
            .alignment(.center)
            .fullWidth()))
        XCTAssertNotNil(bitmap(Callout("Fare updated.").trailing { Badge("New") }.action("Undo") {}.onClose {}))
    }

    func testExplicitDefaultStyleDrawsTheStockPixels() {
        let cases: [(String, Callout)] = [
            ("info", Callout("Informational note").variant(.info)),
            ("warning soft", Callout("Double-check this").variant(.warning).calloutStyle(.soft)),
            ("neutral soft", Callout("A neutral note").variant(.neutral).calloutStyle(.soft)),
            ("accent soft", Callout("Brand emphasis").variant(.accent).calloutStyle(.soft)),
            ("links", Callout("See the docs for details.").variant(.error).links([("docs", {})])),
            ("icon override", Callout("Custom glyph").icon("bell.badge")),
            ("no icon", Callout("No icon").variant(.success).showsIcon(false)),
            ("leading slot", Callout("Checking…").variant(.accent).calloutStyle(.soft)
                .leading { Image(systemName: "hourglass").font(.system(size: 18)) }
                .statusLabel("Loading")),
            ("trailing + action + close", Callout("Fare updated.").variant(.info).calloutStyle(.soft)
                .trailing { Badge("New") }
                .action("Undo") {}
                .onClose {}),
            ("centred", Callout("Seats are filling up.").variant(.warning)
                .leading { Image(systemName: "flame").font(.system(size: 24)) }
                .alignment(.center)),
            ("full width", Callout("Stretched").variant(.info).fullWidth()),
            ("full width soft", Callout("Stretched").variant(.success).calloutStyle(.soft).fullWidth()),
            ("multi-line soft", Callout(String(repeating: "A longer note that wraps across lines. ", count: 4))
                .variant(.warning).calloutStyle(.soft)),
        ]
        for (label, callout) in cases {
            let stock = bitmap(callout)
            XCTAssertNotNil(stock, label)
            XCTAssertTrue(matches(stock, bitmap(callout.calloutChromeStyle(.default))), "\(label): .default differs from the stock look")
        }
    }

    func testPixelComparisonSeesAToneChange() {
        XCTAssertFalse(matches(bitmap(Callout("Same text").variant(.error)), bitmap(Callout("Same text").variant(.success))),
                       "control: the comparison must notice a colour-only change")
    }

    // MARK: The links fix

    func testLinkedTextKeepsTheToneColour() {
        let text = "See the docs for details."
        for tone in [CalloutType.error, .success, .warning, .accent, .neutral] {
            // A link substring that isn't in the text marks nothing, so the only
            // possible difference from the plain path is the text colour.
            XCTAssertTrue(matches(bitmap(Callout(text).variant(tone).links([("absent", {})])), bitmap(Callout(text).variant(tone))),
                          "\(tone): linked text lost the tone colour")
        }
    }

    func testLinkedTextHandsTheToneToInlineText() throws {
        let sink = CalloutCapture<InlineTextStyleConfiguration>()
        render(Callout("See the docs for details.").variant(.error).links([("docs", {})])
            .inlineTextStyle(CalloutCapturingInlineTextStyle(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(rgb(configuration.baseColor), rgb(Theme.shared.foreground(.systemcolorsFgError)))
        XCTAssertEqual(configuration.textStyle, .bodySm400)
    }

    /// `.calloutChromeStyle(.default)` draws linked text the way the stock
    /// callout does — through `InlineText` — so the environment
    /// `InlineTextStyle` reaches it there too, with the tone as base colour.
    func testDefaultStyleHandsLinkedTextToTheEnvironmentInlineTextStyle() throws {
        let sink = CalloutCapture<InlineTextStyleConfiguration>()
        render(Callout("See the docs for details.").variant(.success).links([("docs", {})])
            .calloutChromeStyle(.default)
            .inlineTextStyle(CalloutCapturingInlineTextStyle(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last, "the default chrome bypassed InlineText")
        XCTAssertEqual(configuration.text, "See the docs for details.")
        XCTAssertEqual(rgb(configuration.baseColor), rgb(Theme.shared.foreground(.systemcolorsFgSuccess)))
        XCTAssertEqual(configuration.textStyle, .bodySm400)
    }

    // MARK: New modifiers on the stock path

    func testFullWidthStretchesTheSurface() {
        let hugging = Callout("Short").variant(.info).calloutStyle(.soft)
        XCTAssertFalse(matches(bitmap(hugging), bitmap(hugging.fullWidth())), "the soft surface should span the width")
        XCTAssertTrue(matches(bitmap(hugging), bitmap(hugging.fullWidth(false))))
    }

    func testAlignmentMovesTheRow() {
        let callout = Callout("Seats are filling up.").variant(.warning)
            .leading { Image(systemName: "flame").font(.system(size: 32)) }
        XCTAssertTrue(matches(bitmap(callout), bitmap(callout.alignment(.firstTextBaseline))), "first baseline is the default")
        XCTAssertFalse(matches(bitmap(callout), bitmap(callout.alignment(.center))))
    }

    // MARK: Configuration

    func testCustomStyleReceivesTheDefaults() throws {
        let sink = CalloutCapture<CalloutChromeStyleConfiguration>()
        render(Callout("Heads up").calloutChromeStyle(CapturingCalloutChrome(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(configuration.text, "Heads up")
        XCTAssertTrue(configuration.links.isEmpty)
        XCTAssertEqual(configuration.tone, .info)
        XCTAssertEqual(configuration.calloutStyle, .plain)
        XCTAssertTrue(configuration.showsIcon)
        XCTAssertNotNil(configuration.leading, "the stock icon")
        XCTAssertEqual(configuration.leadingSystemImage, "info.circle")
        XCTAssertEqual(configuration.statusLabel, CalloutType.info.accessibilityLabel)
        XCTAssertEqual(configuration.alignment, .firstTextBaseline)
        XCTAssertFalse(configuration.isFullWidth)
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertNil(configuration.trailing)
        XCTAssertNil(configuration.actionButton)
        XCTAssertNil(configuration.closeButton)
        XCTAssertNil(configuration.actionTitle)
        XCTAssertNil(configuration.onAction)
        XCTAssertNil(configuration.onClose)
        XCTAssertEqual(String(configuration.attributedText.characters), "Heads up")
        XCTAssertTrue(configuration.attributedText.runs.allSatisfy { $0.link == nil && $0.swiftUI.foregroundColor == nil })
    }

    /// `attributedText` carries InlineText's unpainted runs: link runs marked,
    /// the rest with no font and no colour.
    func testAttributedTextMarksLinksWithoutBasePaint() throws {
        let sink = CalloutCapture<CalloutChromeStyleConfiguration>()
        render(Callout("Read the docs first.").variant(.error).links([("docs", {})])
            .calloutChromeStyle(CapturingCalloutChrome(sink: sink)))
        let attributed = try XCTUnwrap(sink.values.last).attributedText

        var linkRuns = 0
        for run in attributed.runs {
            if let link = run.link {
                linkRuns += 1
                XCTAssertEqual(link, URL(string: "inline:0"))
                XCTAssertEqual(String(attributed[run.range].characters), "docs")
                XCTAssertEqual(run.swiftUI.underlineStyle, .single)
                XCTAssertEqual(run.swiftUI.foregroundColor.map(rgb), rgb(Theme.shared.text(.textHero)))
            } else {
                XCTAssertNil(run.swiftUI.foregroundColor, "non-link text must not carry a colour")
            }
            XCTAssertNil(run.swiftUI.font, "the text carries no font at all")
        }
        XCTAssertEqual(linkRuns, 1)
        XCTAssertEqual(attributed, InlineText.attributedString(
            "Read the docs first.", links: [("docs", {})], font: nil, baseColor: nil, linkColor: Theme.shared.text(.textHero)))
    }

    func testCustomStyleReceivesTheAxesAndWiredActions() throws {
        let sink = CalloutCapture<CalloutChromeStyleConfiguration>()
        var events: [String] = []
        let callout = Callout("Read the docs first.")
            .variant(.warning)
            .calloutStyle(.soft)
            .icon("bell")
            .links([("docs", { events.append("docs") })])
            .trailing { Badge("New") }
            .action("Open") { events.append("action") }
            .onClose { events.append("close") }
            .alignment(.center)
            .fullWidth()
            .statusLabel("Heads up")
        render(callout.calloutChromeStyle(CapturingCalloutChrome(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(configuration.text, "Read the docs first.")
        XCTAssertEqual(configuration.links.map(\.substring), ["docs"])
        XCTAssertEqual(configuration.tone, .warning)
        XCTAssertEqual(configuration.calloutStyle, .soft)
        XCTAssertEqual(configuration.leadingSystemImage, "bell")
        XCTAssertEqual(configuration.statusLabel, "Heads up")
        XCTAssertEqual(configuration.alignment, .center)
        XCTAssertTrue(configuration.isFullWidth)
        XCTAssertNotNil(configuration.trailing)
        XCTAssertNotNil(configuration.actionButton)
        XCTAssertNotNil(configuration.closeButton)
        XCTAssertEqual(configuration.actionTitle, "Open")

        configuration.links[0].action()
        configuration.onAction?()
        configuration.onClose?()
        XCTAssertEqual(events, ["docs", "action", "close"])
    }

    func testCustomLeadingReplacesTheStockIconFields() throws {
        let plainSink = CalloutCapture<CalloutChromeStyleConfiguration>()
        let labelledSink = CalloutCapture<CalloutChromeStyleConfiguration>()
        let callout = Callout("Checking…").leading { Image(systemName: "hourglass") }
        render(callout.calloutChromeStyle(CapturingCalloutChrome(sink: plainSink)))
        render(callout.statusLabel("Loading").calloutChromeStyle(CapturingCalloutChrome(sink: labelledSink)))

        let unlabelled = try XCTUnwrap(plainSink.values.last)
        let labelled = try XCTUnwrap(labelledSink.values.last)
        XCTAssertNotNil(unlabelled.leading)
        XCTAssertNil(unlabelled.leadingSystemImage, "a slot isn't the stock icon")
        XCTAssertNil(unlabelled.statusLabel, "a slot keeps its own label by default")
        XCTAssertEqual(labelled.statusLabel, "Loading")
    }

    func testHiddenIconLeavesNoIndicator() throws {
        let sink = CalloutCapture<CalloutChromeStyleConfiguration>()
        render(Callout("No icon").showsIcon(false).calloutChromeStyle(CapturingCalloutChrome(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertFalse(configuration.showsIcon)
        XCTAssertNil(configuration.leading)
        XCTAssertNil(configuration.leadingSystemImage)
        XCTAssertNil(configuration.statusLabel)
    }

    func testStatusLabelNamesTheStockIcon() throws {
        let overridden = CalloutCapture<CalloutChromeStyleConfiguration>()
        let restored = CalloutCapture<CalloutChromeStyleConfiguration>()
        render(Callout("Saved").variant(.success).statusLabel("Done").calloutChromeStyle(CapturingCalloutChrome(sink: overridden)))
        render(Callout("Saved").variant(.success).statusLabel("Done").statusLabel(nil)
            .calloutChromeStyle(CapturingCalloutChrome(sink: restored)))

        XCTAssertEqual(try XCTUnwrap(overridden.values.last).statusLabel, "Done")
        XCTAssertEqual(try XCTUnwrap(restored.values.last).statusLabel, CalloutType.success.accessibilityLabel)
    }

    func testDisabledStateReachesTheStyle() throws {
        let sink = CalloutCapture<CalloutChromeStyleConfiguration>()
        render(Callout("Unavailable").disabled(true).calloutChromeStyle(CapturingCalloutChrome(sink: sink)))
        XCTAssertEqual(sink.values.last?.isEnabled, false)
    }

    // MARK: Link routing on the style path

    func testLinkTapsRouteOnTheStylePath() throws {
        let sink = CalloutCapture<OpenURLAction>()
        var tapped: [String] = []
        var forwarded: [URL] = []
        let surrounding = OpenURLAction { url in
            forwarded.append(url)
            return .handled
        }
        render(Callout("Read the terms and the policy.")
            .links([("terms", { tapped.append("terms") }), ("policy", { tapped.append("policy") })])
            .calloutChromeStyle(OpenURLProbeCalloutChrome(sink: sink))
            .environment(\.openURL, surrounding))

        let openURL = try XCTUnwrap(sink.values.last)
        openURL(URL(string: "inline:1")!)
        XCTAssertEqual(tapped, ["policy"])

        let other = URL(string: "https://example.com/help")!
        openURL(other)
        XCTAssertEqual(forwarded, [other], "non-link URLs go to the surrounding action")
    }

    // MARK: Helpers

    private func render<V: View>(_ view: V) {
        _ = bitmap(view)
    }

    private func bitmap<V: View>(_ view: V) -> CalloutBitmap? {
        let renderer = ImageRenderer(content: view.frame(width: 320))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        return CalloutBitmap(image)
    }

    /// Same size, and no channel more than `tolerance` apart.
    private func matches(_ lhs: CalloutBitmap?, _ rhs: CalloutBitmap?, tolerance: Int = 2) -> Bool {
        guard let lhs, let rhs, lhs.width == rhs.width, lhs.height == rhs.height else { return false }
        return zip(lhs.bytes, rhs.bytes).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }

    private func rgb(_ color: Color) -> String {
        #if canImport(UIKit)
        let native = CalloutNativeColor(color)
        #else
        let native = CalloutNativeColor(color).usingColorSpace(.sRGB) ?? CalloutNativeColor(color)
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
private final class CalloutCapture<Value> {
    var values: [Value] = []
}

/// Records every configuration and draws the pieces in a plain row.
private struct CapturingCalloutChrome: CalloutChromeStyle {
    let sink: CalloutCapture<CalloutChromeStyleConfiguration>

    @MainActor
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        sink.values.append(configuration)
        return HStack {
            configuration.leading
            configuration.content
            configuration.trailing
            configuration.actionButton
            configuration.closeButton
        }
    }
}

/// Draws a probe that records the `openURL` action the style's body sees.
private struct OpenURLProbeCalloutChrome: CalloutChromeStyle {
    let sink: CalloutCapture<OpenURLAction>

    @MainActor
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        CalloutOpenURLProbe(sink: sink, content: configuration.content)
    }
}

private struct CalloutOpenURLProbe: View {
    let sink: CalloutCapture<OpenURLAction>
    let content: AnyView
    @Environment(\.openURL) private var openURL

    var body: some View {
        sink.values.append(openURL)
        return content
    }
}

/// Records the configuration of the `InlineText` a stock callout composes.
private struct CalloutCapturingInlineTextStyle: InlineTextStyle {
    let sink: CalloutCapture<InlineTextStyleConfiguration>

    @MainActor
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        sink.values.append(configuration)
        return configuration.content
    }
}

/// A rendered image's raw RGBA bytes, for pixel comparisons.
private struct CalloutBitmap {
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
