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

    public init(toastPosition: ToastPosition? = nil, toastDuration: Double? = nil, maxVisibleToasts: Int? = nil) {
        self.toastPosition = toastPosition
        self.toastDuration = toastDuration
        self.maxVisibleToasts = maxVisibleToasts
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
                          maxVisibleToasts: Int? = nil) -> some View {
        transformEnvironment(\.feedbackDefaults) { d in
            if let toastPosition { d.toastPosition = toastPosition }
            if let toastDuration { d.toastDuration = toastDuration }
            if let maxVisibleToasts { d.maxVisibleToasts = maxVisibleToasts }
        }
    }
}

#Preview("Feedback defaults: top edge + 1s duration") {
    struct Demo: View {
        @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
        var body: some View {
            VStack(spacing: 12) {
                ThemeButton("Toast (uses defaults)") {
                    feedback.toast("Anchored top, gone in 1s", kind: .success)
                }
                ThemeButton("Explicit duration wins") {
                    feedback.toast("Sticky despite the default", kind: .info, duration: nil)
                }
                .variant(.outline)
                ThemeButton("Explicit position wins") {
                    feedback.toast("Bottom despite the default", kind: .neutral, position: .bottom)
                }
                .variant(.outline)
            }
            .padding()
        }
    }
    return Demo()
        .feedbackHost()
        .feedbackDefaults(toastPosition: .top, toastDuration: 1, maxVisibleToasts: 2)
}
