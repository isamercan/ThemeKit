//
//  OTPDigitStyleTests.swift
//  ThemeKitTests
//
//  `OTPInput.digitTextStyle(_:)` chains and keeps the default otherwise.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class OTPDigitStyleTests: XCTestCase {
    @MainActor
    func testTheDigitStyleCanBeSet() {
        let otp = OTPInput(code: .constant("12")).digitCount(4).digitTextStyle(.headingMd)
        let style = Mirror(reflecting: otp).children.first { $0.label == "digitTextStyle" }?.value
        XCTAssertEqual(String(describing: style ?? ""), String(describing: TextStyle.headingMd))
    }

    @MainActor
    func testTheDefaultIsHeadingBase() {
        let style = Mirror(reflecting: OTPInput(code: .constant(""))).children.first { $0.label == "digitTextStyle" }?.value
        XCTAssertEqual(String(describing: style ?? ""), String(describing: TextStyle.headingBase))
    }

    @MainActor
    func testAnErrorCanRingTheBoxesWithoutAMessage() {
        let otp = OTPInput(code: .constant("1111")).hasError(true)
        let forced = Mirror(reflecting: otp).children.first { $0.label == "forcedError" }?.value as? Bool
        XCTAssertEqual(forced, true)
    }
}
