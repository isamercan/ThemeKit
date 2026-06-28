//
//  PagingCarousel.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Custom drag-paging carousel with PEEKING neighbors + threshold snap (the
/// reference `PagingScrollView`). Distinct from `Carousel` (full-width TabView):
/// here the active tile is narrower so the previous/next peek at the edges.
/// Optional autoplay wraps around.
public struct PagingCarousel<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let peek: CGFloat
    private let spacing: CGFloat
    private let autoplay: TimeInterval?
    private let content: (Item) -> Content

    @State private var index = 0
    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ items: [Item],
        peek: CGFloat = 32,
        spacing: CGFloat = 12,
        autoplay: TimeInterval? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.peek = peek
        self.spacing = spacing
        self.autoplay = autoplay
        self.content = content
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            GeometryReader { geo in
                let tileWidth = max(geo.size.width - 2 * peek, 1)
                let step = tileWidth + spacing
                HStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                        content(item)
                            .frame(width: tileWidth)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                    }
                }
                .offset(x: peek - CGFloat(index) * step + drag)
                .gesture(
                    DragGesture()
                        .onChanged { drag = $0.translation.width }
                        .onEnded { value in
                            let threshold = tileWidth * 0.25
                            var newIndex = index
                            if value.translation.width < -threshold { newIndex += 1 }
                            else if value.translation.width > threshold { newIndex -= 1 }
                            withAnimation(Motion.base.spring) {
                                index = min(max(newIndex, 0), items.count - 1)
                                drag = 0
                            }
                        }
                )
                .animation(Motion.base.animation, value: index)
            }
            .frame(height: 180)

            if items.count > 1 {
                StepIndicator(current: index, total: items.count)
            }
        }
        .onReceive(Timer.publish(every: autoplay ?? 3, on: .main, in: .common).autoconnect()) { _ in
            // Honor Reduce Motion: never auto-advance; the user still swipes manually.
            guard autoplay != nil, items.count > 1, !reduceMotion else { return }
            withAnimation(Motion.base.spring) { index = (index + 1) % items.count }
        }
    }
}

#Preview {
    struct Slide: Identifiable { let id = UUID(); let color: Color; let title: String }
    let slides = [Slide(color: .blue, title: "Bir"), Slide(color: .teal, title: "İki"),
                  Slide(color: .orange, title: "Üç"), Slide(color: .purple, title: "Dört")]
    return PagingCarousel(slides, peek: 36, autoplay: 2) { s in
        s.color.opacity(0.3).overlay(Text(s.title).font(.title))
    }
    .padding(.vertical)
}
