//
//  Badge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum BadgeStyle: String, CaseIterable {
    case neutral, info, success, warning, error
    case pink, orange, turquoise, purple

    func background(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgSecondaryLight)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        case .pink: return theme.background(.badgeBgMaximumpinkLight)
        case .orange: return theme.background(.badgeBgOrange)
        case .turquoise: return theme.background(.badgeBgTurquoiseLight)
        case .purple: return theme.background(.badgeBgPurple)
        }
    }

    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.text(.textSecondary)
        case .info: return theme.foreground(.systemcolorsFgInfo)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error: return theme.foreground(.systemcolorsFgError)
        case .pink: return theme.foreground(.badgeFgMaximumpink)
        case .orange: return theme.foreground(.badgeFgOrange)
        case .turquoise: return theme.foreground(.badgeFgTurquoise)
        case .purple: return theme.text(.textPurple)
        }
    }

    func border(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.border(.borderPrimary)
        case .info: return theme.border(.systemcolorsBorderInfoLight)
        case .success: return theme.border(.systemcolorsBorderSuccessLight)
        case .warning: return theme.border(.systemcolorsBorderWarningLight)
        case .error: return theme.border(.systemcolorsBorderErrorLight)
        case .pink, .orange, .turquoise, .purple: return .clear
        }
    }

    /// The tone's semantic hue — resolve it through the environment theme
    /// (`theme.resolve(tone.semantic)`) to paint a custom ``BadgeChromeStyle``
    /// with the palette the built-in chrome uses.
    public var semantic: SemanticColor {
        switch self {
        case .neutral: return .neutral
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .pink: return .pink
        case .orange: return .orange
        case .turquoise: return .turquoise
        case .purple: return .purple
        }
    }
}

public enum BadgeSize {
    case small, medium, large, xlarge

    var height: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        case .xlarge: return 44
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .small, .medium: return Theme.SpacingKey.sm.value   // 8
        case .large, .xlarge: return Theme.SpacingKey.md.value   // 16
        }
    }
    var textStyle: TextStyle {
        switch self {
        case .small, .medium: return .labelSm600
        case .large: return .labelBase600
        case .xlarge: return .labelMd600
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .xlarge: return 18
        }
    }
}

public enum BadgeShape {
    case pill
    case rounded
}

/// Improved, token-bound rewrite of the reference BadgeView. Styling is driven
/// by a semantic `BadgeStyle` (system + brand variants) instead of
/// component-specific color lookups, and icons use SF Symbols or the
/// `.leading { }` / `.trailing { }` slots.
///
/// The chrome is drawn by the active ``BadgeChromeStyle`` when one is set with
/// `.badgeChromeStyle(_:)` on the badge or an ancestor; the badge keeps its
/// content, axes, action and accessibility either way.
public struct Badge: View {
    @Environment(\.theme) private var theme
    @Environment(\.badgeChromeStyle) private var chromeStyle

    private let text: String
    private let action: (() -> Void)?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: BadgeStyle = .neutral
    private var variant: FillVariant = .soft
    private var size: BadgeSize = .medium
    private var leadingSystemImage: String?
    private var shape: BadgeShape = .pill
    private var trailingSystemImage: String?
    private var textColor: Color?
    // ADR-0006: stored as `SemanticColor` (not a resolved `Color`) so the
    // gradient is re-resolved from the environment theme in `body`, honoring
    // per-subtree `.theme(_:)`; `rawGradient` is the raw-`Color` escape hatch
    // (deprecated `gradient(_: [Color]?)`), which has no theme to resolve.
    private var semanticGradient: [SemanticColor]?
    private var rawGradient: [Color]?
    private var highlighted: Bool = false
    private var leadingSlot: SlotContent?
    private var trailingSlot: SlotContent?

    public init(_ text: String, action: (() -> Void)? = nil) {   // R1 — content + action
        self.text = text
        self.action = action
    }

    public var body: some View {
        if chromeStyle.isDefault {
            if let action {
                Button(action: action) { content }.buttonStyle(PressFeedbackStyle())
            } else {
                content
            }
        } else if let action {
            // The style draws; the badge keeps its button and press feedback.
            Button(action: action) { styledChrome(tracksPress: true) }.buttonStyle(BadgeChromePressStyle())
        } else {
            styledChrome(tracksPress: false).accessibilityElement(children: .combine)
        }
    }

