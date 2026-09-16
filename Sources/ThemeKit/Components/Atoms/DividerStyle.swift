//
//  DividerStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `DividerView`. The paint of a
//  divider — line colour, thickness, dash pattern, the title's type — lives in
//  a `DividerStyle` you set with `.dividerStyle(_:)`, so a host design system
//  can draw its own rules while ThemeKit keeps the content model (axis, dashed,
//  size, title and its placement) and accessibility. The stock look is
//  `DefaultDividerStyle`.
//
//      DividerView("OR").dashed()
//          .dividerStyle(MyDividerStyle())
//

import SwiftUI

/// The inputs a ``DividerStyle`` renders: the divider's title (raw and as the
/// stock label) and its axes.
public struct DividerStyleConfiguration {
    /// The inline title, or `nil` for a bare line. Build your own `Text` from it
    /// to set a different font.
    public let title: String?
    /// The stock title view — `title` in ThemeKit's label type style and
    /// tertiary text colour, at its ideal size — or `nil` without a title.
    /// Place it to keep ThemeKit's title and restyle only the lines.
    public let label: AnyView?
    /// Orientation: `.horizontal` or `.vertical`.
    public let axis: DividerAxis
    /// Whether the line is dashed.
    public let isDashed: Bool
    /// The thickness tier the stock style uses for a bare, solid, horizontal line.
    public let size: DividerViewSize
    /// Where the title sits along a horizontal divider.
    public let titleAlignment: DividerTextAlign
}

/// Defines how a `DividerView` is painted. Implement `makeBody` to draw the
/// line — and the title, when `configuration.title` is set — for the given
/// axis. Set one with `.dividerStyle(_:)`; the default is
/// ``DefaultDividerStyle``.
///
/// The style draws the divider only; it owns the layout of what it draws (a
/// horizontal rule usually fills the offered width, a vertical one the offered
/// height). ThemeKit keeps the content model and accessibility: a bare divider
/// is hidden from VoiceOver, and a titled one reads as its title, once,
/// however the style draws it. A style that draws a dashed line with a `Path`
/// should add `.flipsForRightToLeftLayoutDirection(true)` so the pattern starts
/// at the leading edge, as the stock style does.
///
/// The style is read from the environment, so setting it on a container also
/// restyles the dividers ThemeKit components draw inside it — `Card` header
/// and footer rules, list and menu separators (`ListView`, `ListRow`,
/// `Select`, `Dropdown`, `MultiSelect`, …), `Accordion`, `Dialog`, `Join`.
///
///     struct HairlineDividerStyle: DividerStyle {
///         func makeBody(configuration: DividerStyleConfiguration) -> some View {
///             HairlineDivider(configuration: configuration)
///         }
///     }
///
///     private struct HairlineDivider: View {
///         @Environment(\.theme) private var theme
///         let configuration: DividerStyleConfiguration
///
///         var body: some View {
///             switch configuration.axis {
///             case .horizontal:
///                 HStack(spacing: Theme.SpacingKey.sm.value) {
///                     rule
///                     if let title = configuration.title {
///                         Text(title).textStyle(.bodySm400).fixedSize()
///                         rule
///                     }
///                 }
///             case .vertical:
///                 rule.frame(width: 1).frame(maxHeight: .infinity)
///             }
///         }
///
///         private var rule: some View {
///             Rectangle().fill(theme.border(.borderHero)).frame(height: 1)
///         }
///     }
public protocol DividerStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: DividerStyleConfiguration) -> Body
}

/// The stock divider: a 1 pt `borderPrimary` line (solid, or dashed 4-on-4
/// starting at the leading edge), a solid horizontal line grown to the
/// ``DividerViewSize`` tier with a base surface band, and an optional
/// tertiary label-type title placed leading, centre or trailing. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct DefaultDividerStyle: DividerStyle, Sendable {
    public init() {}
    public func makeBody(configuration: DividerStyleConfiguration) -> some View {
        DefaultDividerChrome(configuration: configuration)
    }
}

public extension DividerStyle where Self == DefaultDividerStyle {
    /// The stock theme-driven divider.
    static var `default`: DefaultDividerStyle { DefaultDividerStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyDividerStyle: DividerStyle {
    /// `true` only for the environment key's stock default below. While the
    /// environment still carries it, `DividerView` draws the built-in chrome
    /// directly (the pre-style render path); any style set with
    /// `.dividerStyle(_:)` — `.default` included — is unmarked and goes through
    /// `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (DividerStyleConfiguration) -> AnyView
    init<S: DividerStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: DividerStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct DividerStyleKey: EnvironmentKey {
    static let defaultValue = AnyDividerStyle(DefaultDividerStyle(), isDefault: true)
}

extension EnvironmentValues {
    var dividerStyle: AnyDividerStyle {
        get { self[DividerStyleKey.self] }
        set { self[DividerStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``DividerStyle`` for `DividerView`s in this view and its
    /// descendants, including the dividers ThemeKit components draw.
    func dividerStyle<S: DividerStyle>(_ style: sending S) -> some View {
        environment(\.dividerStyle, AnyDividerStyle(style))
    }
}
