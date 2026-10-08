//
//  DateWheelPicker.swift
//  ThemeKit
//  Created by İsa Mercan on 02.10.2026.
//
//  A day / month / year drum picker for a date the user knows by heart — a birth
//  date, a document's expiry — where a month calendar is the wrong tool: nobody
//  pages back forty years to find their birthday. Three wheel columns side by
//  side, each dragged or tapped to a value, the middle row the chosen one.
//
//  Pure SwiftUI: no UIPickerView, so the rows are token-fed and a host design
//  system restyles them through ``DateWheelPickerStyle`` (the selected row's
//  surface, the fade of the rows around it). `TimeWheel` (ThemeKitCalendar) is
//  the time-of-day counterpart.
//
//      @State private var birth = Date()
//      DateWheelPicker(selection: $birth)
//          .range(minimum...Date.now)
//          .columnTitles(day: "Day", month: "Month", year: "Year")
//

import SwiftUI

/// Molecule. Three drum columns — day, month, year — editing one bound date in
/// the locale's Gregorian calendar.
///
/// - The day column follows the month and the year: it lists the days the
///   month has, and a day the new month lacks moves to its last day.
/// - ``range(_:)`` bounds the result; a column can't land outside it.
/// - Each column is one VoiceOver element, adjustable up and down.
public struct DateWheelPicker: View {
    @Environment(\.locale) private var locale
    @Environment(\.dateWheelPickerStyle) private var style
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: Date

    // Configuration — mutated only through the modifiers below (R2).
    private var range: ClosedRange<Date>?
    private var titles: (day: String, month: String, year: String)?
    private var accessibilityID: String?

    public init(selection: Binding<Date>) {   // R1 — binding only
        self._selection = selection
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        return c
    }

    private static func parts(of date: Date, in calendar: Calendar) -> (day: Int, month: Int, year: Int) {
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        return (c.day ?? 1, c.month ?? 1, c.year ?? 2000)
    }

    /// The years a column offers: the range's, else a century back and twenty years on.
    static func years(in range: ClosedRange<Date>?, calendar: Calendar, now: Date = Date()) -> [Int] {
        let current = calendar.component(.year, from: now)
        let low = range.map { calendar.component(.year, from: $0.lowerBound) } ?? current - 100
        let high = range.map { calendar.component(.year, from: $0.upperBound) } ?? current + 20
        return Array(low...max(low, high))
    }

    /// The date the columns show: the selection, or the nearer end of `range` when the
    /// selection lies outside it — so a date the host seeds out of range never shows as
    /// the column's first year.
    static func shown(_ selection: Date, within range: ClosedRange<Date>?) -> Date {
        guard let range else { return selection }
        return min(max(selection, range.lowerBound), range.upperBound)
    }

    private static func dayCount(month: Int, year: Int, in calendar: Calendar) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 31 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    public var body: some View {
        // One calendar and one list of years a render: the columns redraw on every turn.
        let calendar = self.calendar
        let current = Self.parts(of: Self.shown(selection, within: range), in: calendar)
        let years = Self.years(in: range, calendar: calendar)
        HStack(spacing: Theme.SpacingKey.sm.value) {
            DateWheelColumn(title: titles?.day,
                            accessibilityTitle: titles?.day ?? String(themeKit: "Day"),
                            labels: (1...Self.dayCount(month: current.month, year: current.year, in: calendar)).map { "\($0)" },
                            selectedIndex: current.day - 1,
                            isCyclic: true,
                            style: style,
                            isEnabled: isEnabled) { set(day: $0 + 1) }
            DateWheelSeparator()
            DateWheelColumn(title: titles?.month,
                            accessibilityTitle: titles?.month ?? String(themeKit: "Month"),
                            labels: calendar.standaloneMonthSymbols,
                            selectedIndex: current.month - 1,
                            isCyclic: true,
                            style: style,
                            isEnabled: isEnabled) { set(month: $0 + 1) }
            DateWheelSeparator()
            DateWheelColumn(title: titles?.year,
                            accessibilityTitle: titles?.year ?? String(themeKit: "Year"),
                            labels: years.map { "\($0)" },
                            selectedIndex: years.firstIndex(of: current.year) ?? (current.year < (years.first ?? 0) ? 0 : years.count - 1),
                            style: style,
                            isEnabled: isEnabled) { set(year: years[$0]) }
        }
        .a11y("dateWheel", in: accessibilityID)
    }

    // MARK: - Editing

    private func set(day: Int? = nil, month: Int? = nil, year: Int? = nil) {
        let calendar = self.calendar
        let current = Self.parts(of: Self.shown(selection, within: range), in: calendar)
        if let date = Self.date(day: day ?? current.day, month: month ?? current.month, year: year ?? current.year,
                                in: calendar, within: range) {
            selection = date
        }
    }

