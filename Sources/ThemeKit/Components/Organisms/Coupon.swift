//
//  Coupon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  CardStyle exception: the dashed-border coupon shell (and its filled/plain
//  variants) is the component's identity, so it does not route through `CardStyle`;
//  it has its own door instead — `CouponChromeStyle` (CouponChromeStyle.swift).
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
///
/// The chrome is drawn by the active ``CouponChromeStyle`` when one is set with
/// `.couponChromeStyle(_:)` on the coupon or an ancestor; the coupon keeps the
/// copy action, its copied state and the accessibility words either way.
public struct Coupon: View {
    @Environment(\.couponChromeStyle) private var chromeStyle
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: CouponStyle = .outlined
    private var size: CouponSize = .medium
    private var icon: String?
    private var discount: String?
    private var expiry: String?
    private var isBlock = false

    private let code: String
    private let labelOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var label: String { labelOverride ?? String(themeKit: "Promo code:") }
    private let onCopy: () -> Void

    public init(code: String, label: String? = nil, onCopy: @escaping () -> Void = {}) {   // R1
        self.code = code
        self.labelOverride = label
        self.onCopy = onCopy
    }

    public var body: some View {
        if chromeStyle.isDefault {
            DefaultCouponChrome(configuration: configuration)
        } else {
            chromeStyle.makeBody(configuration: configuration)
        }
    }

    private var configuration: CouponChromeStyleConfiguration {
        CouponChromeStyleConfiguration(
            code: code,
            label: label,
            icon: icon,
            discount: discount,
            expiry: expiry,
            style: style,
            size: size,
            isFullWidth: isBlock,
            isCopied: copied,
            copy: copy,
            copyAccessibilityLabel: copied ? String(themeKit: "Copied") : String(themeKit: "Copy code"),
            animation: MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
        )
    }

    private func copy() {
        copied = true
        onCopy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
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
