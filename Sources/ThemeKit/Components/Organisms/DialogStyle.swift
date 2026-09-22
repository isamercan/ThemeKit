//
//  DialogStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 22.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for the fixed-layout dialog card — the
//  title / message / actions card that `.dialog(isPresented:title:…)` and
//  `FeedbackPresenter.confirm(…)` draw. The whole card — its surface, corner,
//  padding, type, buttons, kind icon, close button, width, shadow and its margin
//  from the screen's edges — lives in a `DialogStyle` you set with
//  `.dialogStyle(_:)`, so a host design system can draw the card with its own
//  chrome while ThemeKit keeps the behaviour.
//
//      content
//          .dialog(isPresented: $showDelete, title: "Delete trip?",
//                  message: "This can't be undone.",
//                  primaryTitle: "Delete", onPrimary: { await delete() },
//                  secondaryTitle: "Cancel", onSecondary: {}, kind: .error)
//          .dialogStyle(HostDialogStyle())
//
//  ThemeKit keeps the presentation: the scrim, the placement, the transitions,
//  the swipe / scrim / VoiceOver-escape dismissal, the modal trait, the async
//  primary's loading (the spinner flag and the dismissal once the work ends),
//  and dismissal on the primary, secondary and close actions.
//
//  Scope: only the fixed-layout card. `.dialog(content:footer:)`,
//  `.dialog(header:content:footer:)`, `.dialog(content:)` and `AlertDialog`
//  are not drawn through this style.
//

import SwiftUI

/// One action a dialog card offers.
///
/// It arrives resolved: the title as the caller wrote it, the colour the caller
/// asked for, and the loading and disabled state ThemeKit is tracking, beside a
/// ``perform`` closure that already carries the dialog's behaviour. A style
/// draws the button however it likes and calls ``perform`` when it's tapped.
public struct DialogStyleAction {
    /// The button's title, as passed to the dialog (`primaryTitle` /
    /// `secondaryTitle`).
    public let title: String
    /// The intent colour the caller asked for — `kind`'s colour on `.dialog(kind:)`, `primaryKind`'s on
    /// `confirm(...)`; `nil` for the stock primary. Always `nil` on the secondary.
    ///
    /// `confirm(...)` always sets it: its `primaryKind` defaults to `.info`,
    /// whose colour is `.primary`. Resolve it from the environment theme
    /// (`theme.resolve(color)`), never from `Theme.shared`.
    public let color: SemanticColor?
    /// The primary's async work is running (Ant Modal confirmLoading) — spin it.
    ///
    /// Only an async `onPrimary` on `.dialog(…)` ever sets it; `confirm(...)`'s
    /// primary is synchronous. Always `false` on the secondary.
    public let isLoading: Bool
    /// The secondary while the primary is loading — disable it.
    ///
    /// Always `false` on the primary: the stock card never disables it.
    public let isDisabled: Bool
    /// Runs the action with ThemeKit's loading and dismissal built in (exactly what the stock buttons call).
    ///
    /// For the primary on `.dialog(…)` that starts the async work, sets
    /// ``isLoading`` while it runs and dismisses the dialog when it ends; for the
    /// secondary it dismisses and then calls the caller's handler; on
    /// `confirm(...)` both call the caller's handler and dismiss. While
    /// ``isLoading`` or ``isDisabled`` is set it does nothing — the guard the
    /// stock buttons apply by ignoring the tap — so a host button without a
    /// loading guard of its own can't start the work twice.
    public let perform: () -> Void
}

