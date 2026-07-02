//
//  Carousel.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A generic paging carousel with dot indicators, optional autoplay and optional
/// prev/next arrows. Supports seamless infinite looping (clone-edge technique), a
/// two-way `currentIndex` binding, and an active-gating content variant so video
/// pages can play only while visible. (Ant Carousel parity.)
public struct Carousel<Item: Identifiable, Content: View>: View {
    @Environment(\.theme) private var theme

    private let items: [Item]
    private let loop: Bool
    private let externalIndex: Binding<Int>?
    /// (item, isActive) — `isActive` is true only for the currently visible page.
    private let content: (Item, Bool) -> Content
    // Presentation config — set via chainable modifiers.
    private var autoplay: TimeInterval? = nil
    private var showsArrows: Bool = false
    private var showsDots: Bool = true
    private var fade: Bool = false
    private var dotPosition: Edge = .bottom

    @State private var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ items: [Item],
        loop: Bool = false,
        currentIndex: Binding<Int>? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.loop = loop
        self.externalIndex = currentIndex
        self.content = { item, _ in content(item) }
        _selection = State(initialValue: (loop && items.count > 1) ? 1 : (currentIndex?.wrappedValue ?? 0))
    }

    /// Active-gating variant: the content closure also receives whether the page
    /// is currently visible — use it to play only the on-screen video.
    public init(
        _ items: [Item],
        loop: Bool = false,
        currentIndex: Binding<Int>? = nil,
        @ViewBuilder activeContent: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        self.loop = loop
        self.externalIndex = currentIndex
        self.content = activeContent
        _selection = State(initialValue: (loop && items.count > 1) ? 1 : (currentIndex?.wrappedValue ?? 0))
    }

    private var count: Int { items.count }
    private var looping: Bool { loop && count > 1 }

    /// Raw TabView index → real item index. In loop mode raw 0 is a clone of the
    /// last item and raw `count+1` a clone of the first; any out-of-range raw is
    /// folded back with modulo so a fast double-tap can never index out of bounds.
    private func realIndex(_ raw: Int) -> Int {
        guard looping else { return min(max(raw, 0), count - 1) }
        return ((raw - 1) % count + count) % count
    }

    private var currentPage: Int { realIndex(selection) }

    private var pages: [(raw: Int, item: Item)] {
        guard looping else { return items.enumerated().map { (raw: $0.offset, item: $0.element) } }
        var result: [(raw: Int, item: Item)] = [(0, items[count - 1])]
        result += items.enumerated().map { (raw: $0.offset + 1, item: $0.element) }
        result.append((count + 1, items[0]))
        return result
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            if dotPosition == .top, showsDots, count > 1 {
                StepIndicator(current: currentPage, total: count)
            }

            ZStack {
                if fade {
                    fadeStage
                } else {
                    TabView(selection: $selection) {
                        ForEach(pages, id: \.raw) { page in
                            content(page.item, page.raw == selection).tag(page.raw)
                        }
                    }
                    .pagedStyle()
                }

                if showsArrows && count > 1 {
                    HStack {
                        arrow("chevron.left") { advance(-1) }
                        Spacer()
                        arrow("chevron.right") { advance(1) }
                    }
                    .padding(.horizontal, Theme.SpacingKey.sm.value)
                }
            }

            if dotPosition == .bottom, showsDots, count > 1 {
                StepIndicator(current: currentPage, total: count)
            }
        }
        .onChange(of: selection) { _, newValue in
            externalIndex?.wrappedValue = realIndex(newValue)
            guard looping else { return }
            if newValue == 0 { jump(to: count) }
            else if newValue == count + 1 { jump(to: 1) }
        }
        .onChange(of: externalIndex?.wrappedValue ?? -1) { _, real in
            guard real >= 0, real != realIndex(selection) else { return }
            selection = looping ? real + 1 : real
        }
        .onReceive(Timer.publish(every: autoplay ?? 3, on: .main, in: .common).autoconnect()) { _ in
            // Honor Reduce Motion: never auto-advance; the user still pages manually.
            guard autoplay != nil, count > 1, !reduceMotion else { return }
            withAnimation(Motion.base.animation) {
                if looping { selection = min(count + 1, selection + 1) }
                else { selection = (selection + 1) % count }
            }
        }
    }

    /// Cross-fade stage (Ant `fade`): only the active page is shown, swapped with
    /// an opacity transition. Swipe still advances; drag-to-track is dropped.
    private var fadeStage: some View {
        ZStack {
            ForEach(pages, id: \.raw) { page in
                if page.raw == selection {
                    content(page.item, true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
        }
        .animation(Motion.base.animation, value: selection)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -40 { advance(1) }
                    else if value.translation.width > 40 { advance(-1) }
                }
        )
    }

    private func advance(_ delta: Int) {
        withAnimation(Motion.base.animation) {
            // Keep `selection` within [0, count+1] so it never lands beyond a clone.
            if looping { selection = max(0, min(count + 1, selection + delta)) }
            else { selection = (selection + delta + count) % count }
        }
    }

    /// Silently reset to the real twin after the paging animation settles, so the
    /// clone edge is never seen.
    private func jump(to raw: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { selection = raw }
        }
    }

    private func arrow(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName).size(.sm).color(theme.foreground(.fgSecondary))
                .frame(width: 32, height: 32)
                .mirrorsInRTL()
                .background(theme.background(.bgTertiary).opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

public extension Carousel {
    /// Advances pages automatically every `interval` seconds.
    func autoplay(_ interval: TimeInterval?) -> Self { var copy = self; copy.autoplay = interval; return copy }
    /// Shows prev / next arrow buttons.
    func arrows(_ on: Bool = true) -> Self { var copy = self; copy.showsArrows = on; return copy }
    /// Shows the page-dot indicators (default true) and where they sit.
    func dots(_ on: Bool = true, position: Edge = .bottom) -> Self {
        var copy = self; copy.showsDots = on; copy.dotPosition = position; return copy
    }
    /// Cross-fades between pages instead of sliding.
    func fade(_ on: Bool = true) -> Self { var copy = self; copy.fade = on; return copy }
}

private extension View {
    /// Page-style paging (iOS); falls back to the default style elsewhere.
    @ViewBuilder
    func pagedStyle() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self
        #endif
    }
}

#Preview {
    struct Slide: Identifiable { let id = UUID(); let color: Color; let title: String }
    let slides = [
        Slide(color: .blue, title: "One"),
        Slide(color: .teal, title: "Two"),
        Slide(color: .orange, title: "Three"),
    ]
    return Carousel(slides, loop: true) { slide in
        RoundedRectangle(cornerRadius: 16)
            .fill(slide.color.opacity(0.3))
            .overlay(Text(slide.title).font(.title))
            .padding(.horizontal)
    }
    .autoplay(2)
    .arrows()
    .frame(height: 200)
}
