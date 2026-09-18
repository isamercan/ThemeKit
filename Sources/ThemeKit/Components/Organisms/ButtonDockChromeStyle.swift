//
//  ButtonDockChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 18.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `.buttonDock { }`. The bar's
//  chrome — the rule along its top edge, the surface under it, the corners,
//  the padding around the content and any elevation — lives in a
//  `ButtonDockChromeStyle` you set with `.buttonDockChromeStyle(_:)`, so a host
//  design system can draw its own docked action bar while ThemeKit keeps the
//  pinning.
//
//      ScreenBody()
//          .buttonDock {
//              ButtonGroup(.horizontal) {
//                  SecondaryButton("Cancel") {}
//                  PrimaryButton("Continue") {}
//              }
//          }
//          .buttonDockChromeStyle(HostButtonDock())
//
//  `buttonDock` keeps the pinning itself — the bottom `safeAreaInset` that
//  holds the bar over the screen's content and takes its height out of the
//  content's safe area — so a host never re-implements it. The style draws
//  only what sits inside that inset.
//

import SwiftUI

/// The inputs a ``ButtonDockChromeStyle`` renders: what the host put in the
/// dock, the environment control size, and the bottom safe-area inset the bar
/// sits over.
///
/// ``content`` arrives with no padding, no surface and no rule of its own, so
/// the style owns every edge. Fields a style doesn't use are simply ignored;
/// new fields may be added in a minor release.
public struct ButtonDockChromeStyleConfiguration {
    /// What the host put in the dock, unpainted: the `@ViewBuilder` content of
    /// `buttonDock { }` exactly as it was written, with none of the stock
    /// bar's padding, surface or divider around it.
    public let content: AnyView
    /// The environment's control size (`.controlSize(_:)`), for a style with a
    /// size ramp. The stock style ignores it — the dock has one size.
    public let controlSize: ControlSize
    /// The bottom safe-area inset the bar sits over — the home-indicator strip
    /// on a device that has one, `0` where there is none.
    ///
    /// SwiftUI hands the bottom `safeAreaInset`'s content the screen's own
    /// bottom inset, so a bar that pads its content by a flat number would
    /// stack that padding on top of the strip. ThemeKit measures the inset and
    /// passes it here, so a style pads for the home indicator without reading
    /// the geometry itself: `.padding(.bottom, max(spec, inset))` to keep the
    /// spec as a floor, or `spec + inset` to sit the spec above the strip.
    ///
    /// It is `0` until the first layout pass reports it (and in an
    /// `ImageRenderer` render, which runs no layout loop), so read it as a
    /// padding amount, never as "is there a home indicator". A bar shorter than
    /// the strip reports only the part its own frame overlaps on that first
    /// pass, which `max(spec, inset)` absorbs and `spec + inset` does not.
    public let safeAreaBottomInset: CGFloat
}

/// Draws the bar of a `.buttonDock { }`. Implement `makeBody` to pad, surface
/// and rule the configuration's content. Set one with
/// `.buttonDockChromeStyle(_:)`; the default is
/// ``DefaultButtonDockChromeStyle``.
///
/// The style draws; `buttonDock` keeps the behaviour. It pins the bar to the
/// bottom edge with a `safeAreaInset`, which is what takes the bar's height out
/// of the screen content's safe area, and hands the style ``ButtonDockChromeStyleConfiguration/safeAreaBottomInset``
/// so the chrome can cover the home indicator.
///
/// **What reaches the style.** One body draws every dock a host places: a row
/// of buttons, a price beside a single button, free content stacked above a
/// button. The content arrives unpainted, so the style's padding is the only
/// padding, and it must stretch its surface across the full width itself
/// (`.frame(maxWidth: .infinity)`) — `buttonDock` proposes the screen's width
/// but applies no frame of its own.
///
/// The style applies to every `buttonDock` below the view it's set on. It is
/// read where the dock is *applied*, so set it on the `.buttonDock { }` call's
/// result or on an ancestor, not inside the dock's content.
///
/// ```swift
/// struct HostButtonDock: ButtonDockChromeStyle {
///     func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
///         HostButtonDockBody(configuration: configuration)
///     }
/// }
///
/// private struct HostButtonDockBody: View {
///     let configuration: ButtonDockChromeStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         configuration.content
///             .frame(maxWidth: .infinity)
///             .padding(.horizontal, Theme.SpacingKey.md.value)
///             .padding(.top, Theme.SpacingKey.md.value)
///             .padding(.bottom, max(Theme.SpacingKey.xl.value, configuration.safeAreaBottomInset))
///             .background(theme.background(.bgWhite))
///             .overlay(alignment: .top) {
///                 Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
///             }
///             .clipShape(ThemeUnevenRoundedRect(topLeadingRadius: Theme.RadiusRole.box.value,
///                                               topTrailingRadius: Theme.RadiusRole.box.value))
///             .themeShadow(.elevated)
///     }
/// }
/// ```
public protocol ButtonDockChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> Body
}

