//
//  ThemeToggle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Figma "Control Items" → Switch Toggles. Sizes Medium (40×24) / Small (32×20);
/// states active / disabled / loading, with optional on/off glyphs in the knob.
/// (Ant Switch parity.) Colors + motion from theme tokens.
public struct ThemeToggle: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var isLoading = false
    private var onSystemImage: String?
    private var offSystemImage: String?
    private var trackOnSymbol: String?
    private var trackOffSymbol: String?
    private var customThumb: ((Bool) -> AnyView)?
    private var accent: SemanticColor?
    private var accessibilityID: String? = nil

    @Binding private var isOn: Bool
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(isOn: Binding<Bool>) {   // R1
        self._isOn = isOn
    }

    private var isCompact: Bool { controlSize == .mini || controlSize == .small }
    private var trackWidth: CGFloat { isCompact ? 32 : 40 }
    private var trackHeight: CGFloat { isCompact ? 20 : 24 }
    private var knobSize: CGFloat { trackHeight - 4 }
    private var interactive: Bool { isEnabled && !isLoading }

    public var body: some View {
        Button {
            withAnimation(motion) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(track)
                .frame(width: trackWidth, height: trackHeight)
                .overlay(trackSymbol)   // under the knob so it never overlaps it mid-slide
                .overlay(
                    knob
                        .padding(2)
                        .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                )
        }
        .buttonStyle(PressFeedbackStyle())   // subtle press scale, gated by microAnimations + Reduce Motion
        .disabled(!interactive)
        .opacity(isEnabled ? 1 : 0.6)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(isOn ? String(themeKit: "on") : String(themeKit: "off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Knob content precedence: loading spinner > custom `thumbContent` > `symbols` glyph.
    private var knob: some View {
        Circle()
            .fill(theme.foreground(.fgSecondary))
            .frame(width: knobSize, height: knobSize)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(theme.foreground(.fgHero))
                } else if let customThumb {
                    customThumb(isOn)
                        .frame(width: knobSize, height: knobSize)
                        .clipShape(Circle())
                } else if let glyph = isOn ? onSystemImage : offSystemImage {
                    Image(systemName: glyph)
                        .font(.system(size: knobSize * 0.55, weight: .bold))
                        .foregroundStyle(isOn ? theme.text(.textHero) : theme.text(.textTertiary))
                }
            }
    }

    /// On-track glyph rendered on the side the knob vacated (HeroUI
    /// `Switch.StartContent` / `Switch.EndContent` parity): on-symbol at the
    /// leading edge while on, off-symbol at the trailing edge while off.
    @ViewBuilder private var trackSymbol: some View {
        if let glyph = isOn ? trackOnSymbol : trackOffSymbol {
            Image(systemName: glyph)
                .font(.system(size: knobSize * 0.55, weight: .bold))
                .foregroundStyle(trackSymbolColor)
                .frame(width: knobSize, height: knobSize)   // centered in the knob-sized vacated zone
                .padding(2)
                .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
                .transition(.opacity)
                .id(glyph)   // crossfade between on/off glyphs under the file's motion
        }
    }

    /// Contrast-correct color for the visible track glyph: it sits on `track`,
    /// which is the accent/hero solid only when on **and** enabled, otherwise
    /// the secondary background.
    private var trackSymbolColor: Color {
        guard isOn, isEnabled else { return theme.text(.textTertiary) }
        return accent?.onSolid ?? theme.text(.textHero)
    }

    private var track: Color {
        guard isEnabled else { return theme.background(.bgSecondary) }
        guard isOn else { return theme.background(.bgSecondary) }
        return accent?.solid ?? theme.background(.bgHero)
    }
}

#Preview {
    @Previewable @State var live = true   // interactive rows: slide + press-scale feedback
    VStack(alignment: .leading, spacing: 16) {
        ThemeToggle(isOn: .constant(true))
        ThemeToggle(isOn: .constant(false))
        ThemeToggle(isOn: .constant(true)).controlSize(.small)
        ThemeToggle(isOn: .constant(true)).symbols(on: "checkmark", off: "xmark")
        ThemeToggle(isOn: .constant(true)).loading()
        ThemeToggle(isOn: .constant(true)).disabled(true)
        ThemeToggle(isOn: .constant(true)).accent(.success)
        ThemeToggle(isOn: .constant(true)).accent(.error).controlSize(.small)
        // Track symbols (HeroUI start/end content) — tap to see the crossfade + press scale.
        ThemeToggle(isOn: $live).trackSymbols(on: "sun.max.fill", off: "moon.fill")
        ThemeToggle(isOn: .constant(false)).trackSymbols(on: "sun.max.fill", off: "moon.fill")
        ThemeToggle(isOn: .constant(true)).trackSymbols(on: "sun.max.fill", off: "moon.fill").disabled(true)
        ThemeToggle(isOn: .constant(true)).trackSymbols(on: "checkmark").accent(.success).controlSize(.small)
        // Custom thumb content (HeroUI Switch.Thumb children); spinner still wins while loading.
        ThemeToggle(isOn: $live).thumbContent { on in
            Image(systemName: on ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 10, weight: .bold))
        }
        ThemeToggle(isOn: .constant(true)).thumbContent { _ in Text("A").font(.system(size: 10, weight: .bold)) }.loading()
    }
    .padding()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ThemeToggle {
    /// Swap the knob for a spinner and block interaction while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Optional SF Symbols shown inside the knob for the on / off states.
    func symbols(on: String? = nil, off: String? = nil) -> Self {
        copy { $0.onSystemImage = on; $0.offSystemImage = off }
    }

    /// Optional SF Symbols shown inside the *track*, on the side opposite the
    /// knob — the on-symbol while on, the off-symbol while off (HeroUI
    /// `Switch.StartContent`/`EndContent`). Distinct from `symbols(on:off:)`,
    /// which decorates the knob itself; both may be combined.
    func trackSymbols(on: String? = nil, off: String? = nil) -> Self {
        copy { $0.trackOnSymbol = on; $0.trackOffSymbol = off }
    }

    /// Custom view rendered inside the knob (receives `isOn`), replacing the
    /// `symbols(on:off:)` glyph (HeroUI `Switch.Thumb` children). The loading
    /// spinner keeps priority: spinner > `thumbContent` > `symbols`.
    func thumbContent<C: View>(@ViewBuilder _ content: @escaping (Bool) -> C) -> Self {
        copy { $0.customThumb = { AnyView(content($0)) } }
    }

    /// Semantic tint for the on-state track; `nil` (default) uses the hero
    /// background token. (daisyUI `toggle-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
