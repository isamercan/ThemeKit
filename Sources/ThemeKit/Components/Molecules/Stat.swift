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
    var color: Color {
        switch self {
        case .up: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .down: return Theme.shared.foreground(.systemcolorsFgError)
        }
    }
    var systemImage: String { switch self { case .up: return "arrow.up.right"; case .down: return "arrow.down.right" } }
}

/// Molecule. A single statistic block: title, value, optional description,
/// figure icon and trend. (daisyUI "Stat".)
public struct Stat: View {
    private enum Value { case text(String), number(Int) }

    private let title: String
    private let value: Value
    private let prefix: String?
    private let suffix: String?
    private let isLoading: Bool
    private let description: String?
    private let systemImage: String?
    private let trend: StatTrend?

    @Environment(\.statStyle) private var statStyle

    public init(
        title: String, value: String,
        prefix: String? = nil, suffix: String? = nil, isLoading: Bool = false,
        description: String? = nil, systemImage: String? = nil, trend: StatTrend? = nil
    ) {
        self.init(title: title, value: .text(value), prefix: prefix, suffix: suffix,
                  isLoading: isLoading, description: description, systemImage: systemImage, trend: trend)
    }

    /// Numeric value that animates (count-up / roll) on change, via `RollingNumber`.
    public init(
        title: String, value: Int,
        prefix: String? = nil, suffix: String? = nil, isLoading: Bool = false,
        description: String? = nil, systemImage: String? = nil, trend: StatTrend? = nil
    ) {
        self.init(title: title, value: .number(value), prefix: prefix, suffix: suffix,
                  isLoading: isLoading, description: description, systemImage: systemImage, trend: trend)
    }

    private init(
        title: String, value: Value, prefix: String?, suffix: String?,
        isLoading: Bool, description: String?, systemImage: String?, trend: StatTrend?
    ) {
        self.title = title
        self.value = value
        self.prefix = prefix
        self.suffix = suffix
        self.isLoading = isLoading
        self.description = description
        self.systemImage = systemImage
        self.trend = trend
    }

    public var body: some View {
        statStyle.makeBody(configuration: StatStyleConfiguration(
            title: title,
            value: AnyView(valueRow),
            trend: trend.map { AnyView(trendBadge($0)) },
            description: description,
            systemImage: systemImage
        ))
        // Read the whole stat as one phrase instead of four disconnected swipes,
        // and turn the trend arrow glyph into spoken direction.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private func trendBadge(_ trend: StatTrend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend.systemImage).font(.system(size: 11, weight: .bold))
            Text(trend.text).textStyle(.labelSm600)
        }
        .foregroundStyle(trend.color)
    }

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if let prefix {
                Text(prefix).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textSecondary))
            }
            valueView
            if let suffix {
                Text(suffix).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textSecondary))
            }
        }
    }

    @ViewBuilder
    private var valueView: some View {
        if isLoading {
            Skeleton(.capsule, width: 96, height: 26)
        } else {
            switch value {
            case .text(let string):
                Text(string).textStyle(.headingMd).foregroundStyle(Theme.shared.text(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            case .number(let number):
                RollingNumber(number, size: 28, weight: .semibold, color: Theme.shared.text(.textPrimary))
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

#Preview {
    VStack(spacing: 16) {
        Stat(title: "Total bookings", value: "1,284", description: "this month", systemImage: "ticket", trend: .up("+12%"))
        Stat(title: "Cancellations", value: "32", trend: .down("-3%"))
    }
    .padding()
}

#Preview("States") {
    PreviewMatrix("Stat") {
        PreviewCase("Default")  { Stat(title: "Bookings", value: "1,284", systemImage: "ticket", trend: .up("+12%")) }
        PreviewCase("Loading")  { Stat(title: "Bookings", value: "0", isLoading: true) }
        PreviewCase("Down")     { Stat(title: "Cancellations", value: "32", trend: .down("-3%")) }
        PreviewCase("Centered") { Stat(title: "Revenue", value: "₺48,210", systemImage: "creditcard").statStyle(.centered) }
    }
}
