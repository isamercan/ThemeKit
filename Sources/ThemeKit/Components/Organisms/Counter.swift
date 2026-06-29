//
//  Counter.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Displays numeric values in labelled boxes — e.g. a countdown
/// (Day / Hour / Minute).
public struct Counter: View {
    @Environment(\.theme) private var theme

    public struct Segment: Identifiable {
        public let id = UUID()
        let value: Int
        let label: String
        public init(value: Int, label: String) {
            self.value = value
            self.label = label
        }
    }

    private let segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }

    /// Convenience for a day/hour/minute countdown.
    public init(days: Int, hours: Int, minutes: Int) {
        self.segments = [
            .init(value: days, label: String(themeKit: "Days")),
            .init(value: hours, label: String(themeKit: "Hours")),
            .init(value: minutes, label: String(themeKit: "Minutes")),
        ]
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(segments) { segment in
                VStack(spacing: 2) {
                    Text(String(format: "%02d", segment.value))
                        .textStyle(.labelMd700)
                        .monospacedDigit()
                        .foregroundStyle(theme.text(.textPrimary))
                    Text(segment.label)
                        .textStyle(.overline400)
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .frame(minWidth: 44)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(theme.background(.bgElevatorTertiary),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            }
        }
    }
}

#Preview {
    Counter(days: 2, hours: 8, minutes: 45).padding()
}
