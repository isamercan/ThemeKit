//
//  ComponentSnapshotTests.swift
//  GlobalUIComponentsTests
//
//  Visual-regression coverage for a representative slice of atoms. These exist
//  to catch the failure mode unit tests can't: a token, padding, or layout
//  change that silently alters how a component LOOKS across the library.
//
//  This is a seed set, not the finish line — the pattern scales to every
//  component. iOS-only (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import GlobalUIComponents

@MainActor
final class ComponentSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Image comparisons are environment-sensitive (font + antialiasing
        // rendering differs by OS/GPU), so this suite is opt-in rather than a
        // blocking CI gate. Record + verify on the team's pinned simulator:
        //   RUN_SNAPSHOTS=1 RECORD_SNAPSHOTS=1  xcodebuild test ...   # record
        //   RUN_SNAPSHOTS=1                     xcodebuild test ...   # verify
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_SNAPSHOTS"] == "1",
            "Set RUN_SNAPSHOTS=1 to run the visual-regression suite."
        )
    }

    // MARK: Badge

    func testBadge_neutral() {
        assertComponentSnapshot(Badge("New"))
    }

    func testBadge_semanticStyles() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Badge("Info", style: .info)
                Badge("Success", style: .success)
                Badge("Warning", style: .warning)
                Badge("Error", style: .error)
            }
        )
    }

    func testBadge_withIcon_solidVariant() {
        assertComponentSnapshot(
            Badge("Sold out", style: .error, variant: .solid, leadingSystemImage: "xmark.circle.fill")
        )
    }

    // MARK: Tag

    func testTag_withLeadingIcon() {
        assertComponentSnapshot(Tag("Istanbul", leadingSystemImage: "mappin"))
    }

    // MARK: ScoreBadge

    func testScoreBadge() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                ScoreBadge(9.2)
                ScoreBadge(7.4)
                ScoreBadge(4.1)
            }
        )
    }

    // MARK: StatusDot

    func testStatusDot_allKinds() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                StatusDot(.online, label: "Online")
                StatusDot(.busy, label: "Busy")
                StatusDot(.away, label: "Away")
                StatusDot(.offline, label: "Offline")
            }
        )
    }

    // MARK: Chip

    func testChip_selectedAndUnselected() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Chip("Recommended", isSelected: .constant(true))
                Chip("Sold out", isSelected: .constant(false))
            }
        )
    }

    // MARK: Dark mode

    func testBadge_darkMode() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Badge("Info", style: .info)
                Badge("Success", style: .success)
            },
            colorScheme: .dark
        )
    }

    // MARK: Dynamic Type — proves the component grows with the user's text size

    func testBadge_accessibilityExtraExtraExtraLarge() {
        assertComponentSnapshot(
            Badge("Success", style: .success),
            contentSize: .accessibilityExtraExtraExtraLarge
        )
    }

    // MARK: RTL — proves the row mirrors for right-to-left locales

    func testBadgeRow_rightToLeft() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Badge("Info", style: .info)
                ScoreBadge(9.2)
                Tag("Istanbul", leadingSystemImage: "mappin")
            },
            layoutDirection: .rightToLeft
        )
    }
}
#endif
