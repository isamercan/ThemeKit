//
//  CouponChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 06.10.2026.
//
//  The styling door for `Coupon`'s chrome. Coupon keeps the behaviour — the
//  code and label, the copy action with its copied state (shown for 1.2s, then
//  reset) and `onCopy`, the accessibility words for the copy control, and the
//  motion. A `CouponChromeStyle` draws the rest: the shell, the label and code,
//  the icon, discount and expiry, and the control that copies.
//
//      PromoSection()
//          .couponChromeStyle(MyCouponChrome())   // every Coupon inside
//
//  While nobody sets a style, Coupon draws its built-in chrome exactly as
//  before. ``DefaultCouponChromeStyle`` (`.default`) draws that same look.
//
//  (`CouponStyle` is the older enum behind `.couponStyle(_:)` — filled /
//  outlined / plain; it stays, and a chrome reads it from the configuration.
//  `…ChromeStyle` keeps this protocol beside the other components' doors.)
//

import SwiftUI

/// The inputs a ``CouponChromeStyle`` renders: Coupon's raw content, its copy
/// action and state, and the axes the chrome keys off.
///
/// The strings arrive raw, not as pre-styled `Text`, so a style picks its own
/// type styles and colors. Fields a style doesn't use are simply ignored; new
/// fields may be added in a minor release.
public struct CouponChromeStyleConfiguration {
    /// The promo code passed to ``Coupon/init(code:label:onCopy:)``.
    public let code: String
    /// The label before or above the code — the caller's, else the localized
    /// "Promo code:".
    public let label: String
    /// ``Coupon/icon(_:)``: a leading SF Symbol name, when set.
    public let icon: String?
    /// ``Coupon/discount(_:)``: the discount chip's text, when set.
    public let discount: String?
    /// ``Coupon/expiry(_:)``: the expiry line, when set. The stock chrome draws
    /// it in the full-width layout only.
    public let expiry: String?
    /// The visual treatment (``Coupon/couponStyle(_:)``): filled, outlined
    /// (dashed) or plain.
    public let style: CouponStyle
    /// The size tier (``Coupon/size(_:)``).
    public let size: CouponSize
    /// Whether the full-width block layout is on (``Coupon/fullWidth(_:)``).
    public let isFullWidth: Bool
    /// Whether the code was just copied. Coupon turns it on in ``copy`` and off
    /// again 1.2 seconds later; a chrome only draws the state.
    public let isCopied: Bool
    /// Copies the code: Coupon sets ``isCopied`` and runs the caller's
    /// `onCopy`. A chrome's copy control calls it.
    public let copy: () -> Void
    /// The copy control's VoiceOver label, localized: "Copy code", or "Copied"
    /// while ``isCopied``.
    public let copyAccessibilityLabel: String
    /// The copied-state animation, resolved by Coupon (`microAnimations` ∧
    /// ¬Reduce Motion); `nil` when motion is off. Use it for state changes and
    /// never read the motion environment yourself.
    public let animation: Animation?
}

/// Draws a ``Coupon``. Set one with `.couponChromeStyle(_:)` on a coupon or an
/// ancestor; it reaches every coupon in the subtree.
///
///     struct TicketCouponChrome: CouponChromeStyle {
///         func makeBody(configuration: CouponChromeStyleConfiguration) -> some View {
///             HStack {
///                 VStack(alignment: .leading) {
///                     Text(configuration.label).textStyle(.bodySm400)
///                     Text(configuration.code).textStyle(.labelBase600)
///                 }
///                 Spacer()
///                 Button(configuration.isCopied ? "Copied" : "Copy", action: configuration.copy)
///                     .accessibilityLabel(configuration.copyAccessibilityLabel)
///             }
///             .padding(12)
///         }
///     }
public protocol CouponChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CouponChromeStyleConfiguration) -> Body
}

/// The stock chrome — the look Coupon draws when no style is set: the filled,
/// outlined (dashed) or plain shell, the inline row or the full-width block,
/// the SF Symbol icon, the discount chip, the expiry line and the copy glyph.
/// Reads the active `\.theme`, so an injected theme re-skins it too.
public struct DefaultCouponChromeStyle: CouponChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: CouponChromeStyleConfiguration) -> some View {
        DefaultCouponChrome(configuration: configuration)
    }
}

/// Coupon's built-in body, drawn on both paths — with no style set and with
/// `.default` — so the two can't drift apart.
struct DefaultCouponChrome: View {
    let configuration: CouponChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        Group { if configuration.isFullWidth { blockBody } else { inlineBody } }
            .foregroundStyle(foreground)
            .background(background, in: shape)
            .overlay { if configuration.style == .outlined { dashedBorder } }
    }

    private var inlineBody: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let icon = configuration.icon { Image(systemName: icon).font(.system(size: 13)).accessibilityHidden(true) }
            Text(configuration.label).textStyle(.bodySm400)
            Text(configuration.code).textStyle(configuration.size.codeStyle)
            copyButton
            if let discount = configuration.discount { discountChip(discount) }
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: configuration.size.height)
    }

    private var blockBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let icon = configuration.icon { Image(systemName: icon).font(.system(size: 13)).accessibilityHidden(true) }
                Text(configuration.label).textStyle(.bodySm400).foregroundStyle(labelColor)
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let discount = configuration.discount { discountChip(discount) }
            }
            HStack {
                Text(configuration.code).textStyle(.headingXs)
                Spacer()
                copyButton
            }
            if let expiry = configuration.expiry {
                Text(expiry).textStyle(.bodySm400).foregroundStyle(labelColor)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copyButton: some View {
        Button(action: configuration.copy) {
            Image(systemName: configuration.isCopied ? "checkmark" : "doc.on.doc").font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.copyAccessibilityLabel)
    }

    private func discountChip(_ text: String) -> some View {
        Text(text)
            .textStyle(.overline500)
            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(theme.background(.systemcolorsBgSuccessLight), in: Capsule())
    }

    private var labelColor: Color {
        configuration.style == .filled ? theme.foreground(.fgSecondary).opacity(0.85) : theme.text(.textSecondary)
    }

    private var foreground: Color {
        configuration.style == .filled ? theme.foreground(.fgSecondary) : theme.text(.textHero)
    }

    private var background: Color {
        switch configuration.style {
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

public extension CouponChromeStyle where Self == DefaultCouponChromeStyle {
    /// The stock chrome — what `Coupon` draws with no style set.
    static var `default`: DefaultCouponChromeStyle { DefaultCouponChromeStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCouponChromeStyle: CouponChromeStyle {
    /// `true` only for the environment key's stock default below. Any style set
    /// with `.couponChromeStyle(_:)` — including `.default` — goes through
    /// `makeBody`; both draw the same ``DefaultCouponChrome``.
    let isDefault: Bool
    private let _makeBody: @MainActor (CouponChromeStyleConfiguration) -> AnyView
    init<S: CouponChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CouponChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CouponChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyCouponChromeStyle(DefaultCouponChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var couponChromeStyle: AnyCouponChromeStyle {
        get { self[CouponChromeStyleKey.self] }
        set { self[CouponChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CouponChromeStyle`` for `Coupon`s in this view and its descendants.
    func couponChromeStyle<S: CouponChromeStyle>(_ style: sending S) -> some View {
        environment(\.couponChromeStyle, AnyCouponChromeStyle(style))
    }
}
