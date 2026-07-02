//
//  Spinner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Indeterminate circular loading indicator (token-tinted).
public struct Spinner: View {
    @Environment(\.theme) private var theme

    // Appearance/config — mutated only through the modifiers below (R2).
    private var size: CGFloat = 24
    private var lineWidth: CGFloat = 3
    private var color: Color?

    @State private var rotating = false

    public init() {}   // R1

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                (color ?? theme.foreground(.fgHero)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Spinner {
    /// Diameter in points (default 24).
    func size(_ points: CGFloat) -> Self { copy { $0.size = points } }

    /// Stroke thickness in points (default 3).
    func lineWidth(_ width: CGFloat) -> Self { copy { $0.lineWidth = width } }

    /// Tint color; `nil` (default) uses the theme's hero foreground.
    func color(_ c: Color?) -> Self { copy { $0.color = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    HStack(spacing: 24) {
        Spinner().size(16).lineWidth(2)
        Spinner()
        Spinner().size(40).lineWidth(4)
    }
    .padding()
}
