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
                .overlay(
                    knob
                        .padding(2)
                        .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                )
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
        .opacity(isEnabled ? 1 : 0.6)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(isOn ? String(themeKit: "on") : String(themeKit: "off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var knob: some View {
        Circle()
            .fill(theme.foreground(.fgSecondary))
            .frame(width: knobSize, height: knobSize)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(theme.foreground(.fgHero))
                } else if let glyph = isOn ? onSystemImage : offSystemImage {
                    Image(systemName: glyph)
                        .font(.system(size: knobSize * 0.55, weight: .bold))
                        .foregroundStyle(isOn ? theme.text(.textHero) : theme.text(.textTertiary))
                }
            }
    }

    private var track: Color {
        guard isEnabled else { return theme.background(.bgSecondary) }
        return isOn ? theme.background(.bgHero) : theme.background(.bgSecondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ThemeToggle(isOn: .constant(true))
        ThemeToggle(isOn: .constant(false))
        ThemeToggle(isOn: .constant(true)).controlSize(.small)
        ThemeToggle(isOn: .constant(true)).symbols(on: "checkmark", off: "xmark")
        ThemeToggle(isOn: .constant(true)).loading()
        ThemeToggle(isOn: .constant(true)).disabled(true)
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

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
