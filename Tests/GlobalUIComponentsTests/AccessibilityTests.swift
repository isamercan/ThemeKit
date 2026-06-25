//
//  AccessibilityTests.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Locks the Dynamic Type anchoring: every type token maps to a sensible
//  semantic `Font.TextStyle` so custom fonts built with `relativeTo:` scale with
//  the user's preferred text size. (Reduce Motion is environment-driven UI and
//  is verified on-device, not here.)
//

import XCTest
import SwiftUI
@testable import GlobalUIComponents

final class AccessibilityTests: XCTestCase {
    // Big display/heading tokens anchor to large semantic styles; small
    // body/label/overline tokens to small ones. This keeps Dynamic Type scaling
    // proportional to each token's visual weight.
    func testRelativeTextStyleMapping() {
        XCTAssertEqual(TextStyle.displayLg.relativeTextStyle, .largeTitle)   // 48
        XCTAssertEqual(TextStyle.headingLg.relativeTextStyle, .title)        // 32
        XCTAssertEqual(TextStyle.headingBase.relativeTextStyle, .title2)     // 24
        XCTAssertEqual(TextStyle.headingSm.relativeTextStyle, .title3)       // 20
        XCTAssertEqual(TextStyle.bodyLg400.relativeTextStyle, .body)         // 18
        XCTAssertEqual(TextStyle.bodyMd400.relativeTextStyle, .callout)      // 16
        XCTAssertEqual(TextStyle.bodyBase400.relativeTextStyle, .subheadline)// 14
        XCTAssertEqual(TextStyle.bodySm400.relativeTextStyle, .footnote)     // 12
        XCTAssertEqual(TextStyle.overline400.relativeTextStyle, .caption2)   // 10
    }

    // Every token must resolve to a real text style (no crash, total coverage).
    func testEveryTokenHasARelativeStyle() {
        for style in TextStyle.allCases {
            _ = style.relativeTextStyle
            _ = style.font   // also exercises the relativeTo: construction path
        }
    }
}
