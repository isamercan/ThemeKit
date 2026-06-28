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

    private let label: String?
    private let fileName: String?
    private let buttonTitle: String
    private let placeholder: String
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let infoMessages: [InfoMessage]
    private let onPick: () -> Void
    private let onClear: (() -> Void)?

    public init(
        label: String? = nil,
        fileName: String? = nil,
        buttonTitle: String = "Choose file",
        placeholder: String = "No file chosen",
        infoMessages: [InfoMessage] = [],
        onPick: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.label = label
        self.fileName = fileName
        self.buttonTitle = buttonTitle
        self.placeholder = placeholder
        self.infoMessages = infoMessages
        self.onPick = onPick
        self.onClear = onClear
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

#Preview {
    VStack(spacing: 16) {
        FileInput(label: "Passport", onPick: {})
        FileInput(label: "Photo", fileName: "passport-scan.jpg", onPick: {})
    }
    .padding()
}
