//
//  TitleTabChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  Visual-regression coverage for the `TitleStyle` and
//  `SegmentedTabBarChromeStyle` paths: a host-shaped section title with its own
//  type, a boxed leading glyph and a control-size ramp, and a host-shaped tab
//  with a sliding selection bar — filling the width, content-hugging with a
//  baseline, scrollable, in RTL and in the dark scheme. Both styles are
//  host-shaped (their own metrics and type) but fed from theme tokens, so the
//  dark cases re-skin. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

// MARK: - Host-shaped styles

/// A section title with a boxed glyph, an uppercased eyebrow in the tertiary
/// text colour, a control-size type ramp and a soft-filled action pill.
private struct BoxedTitleStyle: TitleStyle {
    func makeBody(configuration: TitleStyleConfiguration) -> some View {
        BoxedTitleBody(configuration: configuration)
    }
}

private struct BoxedTitleBody: View {
    let configuration: TitleStyleConfiguration
    @Environment(\.theme) private var theme

    private var titleStyle: TextStyle {
        switch configuration.controlSize {
        case .mini, .small: return .headingSm
        case .large, .extraLarge: return .headingLg
        default: return .headingBase
        }
    }
    private var glyphSide: CGFloat {
        switch configuration.controlSize {
        case .mini, .small: return 28
        case .large, .extraLarge: return 44
        default: return 36
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            if let leading = configuration.leading {
                leading
                    .font(.system(size: glyphSide * 0.45, weight: .semibold))
                    .foregroundStyle(theme.foreground(.fgHero))
                    .frame(width: glyphSide, height: glyphSide)
                    .background(theme.resolve(.primary).soft,
                                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                if let eyebrow = configuration.eyebrow {
                    Text(eyebrow.uppercased())
                        .textStyle(.overline500)
                        .foregroundStyle(theme.text(.textTertiary))
                }
                configuration.content
                    .textStyle(titleStyle)
                    .foregroundStyle(theme.text(.textPrimary))
                if let subtitle = configuration.subtitle {
                    Text(subtitle)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let action = configuration.action {
                action
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textHero))
                    .padding(.horizontal, Theme.SpacingKey.sm.value)
                    .padding(.vertical, Theme.SpacingKey.xs.value)
                    .background(theme.resolve(.primary).soft, in: Capsule())
            }
        }
    }
}

/// A tab with its own padding, a caption and badge of its own type, and a
/// 3 pt sliding selection bar drawn with the configuration's geometry
/// namespace. Content-hugging bars get the padding as their gap.
private struct SlidingBarTabStyle: SegmentedTabBarChromeStyle {
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        SlidingBarTabBody(configuration: configuration)
    }
}

private struct SlidingBarTabBody: View {
    let configuration: SegmentedTabBarChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                configuration.leading
                Text(configuration.title)
                    .textStyle(configuration.isSelected ? .labelBase700 : .labelBase600)
                    .lineLimit(1)
                if let badge = configuration.badge {
                    Text(badge)
                        .textStyle(.overline500)
                        .foregroundStyle(theme.resolve(.primary).onSolid)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(theme.resolve(.primary).solid, in: Capsule())
                }
                if let closeButton = configuration.closeButton {
                    closeButton
                }
            }
            if let caption = configuration.caption {
                Text(caption).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        // An overlay, so the indicator never stretches the tab: a scrolling or
        // content-hugging bar keeps tabs as wide as their content.
        .overlay(alignment: .bottom) {
            if configuration.isSelected {
                Capsule()
                    .fill(theme.resolve(.primary).solid)
                    .frame(height: 3)
                    .matchedGeometryEffect(id: configuration.indicatorID, in: configuration.indicatorNamespace)
            }
        }
        .frame(maxWidth: configuration.isStretched ? .infinity : nil)
        .opacity(configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
        .contentShape(Rectangle())
    }

    private var foreground: Color {
        guard configuration.isEnabled else { return theme.text(.textDisabled) }
        return configuration.isSelected ? theme.text(.textHero) : theme.text(.textSecondary)
    }
}

// MARK: - Suite

