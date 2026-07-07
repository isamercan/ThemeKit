//
//  BarStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for horizontal bars (`SheetHeader`,
//  and future top/bottom bars). Chrome (surface fill, hairline, shadow, layout
//  of the side slots) lives in a `BarStyle` you set with `.barStyle(_:)`, so a
//  bar can be reskinned — flat, floating, glass — without editing the component.
//  The default style reproduces `SheetHeader`'s original look, so this is
//  additive and non-breaking.
//
//      SheetHeader("…").onClose { … }
//          .barStyle(.floating)         // or a custom BarStyle
//

import SwiftUI

/// Which screen edge a bar is attached to. Styles can key their chrome off
/// this — e.g. a top bar (header) draws its hairline below the content and may
/// cast its shadow downward, a bottom bar (dock) draws the hairline above.
public enum BarEdge: Sendable {
    case top
    case bottom
}

/// The inputs a `BarStyle` renders (mirrors `ButtonStyleConfiguration`).
///
/// `content` is the bar's already-composed center block — title + subtitle
/// (+ an optional full-width progress line), stacked by the component. It is
/// expected to span the bar's full width with the side-slot insets baked in
/// (see `BarMetrics.contentInset(_:)`), so styles lay the `leading`/`trailing`
/// accessories over its first row rather than beside it.
public struct BarStyleConfiguration {
    /// The leading accessory (e.g. a back button), type-erased. `nil` leaves
    /// the leading slot empty (the content still reserves its footprint).
    public let leading: AnyView?
    /// The bar's center block: title + subtitle + progress, pre-arranged.
    public let content: AnyView
    /// The trailing accessory (e.g. a close button), type-erased.
    public let trailing: AnyView?
    /// The edge the bar sits on — top bar (header) or bottom bar (dock).
    public let edge: BarEdge
}

/// Defines a bar's chrome. Implement `makeBody` to wrap the configuration's
/// content and slots with a surface (background, hairline, shadow). Set one
/// with `.barStyle(_:)`; the default is ``DefaultBarStyle``.
public protocol BarStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: BarStyleConfiguration) -> Body
}

// MARK: - Shared geometry

/// The fixed bar geometry shared by the component (which bakes the content
/// inset) and the built-in styles (which place the side slots). One source of
/// truth keeps the two sides pixel-aligned.
enum BarMetrics {
    /// Height of the slot/title row.
    static let rowHeight: CGFloat = 56
    /// Square footprint of a leading/trailing slot.
    static let slotSize: CGFloat = 44
    /// Minimum gap between a slot and the center content.
    static let slotSpacing: CGFloat = 4

    /// Horizontal inset the center content must reserve on each side so it
    /// never underlaps a slot: slot + gap + the bar's edge padding.
    static func contentInset(_ density: ComponentDensity) -> CGFloat {
        slotSize + slotSpacing + density.scale(Theme.SpacingKey.sm.value)
    }
}

// MARK: - Component chrome overrides (internal channel)

/// Legacy per-component chrome knobs (`SheetHeader.surface(_:)` /
/// `.showsDivider(_:)`) that must keep working and must *win* over the fill /
/// hairline a built-in style would draw. They are deliberately not part of
/// `BarStyleConfiguration`: they are component-owned modifiers, so the
/// component plumbs them to the style through this internal environment value
/// instead. Built-in styles honor them; custom styles may ignore them.
struct BarChromeOverrides {
    /// When non-`nil`, replaces the style's own surface fill.
    var surface: Theme.BackgroundColorKey?
    /// When `false`, suppresses the style's edge hairline (also used when a
    /// progress line replaces the divider).
    var showsHairline = true
    /// When non-`nil`, gates the style's own shadow (`StickyBookingBar
    /// .showsShadow(_:)`). `nil` = the style decides. It can only suppress a
    /// shadow the style already draws — styles without one (e.g.
    /// ``DefaultBarStyle``) ignore `true`.
    var showsShadow: Bool? = nil
}

private struct BarChromeOverridesKey: EnvironmentKey {
    static let defaultValue = BarChromeOverrides()
}

extension EnvironmentValues {
    var barChromeOverrides: BarChromeOverrides {
        get { self[BarChromeOverridesKey.self] }
        set { self[BarChromeOverridesKey.self] = newValue }
    }
}

// MARK: - Shared slot row

/// Lays the leading/trailing accessories over the content's first row —
/// each in a fixed 44×44 slot (leading-/trailing-aligned, like the original
/// `SheetHeader.sideSlot`), vertically centered in the 56pt row, inset by the
/// bar's edge padding. Geometrically identical to the original
/// `[slot][spacer][title][spacer][slot]` HStack because the content reserves
/// `BarMetrics.contentInset(_:)` on both sides.
struct BarSlotRow: View {
    let configuration: BarStyleConfiguration
    @Environment(\.componentDensity) private var density

