//
//  FileInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A styled file-picker field: a "Choose file" segment + the selected
/// filename. (daisyUI "File Input"; complements the list-based Upload.)
public struct FileInput: View {
    @Environment(\.theme) private var theme

    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var fileName: String?
    private var buttonTitle: String = "Choose file"
    private var placeholder: String = "No file chosen"
    private var infoMessages: [InfoMessage] = []
    private var onClear: (() -> Void)?

    private let label: String?
    private let onPick: () -> Void

    public init(_ label: String? = nil, onPick: @escaping () -> Void) {   // R1
        self.label = label
        self.onPick = onPick
    }

    private var fieldBorder: Color {
        switch infoMessages.dominantKind {
        case .error: return theme.border(.systemcolorsBorderError)
        case .warning: return theme.border(.systemcolorsBorderWarning)
        default: return theme.border(.borderPrimary)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }

            HStack(spacing: 0) {
                Button(action: onPick) {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Image(systemName: "paperclip").font(.system(size: 13, weight: .semibold))
                        Text(buttonTitle).textStyle(.labelSm700)
                    }
                    .foregroundStyle(theme.text(.textHero))
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .frame(maxHeight: .infinity)
                    .background(theme.background(.bgElevatorTertiary))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)

                Text(fileName ?? placeholder)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(fileName != nil ? theme.text(.textPrimary) : theme.text(.textTertiary))
                    .lineLimit(1)
                    .padding(.horizontal, Theme.SpacingKey.md.value)

                Spacer(minLength: 0)

                if fileName != nil, let onClear {
                    Button(action: onClear) {
                        Icon(systemName: "xmark.circle.fill", size: .sm, color: theme.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, Theme.SpacingKey.md.value)
                    .accessibilityLabel(String(themeKit: "Remove"))
                }
            }
            .frame(height: 48)
            .background(theme.background(.bgWhite))
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(fieldBorder, lineWidth: infoMessages.dominantKind != nil ? 1.5 : 1))

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FileInput {
    /// The selected file's display name (the bound value shown beside the button).
    func fileName(_ name: String?) -> Self { copy { $0.fileName = name } }

    /// Title of the "choose file" segment.
    func buttonTitle(_ title: String) -> Self { copy { $0.buttonTitle = title } }

    /// Placeholder shown when no file is chosen.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Validation / hint messages displayed below the field.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Trailing clear button handler (shown only when a file is selected).
    func onClear(_ action: (() -> Void)?) -> Self { copy { $0.onClear = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 16) {
        FileInput("Passport", onPick: {})
        FileInput("Photo", onPick: {}).fileName("passport-scan.jpg")
    }
    .padding()
}
