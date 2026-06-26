//
//  DrawerPresenterTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Logic coverage for the imperative side-drawer presenter.
//

import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class DrawerPresenterTests: XCTestCase {

    func testPresentSetsCurrentWithEdgeAndWidth() {
        let drawer = DrawerPresenter()
        XCTAssertFalse(drawer.isPresented)
        drawer.present(edge: .trailing, width: 280) { Text("x") }
        XCTAssertTrue(drawer.isPresented)
        XCTAssertEqual(drawer.current?.edge, .trailing)
        XCTAssertEqual(drawer.current?.width, 280)
        XCTAssertEqual(drawer.current?.dismissOnScrimTap, true)
    }

    func testPresentReplacesPrevious() {
        let drawer = DrawerPresenter()
        drawer.present { Text("a") }
        let first = drawer.current?.id
        drawer.present { Text("b") }
        XCTAssertNotEqual(drawer.current?.id, first)
    }

    func testDismissClears() {
        let drawer = DrawerPresenter()
        drawer.present { Text("x") }
        drawer.dismiss()
        XCTAssertNil(drawer.current)
        XCTAssertFalse(drawer.isPresented)
    }
}
