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
    private let maxVisible = 3

    public init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    public var body: some View {
        ZStack {
            ForEach(Array(items.prefix(maxVisible).enumerated()), id: \.element.id) { index, item in
                content(item)
                    .scaleEffect(1 - CGFloat(index) * 0.05)
                    .offset(y: CGFloat(index) * 10)
                    .opacity(1 - Double(index) * 0.15)
                    .zIndex(Double(maxVisible - index))
            }
        }
        .padding(.bottom, CGFloat(min(items.count, maxVisible) - 1) * 10)
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
