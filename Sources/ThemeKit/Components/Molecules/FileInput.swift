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
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var fileName: String?
    private var buttonTitle: String = String(themeKit: "Choose file")
    private var placeholder: String = String(themeKit: "No file chosen")
    private var infoMessages: [InfoMessage] = []
    private var onClear: (() -> Void)?

    private let label: String?
    private let onPick: () -> Void

    public init(_ label: String? = nil, onPick: @escaping () -> Void) {   // R1
        self.label = label
        self.onPick = onPick
    }

    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }

            fieldBox

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages)
            }
        }
    }

    /// The field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Mapping: there is no focusable text element (a button + static filename),
    /// so `isFocused` is always `false`; error/warning come from `infoMessages`'
    /// dominant kind; `size` is `.medium` — FileInput has no `TextInputSize` axis
    /// (the row keeps its fixed 48pt height in the content).
    @ViewBuilder
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldRow),
            isFocused: false,
            isEnabled: isEnabled,
            hasError: dominant == .error,
            hasWarning: dominant == .warning,
            size: .medium
        ))
    }

    /// The "choose file" segment + filename row, sized — everything the
    /// ``FieldStyle`` receives as `configuration.content`.
    private var fieldRow: some View {
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
                    Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .padding(.trailing, Theme.SpacingKey.md.value)
                .accessibilityLabel(String(themeKit: "Remove"))
            }
        }
        .frame(height: 48)
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
    PreviewMatrix("FileInput") {
        PreviewCase("Empty") { FileInput("Passport", onPick: {}) }
        PreviewCase("File chosen + clear") {
            FileInput("Photo", onPick: {}).fileName("passport-scan.jpg").onClear {}
        }
        PreviewCase("Error message") {
            FileInput("Visa", onPick: {})
                .infoMessages([InfoMessage("File is too large", kind: .error)])
        }
        // Swapped chrome: underlined field, same behavior.
        PreviewCase("Underlined field style") {
            FileInput("Receipt", onPick: {}).fieldStyle(.underlined)
        }
    }
}
