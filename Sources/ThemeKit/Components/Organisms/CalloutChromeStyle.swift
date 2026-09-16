//
//  CalloutChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `Callout`. The chrome — the row
//  layout, the text's type style and colour, the icon, padding, surface,
//  stroke and corner — lives in a `CalloutChromeStyle` you set with
//  `.calloutChromeStyle(_:)`, so a host design system can draw its own callout
//  while `Callout` keeps the rest. (The name carries "Chrome" because
//  `CalloutStyle` already names the callout's plain/soft surface enum.)
//
//      Callout("Prices may change").variant(.warning)
//          .leading { HostGlyph(.warning) }
//          .statusLabel("Warning")
//          .calloutChromeStyle(HostCalloutChrome())
//
//  `Callout` keeps: the content model (text + inline links, leading/trailing
//  slots, the action link and the dismiss button, all wired), the tone /
//  surface / alignment / width axes, link tap routing, and the VoiceOver
//  status label on the leading indicator.
//

import SwiftUI

/// The inputs a ``CalloutChromeStyle`` renders: the callout's raw text and
/// links, the text ready to paint, its leading indicator and trailing
/// accessories (already wired), the axes set on the callout, and its resolved
/// state.
///
/// `text` is the raw string and `content` carries no font and no colour, so a
/// style picks its own type style and text colour. Fields a style doesn't use
/// are simply ignored; new fields may be added in a minor release.
public struct CalloutChromeStyleConfiguration {
    /// The callout's text.
    public let text: String
    /// The inline links set with `.links(_:)`; empty when none. Pass them on
    /// with the text to draw it yourself:
    /// `InlineText(configuration.text, links: configuration.links)`.
    public let links: [(substring: String, action: () -> Void)]
    /// The text as a type-erased `Text`, link runs already marked and routed.
    /// The rest of the text has no font and no colour of its own, so
    /// `.textStyle(_:)` and `.foregroundStyle(_:)` applied to it take effect.
    public let content: AnyView
    /// The same text as an `AttributedString`, for a style that repaints the
    /// link runs too — the runs ``InlineTextStyleConfiguration/attributedText``
    /// carries: link runs painted, underlined and given the `link` URL the
    /// callout routes taps through; the rest with no font and no colour.
    /// Render it with `Text(_:)` inside `makeBody`, and taps still reach the
    /// link's action.
    public let attributedText: AttributedString
    /// The leading indicator: the `.leading { }` slot when set, else the stock
    /// status icon (a 14pt SF Symbol) while ``showsIcon`` is on; `nil` when
    /// neither. It already carries ``statusLabel`` for VoiceOver.
    public let leading: AnyView?
    /// The SF Symbol behind the stock icon in ``leading`` (the `.icon(_:)`
    /// override, else the tone's glyph), so a style can draw its own icon at
    /// its own size; `nil` when ``leading`` is a slot or absent. A style that
    /// draws its own icon applies ``statusLabel`` to it.
    public let leadingSystemImage: String?
    /// The `.trailing { }` slot; `nil` when unset.
    public let trailing: AnyView?
    /// The stock text-link action button (`.action(_:onAction:)`), wired;
    /// `nil` when unset.
    public let actionButton: AnyView?
    /// The stock dismiss (×) button (`.onClose(_:)`), wired and labelled for
    /// VoiceOver; `nil` when unset.
    public let closeButton: AnyView?
    /// The action's title, for a style that draws its own action button;
    /// `nil` when unset.
    public let actionTitle: String?
    /// The action's handler; `nil` when unset.
    public let onAction: (() -> Void)?
    /// The dismiss handler, for a style that draws its own dismiss button
    /// (give it a VoiceOver label); `nil` when unset.
    public let onClose: (() -> Void)?
    /// The callout's tone (`.variant(_:)`).
    public let tone: CalloutType
    /// The surface treatment (`.calloutStyle(_:)`): plain or soft.
    public let calloutStyle: CalloutStyle
    /// Whether `.showsIcon(_:)` leaves the stock icon on.
    public let showsIcon: Bool
    /// What VoiceOver reads for the leading indicator, before the text: the
    /// `.statusLabel(_:)` override, else the tone's name while the stock icon
    /// shows; `nil` when a `.leading { }` slot keeps its own label.
    public let statusLabel: String?
    /// The row's vertical alignment (`.alignment(_:)`, `.firstTextBaseline`
    /// when unset).
    public let alignment: VerticalAlignment
    /// Whether `.fullWidth(_:)` asked the chrome to stretch to the offered width.
    public let isFullWidth: Bool
    /// Whether the callout is enabled (`.disabled(_:)` in the environment).
    public let isEnabled: Bool
}

extension CalloutChromeStyleConfiguration {
    /// Whether any trailing accessory is present.
    var hasTrailing: Bool { trailing != nil || actionButton != nil || closeButton != nil }
}