    private var content: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSlot {
                leadingSlot
            } else if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: size.iconSize))
            }
            Text(text).textStyle(size.textStyle)
            if let trailingSlot {
                trailingSlot
            } else if let trailingSystemImage {
                Image(systemName: trailingSystemImage).font(.system(size: size.iconSize))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .background(backgroundStyle, in: shapeStyle)
        .overlay(shapeStyle.stroke(border, lineWidth: 1))
        .modifier(BadgeHighlight(on: highlighted))
    }

    // Paint and outline resolve through the helpers `DefaultBadgeChromeStyle`
    // shares, so `.badgeChromeStyle(.default)` can't drift from this path.
    private var paint: BadgePaint {
        BadgePaint(tone: style, variant: variant, gradient: semanticGradient,
                   legacyForeground: textColor, legacyGradient: rawGradient)
    }
    private var foreground: Color { paint.foreground(theme) }
    private var backgroundStyle: AnyShapeStyle { paint.background(theme) }
    private var border: Color { paint.border(theme) }
    private var shapeStyle: ThemeAnyShape { shape.chromeShape }

    // MARK: Style path

    private func styledChrome(tracksPress: Bool) -> some View {
        BadgeChromeHost(style: chromeStyle, configuration: chromeConfiguration, tracksPress: tracksPress)
    }

    /// The configuration before the state resolved inside the button
    /// (`BadgeChromeHost` fills `isEnabled` / `isPressed`). A set slot replaces
    /// that side's SF Symbol shorthand, as on the default path.
    private var chromeConfiguration: BadgeChromeStyleConfiguration {
        BadgeChromeStyleConfiguration(
            text: text,
            leading: leadingSlot.map { AnyView($0) } ?? leadingSystemImage.map { AnyView(symbol($0)) },
            trailing: trailingSlot.map { AnyView($0) } ?? trailingSystemImage.map { AnyView(symbol($0)) },
            leadingSystemImage: leadingSlot == nil ? leadingSystemImage : nil,
            trailingSystemImage: trailingSlot == nil ? trailingSystemImage : nil,
            tone: style,
            variant: variant,
            size: size,
            shape: shape,
            gradient: semanticGradient,
            isHighlighted: highlighted,
            isEnabled: true,
            isPressed: false,
            legacyForeground: textColor,
            legacyGradient: rawGradient)
    }

    private func symbol(_ systemName: String) -> some View {
        Image(systemName: systemName).font(.system(size: size.iconSize))
    }
}

/// Renders the environment style inside the badge's button, where the
/// pressed flag and the enabled state are readable. A badge without an action
/// ignores the flag, so a plain badge inside a pressed badge's slot stays
/// unpressed.
private struct BadgeChromeHost: View {
    let style: AnyBadgeChromeStyle
    let configuration: BadgeChromeStyleConfiguration
    let tracksPress: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.badgeChromeIsPressed) private var isPressed

    var body: some View {
        style.makeBody(configuration: configuration.resolving(
            isEnabled: isEnabled,
            isPressed: tracksPress && isPressed))
    }
}

/// The badge's press feedback on the style path: the kit's
/// ``PressFeedbackStyle`` (motion-gated), plus the pressed flag handed down to
/// the style's configuration.
private struct BadgeChromePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressFeedbackStyle().makeBody(configuration: configuration)
            .environment(\.badgeChromeIsPressed, configuration.isPressed)
    }
}

private struct BadgeChromePressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var badgeChromeIsPressed: Bool {
        get { self[BadgeChromePressedKey.self] }
        set { self[BadgeChromePressedKey.self] = newValue }
    }
}

/// The fill, foreground and border a badge paints for a tone × variant (or a
/// gradient). Shared by `Badge`'s default path and ``DefaultBadgeChromeStyle``.
struct BadgePaint {
    let tone: BadgeStyle
    let variant: FillVariant
    let gradient: [SemanticColor]?
    let legacyForeground: Color?
    let legacyGradient: [Color]?

