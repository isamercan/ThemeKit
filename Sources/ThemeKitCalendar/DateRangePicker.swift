//
//  DateRangePicker.swift
//  ThemeKitCalendar
//
//  A ThemeKit-themed date-range calendar. Wraps Almanac's `CalendarRangePickerView`
//  and injects a `CalendarStyle` derived from the active ThemeKit `Theme`, so the
//  calendar re-skins with the current preset / per-subtree theme with no manual
//  colour wiring. Named `DateRangePicker` (not `Calendar`) to avoid colliding with
//  `Foundation.Calendar` and to echo SwiftUI's `DatePicker`.
//
#if os(iOS)
import SwiftUI
import ThemeKit
// Re-export so a single `import ThemeKitCalendar` also brings the Almanac types
// callers need (CalendarPickerConfiguration, HolidayEntry, CalendarPickerResult…).
@_exported import Almanac

/// A token-bound date-range calendar.
///
/// ```swift
/// DateRangePicker(.hotel, configuration: config) { result in
///     print(result.goingDate, result.returnDate)
/// }
/// ```
///
/// The calendar's colours come from the active ``Theme`` (`@Environment(\.theme)`),
/// so switching a preset or injecting `.theme(_:)` on a parent re-skins it too.
public struct DateRangePicker: View {
    /// The framing/titles of the picker — a plain range, or hotel / rent-a-car copy.
    public enum Purpose: Sendable { case range, hotel, rentACar }

    private let purpose: Purpose
    private let configuration: CalendarPickerConfiguration
    private let onApply: (CalendarPickerResult) -> Void
    private let onCancel: () -> Void

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
        picker.calendarStyle(.themeKit(theme))
    }

    @ViewBuilder private var picker: some View {
        switch purpose {
        case .range:
            CalendarRangePickerView.rangeSelector(configuration: configuration, onApply: onApply, onCancel: onCancel)
        case .hotel:
            CalendarRangePickerView.hotel(configuration: configuration, onApply: onApply, onCancel: onCancel)
        case .rentACar:
            CalendarRangePickerView.rentACar(configuration: configuration, onApply: onApply, onCancel: onCancel)
        }
    }
}

public extension View {
    /// Apply the ThemeKit-derived calendar style (from a specific `Theme`) to any
    /// Almanac calendar view — the escape hatch when you compose Almanac directly.
    func themeKitCalendarStyle(_ theme: Theme) -> some View {
        calendarStyle(.themeKit(theme))
    }
}
#endif
