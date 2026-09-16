//
//  BadgeChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `Badge`. The chrome — the text's
//  type style, the icon sizes, padding, height, fill, border, corner and lift —
//  lives in a `BadgeChromeStyle` you set with `.badgeChromeStyle(_:)`, so a host
//  design system can draw its own badge while `Badge` keeps the rest. (The name
//  carries "Chrome" because `BadgeStyle` already names the badge's tone enum.)
//
//      Badge("Sale").badgeStyle(.error)
//          .leading { HostGlyph(.tag) }
//          .badgeChromeStyle(HostBadgeChrome())
//
//  `Badge` keeps: the content model (text + leading/trailing slots or SF Symbol
//  shorthands), the tone / variant / size / shape / gradient axes, the action
//  button and its press feedback, and accessibility (on the style path the
//  badge reads as one VoiceOver element).
//

import SwiftUI

/// The inputs a ``BadgeChromeStyle`` renders: the badge's raw text, its
/// leading/trailing content, the appearance axes set on the badge, and its
/// resolved state.
///
/// `text` is the raw string, not a pre-styled `Text`, so a style picks its own
/// type style. Fields a style doesn't use are simply ignored; new fields may
/// be added in a minor release.
public struct BadgeChromeStyleConfiguration {
    /// The badge's label.
    public let text: String
    /// Content before the text: the `.leading { }` slot when set, else the
    /// `.icon(_:)` SF Symbol already sized for ``size``; `nil` when neither is set.
    public let leading: AnyView?
    /// Content after the text: the `.trailing { }` slot when set, else the
    /// `.trailingIcon(_:)` SF Symbol already sized for ``size``; `nil` when neither is set.
    public let trailing: AnyView?
    /// The SF Symbol name behind ``leading``, so a style can draw the symbol at
    /// its own size; `nil` when ``leading`` is a slot or absent.
    public let leadingSystemImage: String?
    /// The SF Symbol name behind ``trailing``, so a style can draw the symbol at
    /// its own size; `nil` when ``trailing`` is a slot or absent.
    public let trailingSystemImage: String?
    /// The badge's tone (`.badgeStyle(_:)`), the hue its chrome is painted in.
    public let tone: BadgeStyle
    /// The fill treatment (`.variant(_:)`).
    public let variant: FillVariant
    /// The size tier (`.size(_:)`).
    public let size: BadgeSize
    /// The outline (`.badgeShape(_:)`).
    public let shape: BadgeShape
    /// The semantic gradient set with `.gradient(_:)`; when non-nil the default
    /// style paints each hue's solid shade instead of the tone's fill.
    public let gradient: [SemanticColor]?
    /// Whether `.highlighted()` asked for the lifted look.
    public let isHighlighted: Bool
    /// Whether the badge is enabled (`.disabled(_:)` in the environment).
    public let isEnabled: Bool
    /// Whether the badge's action is being pressed. Always `false` for a badge
    /// with no action. The component already applies its press feedback
    /// (motion-gated), so a style only uses this for extra pressed chrome.
    public let isPressed: Bool

    // Deprecated raw-color escape hatches (`badgeColor(_:)`,
    // `gradient(_: [Color]?)`), carried so ``DefaultBadgeChromeStyle`` paints
    // exactly what the component's default path paints. Not public: custom
    // styles take their colors from tokens.
    let legacyForeground: Color?
    let legacyGradient: [Color]?
}

extension BadgeChromeStyleConfiguration {
    /// The paint the stock chrome resolves for this configuration.
    var paint: BadgePaint {
        BadgePaint(tone: tone, variant: variant, gradient: gradient,
                   legacyForeground: legacyForeground, legacyGradient: legacyGradient)
    }

    /// A copy carrying the state resolved where the chrome is drawn.
    func resolving(isEnabled: Bool, isPressed: Bool) -> Self {
        BadgeChromeStyleConfiguration(
            text: text, leading: leading, trailing: trailing,
            leadingSystemImage: leadingSystemImage, trailingSystemImage: trailingSystemImage,
            tone: tone, variant: variant, size: size, shape: shape, gradient: gradient,
            isHighlighted: isHighlighted, isEnabled: isEnabled, isPressed: isPressed,
            legacyForeground: legacyForeground, legacyGradient: legacyGradient)
    }
}

