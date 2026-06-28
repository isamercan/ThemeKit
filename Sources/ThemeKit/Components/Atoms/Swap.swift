//
//  Swap.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Animated toggle between two SF Symbols (e.g. menu↔close, sun↔moon).
/// (daisyUI "Swap".)
public struct Swap: View {
    @Environment(\.theme) private var theme

    @Binding private var isOn: Bool
    private let onSystemImage: String
    private let offSystemImage: String
    private let size: CGFloat
    private let rotate: Bool
    private var accessibilityID: String? = nil

    public init(isOn: Binding<Bool>, on onSystemImage: String, off offSystemImage: String, size: CGFloat = 24, rotate: Bool = true) {
        self._isOn = isOn
        self.onSystemImage = onSystemImage
        self.offSystemImage = offSystemImage
        self.size = size
        self.rotate = rotate
    }

    public var body: some View {
        Button {
            withAnimation(Motion.fast.animation) { isOn.toggle() }
        } label: {
            ZStack {
                glyph(offSystemImage, visible: !isOn, angle: rotate ? -90 : 0)
                glyph(onSystemImage, visible: isOn, angle: rotate ? 90 : 0)
            }
            .frame(width: size + 16, height: size + 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(isOn ? String(themeKit: "on") : String(themeKit: "off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func glyph(_ name: String, visible: Bool, angle: Double) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(theme.text(.textPrimary))
            .opacity(visible ? 1 : 0)
            .rotationEffect(.degrees(visible ? 0 : angle))
            .scaleEffect(visible ? 1 : 0.6)
    }
}

#Preview {
    struct Demo: View {
        @State private var a = false
        @State private var b = true
        var body: some View {
            HStack(spacing: 32) {
                Swap(isOn: $a, on: "xmark", off: "line.3.horizontal")
                Swap(isOn: $b, on: "moon.fill", off: "sun.max.fill")
            }
            .padding()
        }
    }
    return Demo()
}

public extension Swap {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
