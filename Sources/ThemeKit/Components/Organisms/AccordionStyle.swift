//
//  AccordionStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `Accordion` — the expandable
//  section a screen stacks for an FAQ, a set of filters or a numbered flow. The
//  whole row — the surface and corner it sits on, the type of the title and its
//  subtitle, the indicator's glyph and tint, the header's padding, where the
//  content goes and whether a rule closes the row — lives in an
//  `AccordionStyle` you set with `.accordionStyle(_:)`, so a host design system
//  can draw its own section card while `Accordion` keeps the behaviour.
//
//      Accordion("Baggage allowance") {
//          Text("One carry-on and one personal item.")
//      }
//      .accordionStyle(HostAccordionStyle())
//
//  `Accordion` keeps: the expansion state (uncontrolled `initiallyExpanded:` or
//  the caller's `isExpanded:` binding), the animation both paths run under, and
//  the accessibility — the header is a button whose expanded state VoiceOver
//  announces. A style's own header button gets that state from
//  ``AccordionStyleConfiguration/expansionValue`` and flips it with
//  ``AccordionStyleConfiguration/toggle``, which runs exactly what the stock
//  header button runs.
//
//  Scope: `Accordion` itself, wherever it is placed. `AccordionGroup` is a
//  component of its own — it draws its rows rather than composing `Accordion`s
//  — so its rows are not drawn through this style; an `Accordion` placed inside
//  a group's content is, like any other.
//

import SwiftUI

/// The inputs an ``AccordionStyle`` renders: the row's raw strings, its leading
/// and trailing slots, the expanded state and the closure that flips it, the
/// axes the modifiers set, and the section's content ready to place.
///
/// The strings arrive raw, not as pre-styled `Text`, and the slots and the
/// content carry no font and no colour, so a style picks its own type styles and
/// colours. Fields a style doesn't use are simply ignored; new fields may be
/// added in a minor release.
public struct AccordionStyleConfiguration {
    /// The header's title, as passed to ``Accordion/init(_:initiallyExpanded:content:)``.
    public let title: String
    /// The second line under the title (``Accordion/subtitle(_:)``); `nil` when
    /// unset. See ``truncatesSubtitle`` for the stock clamping rule.
    public let subtitle: String?
    /// The leading SF Symbol's name (``Accordion/icon(_:)``); `nil` when unset.
    ///
    /// It is a name, not a view, so a style can draw the glyph in its own icon
    /// font. The stock header draws it only when ``leading`` is `nil`.
    public let icon: String?
    /// The leading step / FAQ number (``Accordion/number(_:)``); `nil` when
    /// unset. The stock header pads it to two digits ("01") and sets it in
    /// monospaced digits. Drawn only when ``leading`` is `nil`.
    public let number: Int?
    /// The ``Accordion/leading(_:)`` slot, exactly as written; `nil` when unset.
    /// When it is set it *replaces* the number and the icon, which is why
    /// ``number`` and ``icon`` can be non-`nil` beside it: draw the slot when
    /// it's there.
    public let leading: AnyView?
    /// The ``Accordion/trailing(_:)`` slot, already given the current
    /// ``isExpanded``; `nil` when unset. When it is set it *replaces* the
    /// built-in ``indicator`` glyph.
    public let trailing: AnyView?
    /// Whether the section is open right now — the state `Accordion` keeps,
    /// whichever init the caller used. Draw ``content`` while it is `true`.
    public let isExpanded: Bool
    /// Opens or closes the section: exactly what the stock header button runs,
    /// animation included, and it writes through the caller's `isExpanded:`
    /// binding when there is one. Call it from a style's own header control.
    ///
    /// It runs on the main actor, so call it from inside a control's action
    /// closure (`Button { configuration.toggle() }`) rather than handing the
    /// closure over as an action value.
    public let toggle: @MainActor () -> Void
    /// The disclosure glyph the caller asked for (``Accordion/indicator(_:)``),
    /// for a style that draws its own: `.chevron` (the stock one, turned 180°
    /// while open), `.plusMinus`, or a pair of SF Symbol names. Ignored when
    /// ``trailing`` is set.
    public let indicator: AccordionIndicator
    /// The title's size axis (``Accordion/titleSize(_:)``), for a style to map
    /// onto its own type ramp. The stock header sets `labelLg600` / `labelMd600`
    /// / `labelBase600` for large / medium / small.
    public let titleSize: AccordionTitleSize
    /// The header row's density (``Accordion/density(_:)``), for a style to map
    /// onto its own metrics. The stock header uses it as the row's vertical
    /// padding: 4 / 8 / 16 pt for small / default / large.
    public let density: AccordionPaddingSize
    /// ``Accordion/truncateSubtitle(_:)`` exactly as it was set. The stock rule
    /// is that a truncated subtitle shows one line while the section is closed
    /// and all of it while it is open.
    public let truncatesSubtitle: Bool
    /// ``Accordion/divider(_:)`` exactly as it was set — whether the caller
    /// asked for a rule under the row. A style draws its own separator (or
    /// none) and may ignore this; the stock row draws a small `DividerView`.
    public let showsDivider: Bool
    /// The section's content, ready to place: the caller's `content` builder
    /// with no font and no colour of its own, so a style's `.textStyle(_:)` /
    /// `.font(_:)` and `.foregroundStyle(_:)` land on it.
    ///
    /// It arrives whether or not the section is open — place it while
    /// ``isExpanded`` and give it the transition you want; the stock row fades
    /// it in from the top edge.
    public let content: AnyView
    /// What VoiceOver says about the header's state, in ThemeKit's own
    /// localization ("Expanded" / "Collapsed" for the current ``isExpanded``).
    /// A style's own header control carries it with
    /// `.accessibilityValue(configuration.expansionValue)`, so a styled section
    /// announces its state exactly as the stock one does.
    public let expansionValue: String
}

