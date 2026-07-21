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

    // Appearance/state — mutated only through the modifiers below (R2).
    private var onSystemImage: String = "xmark"
    private var offSystemImage: String = "line.3.horizontal"
    private var size: CGFloat = 24
    private var rotate: Bool = true
    private var accessibilityID: String? = nil

    public init(isOn: Binding<Bool>) {   // R1
        self._isOn = isOn
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
        @State var a = false
        @State var b = true
        var body: some View {
            // Tappable in each cell — the swap animation shows one frame per state.
            PreviewMatrix("Swap") {
                PreviewCase("Menu / close (off)") { Swap(isOn: $a).symbols(on: "xmark", off: "line.3.horizontal") }
                PreviewCase("Sun / moon (on)") { Swap(isOn: $b).symbols(on: "moon.fill", off: "sun.max.fill") }
                PreviewCase("No rotation") { Swap(isOn: $a).rotate(false) }
            }
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Swap {
    /// The two SF Symbols swapped between: `on` (shown when toggled on) and `off`.
    func symbols(on onSystemImage: String, off offSystemImage: String) -> Self {
        copy { $0.onSystemImage = onSystemImage; $0.offSystemImage = offSystemImage }
    }

    /// Glyph point size.
    func size(_ s: CGFloat) -> Self { copy { $0.size = s } }

    /// Toggle the rotate-in/out transition between the two glyphs.
    func rotate(_ on: Bool = true) -> Self { copy { $0.rotate = on } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
