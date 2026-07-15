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
    private var infoAction: (() -> Void)?
    private var links: [(substring: String, action: () -> Void)] = []
    private var tooltipText: String?
    private var tooltipEdge: TooltipEdge = .top
    private var tooltipMaxWidth: CGFloat? = 220

    private let text: String

    public init(_ text: String) {   // R1
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 4) {
            Group {
                if links.isEmpty {
                    Text(text).textStyle(.labelSm600).foregroundStyle(textColor)
                } else {
                    InlineText(text, links: links).inlineStyle(.labelSm600).color(textColor)
                }
            }
            if isRequired {
                Text("*").textStyle(.labelSm600)
                    .foregroundStyle(isEnabled ? theme.foreground(.systemcolorsFgError) : theme.text(.textDisabled))
            }
            if hasInfo || infoAction != nil || tooltipText != nil {
                infoAffordance
            }
        }
    }

    // The trailing info affordance. A `tooltip(_:)` turns the glyph into a
    // tap-to-reveal tooltip trigger; otherwise `onInfo(_:)` makes it a plain
    // tap target; otherwise it's a static hint glyph. (If both a tooltip and an
    // info action are attached, the tooltip wins.)
    @ViewBuilder private var infoAffordance: some View {
        if let tooltipText, isEnabled {
            infoGlyph.tooltip(tooltipText, edge: tooltipEdge, maxWidth: tooltipMaxWidth)
        } else if let infoAction {
            // Tappable info glyph — captured via `onInfo(_:)`. Plain button
            // style so it doesn't tint; disabled state handled natively by the
            // `.disabled(_:)` environment (R5).
            Button(action: infoAction) { infoGlyph }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Info"))
        } else {
            infoGlyph
        }
    }

    private var infoGlyph: some View {
        Image(systemName: "info.circle").font(.system(size: 11))
            .foregroundStyle(isEnabled ? theme.text(.textTertiary) : theme.text(.textDisabled))
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

    /// Turn substrings of the label into inline tappable links (rendered via
    /// `InlineText`) — e.g. a labeled consent with a linked policy name.
    func links(_ links: [(substring: String, action: () -> Void)]) -> Self { copy { $0.links = links } }

    /// Show a trailing info glyph.
    func hasInfo(_ on: Bool = true) -> Self { copy { $0.hasInfo = on } }

    /// Make the trailing info glyph tappable, capturing the tap via `action`
    /// (e.g. to present a tooltip or help sheet). Implies `hasInfo()` — the
    /// glyph shows whenever an action is attached. Pass `nil` to clear.
    func onInfo(_ action: (() -> Void)?) -> Self { copy { $0.infoAction = action } }

    /// Attach a tooltip to the trailing info glyph, turning it into a
    /// tap-to-reveal target that shows `text` for secondary context (the HeroUI
    /// Label "show tooltip" affordance). Implies `hasInfo()`. An alternative to
    /// `onInfo(_:)` — if both are attached the tooltip wins. Pass `maxWidth: nil`
    /// to keep the bubble on a single line.
    func tooltip(_ text: String, edge: TooltipEdge = .top, maxWidth: CGFloat? = 220) -> Self {
        copy { $0.hasInfo = true; $0.tooltipText = text; $0.tooltipEdge = edge; $0.tooltipMaxWidth = maxWidth }
    }

    /// Render the label in the error color.
    func hasError(_ on: Bool = true) -> Self { copy { $0.hasError = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("InputLabel") {
        PreviewCase("Default") { InputLabel("Email") }
        PreviewCase("Required + info") { InputLabel("Password").required().hasInfo() }
        PreviewCase("Tappable info") { InputLabel("Coverage").onInfo { print("info tapped") } }
        PreviewCase("Tooltip") { InputLabel("Your name").required().tooltip("Shown on your public profile.") }
        PreviewCase("Error") { InputLabel("Invalid").hasError() }
        PreviewCase("Linked") { InputLabel("Agree to the Terms").links([("Terms", {})]) }
        PreviewCase("Disabled") { InputLabel("Disabled").disabled(true) }
        PreviewCase("Disabled required") { InputLabel("Disabled required").required().hasInfo().disabled(true) }
        PreviewCase("Disabled error") { InputLabel("Disabled error").hasError().disabled(true) }
    }
}
