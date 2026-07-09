//
//  DateRangePicker.swift
//  ThemeKitCalendar
//
//  A ThemeKit-themed calendar built on Almanac. It re-skins with the active
//  ThemeKit `Theme` automatically, and every visual/behavioural choice — which
//  surface (picker / month / week / year / browse), the day-selection shape, the
//  accent, the chrome, single vs range, custom day cells, holidays, locale — is a
//  **modifier**. Colours are token-fed (they re-theme).
//
//  ```swift
//  DateRangePicker(.hotel) { result in … }
//      .display(.month).daySelection(.rounded).accent(.turquoise)
//      .day { ctx in HeatCell(ctx) }           // bring your own token-bound cell
//      .selectedAccessory { date in FareCard(date) }
//
//  // present anywhere, themed:
//  someView.dateRangePicker(isPresented: $show) { result in … }
//  ```
//
#if os(iOS) && canImport(Almanac)
import SwiftUI
import UIKit
import ThemeKit
@_exported import Almanac

public struct DateRangePicker: View {
    /// The framing/titles of the picker — a plain range, or hotel / rent-a-car copy.
    public enum Purpose: Sendable { case range, hotel, rentACar }
    /// Which calendar surface to render.
    public enum Display: Sendable {
        case picker   // full picker (top bar, date row, footer)
        case month    // bare inline scrolling month grid
        case week     // horizontally-paging single-week strip
        case year     // year overview (tap a month)
        case browse   // year ↔ month navigation in one view
    }
    /// The shape of the selected-day fill / today ring.
    public enum DaySelection: Sendable { case circle, rounded, square }

    private let purpose: Purpose
    private var configuration: CalendarPickerConfiguration
    private let onApply: (CalendarPickerResult) -> Void
    private let onCancel: () -> Void
    // ThemeKit-flavoured overrides — mutated only through the modifiers below (R2).
    private var display: Display = .picker
    private var accent: SemanticColor?
    private var daySelection: DaySelection = .circle
    private var styleTransform: ((inout CalendarStyle) -> Void)?
    // Composition overrides (bring-your-own views).
    private var dayContent: ((CalendarDayContext) -> AnyView)?
    private var selectedAccessoryContent: ((Date) -> AnyView)?
    private var monthHeaderContent: ((CalMonth, Locale) -> AnyView)?
    private var weekdayHeaderContent: ((Int, Locale) -> AnyView)?
    private var legendContent: (([HolidayCategory]) -> AnyView)?

    @Environment(\.theme) private var theme

    public init(
        _ purpose: Purpose = .range,
        configuration: CalendarPickerConfiguration = .init(),
        onApply: @escaping (CalendarPickerResult) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.purpose = purpose
        self.configuration = configuration
        self.onApply = onApply
        self.onCancel = onCancel
    }

    public var body: some View {
        var v = AnyView(surface.calendarStyle(resolvedStyle))
        if let dayContent { v = AnyView(v.calendarDay(dayContent)) }
        if let selectedAccessoryContent { v = AnyView(v.calendarSelectedDateAccessory(selectedAccessoryContent)) }
        if let monthHeaderContent { v = AnyView(v.calendarMonthHeader(monthHeaderContent)) }
        if let weekdayHeaderContent { v = AnyView(v.calendarWeekdayHeader(weekdayHeaderContent)) }
        if let legendContent { v = AnyView(v.calendarLegend(legendContent)) }
        return v
    }

    // MARK: Surface

