//
//  ButtonChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for ThemeButton's chrome door: the stock chrome
//  through `.buttonChromeStyle(.default)` (must match ButtonSnapshotTests'
//  built-in look), its pressed / focused states drawn straight from a
//  configuration, a custom chrome across variants, states, slots, dark and
//  RTL, and the new `.label` / `.loadingIndicator` / `.spacing` slots on the
//  built-in chrome. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

/// A test chrome that owns the whole footprint: a tinted capsule with a 2pt
/// border, its own text style (re-fonting the label), a fixed 44pt height and
/// a focus ring — all painted from the resolved semantic color.
private struct RingChrome: ButtonChromeStyle {
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        RingChromeBody(configuration: configuration)
    }
}

private struct RingChromeBody: View {
    let configuration: ButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let fill = theme.resolve(configuration.color)
        let side: CGFloat = 44
        configuration.label
            .textStyle(.headingSm)
            .foregroundStyle(configuration.isEnabled ? fill.accent : theme.text(.textDisabled))
            .tint(fill.accent)
            .padding(.horizontal, configuration.isIconOnly ? 0 : Theme.SpacingKey.lg.value)
            .frame(minWidth: configuration.isIconOnly ? side : nil, minHeight: side)
            .frame(maxWidth: configuration.isFullWidth ? .infinity : nil)
            .background(configuration.isPressed ? fill.bgHover : fill.bg, in: Capsule())
            .overlay { Capsule().strokeBorder(configuration.variant == .ghost ? .clear : fill.border, lineWidth: 2) }
            .overlay {
                Capsule().stroke(fill.accent, lineWidth: 2).padding(-3)
                    .opacity(configuration.isFocused ? 1 : 0)
            }
    }
}

@MainActor
final class ButtonChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: Stock chrome through the door (≡ ButtonSnapshotTests)

    func testDefaultChrome_variants() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Solid") {}.variant(.solid)
                ThemeButton("Soft") {}.variant(.soft)
                ThemeButton("Outline") {}.variant(.outline)
                ThemeButton("Ghost") {}.variant(.ghost)
                ThemeButton("Link") {}.variant(.link)
            }
            .buttonChromeStyle(.default)
        )
    }

    func testDefaultChrome_shapesStatesAndBlock() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ThemeButton("Pill") {}.shape(.pill)
                    ThemeButton { }.icon(leading: "heart.fill").shape(.circle)
                    ThemeButton { }.icon(leading: "square.and.arrow.up").shape(.square)
                }
                ThemeButton("Loading") {}.loading()
                ThemeButton("Disabled") {}.disabled(true)
                ThemeButton("Continue") {}.fullWidth()
            }
            .buttonChromeStyle(.default)
        )
    }

    /// Pressed + focused can't be driven through a live Button in a snapshot,
    /// so the stock chrome draws them straight from a configuration.
    func testDefaultChrome_pressedAndFocused() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                stockChrome("Resting", variant: .solid)
                stockChrome("Pressed", variant: .solid, isPressed: true)
                stockChrome("Pressed soft", variant: .soft, isPressed: true)
                stockChrome("Pressed outline", variant: .outline, isPressed: true)
                stockChrome("Focused", variant: .solid, isFocused: true)
            }
            .padding(4)
        )
    }

    // MARK: Custom chrome

    func testCustomChrome_variantsAndColors() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Solid") {}.variant(.solid)
                ThemeButton("Soft success") {}.variant(.soft).color(.success)
                ThemeButton("Outline error") {}.variant(.outline).color(.error)
                ThemeButton("Ghost") {}.variant(.ghost)
            }
            .buttonChromeStyle(RingChrome())
        )
    }

    func testCustomChrome_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Loading") {}.loading()
                ThemeButton("Saving") {}.loading().spinnerPlacement(.leading)
                ThemeButton("Disabled") {}.disabled(true)
                HStack(spacing: 8) {
                    ThemeButton { }.icon(leading: "heart.fill").shape(.circle).color(.error)
                    ThemeButton { }.icon(leading: "plus").iconOnly()
                }
                ThemeButton("Continue") {}.icon(trailing: "arrow.right").fullWidth()
            }
            .buttonChromeStyle(RingChrome())
        )
    }

    func testCustomChrome_slots() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Pay 42.00") {}
                    .label { Text("Pay \(Text("42.00").italic())") }
                    .icon(leading: "creditcard", trailing: "lock.fill")
                ThemeButton("Uploading") {}
                    .loading().spinnerPlacement(.trailing)
                    .loadingIndicator { Image(systemName: "arrow.up.circle") }
                ThemeButton { } label: {
                    HStack { Image(systemName: "cart"); Text("Checkout"); Badge("3").badgeStyle(.error).size(.small) }
                }
            }
            .buttonChromeStyle(RingChrome())
        )
    }

    func testCustomChrome_dark() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Solid") {}
                ThemeButton("Outline") {}.variant(.outline).color(.info)
                ThemeButton("Disabled") {}.disabled(true)
            }
            .buttonChromeStyle(RingChrome()),
            colorScheme: .dark
        )
    }

    func testCustomChrome_rtl() {
        assertComponentSnapshot(
            ThemeButton("Continue") {}
                .icon(leading: "star", trailing: "arrow.forward")
                .loading().spinnerPlacement(.leading)
                .buttonChromeStyle(RingChrome()),
            layoutDirection: .rightToLeft
        )
    }

    // MARK: New slots on the built-in chrome

    func testBuiltInChrome_labelIndicatorSpacing() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                ThemeButton("Pay 42.00") {}
                    .label { Text("Pay \(Text("42.00").italic())") }
                    .icon(leading: "creditcard", trailing: "lock.fill")
                ThemeButton("Wide gap") {}
                    .icon(leading: "star", trailing: "arrow.right")
                    .spacing(.lg)
                ThemeButton("Uploading") {}
                    .variant(.soft)
                    .loading().spinnerPlacement(.trailing)
                    .loadingIndicator { Image(systemName: "arrow.up.circle") }
                ThemeButton("Replaced") {}
                    .variant(.outline)
                    .loading()
                    .loadingIndicator { Image(systemName: "hourglass") }
            }
        )
    }

    // MARK: Helpers

    private func stockChrome(
        _ title: String,
        variant: ButtonVariant,
        isPressed: Bool = false,
        isFocused: Bool = false
    ) -> some View {
        DefaultButtonChromeStyle().makeBody(configuration: ButtonChromeStyleConfiguration(
            label: AnyView(Text(title).textStyle(.labelMd600).lineLimit(1)),
            title: title, isPressed: isPressed, isEnabled: true, isLoading: false,
            isFocused: isFocused, isIconOnly: false, isFullWidth: false,
            variant: variant, color: .primary, shape: .rounded, size: .medium,
            density: .regular, isMotionEnabled: false
        ))
    }
}
#endif
