//
//  ComponentMotionTests.swift
//  ThemeKitTests
//
//  The opt-in component motion: the accordion's spring and the tooltip growing out of its arrow
//  are off by default, and the arrow's point follows the edge, the alignment and the layout direction.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class ComponentMotionTests: XCTestCase {
    func testBothAreOffByDefault() {
        XCTAssertNil(EnvironmentValues().accordionMotion)
        XCTAssertFalse(EnvironmentValues().tooltipScalesIn)
    }

    func testTheModifiersWriteTheEnvironment() {
        var values = EnvironmentValues()
        values.accordionMotion = .layout
        values.tooltipScalesIn = true
        XCTAssertEqual(values.accordionMotion, .layout)
        XCTAssertTrue(values.tooltipScalesIn)
    }

    /// A bubble above its anchor grows from its bottom edge, at the alignment's point.
    func testTheArrowAnchorFollowsTheEdgeAndAlignment() {
        XCTAssertEqual(TooltipEdge.top.arrowAnchor(.center, layoutDirection: .leftToRight), UnitPoint(x: 0.5, y: 1))
        XCTAssertEqual(TooltipEdge.top.arrowAnchor(.start, layoutDirection: .leftToRight), UnitPoint(x: 0, y: 1))
        XCTAssertEqual(TooltipEdge.top.arrowAnchor(.start, layoutDirection: .rightToLeft), UnitPoint(x: 1, y: 1))
        XCTAssertEqual(TooltipEdge.bottom.arrowAnchor(.end, layoutDirection: .leftToRight), UnitPoint(x: 1, y: 0))
        XCTAssertEqual(TooltipEdge.leading.arrowAnchor(.center, layoutDirection: .leftToRight), UnitPoint(x: 1, y: 0.5))
        XCTAssertEqual(TooltipEdge.trailing.arrowAnchor(.center, layoutDirection: .rightToLeft), UnitPoint(x: 1, y: 0.5))
    }
}
