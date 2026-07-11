//
//  FormControlSnapshotTests.swift
//  ThemeKitTests
//
//  Form controls are the workhorses of every data-entry screen. Their error /
//  filled / selected states are exactly where a token or spacing change does the
//  most damage, so they're snapshotted across those states.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class FormControlSnapshotTests: SnapshotTestCase {

    // MARK: TextInput

    func testTextInput_empty() {
        assertComponentSnapshot(
            TextInput("Email", text: .constant("")).placeholder("you@example.com").icon(leading: "envelope")
        )
    }

    func testTextInput_filled() {
        assertComponentSnapshot(
            TextInput("Email", text: .constant("traveller@example.com")).icon(leading: "envelope")
        )
    }

    func testTextInput_errorState() {
        assertComponentSnapshot(
            TextInput("Email", text: .constant("not-an-email"))
                .infoMessages([InfoMessage("Enter a valid email address", kind: .error)])
        )
    }

    func testTextInput_secure() {
        assertComponentSnapshot(
            TextInput("Password", text: .constant("hunter2")).secure()
        )
    }

    // MARK: PhoneField (F1.1)

    func testPhoneField_states() {
        // Controlled dial codes → deterministic regardless of the host locale.
        assertComponentSnapshot(VStack(spacing: 12) {
            PhoneField("Phone", number: .constant("532 123 456 7"),
                       dialCode: .constant(DialCode(regionCode: "TR", code: "+90")))
            PhoneField("Phone", number: .constant(""),
                       dialCode: .constant(DialCode(regionCode: "US", code: "+1")))
                .required()
                .infoMessages([InfoMessage("Enter a valid phone number.", kind: .error)])
        })
    }

    func testPhoneField_rtl() {
        // Trigger mirrors to the leading edge; "+90" must not bidi-flip.
        assertComponentSnapshot(
            PhoneField("Phone", number: .constant("532 123 456 7"),
                       dialCode: .constant(DialCode(regionCode: "TR", code: "+90"))),
            layoutDirection: .rightToLeft
        )
    }

    // MARK: Checkbox

    func testCheckbox_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                Checkbox("Checked", isChecked: .constant(true))
                Checkbox("Unchecked", isChecked: .constant(false))
                Checkbox("Indeterminate", isChecked: .constant(false)).indeterminate()
                Checkbox("Disabled", isChecked: .constant(true)).disabled(true)
            }
        )
    }

    // MARK: RadioButton

    func testRadioButton_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                RadioButton("Selected", isSelected: .constant(true))
                RadioButton("Unselected", isSelected: .constant(false))
                RadioButton("Disabled", isSelected: .constant(false)).disabled(true)
            }
        )
    }

    // MARK: SegmentedControl

    func testSegmentedControl() {
        assertComponentSnapshot(
            SegmentedControl(["Day", "Week", "Month"], selection: .constant(1))
        )
    }

    // MARK: Dark mode + Dynamic Type

    func testTextInput_errorState_darkMode() {
        assertComponentSnapshot(
            TextInput("Email", text: .constant("not-an-email"))
                .infoMessages([InfoMessage("Enter a valid email address", kind: .error)]),
            colorScheme: .dark
        )
    }

    func testCheckbox_largeText() {
        assertComponentSnapshot(
            Checkbox("I accept the terms", isChecked: .constant(true)),
            contentSize: .accessibilityExtraExtraExtraLarge
        )
    }
}
#endif
