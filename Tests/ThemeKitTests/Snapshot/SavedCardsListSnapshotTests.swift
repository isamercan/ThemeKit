//
//  SavedCardsListSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel `SavedCardsList` organism
//  (F3.1). Opt-in + iOS-only (see SnapshotSupport.swift); records references on
//  the pinned Simulator, skips in CI. Bindings use `.constant` and card expiry
//  years are pinned far past (2020, always expired) / far future (2032, never
//  expired) so references are reproducible without touching `Date()`.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class SavedCardsListSnapshotTests: SnapshotTestCase {

    // MARK: - F3.1 SavedCardsList (begin)

    /// Mixed wallet: two valid cards + one long-expired one.
    private var mixedCards: [SavedCard] {
        [
            SavedCard(id: "visa", brand: .visa, last4: "4242",
                      holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
            SavedCard(id: "mc", brand: .mastercard, last4: "4444",
                      holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
            SavedCard(id: "amex", brand: .amex, last4: "0005",
                      holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
        ]
    }

    func testSavedCardsList_states() {
        // Selection + expired flag + delete/add-new affordances, and the
        // flagsExpired(false) escape hatch below it.
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 16) {
                SavedCardsList(mixedCards, selection: .constant("visa"))
                    .onDelete { _ in }
                    .onAddNew { }

                SavedCardsList([
                    SavedCard(id: "amex", brand: .amex, last4: "0005",
                              holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
                ], selection: .constant("amex"))
                    .flagsExpired(false)
                    .accent(.success)
            }
            .padding()
        )

        // Empty — the default EmptyState (with wired add-new) and the
        // `.emptyContent { }` slot override.
        assertComponentSnapshot(
            VStack(spacing: 16) {
                SavedCardsList([], selection: .constant(nil))
                    .onAddNew { }
                SavedCardsList([], selection: .constant(nil))
                    .emptyContent {
                        Text("Your wallet is empty.")
                            .textStyle(.bodyBase400)
                    }
            }
            .padding(),
            named: "empty"
        )

        // Dark — token re-skin of rows, badge and affordances.
        assertComponentSnapshot(
            SavedCardsList(mixedCards, selection: .constant("mc"))
                .onDelete { _ in }
                .onAddNew { }
                .padding(),
            colorScheme: .dark,
            named: "dark"
        )
    }

    // MARK: - F3.1 SavedCardsList (end)
}
#endif