    @ViewBuilder private var surface: some View {
        switch display {
        case .picker:
            switch purpose {
            case .range:    CalendarRangePickerView.rangeSelector(configuration: configuration, onApply: onApply, onCancel: onCancel)
            case .hotel:    CalendarRangePickerView.hotel(configuration: configuration, onApply: onApply, onCancel: onCancel)
            case .rentACar: CalendarRangePickerView.rentACar(configuration: configuration, onApply: onApply, onCancel: onCancel)
            }
        case .month:
            CalendarGridView(configuration: configuration, onSelectionChange: onApply)
        case .week:
            CalendarWeekView(configuration: configuration,
                             showsTitle: configuration.chrome.showsTitleBar,
                             showsWeekdayHeader: configuration.chrome.showsWeekdayHeader,
                             onSelectionChange: onApply)
        case .year:
            CalendarYearView(year: configuration.calendar.component(.year, from: Date()),
                             calendar: configuration.calendar, locale: configuration.locale)
        case .browse:
            CalendarBrowseView(configuration: configuration, onSelectionChange: onApply)
        }
    }

    // MARK: Style (ThemeKit tokens + overrides)

    private var resolvedStyle: CalendarStyle {
        var s = CalendarStyle.themeKit(theme)
        s.metrics.daySelectionShape = resolvedDayShape
        if let accent {                                  // token-fed brand override (re-themes)
            s.theme.ink = accent.strong
            s.theme.onInk = accent.onSolid
            s.theme.todayRing = accent.base
            s.theme.inBetweenFill = accent.bg
        }
        styleTransform?(&s)
        return s
    }

    private var resolvedDayShape: CalendarDayShape {
        switch daySelection {
        case .circle: .circle
        case .rounded: .roundedRectangle(cornerRadius: Theme.RadiusRole.selector.value)
        case .square: .square
        }
    }

    /// Packs a SwiftUI colour into Almanac's 0xAARRGGBB integer (for holiday entries).
    static func argb(_ color: Color) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> UInt32 { UInt32((max(0, min(1, v)) * 255).rounded()) }
        return (c(a) << 24) | (c(r) << 16) | (c(g) << 8) | c(b)
    }
}

// MARK: - Modifiers (R2 copy-on-write) — appearance, surfaces, composition & domain

public extension DateRangePicker {
    // Surface & appearance
    /// Which surface: full `.picker`, inline `.month`, `.week` strip, `.year` overview, or `.browse`.
    func display(_ mode: Display) -> Self { copy { $0.display = mode } }
    /// Token-fed accent for the selection / today ring / in-range fill (re-themes).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Selected-day shape: circle (default) / rounded / square.
    func daySelection(_ shape: DaySelection) -> Self { copy { $0.daySelection = shape } }
    /// Range (default) or single-day selection.
    func selectionMode(_ mode: CalendarSelectionMode) -> Self { copy { $0.configuration.selectionMode = mode } }
    /// Scroll months horizontally (paged) instead of vertically.
    func horizontalPaging(_ on: Bool = true) -> Self { copy { $0.configuration.horizontalPaging = on } }

    // Composition (bring-your-own, token-bound views)
    /// A custom cell for each day — build it from ThemeKit atoms (heat-map, price, dots…).
    func day<V: View>(@ViewBuilder _ content: @escaping (CalendarDayContext) -> V) -> Self {
        copy { $0.dayContent = { AnyView(content($0)) } }
    }
    /// A detail accessory shown above the footer for the selected day (fare summary, notes…).
    func selectedAccessory<V: View>(@ViewBuilder _ content: @escaping (Date) -> V) -> Self {
        copy { $0.selectedAccessoryContent = { AnyView(content($0)) } }
    }
    /// A custom month-title header.
    func monthHeader<V: View>(@ViewBuilder _ content: @escaping (CalMonth, Locale) -> V) -> Self {
        copy { $0.monthHeaderContent = { AnyView(content($0, $1)) } }
    }
    /// A custom day-of-week header cell (index 0 = Sunday … 6 = Saturday).
    func weekdayHeader<V: View>(@ViewBuilder _ content: @escaping (Int, Locale) -> V) -> Self {
        copy { $0.weekdayHeaderContent = { AnyView(content($0, $1)) } }
    }
    /// A custom footer legend for the visible holiday categories.
    func legend<V: View>(@ViewBuilder _ content: @escaping ([HolidayCategory]) -> V) -> Self {
        copy { $0.legendContent = { AnyView(content($0)) } }
    }