    /// The date the three columns name. A day the month lacks moves to its last day
    /// (31 → February → 28 or 29); a date outside `range` stops at its nearer end.
    static func date(day: Int, month: Int, year: Int, in calendar: Calendar, within range: ClosedRange<Date>?) -> Date? {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: first)?.count,
              var date = calendar.date(from: DateComponents(year: year, month: month, day: min(max(day, 1), days)))
        else { return nil }
        if let range { date = min(max(date, range.lowerBound), range.upperBound) }
        return date
    }
}

// MARK: - Modifiers (R2 copy-on-write)

public extension DateWheelPicker {
    /// The dates the picker can land on. A column moved past either end stops at it.
    func range(_ range: ClosedRange<Date>?) -> Self { copy { $0.range = range } }

    /// Headers over the three columns — "Day", "Month", "Year". Unset shows none; VoiceOver
    /// still names each column (ThemeKit's own "Day", "Month", "Year").
    func columnTitles(day: String, month: String, year: String) -> Self {
        copy { $0.titles = (day, month, year) }
    }

    /// UI-test identifier, on the picker as `<id>.dateWheel`.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Style

/// What a ``DateWheelPickerStyle`` draws: one row of a column.
public struct DateWheelPickerRowConfiguration {
    /// The row's words — "9", "December", "1994".
    public let label: String
    /// Whether this is the column's chosen value, in the middle row.
    public let isSelected: Bool
    /// How many rows away from the middle — 0 for the chosen one, 1 next to it, 2 at the edge.
    /// A style fades the rows by it.
    public let distance: Int
    /// `false` when the picker is disabled.
    public let isEnabled: Bool
}

/// What a ``DateWheelPickerStyle`` draws over a column: its header.
public struct DateWheelPickerHeaderConfiguration {
    public let title: String
}

/// What a ``DateWheelPickerStyle`` draws behind a column's middle row: the band that marks the
/// choice. It stays put while the drum turns under it.
public struct DateWheelPickerSelectionConfiguration {
    /// `false` when the picker is disabled.
    public let isEnabled: Bool
}

/// Draws the rows (and headers) of a ``DateWheelPicker``. The picker keeps the behaviour —
/// the drag, the snap, the day arithmetic, the range, the accessibility — and the row
/// height; a style paints. Set one with `.dateWheelPickerStyle(_:)`.
///
/// The choice's band belongs in ``makeSelectionBand(configuration:)``: it is drawn once behind
/// the middle row and stays there while the rows turn past it. A band painted by
/// ``makeRow(configuration:)`` for the selected row travels with that row instead.
public protocol DateWheelPickerStyle {
    associatedtype Row: View
    associatedtype Header: View
    associatedtype SelectionBand: View = EmptyView
    @ViewBuilder @MainActor func makeRow(configuration: DateWheelPickerRowConfiguration) -> Row
    @ViewBuilder @MainActor func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> Header
    /// The band behind the middle row, one row high. Default: none.
    @ViewBuilder @MainActor func makeSelectionBand(configuration: DateWheelPickerSelectionConfiguration) -> SelectionBand
}

public extension DateWheelPickerStyle where SelectionBand == EmptyView {
    func makeSelectionBand(configuration: DateWheelPickerSelectionConfiguration) -> EmptyView { EmptyView() }
}

/// ThemeKit's rows: the chosen one on the primary's soft surface in the hero's text, the
/// others fading to tertiary.
public struct DefaultDateWheelPickerStyle: DateWheelPickerStyle, Sendable {
    public init() {}

    public func makeRow(configuration: DateWheelPickerRowConfiguration) -> some View {
        DefaultDateWheelRow(configuration: configuration)
    }

    public func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> some View {
        DefaultDateWheelHeader(configuration: configuration)
    }

    public func makeSelectionBand(configuration: DateWheelPickerSelectionConfiguration) -> some View {
        DefaultDateWheelBand()
    }
}

private struct DefaultDateWheelRow: View {
    let configuration: DateWheelPickerRowConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        Text(configuration.label)
            .textStyle(configuration.isSelected ? .bodyMd500 : .bodyBase500)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var color: Color {
        guard configuration.isEnabled else { return theme.text(.textDisabled) }
        switch configuration.distance {
        case 0: return theme.text(.textHero)
        case 1: return theme.text(.textSecondary)
        default: return theme.text(.textTertiary)
        }
    }
}

/// The primary's soft surface behind the middle row.
private struct DefaultDateWheelBand: View {
    @Environment(\.theme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
            .fill(theme.resolve(.primary).soft)
    }
}

private struct DefaultDateWheelHeader: View {
    let configuration: DateWheelPickerHeaderConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        Text(configuration.title)
            .textStyle(.bodyBase500)
            .foregroundStyle(theme.text(.textPrimary))
            .frame(maxWidth: .infinity)
    }
}

