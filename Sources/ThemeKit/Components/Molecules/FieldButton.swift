//
//  FieldButton.swift
//  ThemeKit
//
//  Molecule. A form-field-styled tappable trigger — a label, a value and a
//  trailing chevron — that runs an action instead of editing text. Use it to open
//  a picker/sheet (passengers, cabin class, a date summary…). Token-bound. Unlike
//  ``SelectBox`` (native options menu) it opens whatever you want.
//

import SwiftUI

public struct FieldButton: View {
    @Environment(\.theme) private var theme

    private let value: String
    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var fieldLabel: String?
    private var systemImage: String?
    private var trailingSystemImage: String? = "chevron.down"
    private var isPlaceholder = false

    public init(_ value: String, action: @escaping () -> Void) {   // R1
        self.value = value
        self.action = action
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }

    public var body: some View {
        Button(action: action) {
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
            .frame(height: fieldLabel != nil ? 56 : 48)
            .frame(maxWidth: .infinity)
            .background(theme.background(.bgBase), in: shape)
            .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fieldLabel.map { $0 + ", " } ?? "")\(value)")
        .accessibilityAddTraits(.isButton)
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
    }
    .padding()
}