/// Draws an `Accordion`. Implement `makeBody` to lay the configuration's header
/// out — title, subtitle, leading accessory, indicator — and to place the
/// content under it while the section is open. Set one with
/// `.accordionStyle(_:)`; the default is ``DefaultAccordionStyle``.
///
/// **The style draws the whole section:** the surface and corner it sits on, the
/// header's padding and layout, the type and colour of the title and subtitle,
/// the indicator (or the ``AccordionStyleConfiguration/trailing`` slot), the
/// content's own paint and transition, and the rule under the row — ThemeKit
/// wraps nothing around a custom body but the component's animation.
///
/// **`Accordion` keeps the behaviour:** the expansion state (seeded by
/// `initiallyExpanded:` or driven by the caller's `isExpanded:` binding), the
/// animation the change runs under, and the header's accessibility. A style's
/// own header control flips the section with
/// ``AccordionStyleConfiguration/toggle`` and announces it with
/// ``AccordionStyleConfiguration/expansionValue``.
///
/// **What reaches the style.** Every section the component can hold: a title
/// alone or with a subtitle, a leading number and/or icon or a custom
/// ``AccordionStyleConfiguration/leading`` slot, any of the three indicators or
/// a custom ``AccordionStyleConfiguration/trailing`` slot, open or closed, with
/// or without a divider.
///
/// **Where to set it.** On the `Accordion` itself or on any ancestor. One style
/// at the root reskins every section at once. `AccordionGroup` draws its own
/// rows, so a style set on a group reaches the `Accordion`s inside its content
/// rather than the group's rows.
///
/// ```swift
/// struct HostAccordionStyle: AccordionStyle {
///     func makeBody(configuration: AccordionStyleConfiguration) -> some View {
///         HostAccordionBody(configuration: configuration)
///     }
/// }
///
/// private struct HostAccordionBody: View {
///     let configuration: AccordionStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
///             Button { configuration.toggle() } label: {
///                 HStack(spacing: Theme.SpacingKey.sm.value) {
///                     Text(configuration.title)
///                         .textStyle(.labelMd600)
///                         .foregroundStyle(theme.text(.textPrimary))
///                     Spacer(minLength: Theme.SpacingKey.sm.value)
///                     Icon(systemName: "chevron.down").size(.sm)
///                         .colorOverride(theme.text(.textHero))
///                         .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
///                 }
///                 .contentShape(Rectangle())
///             }
///             .buttonStyle(.plain)
///             .accessibilityValue(configuration.expansionValue)
///
///             if configuration.isExpanded {
///                 configuration.content
///                     .textStyle(.bodyBase400)
///                     .foregroundStyle(theme.text(.textSecondary))
///             }
///         }
///         .padding(Theme.SpacingKey.md.value)
///         .background(theme.background(.bgWhite),
///                     in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
///     }
/// }
/// ```
public protocol AccordionStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: AccordionStyleConfiguration) -> Body
}

