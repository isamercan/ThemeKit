//
//  ButtonChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The styling door for `ThemeButton`'s chrome. ThemeButton keeps the
//  behaviour — the tap guard while loading, haptics, focus, the accessibility
//  label / value / identifier — and the content model (title or `.label { }`
//  slot, prefix / suffix, icon-only glyph, spinner placement, `.loadingIndicator { }`).
//  A `ButtonChromeStyle` draws everything around the arranged label: padding,
//  frame, fill, border, shape, foreground and the focus ring.
//
//      Checkout()
//          .buttonChromeStyle(MyButtonChrome())   // every ThemeButton inside
//
//  While nobody sets a style, ThemeButton draws its built-in chrome exactly as
//  before. ``DefaultButtonChromeStyle`` (`.default`) draws that same look
//  through the door, so a custom chrome can hand some variants back to it.
//

import SwiftUI

/// The inputs a ``ButtonChromeStyle`` renders: ThemeButton's arranged label,
/// its raw title, and the resolved state and axes the chrome keys off.
public struct ButtonChromeStyleConfiguration {
    /// ThemeButton's arranged content, type-erased (mirrors
    /// `ButtonStyleConfiguration.label`): prefix ▸ title or `.label { }` slot ▸
    /// suffix, with the inline spinner on its edge; the single glyph of an
    /// icon-only button; the `init(action:label:)` content; or, while loading
    /// without ``ThemeButton/spinnerPlacement(_:)``, the loading indicator alone.
    ///
    /// Unpadded, unframed and untinted — the chrome applies padding, frame,
    /// `.foregroundStyle(_:)`, and `.tint(_:)` for the built-in spinner. Its
    /// text carries no font of its own: ThemeButton sets the size's text style
    /// around the chrome, so a `.font(_:)` the chrome applies here re-fonts the
    /// title (and any slot that inherits it).
    ///
    /// The SF Symbol shorthand (``ThemeButton/icon(leading:trailing:)``) is the
    /// exception: those glyphs arrive already sized for the button's size and
    /// density. A host that draws its own glyphs (an icon font, glyphs sized
    /// by its own ramp) hands them in through the ``ThemeButton/prefix(_:)``,
    /// ``ThemeButton/suffix(_:)`` or ``ThemeButton/label(_:)`` slots, which
    /// arrive exactly as written.
    public let label: AnyView
    /// The title passed to ``ThemeButton/init(_:action:)``; `nil` for a
    /// title-less or ``ThemeButton/init(action:label:)`` button. Lets a chrome
    /// compose its own text instead of using `label`.
    public let title: String?
    /// Whether the button is being pressed — the live `ButtonStyle` state.
    public let isPressed: Bool
    /// Whether the button is enabled (native `.disabled(_:)`); `false` draws
    /// the disabled chrome. ThemeButton already blocks the taps.
    public let isEnabled: Bool
    /// Whether ``ThemeButton/loading(_:)`` is on. ThemeButton already swaps
    /// the label (or adds the inline spinner) and ignores taps.
    public let isLoading: Bool
    /// Whether the button holds keyboard / hardware focus. The chrome draws
    /// the focus ring — ThemeButton draws none on this path.
    public let isFocused: Bool
    /// Whether the button renders as a square-footprint icon button
    /// (``ThemeButton/iconOnly(_:)``, or the `.circle` / `.square` shapes).
    public let isIconOnly: Bool
    /// Whether ``ThemeButton/fullWidth(_:)`` asked the button to stretch.
    public let isFullWidth: Bool
    /// The visual treatment: solid / soft / outline / ghost / link.
    public let variant: ButtonVariant
    /// The resolved semantic color: ``ThemeButton/color(_:)`` ?? the subtree
    /// ``ComponentDefaults`` accent ?? `.primary`.
    public let color: SemanticColor
    /// The corner treatment: rounded / pill / circle / square.
    public let shape: ButtonShape
    /// The resolved control size: ``ThemeButton/size(_:)`` ?? an enclosing
    /// sized ``ButtonGroup`` ?? `.medium`.
    public let size: ButtonSize
    /// The height / padding density: touch (`.regular`) or web (`.compact`).
    public let density: ButtonDensity
    /// Micro-animations resolved by ThemeButton (`microAnimations` ∧ ¬Reduce
    /// Motion) — gate press motion on this; never read the motion environment.
    public let isMotionEnabled: Bool

