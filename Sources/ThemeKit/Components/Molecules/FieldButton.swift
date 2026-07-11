//
//  FieldButton.swift
//  ThemeKit
//
//  Molecule. A form-field-styled tappable trigger — a label, a value and a
//  trailing chevron — that runs an action instead of editing text. Use it to open
//  a picker/sheet (passengers, cabin class, a date summary…). Token-bound. Unlike
//  ``SelectBox`` (native options menu) it opens whatever you want. The field
//  chrome (fill + border) is a swappable ``FieldStyle`` set with `.fieldStyle(_:)`.
//

import SwiftUI

public struct FieldButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no action.
    @Environment(\.isReadOnly) private var isReadOnly
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.fieldDefaults) private var fieldDefaults

    private let value: String
    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var fieldLabel: String?
    private var systemImage: String?
    private var trailingSystemImage: String? = "chevron.down"
    private var isPlaceholder = false
    /// Explicit `.size(_:)` preset — wins over the subtree `FieldDefaults.size`.
    private var explicitSize: TextInputSize?

    public init(_ value: String, action: @escaping () -> Void) {   // R1
        self.value = value
        self.action = action
    }

    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → the classic
    /// 56pt (labelled) / 48pt height.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }

    public var body: some View {
        // Read-only keeps the normal (non-dimmed) chrome and the VoiceOver
        // label/value but never runs the action (E1 — distinct from `.disabled`).
        Button { if !isReadOnly { action() } } label: {
            fieldBox
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
        .accessibilityLabel("\(fieldLabel.map { $0 + ", " } ?? "")\(value)")
        .accessibilityAddTraits(.isButton)
    }

    /// The composed trigger row (label + value + accessories), sized —
    /// everything the active ``FieldStyle`` receives as `configuration.content`.
    private var fieldCore: some View {
        VStack(alignment: .leading, spacing: fieldLabel != nil ? 2 : 0) {
            if let fieldLabel {
                Text(fieldLabel).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            }
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 14)).foregroundStyle(theme.text(.textSecondary))
                }
                Text(value).textStyle(.bodyBase400)
                    .foregroundStyle(isPlaceholder ? theme.text(.textTertiary) : theme.text(.textPrimary))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage).font(.system(size: 12)).foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        // Scales with Dynamic Type (G2); an explicit/subtree size preset remaps
        // the classic 56pt (labelled) / 48pt heights onto the family ramp (C1).
        .scaledControlHeight(effectiveSize?.height ?? (fieldLabel != nil ? 56 : 48))
        .frame(maxWidth: .infinity)
    }

    /// The trigger row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: FieldButton has no focus / open-popover state and no
    /// validation axis, so `isFocused` / `hasError` / `hasWarning` are always
    /// false; `isEnabled` comes from the environment (`.disabled(_:)`). With no
    /// explicit `.size(_:)` and no subtree `FieldDefaults.size` the height stays
    /// the classic 48/56pt (nominal `.medium`), carried by the content.
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: false,
            isEnabled: isEnabled,
            hasError: false,
            hasWarning: false,
            size: effectiveSize ?? .medium
        ))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FieldButton {
    /// A small label above the value (form-field style).
    func label(_ text: String?) -> Self { copy { $0.fieldLabel = text } }
    /// A leading SF Symbol.
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// The trailing accessory symbol (default `chevron.down`; pass `nil` to hide).
    func trailing(_ systemName: String?) -> Self { copy { $0.trailingSystemImage = systemName } }
    /// Renders the value in the muted placeholder colour (nothing chosen yet).
    func placeholder(_ on: Bool = true) -> Self { copy { $0.isPlaceholder = on } }
    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? 56/48pt`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 10) {
        FieldButton("2 Passengers · Economy") { }.label("Passengers").icon("person.2.fill")
        FieldButton("Select a date") { }.icon("calendar").placeholder()
        // Underlined chrome via the shared FieldStyle hook.
        FieldButton("Business class") { }.label("Cabin").fieldStyle(.underlined)
        // Size ramp — explicit `.size(_:)` wins over `FieldDefaults.size`.
        FieldButton("Small trigger") { }.size(.small)
        FieldButton("Large trigger") { }.label("Room").size(.large)
        // Read-only: normal chrome, action suppressed (E1).
        FieldButton("1 Room · 2 Guests") { }.label("Occupancy").readOnly()
    }
    .padding()
}
