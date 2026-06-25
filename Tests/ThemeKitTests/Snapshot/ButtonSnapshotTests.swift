//
//  ButtonSnapshotTests.swift
//  ThemeKitTests
//
//  GlobalButton is the highest-traffic interactive component and the widest
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

    func testGlobalButton_variants() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                GlobalButton("Solid", variant: .solid) {}
                GlobalButton("Soft", variant: .soft) {}
                GlobalButton("Outline", variant: .outline) {}
                GlobalButton("Ghost", variant: .ghost) {}
                GlobalButton("Link", variant: .link) {}
            }
        )
    }

    // MARK: Semantic colors

    func testGlobalButton_semanticColors() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                GlobalButton("Primary", color: .primary) {}
                GlobalButton("Success", color: .success) {}
                GlobalButton("Warning", color: .warning) {}
                GlobalButton("Error", color: .error) {}
            }
        )
    }

    // MARK: Sizes

    func testGlobalButton_sizes() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                GlobalButton("XSmall", size: .xsmall) {}
                GlobalButton("Small", size: .small) {}
                GlobalButton("Medium", size: .medium) {}
                GlobalButton("Large", size: .large) {}
            }
        )
    }

    // MARK: Shapes & icon-only

    func testGlobalButton_shapesAndIcon() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                GlobalButton("Pill", shape: .pill) {}
                GlobalButton(systemImage: "heart.fill", shape: .circle) {}
                GlobalButton(systemImage: "square.and.arrow.up", shape: .square) {}
            }
        )
    }

    // MARK: States — loading / disabled

    func testGlobalButton_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                GlobalButton("Loading", isLoading: .constant(true)) {}
                GlobalButton("Disabled", isEnabled: .constant(false)) {}
                GlobalButton("With icon", systemImage: "checkmark") {}
            }
        )
    }

    // MARK: Block (full-width)

    func testGlobalButton_block() {
        assertComponentSnapshot(GlobalButton("Continue", block: true) {})
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

    func testGlobalButton_variants_darkMode() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                GlobalButton("Solid", variant: .solid) {}
                GlobalButton("Soft", variant: .soft) {}
                GlobalButton("Outline", variant: .outline) {}
            },
            colorScheme: .dark
        )
    }

    // MARK: Dynamic Type — footprint must grow with the label

    func testGlobalButton_largeText() {
        assertComponentSnapshot(
            GlobalButton("Book now", systemImage: "calendar") {},
            contentSize: .accessibilityExtraExtraExtraLarge
        )
    }
}
#endif
