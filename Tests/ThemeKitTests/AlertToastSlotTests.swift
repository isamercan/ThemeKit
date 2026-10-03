//
//  AlertToastSlotTests.swift
//  ThemeKitTests
//
//  AlertToast's leading slot and title type: both chain, and a custom leading view is
//  what the row shows in place of the stock glyph.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class AlertToastSlotTests: XCTestCase {
    @MainActor
    func testALeadingViewAndATitleStyleCanBeSet() {
        let toast = AlertToast("Invoice saved.")
            .variant(.success)
            .leading { Text(verbatim: "✓") }
            .titleTextStyle(.bodyBase500)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: toast).children.compactMap { child in
            child.label.map { ($0, child.value) }
        })
        XCTAssertNotNil(fields["leadingView"] as? AnyView)
        XCTAssertEqual(String(describing: fields["titleTextStyle"] ?? ""), String(describing: TextStyle.bodyBase500))
    }

    @MainActor
    func testTheStockToastHasNoLeadingView() {
        let fields = Mirror(reflecting: AlertToast("Invoice saved.")).children
        let leading = fields.first { $0.label == "leadingView" }?.value
        XCTAssertNil(leading as? AnyView)
    }
}
