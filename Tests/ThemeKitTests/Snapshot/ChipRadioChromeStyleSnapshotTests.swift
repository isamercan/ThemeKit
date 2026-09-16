//
//  ChipRadioChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for the consumer chrome doors on the selection
//  controls: `RadioButtonChromeStyle` (standalone, RadioGroup rows, the
//  indicator-only internal radios, `.default`), `RadioButton.description`, and
//  a `ChipStyle` that sets its own title font. Dark + RTL where the layout is
//  direction-sensitive. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class ChipRadioChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: RadioButtonChromeStyle

    private var radioStates: some View {
        VStack(alignment: .leading, spacing: 12) {
            RadioButton("Selected", isSelected: .constant(true))
                .description("The chrome draws the description too.")
            RadioButton("Unselected", isSelected: .constant(false))
            RadioButton("Disabled selected", isSelected: .constant(true)).disabled(true)
            RadioButton("Success accent", isSelected: .constant(true)).accent(.success)
            RadioButton("Invalid", isSelected: .constant(false))
                .infoMessages([InfoMessage("Choose an option", kind: .error)])
            RadioButton(isSelected: .constant(true))   // indicator only
        }
    }

    func testRadioButton_customChrome() {
        assertComponentSnapshot(radioStates.radioButtonChromeStyle(SnapshotDiscRadioChrome()))
    }
    func testRadioButton_customChrome_dark() {
        assertComponentSnapshot(radioStates.radioButtonChromeStyle(SnapshotDiscRadioChrome()), colorScheme: .dark)
    }
    func testRadioButton_customChrome_rtl() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                RadioButton("Leading indicator", isSelected: .constant(true))
                    .description("Mirrors under right-to-left.")
                RadioButton("Trailing indicator", isSelected: .constant(false)).controlPlacement(.trailing)
            }
            .radioButtonChromeStyle(SnapshotDiscRadioChrome()),
            layoutDirection: .rightToLeft
        )
    }

    /// `.default` under a custom ancestor restores the built-in look — this
    /// reference should match `FormControlSnapshotTests.testRadioButton_states`'
    /// look for the same rows.
    func testRadioButton_explicitDefault() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                RadioButton("Selected", isSelected: .constant(true))
                RadioButton("Unselected", isSelected: .constant(false))
                RadioButton("Disabled", isSelected: .constant(false)).disabled(true)
            }
            .radioButtonChromeStyle(.default)
            .radioButtonChromeStyle(SnapshotDiscRadioChrome())
        )
    }

    /// The built-in path with the new `.description(_:)`.
    func testRadioButton_description_builtIn() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                RadioButton("Pay later", isSelected: .constant(true))
                    .description("Pay at the property before check-in.")
                    .alignment(.top)
                RadioButton("Pay now", isSelected: .constant(false))
                    .description("Card payment, non-refundable.")
                    .controlPlacement(.trailing)
                RadioButton("Unavailable", isSelected: .constant(false))
                    .description("Not offered for this rate.")
                    .disabled(true)
            }
        )
    }

    func testRadioGroup_customChrome() {
        assertComponentSnapshot(
            RadioGroup(title: "Cabin", options: ["Economy", "Business", "First"], selection: .constant("Business")) { $0 }
                .optionDescription { $0 == "First" ? "Suites on long-haul routes." : nil }
                .optionEnabled { $0 != "Economy" }
                .controlPlacement(.trailing)
                .radioButtonChromeStyle(SnapshotRowRadioChrome())
        )
    }
    func testRadioGroup_customChrome_dark() {
        assertComponentSnapshot(
            RadioGroup(title: "Cabin", options: ["Economy", "Business"], selection: .constant("Economy")) { $0 }
                .accent(.success)
                .radioButtonChromeStyle(SnapshotRowRadioChrome()),
            colorScheme: .dark
        )
    }
    func testRadioGroup_customChrome_horizontal() {
        assertComponentSnapshot(
            RadioGroup(title: "Trip", options: ["One way", "Round trip"], selection: .constant("One way")) { $0 }
                .axis(.horizontal)
                .radioButtonChromeStyle(SnapshotDiscRadioChrome())
        )
    }

    /// The label-less radios ThemeKit composes pick the environment style up.
    func testIndicatorOnlyRadios_customChrome() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                ControlRow("Radio control row", isOn: .constant(true)).control(.radio)
                RadioCard("Standard fare", isSelected: true) {}
                ListRow("Selectable row").leadingSelection(.constant(false))
            }
            .radioButtonChromeStyle(SnapshotDiscRadioChrome())
        )
    }

    // MARK: ChipStyle title font

    private var chipRow: some View {
        HStack(spacing: 8) {
            Chip("Idle", isSelected: .constant(false))
            Chip("Picked", isSelected: .constant(true))
            Chip("Slot", isSelected: .constant(true))
                .leading { Image(systemName: "airplane") }
            Chip("Off", isSelected: .constant(false)).disabled(true)
        }
    }

    func testChip_customStyleFont() {
        assertComponentSnapshot(chipRow.chipStyle(SnapshotUnderlineChipStyle()))
    }
    func testChip_customStyleFont_rtl() {
        assertComponentSnapshot(chipRow.chipStyle(SnapshotUnderlineChipStyle()), layoutDirection: .rightToLeft)
    }
}

