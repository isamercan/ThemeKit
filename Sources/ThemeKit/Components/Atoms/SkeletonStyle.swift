//
//  SkeletonStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for skeleton placeholders. The paint a
//  loading placeholder uses — its fill, sweep or pulse — lives in a
//  `SkeletonStyle` you set with `.skeletonStyle(_:)`, so a host design system
//  can draw its own placeholder while ThemeKit keeps the loading behaviour.
//  `Skeleton`, `.skeleton(_:)`, `SkeletonGroup` and every ThemeKit component
//  that draws a placeholder go through the same gate; the stock look is
//  `DefaultSkeletonStyle`.
//
//      SkeletonGroup { … }
//          .loading(isLoading)
//          .skeletonStyle(MySkeletonStyle())
//

import SwiftUI

/// The inputs a ``SkeletonStyle`` renders: the placeholder's outline, the
/// requested animation and highlight tint, and whether it should move at all.
public struct SkeletonStyleConfiguration {
    /// The placeholder's outline. ``SkeletonShape/anyShape`` is the exact shape
    /// the stock fill uses (continuous corners), ready to fill or clip with.
    public let shape: SkeletonShape
    /// The requested animation: `.shimmer`, `.pulse` or `.none`.
    public let variant: SkeletonVariant
    /// The caller's highlight tint (`Skeleton.highlight(_:)`,
    /// `.skeleton(_:highlight:)`), or `nil` for the style's own default.
    public let highlight: SemanticColor?
    /// Whether the placeholder should animate. Already resolved: `false` for
    /// `.none`, under `.microAnimations(false)` and under Reduce Motion, so a
    /// style never reads the motion settings itself.
    public let isAnimated: Bool
}

/// Defines how a skeleton placeholder is painted. Implement `makeBody` to draw
/// the fill for `configuration.shape`. Set one with `.skeletonStyle(_:)`; the
/// default is ``DefaultSkeletonStyle``.
///
/// The style draws the placeholder only. ThemeKit keeps the rest: the block's
/// size (`Skeleton.size(width:height:)`), the loading flag and the reveal
/// cross-fade (`.skeleton(_:)`, `SkeletonGroup`), motion resolution, and
/// accessibility (a custom style's output is hidden from VoiceOver; a
/// `SkeletonGroup` announces one "Loading" element). When `variant` or
/// `isAnimated` changes, ThemeKit rebuilds the style's view without animation,
/// so a style can start its loop in `onAppear` and never has to watch for
/// changes.
///
/// The style is read from the environment, so setting it on a container also
/// restyles the placeholders ThemeKit components draw inside it: the `Card`
/// and `ListView` loading states, `Stat`, `Avatar`, `RemoteImage` and
/// `AnimatedImage`.
///
///     struct DimmingSkeletonStyle: SkeletonStyle {
///         func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
///             DimmingSkeleton(configuration: configuration)
///         }
///     }
///
///     private struct DimmingSkeleton: View {
///         @Environment(\.theme) private var theme
///         @State private var dimmed = false
///         let configuration: SkeletonStyleConfiguration
///
///         var body: some View {
///             configuration.shape.anyShape
///                 .fill(theme.resolve(configuration.highlight ?? .neutral).soft)
///                 .opacity(dimmed ? 0.6 : 1)
///                 .onAppear {
///                     guard configuration.isAnimated else { return }
///                     withAnimation(.easeInOut(duration: 0.8).repeatForever()) { dimmed = true }
///                 }
///         }
///     }
public protocol SkeletonStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SkeletonStyleConfiguration) -> Body
}

/// The stock placeholder: the skeleton base token fill with a traveling
/// highlight sweep (`.shimmer`) or a breathing opacity (`.pulse`), and a static
/// fill when `isAnimated` is `false`. The sweep is the highlight's soft shade,
/// or a translucent white surface by default. Reads the active `\.theme`, so an
/// injected theme re-skins it too.
public struct DefaultSkeletonStyle: SkeletonStyle, Sendable {
    public init() {}
    public func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
        DefaultSkeletonChrome(configuration: configuration)
    }
}

public extension SkeletonStyle where Self == DefaultSkeletonStyle {
    /// The stock shimmer / pulse placeholder.
    static var `default`: DefaultSkeletonStyle { DefaultSkeletonStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySkeletonStyle: SkeletonStyle {
    /// `true` only for the environment key's stock default below. While the
    /// environment still carries it, placeholders draw the built-in fill
    /// directly (the pre-style render path); any style set with
    /// `.skeletonStyle(_:)` — `.default` included — is unmarked and goes
    /// through `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (SkeletonStyleConfiguration) -> AnyView
    init<S: SkeletonStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SkeletonStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SkeletonStyleKey: EnvironmentKey {
    static let defaultValue = AnySkeletonStyle(DefaultSkeletonStyle(), isDefault: true)
}

extension EnvironmentValues {
    var skeletonStyle: AnySkeletonStyle {
        get { self[SkeletonStyleKey.self] }
        set { self[SkeletonStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SkeletonStyle`` for skeleton placeholders in this view and its
    /// descendants — `Skeleton`, `.skeleton(_:)`, and the placeholders ThemeKit
    /// components draw.
    func skeletonStyle<S: SkeletonStyle>(_ style: sending S) -> some View {
        environment(\.skeletonStyle, AnySkeletonStyle(style))
    }
}
