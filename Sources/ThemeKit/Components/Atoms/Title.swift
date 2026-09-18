//
//  Title.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A section title: optional eyebrow, title + optional subtitle, an
/// optional leading slot and an optional trailing action (e.g. "See all").
///
/// The chrome is drawn by the active ``TitleStyle`` when one is set with
/// `.titleStyle(_:)` on the title or an ancestor; the title keeps its content,
/// its wired action and its accessibility either way.
public struct Title: View {
    @Environment(\.theme) private var theme
    @Environment(\.titleStyle) private var chromeStyle
    @Environment(\.controlSize) private var controlSize

    private let text: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var subtitle: String? = nil
    private var eyebrow: String? = nil
    private var actionTitle: String? = nil
    private var action: (() -> Void)? = nil
    private var leadingSlot: SlotContent?

    public init(_ text: String) {   // R1
        self.text = text
    }

    public var body: some View {
        if chromeStyle.isDefault {
            builtIn
        } else {
            chromeStyle.makeBody(configuration: chromeConfiguration)
                .modifier(TitleStyleAccessibility(label: accessibilityLabel,
                                                  actionTitle: actionTitle,
                                                  onAction: action))
        }
    }

    private var builtIn: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: TitleMetrics.lineSpacing) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .textStyle(TitleMetrics.eyebrowStyle)
                        .foregroundStyle(theme.text(.textHero))
                }
                TitleLine(leading: leadingSlot.map { AnyView($0) }) {
                    Text(text)
                        .textStyle(TitleMetrics.titleStyle)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                if let subtitle {
                    Text(subtitle)
                        .textStyle(TitleMetrics.subtitleStyle)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            // The title, its eyebrow and its subtitle are one heading; the
            // action below stays a button of its own.
            .modifier(TitleHeading(label: accessibilityLabel))
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .textStyle(TitleMetrics.actionStyle)
                        .foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Style path

    /// The inputs handed to a custom ``TitleStyle``. The title text and the
    /// action's label arrive with no font and no colour, so the style's own
    /// type and tokens take effect.
    private var chromeConfiguration: TitleStyleConfiguration {
        TitleStyleConfiguration(
            text: text,
            content: AnyView(Text(text)),
            subtitle: subtitle,
            eyebrow: eyebrow,
            leading: leadingSlot.map { AnyView($0) },
            actionTitle: actionTitle,
            action: wiredAction,
            onAction: action,
            controlSize: controlSize)
    }

    /// ThemeKit's plain action button with an unpainted label; `nil` unless a
    /// title and a handler are both set (as on the built-in path).
    private var wiredAction: AnyView? {
        guard let actionTitle, let action else { return nil }
        return AnyView(Button(action: action) { Text(actionTitle) }.buttonStyle(.plain))
    }

    /// What VoiceOver reads for the heading, on both paths.
    private var accessibilityLabel: String {
        TitleAccessibility.label(text: text, eyebrow: eyebrow, subtitle: subtitle)
    }
}

// MARK: - Accessibility (shared by both chrome paths)

/// The title's accessibility decisions, in one place so they can be tested
/// without an accessibility tree (a unit-test host builds none).
enum TitleAccessibility {
    /// A title is a heading, whichever chrome draws it.
    static let traits: AccessibilityTraits = .isHeader

    /// The heading's spoken label: the eyebrow, the title and the subtitle as
    /// one element, in reading order. The eyebrow is spoken as it was written,
    /// not uppercased as it's drawn; empty strings are left out.
    static func label(text: String, eyebrow: String?, subtitle: String?) -> String {
        [eyebrow, text, subtitle]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Makes the title's text column one heading element.
struct TitleHeading: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(TitleAccessibility.traits)
    }
}

/// Gives a custom-styled title the built-in title's accessibility, whatever
/// the style drew: one heading element, then the action button when set.
struct TitleStyleAccessibility: ViewModifier {
    let label: String
    let actionTitle: String?
    let onAction: (() -> Void)?

    func body(content: Content) -> some View {
        content.accessibilityRepresentation {
            HStack {
                Text(label).accessibilityAddTraits(TitleAccessibility.traits)
                if let actionTitle, let onAction {
                    Button(actionTitle, action: onAction)
                }
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Title {
    /// Secondary line rendered under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Uppercased kicker rendered above the title.
    func eyebrow(_ text: String?) -> Self { copy { $0.eyebrow = text } }

    /// Trailing action link (e.g. "See all") and its tap handler.
    func action(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.actionTitle = title; $0.action = action }
    }

    /// A custom view before the title (a host glyph, a flag, an avatar). It
    /// inherits the surrounding font and foreground colour. Decorative:
    /// VoiceOver reads the title, eyebrow and subtitle as one heading and
    /// skips the slot.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingSlot = SlotContent(content) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    /// Proof of external implementability: a host-shaped title with its own
    /// type, a boxed glyph and a pill action.
    struct BoxedTitleStyle: TitleStyle {
        func makeBody(configuration: TitleStyleConfiguration) -> some View {
            BoxedTitleBody(configuration: configuration)
        }
    }
    struct BoxedTitleBody: View {
        let configuration: TitleStyleConfiguration
        @Environment(\.theme) private var theme

        var body: some View {
            HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                if let leading = configuration.leading {
                    leading
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground(.fgHero))
                        .frame(width: 32, height: 32)
                        .background(theme.resolve(.primary).soft,
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let eyebrow = configuration.eyebrow {
                        Text(eyebrow).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                    }
                    configuration.content.textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    if let subtitle = configuration.subtitle {
                        Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer(minLength: Theme.SpacingKey.sm.value)
                configuration.action?
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textHero))
            }
        }
    }

    return PreviewMatrix("Title") {
        PreviewCase("Subtitle · action") { Title("Popular destinations").subtitle("Where travellers go").action("See all", action: {}) }
        PreviewCase("Eyebrow") { Title("Deals").eyebrow("Limited time") }
        PreviewCase("Title only") { Title("Recently viewed") }
        PreviewCase("Leading slot") {
            Title("Nearby").subtitle("Within 50 km").leading { Image(systemName: "location.fill") }
        }
        PreviewCase("Custom TitleStyle") {
            Title("Popular destinations")
                .eyebrow("This week")
                .subtitle("Where travellers go")
                .leading { Image(systemName: "sparkles") }
                .action("See all", action: {})
                .titleStyle(BoxedTitleStyle())
        }
    }
}