    /// This configuration with the live `ButtonStyle` inputs filled in.
    func pressing(_ isPressed: Bool, label: AnyView) -> Self {
        Self(
            label: label, title: title, isPressed: isPressed, isEnabled: isEnabled,
            isLoading: isLoading, isFocused: isFocused, isIconOnly: isIconOnly,
            isFullWidth: isFullWidth, variant: variant, color: color, shape: shape,
            size: size, density: density, isMotionEnabled: isMotionEnabled
        )
    }
}

/// Defines ``ThemeButton``'s chrome. Implement `makeBody` to wrap the
/// configuration's label with padding, frame, fill, border, shape, foreground
/// and a focus ring. Set one with `.buttonChromeStyle(_:)` on a button or any
/// ancestor; without one, ThemeButton draws its built-in chrome.
///
/// The style draws; ThemeButton keeps the rest. Taps are still guarded while
/// loading, haptics still fire, focus is still tracked, and the accessibility
/// label, value and identifier stay on the button. A chrome owns the whole
/// footprint, so it decides the height, padding, icon-only square and
/// full-width stretch from ``ButtonChromeStyleConfiguration/size``,
/// `density`, `isIconOnly` and `isFullWidth`.
///
/// The style reaches every ``ThemeButton`` in the subtree, including the ones
/// ThemeKit components compose (dialog, popconfirm and tour actions, banner
/// and result-view buttons, the icon-only circles in travel rows). The preset
/// buttons (``PrimaryButton`` and friends) don't use ThemeButton and keep
/// their own look.
///
///     struct TokenButtonChrome: ButtonChromeStyle {
///         func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
///             TokenButtonChromeBody(configuration: configuration)
///         }
///     }
///
///     private struct TokenButtonChromeBody: View {
///         let configuration: ButtonChromeStyleConfiguration
///         @Environment(\.theme) private var theme
///
///         var body: some View {
///             let fill = theme.resolve(configuration.color)
///             configuration.label
///                 .textStyle(.labelLg600)                      // re-fonts the title
///                 .foregroundStyle(fill.onSolid)
///                 .tint(fill.onSolid)                          // the built-in spinner
///                 .padding(.horizontal, Theme.SpacingKey.base.value)
///                 .frame(minHeight: 52)
///                 .frame(maxWidth: configuration.isFullWidth ? .infinity : nil)
///                 .background(configuration.isPressed ? fill.active : fill.solid,
///                             in: Capsule())
///                 .opacity(configuration.isEnabled ? 1 : 0.4)
///                 .overlay {
///                     Capsule().stroke(fill.accent, lineWidth: 2).padding(-3)
///                         .opacity(configuration.isFocused ? 1 : 0)
///                 }
///         }
///     }
public protocol ButtonChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ButtonChromeStyleConfiguration) -> Body
}

/// The stock chrome — the look ThemeButton draws when no style is set: the
/// variant × color fill from the resolved ``SemanticColor`` ladder, a
/// stronger fill and a gated 0.97 scale while pressed, the outline stroke, the
/// size × density footprint (scaled with Dynamic Type), the shape's corners and
/// an accent focus ring. Like the built-in chrome, it paints the whole label
/// with the variant's foreground but tints only the loading indicator, so a
/// tint-sensitive view in a slot looks the same on both paths. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct DefaultButtonChromeStyle: ButtonChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        DefaultButtonChrome(configuration: configuration)
    }
}

