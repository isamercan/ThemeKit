//
//  Coupon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Displays a promo code with a copy action. Styles: filled / outlined
//  (dashed) / plain.
//

import SwiftUI

public enum CouponStyle {
    case filled, outlined, plain
}

public struct Coupon: View {
    private let code: String
    private let label: String
    private let style: CouponStyle
    private let onCopy: () -> Void

    public init(code: String, label: String = "Kupon Kodu:", style: CouponStyle = .outlined, onCopy: @escaping () -> Void = {}) {
        self.code = code
        self.label = label
        self.style = style
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
        style == .filled ? Theme.shared.foreground(.fgSecondary) : Theme.shared.text(.textHero)
    }

    private var background: Color {
        switch style {
        case .filled: return Theme.shared.background(.bgHero)
        case .plain: return Theme.shared.background(.bgElevatorTertiary)
        case .outlined: return Theme.shared.background(.bgWhite)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
    }

    private var dashedBorder: some View {
        shape.strokeBorder(
            Theme.shared.border(.borderHero),
            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Coupon(code: "UXMUQ", style: .filled)
        Coupon(code: "UXMUQ", style: .outlined)
        Coupon(code: "UXMUQ", style: .plain)
    }
    .padding()
}
