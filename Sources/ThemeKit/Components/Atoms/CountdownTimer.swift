//
//  CountdownTimer.swift
//  ThemeKit
//
//  A live countdown to a deadline — segmented HH:MM:SS boxes that tick every second
//  via `TimelineView(.periodic)`. Token-bound; `.urgent` swaps to the error palette
//  for "price held for 09:58" pressure. `onFinish` fires once when the deadline passes.
//
//  Flexible: three formats (.boxed / .inline / .text), automatic urgency escalation
//  below a threshold with a reduce-motion-aware pulse on the last 10 seconds, an
//  expired slot, and Dynamic-Type-safe boxes.
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

/// How the remaining time is laid out.
public enum CountdownFormat: Sendable {
    /// Segmented boxes with unit labels — the default, high-impact.
    case boxed
    /// A single compact `00:09:44` monospaced readout.
    case inline
    /// Natural text, top two units — `"9m 58s"`.
    case text
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
///     .format(.inline).urgentBelow(60).onFinish { soldOut = true }
/// ```
public struct CountdownTimer: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let deadline: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: CountdownStyle = .standard
    private var format: CountdownFormat = .boxed
    private var size: CountdownSize = .medium
    private var showsDays: Bool = false
    private var urgentThreshold: TimeInterval?
    private var onFinish: (() -> Void)?
    private var expiredSlot: AnyView?

    public init(until deadline: Date) {   // R1 — content
        self.deadline = deadline
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, deadline.timeIntervalSince(context.date))
            Group {
                if remaining <= 0 {
                    expiredView
                } else {
                    activeView(remaining)
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

    @ViewBuilder private var expiredView: some View {
        if let expiredSlot {
            expiredSlot
        } else {
            Text("Time's up").textStyle(size.textStyle).foregroundStyle(theme.text(.textTertiary))
        }
    }

    private func activeView(_ remaining: TimeInterval) -> some View {
        let st = effectiveStyle(remaining)
        let pulsing = remaining <= 10 && !reduceMotion
        let beat = Int(remaining) % 2 == 0
        return Group {
            switch format {
            case .boxed: boxed(remaining, st)
            case .inline:
                Text(Self.inlineString(remaining, showsDays: showsDays)).textStyle(size.textStyle).monospacedDigit()
                    .foregroundStyle(st.foreground(theme))
            case .text:
                Text(Self.compactString(remaining, showsDays: showsDays)).textStyle(size.textStyle)
                    .foregroundStyle(st.foreground(theme))
            }
        }
        .opacity(pulsing && beat ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.5), value: beat)
    }

    private func boxed(_ remaining: TimeInterval, _ st: CountdownStyle) -> some View {
        HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            let segs = Self.segments(remaining, showsDays: showsDays)
            ForEach(Array(segs.enumerated()), id: \.offset) { index, seg in
                if index > 0 { Text(":").textStyle(size.textStyle).foregroundStyle(st.foreground(theme)) }
                box(seg.value, label: seg.label, st: st)
            }
        }
        .dynamicTypeClamp()
    }

    private func box(_ value: Int, label: String, st: CountdownStyle) -> some View {
        VStack(spacing: 2) {
            Text(Self.pad2(value))
                .textStyle(size.textStyle)
                .foregroundStyle(st.foreground(theme))
                .frame(minWidth: size.boxWidth, minHeight: size.boxHeight)
                .background(st.background(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            if !label.isEmpty {
                Text(label).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            }
        }
    }

    private func effectiveStyle(_ remaining: TimeInterval) -> CountdownStyle {
        if let urgentThreshold, remaining <= urgentThreshold { return .urgent }
        return style
    }

    /// Breaks a remaining interval into labelled segments (pure; unit-tested).
    static func segments(_ remaining: TimeInterval, showsDays: Bool) -> [(value: Int, label: String)] {
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

    /// `00:09:44`-style readout (pure; unit-tested).
    static func inlineString(_ remaining: TimeInterval, showsDays: Bool) -> String {
        segments(remaining, showsDays: showsDays).map { pad2($0.value) }.joined(separator: ":")
    }

    /// Two-digit zero pad — avoids `String(format: "%02d", Int)`, which passes a 64-bit
    /// `Int` where `%d` expects a 32-bit `CInt` (undefined behaviour / crashes).
    static func pad2(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

    /// Natural top-two-unit readout like `"9m 58s"` (pure; unit-tested).
    static func compactString(_ remaining: TimeInterval, showsDays: Bool) -> String {
        let short = ["days": "d", "hrs": "h", "min": "m", "sec": "s"]
        let parts = segments(remaining, showsDays: showsDays).drop { $0.value == 0 }
        let top = parts.prefix(2).map { "\($0.value)\(short[$0.label] ?? "")" }
        return top.isEmpty ? "0s" : top.joined(separator: " ")
    }

    private func accessibilityText(_ remaining: TimeInterval) -> String {
        remaining <= 0 ? "Time's up" : Self.segments(remaining, showsDays: showsDays).map { "\($0.value) \($0.label)" }.joined(separator: " ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CountdownTimer {
    /// standard / urgent colour treatment.
    func style(_ s: CountdownStyle) -> Self { copy { $0.style = s } }
    /// Layout: boxed / inline / text.
    func format(_ f: CountdownFormat) -> Self { copy { $0.format = f } }
    /// Size tier: small / medium / large.
    func size(_ s: CountdownSize) -> Self { copy { $0.size = s } }
    /// Shows a leading days box (default false — HH rolls days into hours).
    func showsDays(_ on: Bool) -> Self { copy { $0.showsDays = on } }
    /// Auto-escalates to the urgent palette once fewer than `seconds` remain,
    /// and pulses on the final 10 seconds (no-op under Reduce Motion).
    func urgentBelow(_ seconds: TimeInterval) -> Self { copy { $0.urgentThreshold = seconds } }
    /// Content shown once the deadline passes (defaults to "Time's up").
    func onExpired<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.expiredSlot = AnyView(content()) } }
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
        CountdownTimer(until: .now.addingTimeInterval(125)).format(.inline).urgentBelow(60).size(.large)
        CountdownTimer(until: .now.addingTimeInterval(3 * 86_400 + 3_720)).format(.text)
    }
    .padding()
}