// MARK: - Snapshot styles

/// A filled accent disc with a light center, a medium label and a secondary
/// description, fading when disabled.
private struct SnapshotDiscRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        SnapshotDiscRadioChromeBody(configuration: configuration)
    }
}

private struct SnapshotDiscRadioChromeBody: View {
    let configuration: RadioButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let c = configuration
        let paint = theme.resolve(c.accent ?? .primary)
        let ring = c.validation == .error ? theme.border(.systemcolorsBorderError) : paint.border
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            if c.controlPlacement == .leading { indicator(paint: paint, ring: ring) }
            if c.label != nil || c.description != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let label = c.label {
                        Text(label).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
                    }
                    if let description = c.description {
                        Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
            }
            if c.controlPlacement == .trailing { indicator(paint: paint, ring: ring) }
        }
        .opacity(c.isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
    }

    private func indicator(paint: SemanticColor.Resolved, ring: Color) -> some View {
        let selected = configuration.isSelected
        return Circle()
            .fill(selected ? paint.solid : theme.background(.bgWhite))
            .overlay { Circle().fill(paint.onSolid).padding(5).opacity(selected ? 1 : 0) }
            .overlay { Circle().strokeBorder(ring, lineWidth: selected ? 0 : 1) }
            .frame(width: 18, height: 18)
    }
}

/// A card row: label and description first, a thick-ring indicator pinned to
/// the trailing edge.
private struct SnapshotRowRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        SnapshotRowRadioChromeBody(configuration: configuration)
    }
}

private struct SnapshotRowRadioChromeBody: View {
    let configuration: RadioButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let c = configuration
        let paint = theme.resolve(c.accent ?? .primary)
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
                if let label = c.label {
                    Text(label).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                }
                if let description = c.description {
                    Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            Circle()
                .strokeBorder(c.isSelected ? paint.solid : theme.border(.borderPrimary), lineWidth: c.isSelected ? 6 : 1)
                .frame(width: 20, height: 20)
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(c.isSelected ? .bgElevatorTertiary : .bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .opacity(c.isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
    }
}

/// A rounded rectangle with an underline when selected and its own
/// medium-weight title font (slots without a font inherit it).
private struct SnapshotUnderlineChipStyle: ChipStyle {
    func makeBody(configuration: ChipStyleConfiguration) -> some View {
        SnapshotUnderlineChipChrome(configuration: configuration)
    }
}

private struct SnapshotUnderlineChipChrome: View {
    let configuration: ChipStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        configuration.content
            .textStyle(.bodyBase500)
            .foregroundStyle(configuration.isSelected ? theme.text(.textHero) : theme.text(.textPrimary))
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(theme.background(.bgWhite), in: shape)
            .overlay(shape.strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.border(.borderHero)).frame(height: 2)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .opacity(configuration.isSelected ? 1 : 0)
            }
            .opacity(configuration.isEnabled ? 1 : 0.5)
    }
}
#endif