private struct DefaultButtonChrome: View {
    let configuration: ButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme
    /// The same Dynamic Type footprint scale ThemeButton's built-in chrome uses.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        let paint = ButtonChromePaint(
            theme: theme, color: configuration.color, variant: configuration.variant,
            shape: configuration.shape, isEnabled: configuration.isEnabled
        )
        let height = configuration.size.height(for: configuration.density) * typeScale
        let isIconOnly = configuration.isIconOnly
        let isPressed = configuration.isPressed
        let isMotionEnabled = configuration.isMotionEnabled
        configuration.label
            .frame(minWidth: isIconOnly ? height : nil, maxWidth: isIconOnly ? height : nil, minHeight: height)
            .frame(maxWidth: configuration.isFullWidth && !isIconOnly ? .infinity : nil)
            .padding(.horizontal, isIconOnly ? 0 : configuration.size.horizontalPadding(for: configuration.density))
            .foregroundStyle(paint.foreground)
            // Tints ThemeButton's loading indicator only, as the built-in
            // chrome does — not every tint-sensitive view in the label.
            .environment(\.buttonChromeIndicatorTint, paint.foreground)
            .contentShape(Rectangle())
            .background(isPressed ? paint.pressedBackground : paint.background, in: paint.shapeStyle)
            .overlay { if let stroke = paint.stroke { paint.shapeStyle.stroke(stroke, lineWidth: 1.5) } }
            .scaleEffect(isMotionEnabled && isPressed ? 0.97 : 1)
            .animation(isMotionEnabled ? Motion.instant.animation : nil, value: isPressed)
            // After the scale, like ThemeButton's own ring: it doesn't shrink on press.
            .overlay { paint.focusRing(isVisible: configuration.isFocused) }
    }
}

public extension ButtonChromeStyle where Self == DefaultButtonChromeStyle {
    /// The stock chrome — ThemeButton's built-in look, drawn through the style door.
    static var `default`: DefaultButtonChromeStyle { DefaultButtonChromeStyle() }
}

// MARK: - Shared stock paint + metrics

/// The built-in chrome's paint, shared by ThemeButton's own chrome and
/// ``DefaultButtonChromeStyle`` so the two can't drift apart.
struct ButtonChromePaint {
    let theme: Theme
    let color: SemanticColor
    let variant: ButtonVariant
    let shape: ButtonShape
    let isEnabled: Bool

    /// `color` resolved against the environment theme (ADR-0006).
    private var resolved: SemanticColor.Resolved { theme.resolve(color) }

    var foreground: Color {
        guard isEnabled else { return theme.text(.textDisabled) }
        switch variant {
        case .solid: return resolved.onSolid
        case .soft, .outline, .ghost, .link: return resolved.accent
        }
    }

    var background: Color {
        guard isEnabled else { return variant == .solid ? theme.background(.bgSecondary) : .clear }
        switch variant {
        case .solid: return resolved.solid
        case .soft: return resolved.soft
        case .outline, .ghost, .link: return .clear
        }
    }

    /// Pressed-state fill — the iOS analog of Ant's hover/active, sourced from the
    /// color's primitive ladder. Solid darkens (`active`), soft strengthens
    /// (`bgHover`), bordered/ghost wash in a faint tint (`bg`).
    var pressedBackground: Color {
        guard isEnabled else { return background }
        switch variant {
        case .solid: return color == .neutral ? background : resolved.active
        case .soft: return resolved.bgHover
        case .outline, .ghost, .link: return resolved.bg
        }
    }

    /// The outline variant's 1.5pt stroke; `nil` for the other variants.
    var stroke: Color? {
        variant == .outline ? (isEnabled ? resolved.border : theme.border(.borderPrimary)) : nil
    }

    var shapeStyle: ThemeAnyShape {
        switch shape {
        case .rounded: return ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous))
        case .square: return ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        case .pill, .circle: return ThemeAnyShape(Capsule())
        }
    }

    /// Visible focus ring drawn just outside the button on keyboard / hardware
    /// focus (Figma focus state · accessibility). Offset outward via negative
    /// padding so it reads as a ring, tinted with the button's own accent.
    func focusRing(isVisible: Bool) -> some View {
        shapeStyle
            .stroke(resolved.accent, lineWidth: 2)
            .padding(-3)
            .opacity(isVisible && isEnabled ? 1 : 0)
            .allowsHitTesting(false)
    }
}

/// Density-aware size resolution (regular touch ramp vs compact web ramp),
/// shared by ThemeButton and ``DefaultButtonChromeStyle``.
extension ButtonSize {
    func height(for density: ButtonDensity) -> CGFloat {
        density == .compact ? compactHeight : height
    }
    func horizontalPadding(for density: ButtonDensity) -> CGFloat {
        density == .compact ? compactHorizontalPadding : horizontalPadding
    }
    func textStyle(for density: ButtonDensity) -> TextStyle {
        density == .compact ? compactTextStyle : textStyle
    }
    func fontSize(for density: ButtonDensity) -> CGFloat {
        density == .compact ? compactFontSize : fontSize
    }
}

