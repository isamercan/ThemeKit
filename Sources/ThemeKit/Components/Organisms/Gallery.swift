//
//  Gallery.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A grid of media items rendered at a fixed aspect ratio (uses the
/// AspectRatioToken + GridLayout tokens). Generic over the cell content.
public struct Gallery<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let content: (Item) -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var columns: Int = 2
    private var aspect: AspectRatioToken = .square
    private var emptySlot: AnyView?

    public init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {   // R1
        self.items = items
        self.content = content
    }

    public var body: some View {
        if items.isEmpty, let emptySlot {
            emptySlot
        } else {
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
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Gallery {
    /// Number of grid columns (default 2).
    func columns(_ count: Int) -> Self { copy { $0.columns = count } }

    /// Fixed aspect ratio applied to every cell (default `.square`).
    func aspect(_ ratio: AspectRatioToken) -> Self { copy { $0.aspect = ratio } }

    /// Custom view shown in place of the grid when `items` is empty
    /// (default: an empty grid, i.e. nothing).
    func empty<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.emptySlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Photo: Identifiable { let id = UUID(); let color: Color }
    let photos = [Photo(color: .blue), Photo(color: .teal), Photo(color: .orange), Photo(color: .purple)]
    return VStack(spacing: 24) {
        Gallery(photos) { photo in
            photo.color.opacity(0.3)
        }
        .columns(2)
        .aspect(.square)

        Gallery([Photo]()) { photo in
            photo.color.opacity(0.3)
        }
        .empty {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No photos yet")
                    .textStyle(.bodySm400)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.SpacingKey.lg.value)
        }
    }
    .padding()
}