/// The stock dock — exactly the bar `.buttonDock { }` draws with no style set:
/// a small `DividerView` rule along the top edge, the content inset by `md` at
/// the sides and `sm` at the top, and a flat `bgWhite` surface behind both. No
/// corners, no bottom padding, no shadow. Reads the active `\.theme`, so an
/// injected theme re-skins it too.
public struct DefaultButtonDockChromeStyle: ButtonDockChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        ButtonDockSurface { configuration.content }
    }
}

/// The stock dock's padding ramp, shared by `buttonDock`'s built-in bar and
/// ``DefaultButtonDockChromeStyle`` so the two can't drift apart.
enum ButtonDockMetrics {
    /// Inset at both sides of the dock's content.
    static var horizontalPadding: CGFloat { Theme.SpacingKey.md.value }
    /// Gap between the top rule and the dock's content.
    static var topPadding: CGFloat { Theme.SpacingKey.sm.value }
}

/// The stock bar: the top rule, the padded content and the flat surface behind
/// them. Rendered by `buttonDock`'s built-in path and by
/// ``DefaultButtonDockChromeStyle``, so `.buttonDockChromeStyle(.default)`
/// draws the same pixels.
struct ButtonDockSurface<DockContent: View>: View {
    @ViewBuilder let content: DockContent
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            DividerView().size(.small)
            content
                .padding(.horizontal, ButtonDockMetrics.horizontalPadding)
                .padding(.top, ButtonDockMetrics.topPadding)
        }
        .background(theme.background(.bgWhite))
    }
}

public extension ButtonDockChromeStyle where Self == DefaultButtonDockChromeStyle {
    /// The stock docked bar (today's `buttonDock` look).
    static var `default`: DefaultButtonDockChromeStyle { DefaultButtonDockChromeStyle() }
}

// MARK: - Safe-area probe

/// Renders the environment style inside the dock's inset and keeps the bottom
/// safe-area inset it sits over up to date.
///
/// The probe is a layout-neutral background, so it changes neither the bar's
/// size nor its pixels; it exists only on the custom-style path, which is why
/// the built-in bar is byte-for-byte what it was.
struct ButtonDockChromeHost: View {
    let style: AnyButtonDockChromeStyle
    let content: AnyView
    @Environment(\.controlSize) private var controlSize
    @State private var safeAreaBottomInset: CGFloat = 0

    var body: some View {
        style.makeBody(configuration: ButtonDockChromeStyleConfiguration(
            content: content,
            controlSize: controlSize,
            safeAreaBottomInset: safeAreaBottomInset))
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ButtonDockSafeAreaKey.self,
                                           value: proxy.safeAreaInsets.bottom)
                }
            )
            .onPreferenceChange(ButtonDockSafeAreaKey.self) { safeAreaBottomInset = $0 }
    }
}

/// The bottom safe-area inset reported from inside the dock's own inset.
struct ButtonDockSafeAreaKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Type erasure + environment plumbing

struct AnyButtonDockChromeStyle: ButtonDockChromeStyle {
    /// `true` only for the environment key's stock default below. `buttonDock`
    /// checks it: while the environment still carries the default it draws its
    /// own bar, unchanged; any style set with `.buttonDockChromeStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (ButtonDockChromeStyleConfiguration) -> AnyView
    init<S: ButtonDockChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ButtonDockChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyButtonDockChromeStyle(DefaultButtonDockChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var buttonDockChromeStyle: AnyButtonDockChromeStyle {
        get { self[ButtonDockChromeStyleKey.self] }
        set { self[ButtonDockChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ButtonDockChromeStyle`` for the `.buttonDock { }` bars in this
    /// view and its descendants.
    func buttonDockChromeStyle<S: ButtonDockChromeStyle>(_ style: sending S) -> some View {
        environment(\.buttonDockChromeStyle, AnyButtonDockChromeStyle(style))
    }
}
