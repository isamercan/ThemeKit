//
//  StatStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `Stat`. The arrangement of the pieces
//  (figure icon, title, value, trend, description) lives in a `StatStyle` you set
//  with `.statStyle(_:)`, so a stat can be re-laid-out — centered, value-first,
//  compact — without editing `Stat`. The value and trend arrive pre-rendered, so a
//  style positions them; the default reproduces the original row, so this is
//  additive and non-breaking.
//
//      Stat(title: "Bookings", value: 1284).statStyle(.centered)
//

import SwiftUI

/// The pieces a `StatStyle` arranges. `value` and `trend` are pre-rendered (their
/// internal styling — prefix/suffix, rolling digits, trend color — is fixed); the
/// style places them and styles the title/description text and icon.
public struct StatStyleConfiguration {
    public let title: String
    /// The composed value (prefix + value/skeleton/rolling number + suffix).
    public let value: AnyView
    /// The pre-rendered trend badge (arrow + delta), or `nil`.
    public let trend: AnyView?
    public let description: String?
    public let systemImage: String?
}

/// Defines a `Stat`'s layout. Implement `makeBody` to arrange the configuration's
/// pieces. Set one with `.statStyle(_:)`; the default is ``DefaultStatStyle``.
public protocol StatStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: StatStyleConfiguration) -> Body
}

/// The stock layout: a leading figure icon, then a column of title · value ·
/// (trend + description). Reads `\.theme`, so an injected theme re-skins it.
public struct DefaultStatStyle: StatStyle {
    public init() {}
    public func makeBody(configuration: StatStyleConfiguration) -> some View {
        DefaultStatLayout(configuration: configuration)
    }
}

private struct DefaultStatLayout: View {
    let configuration: StatStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.md.value) {
            if let systemImage = configuration.systemImage {
                Icon(systemName: systemImage).size(.xl).color(theme.foreground(.fgHero))
            }
            column(alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    private func column(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(configuration.title).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
            configuration.value
            HStack(spacing: Theme.SpacingKey.xs.value) {
                configuration.trend
                if let description = configuration.description {
                    Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
        }
    }
}

/// A centered layout (icon above, everything center-aligned) — an example custom
/// `StatStyle` for tiles/dashboards.
public struct CenteredStatStyle: StatStyle {
    public init() {}
    public func makeBody(configuration: StatStyleConfiguration) -> some View {
        CenteredStatLayout(configuration: configuration)
    }
}

private struct CenteredStatLayout: View {
    let configuration: StatStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Theme.SpacingKey.xs.value) {
            if let systemImage = configuration.systemImage {
                Icon(systemName: systemImage).size(.xl).color(theme.foreground(.fgHero))
            }
            Text(configuration.title).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
            configuration.value
            HStack(spacing: Theme.SpacingKey.xs.value) {
                configuration.trend
                if let description = configuration.description {
                    Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

public extension StatStyle where Self == DefaultStatStyle {
    /// The stock leading-icon row.
    static var `default`: DefaultStatStyle { DefaultStatStyle() }
}

public extension StatStyle where Self == CenteredStatStyle {
    /// A centered tile layout (icon above, content centered).
    static var centered: CenteredStatStyle { CenteredStatStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyStatStyle: StatStyle {
    private let _makeBody: @MainActor (StatStyleConfiguration) -> AnyView
    init<S: StatStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: StatStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct StatStyleKey: EnvironmentKey {
    static let defaultValue = AnyStatStyle(DefaultStatStyle())
}

extension EnvironmentValues {
    var statStyle: AnyStatStyle {
        get { self[StatStyleKey.self] }
        set { self[StatStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``StatStyle`` for `Stat`s in this view and its descendants.
    func statStyle<S: StatStyle>(_ style: sending S) -> some View {
        environment(\.statStyle, AnyStatStyle(style))
    }
}