// MARK: - ButtonStyle bridge

/// Hands ThemeButton's chrome to the environment ``ButtonChromeStyle`` through
/// a real SwiftUI `ButtonStyle`, so `isPressed` is the live press state. Used
/// only on the custom-style path; the built-in chrome keeps `FillButtonStyle`.
struct ButtonChromeBridge: ButtonStyle {
    let style: AnyButtonChromeStyle
    /// Everything but the label and the press state, resolved by ThemeButton.
    let template: ButtonChromeStyleConfiguration

    func makeBody(configuration: Configuration) -> some View {
        style.makeBody(configuration: template.pressing(configuration.isPressed, label: AnyView(configuration.label)))
    }
}

// MARK: - Type erasure + environment plumbing

struct AnyButtonChromeStyle: ButtonChromeStyle {
    /// `true` only for the environment key's stock default below. While the
    /// environment still carries it, ThemeButton draws its built-in chrome
    /// (unchanged from before this door existed); any style set with
    /// `.buttonChromeStyle(_:)` — `.default` included — is unmarked and routes
    /// through `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (ButtonChromeStyleConfiguration) -> AnyView
    init<S: ButtonChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ButtonChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyButtonChromeStyle(DefaultButtonChromeStyle(), isDefault: true)
}

/// The tint ``DefaultButtonChromeStyle`` hands to ThemeButton's loading
/// indicator; `nil` everywhere else.
private struct ButtonChromeIndicatorTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var buttonChromeStyle: AnyButtonChromeStyle {
        get { self[ButtonChromeStyleKey.self] }
        set { self[ButtonChromeStyleKey.self] = newValue }
    }

    var buttonChromeIndicatorTint: Color? {
        get { self[ButtonChromeIndicatorTintKey.self] }
        set { self[ButtonChromeIndicatorTintKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ButtonChromeStyle`` for `ThemeButton`s in this view and its
    /// descendants — including the ThemeButtons inside ThemeKit components.
    func buttonChromeStyle<S: ButtonChromeStyle>(_ style: sending S) -> some View {
        environment(\.buttonChromeStyle, AnyButtonChromeStyle(style))
    }
}

// MARK: - Preview

/// A preview-only custom chrome: a capsule with a 2pt ring, painted from the
/// same resolved semantic color, to show a chrome owning the whole footprint.
private struct PreviewRingChrome: ButtonChromeStyle {
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        PreviewRingChromeBody(configuration: configuration)
    }
}

private struct PreviewRingChromeBody: View {
    let configuration: ButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let fill = theme.resolve(configuration.color)
        let side: CGFloat = 44
        configuration.label
            .textStyle(.labelLg600)
            .foregroundStyle(configuration.isEnabled ? fill.accent : theme.text(.textDisabled))
            .tint(fill.accent)
            .padding(.horizontal, configuration.isIconOnly ? 0 : Theme.SpacingKey.lg.value)
            .frame(minWidth: configuration.isIconOnly ? side : nil, minHeight: side)
            .frame(maxWidth: configuration.isFullWidth ? .infinity : nil)
            .background(configuration.isPressed ? fill.bgHover : fill.bg, in: Capsule())
            .overlay { Capsule().strokeBorder(fill.border, lineWidth: 2) }
            .overlay {
                Capsule().stroke(fill.accent, lineWidth: 2).padding(-3)
                    .opacity(configuration.isFocused ? 1 : 0)
            }
    }
}

#Preview("ButtonChromeStyle") {
    PreviewMatrix("ButtonChromeStyle") {
        PreviewCase("Built-in vs .default") {
            HStack {
                ThemeButton("Built-in") {}.color(.success)
                ThemeButton("Door") {}.color(.success).buttonChromeStyle(.default)
            }
        }
        PreviewCase("Custom chrome (subtree)") {
            VStack(spacing: 12) {
                ThemeButton("Continue") {}.icon(trailing: "arrow.right").fullWidth()
                HStack {
                    ThemeButton("Saving") {}.loading().spinnerPlacement(.leading)
                    ThemeButton { }.icon(leading: "heart").shape(.circle).color(.error)
                    ThemeButton("Off") {}.disabled(true)
                }
            }
            .buttonChromeStyle(PreviewRingChrome())
        }
    }
}
