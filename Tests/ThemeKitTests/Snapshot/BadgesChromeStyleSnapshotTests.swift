//
//  BadgesChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for `BadgeChromeStyle`, `IconTileStyle` and
//  `CountBadgeStyle`, plus the new default-path API (Badge slots, IconTile's
//  glyph init and circle shape, the standalone `CountBadge`).
//  `testBadge_defaultChromeStyle` renders the content of
//  `ComponentSnapshotTests.testBadge_semanticStyles` through
//  `.badgeChromeStyle(.default)`, so its reference must match that one pixel
//  for pixel. The custom styles are host-shaped: their own type style, size
//  ramp, corners and disabled look, still fed from theme tokens so the dark
//  cases re-skin. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

// MARK: - Host-shaped styles

/// A squared badge with medium-weight text that hugs its content.
private struct SquareBadgeChromeStyle: BadgeChromeStyle {
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        SquareBadgeChrome(configuration: configuration)
    }
}

private struct SquareBadgeChrome: View {
    let configuration: BadgeChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let tone = theme.resolve(configuration.tone.semantic)
        HStack(spacing: Theme.SpacingKey.xs.value) {
            configuration.leading
            Text(configuration.text).textStyle(.bodySm500).lineLimit(1)
            configuration.trailing
        }
        .foregroundStyle(configuration.isEnabled ? tone.accent : theme.text(.textDisabled))
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .background(configuration.isEnabled ? tone.soft : theme.background(.bgSecondaryLight),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }
}

/// A solid disc that honours the requested size (no 24pt floor).
private struct DiscIconTileStyle: IconTileStyle {
    func makeBody(configuration: IconTileStyleConfiguration) -> some View {
        DiscIconTile(configuration: configuration)
    }
}

private struct DiscIconTile: View {
    let configuration: IconTileStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let hue = theme.resolve(configuration.accent ?? .neutral)
        configuration.glyph
            .font(.system(size: configuration.requestedSize * 0.5))
            .foregroundStyle(hue.onSolid)
            .frame(width: configuration.requestedSize, height: configuration.requestedSize)
            .background(hue.solid, in: Circle())
    }
}

/// A number tag with a control-size ramp (14 / 16 / 20 / 24pt) and a disabled look.
private struct NumberTagCountBadgeStyle: CountBadgeStyle {
    func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
        NumberTag(configuration: configuration)
    }
}

private struct NumberTag: View {
    let configuration: CountBadgeStyleConfiguration
    @Environment(\.theme) private var theme

    private var side: CGFloat {
        switch configuration.controlSize {
        case .mini: return 14
        case .small: return 16
        case .regular: return 20
        default: return 24
        }
    }

    var body: some View {
        let hue = theme.resolve(configuration.accent)
        Group {
            switch configuration.content {
            case .text(let text): Text(text).textStyle(.labelSm700)
            case .glyph(let glyph): glyph.font(.system(size: side * 0.6))
            }
        }
        .foregroundStyle(configuration.isEnabled ? hue.onSolid : theme.text(.textDisabled))
        .padding(.horizontal, Theme.SpacingKey.xs.value)
        .frame(minWidth: side, minHeight: side)
        .background(configuration.isEnabled ? hue.solid : theme.background(.bgSecondaryLight),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }
}

@MainActor
final class BadgesChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: Badge

    func testBadge_slots() {
        assertComponentSnapshot(HStack(spacing: 8) {
            Badge("Live").badgeStyle(.success).leading { Circle().frame(width: 6, height: 6) }
            Badge("Inbox").badgeStyle(.info).icon("tray.fill").trailing { Text("12").textStyle(.labelSm700) }
            Badge("Replaced").badgeStyle(.purple).icon("star.fill").leading { Image(systemName: "heart.fill") }
        })
    }

    func testBadge_defaultChromeStyle() {
        assertComponentSnapshot(
            HStack(spacing: 8) {
                Badge("Info").badgeStyle(.info)
                Badge("Success").badgeStyle(.success)
                Badge("Warning").badgeStyle(.warning)
                Badge("Error").badgeStyle(.error)
            }
            .badgeChromeStyle(.default)
        )
    }

    func testBadge_customChromeStyle() {
        assertComponentSnapshot(customBadges)
    }

    func testBadge_customChromeStyle_dark() {
        assertComponentSnapshot(customBadges, colorScheme: .dark)
    }

    func testBadge_customChromeStyle_rtl() {
        assertComponentSnapshot(customBadges, layoutDirection: .rightToLeft)
    }

    func testBadge_customChromeStyle_accessibilityXXXL() {
        assertComponentSnapshot(customBadges, contentSize: .accessibilityExtraExtraExtraLarge)
    }

    private var customBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Badge("Tag").badgeStyle(.info).icon("tag.fill")
                Badge("Action") {}.badgeStyle(.success).trailing { Image(systemName: "chevron.right") }
                Badge("Disabled").badgeStyle(.error).disabled(true)
            }
            HStack(spacing: 8) {
                Badge("Both").badgeStyle(.warning).icon(leading: "sparkles", trailing: "xmark")
                Badge("Slot").badgeStyle(.purple).leading { Circle().frame(width: 6, height: 6) }
            }
        }
        .badgeChromeStyle(SquareBadgeChromeStyle())
    }

    // MARK: IconTile

    func testIconTile_shapesAndGlyph() {
        assertComponentSnapshot(HStack(spacing: 12) {
            IconTile("airplane")
            IconTile("heart.fill").accent(.pink).tileShape(.circle)
            IconTile { Text("A").textStyle(.labelBase700) }.accent(.info)
            IconTile { Image(systemName: "star.fill") }.accent(.warning).tileShape(.circle).size(32)
            IconTile("bell.fill").size(16)   // default chrome keeps the 24pt floor
        })
    }

    func testIconTile_customStyle() {
        assertComponentSnapshot(customTiles)
    }

    func testIconTile_customStyle_dark() {
        assertComponentSnapshot(customTiles, colorScheme: .dark)
    }

    private var customTiles: some View {
        HStack(spacing: 12) {
            IconTile("bell.fill").size(16)
            IconTile("airplane").accent(.primary).size(20)
            IconTile { Text("A").textStyle(.labelSm700) }.accent(.success).size(32)
            IconTile("gift.fill").accent(.purple).size(64)
        }
        .iconTileStyle(DiscIconTileStyle())
    }

    // MARK: CountBadge

    func testCountBadge_standalone() {
        assertComponentSnapshot(HStack(spacing: 12) {
            CountBadge(7)
            CountBadge(128)
            CountBadge(0).showsZero()
            CountBadge("+1").accent(.primary)
            CountBadge { Image(systemName: "checkmark") }.accent(.success)
            CountBadge(3).halo(false)
        }
        .padding(4)
        .background(Color.gray.opacity(0.3)))   // makes the halo visible
    }

    func testCountBadge_customStyle() {
        assertComponentSnapshot(customCounts)
    }

    func testCountBadge_customStyle_dark() {
        assertComponentSnapshot(customCounts, colorScheme: .dark)
    }

    private var customCounts: some View {
        HStack(spacing: 12) {
            CountBadge(3).controlSize(.mini)
            CountBadge("+1").accent(.primary).controlSize(.small)
            CountBadge(128)
            CountBadge { Image(systemName: "star.fill") }.accent(.warning).controlSize(.large)
            CountBadge(5).disabled(true)
            Image(systemName: "bell.fill").font(.title).countBadge(12).padding(12)
        }
        .countBadgeStyle(NumberTagCountBadgeStyle())
    }
}
#endif