/// Draws a badge's chrome. Implement `makeBody` to lay out the configuration's
/// leading content, text and trailing content and paint the surface around
/// them. Set one with `.badgeChromeStyle(_:)`; the default is
/// ``DefaultBadgeChromeStyle``.
///
/// The style draws; `Badge` keeps the behaviour. It wraps the style's body in
/// its action button (with the kit's press feedback) and, with no action,
/// combines the body into one VoiceOver element.
///
/// The style applies to every `Badge` below the view it's set on, including
/// the badges ThemeKit composes inside other components (list rows, price
/// tags, cards, the travel edition's rows). Set it on the badge itself to
/// restyle only that badge.
///
/// ```swift
/// struct TagBadgeChrome: BadgeChromeStyle {
///     func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
///         TagBadgeChromeBody(configuration: configuration)
///     }
/// }
///
/// private struct TagBadgeChromeBody: View {
///     let configuration: BadgeChromeStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         let tone = theme.resolve(configuration.tone.semantic)
///         HStack(spacing: Theme.SpacingKey.xs.value) {
///             configuration.leading
///             Text(configuration.text).textStyle(.bodySm500).lineLimit(1)
///             configuration.trailing
///         }
///         .foregroundStyle(configuration.isEnabled ? tone.accent : theme.text(.textDisabled))
///         .padding(.horizontal, Theme.SpacingKey.sm.value)
///         .padding(.vertical, Theme.SpacingKey.xs.value)
///         .background(tone.soft, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value))
///     }
/// }
/// ```
public protocol BadgeChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: BadgeChromeStyleConfiguration) -> Body
}

/// The stock badge chrome — exactly the look `Badge` draws with no style set:
/// the size tier's label type, icon sizes, padding and fixed height; the
/// tone × variant fill, foreground and 1pt border (or the semantic gradient);
/// a capsule or selector-radius corner; and a soft shadow when highlighted.
/// It ignores `isEnabled` and `isPressed` (the component's press feedback is the
/// only pressed look). Reads the active `\.theme`, so an injected theme
/// re-skins it too.
public struct DefaultBadgeChromeStyle: BadgeChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        DefaultBadgeChrome(configuration: configuration)
    }
}

private struct DefaultBadgeChrome: View {
    let configuration: BadgeChromeStyleConfiguration
    @Environment(\.theme) private var theme

    // Mirrors `Badge`'s default path modifier for modifier, so
    // `.badgeChromeStyle(.default)` renders the same pixels.
    var body: some View {
        let paint = configuration.paint
        let shape = configuration.shape.chromeShape
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leading = configuration.leading {
                leading
            }
            Text(configuration.text).textStyle(configuration.size.textStyle)
            if let trailing = configuration.trailing {
                trailing
            }
        }
        .foregroundStyle(paint.foreground(theme))
        .padding(.horizontal, configuration.size.horizontalPadding)
        .frame(height: configuration.size.height)
        .background(paint.background(theme), in: shape)
        .overlay(shape.stroke(paint.border(theme), lineWidth: 1))
        .modifier(BadgeHighlight(on: configuration.isHighlighted))
    }
}

public extension BadgeChromeStyle where Self == DefaultBadgeChromeStyle {
    /// The stock badge chrome (today's `Badge` look).
    static var `default`: DefaultBadgeChromeStyle { DefaultBadgeChromeStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyBadgeChromeStyle: BadgeChromeStyle {
    /// `true` only for the environment key's stock default below. `Badge`
    /// checks it: while the environment still carries the default it draws its
    /// own chrome, unchanged; any style set with `.badgeChromeStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (BadgeChromeStyleConfiguration) -> AnyView
    init<S: BadgeChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct BadgeChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyBadgeChromeStyle(DefaultBadgeChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var badgeChromeStyle: AnyBadgeChromeStyle {
        get { self[BadgeChromeStyleKey.self] }
        set { self[BadgeChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``BadgeChromeStyle`` for `Badge`s in this view and its descendants.
    func badgeChromeStyle<S: BadgeChromeStyle>(_ style: sending S) -> some View {
        environment(\.badgeChromeStyle, AnyBadgeChromeStyle(style))
    }
}
