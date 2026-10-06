//
//  CouponChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 06.10.2026.
//
//  Logic coverage for `CouponChromeStyle`: the stock path still renders, the
//  explicit `.default` style draws the stock pixels, a custom style receives
//  the resolved configuration, and its copy action is the coupon's — the
//  copied state and the caller's `onCopy`. Pixel comparisons use
//  `ImageRenderer`, so they run on macOS too, and allow ±2 per channel, as the
//  sibling suites do.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class CouponChromeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    // MARK: Stock path

    func testExplicitDefaultStyleDrawsTheStockPixels() {
        let cases: [(String, Coupon)] = [
            ("outlined", Coupon(code: "UXMUQ")),
            ("filled", Coupon(code: "UXMUQ").couponStyle(.filled)),
            ("plain", Coupon(code: "UXMUQ").couponStyle(.plain)),
            ("small", Coupon(code: "UXMUQ").size(.small)),
            ("large + icon + discount", Coupon(code: "UXMUQ").size(.large).icon("tag.fill").discount("20% OFF")),
            ("label", Coupon(code: "UB200", label: "Kupon Kodu")),
            ("full width", Coupon(code: "SUMMER20").icon("tag.fill").discount("20% OFF")
                .expiry("Valid until Dec 31").fullWidth()),
            ("full width filled", Coupon(code: "SUMMER20").couponStyle(.filled).fullWidth()),
        ]
        for (label, coupon) in cases {
            let stock = bitmap(coupon)
            XCTAssertNotNil(stock, label)
            XCTAssertTrue(matches(stock, bitmap(coupon.couponChromeStyle(.default))), "\(label): .default differs from the stock look")
        }
    }

    func testPixelComparisonSeesAStyleChange() {
        XCTAssertFalse(matches(bitmap(Coupon(code: "UXMUQ").couponStyle(.filled)), bitmap(Coupon(code: "UXMUQ").couponStyle(.plain))),
                       "control: the comparison must notice a colour-only change")
    }

    // MARK: Custom style

    func testACustomStyleReceivesTheConfiguration() throws {
        let sink = CouponCapture()
        render(Coupon(code: "UB200", label: "Kupon Kodu")
            .couponStyle(.filled)
            .size(.large)
            .icon("tag.fill")
            .discount("200 TL")
            .expiry("05.08.2026")
            .fullWidth()
            .couponChromeStyle(CapturingCouponChrome(sink: sink)))

        let configuration = try XCTUnwrap(sink.values.last)
        XCTAssertEqual(configuration.code, "UB200")
        XCTAssertEqual(configuration.label, "Kupon Kodu")
        XCTAssertEqual(configuration.icon, "tag.fill")
        XCTAssertEqual(configuration.discount, "200 TL")
        XCTAssertEqual(configuration.expiry, "05.08.2026")
        XCTAssertEqual(configuration.style, .filled)
        XCTAssertEqual(configuration.size, .large)
        XCTAssertTrue(configuration.isFullWidth)
        XCTAssertFalse(configuration.isCopied)
        XCTAssertEqual(configuration.copyAccessibilityLabel, String(themeKit: "Copy code"))
    }

    func testTheDefaultLabelReachesTheStyle() throws {
        let sink = CouponCapture()
        render(Coupon(code: "UXMUQ").couponChromeStyle(CapturingCouponChrome(sink: sink)))
        XCTAssertEqual(try XCTUnwrap(sink.values.last).label, String(themeKit: "Promo code:"))
    }

    func testTheStylesCopyRunsTheCallersOnCopy() throws {
        let sink = CouponCapture()
        var copies = 0
        render(Coupon(code: "UB200") { copies += 1 }.couponChromeStyle(CapturingCouponChrome(sink: sink)))
        try XCTUnwrap(sink.values.last).copy()
        XCTAssertEqual(copies, 1)
    }

    func testAStyleSetOnAnAncestorReachesTheCoupon() {
        let sink = CouponCapture()
        render(VStack { Coupon(code: "A"); Coupon(code: "B") }.couponChromeStyle(CapturingCouponChrome(sink: sink)))
        XCTAssertEqual(Set(sink.values.map(\.code)), ["A", "B"])
    }

    // MARK: Helpers

    private func render<V: View>(_ view: V) {
        _ = bitmap(view)
    }

    private func bitmap<V: View>(_ view: V) -> CouponBitmap? {
        let renderer = ImageRenderer(content: view.frame(width: 320))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        return CouponBitmap(image)
    }

    /// Same size, and no channel more than `tolerance` apart.
    private func matches(_ lhs: CouponBitmap?, _ rhs: CouponBitmap?, tolerance: Int = 2) -> Bool {
        guard let lhs, let rhs, lhs.width == rhs.width, lhs.height == rhs.height else { return false }
        return zip(lhs.bytes, rhs.bytes).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }
}

private final class CouponCapture {
    var values: [CouponChromeStyleConfiguration] = []
}

/// Records every configuration and draws the pieces in a plain row.
private struct CapturingCouponChrome: CouponChromeStyle {
    let sink: CouponCapture

    @MainActor
    func makeBody(configuration: CouponChromeStyleConfiguration) -> some View {
        sink.values.append(configuration)
        return HStack {
            Text(configuration.label)
            Text(configuration.code)
            Button("Copy", action: configuration.copy)
        }
    }
}

private struct CouponBitmap {
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