    func foreground(_ theme: Theme) -> Color {
        if let legacyForeground { return legacyForeground }
        switch variant {
        case .soft: return tone.foreground(theme)
        case .solid: return theme.resolve(tone.semantic).onSolid
        case .outline, .ghost: return theme.resolve(tone.semantic).accent
        }
    }

    func background(_ theme: Theme) -> AnyShapeStyle {
        if let gradient {
            let colors = gradient.map { theme.resolve($0).solid }
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        }
        if let legacyGradient {
            return AnyShapeStyle(LinearGradient(colors: legacyGradient, startPoint: .leading, endPoint: .trailing))
        }
        switch variant {
        case .soft: return AnyShapeStyle(tone.background(theme))
        case .solid: return AnyShapeStyle(theme.resolve(tone.semantic).solid)
        case .outline, .ghost: return AnyShapeStyle(Color.clear)
        }
    }

    func border(_ theme: Theme) -> Color {
        switch variant {
        case .soft: return tone.border(theme)
        case .solid: return .clear
        case .outline: return theme.resolve(tone.semantic).border
        case .ghost: return .clear
        }
    }
}

extension BadgeShape {
    /// The outline the stock chrome fills and strokes.
    var chromeShape: ThemeAnyShape {
        switch self {
        case .pill: return ThemeAnyShape(Capsule())
        case .rounded: return ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Badge {
    /// Semantic style (system + brand variants) driving fill/foreground/border
    /// (renamed from the bare `style:` to avoid the generic clash + match `BadgeStyle`).
    func badgeStyle(_ s: BadgeStyle) -> Self { copy { $0.style = s } }
    /// Fill treatment: soft / solid / outline / ghost.
    func variant(_ v: FillVariant) -> Self { copy { $0.variant = v } }
    /// Size tier: small / medium / large / xlarge.
    func size(_ s: BadgeSize) -> Self { copy { $0.size = s } }
    /// Leading SF Symbol before the text (the Figma "Prefix" slot). A
    /// ``leading(_:)`` slot, when set, replaces it.
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }
    /// Leading and/or trailing SF Symbols in one call — the Figma "Prefix" and
    /// "Suffix" slots. Mirrors `ThemeButton.icon(leading:trailing:)`; pass `nil`
    /// to clear either side (e.g. `.icon(leading: "star.fill", trailing: "xmark")`).
    func icon(leading: String? = nil, trailing: String? = nil) -> Self {
        copy { $0.leadingSystemImage = leading; $0.trailingSystemImage = trailing }
    }
    /// A trailing SF Symbol after the text — the Figma "Suffix" slot (e.g. a
    /// dismiss `xmark` or a chevron). Also settable via `icon(leading:trailing:)`.
    func trailingIcon(_ systemName: String?) -> Self { copy { $0.trailingSystemImage = systemName } }
    /// Pill (default) or rounded-rectangle outline.
    func badgeShape(_ shape: BadgeShape) -> Self { copy { $0.shape = shape } }
    /// Overrides the text/foreground color (otherwise derived from style + variant).
    @available(*, deprecated, message: "Use badgeStyle(_:) with a semantic BadgeStyle (plus variant(_:)) instead of a raw color.")
    func badgeColor(_ color: Color?) -> Self { copy { $0.textColor = color } }
    /// Fills the badge with a horizontal gradient of semantic tokens (each
    /// hue's solid shade) instead of the style background; `nil` restores it.
    func gradient(_ colors: [SemanticColor]?) -> Self { copy { $0.semanticGradient = colors; $0.rawGradient = nil } }
    /// Raw-color gradient (back-compat); prefer the token-bound overload.
    /// Disfavored so member-shorthand literals like `[.purple, .pink]` —
    /// valid as both `[Color]` and `[SemanticColor]` — resolve to the token
    /// overload instead of being ambiguous.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use gradient(_: [SemanticColor]?) — the token-bound overload.")
    func gradient(_ colors: [Color]?) -> Self { copy { $0.rawGradient = colors; $0.semanticGradient = nil } }
    /// Lifts the badge off the surface with a subtle drop shadow.
    func highlighted(_ on: Bool = true) -> Self { copy { $0.highlighted = on } }
    /// A custom view before the text (a host glyph, a flag, a counter); when
    /// set, it replaces the ``icon(_:)`` shorthand. It inherits the badge's
    /// foreground.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingSlot = SlotContent(content) }
    }
    /// A custom view after the text; when set, it replaces the
    /// ``trailingIcon(_:)`` shorthand. It inherits the badge's foreground.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingSlot = SlotContent(content) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

struct BadgeHighlight: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on {
            content.themeShadow(.soft)
        } else {
            content
        }
    }
}

