//
//  InlineText.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Body text with tappable inline links. Improves on the reference
/// UnderlineText by using AttributedString + openURL routing instead of manual
/// NSRange math.
///
/// Optional `.leading { }` / `.trailing { }` slots sit before and after the
/// text (a glyph, a badge). The paint is drawn by the active
/// ``InlineTextStyle`` when one is set with `.inlineTextStyle(_:)` on the text
/// or an ancestor; the text keeps its links and their tap routing either way.
public struct InlineText: View {
    @Environment(\.theme) private var theme
    @Environment(\.inlineTextStyle) private var inlineTextStyle
    @Environment(\.openURL) private var surroundingOpenURL
    @Environment(\.isEnabled) private var isEnabled

    private let text: String
    private let links: [(substring: String, action: () -> Void)]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var baseColor: Color? = nil
    // ADR-0006: the token overload stores the `SemanticColor` (not a resolved
    // `Color`) so it re-resolves against the environment theme in `body`.
    private var semanticColor: SemanticColor? = nil
    private var style: TextStyle = .bodySm400
    private var leadingSlot: SlotContent?
    private var trailingSlot: SlotContent?

    public init(_ text: String, links: [(substring: String, action: () -> Void)] = []) {   // R1
        self.text = text
        self.links = links
    }

    public var body: some View {
        if inlineTextStyle.isDefault && leadingSlot == nil && trailingSlot == nil {
            Text(attributed)
                .environment(\.openURL, Self.linkRouting(links))
        } else {
            // The style draws; the text keeps routing its link taps, and any
            // other URL opened in the style's body goes to the surrounding action.
            inlineTextStyle.makeBody(configuration: configuration)
                .environment(\.openURL, Self.linkRouting(links, fallback: surroundingOpenURL))
        }
    }

    private var attributed: AttributedString {
        Self.attributedString(text, links: links, font: style.font, baseColor: resolvedBaseColor, linkColor: linkColor)
    }

    private var resolvedBaseColor: Color {
        semanticColor.map { theme.resolve($0).base } ?? baseColor ?? theme.text(.textSecondary)
    }

    private var linkColor: Color { theme.text(.textHero) }

    private var configuration: InlineTextStyleConfiguration {
        let unpainted = Self.attributedString(text, links: links, font: nil, baseColor: nil, linkColor: linkColor)
        return InlineTextStyleConfiguration(
            text: text,
            links: links,
            content: AnyView(Text(unpainted)),
            attributedText: unpainted,
            leading: leadingSlot.map { AnyView($0) },
            trailing: trailingSlot.map { AnyView($0) },
            textStyle: style,
            accent: semanticColor,
            baseColor: resolvedBaseColor,
            linkColor: linkColor,
            isEnabled: isEnabled)
    }
}

// MARK: - Link marking + routing (shared with InlineTextStyle and Callout)

extension InlineText {
    /// The text with its links marked: `font` and `baseColor` (when given) on
    /// the whole string first, then each link's first match painted
    /// `linkColor`, underlined, and given the `inline:<index>` URL that
    /// ``linkRouting(_:fallback:)`` resolves.
    static func attributedString(
        _ text: String,
        links: [(substring: String, action: () -> Void)],
        font: Font?,
        baseColor: Color?,
        linkColor: Color
    ) -> AttributedString {
        var string = AttributedString(text)
        if let font { string.font = font }
        if let baseColor { string.foregroundColor = baseColor }
        for (index, link) in links.enumerated() {
            if let range = string.range(of: link.substring) {
                string[range].foregroundColor = linkColor
                string[range].underlineStyle = .single
                string[range].link = URL(string: "inline:\(index)")
            }
        }
        return string
    }

    /// Routes an `inline:<index>` URL to that link's action. Any other URL goes
    /// to `fallback` when given, else to the system.
    static func linkRouting(
        _ links: [(substring: String, action: () -> Void)],
        fallback: OpenURLAction? = nil
    ) -> OpenURLAction {
        OpenURLAction { url in
            guard url.scheme == "inline",
                  let index = Int(url.absoluteString.replacingOccurrences(of: "inline:", with: "")),
                  links.indices.contains(index) else {
                guard let fallback else { return .systemAction }
                fallback(url)
                return .handled
            }
            links[index].action()
            return .handled
        }
    }

    /// A resolved base colour from a composing component (a callout's tone) —
    /// the non-deprecated internal twin of `color(_:)`.
    internal func baseColorOverride(_ color: Color?) -> Self { copy { $0.baseColor = color; $0.semanticColor = nil } }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InlineText {
    /// Semantic base text color; `nil` (default) uses the theme's secondary text color.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.semanticColor = color; $0.baseColor = nil } }

    /// Raw base text color (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ color: Color?) -> Self { copy { $0.baseColor = color; $0.semanticColor = nil } }

    /// Typography token for the body text. Named `inlineStyle` so it doesn't
    /// shadow the kit-wide `.textStyle(_:)` view modifier.
    func inlineStyle(_ style: TextStyle) -> Self { copy { $0.style = style } }

    /// Content before the text — a glyph, an icon. Sits on the text's first
    /// baseline and inherits its font and base colour. Hide a decorative glyph
    /// from VoiceOver with `.accessibilityHidden(true)`.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingSlot = SlotContent(content) }
    }

    /// Content after the text — a glyph, a `Badge`. Sits on the text's first
    /// baseline and inherits its font and base colour.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingSlot = SlotContent(content) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("InlineText") {
        PreviewCase("Links") {
            InlineText("By continuing you accept the Terms and the Privacy Policy.",
                       links: [("Terms", { print("terms") }), ("Privacy Policy", { print("privacy") })])
        }
        PreviewCase("Plain") { InlineText("A plain sentence with no anchors.") }
        PreviewCase("Accent + style") {
            InlineText("Read the Guidelines before publishing.", links: [("Guidelines", {})])
                .accent(.primary)
                .inlineStyle(.bodyBase400)
        }
        PreviewCase("Slots") {
            InlineText("Free cancellation")
                .accent(.success)
                .leading { Image(systemName: "checkmark.circle") }
                .trailing { Badge("New").badgeStyle(.success).size(.small) }
        }
        PreviewCase("Custom style") {
            InlineText("Read the Guidelines before publishing.", links: [("Guidelines", {})])
                .leading { Image(systemName: "book") }
                .inlineTextStyle(PreviewInlineTextStyle())
        }
    }
}

/// A preview-only custom style: primary body text on one line, a centred row,
/// slot glyphs in the tertiary text colour.
private struct PreviewInlineTextStyle: InlineTextStyle {
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        PreviewInlineTextBody(configuration: configuration)
    }
}

private struct PreviewInlineTextBody: View {
    let configuration: InlineTextStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            configuration.leading
            configuration.content
                .textStyle(.bodyBase500)
                .foregroundStyle(theme.text(.textPrimary))
                .lineLimit(1)
            configuration.trailing
        }
        .foregroundStyle(theme.text(.textTertiary))
    }
}
