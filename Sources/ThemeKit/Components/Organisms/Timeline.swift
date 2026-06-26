//
//  Timeline.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Vertical timeline of events with a connecting rail, dot/icon
//  markers, done / active / todo / error states, optional per-item color and a
//  trailing "pending" (loading) node. `mode` places the content left, right or
//  alternating around the rail; `reverse` flips the order. (Ant Timeline parity.)
//

import SwiftUI

/// Where item content sits relative to the rail (vertical axis only). (Ant Timeline `mode`.)
public enum TimelineMode: Sendable {
    /// Content to the right of the rail (default).
    case left
    /// Content to the left of the rail.
    case right
    /// Content alternates side to side; the time moves to the opposite side.
    case alternate
}

public struct Timeline: View {
    public struct Item: Identifiable {
        public let id = UUID()
        let title: String
        let time: String?
        let description: String?
        let systemImage: String?
        let state: StepState
        let color: SemanticColor?
        public init(title: String, time: String? = nil, description: String? = nil, systemImage: String? = nil, state: StepState = .done, color: SemanticColor? = nil) {
            self.title = title; self.time = time; self.description = description; self.systemImage = systemImage; self.state = state; self.color = color
        }
    }

    private let items: [Item]
    private let pending: String?
    private let axis: Axis
    private let mode: TimelineMode
    private let reverse: Bool

    public init(_ items: [Item], axis: Axis = .vertical, mode: TimelineMode = .left, reverse: Bool = false, pending: String? = nil) {
        self.items = items
        self.axis = axis
        self.mode = mode
        self.reverse = reverse
        self.pending = pending
    }

    private enum DisplayRow {
        case item(Item)
        case pending(String)
    }

    /// Items (+ optional pending node), in display order.
    private var displayRows: [DisplayRow] {
        var rows: [DisplayRow] = items.map { .item($0) }
        if let pending { rows.append(.pending(pending)) }
        return reverse ? Array(rows.reversed()) : rows
    }

    public var body: some View {
        if axis == .horizontal { horizontalBody } else { verticalBody }
    }