struct AnyDateWheelPickerStyle {
    private enum Part {
        case row(DateWheelPickerRowConfiguration)
        case header(DateWheelPickerHeaderConfiguration)
        case band(DateWheelPickerSelectionConfiguration)
    }

    // One closure, so the `sending` style is captured once.
    private let _make: @MainActor (Part) -> AnyView

    init<S: DateWheelPickerStyle>(_ style: sending S) {
        _make = { part in
            switch part {
            case .row(let configuration): return AnyView(style.makeRow(configuration: configuration))
            case .header(let configuration): return AnyView(style.makeHeader(configuration: configuration))
            case .band(let configuration): return AnyView(style.makeSelectionBand(configuration: configuration))
            }
        }
    }

    @MainActor func row(_ configuration: DateWheelPickerRowConfiguration) -> AnyView { _make(.row(configuration)) }
    @MainActor func header(_ configuration: DateWheelPickerHeaderConfiguration) -> AnyView { _make(.header(configuration)) }
    @MainActor func band(_ configuration: DateWheelPickerSelectionConfiguration) -> AnyView { _make(.band(configuration)) }
}

private struct DateWheelPickerStyleKey: EnvironmentKey {
    static let defaultValue = AnyDateWheelPickerStyle(DefaultDateWheelPickerStyle())
}

