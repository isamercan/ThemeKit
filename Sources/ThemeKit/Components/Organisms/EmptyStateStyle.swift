//
//  EmptyStateStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 22.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `EmptyState` — the media / title /
//  message / actions block a screen shows when it has nothing to list. The
//  whole block — the media's shape and tint, the type of the title and message,
//  where the actions sit and which buttons draw them, the spacing between them
//  and the width the block fills — lives in an `EmptyStateStyle` you set with
//  `.emptyStateStyle(_:)`, so a host design system can draw its own empty state
//  while `EmptyState` keeps the content model.
//
//      EmptyState("No results found")
//          .icon("magnifyingglass")
//          .message("Try adjusting your search or filters.")
//          .primaryAction("Clear filters") { reset() }
//          .emptyStateStyle(HostEmptyStateStyle())
//
//  `EmptyState` keeps the content model: which media variant the caller chose
//  (SF Symbol, `Image` or animated URL) and the stock media view built from it,
//  the message's inline links and their tap routing, the rule that a custom
//  `.actions { }` slot replaces the stock buttons, and the resolved icon tints
//  and sizes a style can reuse.
//
//  Scope: `EmptyState` itself, wherever it is placed — including the ones
//  ThemeKit composes (`Agenda`'s empty day list, `CommandPalette`'s no-match
//  block). `ResultView`, which generalizes the same shape with its own slots,
//  is not drawn through this style.
//

import SwiftUI

/// Which media variant the caller chose, for a style that draws the media
/// itself rather than placing ``EmptyStateStyleConfiguration/media``.
///
/// The payload is exactly what the caller passed: the SF Symbol name from
/// ``EmptyState/icon(_:)`` (or the stock `"tray"`), the host's own `Image`, or
/// the animated illustration's URL — which may be `nil`, as
/// `EmptyState(animatedURL:)` accepts.
public enum EmptyStateMedia {
    /// An SF Symbol in the faded circle — the stock media. The payload is the
    /// symbol name.
    case symbol(String)
    /// The host's own illustration, as passed to `EmptyState(image:title:)`.
    case image(Image)
    /// An animated illustration (GIF / APNG), as passed to
    /// `EmptyState(animatedURL:title:)`; `nil` when the caller had no URL yet.
    case animated(URL?)
}

/// One call-to-action an empty state offers.
///
/// It arrives resolved: the title as the caller wrote it, beside a ``perform``
/// closure that is exactly what the stock button calls. A style draws the
/// button however it likes and calls ``perform`` when it's tapped.
public struct EmptyStateStyleAction {
    /// The button's title, as passed to ``EmptyState/primaryAction(_:action:)``
    /// / ``EmptyState/secondaryAction(_:action:)``.
    public let title: String
    /// Runs the caller's handler — exactly what the stock button calls.
    public let perform: () -> Void
}

