//
//  EmptyStateChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 22.09.2026.
//
//  Visual-regression coverage for the `EmptyStateStyle` path: a host-shaped
//  empty state that looks nothing like the stock one — leading-aligned, the SF
//  Symbol redrawn in a rounded square badge beside the text instead of centred
//  in a circle above it, the message under the title, the actions in a trailing
//  row of compact buttons, all on a flat bordered card. The style is fed from
//  theme tokens and from the configuration's resolved icon tints, so the dark
//  case re-skins.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

// MARK: - Host-shaped style

/// A leading-aligned empty state: a square media badge, the title and message
/// beside it, a trailing row of small buttons, and a bordered card around the
/// lot.
private struct RowEmptyStateStyle: EmptyStateStyle {
    func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        RowEmptyStateBody(configuration: configuration)
    }
}

private struct RowEmptyStateBody: View {
    let configuration: EmptyStateStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.base.value) {
            media
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                if let title = configuration.title {
                    Text(title)
                        .textStyle(.labelLg700)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                configuration.messageContent?
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
                actions
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite), in: shape)
        .overlay(shape.strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    /// The SF Symbol drawn the host's way — a rounded square in the resolved
    /// tints — and the illustration variants relayed as they come.
    @ViewBuilder
    private var media: some View {
        if case .symbol(let name) = configuration.mediaKind {
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(configuration.iconForeground)
                .frame(width: 44, height: 44)
                .background(configuration.iconBackground, in: shape)
        } else {
            configuration.media.frame(width: 44)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let slot = configuration.actions {
            slot.padding(.top, Theme.SpacingKey.xs.value)
        } else if configuration.primaryAction != nil || configuration.secondaryAction != nil {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let primary = configuration.primaryAction {
                    ThemeButton(primary.title, action: primary.perform).size(.small)
                }
                if let secondary = configuration.secondaryAction {
                    ThemeButton(secondary.title, action: secondary.perform)
                        .variant(.ghost).color(.neutral).size(.small)
                }
            }
            .padding(.top, Theme.SpacingKey.xs.value)
        }
    }
}

// MARK: - Suite

@available(iOS 16.0, *)
@MainActor
final class EmptyStateChromeStyleSnapshotTests: SnapshotTestCase {

    /// A block with a message and one without it.
    func testCustomEmptyState_withAndWithoutMessage() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                EmptyState("No results found")
                    .icon("magnifyingglass")
                    .message("Try adjusting your search or filters to find what you're looking for.")
                    .primaryAction("Clear filters") {}
                EmptyState("Nothing scheduled")
                    .icon("calendar")
                    .primaryAction("Add an event") {}
            }
            .emptyStateStyle(RowEmptyStateStyle())
        )
    }

    /// Both actions, and the custom `.actions { }` slot the style draws in
    /// their place.
    func testCustomEmptyState_withBothActionsAndTheSlot() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                EmptyState("You're offline")
                    .icon("wifi.slash")
                    .message("Check your connection and try again.")
                    .primaryAction("Retry") {}
                    .secondaryAction("Use offline mode") {}
                EmptyState("Your trips will appear here")
                    .icon("airplane")
                    .message("Plan your first trip to get started.")
                    .actions {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            ThemeButton("Search flights") {}.size(.small)
                            ThemeButton("Explore deals") {}.variant(.ghost).size(.small)
                        }
                    }
            }
            .emptyStateStyle(RowEmptyStateStyle())
        )
    }

    /// The stock block drawn through `makeBody` — the same pixels the built-in
    /// block draws — above the custom one.
    func testCustomEmptyState_besideTheDefaultStyle() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                fixture.emptyStateStyle(.default)
                fixture.emptyStateStyle(RowEmptyStateStyle())
            }
        )
    }

    /// RTL: the badge, the text column and the button row all swap sides.
    func testCustomEmptyState_rtl() {
        assertComponentSnapshot(
            fixture.emptyStateStyle(RowEmptyStateStyle()),
            layoutDirection: .rightToLeft
        )
    }

    func testCustomEmptyState_darkScheme() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                fixture.emptyStateStyle(RowEmptyStateStyle())
                EmptyState("Nothing scheduled")
                    .icon("calendar")
                    .emptyStateStyle(RowEmptyStateStyle())
            },
            colorScheme: .dark
        )
    }

    // MARK: Fixtures

    /// One block with every part the style draws: media, title, message and
    /// both actions.
    private var fixture: some View {
        EmptyState("No results found")
            .icon("magnifyingglass")
            .message("Try adjusting your search or filters.")
            .primaryAction("Clear filters") {}
            .secondaryAction("Browse all") {}
    }
}
#endif
