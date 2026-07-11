//
//  ListRowStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `ListRow`. The row's *chrome*
//  (layout of the leading / content / trailing zones, padding, selected-state
//  background) lives in a `ListRowStyle` you set with `.listRowStyle(_:)`, so a
//  row can be reskinned — flat, inset card, custom — without editing `ListRow`.
//  The interactive content (title/subtitle/meta, accessories) stays in `ListRow`
//  and arrives composed; the style only arranges and wraps it. The default
//  reproduces the original row, so this is additive and non-breaking.
//
//      ListRow("Account", action: {}).subtitle("Profile & security")
//          .listRowStyle(.inset)        // or a custom ListRowStyle
//

import SwiftUI

/// The inputs a `ListRowStyle` arranges: the row's already-composed zones plus
/// the state a chrome keys off (selected / enabled / size tier).
public struct ListRowStyleConfiguration {
    /// The leading zone (slot, or the row's icon / thumbnail / number / radio), if any.
    public let leading: AnyView?
    /// The center zone: title + subtitle + meta / info lines, laid out.
    public let content: AnyView
    /// The trailing zone (slot, or the enum accessory + info button), if any.
    public let trailing: AnyView?
    /// Whether the row is in its active/selected state.
    public let isSelected: Bool
    /// Whether the row is enabled in its environment.
    public let isEnabled: Bool
    /// The row's title weight/size tier.
    public let size: ListRowSize
}

/// Defines a `ListRow`'s chrome. Implement `makeBody` to arrange the
/// configuration's zones and wrap them with a surface (padding, background,
/// border). Set one with `.listRowStyle(_:)`; the default is ``DefaultListRowStyle``.
public protocol ListRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ListRowStyleConfiguration) -> Body
}

/// The stock row: a leading-content-trailing `HStack`, vertical padding, and a
/// soft hero-tinted rounded background when selected. Reads the active `\.theme`,
/// so an injected theme re-skins it too.
public struct DefaultListRowStyle: ListRowStyle {
    public init() {}
    public func makeBody(configuration: ListRowStyleConfiguration) -> some View {
        DefaultListRowChrome(configuration: configuration)
    }
}

private struct DefaultListRowChrome: View {
    let configuration: ListRowStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            if let leading = configuration.leading { leading }
            configuration.content
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let trailing = configuration.trailing { trailing }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
        // The selected highlight is a full-width band drawn BEHIND the content —
        // it never adds horizontal padding, so the leading edge (radio, icon,
        // text) stays aligned whether or not the row is selected. Want an inset
        // pill instead? Opt in with `.listRowStyle(.inset)`.
        .background(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                .fill(configuration.isSelected ? theme.background(.bgHero).opacity(0.08) : .clear)
        )
    }
}

/// A card-shaped row: white fill, a 1pt border (hero-colored when selected) and
/// the `field` radius role. An example custom `ListRowStyle` consumers can use
/// directly or model their own on.
public struct InsetListRowStyle: ListRowStyle {
    public init() {}
    public func makeBody(configuration: ListRowStyleConfiguration) -> some View {
        InsetListRowChrome(configuration: configuration)
    }
}

private struct InsetListRowChrome: View {
    let configuration: ListRowStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            if let leading = configuration.leading { leading }
            configuration.content
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let trailing = configuration.trailing { trailing }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                .strokeBorder(configuration.isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: 1)
        )
    }
}

public extension ListRowStyle where Self == DefaultListRowStyle {
    /// The stock flat row (selected-state tinted background).
    static var `default`: DefaultListRowStyle { DefaultListRowStyle() }
}

public extension ListRowStyle where Self == InsetListRowStyle {
    /// A card-shaped row (white fill, bordered, `field` radius).
    static var inset: InsetListRowStyle { InsetListRowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyListRowStyle: ListRowStyle {
    private let _makeBody: @MainActor (ListRowStyleConfiguration) -> AnyView
    init<S: ListRowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ListRowStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ListRowStyleKey: EnvironmentKey {
    static let defaultValue = AnyListRowStyle(DefaultListRowStyle())
}

extension EnvironmentValues {
    var listRowStyle: AnyListRowStyle {
        get { self[ListRowStyleKey.self] }
        set { self[ListRowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ListRowStyle`` for `ListRow`s in this view and its descendants.
    func listRowStyle<S: ListRowStyle>(_ style: sending S) -> some View {
        environment(\.listRowStyle, AnyListRowStyle(style))
    }
}
