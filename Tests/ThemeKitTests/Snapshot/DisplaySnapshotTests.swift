//
//  DisplaySnapshotTests.swift
//  ThemeKitTests
//
//  Display and layout components seen on nearly every screen — cards, avatars,
//  callouts, ratings, progress, stats. These carry the design tokens (radius,
//  shadow, color) most visibly, so they're the canaries for a token change.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class DisplaySnapshotTests: SnapshotTestCase {

    // MARK: Avatar

    func testAvatar_contentAndSizes() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Avatar(.initials("AB"), size: .sm)
                Avatar(.initials("CD"), size: .md)
                Avatar(.icon("person.fill"), size: .lg)
                Avatar(.icon("person.fill"), size: .lg, background: .dark, shape: .square)
            }
        )
    }

    func testAvatar_group() {
        assertComponentSnapshot(
            AvatarGroup([AvatarContent.initials("AB"), .initials("CD"), .initials("EF"), .initials("GH"), .initials("IJ")], max: 3)
        )
    }

    // MARK: Card

    func testCard_elevations() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Card(elevation: .soft) {
                    Text("Soft card").textStyle(.bodyMd500)
                }
                Card(elevation: .elevated) {
                    Text("Elevated card").textStyle(.bodyMd500)
                }
            }
        )
    }

    // MARK: Callout

    func testCallout_types() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                Callout("Informational note", type: .info)
                Callout("Saved successfully", type: .success)
                Callout("Double-check this", type: .warning)
                Callout("Something went wrong", type: .error)
            }
        )
    }

    // MARK: EmptyState

    func testEmptyState() {
        assertComponentSnapshot(
            EmptyState(
                systemImage: "magnifyingglass",
                title: "No results",
                message: "Try adjusting your filters or search for something else.",
                buttonTitle: "Clear filters",
                action: {}
            ),
            width: 360
        )
    }

    // MARK: Rating

    func testRating_layouts() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 10) {
                Rating(value: 4.3, countLabel: "(128)")
                Rating(value: 4.3, layout: .numberRate, countLabel: "1,284 reviews")
                Rating(value: 8.4, layout: .rateNumberText)
            }
        )
    }

    // MARK: Progress

    func testProgressBar_statuses() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                ProgressBar(value: 0.3, showPercentage: true)
                ProgressBar(value: 0.7, showPercentage: true).gradient()
                ProgressBar(value: 0.5, showPercentage: true, status: .exception)
                ProgressBar(value: 1.0, showPercentage: true, status: .success)
            }
        )
    }

    func testRadialProgress() {
        assertComponentSnapshot(
            HStack(spacing: 16) {
                RadialProgress(value: 0.25)
                RadialProgress(value: 0.7, dashboard: true)
                RadialProgress(value: 1.0, status: .success)
            }
        )
    }

    // MARK: Stat

    func testStat() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Stat(title: "Total bookings", value: "1,284", description: "this month",
                     systemImage: "ticket", trend: .up("+12%"))
                Stat(title: "Cancellations", value: "32", trend: .down("-3%"))
            },
            width: 320
        )
    }

    // MARK: Dark mode

    func testCard_darkMode() {
        assertComponentSnapshot(
            Card(elevation: .elevated) {
                Text("Elevated card").textStyle(.bodyMd500)
            },
            colorScheme: .dark
        )
    }
}
#endif
