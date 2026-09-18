//
//  TitleStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 17.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `Title`. The chrome — the type
//  style and colour of the eyebrow, the title and the subtitle, the gaps
//  between them, the action link's type and where every part sits — lives in a
//  `TitleStyle` you set with `.titleStyle(_:)`, so a host design system can
//  draw its own section title while `Title` keeps the rest.
//
//      Title("Popular destinations")
//          .eyebrow("This week")
//          .subtitle("Where travellers go")
//          .leading { HostGlyph(.compass) }
//          .action("See all") { showAll() }
//          .titleStyle(HostSectionTitleStyle())
//
//  `Title` keeps: the content model (text, eyebrow, subtitle and the
//  `.leading { }` slot), the wired action button, and the accessibility
//  decision — the title reads as one heading with its eyebrow and subtitle,
//  and the action stays a button of its own.
//

import SwiftUI

/// The inputs a ``TitleStyle`` renders: `Title`'s raw strings, the title text
/// ready to paint, the leading slot, the wired action link and the environment
/// control size.
///
/// The strings arrive raw, not as pre-styled `Text`, and ``content`` and
/// ``action`` carry no font and no colour, so a style picks its own type style
/// and colours. Fields a style doesn't use are simply ignored; new fields may
/// be added in a minor release.
public struct TitleStyleConfiguration {
    /// The title, as passed to ``Title/init(_:)``.
    public let text: String
    /// ``text`` as a `Text` with no font and no colour of its own, so
    /// `.textStyle(_:)` / `.font(_:)` and `.foregroundStyle(_:)` applied to it
    /// take effect. Use it (rather than `Text(configuration.text)`) to keep the
    /// title's identity stable across renders.
    public let content: AnyView
    /// The second line under the title (``Title/subtitle(_:)``); `nil` when unset.
    public let subtitle: String?
    /// The kicker above the title (``Title/eyebrow(_:)``), exactly as it was
    /// passed in — the stock style is the one that uppercases it. `nil` when unset.
    public let eyebrow: String?
    /// The ``Title/leading(_:)`` slot, exactly as written; `nil` when unset.
    /// It is decorative: VoiceOver reads the title, its eyebrow and its
    /// subtitle as one heading and skips this slot.
    public let leading: AnyView?
    /// The action link's title (``Title/action(_:action:)``), for a style that
    /// draws its own button; `nil` when unset.
    public let actionTitle: String?
    /// The action link, wired: ThemeKit's plain button around ``actionTitle``,
    /// calling the handler. Its label has no font and no colour of its own, so
    /// `.textStyle(_:)` and `.foregroundStyle(_:)` applied to it take effect —
    /// the host's type on ThemeKit's button. `nil` unless a title *and* a
    /// handler are set (`Title` never draws a link it can't trigger).
    public let action: AnyView?
    /// The action's handler, for a style that draws its own button; `nil` when unset.
    public let onAction: (() -> Void)?
    /// The environment's control size (`.controlSize(_:)`), for a style with a
    /// size ramp. The stock style ignores it — `Title` has one size.
    public let controlSize: ControlSize
}

/// Draws a `Title`. Implement `makeBody` to lay out the configuration's
/// eyebrow, leading slot, title, subtitle and action, and give each its type
/// and colour. Set one with `.titleStyle(_:)`; the default is
/// ``DefaultTitleStyle``.
///
/// The style draws; `Title` keeps the behaviour. The action arrives as a wired
/// button (with its raw title and handler beside it, for a style that draws its
/// own), and whatever the style returns reads to VoiceOver like the built-in
/// title: one heading carrying the eyebrow, the title and the subtitle, then
/// the action button.
///
/// The style applies to every `Title` below the view it's set on. Set it on the
/// title itself to restyle only that one.
///
/// ```swift
/// struct HostSectionTitleStyle: TitleStyle {
///     func makeBody(configuration: TitleStyleConfiguration) -> some View {
///         HostSectionTitleBody(configuration: configuration)
///     }
/// }
///
/// private struct HostSectionTitleBody: View {
///     let configuration: TitleStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
///             configuration.leading
///             VStack(alignment: .leading, spacing: 2) {
///                 configuration.content
///                     .textStyle(.headingSm)
///                     .foregroundStyle(theme.custom.color(.sectionTitle) ?? theme.text(.textPrimary))
///                 if let subtitle = configuration.subtitle {
///                     Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
///                 }
///             }
///             Spacer(minLength: Theme.SpacingKey.sm.value)
///             configuration.action?
///                 .textStyle(.labelSm600)
///                 .foregroundStyle(theme.text(.textHero))
///         }
///     }
/// }
/// ```
public protocol TitleStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: TitleStyleConfiguration) -> Body
}

