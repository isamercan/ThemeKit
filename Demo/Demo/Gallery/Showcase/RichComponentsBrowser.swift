//
//  RichComponentsBrowser.swift
//  Demo
//  Created by İsa Mercan.
//
//  The "Rich components" shelf — every entry in the ComponentRegistry rendered
//  live in ONE horizontal row of large cards (each ~half the screen tall), like
//  Ant Design's "Rich components" section. Swipe the row to browse all 198
//  components & organisms; tap a card to open its full interactive demo.
//  Auto theme-cycle is off by default (tap a swatch / play to change the theme).
//

import SwiftUI
import Combine
import UIKit
import ThemeKit

struct RichComponentsBrowser: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeStore: DemoThemeStore

    @State private var selected: ComponentEntry?
    @State private var autoCycle = false
    private let ticker = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    private enum ShelfItem: Identifiable {
        case marker(ComponentCategory, Int)
        case component(ComponentEntry)
        var id: String {
            switch self {
            case let .marker(category, _): return "marker-\(category.rawValue)"
            case let .component(entry): return "comp-\(entry.id)"
            }
        }
    }

    // All components in one ordered row, with a slim marker before each category.
    private var shelfItems: [ShelfItem] {
        var items: [ShelfItem] = []
        for category in ComponentCategory.allCases {
            let entries = ComponentRegistry.entries(in: category)
            items.append(.marker(category, entries.count))
            items.append(contentsOf: entries.map { .component($0) })
        }
        return items
    }

    var body: some View {
        GeometryReader { geo in
            let cardH = geo.size.height * 0.5
            let cardW = min(max(geo.size.width * 0.32, 360), 480)

            ZStack(alignment: .top) {
                Theme.shared.background(.bgBase).ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    titleBlock
                    Spacer().frame(height: 28)
                    shelf(cardW: cardW, cardH: cardH)
                    Spacer(minLength: 0)
                }
            }
        }
        .environment(\.locale, Locale(identifier: "en_US"))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onReceive(ticker) { _ in if autoCycle { advanceTheme() } }
        .sheet(item: $selected) { entry in
            NavigationStack {
                entry.make()
                    .environment(\.componentUsage, entry.usage)
                    .navigationTitle(entry.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selected = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Header (theme row + close)

    private var header: some View {
        HStack(spacing: 16) {
            Spacer()
            ThemePresetRow(autoCycle: $autoCycle)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.shared.background(.bgWhite), in: Capsule())
                .overlay(Capsule().stroke(Theme.shared.border(.borderPrimary), lineWidth: 0.5))
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("Rich components")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("\(ComponentRegistry.all.count) live components & organisms — practical, flexible, and yours to theme.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - The single horizontal row

    private func shelf(cardW: CGFloat, cardH: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 18) {
                ForEach(shelfItems) { item in
                    switch item {
                    case let .marker(category, count):
                        CategoryMarker(category: category, count: count, height: cardH)
                    case let .component(entry):
                        ShelfCard(entry: entry, width: cardW, height: cardH) { selected = entry }
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: cardH)
    }

    // MARK: - Auto theme-cycle (off unless the user turns it on)

    private func advanceTheme() {
        let cases = DemoTheme.allCases
        guard let idx = cases.firstIndex(of: themeStore.current) else { return }
        let next = (idx + 1) % cases.count
        themeStore.select(cases[next])
        if next == 0 { themeStore.setDark(!themeStore.isDark) }
    }
}

// MARK: - One big shelf card: clean live preview on top, info + code below

private struct ShelfCard: View {
    let entry: ComponentEntry
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    // The demo's canvas (its live preview) sits in the top ~220pt of
    // `entry.make()`; rendering it at the card's real width keeps every
    // component fully inside the card (no cropping / overflow), while the theme
    // bar / properties below stay clipped off.
    private let previewHeight: CGFloat = 224
    private var accent: Color { Theme.shared.foreground(.systemcolorsFgInfo) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                entry.make()
                    .frame(width: width, height: previewHeight, alignment: .top)
                    .clipped()
                    .allowsHitTesting(false)

                infoFooter
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Theme.shared.background(.bgWhite))
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.shared.border(.borderPrimary), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var infoFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.category.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(entry.name)
                .font(.title3.weight(.bold))
                .lineLimit(1)

            if let usage = entry.usage, !usage.isEmpty {
                Text(usage)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Text("Open in playground")
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
        }
        .padding(16)
    }
}

// MARK: - Slim in-row category marker

private struct CategoryMarker: View {
    let category: ComponentCategory
    let count: Int
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            Text("\(count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.shared.foreground(.systemcolorsFgInfo))
            Text(category.rawValue.uppercased())
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(width: 130, height: height, alignment: .leading)
        .padding(.horizontal, 16)
    }
}
