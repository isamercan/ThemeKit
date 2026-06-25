//
//  ContentView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import ThemeKit

struct ContentView: View {
    // Overridable at launch via `-startTab <index>` (used for screenshots).
    @State private var selection = UserDefaults.standard.integer(forKey: "startTab")
    @EnvironmentObject private var themeStore: DemoThemeStore

    var body: some View {
        TabView(selection: $selection) {
            CatalogView()
                .tabItem { Label("Components", systemImage: "square.grid.2x2") }
                .tag(0)

            ThemeGalleryView()
                .tabItem { Label("Colors", systemImage: "paintpalette") }
                .tag(1)

            TypographyView()
                .tabItem { Label("Type", systemImage: "textformat") }
                .tag(2)

            LayoutTokensView()
                .tabItem { Label("Layout", systemImage: "ruler") }
                .tag(3)

            HotelSearchView()
                .tabItem { Label("Example", systemImage: "sparkles") }
                .tag(4)
        }
        // A top "did fire" toast for every component callback (`flash("…")`).
        .modifier(ActionFlashOverlay())
        // Match system chrome (nav bars, grouped backgrounds) to the active theme.
        .preferredColorScheme(themeStore.isDark ? .dark : .light)
    }
}

/// Switches the active brand theme (Default / Ocean / Sunset) from a toolbar.
struct ThemeSwitcherMenu: View {
    @EnvironmentObject private var store: DemoThemeStore

    var body: some View {
        Menu {
            Picker("Theme", selection: Binding(get: { store.current }, set: { store.select($0) })) {
                ForEach(DemoTheme.allCases) { Text($0.label).tag($0) }
            }
            Divider()
            Toggle(isOn: Binding(get: { store.isDark }, set: { store.setDark($0) })) {
                Label("Dark Mode", systemImage: "moon.fill")
            }
        } label: {
            Label(store.current.label, systemImage: store.isDark ? "moon.fill" : "paintpalette")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Theme.shared)
        .environmentObject(DemoThemeStore())
}
