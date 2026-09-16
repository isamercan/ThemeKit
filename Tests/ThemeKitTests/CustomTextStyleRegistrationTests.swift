//
//  CustomTextStyleRegistrationTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  A host builds `Theme.ResolvedTextStyle` values itself and registers them
//  with `registerCustomTokens(_:)`. Plain `import ThemeKit`: the initializer
//  must be public for this file to compile at all.
//

import XCTest
import SwiftUI
import ThemeKit

@MainActor
final class CustomTextStyleRegistrationTests: XCTestCase {
    private let price = Theme.ResolvedTextStyle(font: .system(size: 24).weight(.bold), lineSpacing: 8)
    private let caption = Theme.ResolvedTextStyle(font: .custom("Host-Regular", size: 12, relativeTo: .footnote), lineSpacing: 4)

    override func setUp() {
        super.setUp()
        // Start from the bundled theme, whatever an earlier test left applied
        // (a data theme's own `custom.` styles would otherwise leak in).
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        Theme.shared.registerCustomTokens(.init(textStyles: [.hostPrice: price, .hostCaption: caption]))
    }

    override func tearDown() {
        Theme.shared.registerCustomTokens(.init())
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    func testInitKeepsItsValues() {
        XCTAssertEqual(price.font, .system(size: 24).weight(.bold))
        XCTAssertEqual(price.lineSpacing, 8)
        XCTAssertEqual(price, Theme.ResolvedTextStyle(font: .system(size: 24).weight(.bold), lineSpacing: 8))
        XCTAssertNotEqual(price, Theme.ResolvedTextStyle(font: .system(size: 24).weight(.bold), lineSpacing: 6))
    }

    func testRegisteredTextStyleReadsBack() {
        XCTAssertEqual(Theme.shared.custom.textStyle(.hostPrice), price)
        XCTAssertEqual(Theme.shared.custom.textStyle(.hostCaption), caption)
        XCTAssertEqual(Theme.shared.custom.textStyles, [.hostPrice, .hostCaption])
        XCTAssertEqual(Theme.shared.registeredCustomTokens.textStyles[.hostPrice], price)
        XCTAssertNil(Theme.shared.custom.textStyle("host-missing"))
    }

    func testRegisteredTextStyleSurvivesThemeChanges() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))
        XCTAssertEqual(Theme.shared.custom.textStyle(.hostPrice), price, "config path")

        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertEqual(Theme.shared.custom.textStyle(.hostPrice), price, "named theme path")

        Theme.shared.setTheme(css: ":root { --accent: #ff0000; }")
        XCTAssertEqual(Theme.shared.custom.textStyle(.hostPrice), price, "css path")
    }

    /// The app owns a registered style, so a theme file declaring the same name loses.
    func testRegisteredTextStyleOutranksTheThemesOwn() {
        let json = """
        { "typography": [
            { "name": "custom.host-price", "font": "System", "size": 40, "weight": "regular", "lineHeight": 44 },
            { "name": "custom.host-theme-only", "font": "System", "size": 14, "weight": "medium", "lineHeight": 20 }
        ] }
        """
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(Theme.shared.custom.textStyle(.hostPrice), price)
        XCTAssertEqual(Theme.shared.custom.textStyle("host-theme-only")?.lineSpacing, 6)
    }

    @available(iOS 16.0, macOS 13.0, *)
    func testRegisteredTextStyleStylesText() {
        guard let style = Theme.shared.custom.textStyle(.hostPrice) else { return XCTFail("not registered") }
        let styled = ImageRenderer(content: Text(verbatim: "120").font(style.font).lineSpacing(style.lineSpacing))
        let plain = ImageRenderer(content: Text(verbatim: "120").font(.system(size: 10)))
        let styledHeight = styled.cgImage?.height ?? 0
        let plainHeight = plain.cgImage?.height ?? 0
        XCTAssertGreaterThan(styledHeight, plainHeight)
    }

    /// Same contract as the other token kinds: clearing takes effect at the next
    /// theme application.
    func testClearingDropsTheTextStyles() {
        Theme.shared.registerCustomTokens(.init())
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertNil(Theme.shared.custom.textStyle(.hostPrice))
        XCTAssertTrue(Theme.shared.custom.textStyles.isEmpty)
    }
}

private extension Theme.CustomToken {
    static let hostPrice: Self = "host-price"
    static let hostCaption: Self = "host-caption"
}
