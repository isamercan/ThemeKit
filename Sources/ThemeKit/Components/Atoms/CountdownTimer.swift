//
//  CountdownTimer.swift
//  ThemeKit
//
//  A live countdown to a deadline — segmented HH:MM:SS boxes that tick every second
//  via `TimelineView(.periodic)`. Token-bound; `.urgent` swaps to the error palette
//  for "price held for 09:58" pressure. `onFinish` fires once when the deadline passes.
//

import SwiftUI

public enum CountdownStyle {
    /// Neutral surface boxes.
    case standard
    /// Error/red boxes — draws urgency (a held price, a flash sale).
    case urgent

    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .standard: return theme.text(.textPrimary)
        case .urgent: return theme.foreground(.systemcolorsFgError)
        }
    }
    func background(_ theme: Theme) -> Color {
        switch self {
        case .standard: return theme.background(.bgSecondaryLight)
        case .urgent: return theme.background(.systemcolorsBgErrorLight)
        }
    }
}

public enum CountdownSize {
    case small, medium, large

    var textStyle: TextStyle {
        switch self {
        case .small: return .labelSm700
        case .medium: return .labelMd700
        case .large: return .headingXs
        }
    }
    var boxWidth: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 32
        case .large: return 40
        }
    }
    var boxHeight: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 32
        case .large: return 44
        }
    }
}

/// A token-bound live countdown to `deadline`.
///
/// ```swift
/// CountdownTimer(until: .now.addingTimeInterval(600))
///     .style(.urgent).size(.large).showsDays(false) { /* expired */ }
/// ```
public struct CountdownTimer: View {
    @Environment(\.theme) private var theme

    private let deadline: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: CountdownStyle = .standard
    private var size: CountdownSize = .medium
    private var showsDays: Bool = false
    private var onFinish: (() -> Void)?

    public init(until deadline: Date) {   // R1 — content
        self.deadline = deadline
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, deadline.timeIntervalSince(context.date))
            HStack(spacing: Theme.SpacingKey.xs.value) {
                let segs = segments(remaining)
                ForEach(Array(segs.enumerated()), id: \.offset) { index, seg in
                    if index > 0 { Text(":").textStyle(size.textStyle).foregroundStyle(style.foreground(theme)) }
                    box(seg.value, label: seg.label)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText(remaining))
        }
        .task(id: deadline) {
            let secs = deadline.timeIntervalSinceNow
            guard secs > 0 else { onFinish?(); return }
            try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
            onFinish?()
        }
    }

    private func box(_ value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .textStyle(size.textStyle)
                .foregroundStyle(style.foreground(theme))
                .frame(width: size.boxWidth, height: size.boxHeight)
                .background(style.background(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            if !label.isEmpty {
                Text(label).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            }
        }
    }

    private func segments(_ remaining: TimeInterval) -> [(value: Int, label: String)] {
        let total = Int(remaining)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        var out: [(Int, String)] = []
        if showsDays { out.append((days, "days")) }
        out.append((showsDays ? hours : hours + days * 24, "hrs"))
        out.append((minutes, "min"))
        out.append((seconds, "sec"))
        return out
    }

    private func accessibilityText(_ remaining: TimeInterval) -> String {
        remaining <= 0 ? "Time's up" : segments(remaining).map { "\($0.value) \($0.label)" }.joined(separator: " ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CountdownTimer {
    /// standard / urgent colour treatment.
    func style(_ s: CountdownStyle) -> Self { copy { $0.style = s } }
    /// Size tier: small / medium / large.
    func size(_ s: CountdownSize) -> Self { copy { $0.size = s } }
    /// Shows a leading days box (default false — HH rolls days into hours).
    func showsDays(_ on: Bool) -> Self { copy { $0.showsDays = on } }
    /// Called once when the deadline passes (also immediately if already past).
    func onFinish(_ action: (() -> Void)?) -> Self { copy { $0.onFinish = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 24) {
        CountdownTimer(until: .now.addingTimeInterval(9 * 60 + 58)).style(.urgent).size(.large)
        CountdownTimer(until: .now.addingTimeInterval(3 * 86_400 + 3_720)).showsDays(true)
    }
    .padding()
}
