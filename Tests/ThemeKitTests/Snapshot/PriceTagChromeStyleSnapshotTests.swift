//
//  PriceTagChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for `PriceTagStyle` and the host-text API
//  (`PriceTag(verbatim:)`, `original(verbatim:)`, `discountBadge(_: String?)`,
//  `leading { }`). `testPriceTag_defaultStyle` renders the exact content of
//  `TravelSnapshotTests.testPriceTag_variants` through `.priceTagStyle(.default)`,
//  so its reference must match that one pixel for pixel. The custom style is
//  host-shaped: a trailing-aligned stack with a caption above and the struck
//  original + offer below. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

/// A host-shaped price chrome: caption above, price + unit, then the struck
/// original and the offer badge. Token-fed, so the dark case re-skins.
private struct StackedPriceTagStyle: PriceTagStyle {
    func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
        StackedPriceTagChrome(configuration: configuration)
    }
}

private struct StackedPriceTagChrome: View {
    let configuration: PriceTagStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: configuration.spacing(.sm)) {
            if let leading = configuration.leading { leading }
            VStack(alignment: .trailing, spacing: configuration.spacing(.xs)) {
                if let prefix = configuration.prefix {
                    Text(prefix).textStyle(.overline400).foregroundStyle(theme.text(.textSecondary))
                }
                HStack(alignment: .firstTextBaseline, spacing: configuration.spacing(.xs)) {
                    Text(configuration.stateText ?? configuration.price)
                        .textStyle(.headingSm)
                        .foregroundStyle(configuration.state == .priced ? theme.foreground(.fgHero) : theme.text(.textTertiary))
                    if let unit = configuration.unit {
                        Text(unit).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                if configuration.state == .priced, configuration.original != nil || configuration.discount != nil {
                    HStack(spacing: configuration.spacing(.xs)) {
                        if let original = configuration.original {
                            Text(original).strikethrough().textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                        }
                        if let discount = configuration.discount {
                            Badge(discount).badgeStyle(.success).size(.small)
                        }
                    }
                }
            }
            if let trailing = configuration.trailing { trailing }
        }
    }
}

@MainActor
final class PriceTagChromeStyleSnapshotTests: SnapshotTestCase {

    private var stockMatrix: some View {
        VStack(alignment: .leading, spacing: 12) {
            PriceTag(1_299).original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()
            PriceTag(2_499, currencyCode: "EUR").from()
            PriceTag(0).free()
            PriceTag(1_299).soldOut()
        }
    }

    private var hostMatrix: some View {
        VStack(alignment: .trailing, spacing: 16) {
            PriceTag(verbatim: "EUR 1.299").prefix("Total").original(verbatim: "EUR 1.899").discountBadge("-15%")
            PriceTag(verbatim: "EUR 89").unit("/ night")
                .leading { Icon(systemName: "bed.double").size(.sm) }
                .trailing { Icon(systemName: "chevron.right").size(.xs) }
            PriceTag(1_299).original(1_899).unit("/ night").discountBadge()
            PriceTag(verbatim: "EUR 1.299").soldOut()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Default style (must equal the stock references)

    /// Same content as `TravelSnapshotTests.testPriceTag_variants`, routed
    /// through `makeBody` — the reference must be identical to that one.
    func testPriceTag_defaultStyle() {
        assertComponentSnapshot(stockMatrix.priceTagStyle(.default))
    }

    // MARK: - Host text on the stock look

    func testPriceTag_verbatim_stock() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                PriceTag(verbatim: "EUR 1.299").original(verbatim: "EUR 1.899").discountBadge("Deal").emphasis(.hero)
                PriceTag(verbatim: "EUR 1.299").original(verbatim: "EUR 1.899").originalBelow().size(.large)
                PriceTag(verbatim: "EUR 89").prefix("from").unit("/ night")
                    .leading { Icon(systemName: "bed.double").size(.xs) }
                PriceTag(1_299).original(1_899).discountBadge("-32% today")
            }
        )
    }

    // MARK: - Custom style

    func testPriceTag_customStyle() {
        assertComponentSnapshot(hostMatrix.priceTagStyle(StackedPriceTagStyle()))
    }

    func testPriceTag_customStyle_dark() {
        assertComponentSnapshot(hostMatrix.priceTagStyle(StackedPriceTagStyle()), colorScheme: .dark)
    }

    func testPriceTag_customStyle_rtl() {
        assertComponentSnapshot(hostMatrix.priceTagStyle(StackedPriceTagStyle()), layoutDirection: .rightToLeft)
    }

    /// A container style also restyles the tag `PriceBreakdown` composes.
    func testPriceTag_customStyle_insidePriceBreakdown() {
        assertComponentSnapshot(
            PriceBreakdown(190_960).note("2 rooms · 4 nights").original(248_000).discountBadge("-23%")
                .priceTagStyle(StackedPriceTagStyle())
        )
    }
}
#endif
