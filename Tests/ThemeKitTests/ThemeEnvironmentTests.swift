//
//  ThemeEnvironmentTests.swift
//  ThemeKitTests
//
//  The `\.theme` environment value: defaults to the shared singleton (so unthemed
//  components never crash) and is overridable per-subtree (so a component can be
//  re-themed in isolation — a different brand in a branch, a pinned theme in a
//  preview/snapshot — without mutating global state).
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class ThemeEnvironmentTests: XCTestCase {

    func testEnvironmentThemeDefaultsToSharedSingleton() {
        XCTAssertTrue(EnvironmentValues().theme === Theme.shared,
                      "\\.theme must default to Theme.shared so a component reads a working theme when none is injected")
    }

    func testEnvironmentThemeIsOverridablePerSubtree() {
        var env = EnvironmentValues()
        let custom = Theme()
        env.theme = custom
        XCTAssertTrue(env.theme === custom)
        XCTAssertFalse(env.theme === Theme.shared)
    }
}
