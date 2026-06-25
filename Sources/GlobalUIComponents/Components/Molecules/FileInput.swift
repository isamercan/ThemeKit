//
//  FileInput.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A styled file-picker field: a "Choose file" segment + the selected
//  filename. (daisyUI "File Input"; complements the list-based Upload.)
//

import SwiftUI

public struct FileInput: View {
    private let label: String?
    private let fileName: String?
    private let buttonTitle: String
    private let placeholder: String
    private let isEnabled: Bool
    private let onPick: () -> Void

    public init(
        label: String? = nil,
        fileName: String? = nil,
        buttonTitle: String = "Choose file",
        placeholder: String = "No file chosen",
        isEnabled: Bool = true,
        onPick: @escaping () -> Void
    ) {
        self.label = label
        self.fileName = fileName
        self.buttonTitle = buttonTitle
        self.placeholder = placeholder
        self.isEnabled = isEnabled
        self.onPick = onPick
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
                    .foregroundStyle(Theme.shared.text(.textHero))
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .frame(maxHeight: .infinity)
                    .background(Theme.shared.background(.bgElevatorTertiary))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)

                Text(fileName ?? placeholder)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(fileName != nil ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textTertiary))
                    .lineLimit(1)
                    .padding(.horizontal, Theme.SpacingKey.md.value)

                Spacer(minLength: 0)
            }
            .frame(height: 48)
            .background(Theme.shared.background(.bgWhite))
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
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
