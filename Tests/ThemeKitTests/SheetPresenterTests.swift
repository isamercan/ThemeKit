//
//  SheetPresenterTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Logic coverage for the imperative bottom-sheet presenter.
//

import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class SheetPresenterTests: XCTestCase {

    func testPresentSetsCurrentWithDetents() {
        let sheet = SheetPresenter()
        XCTAssertFalse(sheet.isPresented)
        sheet.present(detents: [.height(200), .large]) { Text("x") }
        XCTAssertTrue(sheet.isPresented)
        XCTAssertEqual(sheet.current?.detents, [.height(200), .large])
        XCTAssertEqual(sheet.current?.showsDragIndicator, true)
    }

    func testPresentReplacesPrevious() {
        let sheet = SheetPresenter()
        sheet.present { Text("a") }
        let first = sheet.current?.id
        sheet.present { Text("b") }
        XCTAssertNotEqual(sheet.current?.id, first)
    }

    func testDismissClears() {
        let sheet = SheetPresenter()
        sheet.present { Text("x") }
        sheet.dismiss()
        XCTAssertNil(sheet.current)
        XCTAssertFalse(sheet.isPresented)
    }
}
