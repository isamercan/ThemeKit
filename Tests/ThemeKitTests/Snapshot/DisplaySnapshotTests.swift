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
                Avatar(.initials("AB")).size(.sm)
                Avatar(.initials("CD")).size(.md)
                Avatar(.icon("person.fill")).size(.lg)
                Avatar(.icon("person.fill")).size(.lg).fillColor(.dark).shape(.square)
            }
        )
    }

    func testAvatar_group() {
        assertComponentSnapshot(
            AvatarGroup([AvatarContent.initials("AB"), .initials("CD"), .initials("EF"), .initials("GH"), .initials("IJ")]).maxVisible(3)
        )
    }

    // MARK: Card

    func testCard_elevations() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Card {
                    Text("Soft card").textStyle(.bodyMd500)
                }
                Card {
                    Text("Elevated card").textStyle(.bodyMd500)
                }.elevation(.elevated)
            }
        )
    }

    // MARK: Callout

    func testCallout_types() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                Callout("Informational note").variant(.info)
                Callout("Saved successfully").variant(.success)
                Callout("Double-check this").variant(.warning)
                Callout("Something went wrong").variant(.error)
            }
        )
    }

    // MARK: EmptyState

    func testEmptyState() {
        assertComponentSnapshot(
            EmptyState("No results")
                .icon("magnifyingglass")
                .message("Try adjusting your filters or search for something else.")
                .primaryAction("Clear filters") {},
            width: 360
        )
    }

    // MARK: Rating

    func testRating_layouts() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 10) {
                Rating(value: 4.3).countLabel("(128)")
                Rating(value: 4.3).layout(.numberRate).countLabel("1,284 reviews")
                Rating(value: 8.4).layout(.rateNumberText)
            }
        )
    }

    // MARK: Progress

    func testProgressBar_statuses() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                ProgressBar(value: 0.3).showsPercentage()
                ProgressBar(value: 0.7).showsPercentage().gradient()
                ProgressBar(value: 0.5).showsPercentage().status(.exception)
                ProgressBar(value: 1.0).showsPercentage().status(.success)
            }
        )
    }

    func testRadialProgress() {
        assertComponentSnapshot(
            HStack(spacing: 16) {
                RadialProgress(0.25)
                RadialProgress(0.7).dashboard()
                RadialProgress(1.0).status(.success)
            }
        )
    }

    // MARK: Stat

    func testStat() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Stat(title: "Total bookings", value: "1,284").description("this month")
                    .icon("ticket").trend(.up("+12%"))
                Stat(title: "Cancellations", value: "32").trend(.down("-3%"))
            },
            width: 320
        )
    }

    // MARK: Dark mode

    func testCard_darkMode() {
        assertComponentSnapshot(
            Card {
                Text("Elevated card").textStyle(.bodyMd500)
            }.elevation(.elevated),
            colorScheme: .dark
        )
    }
}
#endif