/// The stock title — exactly the look `Title` draws with no style set: the
/// eyebrow uppercased in `overline500` and the hero text colour, the title in
/// `headingBase`, the subtitle in `bodyBase400`, 2 pt apart in a leading
/// column, and the action as a `linkBase` link baseline-aligned with the first
/// line. A ``TitleStyleConfiguration/leading`` slot sits before the title in
/// the icon font's place. Reads the active `\.theme`, so an injected theme
/// re-skins it too.
public struct DefaultTitleStyle: TitleStyle, Sendable {
    public init() {}
    public func makeBody(configuration: TitleStyleConfiguration) -> some View {
        DefaultTitleChrome(configuration: configuration)
    }
}

private struct DefaultTitleChrome: View {
    let configuration: TitleStyleConfiguration
    @Environment(\.theme) private var theme

    // Mirrors `Title`'s built-in body, modifier for modifier, so
    // `.titleStyle(.default)` renders the same pixels.
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: TitleMetrics.lineSpacing) {
                if let eyebrow = configuration.eyebrow {
                    Text(eyebrow.uppercased())
                        .textStyle(TitleMetrics.eyebrowStyle)
                        .foregroundStyle(theme.text(.textHero))
                }
                TitleLine(leading: configuration.leading) {
                    configuration.content
                        .textStyle(TitleMetrics.titleStyle)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                if let subtitle = configuration.subtitle {
                    Text(subtitle)
                        .textStyle(TitleMetrics.subtitleStyle)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let action = configuration.action {
                action
                    .textStyle(TitleMetrics.actionStyle)
                    .foregroundStyle(theme.text(.textHero))
            }
        }
    }
}

/// The stock type ramp and gaps, shared by `Title`'s built-in body and
/// ``DefaultTitleStyle`` so the two can't drift apart.
enum TitleMetrics {
    static let lineSpacing: CGFloat = 2
    // Computed: `TextStyle` isn't `Sendable`, so these can't be stored globals.
    static var eyebrowStyle: TextStyle { .overline500 }
    static var titleStyle: TextStyle { .headingBase }
    static var subtitleStyle: TextStyle { .bodyBase400 }
    static var actionStyle: TextStyle { .linkBase }
}

/// The title's line: the `.leading { }` slot before the text when set, else the
/// text alone. Shared by the built-in body and ``DefaultTitleStyle``.
struct TitleLine<Content: View>: View {
    let leading: AnyView?
    @ViewBuilder let content: Content

    var body: some View {
        if let leading {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                leading
                content
            }
        } else {
            content
        }
    }
}

public extension TitleStyle where Self == DefaultTitleStyle {
    /// The stock title (today's `Title` look).
    static var `default`: DefaultTitleStyle { DefaultTitleStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyTitleStyle: TitleStyle {
    /// `true` only for the environment key's stock default below. `Title`
    /// checks it: while the environment still carries the default it draws its
    /// own body, unchanged; any style set with `.titleStyle(_:)` — including
    /// `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (TitleStyleConfiguration) -> AnyView
    init<S: TitleStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: TitleStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct TitleStyleKey: EnvironmentKey {
    static let defaultValue = AnyTitleStyle(DefaultTitleStyle(), isDefault: true)
}

extension EnvironmentValues {
    var titleStyle: AnyTitleStyle {
        get { self[TitleStyleKey.self] }
        set { self[TitleStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``TitleStyle`` for the `Title`s in this view and its descendants.
    func titleStyle<S: TitleStyle>(_ style: sending S) -> some View {
        environment(\.titleStyle, AnyTitleStyle(style))
    }
}
