//
//  FlexibilitySnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the flexibility-sweep behavior changes —
//  control placement, glyph/size shifts, read-only chrome, inline links, and
//  the long-tail axes — with dark + RTL variants where direction-sensitive.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class FlexibilitySnapshotTests: SnapshotTestCase {

    // MARK: Control placement (A1-A5)

    func testControlRow_leadingVsTrailing() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 16) {
            ControlRow("Trailing (default)", isOn: .constant(true)).control(.checkbox)
            ControlRow("Leading control", isOn: .constant(true)).control(.checkbox).controlPlacement(.leading)
        })
    }
    func testControlRow_leading_rtl() {
        assertComponentSnapshot(
            ControlRow("Leading control", isOn: .constant(true)).control(.checkbox).controlPlacement(.leading),
            layoutDirection: .rightToLeft
        )
    }
    func testCheckbox_placementAndLarge() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 12) {
            Checkbox(isChecked: .constant(true)).controlSize(.large)          // C4: 28pt glyph
            Checkbox(isChecked: .constant(true)).controlPlacement(.trailing)
            Checkbox(isChecked: .constant(true)).lineThrough().label { Text("Done") }   // E4 + D1
        })
    }
    func testRadioButton_trailing() {
        assertComponentSnapshot(RadioButton(isSelected: .constant(true)).controlPlacement(.trailing))
    }

    // MARK: Field size + read-only (C1, E1)

    func testTextInput_sizeRamp() {
        assertComponentSnapshot(VStack(spacing: 12) {
            TextInput("Small", text: .constant("value")).size(.small)
            TextInput("Large", text: .constant("value")).size(.large)
        })
    }
    func testTextInput_readOnly() {
        assertComponentSnapshot(
            TextInput("Email", text: .constant("ada@example.com")).readOnly()
        )
    }

    // MARK: Inline links (B1-B4)

    func testHelperText_links() {
        assertComponentSnapshot(HelperText("By continuing you accept the Terms.").links([("Terms", {})]))
    }
    func testCallout_links() {
        assertComponentSnapshot(Callout("See the docs for details.").links([("docs", {})]))
    }
    func testEmptyState_messageLinks() {
        assertComponentSnapshot(
            EmptyState("Nothing here").icon("tray").message("Read the guide to get started.", links: [("guide", {})])
        )
    }

    // MARK: Long-tail axes (E14/E15, C3, D8)

    func testAvatar_bordered() {
        assertComponentSnapshot(HStack(spacing: 12) {
            Avatar(.initials("AB")).bordered()
            Avatar(.initials("CD")).bordered(accent: .success)
        })
    }
    func testTag_closable() {
        assertComponentSnapshot(Tag("Istanbul").closable {})
    }
    func testChip_sizes() {
        assertComponentSnapshot(HStack(spacing: 8) {
            Chip("Small", isSelected: .constant(true)).size(.small)
            Chip("Medium", isSelected: .constant(true)).size(.medium)
            Chip("Large", isSelected: .constant(true)).size(.large)
        })
    }
    func testEmojiReactionButton_sizeAccent() {
        assertComponentSnapshot(HStack(spacing: 10) {
            EmojiReactionButton("👍", count: 12, initiallyReacted: true).accent(.success)
            EmojiReactionButton("🔥", count: 3).size(.small)
        })
    }
}
#endif