/// Draws a callout's chrome. Implement `makeBody` to lay out the
/// configuration's leading indicator, text and trailing accessories and paint
/// the surface around them. Set one with `.calloutChromeStyle(_:)`; the
/// default is ``DefaultCalloutChromeStyle``.
///
/// The style draws; `Callout` keeps the behaviour. The action and dismiss
/// buttons arrive wired, link taps are routed for whatever the style renders,
/// and the leading indicator already carries the VoiceOver status label.
///
/// The style applies to every `Callout` below the view it's set on, including
/// the callouts ThemeKit composes inside other components (`Upload`'s status
/// line). Set it on the callout itself to restyle only that callout.
///
/// ```swift
/// struct BorderedCalloutChrome: CalloutChromeStyle {
///     func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
///         BorderedCallout(configuration: configuration)
///     }
/// }
///
/// private struct BorderedCallout: View {
///     let configuration: CalloutChromeStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         let tone = theme.resolve(semantic)
///         HStack(alignment: configuration.alignment, spacing: Theme.SpacingKey.sm.value) {
///             configuration.leading.foregroundStyle(tone.accent)
///             configuration.content
///                 .textStyle(.bodyBase400)
///                 .foregroundStyle(theme.text(.textPrimary))
///                 .frame(maxWidth: configuration.isFullWidth ? .infinity : nil, alignment: .leading)
///             configuration.trailing
///             configuration.actionButton.foregroundStyle(tone.accent)
///             configuration.closeButton.foregroundStyle(theme.text(.textTertiary))
///         }
///         .padding(Theme.SpacingKey.sm.value)
///         .background(tone.soft, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value))
///         .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value).strokeBorder(tone.border))
///     }
///
///     private var semantic: SemanticColor {
///         switch configuration.tone {
///         case .neutral: return .neutral
///         case .info: return .info
///         case .success: return .success
///         case .warning: return .warning
///         case .error: return .error
///         case .accent: return .primary
///         }
///     }
/// }
/// ```
public protocol CalloutChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CalloutChromeStyleConfiguration) -> Body
}

/// The stock callout chrome — exactly the look `Callout` draws with no style
/// set: a first-baseline row (or the `.alignment(_:)` you set) with `xs`
/// spacing; the text in `bodySm400`; icon and text in the tone's accent
/// colour; trailing accessories pushed to the end; and, for the soft surface,
/// the tone's light fill on an `xs`-radius rectangle with `sm` / `xs` padding.
/// Linked text is drawn by ``InlineText``, as the stock callout draws it, so an
/// environment ``InlineTextStyle`` paints it here too. It ignores `isEnabled`
/// (the buttons disable natively). Reads the active `\.theme`, so an injected
/// theme re-skins it too.
public struct DefaultCalloutChromeStyle: CalloutChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        DefaultCalloutChrome(configuration: configuration)
    }
}

private struct DefaultCalloutChrome: View {
    let configuration: CalloutChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: configuration.alignment, spacing: Theme.SpacingKey.xs.value) {
            configuration.leading
            text
            if configuration.hasTrailing {
                Spacer(minLength: Theme.SpacingKey.sm.value)
                configuration.trailing
                configuration.actionButton
                configuration.closeButton
            }
        }
        .modifier(CalloutWidth(isFullWidth: configuration.isFullWidth))
        .foregroundStyle(configuration.tone.accent(theme))
        .padding(.horizontal, configuration.calloutStyle == .soft ? Theme.SpacingKey.sm.value : 0)
        .padding(.vertical, configuration.calloutStyle == .soft ? Theme.SpacingKey.xs.value : 0)
        .background {
            if configuration.calloutStyle == .soft {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                    .fill(configuration.tone.soft(theme))
            }
        }
    }

    /// Plain text takes the whole text style; linked text goes through
    /// `InlineText` with the tone as its base colour — the stock callout's own
    /// composition, so the environment `InlineTextStyle` reaches it. Its link
    /// taps route to the links' actions.
    @ViewBuilder private var text: some View {
        if configuration.links.isEmpty {
            configuration.content.textStyle(.bodySm400)
        } else {
            InlineText(configuration.text, links: configuration.links)
                .inlineStyle(.bodySm400)
                .baseColorOverride(configuration.tone.accent(theme))
        }
    }
}

/// Stretches a callout row to the offered width, leading-aligned, inside its
/// chrome; leaves it untouched when off.
struct CalloutWidth: ViewModifier {
    let isFullWidth: Bool

    func body(content: Content) -> some View {
        if isFullWidth {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
        }
    }
}

public extension CalloutChromeStyle where Self == DefaultCalloutChromeStyle {
    /// The stock chrome — what `Callout` draws with no style set.
    static var `default`: DefaultCalloutChromeStyle { DefaultCalloutChromeStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCalloutChromeStyle: CalloutChromeStyle {
    /// `true` only for the environment key's stock default below. `Callout`
    /// checks it: while the environment still carries the default it draws its
    /// own chrome, unchanged; any style set with `.calloutChromeStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (CalloutChromeStyleConfiguration) -> AnyView
    init<S: CalloutChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CalloutChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyCalloutChromeStyle(DefaultCalloutChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var calloutChromeStyle: AnyCalloutChromeStyle {
        get { self[CalloutChromeStyleKey.self] }
        set { self[CalloutChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CalloutChromeStyle`` for `Callout`s in this view and its descendants.
    func calloutChromeStyle<S: CalloutChromeStyle>(_ style: sending S) -> some View {
        environment(\.calloutChromeStyle, AnyCalloutChromeStyle(style))
    }
}
