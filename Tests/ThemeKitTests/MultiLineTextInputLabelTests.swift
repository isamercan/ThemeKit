//
//  MultiLineTextInputLabelTests.swift
//  ThemeKitTests
//
//  `MultiLineTextInput` with an empty label: no header line over the box and no idle message row
//  under it — the box alone, as tall as its least height.
//

#if canImport(UIKit)
import XCTest
import SwiftUI
import UIKit
@testable import ThemeKit

final class MultiLineTextInputLabelTests: XCTestCase {
    @MainActor
    private func height<V: View>(_ view: V) -> CGFloat {
        let host = UIHostingController(rootView: view.environment(\.theme, Theme.shared))
        return host.sizeThatFits(in: CGSize(width: 343, height: CGFloat.greatestFiniteMagnitude)).height
    }

    @MainActor
    func testAnEmptyLabelLeavesTheBoxAlone() {
        let box = height(MultiLineTextInput("", text: .constant("")).placeholder("Address").minHeight(96))
        XCTAssertEqual(box, 96, accuracy: 0.5)
    }

    @MainActor
    func testALabelStillStandsOverTheBox() {
        let labelled = height(MultiLineTextInput("Notes", text: .constant("")).minHeight(96))
        XCTAssertGreaterThan(labelled, 96 + 8)
    }

    @MainActor
    func testAMessageOrACounterKeepsItsRow() {
        let bare = height(MultiLineTextInput("", text: .constant("")).minHeight(96))
        XCTAssertGreaterThan(height(MultiLineTextInput("", text: .constant("")).minHeight(96).errorText("Required")), bare)
        XCTAssertGreaterThan(height(MultiLineTextInput("", text: .constant("")).minHeight(96).characterLimit(200)), bare)
    }
}
#endif