extension EnvironmentValues {
    var dateWheelPickerStyle: AnyDateWheelPickerStyle {
        get { self[DateWheelPickerStyleKey.self] }
        set { self[DateWheelPickerStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``DateWheelPickerStyle`` for the `DateWheelPicker`s in this view and its descendants.
    func dateWheelPickerStyle<S: DateWheelPickerStyle>(_ style: sending S) -> some View {
        environment(\.dateWheelPickerStyle, AnyDateWheelPickerStyle(style))
    }
}

// MARK: - Column

/// One drum: five rows showing, the middle one chosen. Dragged, it follows the finger; let go,
/// it spins on with the fling's momentum through the rows between and slows to a stop on one,
/// as UIKit's picker does; tapped, it turns to that row. A cyclic column (days, months) runs on
/// past its last value into its first, as a paper drum does; the years stop at their ends.
struct DateWheelColumn: View {
    /// Rows shown at once; the middle one is the choice.
    static let visibleRows = 5
    static let rowHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 4
    static var pitch: CGFloat { rowHeight + rowSpacing }
    static var height: CGFloat { CGFloat(visibleRows) * rowHeight + CGFloat(visibleRows - 1) * rowSpacing }
    /// How much further than SwiftUI's own prediction a fling carries the drum: its prediction
    /// stops short of a scroll view's, and a fast fling then turned only ten years.
    static let momentum: Double = 2.5
    /// How far past a non-cyclic column's end a finger can pull it, in rows.
    static let overscroll: Double = 0.4

    let title: String?
    let accessibilityTitle: String
    let labels: [String]
    let selectedIndex: Int
    var isCyclic = false
    let style: AnyDateWheelPickerStyle
    let isEnabled: Bool
    let select: (Int) -> Void

    /// Where the drum stands while a finger or a spin turns it, as a row index with its fraction;
    /// `nil` at rest on the selection.
    @State private var position: Double?
    /// The position the finger took the drum at.
    @State private var dragStart: Double?
    /// Bumped by every turn, so a spin a newer turn interrupted doesn't commit its row.
    @State private var turn = 0

    var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            if let title {
                style.header(DateWheelPickerHeaderConfiguration(title: title))
            }
            drum
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(labels.indices.contains(selectedIndex) ? labels[selectedIndex] : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(Self.index(selectedIndex + 1, count: labels.count, cyclic: isCyclic))
            case .decrement: select(Self.index(selectedIndex - 1, count: labels.count, cyclic: isCyclic))
            @unknown default: break
            }
        }
    }

    private var drum: some View {
        DateWheelDrum(position: position ?? Double(selectedIndex), labels: labels, isCyclic: isCyclic,
                      style: style, isEnabled: isEnabled) { index in spin(to: Self.nearest(index, from: position ?? Double(selectedIndex), count: labels.count, cyclic: isCyclic)) }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            // The choice's band, still behind the middle row while the rows turn past it.
            .background(style.band(DateWheelPickerSelectionConfiguration(isEnabled: isEnabled))
                            .frame(height: Self.rowHeight))
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        // A finger stops a spin where it is and takes the drum from there.
                        turn += 1
                        let start = dragStart ?? (position ?? Double(selectedIndex))
                        if dragStart == nil { dragStart = start }
                        position = bounded(start - Double(value.translation.height / Self.pitch))
                    }
                    .onEnded { value in
                        let start = dragStart ?? (position ?? Double(selectedIndex))
                        dragStart = nil
                        let here = start - Double(value.translation.height / Self.pitch)
                        let flung = -Double((value.predictedEndTranslation.height - value.translation.height) / Self.pitch)
                        spin(to: Self.landing(here + flung * Self.momentum, count: labels.count, cyclic: isCyclic))
                    }
            )
            .allowsHitTesting(isEnabled)
    }

    /// Turns the drum to the row at `target` — through the rows between, slowing as it goes —
    /// and chooses it once the drum stops.
    private func spin(to target: Double) {
        let from = position ?? Double(selectedIndex)
        let duration = Self.spinDuration(rows: abs(target - from))
        turn += 1
        let mine = turn
        withAnimation(.timingCurve(0.15, 0.85, 0.3, 1, duration: duration)) { position = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard turn == mine else { return }
            var rest = Transaction()
            rest.disablesAnimations = true
            withTransaction(rest) {
                position = nil
                select(Self.index(Int(target.rounded()), count: labels.count, cyclic: isCyclic))
            }
        }
    }

    /// A finger can't pull a column that doesn't wrap more than a little past its ends.
    private func bounded(_ position: Double) -> Double {
        guard !isCyclic, !labels.isEmpty else { return position }
        return min(max(position, -Self.overscroll), Double(labels.count - 1) + Self.overscroll)
    }

    /// How long a spin of `rows` takes: short for a row, longer for a long fling, as a scroll
    /// view's deceleration is — never more than a second and a quarter.
    static func spinDuration(rows: Double) -> Double {
        min(1.25, 0.2 + 0.14 * rows.squareRoot())
    }

    /// The whole row a spin lands on: the nearest, held to the ends of a column that doesn't wrap.
    /// A cyclic column keeps the drum's own count of turns, so it spins on rather than back.
    static func landing(_ position: Double, count: Int, cyclic: Bool) -> Double {
        let row = position.rounded()
        guard !cyclic, count > 0 else { return row }
        return min(max(row, 0), Double(count - 1))
    }

    /// The drum position of the value `index` nearest to where the drum stands — the short way
    /// round a cyclic column.
    static func nearest(_ index: Int, from position: Double, count: Int, cyclic: Bool) -> Double {
        guard cyclic, count > 0 else { return Double(index) }
        let base = (position / Double(count)).rounded(.down) * Double(count)
        let candidates = [base - Double(count), base, base + Double(count)].map { $0 + Double(index) }
        return candidates.min { abs($0 - position) < abs($1 - position) } ?? Double(index)
    }

    /// The value `position` lands on: wrapped round a cyclic column, stopped at the ends of
    /// any other.
    static func index(_ position: Int, count: Int, cyclic: Bool) -> Int {
        guard count > 0 else { return 0 }
        return cyclic ? ((position % count) + count) % count : min(max(position, 0), count - 1)
    }

    /// The value drawn at `position`, or `nil` past the end of a column that doesn't wrap.
    static func resolved(_ position: Int, count: Int, cyclic: Bool) -> Int? {
        guard count > 0 else { return nil }
        if cyclic { return index(position, count: count, cyclic: true) }
        return (0..<count).contains(position) ? position : nil
    }
}

/// The drum's rows around the middle line, drawn where `position` has carried them: a window
/// of seven (one beyond each edge, so a row slides in rather than appearing). Animatable, so a
/// spin redraws it on every frame and the rows between pass through the middle.
private struct DateWheelDrum: View, Animatable {
    var position: Double
    let labels: [String]
    let isCyclic: Bool
    let style: AnyDateWheelPickerStyle
    let isEnabled: Bool
    let tap: (Int) -> Void

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        let nearest = Int(position.rounded())
        let fraction = position - Double(nearest)
        return ZStack {
            ForEach(-3...3, id: \.self) { step in
                if let index = DateWheelColumn.resolved(nearest + step, count: labels.count, cyclic: isCyclic) {
                    let place = Double(step) - fraction
                    style.row(DateWheelPickerRowConfiguration(label: labels[index],
                                                              isSelected: step == 0,
                                                              distance: min(Int(abs(place).rounded()), 2),
                                                              isEnabled: isEnabled))
                        .frame(height: DateWheelColumn.rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { tap(index) }
                        .offset(y: CGFloat(place) * DateWheelColumn.pitch)
                }
            }
        }
    }
}

/// The hairline between two columns.
private struct DateWheelSeparator: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.border(.borderPrimary))
            .frame(width: 1)
            .padding(.top, Theme.SpacingKey.xl.value)
            .accessibilityHidden(true)
    }
}
