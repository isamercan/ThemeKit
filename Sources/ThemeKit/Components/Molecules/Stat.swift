//
//  Stat.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum StatTrend {
    case up(String), down(String)

    var text: String { switch self { case .up(let t), .down(let t): return t } }
    /// Spoken trend including direction, since the arrow glyph alone is silent
    /// to VoiceOver — e.g. "up 12%".
    var accessibleText: String {
        switch self {
        case .up(let t): return String(themeKit: "up \(t)")
        case .down(let t): return String(themeKit: "down \(t)")
        }
    }
    func color(_ theme: Theme) -> Color {
        switch self {
        case .up: return theme.foreground(.systemcolorsFgSuccess)
        case .down: return theme.foreground(.systemcolorsFgError)
        }
    }
    var systemImage: String { switch self { case .up: return "arrow.up.right"; case .down: return "arrow.down.right" } }
}

/// Molecule. A single statistic block: title, value, optional description,
/// figure icon and trend. (daisyUI "Stat".) Per the modifier-based architecture
/// (COMPONENT_REFACTOR_RULES R1–R7) the init takes only its `title` + `value`;
/// every other axis (prefix/suffix, description, figure icon, trend, loading) is
/// a chainable, order-free modifier.
///
///     Stat(title: "Bookings", value: 1284)
///         .suffix("$").icon("ticket").trend(.up("+12%")).loading(refreshing)
public struct Stat: View {
    @Environment(\.theme) private var theme

    private enum Value { case text(String), number(Int) }

    private let title: String
    private let value: Value

    // Appearance/content — mutated only through the modifiers below (R2).
    private var prefix: String?
    private var suffix: String?
    private var isLoading = false
    private var description: String?
    private var systemImage: String?
    private var trend: StatTrend?

    @Environment(\.statStyle) private var statStyle

    public init(title: String, value: String) {   // R1 — content only
        self.title = title
        self.value = .text(value)
    }

    /// Numeric value that animates (count-up / roll) on change, via `RollingNumber`.
    public init(title: String, value: Int) {   // R1 — content only
        self.title = title
        self.value = .number(value)
    }

    public var body: some View {
        statStyle.makeBody(configuration: StatStyleConfiguration(
            title: title,
            value: AnyView(valueRow),
            trend: trend.map { AnyView(TrendChip($0).size(.small)) },
            description: description,
            systemImage: systemImage
        ))
        // Read the whole stat as one phrase instead of four disconnected swipes,
        // and turn the trend arrow glyph into spoken direction.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if let prefix {
                Text(prefix).textStyle(.headingSm).foregroundStyle(theme.text(.textSecondary))
            }
            valueView
            if let suffix {
                Text(suffix).textStyle(.headingSm).foregroundStyle(theme.text(.textSecondary))
            }
        }
    }

    @ViewBuilder
    private var valueView: some View {
        if isLoading {
            Skeleton(.capsule).size(width: 96, height: 26)
        } else {
            switch value {
            case .text(let string):
                Text(string).textStyle(.headingMd).foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            case .number(let number):
                RollingNumber(number).size(28).weight(.semibold).color(theme.text(.textPrimary))
            }
        }
    }

    private var valueString: String {
        if isLoading { return String(themeKit: "Loading") }
        let core: String
        switch value {
        case .text(let string): core = string
        case .number(let number): core = "\(number)"
        }
        return [prefix, core, suffix].compactMap { $0 }.joined(separator: " ")
    }

    private var accessibilityLabel: String {
        [title, valueString, trend?.accessibleText, description]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Stat {
    /// Unit/symbol shown before the value (e.g. a currency sign).
    func prefix(_ s: String?) -> Self { copy { $0.prefix = s } }

    /// Unit/symbol shown after the value.
    func suffix(_ s: String?) -> Self { copy { $0.suffix = s } }

    /// Swap the value for a skeleton placeholder while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Secondary caption line beside the trend.
    func description(_ s: String?) -> Self { copy { $0.description = s } }

    /// Leading figure SF Symbol.
    func icon(_ systemImage: String?) -> Self { copy { $0.systemImage = systemImage } }

    /// Trend badge (arrow + delta) in success/error color.
    func trend(_ t: StatTrend?) -> Self { copy { $0.trend = t } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 16) {
        Stat(title: "Total bookings", value: "1,284").description("this month").icon("ticket").trend(.up("+12%"))
        Stat(title: "Cancellations", value: "32").trend(.down("-3%"))
    }
    .padding()
}

#Preview("States") {
    PreviewMatrix("Stat") {
        PreviewCase("Default")  { Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%")) }
        PreviewCase("Loading")  { Stat(title: "Bookings", value: "0").loading() }
        PreviewCase("Down")     { Stat(title: "Cancellations", value: "32").trend(.down("-3%")) }
        PreviewCase("Centered") { Stat(title: "Revenue", value: "$48,210").icon("creditcard").statStyle(.centered) }
    }
}
