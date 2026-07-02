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

    /// Tracks the environment locale so month titles, weekday symbols, and the
    /// first day of the week follow the app's language (and mirror correctly for
    /// RTL). Defaults to the system locale, so existing call sites are unchanged.
    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = locale
        return c
    }

    public init(selection: Binding<Date?>) {
        self._selection = selection
        self._displayed = State(initialValue: selection.wrappedValue ?? Date.now)
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            header
            weekdayRow
            grid
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    private var header: some View {
        HStack {
            navButton("chevron.left", months: -1)
            Spacer()
            Text(displayed.formatted(.dateTime.month(.wide).year().locale(locale)))
                .textStyle(.labelMd700)
                .foregroundStyle(theme.text(.textPrimary))
            Spacer()
            navButton("chevron.right", months: 1)
        }
    }

    private func navButton(_ name: String, months: Int) -> some View {
        Button {
            if let d = calendar.date(byAdding: .month, value: months, to: monthStart) {
                withAnimation(Motion.fast.animation) { displayed = d }
            }
        } label: {
            Icon(systemName: name).size(.sm).color(theme.text(.textPrimary))
                .frame(width: 32, height: 32)
                .mirrorsInRTL()
        }
        .buttonStyle(.plain)
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
                    Color.clear.frame(height: 36)
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
                .foregroundStyle(isSelected ? theme.foreground(.fgSecondary) : (isToday ? theme.text(.textHero) : theme.text(.textPrimary)))
                .frame(width: 36, height: 36)
                .background(isSelected ? theme.background(.bgHero) : .clear, in: Circle())
                .overlay { if isToday && !isSelected { Circle().stroke(theme.border(.borderHero), lineWidth: 1) } }
        }
        .buttonStyle(.plain)
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

#Preview {
    struct Demo: View {
        @State var date: Date? = .now
        var body: some View { CalendarView(selection: $date).padding() }
    }
    return Demo()
}