/// The inputs a ``DialogStyle`` renders: the card's raw strings, the intent
/// whose icon the stock card shows, the two actions, the close handler, and the
/// width and margin the stock card keeps.
///
/// The strings arrive raw, not as pre-styled `Text`, so a style picks its own
/// type styles and colours. Fields a style doesn't use are simply ignored; new
/// fields may be added in a minor release.
public struct DialogStyleConfiguration {
    /// The dialog's title (`title:`).
    public let title: String
    /// The line under the title (`message:`); `nil` when unset.
    public let message: String?
    /// The intent whose icon the stock card shows over the title; `nil` shows none.
    ///
    /// Only `.dialog(kind:)` sets it; `confirm(...)` shows no icon, so it is
    /// always `nil` there (its `primaryKind` reaches the style as the primary's
    /// ``DialogStyleAction/color``). The stock icon is `kind.systemImage` in
    /// `kind.semanticColor`'s accent.
    public let kind: FeedbackKind?
    /// The primary action — always present.
    public let primaryAction: DialogStyleAction
    /// The secondary action; `nil` when the dialog has none. `.dialog(…)` offers
    /// one when both `secondaryTitle` and `onSecondary` are set, `confirm(...)`
    /// when `secondaryTitle` isn't `nil` (it defaults to "Cancel").
    public let secondaryAction: DialogStyleAction?
    /// The close button's handler when the dialog is closable; `nil` otherwise.
    ///
    /// It dismisses the dialog. `.dialog(closable: true)` sets it — except while
    /// the primary's async work runs, when the stock card hides its close button
    /// too; `confirm(...)` has no close button. A style that draws the button
    /// gives it a VoiceOver label (the stock one says "Close").
    public let onClose: (() -> Void)?
    /// The card's maximum width as the caller sized it (`width:` → `size:` → 320).
    ///
    /// `size: .full` makes it `.infinity`, so apply it as
    /// `.frame(maxWidth: configuration.maxWidth)`, never as a fixed width.
    public let maxWidth: CGFloat
    /// The margin the stock card keeps from the screen's edges (`Theme.SpacingKey.lg`), for a style that wants the same.
    ///
    /// ThemeKit adds no margin around a custom style's card, so a card that
    /// should keep the stock clearance pads itself by this on every edge.
    public let stockMargin: CGFloat
}

/// Draws the fixed-layout dialog card. Implement `makeBody` to lay out the
/// configuration's title, message, kind icon, actions and close button on your
/// own card. Set one with `.dialogStyle(_:)`; the default is
/// ``DefaultDialogStyle``.
///
/// **The style draws the whole card:** the surface, the corner, the padding,
/// the type, the buttons, the kind icon, the close button, the width, the
/// shadow, and the card's margin from the screen's edges — ThemeKit adds none
/// around a custom card, so a style that wants the stock clearance pads by
/// ``DialogStyleConfiguration/stockMargin``. The stock card's corner comes from
/// `.dialogCornerRadius(_:)`; a custom style owns its own corner.
///
/// **ThemeKit keeps the behaviour:** the scrim, the placement, the transitions,
/// swipe / scrim / VoiceOver-escape dismissal, the modal trait, the async
/// primary's loading (the ``DialogStyleAction/isLoading`` flag, and the
/// dismissal once the work ends), and dismissal on the primary, secondary and
/// close actions. Call each action's ``DialogStyleAction/perform`` and
/// ``DialogStyleConfiguration/onClose`` as they arrive.
///
/// **What reaches the style.** The card `.dialog(isPresented:title:…)` draws and
/// the one `FeedbackPresenter.confirm(…)` draws — title alone or with a
/// message, one or two actions, a kind icon, a close button, a loading primary,
/// and any width `width:` / `size:` sets (`.full` is `.infinity`). The other
/// dialog forms — `.dialog(content:footer:)`, `.dialog(header:content:footer:)`,
/// `.dialog(content:)` — and `AlertDialog` don't consult it.
///
/// **Where to set it.** The card is drawn in an overlay at the modifier that
/// presents it, so set the style on the `.dialog(…)` call's result or an
/// ancestor, not on the view the dialog is attached to; for `confirm(…)`, on the
/// `.feedbackHost()` call's result or an ancestor. One style at the root
/// reskins every such dialog; one on a single `.dialog(…)` scopes it there.
///
/// ```swift
/// struct HostDialogStyle: DialogStyle {
///     func makeBody(configuration: DialogStyleConfiguration) -> some View {
///         HostDialogCard(configuration: configuration)
///     }
/// }
///
/// private struct HostDialogCard: View {
///     let configuration: DialogStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
///             Text(configuration.title)
///                 .textStyle(.labelLg700)
///                 .foregroundStyle(theme.text(.textPrimary))
///             if let message = configuration.message {
///                 Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
///             }
///             HStack(spacing: Theme.SpacingKey.sm.value) {
///                 Spacer(minLength: 0)
///                 if let secondary = configuration.secondaryAction {
///                     ThemeButton(secondary.title, action: secondary.perform)
///                         .variant(.ghost).disabled(secondary.isDisabled)
///                 }
///                 let primary = configuration.primaryAction
///                 ThemeButton(primary.title, action: primary.perform)
///                     .color(primary.color ?? .primary).loading(primary.isLoading)
///             }
///         }
///         .padding(Theme.SpacingKey.md.value)
///         .frame(maxWidth: configuration.maxWidth)
///         .background(theme.background(.bgWhite),
///                     in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
///         .padding(configuration.stockMargin)
///     }
/// }
/// ```
public protocol DialogStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: DialogStyleConfiguration) -> Body
}

