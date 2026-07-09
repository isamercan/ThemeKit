//
//  InputLabel.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A form field label: text + optional required asterisk + optional info
/// glyph. Shared by the input components.
public struct InputLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)` (R5)

    // Appearance/state — mutated only through the modifiers below (R2).
    private var isRequired = false
    private var hasInfo = false
    private var hasError = false

    private let text: String

    public init(_ text: String) {   // R1
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .textStyle(.labelSm600)
                .foregroundStyle(textColor)
            if isRequired {
                Text("*").textStyle(.labelSm600)
                    .foregroundStyle(isEnabled ? theme.foreground(.systemcolorsFgError) : theme.text(.textDisabled))
            }
            if hasInfo {
                Image(systemName: "info.circle").font(.system(size: 11))
                    .foregroundStyle(isEnabled ? theme.text(.textTertiary) : theme.text(.textDisabled))
            }
        }
    }

    private var textColor: Color {
        if hasError { return theme.foreground(.systemcolorsFgError) }
        if !isEnabled { return theme.text(.textDisabled) }
        return theme.text(.textPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InputLabel {
    /// Append a required asterisk after the label text.
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Show a trailing info glyph.
    func hasInfo(_ on: Bool = true) -> Self { copy { $0.hasInfo = on } }

    /// Render the label in the error color.
    func hasError(_ on: Bool = true) -> Self { copy { $0.hasError = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        InputLabel("Email")
        InputLabel("Password").required().hasInfo()
        InputLabel("Invalid").hasError()
    }
    .padding()
}
