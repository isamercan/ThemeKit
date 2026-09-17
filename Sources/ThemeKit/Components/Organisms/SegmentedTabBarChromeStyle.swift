//
//  SegmentedTabBarChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 17.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for one `SegmentedTabBar` tab. A
//  tab's chrome — the label's type style and colour, the glyph, the caption
//  and badge, padding, the selected fill and the selection indicator — lives
//  in a `SegmentedTabBarChromeStyle` you set with
//  `.segmentedTabBarChromeStyle(_:)`, so a host design system can draw its own
//  tabs while the bar keeps the rest. (The name carries "Chrome" because
//  `SegmentedTabBarStyle` already names the bar's underline / card / pill enum.)
//
//      SegmentedTabBar([TabItem("Flights").leading { HostGlyph(.plane) },
//                       TabItem("Hotels").leading { HostGlyph(.bed) }], selection: $tab)
//          .fillsWidth(false)
//          .baseline()
//          .segmentedTabBarChromeStyle(HostTabChrome())
//
//  `SegmentedTabBar` keeps: each tab's button and the selection it writes
//  (under the resolved motion), the selected trait, the tab's VoiceOver label,
//  the bar's identifier and value, scroll-to-selection, the content pane, and
//  the bar around the tabs — the `.pill` track, the `.card` add button, the
//  `.dividers()` hairlines and the `.baseline()` rule.
//

import SwiftUI

/// The inputs a ``SegmentedTabBarChromeStyle`` renders: **one** tab's content,
/// the axes set on the bar, that tab's resolved state, and the geometry
/// namespace a sliding selection indicator needs.
///
/// The strings arrive raw, not as pre-styled `Text`, so a style picks its own
/// type style and colours. Fields a style doesn't use are simply ignored; new
/// fields may be added in a minor release.
public struct SegmentedTabBarChromeStyleConfiguration {
    /// The tab's title.
    public let title: String
    /// The second line under the title (`TabItem(caption:)`); `nil` when unset.
    /// The stock `.underline` tab is the only one that draws it.
    public let caption: String?
    /// The tab's badge text (`TabItem(badge:)`); `nil` when unset.
    public let badge: String?
    /// Content before the title: the tab's ``TabItem/leading(_:)`` slot when
    /// set (exactly as written), else the `TabItem(systemImage:)` SF Symbol,
    /// already sized for ``tabStyle`` and ``size``. `nil` when neither is set.
    public let leading: AnyView?
    /// The SF Symbol name behind ``leading``, so a style can draw the symbol at
    /// its own size; `nil` when ``leading`` is a slot or absent.
    public let systemImage: String?
    /// The `TabItem(trailingSystemImage:)` name, for a glyph after the title;
    /// `nil` when unset. The stock `.underline` tab is the only one that draws it.
    public let trailingSystemImage: String?
    /// Whether this tab is the selected one.
    public let isSelected: Bool
    /// Whether the tab can be selected: its `TabItem(isEnabled:)` and the
    /// environment's `.disabled(_:)` together. The bar already blocks the taps.
    public let isEnabled: Bool
    /// Whether the tab is being pressed — the live `ButtonStyle` state. The
    /// bar's button adds no press effect of its own on this path, so a style
    /// draws whatever pressed look it wants.
    public let isPressed: Bool
    /// The bar's visual treatment (`.tabStyle(_:)`). It also says what the bar
    /// draws around the tabs: a `.pill` bar keeps its boxed track, a `.card`
    /// bar its add button.
    public let tabStyle: SegmentedTabBarStyle
    /// The density tier (`.size(_:)`).
    public let size: SegmentedTabBarSize
    /// The environment's control size (`.controlSize(_:)`), for a style with a
    /// second size ramp. The stock style ignores it — the bar has ``size``.
    public let controlSize: ControlSize
    /// Whether the bar scrolls horizontally: `.scrollable()` is on, or the bar
    /// uses `.card` (which always scrolls).
    public let isScrollable: Bool
    /// `.fillsWidth(_:)` as it was set. With it off the bar hugs its tabs from
    /// the leading edge and puts **no** space between them — a style's own
    /// padding sets the gap. See ``isStretched`` for the resolved rule.
    public let fillsWidth: Bool
    /// The geometry namespace of this bar's selection indicator. Pair it with
    /// ``indicatorID`` in `matchedGeometryEffect(id:in:)` on the shape you draw
    /// only while ``isSelected`` is true, and the indicator slides from tab to
    /// tab under ``animation``. Derive further ids from ``indicatorID`` (for
    /// example `"\(configuration.indicatorID).fill"`) to slide more than one.
    public let indicatorNamespace: Namespace.ID
    /// The geometry id of this bar's selection indicator; see ``indicatorNamespace``.
    public let indicatorID: String
    /// The animation the bar writes the selection with, already resolved
    /// (`nil` under `.microAnimations(false)` or Reduce Motion), so a style
    /// never reads the motion settings itself.
    public let animation: Animation?
    /// The stock close (×) button of a closable `.card` tab, wired to the bar's
    /// `onClose:` handler; `nil` for any other tab. It renders inside the tab's
    /// button, so it's hidden from VoiceOver — the bar gives the tab a
    /// "Close …" accessibility action instead.
    public let closeButton: AnyView?
    /// This tab's close handler, for a style that draws its own close button
    /// (give it a VoiceOver label); `nil` when the tab isn't closable.
    public let onClose: (() -> Void)?

