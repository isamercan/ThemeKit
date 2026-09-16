//
//  ChromeStyleBehaviourTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  Cross-cutting checks for the consumer chrome styles (ADR-0009): the stock
//  `Default…` styles are `Sendable` (one instance can be set on many views),
//  `DefaultRadioButtonChromeStyle` draws the built-in path's press dim, and
//  the accessibility decisions both render paths share. (A unit-test host
//  builds no accessibility tree without an assistive client, so those are
//  checked as decisions, not read back from a hosted view.)
//

import SwiftUI
import XCTest
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ChromeStyleBehaviourTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Sendable stock styles

    /// Compile-time: each stock style is `Sendable`, so one shared instance —
    /// held in a `static let`, which Swift 6 accepts only for `Sendable`
    /// types — can be set on any number of views.
    func testStockStylesAreSendableAndReusable() {
        typealias Shared = SharedStockStyles
        requireSendable(Shared.button); requireSendable(Shared.badge); requireSendable(Shared.countBadge)
        requireSendable(Shared.iconTile); requireSendable(Shared.priceTag); requireSendable(Shared.radio)
        requireSendable(Shared.skeleton); requireSendable(Shared.divider); requireSendable(Shared.callout)
        requireSendable(Shared.inlineText)

        let rendered = render(VStack {
            VStack {
                ThemeButton("One") {}.buttonChromeStyle(Shared.button)
                ThemeButton("Two") {}.buttonChromeStyle(Shared.button)
                Badge("One").badgeChromeStyle(Shared.badge)
                Badge("Two").badgeChromeStyle(Shared.badge)
                CountBadge(1).countBadgeStyle(Shared.countBadge)
                CountBadge(2).countBadgeStyle(Shared.countBadge)
                IconTile("star").iconTileStyle(Shared.iconTile)
                IconTile("heart").iconTileStyle(Shared.iconTile)
                PriceTag(1).priceTagStyle(Shared.priceTag)
                PriceTag(2).priceTagStyle(Shared.priceTag)
            }
            VStack {
                RadioButton("One", isSelected: .constant(true)).radioButtonChromeStyle(Shared.radio)
                RadioButton("Two", isSelected: .constant(false)).radioButtonChromeStyle(Shared.radio)
                Skeleton().size(width: 20, height: 8).skeletonStyle(Shared.skeleton)
                Skeleton().size(width: 30, height: 8).skeletonStyle(Shared.skeleton)
                DividerView().dividerStyle(Shared.divider)
                DividerView("Or").dividerStyle(Shared.divider)
                Callout("One").calloutChromeStyle(Shared.callout)
                Callout("Two").calloutChromeStyle(Shared.callout)
                InlineText("One").inlineTextStyle(Shared.inlineText)
                InlineText("Two").inlineTextStyle(Shared.inlineText)
            }
        })
        XCTAssertNotNil(rendered)
    }

    private func requireSendable(_ style: some Sendable) {}

    // MARK: Radio press feedback through the stock style

    /// `.plain` — the built-in radio's button style — dims a pressed label to
    /// 75%. The stock style draws the same dim from `isPressed`, so a custom
    /// style that hands a radio to `.default` keeps the press feedback.
    func testDefaultRadioChromeDrawsThePlainButtonPressDim() throws {
        let radio = RadioButton("Press me", isSelected: .constant(true))
        let resting = try XCTUnwrap(capturedConfiguration(radio))
        XCTAssertFalse(resting.isPressed)
        let stock = DefaultRadioButtonChromeStyle()

        XCTAssertTrue(matches(bitmap(stock.makeBody(configuration: resting)), bitmap(radio)), "at rest: the built-in look")
        XCTAssertTrue(matches(bitmap(stock.makeBody(configuration: resting.pressing(true))), bitmap(radio.opacity(0.75))),
                      "pressed: the built-in look at 75%")
        XCTAssertFalse(matches(bitmap(stock.makeBody(configuration: resting.pressing(true))), bitmap(radio)),
                       "control: the press dim is visible")

        // Disabled stays at half opacity, pressed or not (a disabled button
        // never reports a press, but the chrome doesn't rely on that).
        let disabled = RadioButton("Press me", isSelected: .constant(true)).disabled(true)
        let off = try XCTUnwrap(capturedConfiguration(disabled))
        XCTAssertFalse(off.isEnabled)
        XCTAssertTrue(matches(bitmap(stock.makeBody(configuration: off.pressing(true))),
                              bitmap(stock.makeBody(configuration: off))))
    }

    // MARK: Accessibility decisions (shared by both render paths)

    /// A radio's description becomes its hint only when there is one.
    func testRadioHintOnlyForARealDescription() {
        XCTAssertNil(RadioDescriptionHint.hint(for: nil))
        XCTAssertNil(RadioDescriptionHint.hint(for: ""), "an empty description adds no (empty) hint")
        XCTAssertEqual(RadioDescriptionHint.hint(for: "Pay at the property."), "Pay at the property.")
    }

    /// Which buttons take their title as the VoiceOver label.
    func testThemeButtonLabelsWithTheTitleUnlessContentSpeaks() {
        XCTAssertTrue(ThemeButton("Pay") {}.labelsWithTitle)
        XCTAssertTrue(ThemeButton("Pay") {}.label { Text("Pay now") }.labelsWithTitle, "the title names a relabelled button")
        XCTAssertFalse(ThemeButton {}.label { Text("Pay now") }.labelsWithTitle, "a title-less slot speaks for itself")
        XCTAssertFalse((ThemeButton {} label: { Text("Cart") }).labelsWithTitle, "custom label content speaks for itself")
        // An icon-only button draws no title slot, so it keeps the (empty)
        // title label it had before the slot existed.
        XCTAssertTrue(ThemeButton {}.icon(leading: "heart").shape(.circle).label { Text("Like") }.labelsWithTitle)
        XCTAssertTrue(ThemeButton {}.icon(leading: "plus").iconOnly().label { Text("Add") }.labelsWithTitle)
    }

    // MARK: Helpers

    private func capturedConfiguration(_ radio: some View) -> RadioButtonChromeStyleConfiguration? {
        let box = RadioConfigurationBox()
        _ = render(radio.radioButtonChromeStyle(CapturingRadioChrome(box: box)))
        return box.configurations.last
    }

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// RGBA bytes at a fixed width, rendered twice and keeping the second.
    private func bitmap(_ view: some View) -> (width: Int, height: Int, bytes: [UInt8])? {
        let framed = view.frame(width: 320, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        _ = render(framed)
        guard let image = render(framed) else { return nil }
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? (w, h, bytes) : nil
    }

    /// Same size, and no channel more than ±3 apart (glyph rasterization noise).
    private func matches(
        _ lhs: (width: Int, height: Int, bytes: [UInt8])?,
        _ rhs: (width: Int, height: Int, bytes: [UInt8])?
    ) -> Bool {
        guard let lhs, let rhs, lhs.width == rhs.width, lhs.height == rhs.height else { return false }
        return zip(lhs.bytes, rhs.bytes).allSatisfy { abs(Int($0) - Int($1)) <= 3 }
    }

}

// MARK: - Fixtures

/// One instance of each stock style, shared app-wide the way a host might.
private enum SharedStockStyles {
    static let button = DefaultButtonChromeStyle()
    static let badge = DefaultBadgeChromeStyle()
    static let countBadge = DefaultCountBadgeStyle()
    static let iconTile = DefaultIconTileStyle()
    static let priceTag = DefaultPriceTagStyle()
    static let radio = DefaultRadioButtonChromeStyle()
    static let skeleton = DefaultSkeletonStyle()
    static let divider = DefaultDividerStyle()
    static let callout = DefaultCalloutChromeStyle()
    static let inlineText = DefaultInlineTextStyle()
}

@MainActor
private final class RadioConfigurationBox {
    var configurations: [RadioButtonChromeStyleConfiguration] = []
}

private struct CapturingRadioChrome: RadioButtonChromeStyle {
    let box: RadioConfigurationBox

    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        box.configurations.append(configuration)
        return DefaultRadioButtonChromeStyle().makeBody(configuration: configuration)
    }
}