@available(iOS 16.0, *)
@MainActor
final class TitleTabChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: Title

    /// The same title at three control sizes, each with its boxed glyph.
    func testCustomTitle_controlSizes() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 20) {
                titleFixture.controlSize(.small)
                titleFixture.controlSize(.regular)
                titleFixture.controlSize(.large)
            }
            .titleStyle(BoxedTitleStyle())
        )
    }

    /// Every content combination one style body has to draw.
    func testCustomTitle_contentVariants() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 20) {
                Title("Recently viewed").titleStyle(BoxedTitleStyle())
                Title("Deals").eyebrow("Limited time").titleStyle(BoxedTitleStyle())
                Title("Nearby").subtitle("Within 50 km")
                    .leading { Image(systemName: "location.fill") }
                    .titleStyle(BoxedTitleStyle())
                Title("Popular destinations").action("See all", action: {}).titleStyle(BoxedTitleStyle())
            }
        )
    }

    /// The stock title drawn through `makeBody` — the same pixels the built-in
    /// title draws, next to the custom one.
    func testCustomTitle_besideTheDefaultStyle() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 20) {
                titleFixture.titleStyle(.default)
                titleFixture.titleStyle(BoxedTitleStyle())
            }
        )
    }

    func testCustomTitle_darkScheme() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 20) {
                titleFixture
                titleFixture.controlSize(.large)
            }
            .titleStyle(BoxedTitleStyle()),
            colorScheme: .dark
        )
    }

    // MARK: Tabs

    /// The sliding bar with the tabs sharing the width, over the bar's baseline.
    func testCustomTabs_slidingBar() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                tabFixture(selection: 0).baseline()
                tabFixture(selection: 1).baseline()
            }
            .segmentedTabBarChromeStyle(SlidingBarTabStyle())
        )
    }

    /// Content-hugging tabs park at the leading edge with no gap of their own —
    /// the style's padding is the gap.
    func testCustomTabs_contentHugging() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                tabFixture(selection: 1).fillsWidth(false).baseline()
                tabFixture(selection: 1).fillsWidth(false)
            }
            .segmentedTabBarChromeStyle(SlidingBarTabStyle())
        )
    }

    /// A scrollable bar of captioned tabs, scrolled to its start.
    func testCustomTabs_scrollable() {
        assertComponentSnapshot(
            scrollableFixture(selection: 0)
                .segmentedTabBarChromeStyle(SlidingBarTabStyle())
        )
    }

    func testCustomTabs_rtl() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                tabFixture(selection: 1).baseline()
                tabFixture(selection: 1).fillsWidth(false)
            }
            .segmentedTabBarChromeStyle(SlidingBarTabStyle()),
            layoutDirection: .rightToLeft
        )
    }

    func testCustomTabs_darkScheme() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                tabFixture(selection: 1).baseline()
                scrollableFixture(selection: 2)
            }
            .segmentedTabBarChromeStyle(SlidingBarTabStyle()),
            colorScheme: .dark
        )
    }

    /// The pill track and the card chrome still come from the bar, around the
    /// styled tabs.
    func testCustomTabs_insideTheBarsOwnChrome() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                tabFixture(selection: 1).tabStyle(.pill)
                SegmentedTabBar(["Search", "Results", "Booking"], selection: .constant(0),
                                onClose: { _ in }, onAdd: {})
                    .tabStyle(.card)
            }
            .segmentedTabBarChromeStyle(SlidingBarTabStyle())
        )
    }

    // MARK: Fixtures

    private var titleFixture: Title {
        Title("Popular destinations")
            .eyebrow("This week")
            .subtitle("Where travellers go next")
            .leading { Image(systemName: "sparkles") }
            .action("See all", action: {})
    }

    private func tabFixture(selection: Int) -> SegmentedTabBar {
        SegmentedTabBar([TabItem("Flights").leading { Image(systemName: "airplane") },
                         TabItem("Stays", badge: "12").leading { Image(systemName: "bed.double.fill") },
                         TabItem("Cars", isEnabled: false).leading { Image(systemName: "car.fill") }],
                        selection: .constant(selection))
    }

    private func scrollableFixture(selection: Int) -> SegmentedTabBar {
        SegmentedTabBar([TabItem("Economy", caption: "$2,450"),
                         TabItem("Premium", caption: "$3,180"),
                         TabItem("Business", caption: "$6,900", badge: "2"),
                         TabItem("First", caption: "Sold out", isEnabled: false)],
                        selection: .constant(selection))
            .scrollable()
            .scrollAlign(.start)
    }
}
#endif
