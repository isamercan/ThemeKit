//
//  CalendarTheme+ThemeKit.swift
//  ThemeKitCalendar
//
//  Bridges Almanac's `CalendarTheme` / `CalendarStyle` to ThemeKit design tokens,
//  so a calendar re-skins with the active `Theme` — including theme presets and
//  per-subtree `.theme(_:)` injection — instead of carrying its own palette.
//
#if os(iOS) && canImport(Almanac)
import SwiftUI
import ThemeKit
import Almanac

public extension CalendarTheme {
    /// A calendar color theme derived from a ThemeKit ``Theme``.
    ///
    /// Each of Almanac's ten semantic slots maps to a ThemeKit token, so the
    /// calendar inherits the active brand + light/dark automatically:
    ///
    /// | Calendar slot | ThemeKit token |
    /// |---|---|
    /// | `ink` (text + selected fill) | `text(.textPrimary)` |
    /// | `onInk` (on the selected fill) | `text(.textSecondaryInverse)` |
    /// | `surface` (page / cell bg) | `background(.bgBase)` |
    /// | `line` (borders / disabled) | `border(.borderPrimary)` |
    /// | `weekendText` | `text(.textTertiary)` |
    /// | `todayRing` | `foreground(.fgHero)` |
    /// | `inBetweenFill` (in-range) | `palette(.primary100)` |
    /// | `holidayDot` | `foreground(.systemcolorsFgError)` |
    /// | `disabledButtonContainer` | `background(.bgSecondary)` |
    /// | `disabledButtonContent` | `text(.textDisabled)` |
    init(themeKit theme: Theme) {
        self.init(
            ink: theme.text(.textPrimary),
            onInk: theme.text(.textSecondaryInverse),
            surface: theme.background(.bgBase),
            line: theme.border(.borderPrimary),
            weekendText: theme.text(.textTertiary),
            todayRing: theme.foreground(.fgHero),
            inBetweenFill: theme.palette(.primary100),
            holidayDot: theme.foreground(.systemcolorsFgError),
            disabledButtonContainer: theme.background(.bgSecondary),
            disabledButtonContent: theme.text(.textDisabled)
        )
    }
}

public extension CalendarStyle {
    /// `CalendarStyle.standard` with its colors replaced by ThemeKit tokens.
    /// Typography and metrics keep Almanac's tuned defaults.
    static func themeKit(_ theme: Theme) -> CalendarStyle {
        var style = CalendarStyle.standard
        style.theme = CalendarTheme(themeKit: theme)
        return style
    }
}
#endif