    /// `TabItem(isEnabled:)` on its own, without the environment's
    /// `.disabled(_:)`. Internal: it exists so ``DefaultSegmentedTabBarChromeStyle``
    /// can paint exactly what the built-in path paints (which greys out a
    /// disabled *item* but only fades a disabled *bar*). Custom styles use
    /// ``isEnabled``.
    let isItemEnabled: Bool
}

public extension SegmentedTabBarChromeStyleConfiguration {
    /// Whether the bar gives this tab an equal share of its width:
    /// ``fillsWidth`` is on and the bar doesn't scroll. When it's `true` a
    /// style stretches its chrome into the share with
    /// `.frame(maxWidth: .infinity)`; when it's `false` the tab hugs its content.
    var isStretched: Bool { fillsWidth && !isScrollable }
}

extension SegmentedTabBarChromeStyleConfiguration {
    /// A copy carrying the state resolved inside the tab's button.
    func resolving(isEnabled: Bool, isPressed: Bool) -> Self {
        SegmentedTabBarChromeStyleConfiguration(
            title: title, caption: caption, badge: badge, leading: leading,
            systemImage: systemImage, trailingSystemImage: trailingSystemImage,
            isSelected: isSelected, isEnabled: isEnabled, isPressed: isPressed,
            tabStyle: tabStyle, size: size, controlSize: controlSize,
            isScrollable: isScrollable, fillsWidth: fillsWidth,
            indicatorNamespace: indicatorNamespace, indicatorID: indicatorID,
            animation: animation, closeButton: closeButton, onClose: onClose,
            isItemEnabled: isItemEnabled)
    }

    /// The glyph point size the stock tab uses at this density.
    var glyphPoints: CGFloat { size.iconPoints(base: tabStyle == .underline ? 14 : 13) }

    /// Whether the bar hugs its tabs with no spacing between them.
    var hugsContent: Bool { !fillsWidth && tabStyle != .card }
}

/// Draws one tab of a `SegmentedTabBar`. Implement `makeBody` to lay out the
/// configuration's leading content, title, caption and badge, paint the
/// surface around them and — while ``SegmentedTabBarChromeStyleConfiguration/isSelected``
/// is true — draw the selection indicator. Set one with
/// `.segmentedTabBarChromeStyle(_:)`; the default is
/// ``DefaultSegmentedTabBarChromeStyle``.
///
/// The style draws; `SegmentedTabBar` keeps the behaviour. It wraps the style's
/// body in the tab's button (so `isPressed` is live and the selection is
/// written under the resolved `animation`), adds the selected trait and the
/// tab's VoiceOver label, keeps the bar's identifier and value, scrolls the
/// selected tab into view, and still draws what sits around the tabs: the
/// `.pill` track, the `.card` add button, `.dividers()` and `.baseline()`.
///
/// **The style owns the indicator.** On this path the bar draws neither its
/// underline nor its pill fill: draw your own while `isSelected` is true, and
/// give it `matchedGeometryEffect(id: configuration.indicatorID, in:
/// configuration.indicatorNamespace)` to make it slide between tabs.
///
/// **What reaches the style.** One body draws every tab the bar can hold: a
/// tab with a caption, a badge, a leading glyph or a trailing symbol, a
/// disabled one, the selected one, a stretched tab (``SegmentedTabBarChromeStyleConfiguration/isStretched``)
/// and a content-hugging one, and — in a closable `.card` bar — one carrying
/// ``SegmentedTabBarChromeStyleConfiguration/closeButton``.
///
/// ```swift
/// struct HostTabChrome: SegmentedTabBarChromeStyle {
///     func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
///         HostTabChromeBody(configuration: configuration)
///     }
/// }
///
/// private struct HostTabChromeBody: View {
///     let configuration: SegmentedTabBarChromeStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         HStack(spacing: Theme.SpacingKey.xs.value) {
///             configuration.leading
///             Text(configuration.title).textStyle(.labelBase600).lineLimit(1)
///         }
///         .foregroundStyle(configuration.isSelected ? theme.text(.textHero) : theme.text(.textSecondary))
///         .padding(.horizontal, Theme.SpacingKey.md.value)
///         .padding(.vertical, Theme.SpacingKey.sm.value)
///         // An overlay keeps the indicator out of the tab's width: a flexible
///         // shape stacked *beside* the label would stretch the tab in a
///         // scrolling or content-hugging bar.
///         .overlay(alignment: .bottom) {
///             if configuration.isSelected {
///                 Capsule().fill(theme.background(.bgHero)).frame(height: 3)
///                     .matchedGeometryEffect(id: configuration.indicatorID,
///                                            in: configuration.indicatorNamespace)
///             }
///         }
///         .frame(maxWidth: configuration.isStretched ? .infinity : nil)
///         .opacity(configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
///         .contentShape(Rectangle())
///     }
/// }
/// ```
public protocol SegmentedTabBarChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> Body
}