/// The stock section — exactly what `Accordion` draws with no style set: the
/// header row (leading number / icon or the custom slot, the title over an
/// optional `bodySm400` subtitle, the indicator) on a plain button with `sm`
/// spacing and the density's vertical padding, the content under it in
/// `bodyBase400` `textSecondary`, and a small `DividerView` when the caller
/// asked for one. Reads the active `\.theme`, so an injected theme re-skins it
/// too.
public struct DefaultAccordionStyle: AccordionStyle, Sendable {
    public init() {}
    public func makeBody(configuration: AccordionStyleConfiguration) -> some View {
        DefaultAccordionChrome(configuration: configuration)
    }
}

/// Mirrors `Accordion`'s built-in body from the configuration.
/// `AccordionStyleTests` renders both and compares the pixels, so the two can't
/// drift apart unnoticed.
private struct DefaultAccordionChrome: View {
    let configuration: AccordionStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Button {
                configuration.toggle()
            } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let leading = configuration.leading {
                        leading
                    } else {
                        if let number = configuration.number {
                            Text(zeroPad2(number))
                                .textStyle(configuration.titleSize.textStyle)
                                .foregroundStyle(titleColor)
                                .monospacedDigit()
                        }
                        if let icon = configuration.icon {
                            Icon(systemName: icon).size(.sm).colorOverride(titleColor)
                        }
                    }
                    VStack(alignment: .leading, spacing: AccordionMetrics.titleSpacing) {
                        Text(configuration.title)
                            .textStyle(configuration.titleSize.textStyle)
                            .foregroundStyle(titleColor)
                        if let subtitle = configuration.subtitle {
                            Text(subtitle)
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary))
                                .lineLimit(configuration.truncatesSubtitle && !configuration.isExpanded ? 1 : nil)
                        }
                    }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if let trailing = configuration.trailing {
                        trailing
                    } else {
                        indicatorIcon
                    }
                }
                .padding(.vertical, configuration.density.value)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // State-aware for VoiceOver (Dropdown's disclosure convention).
            .accessibilityValue(configuration.expansionValue)

            if configuration.isExpanded {
                configuration.content
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if configuration.showsDivider {
                DividerView().size(.small)
            }
        }
    }

    private var titleColor: Color {
        configuration.isExpanded ? theme.text(.textHero) : theme.text(.textPrimary)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        let color = theme.text(.textTertiary)
        switch configuration.indicator {
        case .chevron:
            Icon(systemName: "chevron.down").size(.sm).colorOverride(color)
                .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
        case .plusMinus:
            Icon(systemName: configuration.isExpanded ? "minus" : "plus").size(.sm).colorOverride(color)
        case .custom(let expand, let collapse):
            Icon(systemName: configuration.isExpanded ? collapse : expand).size(.sm).colorOverride(color)
        }
    }
}

/// The stock row's fixed geometry, shared by `Accordion`'s built-in body and
/// ``DefaultAccordionStyle`` so the two can't drift apart.
enum AccordionMetrics {
    /// Gap between the title and its subtitle.
    static let titleSpacing: CGFloat = 2
}

public extension AccordionStyle where Self == DefaultAccordionStyle {
    /// The stock section (today's `Accordion` look).
    static var `default`: DefaultAccordionStyle { DefaultAccordionStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyAccordionStyle: AccordionStyle {
    /// `true` only for the environment key's stock default below. `Accordion`
    /// checks it: while the environment still carries the default it draws its
    /// own body, unchanged; any style set with `.accordionStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (AccordionStyleConfiguration) -> AnyView
    init<S: AccordionStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: AccordionStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct AccordionStyleKey: EnvironmentKey {
    static let defaultValue = AnyAccordionStyle(DefaultAccordionStyle(), isDefault: true)
}

extension EnvironmentValues {
    var accordionStyle: AnyAccordionStyle {
        get { self[AccordionStyleKey.self] }
        set { self[AccordionStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``AccordionStyle`` for the `Accordion`s in this view and its
    /// descendants.
    func accordionStyle<S: AccordionStyle>(_ style: sending S) -> some View {
        environment(\.accordionStyle, AnyAccordionStyle(style))
    }
}