    var body: some View {
        configuration.content
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) { slot(configuration.leading, alignment: .leading) }
            .overlay(alignment: .topTrailing) { slot(configuration.trailing, alignment: .trailing) }
    }

    @ViewBuilder
    private func slot(_ accessory: AnyView?, alignment: Alignment) -> some View {
        if let accessory {
            accessory
                .frame(width: BarMetrics.slotSize, height: BarMetrics.slotSize, alignment: alignment)
                .frame(height: BarMetrics.rowHeight)   // centers the slot in the row
                .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
        }
    }
}

// MARK: - Default style

/// The stock bar chrome — `SheetHeader`'s original look: slots over the
/// content row, a flat `bgWhite` fill, and a 1pt `borderPrimary` hairline on
/// the inner edge (below the content for `.top` bars, above it for `.bottom`
/// bars). Honors the component's `surface`/`showsDivider` overrides and reads
/// the active `\.theme`, so an injected theme re-skins it too.
public struct DefaultBarStyle: BarStyle {
    public init() {}
    public func makeBody(configuration: BarStyleConfiguration) -> some View {
        DefaultBarChrome(configuration: configuration)
    }
}

private struct DefaultBarChrome: View {
    let configuration: BarStyleConfiguration
    @Environment(\.theme) private var theme
    @Environment(\.barChromeOverrides) private var overrides

    var body: some View {
        VStack(spacing: 0) {
            if configuration.edge == .bottom { hairline }
            BarSlotRow(configuration: configuration)
            if configuration.edge == .top { hairline }
        }
        .background(theme.background(overrides.surface ?? .bgWhite))
    }

    @ViewBuilder private var hairline: some View {
        if overrides.showsHairline {
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
        }
    }
}

// MARK: - Floating style

/// A detached, elevated bar: the slot row on a rounded-box surface with a
/// `.soft` token shadow, inset from the horizontal edges. No hairline — the
/// shadow separates it from the content behind. Honors the component's
/// `surface` override for its fill.
public struct FloatingBarStyle: BarStyle {
    public init() {}
    public func makeBody(configuration: BarStyleConfiguration) -> some View {
        FloatingBarChrome(configuration: configuration)
    }
}

private struct FloatingBarChrome: View {
    let configuration: BarStyleConfiguration
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.barChromeOverrides) private var overrides

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    var body: some View {
        box
            .modifier(OptionalBarShadow(on: overrides.showsShadow ?? true))
            .padding(.horizontal, density.scale(Theme.SpacingKey.md.value))
    }

    private var box: some View {
        BarSlotRow(configuration: configuration)
            .clipShape(shape)   // keeps a progress line inside the rounded corners
            .background(theme.background(overrides.surface ?? .bgWhite), in: shape)
    }
}

/// Applies the style's shadow token unless a component override turned it off.
private struct OptionalBarShadow: ViewModifier {
    let on: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.themeShadow(.soft) } else { content }
    }
}

// MARK: - Static accessors

public extension BarStyle where Self == DefaultBarStyle {
    /// The stock bar chrome (flat fill + inner-edge hairline).
    static var `default`: DefaultBarStyle { DefaultBarStyle() }
}

public extension BarStyle where Self == FloatingBarStyle {
    /// A detached rounded-box bar with a soft shadow, inset from the edges.
    static var floating: FloatingBarStyle { FloatingBarStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyBarStyle: BarStyle {
    private let _makeBody: @MainActor (BarStyleConfiguration) -> AnyView
    /// `true` only for the environment's stock value — i.e. no `.barStyle(_:)`
    /// anywhere up the tree. Bars whose *stock* chrome cannot be produced by
    /// ``DefaultBarStyle`` (the capsule tab bar, the shadowed booking bar) key
    /// off this to keep their default look pixel-identical while still routing
    /// through any explicitly set style. `SheetHeader` (whose stock chrome *is*
    /// `DefaultBarStyle`) ignores it.
    let isDefault: Bool
    init<S: BarStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: BarStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct BarStyleKey: EnvironmentKey {
    static let defaultValue = AnyBarStyle(DefaultBarStyle(), isDefault: true)
}

extension EnvironmentValues {
    var barStyle: AnyBarStyle {
        get { self[BarStyleKey.self] }
        set { self[BarStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``BarStyle`` for bars (`SheetHeader`, …) in this view and its
    /// descendants.
    func barStyle<S: BarStyle>(_ style: sending S) -> some View {
        environment(\.barStyle, AnyBarStyle(style))
    }
}
