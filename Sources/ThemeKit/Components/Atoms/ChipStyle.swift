//
//  ChipStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for `Chip`. Chroma (capsule fill,
//  stroke border, padding, foreground) lives in a `ChipStyle` you set with
//  `.chipStyle(_:)`, so chips can be reskinned without editing `Chip`. The
//  built-in `ChipSelectionStyle` enum modifier keeps working — internally it
//  routes through the same `ChipStyle` gate (`TonalChipStyle` /
//  `SolidChipStyle`), so built-ins use the exact door custom styles do.
//
//      Chip("…", isSelected: $on)
//          .chipStyle(.solid)           // enum shorthand on Chip, or
//      SomeContainer { … }
//          .chipStyle(.solid)           // a ChipStyle via the environment
//

import SwiftUI

/// The inputs a `ChipStyle` renders: the chip's already-composed content
/// (leading icon/rating or slot + title + trailing slot) plus the state the
/// chroma keys off (selection, enabled, size).
public struct ChipStyleConfiguration {
    /// The chip's content, type-erased (mirrors `ButtonStyleConfiguration.label`).
    public let content: AnyView
    /// Whether the chip is currently selected.
    public let isSelected: Bool
    /// Whether the chip is enabled; `false` draws the disabled chroma.
    public let isEnabled: Bool
    /// The chip's control size, for styles that key padding off it.
    public let size: ChipSize
}

/// Defines a chip's chroma. Implement `makeBody` to wrap the configuration's
/// content with fill, border, and padding. Set one with `.chipStyle(_:)`;
/// the default is ``TonalChipStyle``.
public protocol ChipStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ChipStyleConfiguration) -> Body
}

/// The stock tonal chroma: white capsule when idle, light hero surface + hero
/// text and border when selected, token disabled fill when disabled. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct TonalChipStyle: ChipStyle {
    public init() {}
    public func makeBody(configuration: ChipStyleConfiguration) -> some View {
        TonalChipChrome(configuration: configuration)
    }
}

private struct TonalChipChrome: View {
    let configuration: ChipStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .foregroundStyle(foreground)
            .padding(.horizontal, configuration.size.horizontalPadding)
            .padding(.vertical, configuration.size.verticalPadding)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: configuration.isSelected ? 1.5 : 1))
    }

    private var foreground: Color {
        if !configuration.isEnabled { return theme.text(.textDisabled) }
        return configuration.isSelected ? theme.text(.textHero) : theme.text(.textSecondary)
    }
    private var background: Color {
        if !configuration.isEnabled { return theme.background(.bgSecondaryLight) }
        return configuration.isSelected ? theme.background(.bgElevatorTertiary) : theme.background(.bgWhite)
    }
    private var border: Color {
        guard configuration.isEnabled, configuration.isSelected else { return theme.border(.borderPrimary) }
        return theme.border(.borderHero)
    }
}

/// The solid chroma: white capsule when idle, hero fill + light text when
/// selected, token disabled fill when disabled.
public struct SolidChipStyle: ChipStyle {
    public init() {}
    public func makeBody(configuration: ChipStyleConfiguration) -> some View {
        SolidChipChrome(configuration: configuration)
    }
}

private struct SolidChipChrome: View {
    let configuration: ChipStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        configuration.content
            .foregroundStyle(foreground)
            .padding(.horizontal, configuration.size.horizontalPadding)
            .padding(.vertical, configuration.size.verticalPadding)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: configuration.isSelected ? 1.5 : 1))
    }

    private var foreground: Color {
        if !configuration.isEnabled { return theme.text(.textDisabled) }
        return configuration.isSelected ? theme.foreground(.fgSecondary) : theme.text(.textSecondary)
    }
    private var background: Color {
        if !configuration.isEnabled { return theme.background(.bgSecondaryLight) }
        return configuration.isSelected ? theme.background(.bgHero) : theme.background(.bgWhite)
    }
    private var border: Color {
        guard configuration.isEnabled, configuration.isSelected else { return theme.border(.borderPrimary) }
        return theme.background(.bgHero)
    }
}

public extension ChipStyle where Self == TonalChipStyle {
    /// The stock tonal chroma (light hero surface + hero text when selected).
    static var tonal: TonalChipStyle { TonalChipStyle() }
}

public extension ChipStyle where Self == SolidChipStyle {
    /// The solid chroma (hero fill + light text when selected).
    static var solid: SolidChipStyle { SolidChipStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyChipStyle: ChipStyle {
    /// `true` only for the environment key's stock default below. Molecules
    /// whose stock chroma is not the capsule the built-ins draw (ImageChip,
    /// CompactChip, ChoseChip, FilterChip, MapPriceMarker) check this flag:
    /// while the environment still carries the default they draw their own
    /// pixel-identical chroma; any style set with `.chipStyle(_:)` is unmarked
    /// and routes them through `makeBody(configuration:)` instead. `Chip`
    /// ignores the flag — its `resolvedStyle` already arbitrates between the
    /// enum shorthand and the environment style.
    let isDefault: Bool
    private let _makeBody: @MainActor (ChipStyleConfiguration) -> AnyView
    init<S: ChipStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ChipStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ChipStyleKey: EnvironmentKey {
    static let defaultValue = AnyChipStyle(TonalChipStyle(), isDefault: true)
}

extension EnvironmentValues {
    var chipStyle: AnyChipStyle {
        get { self[ChipStyleKey.self] }
        set { self[ChipStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ChipStyle`` for `Chip`s in this view and its descendants.
    func chipStyle<S: ChipStyle>(_ style: sending S) -> some View {
        environment(\.chipStyle, AnyChipStyle(style))
    }
}
