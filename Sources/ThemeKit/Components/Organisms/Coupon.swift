//
//  Coupon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  CardStyle exception: the dashed-border coupon shell (and its filled/plain
//  variants) is the component's identity, so it does not route through `CardStyle`.
//

import SwiftUI

public enum CouponStyle {
    case filled, outlined, plain
}

/// Size tier of a ``Coupon`` — inline height / code weight.
public enum CouponSize {
    case small, medium, large
    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 36
        case .large: return 44
        }
    }
    var codeStyle: TextStyle {
        switch self {
        case .small: return .labelSm700
        case .medium: return .labelSm700
        case .large: return .labelBase700
        }
    }
}

/// Organism. Displays a promo code with a copy action. Styles: filled / outlined
/// (dashed) / plain. Flexible: a leading icon, a discount chip, an expiry line, a
/// size tier, a full-width block layout, and copied-state feedback.
public struct Coupon: View {
    @Environment(\.theme) private var theme
    @State private var copied = false

    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: CouponStyle = .outlined
    private var size: CouponSize = .medium
    private var icon: String?
    private var discount: String?
    private var expiry: String?
    private var isBlock = false

    private let code: String
    private let label: String
    private let onCopy: () -> Void

    public init(code: String, label: String = String(themeKit: "Promo code:"), onCopy: @escaping () -> Void = {}) {   // R1
        self.code = code
        self.label = label
        self.onCopy = onCopy
    }

    public var body: some View {
        Group { if isBlock { blockBody } else { inlineBody } }
            .foregroundStyle(foreground)
            .background(background, in: shape)
            .overlay { if style == .outlined { dashedBorder } }
    }

    private var inlineBody: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let icon { Image(systemName: icon).font(.system(size: 13)).accessibilityHidden(true) }
            Text(label).textStyle(.bodySm400)
            Text(code).textStyle(size.codeStyle)
            copyButton
            if let discount { discountChip(discount) }
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: size.height)
    }

    private var blockBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let icon { Image(systemName: icon).font(.system(size: 13)).accessibilityHidden(true) }
                Text(label).textStyle(.bodySm400).foregroundStyle(labelColor)
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let discount { discountChip(discount) }
            }
            HStack {
                Text(code).textStyle(.headingXs)
                Spacer()
                copyButton
            }
            if let expiry {
                Text(expiry).textStyle(.bodySm400).foregroundStyle(labelColor)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copyButton: some View {
        Button {
            copied = true
            onCopy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copied ? String(themeKit: "Copied") : String(themeKit: "Copy code"))
    }

    private func discountChip(_ text: String) -> some View {
        Text(text)
            .textStyle(.overline500)
            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(theme.background(.systemcolorsBgSuccessLight), in: Capsule())
    }

    private var labelColor: Color {
        style == .filled ? theme.foreground(.fgSecondary).opacity(0.85) : theme.text(.textSecondary)
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
    /// Size tier: small / medium / large.
    func size(_ s: CouponSize) -> Self { copy { $0.size = s } }
    /// A leading SF Symbol, e.g. "tag.fill".
    func icon(_ systemName: String?) -> Self { copy { $0.icon = systemName } }
    /// A trailing discount chip, e.g. "20% OFF".
    func discount(_ text: String?) -> Self { copy { $0.discount = text } }
    /// An expiry line under the code (block layout only), e.g. "Valid until Dec 31".
    func expiry(_ text: String?) -> Self { copy { $0.expiry = text } }
    /// Full-width block layout: label above, large code + copy below, optional expiry.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isBlock = on } }
    /// Full-width block layout: label above, large code + copy below, optional expiry.
    @available(*, deprecated, renamed: "fullWidth")
    func block(_ on: Bool = true) -> Self { fullWidth(on) }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Coupon") {
        PreviewCase("Filled") {
            Coupon(code: "UXMUQ").couponStyle(.filled)
        }
        PreviewCase("Outlined (dashed)") {
            Coupon(code: "UXMUQ").couponStyle(.outlined)
        }
        PreviewCase("Plain") {
            Coupon(code: "UXMUQ").couponStyle(.plain)
        }
        PreviewCase("Full width · icon + discount + expiry") {
            Coupon(code: "SUMMER20")
                .icon("tag.fill")
                .discount("20% OFF")
                .expiry("Valid until Dec 31")
                .fullWidth()
        }
    }
}
