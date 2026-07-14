//
//  DescriptionModal.swift
//  ThemeKit
//  Created by İsa Mercan on 13.07.2026.
//

import SwiftUI

/// Atom. A swappable, muted body-text block for modal content (HeroUI
/// "DescriptionModal"). It's the paragraph that explains what a dialog is asking
/// — a single content slot you drop into a modal's body without detaching the
/// modal itself.
///
/// The caller supplies the string; the atom adds no copy of its own. Text wraps
/// to as many lines as it needs and the block grows to fit — there is no clamp
/// unless you add one with the native `.lineLimit(_:)`.
///
///     DescriptionModal("Delete this trip? This can't be undone.")
///     DescriptionModal(longParagraph).textAlignment(.center)
///
/// Styling is fixed to the HeroUI spec: `Body sm` (14/20) in the muted
/// foreground token, so it reads as secondary copy beneath the modal title.
/// For the small print *under a form field* use ``HelperText`` instead; for a
/// field label use ``InputLabel``.
///
/// Accessibility: renders as plain `Text`, so VoiceOver reads it naturally in
/// order. An owning modal should group it with its title via
/// `.accessibilityElement(children: .combine)` where appropriate.
public struct DescriptionModal: View {
    @Environment(\.theme) private var theme

    private let text: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var alignment: TextAlignment = .leading
    private var accessibilityID: String? = nil

    public init(_ text: String) {   // R1 — content only
        self.text = text
    }

    public var body: some View {
        Text(text)
            .textStyle(.bodySm400)
            .foregroundStyle(theme.text(.textSecondary))   // HeroUI foreground/muted
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .a11y(A11yElement.Field.message, in: accessibilityID)
    }

    /// Maps the text alignment onto the enclosing frame so a centred paragraph
    /// also centres within the modal, and RTL flips leading/trailing for free.
    private var frameAlignment: Alignment {
        switch alignment {
        case .center:   return .center
        case .trailing: return .trailing
        case .leading:  return .leading
        @unknown default: return .leading
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DescriptionModal {
    /// Align the wrapped body text (default `.leading`, which mirrors under RTL).
    /// Use `.center` for confirmation-style dialogs.
    func textAlignment(_ alignment: TextAlignment) -> Self { copy { $0.alignment = alignment } }

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
    VStack(alignment: .leading, spacing: 20) {
        DescriptionModal("Lorem ipsum dolor sit amet consectetur. Ultrices nunc commodo dictumst fermentum.")
        DescriptionModal("California is a state in the Western United States that lies on the Pacific Coast. With almost 40 million residents across an area of 163,696 square miles.")
        DescriptionModal("Centred confirmation copy sits under the dialog title.")
            .textAlignment(.center)
    }
    .padding()
    .frame(width: 320)
}

#Preview("Dark") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return VStack(alignment: .leading, spacing: 20) {
        DescriptionModal("Lorem ipsum dolor sit amet consectetur. Ultrices nunc commodo dictumst fermentum.")
        DescriptionModal("Delete this trip? This action can't be undone and any unsaved changes will be lost.")
    }
    .padding()
    .frame(width: 320)
    .background(dark.background(.bgBase))
    .theme(dark)
}
