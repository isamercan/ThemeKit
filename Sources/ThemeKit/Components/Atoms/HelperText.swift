//
//  HelperText.swift
//  ThemeKit
//  Created by İsa Mercan on 09.07.2026.
//

import SwiftUI

/// Atom. A muted helper/description line for form fields — the small print under
/// an input that explains what to enter (HeroUI Native "Description").
///
/// The caller supplies the string; the atom adds no copy of its own. Reads
/// `.disabled(_:)` from the environment and dims to the disabled text token.
///
///     HelperText("We'll never share your email.")
///     HelperText("Min. 8 characters").hasError(isInvalid)
///     HelperText("Optional hint").hidesOnError().hasError(isInvalid)
///
/// Accessibility: renders as plain text, so VoiceOver reads it naturally in
/// order. An owning field should either group it with the input via
/// `.accessibilityElement(children: .combine)` or surface the same string as
/// an `accessibilityHint` on the field itself.
public struct HelperText: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private let text: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var hasError = false
    private var hidesOnError = false
    private var accessibilityID: String? = nil

    public init(_ text: String) {   // R1 — content only
        self.text = text
    }

    public var body: some View {
        Group {
            if !(hasError && hidesOnError) {   // hidden so a field-error line can take its place
                Text(text)
                    .textStyle(.bodySm400)
                    .foregroundStyle(color)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
                    .transition(.opacity)
            }
        }
        .animation(motion, value: hasError)
    }

    private var color: Color {
        if !isEnabled { return theme.text(.textDisabled) }
        if hasError { return theme.foreground(.systemcolorsFgError) }
        return theme.text(.textSecondary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension HelperText {
    /// Render the helper text in the error color (maps HeroUI `isInvalid`).
    func hasError(_ on: Bool = true) -> Self { copy { $0.hasError = on } }

    /// Remove the helper text entirely while `hasError` is set, so a field-error
    /// line can take its place (maps HeroUI `hideOnInvalid`).
    func hidesOnError(_ on: Bool = true) -> Self { copy { $0.hidesOnError = on } }

    /// Namespaced accessibility identifier for UI tests
    /// (the text gets `"<id>.message"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HelperText("We'll never share your email.")
        HelperText("Min. 8 characters, one number.").hasError()
        HStack(spacing: 4) {
            Text("(hidden under error →)").textStyle(.bodySm400)
            HelperText("Optional hint").hidesOnError().hasError()
        }
        HelperText("Unavailable while the form is locked.").disabled(true)
    }
    .padding()
}

#Preview("Dark") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return VStack(alignment: .leading, spacing: 12) {
        HelperText("We'll never share your email.")
        HelperText("Min. 8 characters, one number.").hasError()
        HelperText("Unavailable while the form is locked.").disabled(true)
    }
    .padding()
    .background(dark.background(.bgBase))
    .theme(dark)
}
