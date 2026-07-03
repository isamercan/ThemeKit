//
//  CalendarThemeBridgeTests.swift
//  ThemeKitCalendarTests
//
//  Verifies the ThemeKit → Almanac calendar bridge. iOS-only (Almanac is UIKit /
//  HorizonCalendar based); on macOS this file is empty and the target passes.
//
#if os(iOS)
import XCTest
import SwiftUI
import ThemeKit
import Almanac
@testable import ThemeKitCalendar

final class CalendarThemeBridgeTests: XCTestCase {

    func test_bridge_maps_themekit_tokens_to_calendar_slots() {
        let theme = Theme.shared
        let ct = CalendarTheme(themeKit: theme)

        XCTAssertEqual(ct.ink, theme.text(.textPrimary))
        XCTAssertEqual(ct.onInk, theme.text(.textSecondaryInverse))
        XCTAssertEqual(ct.surface, theme.background(.bgElevatorPrimary))
        XCTAssertEqual(ct.line, theme.border(.borderPrimary))
        XCTAssertEqual(ct.weekendText, theme.text(.textTertiary))
        XCTAssertEqual(ct.todayRing, theme.foreground(.fgHero))
        XCTAssertEqual(ct.inBetweenFill, theme.palette(.primary100))
        XCTAssertEqual(ct.holidayDot, theme.foreground(.systemcolorsFgError))
    }

    func test_style_themeKit_overrides_colors_and_keeps_almanac_defaults() {
        let s = CalendarStyle.themeKit(Theme.shared)
        XCTAssertEqual(s.theme, CalendarTheme(themeKit: Theme.shared))
        // typography + metrics are untouched — still Almanac's tuned standard.
        XCTAssertEqual(s.typography, CalendarStyle.standard.typography)
        XCTAssertEqual(s.metrics, CalendarStyle.standard.metrics)
    }
}
#endif
