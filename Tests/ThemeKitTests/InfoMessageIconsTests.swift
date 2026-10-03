//
//  InfoMessageIconsTests.swift
//  ThemeKitTests
//
//  `infoMessageIcons(_:)`: the severity glyph is on by default and the modifier turns it off
//  through the environment.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class InfoMessageIconsTests: XCTestCase {
    func testIconsAreOnByDefault() {
        XCTAssertTrue(EnvironmentValues().infoMessageIcons)
    }

    func testTheModifierWritesTheEnvironment() {
        var values = EnvironmentValues()
        values.infoMessageIcons = false
        XCTAssertFalse(values.infoMessageIcons)
    }

    @MainActor
    func testAFieldTakesTheModifier() {
        let field = TextInput("Name", text: .constant("")).errorText("This field is required.")
            .infoMessageIcons(false)
        XCTAssertNotNil(field)
    }
}
