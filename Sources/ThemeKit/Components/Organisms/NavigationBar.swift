//
//  NavigationBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Floating bottom tab bar. Active item uses a filled glyph + hero
//  underline. Selection owned by the caller.
//

import SwiftUI

public struct NavigationBar: View {
    public struct Item: Identifiable {
        public let id = UUID()
        let systemImage: String
        let activeSystemImage: String?
        public init(systemImage: String, activeSystemImage: String? = nil) {
            self.systemImage = systemImage
            self.activeSystemImage = activeSystemImage
        }
    }

    private let items: [Item]
    @Binding private var selection: Int

    public init(items: [Item], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isActive = index == selection
                Button {
                    withAnimation(Motion.fast.animation) { selection = index }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: isActive ? (item.activeSystemImage ?? item.systemImage + ".fill") : item.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(isActive ? Theme.shared.foreground(.fgHero) : Theme.shared.text(.textTertiary))
                        Capsule()
                            .fill(isActive ? Theme.shared.background(.bgHero) : .clear)
                            .frame(width: 20, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(Theme.shared.background(.bgWhite), in: Capsule())
        .themeShadow(.tabBar)
    }
}

#Preview {
    struct Demo: View {
        @State var sel = 1
        var body: some View {
            NavigationBar(items: [
                .init(systemImage: "house"),
                .init(systemImage: "heart"),
                .init(systemImage: "bag"),
                .init(systemImage: "person"),
            ], selection: $sel)
            .padding()
        }
    }
    return Demo()
}
