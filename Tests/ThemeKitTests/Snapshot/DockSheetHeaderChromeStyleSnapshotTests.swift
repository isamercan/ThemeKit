//
//  DockSheetHeaderChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 18.09.2026.
//
//  Visual-regression coverage for the `ButtonDockChromeStyle` and
//  `SheetHeaderStyle` paths: a host-shaped docked bar with rounded top corners,
//  a top rule, its own padding ramp and a lifted shadow — over a scrolling page
//  and holding each of the three things a dock holds — and two host-shaped sheet
//  headers laid out differently from the stock one (a leading title with the
//  close button in the corner, and a centred title between two round buttons).
//  Both styles are host-shaped (their own metrics and type) but fed from theme
//  tokens, so the dark cases re-skin. A docked bar over a `ScrollView` renders
//  as nothing under `ImageRenderer`, so those pixels are pinned here rather
//  than in a unit test. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

// MARK: - Host-shaped styles

/// A docked bar with rounded top corners, a hairline rule along the top, 16 pt
/// at the sides and top, and a bottom inset that keeps a floor over whatever
/// the home indicator claims.
private struct LiftedButtonDockStyle: ButtonDockChromeStyle {
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        LiftedButtonDockBody(configuration: configuration)
    }
}

private struct LiftedButtonDockBody: View {
    let configuration: ButtonDockChromeStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: ThemeUnevenRoundedRect {
        ThemeUnevenRoundedRect(topLeadingRadius: Theme.RadiusRole.box.value,
                               topTrailingRadius: Theme.RadiusRole.box.value)
    }

    var body: some View {
        configuration.content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.top, Theme.SpacingKey.md.value)
            .padding(.bottom, max(Theme.SpacingKey.xl.value, configuration.safeAreaBottomInset))
            .background(theme.background(.bgWhite), in: shape)
            .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
            .themeShadow(.elevated)
    }
}

/// A sheet header with the title on the leading edge (after an optional back
/// arrow), the close button in the top-trailing corner and the description
/// under the title.
private struct CornerCloseSheetHeaderStyle: SheetHeaderStyle {
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        CornerCloseSheetHeaderBody(configuration: configuration)
    }
}

private struct CornerCloseSheetHeaderBody: View {
    let configuration: SheetHeaderStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
                if let leading = configuration.leading { leading } else {
                    glyph(configuration.backButton, tint: theme.text(.textPrimary))
                }
                configuration.content
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                Spacer(minLength: Theme.SpacingKey.md.value)
                if let trailing = configuration.trailing { trailing } else {
                    glyph(configuration.closeButton, tint: theme.text(.textSecondary))
                }
            }
            if let subtitle = configuration.subtitle {
                Text(subtitle)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            if let progress = configuration.progress {
                Capsule()
                    .fill(theme.border(.borderPrimary))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(theme.resolve(configuration.accent ?? .primary).solid)
                                .frame(width: geo.size.width * min(1, max(0, progress)))
                        }
                    }
                    .padding(.top, Theme.SpacingKey.xs.value)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.base.value)
        .background(theme.background(.bgWhite))
    }

    @ViewBuilder private func glyph(_ button: AnyView?, tint: Color) -> some View {
        if let button {
            button.font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
        }
    }
}

/// A sheet header laid out the other common way: a 32 pt row with the close
/// button at the leading edge, the title centred, an optional trailing button,
/// and the description underneath.
private struct CentredSheetHeaderStyle: SheetHeaderStyle {
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        CentredSheetHeaderBody(configuration: configuration)
    }
}

private struct CentredSheetHeaderBody: View {
    let configuration: SheetHeaderStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ZStack {
                configuration.content
                    .textStyle(.labelLg700)
                    .foregroundStyle(theme.text(.textPrimary))
                HStack {
                    round(configuration.closeButton)
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if let trailing = configuration.trailing { trailing } else {
                        round(configuration.backButton)
                    }
                }
            }
            .frame(height: 32)
            if let subtitle = configuration.subtitle {
                Text(subtitle)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(theme.background(.bgWhite))
    }

    @ViewBuilder private func round(_ button: AnyView?) -> some View {
        if let button {
            button
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text(.textSecondary))
                .frame(width: 32, height: 32)
                .background(theme.background(.bgSecondaryLight), in: Circle())
        }
    }
}

// MARK: - Suite

