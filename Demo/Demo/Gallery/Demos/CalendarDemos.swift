//
//  CalendarDemos.swift
//  Demo
//
//  Demos for the opt-in ThemeKitCalendar add-on — an Almanac calendar themed by
//  ThemeKit tokens. Shows the five surfaces, modifier-driven appearance, custom
//  token-bound day cells (heat-map), holidays, plus the drum TimeWheel and the live
//  style designer. Switch a theme above → everything re-skins.
//

import SwiftUI
import ThemeKit

// The ThemeKitCalendar add-on is behind the package's "Calendar" trait (default
// OFF, so a plain checkout resolves zero third-party deps). Enable it in Xcode via
// *Package Dependencies ▸ ThemeKit ▸ Traits ▸ Calendar* to resolve Almanac. This
// `canImport` guard lets the Demo compile either way: with the trait on you get the
// real add-on demos; with it off the same knob types render a short "enable it" note
// (see the `#else` stubs) so the gallery still builds and lists them.
#if canImport(Almanac)
import ThemeKitCalendar

struct DateRangePickerDemo: View {
    @State private var displayIdx = 0     // 0 picker · 1 month · 2 week · 3 year · 4 browse
    @State private var shapeIdx = 0       // 0 circle · 1 rounded · 2 square
    @State private var accentIdx = 0      // 0 theme · 1 purple · 2 turquoise · 3 orange
    @State private var single = false
    @State private var custom = false     // token-bound heat-map cells via .day { }
    @State private var holidays = false
    @State private var today = false

    private let displays: [DateRangePicker.Display] = [.picker, .month, .week, .year, .browse]
    private let displayLabels = ["Picker", "Month", "Week", "Year", "Browse"]
    private let shapes: [DateRangePicker.DaySelection] = [.circle, .rounded, .square]
    private let accents: [SemanticColor?] = [nil, .purple, .turquoise, .orange]
    private let accentLabels = ["Theme", "Purple", "Turquoise", "Orange"]

    private var thisMonth: (year: Int, month: Int) {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return (c.year ?? 2026, c.month ?? 1)
    }

    private var calendar: DateRangePicker {
        var c = DateRangePicker(.hotel) { _ in flash("Dates applied") } onCancel: { flash("Cancelled") }
            .display(displays[displayIdx])
            .daySelection(shapes[shapeIdx])
            .selectionMode(single ? .single : .range)
        if let accent = accents[accentIdx] { c = c.accent(accent) }
        if today { c = c.showsTodayButton() }
        if holidays {
            let (y, m) = thisMonth
            c = c.holiday(on: [ETSCalendarDate(day: 15, month: m, year: y)], color: .error, name: "Holiday")
                .holiday(on: [ETSCalendarDate(day: 23, month: m, year: y)], color: .success, name: "Festival")
        }
        if custom {                                     // bring-your-own, token-bound heat-map cell
            c = c.day { ctx in
                let level = ctx.day % 3
                let fills = [SemanticColor.success.bg, SemanticColor.success.base, SemanticColor.success.strong]
                return ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ctx.isCurrentMonth ? fills[level] : .clear)
                    Text("\(ctx.day)").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(level == 0 ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textSecondaryInverse))
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                .opacity(ctx.isCurrentMonth ? 1 : 0.25)
            }
        }
        return c
    }

    private var minHeight: CGFloat {
        switch displayIdx { case 2: 210; default: 460 }   // week strip is compact
    }

    var body: some View {
        ComponentStage("DateRangePicker", inspector: [
            ("display", displayLabels[displayIdx]), ("accent", accentLabels[accentIdx]), ("engine", "Almanac"),
        ]) {
            calendar
                .frame(maxWidth: 390, minHeight: minHeight)
                .id("\(displayIdx)-\(single)-\(custom)-\(holidays)")   // rebuild on structural change
        } knobs: {
            Picker("Display", selection: $displayIdx) {
                ForEach(displayLabels.indices, id: \.self) { Text(displayLabels[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Day shape", selection: $shapeIdx) {
                Text("Circle").tag(0); Text("Rounded").tag(1); Text("Square").tag(2)
            }.pickerStyle(.segmented)
            Picker("Accent (token)", selection: $accentIdx) {
                ForEach(accentLabels.indices, id: \.self) { Text(accentLabels[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Single-day selection", isOn: $single)
            Toggle("Custom cells — heat-map via .day { } (ThemeKit tokens)", isOn: $custom)
            Toggle("Holidays (token-coloured)", isOn: $holidays)
            Toggle("\"Jump to today\" button", isOn: $today)
            Text("One component, five surfaces + modifiers. Switch Default/Ocean/Sunset above — it re-skins from theme tokens. Also: .selectedAccessory{} · .monthHeader{} · .dateRangePicker(isPresented:) sheet. (ThemeKitCalendar · Almanac, iOS-only.)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TimeWheelDemo: View {
    @State private var hour = 9
    @State private var minute = 41
    @State private var isAM = true
    @State private var ampm = false

    var body: some View {
        ComponentStage("TimeWheel", inspector: [
            ("time", String(format: "%02d:%02d", hour, minute)), ("format", ampm ? "12h" : "24h"),
        ]) {
            TimeWheel(hour: $hour, minute: $minute, isAM: $isAM)
                .format(ampm ? .amPm : .h24)
                .frame(height: 190)
        } knobs: {
            Toggle("12-hour (AM/PM)", isOn: $ampm)
            Text("Almanac drum time picker — text colour from a theme token. Pair with the calendar for a date + time flow.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CalendarDesignerDemo: View {
    @State private var style = CalendarStyle.themeKit(Theme.shared)

    var body: some View {
        ComponentStage("Calendar Designer", inspector: [("engine", "Almanac")]) {
            CalendarStyleConfigurator(style: $style)
                .frame(maxWidth: 390, minHeight: 470)
        } knobs: {
            Text("Live design playground (day shape · colours · typography · metrics). Seeded from the current theme; `style.generatedSwiftCode` gives copyable Swift.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
#else
// Calendar trait OFF → Almanac isn't resolved. These stubs keep the gallery
// compiling and still list the calendar knobs, each showing how to enable them.
private struct CalendarTraitDisabledNote: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("ThemeKitCalendar add-on disabled")
                .font(.headline)
            Text("Enable the **Calendar** trait — *Package Dependencies ▸ ThemeKit ▸ Traits ▸ Calendar* — to resolve Almanac and load these demos.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: 390)
    }
}
struct DateRangePickerDemo: View { var body: some View { CalendarTraitDisabledNote() } }
struct TimeWheelDemo: View { var body: some View { CalendarTraitDisabledNote() } }
struct CalendarDesignerDemo: View { var body: some View { CalendarTraitDisabledNote() } }
#endif