/// The inputs an ``EmptyStateStyle`` renders: the block's raw strings, the
/// media (both as a variant to switch on and as a view to place), the two
/// actions, the custom actions slot, and the icon metrics and tints the stock
/// media keeps.
///
/// The strings arrive raw, not as pre-styled `Text`, so a style picks its own
/// type styles and colours; ``messageContent`` is there for the message that
/// carries inline links, so a style never re-implements the link marking or
/// its tap routing. Fields a style doesn't use are simply ignored; new fields
/// may be added in a minor release.
public struct EmptyStateStyleConfiguration {
    /// The title (`EmptyState("…")`); `nil` when the caller passed none.
    public let title: String?
    /// The line under the title (``EmptyState/message(_:)``); `nil` when unset.
    ///
    /// It is the raw string even when the caller attached links — draw it as
    /// plain text only when ``messageLinks`` is empty, or use
    /// ``messageContent``, which carries them.
    public let message: String?
    /// The message's inline links (``EmptyState/message(_:links:)``), each a
    /// substring and the handler its tap runs; empty when the message is plain.
    ///
    /// For a style that routes the taps itself. A style that draws
    /// ``messageContent`` gets the routing for free.
    public let messageLinks: [(substring: String, action: () -> Void)]
    /// ``message`` ready to draw, with its links marked and routed: a `Text`
    /// with no font and no colour of its own, so `.textStyle(_:)` /
    /// `.font(_:)` and `.foregroundStyle(_:)` applied to it take effect while
    /// the link runs keep their own tint and underline. `nil` when there is no
    /// message.
    ///
    /// Use it (rather than `Text(configuration.message)`) whenever the message
    /// may carry links: it routes a tapped link to its handler on its own, the
    /// same way `InlineText` does on the stock path.
    public let messageContent: AnyView?
    /// The media the caller chose, for a style that draws it itself. Place
    /// ``media`` instead to keep the stock one.
    public let mediaKind: EmptyStateMedia
    /// The stock media, ready to place: the SF Symbol in its faded circle, or
    /// the host's `Image` / animated illustration fitted to
    /// ``imageMaxHeight``. It carries the resolved tints and sizes below, so a
    /// style that only relays the media keeps every media modifier working.
    public let media: AnyView
    /// The primary call to action; `nil` when the empty state has none.
    /// ``EmptyState/primaryAction(_:action:)`` offers one when both the title
    /// and the handler are set — the stock block never draws a button it can't
    /// trigger.
    public let primaryAction: EmptyStateStyleAction?
    /// The secondary call to action; `nil` when unset. See ``primaryAction``
    /// for when it is offered.
    public let secondaryAction: EmptyStateStyleAction?
    /// The ``EmptyState/actions(_:)`` slot, exactly as written; `nil` when
    /// unset. When it is set it *replaces* the stock buttons, which is why
    /// ``primaryAction`` can be non-`nil` beside it: draw the slot when it's
    /// there.
    public let actions: AnyView?
    /// The diameter of the stock symbol's circle
    /// (``EmptyState/iconCircleSize(_:)``, default 88), for a style that draws
    /// its own badge. The stock glyph is 36% of it.
    public let iconCircleSize: CGFloat
    /// The glyph's colour, already resolved against the environment theme:
    /// ``EmptyState/iconForeground(_:)`` when the caller set one, else the
    /// stock `fgHero`.
    public let iconForeground: Color
    /// The circle's fill, already resolved: ``EmptyState/iconBackground(_:)``
    /// when the caller set one, else the stock `bgElevatorTertiary`.
    public let iconBackground: Color
    /// The maximum height of the `Image` / animated illustration
    /// (``EmptyState/imageMaxHeight(_:)``, default 160). It is already applied
    /// to ``media``; a style that lays the illustration out itself applies it.
    public let imageMaxHeight: CGFloat
    /// The stock block keeps its action stack whenever an action *title* was
    /// set — even when the handler that would trigger the button is missing,
    /// in which case the stack is there but empty. Internal: it exists so
    /// ``DefaultEmptyStateStyle`` can mirror the built-in block down to that
    /// edge, and a host style has no use for it — draw from ``primaryAction``
    /// and ``secondaryAction``, which are `nil` unless a button can be drawn.
    let keepsStockActionStack: Bool
}

/// Draws an `EmptyState`. Implement `makeBody` to lay out the configuration's
/// media, title, message and actions on your own block. Set one with
/// `.emptyStateStyle(_:)`; the default is ``DefaultEmptyStateStyle``.
///
/// **The style draws the whole block:** the media (place
/// ``EmptyStateStyleConfiguration/media`` or draw your own from
/// ``EmptyStateStyleConfiguration/mediaKind``), the type of the title and the
/// message, the buttons, the spacing between the parts, the alignment, and the
/// width the block fills — ThemeKit wraps nothing around a custom body, so a
/// block that should span its container sets its own
/// `.frame(maxWidth: .infinity)`.
///
/// **`EmptyState` keeps the content model:** which media variant the caller
/// chose and the stock view built from it, the resolved icon tints and sizes,
/// the message's inline links and their tap routing (through
/// ``EmptyStateStyleConfiguration/messageContent``), the actions' handlers, and
/// the rule that a custom ``EmptyState/actions(_:)`` slot replaces the stock
/// buttons. Call each action's ``EmptyStateStyleAction/perform`` as it arrives.
///
/// **What reaches the style.** Every empty state the component can hold: any of
/// the three media variants, a title alone or with a message (plain or with
/// inline links), no actions, one, two, or the custom slot.
///
/// **Where to set it.** On the `EmptyState` itself or on any ancestor. One
/// style at the root reskins every empty state at once — including the ones
/// ThemeKit composes inside `Agenda` and `CommandPalette`.
///
/// ```swift
/// struct HostEmptyStateStyle: EmptyStateStyle {
///     func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
///         HostEmptyStateBody(configuration: configuration)
///     }
/// }
///
/// private struct HostEmptyStateBody: View {
///     let configuration: EmptyStateStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         HStack(alignment: .top, spacing: Theme.SpacingKey.base.value) {
///             configuration.media
///             VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
///                 if let title = configuration.title {
///                     Text(title).textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary))
///                 }
///                 configuration.messageContent?
///                     .textStyle(.bodySm400)
///                     .foregroundStyle(theme.text(.textSecondary))
///                 if let actions = configuration.actions {
///                     actions
///                 } else if let primary = configuration.primaryAction {
///                     ThemeButton(primary.title, action: primary.perform).size(.small)
///                 }
///             }
///             Spacer(minLength: 0)
///         }
///     }
/// }
/// ```
public protocol EmptyStateStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: EmptyStateStyleConfiguration) -> Body
}

