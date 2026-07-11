//
//  LanguageSwitcherSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the neutral LanguageSwitcher molecule
//  (ThemeKitTravel plan §9.12): the closed menu trigger, check-marked list
//  rows (endonym + exonym subtitle), the inline SegmentedControl, plus dark
//  and RTL renders. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class LanguageSwitcherSnapshotTests: SnapshotTestCase {

    private var languages: [AppLanguage] {
        [AppLanguage(code: "en"), AppLanguage(code: "de"), AppLanguage(code: "ar")]
    }

    /// All three variants stacked — deterministic (fixed selection, menu closed).
    private var states: some View {
        VStack(alignment: .leading, spacing: 16) {
            LanguageSwitcher(languages, selection: .constant("en"))                    // .menu trigger
            LanguageSwitcher(languages, selection: .constant("de")).variant(.list)
            LanguageSwitcher(languages, selection: .constant("de")).variant(.list)
                .showsFlags(false).nativeNames(false).accent(.success)
            LanguageSwitcher(languages, selection: .constant("en")).variant(.inline)
        }
        .padding()
    }

    func testLanguageSwitcher_states() {
        assertComponentSnapshot(states)
        assertComponentSnapshot(states, colorScheme: .dark, named: "dark")
        assertComponentSnapshot(states, layoutDirection: .rightToLeft, named: "rtl")
    }
}
#endif
