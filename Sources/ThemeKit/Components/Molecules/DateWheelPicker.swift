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
//          .columnTitles(day: "Gün", month: "Ay", year: "Yıl")
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

    private var parts: (day: Int, month: Int, year: Int) {
        let c = calendar.dateComponents([.day, .month, .year], from: selection)
        return (c.day ?? 1, c.month ?? 1, c.year ?? 2000)
    }

    /// The years a column offers: the range's, else a century back and twenty years on.
    private var years: [Int] {
        let now = calendar.component(.year, from: Date())
        let low = range.map { calendar.component(.year, from: $0.lowerBound) } ?? now - 100
        let high = range.map { calendar.component(.year, from: $0.upperBound) } ?? now + 20
        return Array(low...max(low, high))
    }

    private var monthNames: [String] {
        calendar.standaloneMonthSymbols
    }

    private func dayCount(month: Int, year: Int) -> Int {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? selection
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    public var body: some View {
        let current = parts
        HStack(spacing: Theme.SpacingKey.sm.value) {
            DateWheelColumn(title: titles?.day,
                            accessibilityTitle: titles?.day ?? String(themeKit: "Day"),
                            labels: (1...dayCount(month: current.month, year: current.year)).map { "\($0)" },
                            selectedIndex: current.day - 1,
                            isCyclic: true,
                            style: style,
                            isEnabled: isEnabled) { set(day: $0 + 1) }
            DateWheelSeparator()
            DateWheelColumn(title: titles?.month,
                            accessibilityTitle: titles?.month ?? String(themeKit: "Month"),
                            labels: monthNames,
                            selectedIndex: current.month - 1,
                            isCyclic: true,
                            style: style,
                            isEnabled: isEnabled) { set(month: $0 + 1) }
            DateWheelSeparator()
            DateWheelColumn(title: titles?.year,
                            accessibilityTitle: titles?.year ?? String(themeKit: "Year"),
                            labels: years.map { "\($0)" },
                            selectedIndex: years.firstIndex(of: current.year) ?? 0,
                            style: style,
                            isEnabled: isEnabled) { set(year: years[$0]) }
        }
        .a11y("dateWheel", in: accessibilityID)
    }

    // MARK: - Editing

    private func set(day: Int? = nil, month: Int? = nil, year: Int? = nil) {
        let current = parts
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

    /// Headers over the three columns — "Gün", "Ay", "Yıl". Unset shows none; VoiceOver
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
    /// The row's words — "9", "Aralık", "1994".
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

/// Draws the rows (and headers) of a ``DateWheelPicker``. The picker keeps the behaviour —
/// the drag, the snap, the day arithmetic, the range, the accessibility — and the row
/// height; a style paints. Set one with `.dateWheelPickerStyle(_:)`.
public protocol DateWheelPickerStyle {
    associatedtype Row: View
    associatedtype Header: View
    @ViewBuilder @MainActor func makeRow(configuration: DateWheelPickerRowConfiguration) -> Row
    @ViewBuilder @MainActor func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> Header
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
            .background(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .fill(configuration.isSelected ? theme.resolve(.primary).soft : .clear)
            )
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
    }

    // One closure, so the `sending` style is captured once.
    private let _make: @MainActor (Part) -> AnyView

    init<S: DateWheelPickerStyle>(_ style: sending S) {
        _make = { part in
            switch part {
            case .row(let configuration): return AnyView(style.makeRow(configuration: configuration))
            case .header(let configuration): return AnyView(style.makeHeader(configuration: configuration))
            }
        }
    }

    @MainActor func row(_ configuration: DateWheelPickerRowConfiguration) -> AnyView { _make(.row(configuration)) }
    @MainActor func header(_ configuration: DateWheelPickerHeaderConfiguration) -> AnyView { _make(.header(configuration)) }
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

/// One drum: five rows showing, the middle one chosen. Dragged, it follows the finger and
/// snaps to the nearest row (with the fling's momentum); tapped, a row becomes the choice.
/// A cyclic column (days, months) runs on past its last value into its first, as a
/// paper drum does; the years stop at their ends.
struct DateWheelColumn: View {
    /// Rows shown at once; the middle one is the choice.
    static let visibleRows = 5
    static let rowHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 4
    static var pitch: CGFloat { rowHeight + rowSpacing }
    static var height: CGFloat { CGFloat(visibleRows) * rowHeight + CGFloat(visibleRows - 1) * rowSpacing }

    let title: String?
    let accessibilityTitle: String
    let labels: [String]
    let selectedIndex: Int
    var isCyclic = false
    let style: AnyDateWheelPickerStyle
    let isEnabled: Bool
    let select: (Int) -> Void

    @State private var drag: CGFloat = 0

    var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            if let title {
                style.header(DateWheelPickerHeaderConfiguration(title: title))
            }
            rows
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

    /// The rows around the middle line, drawn where the drag has carried them: a window of
    /// seven (one beyond each edge, so a row slides in rather than appearing).
    private var rows: some View {
        // How far the drag has turned the drum, in rows; positive brings earlier rows down.
        let turned = Double(drag / Self.pitch)
        let centre = Double(selectedIndex) - turned
        let nearest = Int(centre.rounded())
        let fraction = centre - Double(nearest)
        return ZStack {
            ForEach(-3...3, id: \.self) { step in
                let position = nearest + step
                if let index = Self.resolved(position, count: labels.count, cyclic: isCyclic) {
                    let place = Double(step) - fraction
                    style.row(DateWheelPickerRowConfiguration(label: labels[index],
                                                              isSelected: step == 0,
                                                              distance: min(Int(abs(place).rounded()), 2),
                                                              isEnabled: isEnabled))
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { choose(index) }
                        .offset(y: CGFloat(place) * Self.pitch)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { drag = $0.translation.height }
                .onEnded { value in
                    let moved = Int((-value.predictedEndTranslation.height / Self.pitch).rounded())
                    choose(Self.index(selectedIndex + moved, count: labels.count, cyclic: isCyclic))
                }
        )
        .allowsHitTesting(isEnabled)
    }

    private func choose(_ index: Int) {
        withAnimation(Motion.fast.animation) {
            drag = 0
            select(index)
        }
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