/// The stock block — exactly what `EmptyState` draws with no style set: the
/// media over a centred `headingBase` title and `bodyBase400` message, the
/// `PrimaryButton` / `SecondaryButton` stack (or the custom actions slot) under
/// them, `base` spacing between the three groups and `sm` inside the text and
/// button groups, spanning the full width. Reads the active `\.theme`, so an
/// injected theme re-skins it too.
public struct DefaultEmptyStateStyle: EmptyStateStyle, Sendable {
    public init() {}
    public func makeBody(configuration: EmptyStateStyleConfiguration) -> some View {
        DefaultEmptyStateChrome(configuration: configuration)
    }
}

/// Mirrors `EmptyState`'s built-in body from the configuration.
/// `EmptyStateStyleTests` renders both and compares the pixels, so the two
/// can't drift apart unnoticed.
private struct DefaultEmptyStateChrome: View {
    let configuration: EmptyStateStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            configuration.media

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let title = configuration.title {
                    Text(title)
                        .textStyle(.headingBase)
                        .foregroundStyle(theme.text(.textPrimary))
                        .multilineTextAlignment(.center)
                }
                if let message = configuration.message {
                    Group {
                        if configuration.messageLinks.isEmpty {
                            Text(message)
                                .textStyle(.bodyBase400)
                                .foregroundStyle(theme.text(.textSecondary))
                        } else {
                            InlineText(message, links: configuration.messageLinks)
                                .inlineStyle(.bodyBase400)   // base color defaults to textSecondary
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }

            if let actions = configuration.actions {
                // Custom actions replace the stock button stack (D4).
                actions
            } else if configuration.keepsStockActionStack {
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    if let primary = configuration.primaryAction {
                        PrimaryButton(primary.title, action: primary.perform)
                    }
                    if let secondary = configuration.secondaryAction {
                        SecondaryButton(secondary.title, action: secondary.perform)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

public extension EmptyStateStyle where Self == DefaultEmptyStateStyle {
    /// The stock empty state (today's `EmptyState` look).
    static var `default`: DefaultEmptyStateStyle { DefaultEmptyStateStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyEmptyStateStyle: EmptyStateStyle {
    /// `true` only for the environment key's stock default below. `EmptyState`
    /// checks it: while the environment still carries the default it draws its
    /// own body, unchanged; any style set with `.emptyStateStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (EmptyStateStyleConfiguration) -> AnyView
    init<S: EmptyStateStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: EmptyStateStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct EmptyStateStyleKey: EnvironmentKey {
    static let defaultValue = AnyEmptyStateStyle(DefaultEmptyStateStyle(), isDefault: true)
}

extension EnvironmentValues {
    var emptyStateStyle: AnyEmptyStateStyle {
        get { self[EmptyStateStyleKey.self] }
        set { self[EmptyStateStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``EmptyStateStyle`` for the `EmptyState`s in this view and its
    /// descendants.
    func emptyStateStyle<S: EmptyStateStyle>(_ style: sending S) -> some View {
        environment(\.emptyStateStyle, AnyEmptyStateStyle(style))
    }
}
