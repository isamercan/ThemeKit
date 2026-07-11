//
//  Counter.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Digit-box scale of a ``Counter``.
public enum CounterSize {
    case small, regular, large

    var valueStyle: TextStyle {
        switch self {
        case .small: return .labelBase700
        case .regular: return .labelMd700
        case .large: return .labelLg700
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .small: return 36
        case .regular: return 44
        case .large: return 56
        }
    }
}

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
    // Appearance — mutated only through the modifiers below (R2).
    private var size: CounterSize = .regular
    private var accent: SemanticColor?
    private var separator: String?

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

    /// Digit tint — semantic accent when set, else primary text (R4).
    private var valueColor: Color { accent?.accent ?? theme.text(.textPrimary) }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0, let separator {
                    Text(separator)
                        .textStyle(size.valueStyle)
                        .monospacedDigit()
                        .foregroundStyle(theme.text(.textTertiary))
                }
                segmentBox(segment)
            }
        }
    }

    private func segmentBox(_ segment: Segment) -> some View {
        VStack(spacing: 2) {
            Text(zeroPad2(segment.value))
                .textStyle(size.valueStyle)
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text(segment.label)
                .textStyle(.overline400)
                .foregroundStyle(theme.text(.textTertiary))
        }
        .frame(minWidth: size.minWidth)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .background(theme.background(.bgElevatorTertiary),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Counter {
    /// Digit-box scale: small / regular / large (default regular).
    func size(_ s: CounterSize) -> Self { copy { $0.size = s } }

    /// Token-fed tint for the digits; `nil` (default) keeps primary text.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Text drawn between the boxes (e.g. ":"); `nil` (default) renders none.
    func separator(_ text: String?) -> Self { copy { $0.separator = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Counter") {
        PreviewCase("Default") {
            Counter(days: 2, hours: 8, minutes: 45)
        }
        PreviewCase("Large · primary accent + separator") {
            Counter(days: 2, hours: 8, minutes: 45)
                .size(.large)
                .accent(.primary)
                .separator(":")
        }
        PreviewCase("Small · error accent") {
            Counter(segments: [.init(value: 12, label: "Min"), .init(value: 30, label: "Sec")])
                .size(.small)
                .accent(.error)
        }
    }
}
