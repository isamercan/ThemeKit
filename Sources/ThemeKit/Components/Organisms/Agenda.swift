//
//  Agenda.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A date-grouped schedule list: events under day headers with a leading time
//  column and a per-event accent rail. (HeroUI Pro "Agenda".) Distinct from
//  `Timeline`, which is a progress rail with states — this is a calendar of
//  what's happening when.
//

import SwiftUI

/// One scheduled event. `isAllDay` swaps the time column for an "All day" chip.
public struct AgendaEvent: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let location: String?
    public let start: Date
    public let end: Date?
    public let isAllDay: Bool
    public let accent: SemanticColor?
    public let onTap: (() -> Void)?

    public init(_ title: String, start: Date, end: Date? = nil, subtitle: String? = nil,
                location: String? = nil, isAllDay: Bool = false, accent: SemanticColor? = nil,
                id: String? = nil, onTap: (() -> Void)? = nil) {
        self.title = title
        self.start = start
        self.end = end
        self.subtitle = subtitle
        self.location = location
        self.isAllDay = isAllDay
        self.accent = accent
        self.onTap = onTap
        self.id = id ?? "\(title)-\(start.timeIntervalSinceReferenceDate)"
    }
}

/// Organism. `Agenda(events)` groups by day and renders a schedule.
public struct Agenda: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var envLocale

    private let events: [AgendaEvent]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var showsDayHeaders = true
    private var localeOverride: Locale?
    private var emptyContent: AnyView?
    private var headerContent: AnyView?

    public init(_ events: [AgendaEvent]) {   // R1 — content only
        self.events = events
    }

    private var locale: Locale { localeOverride ?? envLocale }
    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = locale
        return c
    }

    /// Events bucketed by day, days ascending, events within a day by start time.
    private var days: [(day: Date, events: [AgendaEvent])] {
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { key in
            (key, groups[key]!.sorted { $0.start < $1.start })
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let headerContent { headerContent }
            if events.isEmpty {
                emptyContent ?? AnyView(EmptyState(String(themeKit: "Nothing scheduled")).icon("calendar"))
            } else {
                ForEach(days, id: \.day) { group in
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                        if showsDayHeaders {
                            Text(dayTitle(group.day))
                                .textStyle(.labelBase700)
                                .foregroundStyle(theme.text(.textPrimary))
                        }
                        ForEach(group.events) { eventRow($0) }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: AgendaEvent) -> some View {
        Button {
            event.onTap?()
        } label: {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                timeColumn(event)
                    .frame(width: 60, alignment: .leading)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(event.accent?.solid ?? SemanticColor.primary.solid)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if let subtitle = event.subtitle {
                        Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                    if let location = event.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .labelStyle(.titleAndIcon)
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(event.onTap == nil)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func timeColumn(_ event: AgendaEvent) -> some View {
        if event.isAllDay {
            Tag(String(themeKit: "All day"))
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(timeText(event.start)).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                if let end = event.end {
                    Text(timeText(end)).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    private func dayTitle(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return String(themeKit: "Today") }
        if calendar.isDateInTomorrow(day) { return String(themeKit: "Tomorrow") }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Agenda {
    /// Show or hide the per-day header rows (default on).
    func showsDayHeaders(_ on: Bool = true) -> Self { copy { $0.showsDayHeaders = on } }

    /// Locale for date/time formatting; defaults to the environment locale.
    func locale(_ locale: Locale) -> Self { copy { $0.localeOverride = locale } }

    /// Replace the built-in empty state.
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.emptyContent = AnyView(content()) }
    }

    /// A header shown above the schedule.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.headerContent = AnyView(content()) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let now = Date.now
    let cal = Calendar.current
    // `let` closure, not a local `func` — the #Preview macro rejects local funcs.
    let at: (_ h: Int, _ m: Int, _ dayOffset: Int) -> Date = { h, m, dayOffset in
        let base = cal.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return cal.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
    }
    let events = [
        AgendaEvent("Team standup", start: at(9, 30, 0), end: at(10, 0, 0), location: "Zoom", accent: .primary),
        AgendaEvent("Design review", start: at(13, 0, 0), end: at(14, 0, 0), subtitle: "New components", accent: .purple),
        AgendaEvent("Company offsite", start: at(0, 0, 1), isAllDay: true, accent: .success),
        AgendaEvent("1:1 with Ada", start: at(11, 0, 1), end: at(11, 30, 1)),
    ]
    return PreviewMatrix("Agenda") {
        PreviewCase("Schedule") { Agenda(events) }
        PreviewCase("No day headers") { Agenda(Array(events.prefix(2))).showsDayHeaders(false) }
        PreviewCase("Empty") { Agenda([]) }
    }
}
