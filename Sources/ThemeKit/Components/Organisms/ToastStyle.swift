//
//  ToastStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `AlertToast` (and everything built
//  on it: the `.toast(...)` presenter and the `feedbackHost` toast stack). The
//  shell chrome — variant fill, foreground tint, padding, corner shape — lives
//  in a `ToastStyle` you set with `.toastStyle(_:)`, so a toast can be reskinned
//  — capsule, glass, outlined — without editing `AlertToast`. The content row
//  (icon/spinner + title/message + action + close) stays component-owned and is
//  handed to the style pre-composed. The default style reproduces the original
//  look, so this is additive and non-breaking.
//
//      AlertToast("Saved").variant(.success)
//          .toastStyle(.capsule)        // or a custom ToastStyle
//

import SwiftUI

/// The inputs a `ToastStyle` renders: the toast's already-composed content row
/// (icon/spinner + title/message + action/close block), plus the status variant
/// that drives fill/foreground and the loading flag for styles that want to
/// key chrome off an in-flight state.
public struct ToastStyleConfiguration {
    /// The toast's content row, type-erased (mirrors `ButtonStyleConfiguration.label`).
    public let content: AnyView
    /// Status treatment: success / warning / danger / info (drives fill + tint).
    public let variant: AlertToastType
    /// Whether the toast is showing its loading spinner instead of the status icon.
    public let isLoading: Bool

    init(content: AnyView, variant: AlertToastType, isLoading: Bool = false) {
        self.content = content
        self.variant = variant
        self.isLoading = isLoading
    }
}

/// Defines a toast's shell appearance. Implement `makeBody` to wrap the
/// configuration's content with a surface (fill, shape, padding, shadow). Set
/// one with `.toastStyle(_:)`; the default is ``DefaultToastStyle``.
public protocol ToastStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ToastStyleConfiguration) -> Body
}

// MARK: - Default style

/// The stock toast shell — `AlertToast`'s original look: the variant's solid
/// system fill, the variant foreground tint, 12pt vertical / `md` horizontal
/// padding, and a small continuous rounded rectangle. Reads the active
/// `\.theme`, so an injected theme re-skins it too.
public struct DefaultToastStyle: ToastStyle {
    public init() {}
    public func makeBody(configuration: ToastStyleConfiguration) -> some View {
        DefaultToastChrome(configuration: configuration)
    }
}

private struct DefaultToastChrome: View {
    let configuration: ToastStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .foregroundStyle(configuration.variant.foreground(theme))
            .padding(.vertical, 12)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .background(configuration.variant.background(theme),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

// MARK: - Capsule style

/// A compact pill toast: the same variant fill and tint on a capsule, with
/// tighter vertical padding and a soft token shadow to lift it off the content.
/// An example custom `ToastStyle` consumers can use directly or model their own on.
public struct CapsuleToastStyle: ToastStyle {
    public init() {}
    public func makeBody(configuration: ToastStyleConfiguration) -> some View {
        CapsuleToastChrome(configuration: configuration)
    }
}

private struct CapsuleToastChrome: View {
    let configuration: ToastStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .foregroundStyle(configuration.variant.foreground(theme))
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .background(configuration.variant.background(theme), in: Capsule(style: .continuous))
            .themeShadow(.soft)
    }
}

// MARK: - Static accessors

public extension ToastStyle where Self == DefaultToastStyle {
    /// The stock toast shell (solid variant fill + rounded rectangle).
    static var `default`: DefaultToastStyle { DefaultToastStyle() }
}

public extension ToastStyle where Self == CapsuleToastStyle {
    /// A compact capsule toast with a soft shadow.
    static var capsule: CapsuleToastStyle { CapsuleToastStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyToastStyle: ToastStyle {
    private let _makeBody: @MainActor (ToastStyleConfiguration) -> AnyView
    /// `true` only for the environment's stock value — i.e. no `.toastStyle(_:)`
    /// anywhere up the tree. `AlertToast` keys off this to render its original
    /// inline shell (pixel-identical by construction) and only routes through
    /// `makeBody` when a style was explicitly set.
    let isDefault: Bool
    init<S: ToastStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ToastStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ToastStyleKey: EnvironmentKey {
    static let defaultValue = AnyToastStyle(DefaultToastStyle(), isDefault: true)
}

extension EnvironmentValues {
    var toastStyle: AnyToastStyle {
        get { self[ToastStyleKey.self] }
        set { self[ToastStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ToastStyle`` for `AlertToast`s (including toasts shown via
    /// `.toast(...)` and `feedbackHost`) in this view and its descendants.
    func toastStyle<S: ToastStyle>(_ style: sending S) -> some View {
        environment(\.toastStyle, AnyToastStyle(style))
    }
}
