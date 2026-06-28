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
    @Binding private var isOn: Bool
    private let size: ControlSize
    private let isEnabled: Bool
    private let isLoading: Bool
    private let onSystemImage: String?
    private let offSystemImage: String?
    private let accessibilityID: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        isOn: Binding<Bool>,
        size: ControlSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        onSystemImage: String? = nil,
        offSystemImage: String? = nil,
        accessibilityID: String? = nil
    ) {
        self._isOn = isOn
        self.size = size
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.onSystemImage = onSystemImage
        self.offSystemImage = offSystemImage
        self.accessibilityID = accessibilityID
    }

    private var trackWidth: CGFloat { size == .medium ? 40 : 32 }
    private var trackHeight: CGFloat { size == .medium ? 24 : 20 }
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
            .fill(Theme.shared.foreground(.fgSecondary))
            .frame(width: knobSize, height: knobSize)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.shared.foreground(.fgHero))
                } else if let glyph = isOn ? onSystemImage : offSystemImage {
                    Image(systemName: glyph)
                        .font(.system(size: knobSize * 0.55, weight: .bold))
                        .foregroundStyle(isOn ? Theme.shared.text(.textHero) : Theme.shared.text(.textTertiary))
                }
            }
    }

    private var track: Color {
        guard isEnabled else { return Theme.shared.background(.bgSecondary) }
        return isOn ? Theme.shared.background(.bgHero) : Theme.shared.background(.bgSecondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ThemeToggle(isOn: .constant(true))
        ThemeToggle(isOn: .constant(false))
        ThemeToggle(isOn: .constant(true), size: .small)
        ThemeToggle(isOn: .constant(true), onSystemImage: "checkmark", offSystemImage: "xmark")
        ThemeToggle(isOn: .constant(true), isLoading: true)
        ThemeToggle(isOn: .constant(true), isEnabled: false)
    }
    .padding()
}