@available(iOS 16.0, *)
@MainActor
final class DockSheetHeaderChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: Button dock

    /// The three things a dock holds: a two-button group, a price beside one
    /// button, and free content above a button.
    func testCustomDock_contentVariants() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                page.buttonDock { buttonPair }.frame(height: 190)
                page.buttonDock { priceRow }.frame(height: 170)
                page.buttonDock { stackedRow }.frame(height: 200)
            }
            .buttonDockChromeStyle(LiftedButtonDockStyle())
        )
    }

    /// The stock bar drawn through `makeBody` — the same pixels the built-in
    /// dock draws — above the custom one.
    func testCustomDock_besideTheDefaultStyle() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                page.buttonDock { buttonPair }.buttonDockChromeStyle(.default).frame(height: 180)
                page.buttonDock { buttonPair }.buttonDockChromeStyle(LiftedButtonDockStyle()).frame(height: 190)
            }
        )
    }

    /// The case `ImageRenderer` can't see: a docked bar over a scrolling page.
    func testCustomDock_overAScrollView() {
        assertComponentSnapshot(
            scrollingPage
                .buttonDock { priceRow }
                .buttonDockChromeStyle(LiftedButtonDockStyle())
                .frame(height: 300)
        )
    }

    /// RTL: the price and the button swap sides, and the bar's corners follow.
    func testCustomDock_rtl() {
        assertComponentSnapshot(
            page.buttonDock { priceRow }
                .buttonDockChromeStyle(LiftedButtonDockStyle())
                .frame(height: 190),
            layoutDirection: .rightToLeft
        )
    }

    func testCustomDock_darkScheme() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                page.buttonDock { buttonPair }.frame(height: 190)
                page.buttonDock { priceRow }.frame(height: 170)
            }
            .buttonDockChromeStyle(LiftedButtonDockStyle()),
            colorScheme: .dark
        )
    }

    // MARK: Sheet header

    /// The leading-title layout, across the content the header can hold.
    func testCustomSheetHeader_cornerClose() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                SheetHeader("Filters").onClose {}
                SheetHeader("Passengers").subtitle("Who is travelling?").onBack {}.onClose {}
                SheetHeader("Payment").subtitle("Step 3 of 4").onBack {}.onClose {}.progress(0.75).accent(.success)
                SheetHeader("Sort").onClose {}.leading { Icon(systemName: "line.3.horizontal.decrease") }
            }
            .sheetHeaderStyle(CornerCloseSheetHeaderStyle())
        )
    }

    /// The centred-title layout, with the close button leading.
    func testCustomSheetHeader_centredRow() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                SheetHeader("Filters").onClose {}
                SheetHeader("Passengers").subtitle("Who is travelling?").onBack {}.onClose {}
                SheetHeader("Cabin").onClose {}.trailing { ThemeButton("Reset") {}.variant(.ghost).size(.small) }
            }
            .sheetHeaderStyle(CentredSheetHeaderStyle())
        )
    }

    /// The stock header drawn through `makeBody`, then the same header under
    /// each custom layout.
    func testCustomSheetHeader_besideTheDefaultStyle() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                headerFixture.sheetHeaderStyle(.default)
                headerFixture.sheetHeaderStyle(CornerCloseSheetHeaderStyle())
                headerFixture.sheetHeaderStyle(CentredSheetHeaderStyle())
            }
        )
    }

    /// RTL: the back arrow turns, and both layouts mirror around it.
    func testCustomSheetHeader_rtl() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                headerFixture.sheetHeaderStyle(CornerCloseSheetHeaderStyle())
                headerFixture.sheetHeaderStyle(CentredSheetHeaderStyle())
            },
            layoutDirection: .rightToLeft
        )
    }

    func testCustomSheetHeader_darkScheme() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                headerFixture.sheetHeaderStyle(CornerCloseSheetHeaderStyle())
                SheetHeader("Payment").subtitle("Step 3 of 4").onBack {}.onClose {}.progress(0.4)
                    .sheetHeaderStyle(CornerCloseSheetHeaderStyle())
                headerFixture.sheetHeaderStyle(CentredSheetHeaderStyle())
            },
            colorScheme: .dark
        )
    }

    // MARK: Fixtures

    private var headerFixture: SheetHeader {
        SheetHeader("Passengers").subtitle("Who is travelling?").onBack {}.onClose {}
    }

    /// A plain tinted page for the dock to sit at the bottom of.
    private var page: some View {
        ThemedPage()
    }

    private var scrollingPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    ListRow("Option \(index + 1)").subtitle("Available")
                }
            }
            .padding(Theme.SpacingKey.md.value)
        }
    }

    private var buttonPair: some View {
        ButtonGroup(.horizontal) {
            SecondaryButton("Back") {}
            PrimaryButton("Continue") {}
        }
    }

    private var priceRow: some View {
        HStack {
            PriceTag(1249).size(.large)
            Spacer(minLength: Theme.SpacingKey.md.value)
            PrimaryButton("Select") {}
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            Callout("Free cancellation until 24 hours before departure.").calloutStyle(.soft)
            PrimaryButton("Continue") {}.fullWidth()
        }
    }
}

/// The dock's backdrop — a token surface, so the bar's own fill and shadow read
/// against something in both schemes.
private struct ThemedPage: View {
    @Environment(\.theme) private var theme

    var body: some View {
        theme.background(.bgSecondaryLight)
    }
}
#endif
