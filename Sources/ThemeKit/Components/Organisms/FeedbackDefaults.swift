//
//  FeedbackDefaults.swift
//  ThemeKit
//
//  A subtree-level "house style" for toast / notification presentation — default
//  edge, auto-dismiss duration, and stack cap. Set it once with
//  `.feedbackDefaults(...)` above the `.feedbackHost(...)` and both the
//  presenter-driven feedback layer and the declarative `.toast(isPresented:)`
//  read it as their default. Additive and Open/Closed: an explicit per-call
//  argument (`toast(position:)`, `toast(duration:)`, `.toast(autoDismiss:)`)
//  still wins; this only fills the default.
//
//  ```swift
//  RootView()
//      .feedbackHost()
//      .feedbackDefaults(toastPosition: .top, toastDuration: 3)
//  ```
//

import SwiftUI

/// House defaults for toast / notification presentation. Every axis is optional;
/// `nil` keeps the component's own default, and an explicit per-call argument
/// always wins over the subtree default.
public struct FeedbackDefaults: Equatable {
    /// Default edge the toast stack anchors to. Read by the `.feedbackHost`
    /// overlay (ahead of its `toastPosition:` parameter) and by the declarative
    /// `.toast(isPresented:)`; a per-toast `position:` still wins.
    public var toastPosition: ToastPosition?
    /// Default auto-dismiss duration (seconds) for toasts and notification
    /// cards presented *without* an explicit `duration:` / `autoDismiss:`
    /// argument. Explicit durations — including `nil`-means-sticky — always win.
    public var toastDuration: Double?
    /// Default stack cap for the `.feedbackHost` toast stack (oldest drops past
    /// it). Read ahead of the host's `maxVisibleToasts:` parameter.
    public var maxVisibleToasts: Int?

    /// Inset of the toast stack from its anchored edge (default `.md`). Ant
    /// `notification.config({ top / bottom })`.
    public var toastOffset: Theme.SpacingKey?
    /// Gap between stacked toasts (default `.sm`).
    public var toastSpacing: Theme.SpacingKey?
    /// Whether toasts can be swiped away (default `true`). Ant `closable` /
    /// HeroUI `shouldAllowSwipe`.
    public var swipeToDismiss: Bool?
    /// Fire a light haptic when a toast appears (default off).
    public var hapticsOnShow: Bool?

    /// Motion token for the toast stack's insert / remove animation (default
    /// `.base`, as a spring). Gated the `MicroMotion` way — micro-animations
    /// off or system Reduce Motion on disable the motion entirely, whatever
    /// this is set to.
    public var toastMotion: Motion?
    /// Show a thin drain bar along each toast's bottom edge while its
    /// auto-dismiss countdown runs (HeroUI `shouldShowTimeoutProgress`;
    /// default off). Sticky toasts (`duration: nil`) never show it, and it is
    /// suppressed under Reduce Motion. It pauses with the countdown while the
    /// toast is being dragged.
    public var showsTimeoutProgress: Bool?
    /// Anchor for the `notify(...)` notification card (default `.top` — the
    /// historical placement). Corner anchors are logical (leading/trailing),
    /// so they mirror under RTL; the card spans the full width, so what they
    /// choose is the vertical edge it slides from.
    public var notificationPosition: ToastPosition?

    public init(toastPosition: ToastPosition? = nil, toastDuration: Double? = nil, maxVisibleToasts: Int? = nil,
                toastOffset: Theme.SpacingKey? = nil, toastSpacing: Theme.SpacingKey? = nil,
                swipeToDismiss: Bool? = nil, hapticsOnShow: Bool? = nil,
                toastMotion: Motion? = nil, showsTimeoutProgress: Bool? = nil,
                notificationPosition: ToastPosition? = nil) {
        self.toastPosition = toastPosition
        self.toastDuration = toastDuration
        self.maxVisibleToasts = maxVisibleToasts
        self.toastOffset = toastOffset
        self.toastSpacing = toastSpacing
        self.swipeToDismiss = swipeToDismiss
        self.hapticsOnShow = hapticsOnShow
        self.toastMotion = toastMotion
        self.showsTimeoutProgress = showsTimeoutProgress
        self.notificationPosition = notificationPosition
    }
}

