//
//  CalendarView.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. An inline month calendar with day selection + month navigation.
/// (daisyUI "Calendar"; complements DateField which presents a popover.)
public struct CalendarView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    @Binding private var selection: Date?
    @State private var displayed: Date

    // Appearance/config — mutated only through the modifiers below (R2).
    private var accent: SemanticColor?
    private var showsWeekdayHeader = true
    private var firstWeekdayOverride: Int?
    private var yearPickerEnabled = false

    /// The navigation stage of the interior grid. Only ever leaves `.days` when
    /// `.yearPicker()` makes the header tappable, so default calendars are
    /// unaffected.
    private enum Stage { case days, months, years }
    @State private var stage: Stage = .days
    /// Top-left year of the year-stage page.
    @State private var yearPageStart: Int = 0

    /// Tracks the environment locale so month titles, weekday symbols, and the
    /// first day of the week follow the app's language (and mirror correctly for
    /// RTL). Defaults to the system locale, so existing call sites are unchanged.
    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = locale
        if let firstWeekdayOverride {
            c.firstWeekday = min(max(firstWeekdayOverride, 1), 7)
        }
        return c
    }

    public init(selection: Binding<Date?>) {
        self._selection = selection
        self._displayed = State(initialValue: selection.wrappedValue ?? Date.now)
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            header
            // A fixed interior height only when the year picker can swap stages,
            // so the card doesn't pump between the 6-row day grid and the 4-row
            // year/month grids. Default calendars keep their natural height.
            if yearPickerEnabled {
                stageContent.frame(height: 312, alignment: .top)
            } else {
                stageContent
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    @ViewBuilder private var stageContent: some View {
        switch stage {
        case .days:
            VStack(spacing: Theme.SpacingKey.sm.value) {
                if showsWeekdayHeader { weekdayRow }
                grid
            }
        case .years:
            yearGrid
        case .months:
            monthGrid
        }
    }

    private var header: some View {
        HStack {
            navButton("chevron.left", direction: -1)
            Spacer()
            titleView
            Spacer()
            navButton("chevron.right", direction: 1)
        }
    }

    /// The month/year title. When `.yearPicker()` is on it becomes a button that
    /// walks the stages; otherwise it is the same static label as before.
    @ViewBuilder private var titleView: some View {
        if yearPickerEnabled {
            Button { advanceStageFromHeader() } label: { titleLabel }
                .buttonStyle(.plain)
                .accessibilityLabel(headerA11yLabel)
        } else {
            titleLabel
        }
    }

    @ViewBuilder private var titleLabel: some View {
        switch stage {
        case .days:
            Text(displayed.formatted(.dateTime.month(.wide).year().locale(locale)))
                .textStyle(.labelMd700)
                .foregroundStyle(theme.text(.textPrimary))
        case .years:
            Text(yearRangeTitle)
                .textStyle(.labelMd700)
                .foregroundStyle(theme.text(.textPrimary))
        case .months:
            Text(displayedYear.formatted(.number.grouping(.never).locale(locale)))
                .textStyle(.labelMd700)
                .foregroundStyle(theme.text(.textPrimary))
        }
    }

    private func navButton(_ name: String, direction: Int) -> some View {
        Button {
            pageBy(direction)
        } label: {
            Icon(systemName: name).size(.sm).color(theme.text(.textPrimary))
                .frame(width: 32, height: 32)
                .mirrorsInRTL()
                .frame(minWidth: 44, minHeight: 44)   // A11y: ≥44pt tap target (glyph stays 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(navLabel(direction))
    }

    /// Paging is stage-aware: ±1 month on days (unchanged), ±12 years on the
    /// year page, ±1 year on months.
    private func pageBy(_ direction: Int) {
        switch stage {
        case .days:
            if let d = calendar.date(byAdding: .month, value: direction, to: monthStart) {
                withAnimation(Motion.fast.animation) { displayed = d }
            }
        case .years:
            withAnimation(Motion.base.animation) { yearPageStart += direction * 12 }
        case .months:
            if let d = calendar.date(byAdding: .year, value: direction, to: monthStart) {
                withAnimation(Motion.base.animation) { displayed = d }
            }
        }
    }

    private func navLabel(_ direction: Int) -> String {
        switch stage {
        case .days: return String(themeKit: direction < 0 ? "Previous month" : "Next month")
        case .years: return String(themeKit: direction < 0 ? "Previous years" : "Next years")
        case .months: return String(themeKit: direction < 0 ? "Previous year" : "Next year")
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textTertiary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = selection.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        return Button {
            selection = date
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .textStyle(.bodyBase400)
                .foregroundStyle(isSelected ? selectedContent : (isToday ? todayText : theme.text(.textPrimary)))
                .frame(width: 36, height: 36)
                .background(isSelected ? selectedFill : .clear, in: Circle())
                .overlay { if isToday && !isSelected { Circle().stroke(todayRing, lineWidth: 1) } }
                .frame(maxWidth: .infinity, minHeight: 44)   // A11y: ≥44pt tap target (circle stays 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Accent resolution (defaults keep the hero tokens, R4)

    private var selectedFill: Color { accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero) }
    private var selectedContent: Color { accent.map { theme.resolve($0).onSolid } ?? theme.foreground(.fgSecondary) }
    private var todayText: Color { accent.map { theme.resolve($0).accent } ?? theme.text(.textHero) }
    private var todayRing: Color { accent.map { theme.resolve($0).border } ?? theme.border(.borderHero) }

    // MARK: - Year / month stages (opt-in via .yearPicker())

    private var displayedYear: Int { calendar.component(.year, from: displayed) }
    private var currentYear: Int { calendar.component(.year, from: Date.now) }

    private var yearRangeTitle: String {
        let lo = yearPageStart.formatted(.number.grouping(.never).locale(locale))
        let hi = (yearPageStart + 11).formatted(.number.grouping(.never).locale(locale))
        return "\(lo) – \(hi)"
    }

    private var headerA11yLabel: String {
        switch stage {
        case .days: return String(themeKit: "Choose year")
        case .years: return String(themeKit: "Back to days")
        case .months: return String(themeKit: "Back to years")
        }
    }

    /// Tapping the header walks up the stages: days → years, months → years,
    /// years → back to days.
    private func advanceStageFromHeader() {
        withAnimation(Motion.base.animation) {
            switch stage {
            case .days, .months:
                yearPageStart = displayedYear - 6   // keep the shown year near the page middle
                stage = .years
            case .years:
                stage = .days
            }
        }
    }

    private var yearGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Theme.SpacingKey.sm.value) {
            ForEach(0..<12, id: \.self) { offset in
                yearCell(yearPageStart + offset)
            }
        }
    }

    private func yearCell(_ year: Int) -> some View {
        let isSelected = year == displayedYear
        let isCurrent = year == currentYear
        return Button {
            selectYear(year)
        } label: {
            Text(year.formatted(.number.grouping(.never).locale(locale)))
                .textStyle(.bodyBase400)
                .foregroundStyle(isSelected ? selectedContent : (isCurrent ? todayText : theme.text(.textPrimary)))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(isSelected ? selectedFill : .clear, in: Capsule())
                .overlay { if isCurrent && !isSelected { Capsule().stroke(todayRing, lineWidth: 1) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var monthGrid: some View {
        let symbols = calendar.shortMonthSymbols
        let selectedMonth = calendar.component(.month, from: displayed)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                monthCell(index: index, symbol: symbol, isSelected: index + 1 == selectedMonth)
            }
        }
    }

    private func monthCell(index: Int, symbol: String, isSelected: Bool) -> some View {
        Button {
            selectMonth(index + 1)
        } label: {
            Text(symbol)
                .textStyle(.bodyBase400)
                .foregroundStyle(isSelected ? selectedContent : theme.text(.textPrimary))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(isSelected ? selectedFill : .clear, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectYear(_ year: Int) {
        var comps = calendar.dateComponents([.year, .month, .day], from: displayed)
        comps.year = year
        if let d = calendar.date(from: comps) {
            withAnimation(Motion.base.animation) { displayed = d; stage = .months }
        }
    }

    private func selectMonth(_ month: Int) {
        var comps = calendar.dateComponents([.year, .month], from: displayed)
        comps.month = month
        if let d = calendar.date(from: comps) {
            withAnimation(Motion.base.animation) { displayed = d; stage = .days }
        }
    }

    // MARK: - Date math

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayed)) ?? displayed
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        return result
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CalendarView {
    /// Token-fed accent for the selected day (today's ring/text follows the same
    /// ladder); `nil` (default) keeps the hero tokens.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Show or hide the weekday-initials row (default on).
    func showsWeekdayHeader(_ on: Bool = true) -> Self { copy { $0.showsWeekdayHeader = on } }

    /// Override the first day of the week — `1` = Sunday … `7` = Saturday
    /// (clamped); `nil` (default) follows the locale's convention.
    func firstWeekday(_ day: Int?) -> Self { copy { $0.firstWeekdayOverride = day } }

    /// Make the month-year header tappable to jump across months and years:
    /// day grid → year grid → month grid, then back to the chosen month. Off by
    /// default, so existing calendars are visually and behaviorally unchanged.
    func yearPicker(_ enabled: Bool = true) -> Self { copy { $0.yearPickerEnabled = enabled } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    // The calendar is paging/stage-interactive; each cell is a single month frame.
    PreviewMatrix("CalendarView") {
        PreviewCase("Default") {
            CalendarView(selection: .constant(Date.now))
        }
        PreviewCase("Year picker + purple accent") {
            CalendarView(selection: .constant(Date.now))
                .yearPicker()      // tap the header to jump years/months
                .accent(.purple)
        }
        PreviewCase("Monday first · no weekday header") {
            CalendarView(selection: .constant(Date.now))
                .accent(.success)
                .firstWeekday(2)   // Monday first
                .showsWeekdayHeader(false)
        }
    }
}