    // Chrome
    /// Strip all chrome — just the scrolling grid (ideal for embedding).
    func bare(_ on: Bool = true) -> Self { copy { if on { $0.configuration.chrome = .none } } }
    func showsWeekdayHeader(_ on: Bool) -> Self { copy { $0.configuration.chrome.showsWeekdayHeader = on } }
    func showsFooter(_ on: Bool) -> Self { copy { $0.configuration.chrome.showsFooter = on } }
    func showsLegend(_ on: Bool) -> Self { copy { $0.configuration.chrome.showsLegend = on } }
    func showsTitleBar(_ on: Bool) -> Self { copy { $0.configuration.chrome.showsTitleBar = on } }
    func showsDateRow(_ on: Bool) -> Self { copy { $0.configuration.chrome.showsDateRow = on } }
    /// Surface a floating "jump to today" button (opt-in).
    func showsTodayButton(_ on: Bool = true) -> Self { copy { $0.configuration.chrome.showsTodayButton = on } }

    // Domain
    /// Per-day badge text — e.g. a fare like "₺1.250" (taller day cells).
    func prices(_ prices: [Date: String]) -> Self { copy { $0.configuration.priceByDate = prices } }
    /// Inclusive last selectable day (also caps the visible months).
    func maxDate(_ date: Date?) -> Self { copy { $0.configuration.maxSelectableDate = date } }
    /// Days that can't be tapped or spanned.
    func blockedDates(_ dates: [Date]) -> Self { copy { $0.configuration.blockedDates = dates } }
    /// Initial selected range.
    func initialRange(going: Date?, returning: Date? = nil) -> Self {
        copy { $0.configuration.goingDate = going; $0.configuration.returnDate = returning }
    }
    /// Min/max nights allowed between the two dates.
    func nights(min: Int? = nil, max: Int? = nil) -> Self { copy { $0.configuration.minNights = min; $0.configuration.maxNights = max } }
    /// Holiday categories (raw entries).
    func holidays(_ entries: [HolidayEntry]) -> Self { copy { $0.configuration.holidays = entries } }
    /// Append a token-coloured holiday for the given days.
    func holiday(on dates: [ETSCalendarDate], color: SemanticColor, name: String) -> Self {
        copy { $0.configuration.holidays.append(HolidayEntry(dates: dates, colorARGB: Self.argb(color.base), description: name)) }
    }
    /// BCP-47 locale tag (e.g. "tr", "en-US", "ar" for RTL). nil ⇒ system.
    func locale(_ tag: String?) -> Self { copy { $0.configuration.localeTag = tag } }
    /// The calendar system + first weekday + timezone (e.g. `Calendar(identifier: .islamicUmmAlQura)`).
    func calendar(_ calendar: Calendar) -> Self { copy { $0.configuration.calendar = calendar } }

    /// Escape hatch: mutate the resolved `CalendarStyle` (metrics/typography) directly.
    func customizeStyle(_ transform: @escaping (inout CalendarStyle) -> Void) -> Self { copy { $0.styleTransform = transform } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension View {
    /// Apply the ThemeKit-derived calendar style (from a specific `Theme`) to any
    /// Almanac calendar view — the escape hatch when you compose Almanac directly.
    func themeKitCalendarStyle(_ theme: Theme) -> some View {
        calendarStyle(.themeKit(theme))
    }

    /// Present a themed ``DateRangePicker`` in a sheet from anywhere. `configure`
    /// lets you apply any of its modifiers; the sheet dismisses on apply/cancel.
    func dateRangePicker(
        isPresented: Binding<Bool>,
        _ purpose: DateRangePicker.Purpose = .range,
        configure: @escaping (DateRangePicker) -> DateRangePicker = { $0 },
        onApply: @escaping (CalendarPickerResult) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            configure(DateRangePicker(purpose,
                onApply: { result in isPresented.wrappedValue = false; onApply(result) },
                onCancel: { isPresented.wrappedValue = false }))
        }
    }
}
#endif
