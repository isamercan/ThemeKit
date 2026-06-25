//
//  Gallery.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A grid of media items rendered at a fixed aspect ratio (uses the
//  AspectRatioToken + GridLayout tokens). Generic over the cell content.
//

import SwiftUI

public struct Gallery<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let columns: Int
    private let aspect: AspectRatioToken
    private let content: (Item) -> Content

    public init(
        _ items: [Item],
        columns: Int = 2,
        aspect: AspectRatioToken = .square,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.aspect = aspect
        self.content = content
    }

    public var body: some View {
        LazyVGrid(columns: GridLayout.columns(columns), spacing: GridLayout.gutter) {
            ForEach(items) { item in
                content(item)
                    .aspectRatioToken(aspect, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            }
        }
    }
}

#Preview {
    struct Photo: Identifiable { let id = UUID(); let color: Color }
    let photos = [Photo(color: .blue), Photo(color: .teal), Photo(color: .orange), Photo(color: .purple)]
    return Gallery(photos, columns: 2, aspect: .square) { photo in
        photo.color.opacity(0.3)
    }
    .padding()
}