private struct FeedbackDefaultsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = FeedbackDefaults()   // immutable empty default — safe
}

public extension EnvironmentValues {
    var feedbackDefaults: FeedbackDefaults {
        get { self[FeedbackDefaultsKey.self] }
        set { self[FeedbackDefaultsKey.self] = newValue }
    }
}

public extension View {
    /// Sets the house-style defaults for toast / notification presentation in
    /// this subtree. Only the provided fields are set (nested calls merge,
    /// inner wins per axis); an explicit per-call argument still overrides.
    ///
    /// Apply it *around* (or above) the `.feedbackHost(...)` so the host's
    /// overlays can read it:
    ///
    /// ```swift
    /// RootView()
    ///     .feedbackHost()
    ///     .feedbackDefaults(toastPosition: .top, toastDuration: 3, maxVisibleToasts: 2)
    /// ```
    func feedbackDefaults(toastPosition: ToastPosition? = nil,
                          toastDuration: Double? = nil,
                          maxVisibleToasts: Int? = nil,
                          toastOffset: Theme.SpacingKey? = nil,
                          toastSpacing: Theme.SpacingKey? = nil,
                          swipeToDismiss: Bool? = nil,
                          hapticsOnShow: Bool? = nil,
                          toastMotion: Motion? = nil,
                          showsTimeoutProgress: Bool? = nil,
                          notificationPosition: ToastPosition? = nil) -> some View {
        transformEnvironment(\.feedbackDefaults) { d in
            if let toastPosition { d.toastPosition = toastPosition }
            if let toastDuration { d.toastDuration = toastDuration }
            if let maxVisibleToasts { d.maxVisibleToasts = maxVisibleToasts }
            if let toastOffset { d.toastOffset = toastOffset }
            if let toastSpacing { d.toastSpacing = toastSpacing }
            if let swipeToDismiss { d.swipeToDismiss = swipeToDismiss }
            if let hapticsOnShow { d.hapticsOnShow = hapticsOnShow }
            if let toastMotion { d.toastMotion = toastMotion }
            if let showsTimeoutProgress { d.showsTimeoutProgress = showsTimeoutProgress }
            if let notificationPosition { d.notificationPosition = notificationPosition }
        }
    }
}

#Preview("Feedback defaults: top edge + 2s duration") {
    struct Demo: View {
        @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
        var body: some View {
            VStack(spacing: 12) {
                ThemeButton("Toast (uses defaults)") {
                    feedback.toast("Top-anchored, 2s, drain bar", kind: .success)
                }
                ThemeButton("Explicit duration wins") {
                    feedback.toast("Sticky despite the default (no drain bar)", kind: .info, duration: nil)
                }
                .variant(.outline)
                ThemeButton("Explicit position wins") {
                    feedback.toast("Bottom despite the default", kind: .neutral, position: .bottom)
                }
                .variant(.outline)
                ThemeButton("Corner toast (.topTrailing)") {
                    feedback.toast("Anchored to the trailing corner", kind: .accent, position: .topTrailing)
                }
                .variant(.outline)
                ThemeButton("Notification (bottom via default)") {
                    feedback.notify("Synced", message: "See the sync log for details.",
                                    links: [("sync log", { print("log") })])
                }
                .variant(.outline)
            }
            .padding()
        }
    }
    return Demo()
        .feedbackHost()
        .feedbackDefaults(toastPosition: .top, toastDuration: 2, maxVisibleToasts: 2,
                          toastMotion: .slow, showsTimeoutProgress: true,
                          notificationPosition: .bottom)
}
