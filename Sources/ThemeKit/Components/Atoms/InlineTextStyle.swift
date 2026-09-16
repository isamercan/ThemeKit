//
//  InlineTextStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `InlineText`. The paint — the
//  text's type style and base colour, and how the leading/trailing slots sit
//  around it — lives in an `InlineTextStyle` you set with
//  `.inlineTextStyle(_:)`, so a host design system can draw inline text in its
//  own type and colour while `InlineText` keeps the rest.
//
//      InlineText("Free cancellation", links: [("Free cancellation", showPolicy)])
//          .leading { HostGlyph(.check) }
//          .inlineTextStyle(HostInlineTextStyle())
//
//  `InlineText` keeps: the content model (text + inline links + slots), link
//  marking and tap routing (on both paths), and its `accent(_:)` /
//  `inlineStyle(_:)` axes, which reach the style resolved.
//

import SwiftUI

/// The inputs an ``InlineTextStyle`` renders: the raw text and links, the text
/// ready to paint, the slots, and the type style and colours the stock look
/// would use.
///
/// `content` carries no font and no base colour, so a style sets both. Fields
/// a style doesn't use are simply ignored; new fields may be added in a minor
/// release.
public struct InlineTextStyleConfiguration {
    /// The full text.
    public let text: String
    /// The inline links, as passed to `InlineText`: each substring's first
    /// match becomes tappable and calls its action.
    public let links: [(substring: String, action: () -> Void)]
    /// The text as a type-erased `Text`. Link runs are already marked (link
    /// colour, underline, tap routing); the rest of the text has no font and no
    /// colour of its own, so `.font(_:)` / `.textStyle(_:)` and
    /// `.foregroundStyle(_:)` applied to it take effect.
    public let content: AnyView
    /// The same text as an `AttributedString`, for a style that repaints the
    /// link runs too. Each link run carries the `link` URL `InlineText` routes
    /// taps through; keep it and render the result with `Text(_:)` inside
    /// `makeBody`, and taps still reach the link's action.
    public let attributedText: AttributedString
    /// The `.leading { }` slot; `nil` when unset.
    public let leading: AnyView?
    /// The `.trailing { }` slot; `nil` when unset.
    public let trailing: AnyView?
    /// The type style the stock look uses (`.inlineStyle(_:)`, `.bodySm400`
    /// when unset).
    public let textStyle: TextStyle
    /// The semantic base colour set with `.accent(_:)`; `nil` when unset.
    public let accent: SemanticColor?
    /// The resolved base colour the stock look paints the non-link text with:
    /// the theme's colour for ``accent`` (its secondary text colour when
    /// unset), or the colour set for this text in its place — for example by a
    /// composing component (a callout's tone, a validation message's status).
    /// Only the resolved result is handed over.
    public let baseColor: Color
    /// The colour the link runs in ``content`` are painted with.
    public let linkColor: Color
    /// Whether the text is enabled (`.disabled(_:)` in the environment). The
    /// default style ignores it.
    public let isEnabled: Bool
}

/// Draws inline text. Implement `makeBody` to paint the configuration's
/// content and lay out its slots. Set one with `.inlineTextStyle(_:)`; the
/// default is ``DefaultInlineTextStyle``.
///
/// The style draws; `InlineText` keeps the behaviour. It marks the link runs
/// and routes their taps for whatever the style renders — `content`, or a
/// `Text` built from `attributedText`. Other URLs opened inside the style's
/// body go to the surrounding `openURL` action.
///
/// The style applies to every `InlineText` below the view it's set on,
/// including the linked text ThemeKit composes inside other components (helper
/// text, input labels, validation messages, banners, callouts, toasts, empty
/// states). Those components pass their own colour and type style through
/// ``InlineTextStyleConfiguration/baseColor`` and
/// ``InlineTextStyleConfiguration/textStyle``; a style that honours them keeps
/// those uses right. Set it on the text itself to restyle only that text.
///
/// ```swift
/// struct BodyInlineTextStyle: InlineTextStyle {
///     func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
///         BodyInlineText(configuration: configuration)
///     }
/// }
///
/// private struct BodyInlineText: View {
///     let configuration: InlineTextStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         HStack(alignment: .center, spacing: Theme.SpacingKey.xs.value) {
///             configuration.leading
///             configuration.content
///                 .textStyle(.bodyBase400)
///                 .foregroundStyle(theme.text(.textPrimary))
///                 .lineLimit(1)
///             configuration.trailing
///         }
///         .foregroundStyle(theme.text(.textSecondary))   // slot glyphs
///     }
/// }
/// ```
public protocol InlineTextStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: InlineTextStyleConfiguration) -> Body
}

/// The stock inline text — exactly what `InlineText` draws with no style set:
/// the text in its type style (font only) and base colour, link runs in the
/// link colour and underlined. With slots, the leading slot, text and trailing
/// slot sit in a first-baseline row with `xs` spacing, and the slots inherit
/// the text's font and base colour. Ignores `isEnabled`.
public struct DefaultInlineTextStyle: InlineTextStyle, Sendable {
    public init() {}
    public func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        DefaultInlineTextChrome(configuration: configuration)
    }
}

private struct DefaultInlineTextChrome: View {
    let configuration: InlineTextStyleConfiguration

    var body: some View {
        if configuration.leading == nil && configuration.trailing == nil {
            text
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
                configuration.leading
                text
                configuration.trailing
            }
            // The text carries its own paint; this reaches the slots, so a
            // plain glyph matches the text with zero configuration.
            .font(configuration.textStyle.font)
            .foregroundStyle(configuration.baseColor)
        }
    }

    /// The text exactly as the component's stock path builds it: base font and
    /// colour on the whole string, then the link runs.
    private var text: Text {
        Text(InlineText.attributedString(
            configuration.text,
            links: configuration.links,
            font: configuration.textStyle.font,
            baseColor: configuration.baseColor,
            linkColor: configuration.linkColor))
    }
}

public extension InlineTextStyle where Self == DefaultInlineTextStyle {
    /// The stock look — what `InlineText` draws with no style set.
    static var `default`: DefaultInlineTextStyle { DefaultInlineTextStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyInlineTextStyle: InlineTextStyle {
    /// `true` only for the environment key's stock default below. `InlineText`
    /// checks it: while the environment still carries the default and no slot
    /// is set, it draws its own text, unchanged; any style set with
    /// `.inlineTextStyle(_:)` — including `.default` — is unmarked and goes
    /// through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (InlineTextStyleConfiguration) -> AnyView
    init<S: InlineTextStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: InlineTextStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct InlineTextStyleKey: EnvironmentKey {
    static let defaultValue = AnyInlineTextStyle(DefaultInlineTextStyle(), isDefault: true)
}

extension EnvironmentValues {
    var inlineTextStyle: AnyInlineTextStyle {
        get { self[InlineTextStyleKey.self] }
        set { self[InlineTextStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``InlineTextStyle`` for `InlineText`s in this view and its descendants.
    func inlineTextStyle<S: InlineTextStyle>(_ style: sending S) -> some View {
        environment(\.inlineTextStyle, AnyInlineTextStyle(style))
    }
}