/// The stock tab — exactly what `SegmentedTabBar` draws with no style set, for
/// each of the three treatments: the underline tab with its caption, trailing
/// glyph and sliding 2 pt rule; the boxed pill with its sliding fill; and the
/// bordered card with its close button. Like the built-in path's plain button
/// it dims a pressed tab to 75% and halves a disabled one. Reads the active
/// `\.theme`, so an injected theme re-skins it too.
public struct DefaultSegmentedTabBarChromeStyle: SegmentedTabBarChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        DefaultSegmentedTabChrome(configuration: configuration)
    }
}

/// Mirrors `SegmentedTabBar`'s built-in tabs. `SegmentedTabBarChromeStyleTests`
/// renders both and compares the pixels, so the two can't drift apart unnoticed.
private struct DefaultSegmentedTabChrome: View {
    let configuration: SegmentedTabBarChromeStyleConfiguration
    @Environment(\.theme) private var theme

    private var size: SegmentedTabBarSize { configuration.size }
    private var isActive: Bool { configuration.isSelected }

    /// The built-in path's `.buttonStyle(.plain)` dims a pressed label to 75%
    /// and halves a disabled one; the style path's bridge adds neither, so the
    /// stock chrome does both.
    private var fade: Double { configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5 }

    var body: some View {
        switch configuration.tabStyle {
        case .underline: underlineTab
        case .pill: pillTab
        case .card: cardTab
        }
    }

    // MARK: Treatments

    private var underlineTab: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            VStack(spacing: 1) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    glyph
                    Text(configuration.title).textStyle(size.titleStyle(isSelected: isActive))
                    if let trailing = configuration.trailingSystemImage {
                        Image(systemName: trailing).font(.system(size: 13, weight: .semibold))
                    }
                    if let badge = configuration.badge {
                        SegmentedTabBadge(text: badge)
                    }
                }
                if let caption = configuration.caption {
                    Text(caption).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, configuration.hugsContent ? size.tabHorizontalPadding : 0)

            ZStack {
                Capsule().fill(Color.clear).frame(height: 2)
                if isActive {
                    Capsule()
                        .fill(theme.border(.borderHero))
                        .frame(height: 2)
                        .matchedGeometryEffect(id: configuration.indicatorID, in: configuration.indicatorNamespace)
                }
            }
        }
        .contentShape(Rectangle())
        .opacity(fade)
    }

    private var pillTab: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            glyph
            Text(configuration.title).textStyle(size.titleStyle(isSelected: isActive))
            if let badge = configuration.badge {
                SegmentedTabBadge(text: badge)
            }
        }
        .foregroundStyle(configuration.isItemEnabled
                         ? (isActive ? theme.foreground(.fgSecondary) : theme.text(.textSecondary))
                         : theme.text(.textDisabled))
        .padding(.horizontal, size.tabHorizontalPadding)
        .padding(.vertical, size.tabVerticalPadding)
        .frame(maxWidth: configuration.isStretched ? .infinity : nil)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .fill(theme.background(.bgHero))
                    .matchedGeometryEffect(id: configuration.indicatorID, in: configuration.indicatorNamespace)
            }
        }
        .contentShape(Rectangle())
        .opacity(fade)
    }

    private var cardTab: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                glyph
                Text(configuration.title).textStyle(size.titleStyle(isSelected: isActive))
                if let badge = configuration.badge {
                    SegmentedTabBadge(text: badge)
                }
            }
            .foregroundStyle(foreground)
            .contentShape(Rectangle())
            // The built-in card keeps its chrome unfaded: only the two
            // buttons' labels dim, and the close button dims itself.
            .opacity(fade)
            if let closeButton = configuration.closeButton {
                closeButton
            }
        }
        .padding(.horizontal, size.tabHorizontalPadding)
        .padding(.vertical, size.tabVerticalPadding)
        .background(
            (isActive ? theme.background(.bgWhite) : theme.background(.bgElevatorTertiary)),
            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(isActive ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: isActive ? 1.5 : 1)
        )
    }

    // MARK: Parts

    /// The leading slot or the SF Symbol shorthand, in the tab's icon font. A
    /// slot that sets its own font keeps it.
    @ViewBuilder private var glyph: some View {
        if let leading = configuration.leading {
            leading.font(.system(size: configuration.glyphPoints, weight: .semibold))
        }
    }

    private var foreground: Color {
        guard configuration.isItemEnabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textPrimary) : theme.text(.textSecondary)
    }
}

