//
//  TooltipTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for TooltipEdge placement geometry (orientation + anchor alignment).
//

import SwiftUI
import XCTest
@testable import ThemeKit

final class TooltipTests: XCTestCase {

    func testVerticalEdgesAreVertical() {
        XCTAssertTrue(TooltipEdge.top.isVertical)
        XCTAssertTrue(TooltipEdge.bottom.isVertical)
    }

    func testHorizontalEdgesAreNotVertical() {
        XCTAssertFalse(TooltipEdge.leading.isVertical)
        XCTAssertFalse(TooltipEdge.trailing.isVertical)
    }

    func testEachEdgeAlignsToItsOwnSide() {
        XCTAssertEqual(TooltipEdge.top.alignment, .top)
        XCTAssertEqual(TooltipEdge.bottom.alignment, .bottom)
        XCTAssertEqual(TooltipEdge.leading.alignment, .leading)
        XCTAssertEqual(TooltipEdge.trailing.alignment, .trailing)
    }
}
