//
//  Timeline.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Vertical timeline of events with a connecting rail, dot/icon
//  markers, done / active / todo / error states, optional per-item color and a
//  trailing "pending" (loading) node. (Ant Timeline parity.)
//

import SwiftUI

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

    public init(_ items: [Item], axis: Axis = .vertical, pending: String? = nil) {
        self.items = items
        self.axis = axis
        self.pending = pending
    }

    private var hasPending: Bool { pending != nil }
    private var lastIndex: Int { items.count - 1 + (hasPending ? 1 : 0) }

    public var body: some View {
        if axis == .horizontal { horizontalBody } else { verticalBody }
    }

    private var horizontalBody: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: Theme.SpacingKey.xs.value) {
                    ZStack {
                        if index < items.count - 1 {
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
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(index: index, marker: marker(item), railOn: railColor(item)) {
                    if let time = item.time {
                        Text(time).textStyle(.overline400).foregroundStyle(Theme.shared.text(.textTertiary))
                    }
                    Text(item.title).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
                    if let description = item.description {
                        Text(description).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
            }
            if let pending {
                row(index: items.count, marker: pendingMarker, railOn: .clear) {
                    Text(pending).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textTertiary))
                }
            }
        }
    }

    @ViewBuilder
    private func row<Content: View>(index: Int, marker: some View, railOn: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) {
            VStack(spacing: 0) {
                marker
                if index < lastIndex {
                    Rectangle().fill(railOn).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 2, content: content)
                .padding(.bottom, index < lastIndex ? Theme.SpacingKey.md.value : 0)
            Spacer(minLength: 0)
        }
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
    Timeline([
        .init(title: "Order placed", time: "09:24", description: "We received your order.", systemImage: "cart", state: .done),
        .init(title: "Payment failed", time: "09:30", description: "Retry your card.", state: .error),
        .init(title: "Preparing", time: "09:40", systemImage: "shippingbox", state: .done, color: .success),
    ], pending: "Awaiting courier…")
    .padding()
}
