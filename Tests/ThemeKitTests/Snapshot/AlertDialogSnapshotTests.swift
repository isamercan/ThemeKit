//
//  AlertDialogSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the AlertDialog composition and its two public
//  molecules (AlertHeader, AlertFooter). Guards the token-driven chrome, the
//  header alignment variants, and — most importantly — the footer's auto-stack
//  behaviour and its RTL mirroring. iOS-only, opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class AlertDialogSnapshotTests: SnapshotTestCase {

    // A representative destructive dialog: neutral bubble + tinted glyph, title,
    // body, trailing horizontal footer, close button.
    private var destructiveCard: some View {
        AlertDialog("Delete product", message: "Are you sure you want to delete this product? This action cannot be undone.")
            .icon("trash").tone(.error)
            .primaryAction("Delete") {}
            .secondaryAction("Cancel") {}
            .closable {}
            .size(.sm)
    }

    // MARK: AlertDialog

    func testAlertDialog_destructiveTwoActions() {
        assertComponentSnapshot(destructiveCard)
    }

    func testAlertDialog_darkMode() {
        assertComponentSnapshot(destructiveCard, colorScheme: .dark)
    }

    // Proves the whole card mirrors: header to the trailing edge, footer to the
    // leading edge, close button to the top-leading corner.
    func testAlertDialog_rightToLeft() {
        assertComponentSnapshot(destructiveCard, layoutDirection: .rightToLeft)
    }

    // The reported overflow fix: two long labels can't sit side by side at this
    // width, so `.auto` drops them to a full-width vertical stack.
    func testAlertDialog_footerAutoStacksLongLabels() {
        assertComponentSnapshot(
            AlertDialog("Unsaved changes", message: "You have edits that haven't been saved yet.")
                .icon("square.and.pencil").tone(.primary)
                .primaryAction("Save and continue editing") {}
                .secondaryAction("Discard all my recent changes") {}
                .size(.xs),
            width: 320
        )
    }

    func testAlertDialog_centerHeaderVerticalFooter() {
        assertComponentSnapshot(
            AlertDialog("Discard changes?", message: "Your edits will be lost.")
                .icon("exclamationmark.triangle").tone(.warning)
                .headerAlignment(.center)
                .primaryAction("Discard") {}
                .secondaryAction("Keep editing") {}
                .footerLayout(.vertical)
                .size(.xs),
            width: 320
        )
    }

    // Dynamic Type — the card grows with the user's text size instead of clipping.
    func testAlertDialog_accessibilityExtraExtraExtraLarge() {
        assertComponentSnapshot(destructiveCard, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    // MARK: Molecules

    func testAlertHeader_iconOnlyAndTitleOnly() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 24) {
                AlertHeader().icon("bell.badge").tone(.primary)      // icon-only
                AlertHeader("Terms updated")                          // title-only
                AlertHeader("All set!").icon("checkmark.seal").tone(.success).alignment(.center)
            },
            width: 260
        )
    }

    func testAlertFooter_variants() {
        assertComponentSnapshot(
            VStack(spacing: 20) {
                AlertFooter().tone(.error).primaryAction("Delete") {}.secondaryAction("Cancel") {}.layout(.horizontal)
                AlertFooter().tone(.warning).layout(.vertical).primaryAction("Confirm") {}
            },
            width: 320
        )
    }
}
#endif
