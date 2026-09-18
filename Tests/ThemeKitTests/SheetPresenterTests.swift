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

    /// A sheet whose content brings its own padding says so; leaving it out
    /// keeps the stock `md` on all four sides.
    func testContentPaddingTravelsWithTheRequest() {
        let sheet = SheetPresenter()
        sheet.present { Text("x") }
        XCTAssertNil(sheet.current?.contentPadding, "unset stays unset — the stock inset")

        let spec = EdgeInsets(top: 24, leading: 16, bottom: 16, trailing: 16)
        sheet.present(contentPadding: spec) { Text("x") }
        XCTAssertEqual(sheet.current?.contentPadding, spec)
    }

    /// The inset the sheets actually apply: the caller's when set, else `md`
    /// on all four sides (what both entry points hardcoded before 1.8.0).
    func testContentPaddingFallsBackToTheStockInset() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        let md = Theme.SpacingKey.md.value
        XCTAssertEqual(BottomSheetMetrics.contentPadding(nil),
                       EdgeInsets(top: md, leading: md, bottom: md, trailing: md))

        let spec = EdgeInsets(top: 24, leading: 16, bottom: 0, trailing: 16)
        XCTAssertEqual(BottomSheetMetrics.contentPadding(spec), spec)
    }

    func testDismissClears() {
        let sheet = SheetPresenter()
        sheet.present { Text("x") }
        sheet.dismiss()
        XCTAssertNil(sheet.current)
        XCTAssertFalse(sheet.isPresented)
    }
}