    private var horizontalBody: some View {
        let ordered = reverse ? Array(items.reversed()) : items
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: Theme.SpacingKey.xs.value) {
                    ZStack {
                        if index < ordered.count - 1 {
                            Rectangle().fill(railColor(item)).frame(height: 2).offset(x: 14)
                        }
                        marker(item)
                    }
                    if let time = item.time {
                        Text(time).textStyle(.overline400).foregroundStyle(Theme.shared.text(.textTertiary))
                    }
                    Text(item.title).textStyle(.labelSm600)
                        .foregroundStyle(item.state == .todo ? Theme.shared.text(.textTertiary) : Theme.shared.text(.textPrimary))
                        .multilineTextAlignment(.center)
                    if let description = item.description {
                        Text(description).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var verticalBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(displayRows.enumerated()), id: \.offset) { position, row in
                let isLast = position == displayRows.count - 1
                switch row {
                case .item(let item):
                    verticalRow(position: position, isLast: isLast, marker: marker(item), rail: railColor(item),
                                main: { itemMain(item, showTime: mode != .alternate) },
                                opposite: { oppositeContent(item) })
                case .pending(let text):
                    verticalRow(position: position, isLast: isLast, marker: pendingMarker, rail: .clear,
                                main: { pendingMain(text) }, opposite: { EmptyView() })
                }
            }
        }
    }

    @ViewBuilder
    private func verticalRow<Marker: View, Main: View, Opposite: View>(
        position: Int, isLast: Bool, marker: Marker, rail: Color,
        @ViewBuilder main: () -> Main, @ViewBuilder opposite: () -> Opposite
    ) -> some View {
        switch mode {
        case .left:
            HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) {
                railColumn(marker: marker, rail: rail, isLast: isLast)
                VStack(alignment: .leading, spacing: 2) { main() }
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, isLast ? 0 : Theme.SpacingKey.md.value)
                Spacer(minLength: 0)
            }
        case .right:
            HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) {
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) { main() }
                    .multilineTextAlignment(.trailing)
                    .padding(.bottom, isLast ? 0 : Theme.SpacingKey.md.value)
                railColumn(marker: marker, rail: rail, isLast: isLast)
            }
        case .alternate:
            let mainTrailing = position.isMultiple(of: 2)
            HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) {
                VStack(alignment: .trailing, spacing: 2) { if mainTrailing { opposite() } else { main() } }
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, isLast ? 0 : Theme.SpacingKey.md.value)
                railColumn(marker: marker, rail: rail, isLast: isLast)
                VStack(alignment: .leading, spacing: 2) { if mainTrailing { main() } else { opposite() } }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, isLast ? 0 : Theme.SpacingKey.md.value)
            }
        }
    }

    private func railColumn(marker: some View, rail: Color, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            marker
            if !isLast {
                Rectangle().fill(rail).frame(width: 2).frame(maxHeight: .infinity)
            }
        }
        .frame(width: 28)
    }

    @ViewBuilder
    private func itemMain(_ item: Item, showTime: Bool) -> some View {
        if showTime, let time = item.time {
            Text(time).textStyle(.overline400).foregroundStyle(Theme.shared.text(.textTertiary))
        }
        Text(item.title).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
        if let description = item.description {
            Text(description).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
        }
    }

    @ViewBuilder
    private func oppositeContent(_ item: Item) -> some View {
        if let time = item.time {
            Text(time).textStyle(.overline400).foregroundStyle(Theme.shared.text(.textTertiary))
        }
    }

    private func pendingMain(_ text: String) -> some View {
        Text(text).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textTertiary))
    }

    private func railColor(_ item: Item) -> Color {
        item.state == .done ? (item.color?.solid ?? Theme.shared.background(.bgHero)) : Theme.shared.border(.borderPrimary)
    }

    @ViewBuilder
    private func marker(_ item: Item) -> some View {
        let dotColor = item.state == .error
            ? Theme.shared.background(.systemcolorsBgError)
            : (item.color?.solid ?? Theme.shared.background(.bgHero))
        ZStack {
            Circle().fill(item.state == .todo ? Theme.shared.background(.bgWhite) : dotColor).frame(width: 28, height: 28)
            Circle().strokeBorder(item.state == .todo ? Theme.shared.border(.borderPrimary) : dotColor, lineWidth: 1.5).frame(width: 28, height: 28)
            if item.state == .error {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.shared.foreground(.fgSecondary))
            } else if let systemImage = item.systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.state == .todo ? Theme.shared.text(.textTertiary) : Theme.shared.foreground(.fgSecondary))
            } else if item.state == .done {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.shared.foreground(.fgSecondary))
            }
        }
    }

    private var pendingMarker: some View {
        ZStack {
            Circle().fill(Theme.shared.background(.bgWhite)).frame(width: 28, height: 28)
            Circle().strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1.5).frame(width: 28, height: 28)
            ProgressView().controlSize(.mini).tint(Theme.shared.foreground(.fgHero))
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            Timeline([
                .init(title: "Order placed", time: "09:24", description: "We received your order.", systemImage: "cart", state: .done),
                .init(title: "Payment failed", time: "09:30", description: "Retry your card.", state: .error),
                .init(title: "Preparing", time: "09:40", systemImage: "shippingbox", state: .done, color: .success),
            ], pending: "Awaiting courier…")

            Timeline([
                .init(title: "Departure", time: "08:00", description: "İstanbul (IST)", systemImage: "airplane.departure", state: .done),
                .init(title: "Layover", time: "12:30", description: "Munich (MUC)", systemImage: "clock", state: .active),
                .init(title: "Arrival", time: "16:45", description: "Barcelona (BCN)", systemImage: "airplane.arrival", state: .todo),
            ], mode: .alternate)
        }
        .padding()
    }
}
