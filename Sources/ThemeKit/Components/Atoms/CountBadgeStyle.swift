//
//  CountBadgeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `CountBadge`. The chrome — type,
//  padding, minimum size, fill, corner and halo — lives in a `CountBadgeStyle`
//  you set with `.countBadgeStyle(_:)`, so a host design system can draw its
//  own number tags while `CountBadge` keeps the rest.
//
//      CountBadge("+1")
//          .controlSize(.small)
//          .countBadgeStyle(HostNumberTag())
//
//  `CountBadge` keeps: the content model (count / text / glyph), the locale
//  formatting and overflow cap, the zero rule, the accent and halo axes, and
//  accessibility (on the style path the bubble reads as one VoiceOver element).
//

import SwiftUI

/// The inputs a ``CountBadgeStyle`` renders: the bubble's content, the raw
/// count behind it, the appearance axes set on the badge, and the
/// environment state the badge captured.
///
/// Fields a style doesn't use are simply ignored; new fields may be added in a
/// minor release.
public struct CountBadgeStyleConfiguration {
    /// What the bubble shows.
    ///
    /// A future minor release may add cases (another kind of bubble content),
    /// so give a `switch` over it a `default:` or `@unknown default:` branch —
    /// for example, drawing nothing or falling back to ``DefaultCountBadgeStyle``.
    public enum Content {
        /// A string to draw in the style's own type style: the formatted count
        /// (overflow cap applied, e.g. `"99+"`) or the host text.
        case text(String)
        /// The view passed to `CountBadge(glyph:)`, **un-fonted** — the style
        /// sizes and colours it.
        case glyph(AnyView)
    }

    /// What the bubble shows.
    public let content: Content
    /// The raw count for `CountBadge(_ count:)`, before formatting and the
    /// overflow cap; `nil` for text and glyph badges.
    public let count: Int?
    /// The semantic fill (`.accent(_:)`, `.error` when unset).
    public let accent: SemanticColor
    /// Whether the separating ring is on (`.halo(_:)`).
    public let showsHalo: Bool
    /// Whether the badge is enabled (`.disabled(_:)` in the environment). The
    /// default style ignores it.
    public let isEnabled: Bool
    /// The environment's control size (`.controlSize(_:)`), for styles with a
    /// size ramp. The default style ignores it.
    public let controlSize: ControlSize
}

/// Draws a count bubble. Implement `makeBody` to draw the configuration's
/// content and paint the bubble around it. Set one with `.countBadgeStyle(_:)`;
/// the default is ``DefaultCountBadgeStyle``.
///
/// The style draws; `CountBadge` keeps the content, formatting and visibility
/// rules and combines the result into one VoiceOver element. A hidden badge
/// (a count of zero or below without `.showsZero()`) never reaches the style.
///
/// The style applies to every `CountBadge` below the view it's set on,
/// including the bubbles placed by `View.countBadge(_:)` — ThemeKit's
/// floating action button uses one. The overlay keeps its fixed 9pt corner
/// offset, which is tuned for the default 18pt bubble.
///
/// ```swift
/// struct PillCountBadgeStyle: CountBadgeStyle {
///     func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
///         PillCountBadgeBody(configuration: configuration)
///     }
/// }
///
/// private struct PillCountBadgeBody: View {
///     let configuration: CountBadgeStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         let hue = theme.resolve(configuration.accent)
///         Group {
///             switch configuration.content {
///             case .text(let text): Text(text).textStyle(.labelSm700)
///             case .glyph(let glyph): glyph.font(.system(size: 10))
///             }
///         }
///         .foregroundStyle(configuration.isEnabled ? hue.onSolid : theme.text(.textDisabled))
///         .padding(.horizontal, Theme.SpacingKey.xs.value)
///         .background(configuration.isEnabled ? hue.solid : theme.background(.bgSecondaryLight), in: Capsule())
///     }
/// }
/// ```
public protocol CountBadgeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CountBadgeStyleConfiguration) -> Body
}

/// The stock bubble — exactly the look `CountBadge` draws with no style set:
/// 11pt bold content in the accent's on-solid colour, 5pt side padding, an
/// 18pt minimum capsule in the accent's solid shade, and a 1.5pt ring in the
/// white surface colour when the halo is on. Ignores `isEnabled` and
/// `controlSize`. Reads the active `\.theme`, so an injected theme re-skins it too.
public struct DefaultCountBadgeStyle: CountBadgeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
        DefaultCountBadgeChrome(configuration: configuration)
    }
}

private struct DefaultCountBadgeChrome: View {
    let configuration: CountBadgeStyleConfiguration
    @Environment(\.theme) private var theme

    // Mirrors `CountBadge`'s default path modifier for modifier, so
    // `.countBadgeStyle(.default)` renders the same pixels.
    var body: some View {
        label
            .font(.system(size: CountBadgeMetrics.fontSize, weight: .bold))
            .foregroundStyle(theme.resolve(configuration.accent).onSolid)
            .padding(.horizontal, CountBadgeMetrics.horizontalPadding)
            .frame(minWidth: CountBadgeMetrics.minSide, minHeight: CountBadgeMetrics.minSide)
            .background(theme.resolve(configuration.accent).solid, in: Capsule())
            .modifier(CountBadgeHalo(on: configuration.showsHalo))
    }

    @ViewBuilder private var label: some View {
        switch configuration.content {
        case .text(let text): Text(text)
        case .glyph(let glyph): glyph
        }
    }
}

public extension CountBadgeStyle where Self == DefaultCountBadgeStyle {
    /// The stock bubble (today's count-badge look).
    static var `default`: DefaultCountBadgeStyle { DefaultCountBadgeStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCountBadgeStyle: CountBadgeStyle {
    /// `true` only for the environment key's stock default below. `CountBadge`
    /// checks it: while the environment still carries the default it draws its
    /// own bubble, unchanged; any style set with `.countBadgeStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (CountBadgeStyleConfiguration) -> AnyView
    init<S: CountBadgeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CountBadgeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CountBadgeStyleKey: EnvironmentKey {
    static let defaultValue = AnyCountBadgeStyle(DefaultCountBadgeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var countBadgeStyle: AnyCountBadgeStyle {
        get { self[CountBadgeStyleKey.self] }
        set { self[CountBadgeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CountBadgeStyle`` for `CountBadge`s — including the
    /// `countBadge(_:)` overlays — in this view and its descendants.
    func countBadgeStyle<S: CountBadgeStyle>(_ style: sending S) -> some View {
        environment(\.countBadgeStyle, AnyCountBadgeStyle(style))
    }
}