/// The count bubble a tab carries, in the stock type and error fill. Drawn by
/// the built-in tabs and by ``DefaultSegmentedTabBarChromeStyle``.
struct SegmentedTabBadge: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.overline400)
            .foregroundStyle(theme.foreground(.fgSecondary))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(theme.background(.systemcolorsBgError), in: Capsule())
    }
}

// MARK: - Size metrics (shared by both chrome paths)

extension SegmentedTabBarSize {
    /// The label's type style at this density (Ant `size`).
    func titleStyle(isSelected: Bool) -> TextStyle {
        switch self {
        case .small: return isSelected ? .labelSm700 : .labelSm600
        case .medium: return isSelected ? .labelBase700 : .labelBase600
        case .large: return isSelected ? .labelMd700 : .labelMd600
        }
    }

    /// Glyph point size for a tab icon at this density.
    func iconPoints(base: CGFloat) -> CGFloat {
        switch self {
        case .small: return base - 2
        case .medium: return base
        case .large: return base + 2
        }
    }

    /// Horizontal padding inside a pill / card tab (and inside a
    /// content-hugging underline tab).
    var tabHorizontalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.sm.value
        case .medium: return Theme.SpacingKey.md.value
        case .large: return Theme.SpacingKey.lg.value
        }
    }

    /// Vertical padding inside a pill / card tab.
    var tabVerticalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.xs.value
        case .medium: return Theme.SpacingKey.sm.value
        case .large: return Theme.SpacingKey.md.value
        }
    }
}

public extension SegmentedTabBarChromeStyle where Self == DefaultSegmentedTabBarChromeStyle {
    /// The stock tab (today's `SegmentedTabBar` look).
    static var `default`: DefaultSegmentedTabBarChromeStyle { DefaultSegmentedTabBarChromeStyle() }
}

// MARK: - ButtonStyle bridge + type erasure + environment plumbing

/// Hands the tab's chrome to the environment style through a real SwiftUI
/// `ButtonStyle`, so `isPressed` is the live press state. Draws nothing of its
/// own: no press effect, no disabled fade. Used only on the custom-style path;
/// the built-in tabs keep `.plain`.
struct SegmentedTabChromePressBridge: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.environment(\.segmentedTabIsPressed, configuration.isPressed)
    }
}

/// Renders the environment style inside the tab's button, where the pressed
/// flag and the enabled state are readable.
struct SegmentedTabChromeHost: View {
    let style: AnySegmentedTabBarChromeStyle
    let configuration: SegmentedTabBarChromeStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.segmentedTabIsPressed) private var isPressed

    var body: some View {
        style.makeBody(configuration: configuration.resolving(isEnabled: isEnabled, isPressed: isPressed))
    }
}

private struct SegmentedTabPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var segmentedTabIsPressed: Bool {
        get { self[SegmentedTabPressedKey.self] }
        set { self[SegmentedTabPressedKey.self] = newValue }
    }
}

struct AnySegmentedTabBarChromeStyle: SegmentedTabBarChromeStyle {
    /// `true` only for the environment key's stock default below.
    /// `SegmentedTabBar` checks it: while the environment still carries the
    /// default it draws its own tabs, unchanged; any style set with
    /// `.segmentedTabBarChromeStyle(_:)` — including `.default` — is unmarked
    /// and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (SegmentedTabBarChromeStyleConfiguration) -> AnyView
    init<S: SegmentedTabBarChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SegmentedTabBarChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnySegmentedTabBarChromeStyle(DefaultSegmentedTabBarChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var segmentedTabBarChromeStyle: AnySegmentedTabBarChromeStyle {
        get { self[SegmentedTabBarChromeStyleKey.self] }
        set { self[SegmentedTabBarChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SegmentedTabBarChromeStyle`` for the `SegmentedTabBar`s in
    /// this view and its descendants. The style draws every tab of those bars.
    func segmentedTabBarChromeStyle<S: SegmentedTabBarChromeStyle>(_ style: sending S) -> some View {
        environment(\.segmentedTabBarChromeStyle, AnySegmentedTabBarChromeStyle(style))
    }
}
