//
//  Stat.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A single statistic block: title, value, optional description,
//  figure icon and trend. (daisyUI "Stat".)
//

import SwiftUI

public enum StatTrend {
    case up(String), down(String)

    var text: String { switch self { case .up(let t), .down(let t): return t } }
    var color: Color {
        switch self {
        case .up: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .down: return Theme.shared.foreground(.systemcolorsFgError)
        }
    }
    var systemImage: String { switch self { case .up: return "arrow.up.right"; case .down: return "arrow.down.right" } }
}

public struct Stat: View {
    private let title: String
    private let value: String
    private let description: String?
    private let systemImage: String?
    private let trend: StatTrend?

    public init(title: String, value: String, description: String? = nil, systemImage: String? = nil, trend: StatTrend? = nil) {
        self.title = title
        self.value = value
        self.description = description
        self.systemImage = systemImage
        self.trend = trend
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.md.value) {
            if let systemImage {
                Icon(systemName: systemImage, size: .xl, color: Theme.shared.foreground(.fgHero))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textTertiary))
                Text(value).textStyle(.headingMd).foregroundStyle(Theme.shared.text(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend.systemImage).font(.system(size: 11, weight: .bold))
                            Text(trend.text).textStyle(.labelSm600)
                        }
                        .foregroundStyle(trend.color)
                    }
                    if let description {
                        Text(description).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Stat(title: "Total bookings", value: "1,284", description: "this month", systemImage: "ticket", trend: .up("+12%"))
        Stat(title: "Cancellations", value: "32", trend: .down("-3%"))
    }
    .padding()
}
