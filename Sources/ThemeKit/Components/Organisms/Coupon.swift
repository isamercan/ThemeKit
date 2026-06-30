//
//  Coupon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum CouponStyle {
    case filled, outlined, plain
}

/// Organism. Displays a promo code with a copy action. Styles: filled / outlined
/// (dashed) / plain.
public struct Coupon: View {
    @Environment(\.theme) private var theme

    // Appearance — mutated only through the modifiers below (R2).
    private var style: CouponStyle = .outlined

    private let code: String
    private let label: String
    private let onCopy: () -> Void

    public init(code: String, label: String = "Kupon Kodu:", onCopy: @escaping () -> Void = {}) {   // R1
        self.code = code
        self.label = label
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(label)
                .textStyle(.bodySm400)
            Text(code)
                .textStyle(.labelSm700)
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc").font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: 36)
        .background(background, in: shape)
        .overlay { if style == .outlined { dashedBorder } }
    }

    private var foreground: Color {
        style == .filled ? theme.foreground(.fgSecondary) : theme.text(.textHero)
    }

    private var background: Color {
        switch style {
        case .filled: return theme.background(.bgHero)
        case .plain: return theme.background(.bgElevatorTertiary)
        case .outlined: return theme.background(.bgWhite)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
    }

    private var dashedBorder: some View {
        shape.strokeBorder(
            theme.border(.borderHero),
            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Coupon {
    /// Visual treatment: filled / outlined (dashed) / plain.
    func couponStyle(_ s: CouponStyle) -> Self { copy { $0.style = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Coupon(code: "UXMUQ").couponStyle(.filled)
        Coupon(code: "UXMUQ").couponStyle(.outlined)
        Coupon(code: "UXMUQ").couponStyle(.plain)
    }
    .padding()
}
