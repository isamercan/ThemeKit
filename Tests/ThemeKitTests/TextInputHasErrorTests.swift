//
//  TextInputHasErrorTests.swift
//  ThemeKitTests
//
//  `TextInput.hasError(_:)` chains and is off by default.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class TextInputHasErrorTests: XCTestCase {
    @MainActor
    func testAnErrorCanRingTheFieldWithoutAMessage() {
        let field = TextInput("Code", text: .constant("XY12")).hasError()
        XCTAssertEqual(Mirror(reflecting: field).children.first { $0.label == "forcedError" }?.value as? Bool, true)
    }

    @MainActor
    func testItIsOffByDefault() {
        let field = TextInput("Code", text: .constant(""))
        XCTAssertEqual(Mirror(reflecting: field).children.first { $0.label == "forcedError" }?.value as? Bool, false)
    }
}
