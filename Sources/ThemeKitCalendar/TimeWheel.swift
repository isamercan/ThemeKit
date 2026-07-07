//
//  TimeWheel.swift
//  ThemeKitCalendar
//
//  A ThemeKit-themed drum time picker wrapping Almanac's `TimeWheel24` /
//  `TimeWheelAmPm`. Its text colour comes from the active `Theme`, so a date+time
//  flow (calendar + wheel) stays on-brand. iOS-only.
//
//  ```swift
//  TimeWheel(hour: $hour, minute: $minute)           // 24-hour
//  TimeWheel(hour: $hour, minute: $minute, isAM: $am).format(.amPm)
//  ```
//
#if os(iOS)
import SwiftUI
import ThemeKit
import Almanac

public struct TimeWheel: View {
    public enum Format: Sendable { case h24, amPm }

    @Binding private var hour: Int
    @Binding private var minute: Int
    @Binding private var isAM: Bool
    private var format: Format = .h24

    @Environment(\.theme) private var theme

    public init(hour: Binding<Int>, minute: Binding<Int>, isAM: Binding<Bool> = .constant(true)) {   // R1
        self._hour = hour
        self._minute = minute
        self._isAM = isAM
    }

    private var config: TimePickerConfig {
        var c = TimePickerConfig()
        c.textColor = theme.text(.textPrimary)   // token-fed
        return c
    }

    public var body: some View {
        switch format {
        case .h24:
            TimeWheel24(hour: hour, minute: minute,
                        onTimeChanged: { h, m in hour = h; minute = m },
                        config: config)
        case .amPm:
            TimeWheelAmPm(hour: hour, minute: minute, isAm: isAM,
                          onTimeChanged: { h, m, a in hour = h; minute = m; isAM = a },
                          config: config)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write)

public extension TimeWheel {
    /// 24-hour (default) or 12-hour AM/PM.
    func format(_ f: Format) -> Self {
        var c = self
        c.format = f
        return c
    }
}
#endif