/// The stock card — exactly the card `.dialog(isPresented:title:…)` and
/// `confirm(…)` draw with no style set: the kind icon over a centred
/// `headingSm` title and `bodyBase400` message, the primary (a full-width
/// `ThemeButton` in the action's colour, else a `PrimaryButton`) over an
/// `OutlineButton` secondary, `lg` padding, the given max width, the floating
/// glass chrome in the `.dialogCornerRadius(_:)` role, a top-trailing close
/// button, the elevated shadow and the `lg` margin. Reads the active `\.theme`,
/// so an injected theme re-skins it too.
public struct DefaultDialogStyle: DialogStyle, Sendable {
    public init() {}
    public func makeBody(configuration: DialogStyleConfiguration) -> some View {
        DefaultDialogChrome(configuration: configuration)
    }
}

/// Mirrors `DialogCard`'s built-in body, margin included, from the
/// configuration. `DialogStyleTests` renders both and compares the pixels, so
/// the two can't drift apart unnoticed.
private struct DefaultDialogChrome: View {
    let configuration: DialogStyleConfiguration
    @Environment(\.theme) private var theme
    @Environment(\.dialogCornerRadius) private var cornerRadiusRole

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if let kind = configuration.kind {
                Icon(systemName: kind.systemImage).size(.xl).colorOverride(theme.resolve(kind.semanticColor).accent)
            }
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(configuration.title)
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let message = configuration.message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                primaryButton(configuration.primaryAction)
                if let secondary = configuration.secondaryAction {
                    OutlineButton(secondary.title, action: secondary.perform).disabled(secondary.isDisabled)
                }
            }
        }
        .padding(Theme.SpacingKey.lg.value)
        .frame(maxWidth: configuration.maxWidth)
        // Floating modal chrome → Liquid Glass on OS 26+, Material below, opaque under Reduce Transparency.
        .glassChrome(in: RoundedRectangle(cornerRadius: theme.radius(cornerRadiusRole), style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onClose = configuration.onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark").size(.sm).colorOverride(theme.text(.textTertiary))
                        .padding(Theme.SpacingKey.md.value)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Close"))
            }
        }
        .themeShadow(.elevated)
        .padding(configuration.stockMargin)
    }

    @ViewBuilder
    private func primaryButton(_ primary: DialogStyleAction) -> some View {
        if let color = primary.color {
            ThemeButton(primary.title, action: primary.perform)
                .color(color).fullWidth().loading(primary.isLoading)
        } else {
            PrimaryButton(primary.title, action: primary.perform).loading(primary.isLoading)
        }
    }
}

public extension DialogStyle where Self == DefaultDialogStyle {
    /// The stock dialog card (today's `.dialog(isPresented:title:…)` /
    /// `confirm(…)` look).
    static var `default`: DefaultDialogStyle { DefaultDialogStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyDialogStyle: DialogStyle {
    /// `true` only for the environment key's stock default below. `DialogCard`
    /// checks it: while the environment still carries the default it draws its
    /// own body, unchanged; any style set with `.dialogStyle(_:)` — including
    /// `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (DialogStyleConfiguration) -> AnyView
    init<S: DialogStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: DialogStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct DialogStyleKey: EnvironmentKey {
    static let defaultValue = AnyDialogStyle(DefaultDialogStyle(), isDefault: true)
}

extension EnvironmentValues {
    var dialogStyle: AnyDialogStyle {
        get { self[DialogStyleKey.self] }
        set { self[DialogStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``DialogStyle`` for the fixed-layout dialog cards —
    /// `.dialog(isPresented:title:…)` and `FeedbackPresenter.confirm(…)` — in
    /// this view and its descendants. Set it on the `.dialog(…)` /
    /// `.feedbackHost()` call's result or an ancestor.
    func dialogStyle<S: DialogStyle>(_ style: sending S) -> some View {
        environment(\.dialogStyle, AnyDialogStyle(style))
    }
}
