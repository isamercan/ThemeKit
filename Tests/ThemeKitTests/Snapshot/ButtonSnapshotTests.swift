//
//  ButtonSnapshotTests.swift
//  ThemeKitTests
//
//  ThemeButton is the highest-traffic interactive component and the widest
//  visual matrix (variant × color × size × shape × state). A regression here
//  ripples across every screen, so it gets the deepest snapshot coverage.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class ButtonSnapshotTests: SnapshotTestCase {

    // MARK: Variants (the daisyUI-style fill spectrum)

    func testThemeButton_variants() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Solid", variant: .solid) {}
                ThemeButton("Soft", variant: .soft) {}
                ThemeButton("Outline", variant: .outline) {}
                ThemeButton("Ghost", variant: .ghost) {}
                ThemeButton("Link", variant: .link) {}
            }
        )
    }

    // MARK: Semantic colors

    func testThemeButton_semanticColors() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Primary", color: .primary) {}
                ThemeButton("Success", color: .success) {}
                ThemeButton("Warning", color: .warning) {}
                ThemeButton("Error", color: .error) {}
            }
        )
    }

    // MARK: Sizes

    func testThemeButton_sizes() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("XSmall", size: .xsmall) {}
                ThemeButton("Small", size: .small) {}
                ThemeButton("Medium", size: .medium) {}
                ThemeButton("Large", size: .large) {}
            }
        )
    }

    // MARK: Shapes & icon-only

    func testThemeButton_shapesAndIcon() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                ThemeButton("Pill", shape: .pill) {}
                ThemeButton(systemImage: "heart.fill", shape: .circle) {}
                ThemeButton(systemImage: "square.and.arrow.up", shape: .square) {}
            }
        )
    }

    // MARK: States — loading / disabled

    func testThemeButton_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Loading", isLoading: .constant(true)) {}
                ThemeButton("Disabled", isEnabled: .constant(false)) {}
                ThemeButton("With icon", systemImage: "checkmark") {}
            }
        )
    }

    // MARK: Block (full-width)

    func testThemeButton_block() {
        assertComponentSnapshot(ThemeButton("Continue", block: true) {})
    }

    // MARK: Presets

    func testButtonPresets() {
        assertComponentSnapshot(
            VStack(spacing: 8) {
                PrimaryButton("Primary") {}
                SecondaryButton("Secondary") {}
                OutlineButton("Outline") {}
                GhostButton("Ghost") {}
                LinkButton("Link") {}
            }
        )
    }

    // MARK: Dark mode

    func testThemeButton_variants_darkMode() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Solid", variant: .solid) {}
                ThemeButton("Soft", variant: .soft) {}
                ThemeButton("Outline", variant: .outline) {}
            },
            colorScheme: .dark
        )
    }

    // MARK: Dynamic Type — footprint must grow with the label

    func testThemeButton_largeText() {
        assertComponentSnapshot(
            ThemeButton("Book now", systemImage: "calendar") {},
            contentSize: .accessibilityExtraExtraExtraLarge
        )
    }
}
#endif