#Preview {
    /// Proof of external implementability: a host-shaped chrome with its own
    /// type style, padding and corner. The hue still comes from the badge's tone.
    struct SquareBadgeChrome: BadgeChromeStyle {
        func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
            SquareBadgeChromeBody(configuration: configuration)
        }
    }
    struct SquareBadgeChromeBody: View {
        let configuration: BadgeChromeStyleConfiguration
        @Environment(\.theme) private var theme

        var body: some View {
            let tone = theme.resolve(configuration.tone.semantic)
            HStack(spacing: Theme.SpacingKey.xs.value) {
                configuration.leading
                Text(configuration.text).textStyle(.bodySm500).lineLimit(1)
                configuration.trailing
            }
            .foregroundStyle(configuration.isEnabled ? tone.accent : theme.text(.textDisabled))
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(configuration.isPressed ? tone.bgHover : tone.soft,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        }
    }

    return PreviewMatrix("Badge") {
        for style in BadgeStyle.allCases {
            PreviewCase(style.rawValue.capitalized) {
                Badge(style.rawValue.capitalized).badgeStyle(style).icon("star.fill")
            }
        }
        PreviewCase("Sizes + rounded") {
            HStack {
                Badge("Small").badgeStyle(.info).size(.small)
                Badge("Medium").badgeStyle(.info).size(.medium)
                Badge("Large").badgeStyle(.info).size(.large)
                Badge("Rounded").badgeStyle(.success).badgeShape(.rounded)
            }
        }
        PreviewCase("Variants") {
            HStack {
                Badge("Solid").badgeStyle(.error).variant(.solid)
                Badge("Outline").badgeStyle(.info).variant(.outline)
                Badge("Ghost").badgeStyle(.success).variant(.ghost)
            }
        }
        // Prefix + Suffix slots (Figma): leading, trailing, or both.
        PreviewCase("Prefix + Suffix icons") {
            HStack {
                Badge("Prefix").badgeStyle(.info).icon("star.fill")
                Badge("Suffix").badgeStyle(.info).trailingIcon("xmark")
                Badge("Both").badgeStyle(.purple).icon(leading: "sparkles", trailing: "chevron.right")
            }
        }
        // G5 — token gradient twin (solid shades of semantic hues); `.solid`
        // variant keeps the on-solid foreground over the gradient fill.
        PreviewCase("Gradient (solid)") {
            HStack {
                Badge("Pro").gradient([.purple, .pink]).variant(.solid)
                Badge("Deal").gradient([.primary, .turquoise]).variant(.solid)
            }
        }
        PreviewCase("Long text") {
            Badge("a-rather-long-badge-label").badgeStyle(.warning)
        }
        // Slots replace that side's SF Symbol shorthand and inherit the foreground.
        PreviewCase("Leading / trailing slots") {
            HStack {
                Badge("Live").badgeStyle(.success).leading { Circle().frame(width: 6, height: 6) }
                Badge("Inbox").badgeStyle(.info).icon("tray.fill").trailing { Text("12").textStyle(.labelSm700) }
            }
        }
        // A custom BadgeChromeStyle set once on the container.
        PreviewCase("Custom chrome style") {
            HStack {
                Badge("Tag").badgeStyle(.info).icon("tag.fill")
                Badge("Action", action: {}).badgeStyle(.success).trailing { Image(systemName: "chevron.right") }
                Badge("Disabled").badgeStyle(.error).disabled(true)
            }
            .badgeChromeStyle(SquareBadgeChrome())
        }
    }
}
