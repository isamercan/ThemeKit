//
//  CardStack.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Layers items into a stacked "deck" with offset + scale.
/// (daisyUI "Stack".)
public struct CardStack<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let content: (Item) -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var maxVisible = 3
    private var peekKey: Theme.SpacingKey?
    private var rotationDegrees: Double = 0

    /// Per-depth scale/fade steps of the legacy deck (kept as constants so the
    /// default rendering stays pixel-identical).
    private static var scaleStep: CGFloat { 0.05 }
    private static var opacityStep: Double { 0.15 }
    /// Legacy fixed 10pt peek; used until a `peekOffset(_:)` token is applied
    /// (no spacing token resolves to 10 in the default theme).
    private var peekValue: CGFloat { peekKey?.value ?? 10 }

    public init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {   // R1
        self.items = items
        self.content = content
    }

    public var body: some View {
        ZStack {
            ForEach(Array(items.prefix(maxVisible).enumerated()), id: \.element.id) { index, item in
                content(item)
                    .scaleEffect(1 - CGFloat(index) * Self.scaleStep)
                    .rotationEffect(.degrees(rotationDegrees * Double(index) * (index.isMultiple(of: 2) ? 1 : -1)))
                    .offset(y: CGFloat(index) * peekValue)
                    .opacity(1 - Double(index) * Self.opacityStep)
                    .zIndex(Double(maxVisible - index))
            }
        }
        // Reserve the space the peeking cards hang into below the front card.
        .padding(.bottom, CGFloat(max(min(items.count, maxVisible) - 1, 0)) * peekValue)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CardStack {
    /// Maximum number of cards rendered in the deck (default 3).
    func maxVisible(_ count: Int) -> Self { copy { $0.maxVisible = max(count, 0) } }

    /// Vertical peek of each card behind the front one, token-fed
    /// (default: the legacy fixed 10pt offset).
    func peekOffset(_ spacing: Theme.SpacingKey) -> Self { copy { $0.peekKey = spacing } }

    /// Scatter angle in degrees applied per depth, alternating sides for a
    /// fanned-deck look (default 0 — a straight stack, today's rendering).
    func rotation(_ degrees: Double) -> Self { copy { $0.rotationDegrees = degrees } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Item: Identifiable { let id = UUID(); let color: Color; let title: String }
    let items = [Item(color: .blue, title: "Front"), Item(color: .teal, title: "Middle"), Item(color: .orange, title: "Back")]
    return CardStack(items) { item in
        RoundedRectangle(cornerRadius: 16)
            .fill(item.color.opacity(0.3))
            .frame(height: 120)
            .overlay(Text(item.title).font(.headline))
            .frame(maxWidth: .infinity)
    }
    .padding()
}

#Preview("Deck modifiers") {
    struct Item: Identifiable { let id = UUID(); let color: Color; let title: String }
    let items = [Item(color: .blue, title: "Front"), Item(color: .teal, title: "Middle"),
                 Item(color: .orange, title: "Back"), Item(color: .purple, title: "Hidden")]
    return VStack(spacing: 40) {
        CardStack(items) { item in
            RoundedRectangle(cornerRadius: 16)
                .fill(item.color.opacity(0.3))
                .frame(height: 120)
                .overlay(Text(item.title).font(.headline))
                .frame(maxWidth: .infinity)
        }
        .maxVisible(4)
        .peekOffset(.md)

        CardStack(items) { item in
            RoundedRectangle(cornerRadius: 16)
                .fill(item.color.opacity(0.3))
                .frame(height: 120)
                .overlay(Text(item.title).font(.headline))
                .frame(maxWidth: .infinity)
        }
        .maxVisible(3)
        .rotation(3)
    }
    .padding()
}
