//
//  PriceTagStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `PriceTagStyle` + the host-text API (`init(verbatim:)`, `original(verbatim:)`,
//  `discountBadge(_: String?)`, `prefix(_: String?)`, `leading { }`): the stock
//  path still renders, `.priceTagStyle(.default)` draws the same pixels as no
//  style at all, and a custom style receives exactly the resolved content the
//  component owns — captured from `makeBody` during an `ImageRenderer` pass.
//

import XCTest
import SwiftUI
@testable import ThemeKit

/// Collects every configuration a capturing style is handed.
@MainActor
private final class PriceTagConfigurationLog {
    var entries: [PriceTagStyleConfiguration] = []
}

/// Records its configuration and draws the bare price.
private struct CapturingPriceTagStyle: PriceTagStyle {
    let log: PriceTagConfigurationLog
    func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
        log.entries.append(configuration)
        return Text(configuration.price)
    }
}

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class PriceTagStyleTests: XCTestCase {

    private let enUS = Locale(identifier: "en_US")

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: - Helpers

    /// Renders `view` under a capturing style and returns the last configuration.
    private func configuration<V: View>(
        _ view: V, file: StaticString = #filePath, line: UInt = #line
    ) -> PriceTagStyleConfiguration? {
        let log = PriceTagConfigurationLog()
        let renderer = ImageRenderer(content: view
            .priceTagStyle(CapturingPriceTagStyle(log: log))
            .environment(\.locale, enUS))
        XCTAssertNotNil(renderer.cgImage, "capture render failed", file: file, line: line)
        XCTAssertFalse(log.entries.isEmpty, "the style's makeBody was never called", file: file, line: line)
        return log.entries.last
    }

    /// The rendered bitmap of `view` — size plus raw pixel bytes.
    private func bitmap<V: View>(_ view: V) -> (width: Int, height: Int, bytes: Data)? {
        let renderer = ImageRenderer(content: view.environment(\.locale, enUS))
        renderer.scale = 2
        guard let image = renderer.cgImage, let data = image.dataProvider?.data else { return nil }
        return (image.width, image.height, data as Data)
    }

    // MARK: - Default path

    func testStockPathRendersFormattedAndVerbatimTags() {
        let tags: [(String, PriceTag)] = [
            ("formatted", PriceTag(1_299, currencyCode: "USD").original(1_899).unit("/ night").discountBadge()),
            ("verbatim", PriceTag(verbatim: "EUR 1.299").original(verbatim: "EUR 1.899").discountBadge("Deal")),
            ("leading", PriceTag(verbatim: "EUR 89").leading { Text("L") }.trailing { Text("T") }),
            ("stacked", PriceTag(verbatim: "EUR 89").original(verbatim: "EUR 99").originalBelow()),
        ]
        for (label, tag) in tags {
            XCTAssertNotNil(ImageRenderer(content: tag.frame(width: 260, height: 60)).cgImage, "\(label) failed to render")
        }
    }

    func testNoStyleKeepsTheStockBridge() {
        XCTAssertTrue(EnvironmentValues().priceTagStyle.isDefault)
        XCTAssertFalse(AnyPriceTagStyle(DefaultPriceTagStyle()).isDefault,
                       "an explicitly set style — .default included — must route through makeBody")
    }

    /// `.priceTagStyle(.default)` goes through `makeBody`; it must draw exactly
    /// what the stock inline body draws.
    func testDefaultStyleDrawsTheStockPixels() throws {
        // The comparison must be able to fail: a one-digit change and a
        // different style both change the bitmap.
        let one = try XCTUnwrap(bitmap(PriceTag(1_299, currencyCode: "USD")))
        let other = try XCTUnwrap(bitmap(PriceTag(1_298, currencyCode: "USD")))
        XCTAssertFalse(one.bytes == other.bytes, "the bitmap comparison is blind to content")
        let restyled = try XCTUnwrap(bitmap(PriceTag(1_299, currencyCode: "USD")
            .priceTagStyle(CapturingPriceTagStyle(log: PriceTagConfigurationLog()))))
        XCTAssertFalse(one.width == restyled.width && one.bytes == restyled.bytes,
                       "the bitmap comparison is blind to styling")

        let cases: [(String, PriceTag)] = [
            ("discount", PriceTag(1_299, currencyCode: "USD").original(1_899).unit("/ night")
                .size(.large).emphasis(.hero).discountBadge()),
            ("from", PriceTag(2_499, currencyCode: "EUR").from()),
            ("free", PriceTag(0).free()),
            ("soldOut", PriceTag(1_299).soldOut()),
            ("below", PriceTag(1_299, currencyCode: "USD").original(1_899).originalBelow().size(.xlarge)),
            ("fraction", PriceTag(12.5, currencyCode: "USD").fractionDigits(2).emphasis(.success).size(.small)),
            ("verbatim", PriceTag(verbatim: "EUR 1.299").prefix("Total").original(verbatim: "EUR 1.899")
                .unit("/ night").discountBadge("Deal").emphasis(.muted)),
            ("slots", PriceTag(verbatim: "EUR 89").leading { Text("L") }.trailing { Text("T") }),
        ]
        for (label, tag) in cases {
            let stock = try XCTUnwrap(bitmap(tag), "\(label): stock render failed")
            let styled = try XCTUnwrap(bitmap(tag.priceTagStyle(.default)), "\(label): styled render failed")
            XCTAssertEqual(stock.width, styled.width, "\(label): width differs")
            XCTAssertEqual(stock.height, styled.height, "\(label): height differs")
            XCTAssertTrue(stock.bytes == styled.bytes, "\(label): .priceTagStyle(.default) drew different pixels")
        }
    }

    // MARK: - Configuration

    func testFormattedTagHandsTheStyleItsResolvedContent() throws {
        let c = try XCTUnwrap(configuration(
            PriceTag(1_299, currencyCode: "USD")
                .from().original(1_899).originalBelow().unit("/ night")
                .size(.large).emphasis(.hero).discountBadge().animatesValue()
        ))
        XCTAssertEqual(c.price, "$1,299")
        XCTAssertEqual(c.amount, 1_299)
        XCTAssertFalse(c.isVerbatim)
        XCTAssertEqual(c.state, .priced)
        XCTAssertNil(c.stateText)
        XCTAssertEqual(c.original, "$1,899")
        XCTAssertTrue(c.originalBelow)
        XCTAssertEqual(c.prefix, "from")
        XCTAssertEqual(c.unit, "/ night")
        XCTAssertEqual(c.discount, "-32%")
        XCTAssertEqual(c.discountPercent, 32)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.trailing)
        XCTAssertEqual(c.size, .large)
        XCTAssertEqual(c.emphasis, .hero)
        XCTAssertTrue(c.animatesValue)
        XCTAssertEqual(c.density, .regular)
        XCTAssertEqual(c.locale, enUS)
        XCTAssertTrue(c.isEnabled)
        XCTAssertEqual(c.accessibilityLabel, "from $1,299 / night 32% off")
    }

    func testDisabledStateReachesTheStyle() throws {
        let c = try XCTUnwrap(configuration(PriceTag(verbatim: "EUR 1").disabled(true)))
        XCTAssertFalse(c.isEnabled)
    }

    func testVerbatimTagHandsTheStyleTheHostStrings() throws {
        let c = try XCTUnwrap(configuration(
            PriceTag(verbatim: "EUR 1.299")
                .prefix("Total").unit("/ night")
                .original(verbatim: "EUR 1.899").discountBadge("Deal")
                .leading { Text("L") }.trailing { Text("T") }
        ))
        XCTAssertEqual(c.price, "EUR 1.299")
        XCTAssertNil(c.amount)
        XCTAssertTrue(c.isVerbatim)
        XCTAssertEqual(c.original, "EUR 1.899")
        XCTAssertEqual(c.prefix, "Total")
        XCTAssertEqual(c.unit, "/ night")
        XCTAssertEqual(c.discount, "Deal")
        XCTAssertNil(c.discountPercent)
        XCTAssertNotNil(c.leading)
        XCTAssertNotNil(c.trailing)
        XCTAssertFalse(c.animatesValue)
        XCTAssertEqual(c.accessibilityLabel, "Total EUR 1.299 / night original price EUR 1.899 Deal")
    }

    func testVerbatimTagNeverFormatsOrComputes() throws {
        // A numeric original on a verbatim tag has no amount to compare with.
        let c = try XCTUnwrap(configuration(PriceTag(verbatim: "EUR 1.299").original(1_899).discountBadge()))
        XCTAssertNil(c.original)
        XCTAssertNil(c.discount)
        XCTAssertNil(c.discountPercent)
        XCTAssertEqual(c.accessibilityLabel, "EUR 1.299")
    }

    func testVerbatimOriginalShowsWheneverSet() throws {
        // Host text is never compared with the amount.
        let c = try XCTUnwrap(configuration(PriceTag(100, currencyCode: "USD").original(verbatim: "USD 50").discountBadge()))
        XCTAssertEqual(c.original, "USD 50")
        XCTAssertNil(c.discount, "no numeric original → nothing to compute")
        XCTAssertEqual(c.accessibilityLabel, "$100 original price USD 50")
    }

    func testNumericOriginalAtOrBelowTheAmountStaysHidden() throws {
        let equal = try XCTUnwrap(configuration(PriceTag(100, currencyCode: "USD").original(100).discountBadge()))
        XCTAssertNil(equal.original)
        XCTAssertNil(equal.discount)
        let lower = try XCTUnwrap(configuration(PriceTag(100, currencyCode: "USD").original(80)))
        XCTAssertNil(lower.original)
    }

    func testTheLastOriginalCallWins() throws {
        let verbatimLast = try XCTUnwrap(configuration(
            PriceTag(1_299, currencyCode: "USD").original(1_899).original(verbatim: "was more").discountBadge()))
        XCTAssertEqual(verbatimLast.original, "was more")
        XCTAssertNil(verbatimLast.discountPercent)

        let numericLast = try XCTUnwrap(configuration(
            PriceTag(1_299, currencyCode: "USD").original(verbatim: "was more").original(1_899).discountBadge()))
        XCTAssertEqual(numericLast.original, "$1,899")
        XCTAssertEqual(numericLast.discount, "-32%")

        let cleared = try XCTUnwrap(configuration(
            PriceTag(1_299, currencyCode: "USD").original(verbatim: "was more").original(verbatim: nil)))
        XCTAssertNil(cleared.original)
    }

    func testDiscountBadgeOverloadsResolveAndTheLastCallWins() throws {
        let base = PriceTag(1_299, currencyCode: "USD").original(1_899)
        let offer: String? = "Deal"
        let cases: [(String, PriceTag, String?)] = [
            ("()", base.discountBadge(), "-32%"),
            ("(true)", base.discountBadge(true), "-32%"),
            ("(false)", base.discountBadge(false), nil),
            ("(literal)", base.discountBadge("Deal"), "Deal"),
            ("(nil)", base.discountBadge(nil), nil),
            ("(String?)", base.discountBadge(offer), "Deal"),
            ("text then ()", base.discountBadge("Deal").discountBadge(), "-32%"),
            ("() then nil", base.discountBadge().discountBadge(nil), nil),
            ("text then false", base.discountBadge("Deal").discountBadge(false), nil),
        ]
        for (label, tag, expected) in cases {
            let c = try XCTUnwrap(configuration(tag), label)
            XCTAssertEqual(c.discount, expected, label)
            XCTAssertEqual(c.discountPercent, 32, "\(label): the saving is computed regardless of the badge")
        }
        // Host text replaces the computed saving in the spoken label.
        let spoken = try XCTUnwrap(configuration(base.discountBadge("Deal")))
        XCTAssertEqual(spoken.accessibilityLabel, "$1,299 Deal")
    }

    func testPrefixOverloadsResolve() throws {
        let optionalCaption: String? = "Total"
        let caption = "Total"
        let literal: PriceTag = PriceTag(1).prefix("Total")
        let variable: PriceTag = PriceTag(1).prefix(caption)
        let optional: PriceTag = PriceTag(1).prefix(optionalCaption)
        let cleared: PriceTag = PriceTag(1).from().prefix(nil)
        XCTAssertEqual(try XCTUnwrap(configuration(literal)).prefix, "Total")
        XCTAssertEqual(try XCTUnwrap(configuration(variable)).prefix, "Total")
        XCTAssertEqual(try XCTUnwrap(configuration(optional)).prefix, "Total")
        XCTAssertNil(try XCTUnwrap(configuration(cleared)).prefix)
    }

    func testFreeAndSoldOutCarryTheirWordAndThePrice() throws {
        let free = try XCTUnwrap(configuration(PriceTag(0, currencyCode: "USD").free()))
        XCTAssertEqual(free.state, .free)
        XCTAssertEqual(free.stateText, "Free")
        XCTAssertEqual(free.price, "$0")
        XCTAssertEqual(free.accessibilityLabel, "Free")

        let soldOut = try XCTUnwrap(configuration(PriceTag(verbatim: "EUR 1.299").soldOut()))
        XCTAssertEqual(soldOut.state, .soldOut)
        XCTAssertEqual(soldOut.stateText, "Sold out")
        XCTAssertEqual(soldOut.price, "EUR 1.299")
        XCTAssertEqual(soldOut.accessibilityLabel, "Sold out")
    }

    func testAnimatesValueArrivesResolvedAgainstReduceMotion() throws {
        let off = try XCTUnwrap(configuration(PriceTag(1)))
        XCTAssertFalse(off.animatesValue)
        let on = try XCTUnwrap(configuration(PriceTag(1).animatesValue()))
        XCTAssertTrue(on.animatesValue)
        let reduced = try XCTUnwrap(configuration(
            PriceTag(verbatim: "EUR 1").animatesValue().environment(\._accessibilityReduceMotion, true)))
        XCTAssertFalse(reduced.animatesValue, "Reduce Motion must be resolved before the style sees the flag")
        // As in 1.4.0, the micro-animations switch doesn't gate the flag (yet).
        let micro = try XCTUnwrap(configuration(PriceTag(1).animatesValue().microAnimations(false)))
        XCTAssertTrue(micro.animatesValue, "animatesValue ignores microAnimations, as in 1.4.0")
    }

    func testDensityAndSpacingComeFromTheEnvironment() throws {
        let c = try XCTUnwrap(configuration(PriceTag(1).componentDensity(.compact)))
        XCTAssertEqual(c.density, .compact)
        XCTAssertEqual(c.spacing(.md), ComponentDensity.compact.scale(Theme.SpacingKey.md.value))
    }

    /// The style is environment-scoped, so tags ThemeKit composes internally
    /// pick it up too (documented on `PriceTagStyle`).
    func testContainerStyleReachesComposedTags() throws {
        let c = try XCTUnwrap(configuration(
            PriceBreakdown(190_960, currencyCode: "USD").original(248_000).discountBadge("-23%")
        ))
        XCTAssertEqual(c.price, "$190,960")
        XCTAssertNil(c.original, "PriceBreakdown draws its own struck original next to the tag")
        XCTAssertNil(c.discount)
    }
}
