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

    @Binding private var isOn: Bool
    @Environment(\.controlSize) private var controlSize
    private let isEnabled: Bool
    private let isLoading: Bool
    private let onSystemImage: String?
    private let offSystemImage: String?
    private var accessibilityID: String? = nil

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        onSystemImage: String? = nil,
        offSystemImage: String? = nil
    ) {
        self._isOn = isOn
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.onSystemImage = onSystemImage
        self.offSystemImage = offSystemImage
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
        ThemeToggle(isOn: .constant(true), onSystemImage: "checkmark", offSystemImage: "xmark")
        ThemeToggle(isOn: .constant(true), isLoading: true)
        ThemeToggle(isOn: .constant(true), isEnabled: false)
    }
    .padding()
}

public extension ThemeToggle {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
