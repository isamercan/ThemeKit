//
//  CatalogView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Registry-driven catalog: lists every component grouped by category and
//  navigates to its dedicated demo page. Adding a component is one registry
//  entry — this screen needs no changes.
//

import SwiftUI
import ThemeKit

struct CatalogView: View {
    @EnvironmentObject private var themeStore: DemoThemeStore
    @State private var query = ""
    @State private var path: [String] = []

    // The "Test list" (ComponentListBrowser) presented full-screen from here so
    // iPhone gets the same top-to-bottom, live-preview component browser the iPad
    // Showcase has. It runs on its OWN isolated theme (like the Showcase), so
    // cycling themes inside it never disturbs the rest of the app.
    @State private var showTestList = UserDefaults.standard.bool(forKey: "openList")
    @State private var listTheme: Theme = {
        let t = Theme(); t.loadTheme(named: DemoTheme.default.resourceName, dark: false); return t
    }()
    @State private var listPreset: DemoTheme = .default
    @State private var listDark = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(ComponentCategory.allCases) { category in
                    let entries = filtered(category)
                    if !entries.isEmpty {
                        Section("\(category.rawValue) · \(entries.count)") {
                            ForEach(entries) { entry in
                                NavigationLink(value: entry.name) {
                                    HStack(spacing: 8) {
                                        Text(entry.name)
                                        if entry.isNew {
                                            Badge("New").badgeStyle(.success).size(.small)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Components")
            .navigationDestination(for: String.self) { name in
                if let entry = ComponentRegistry.all.first(where: { $0.name == name }) {
                    ResettableDemo(usage: entry.usage) { entry.make() }
                }
            }
            .searchable(text: $query, prompt: "Search components")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showTestList = true } label: {
                        Label("Test list", systemImage: "list.bullet.rectangle.portrait")
                    }
                    .accessibilityLabel("Test list")
                }
                ToolbarItem(placement: .topBarTrailing) { ThemeSwitcherMenu() }
            }
            .onAppear {
                // Deep-link for screenshots: launch with `-openDemo <name>`.
                if path.isEmpty, let demo = UserDefaults.standard.string(forKey: "openDemo"), !demo.isEmpty {
                    path = [demo]
                }
            }
        }
        .fullScreenCover(isPresented: $showTestList) {
            ComponentListBrowser(theme: listTheme, preset: $listPreset, isDark: $listDark)
                .theme(listTheme)
                .environmentObject(themeStore)
                .feedbackHost()
                .sheetHost()
                .drawerHost()
        }
    }

    private func filtered(_ category: ComponentCategory) -> [ComponentEntry] {
        ComponentRegistry.entries(in: category).filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}

/// Hosts a component's demo page and adds a "Reset to defaults" toolbar button.
/// Reset bumps an id token, which remounts the demo subtree — so every `@State`
/// knob returns to its initial value with no per-demo plumbing. The active brand
/// theme lives in `DemoThemeStore` (not in the subtree), so it is preserved.
private struct ResettableDemo<Content: View>: View {
    let usage: String?
    @ViewBuilder let content: () -> Content
    @State private var token = 0

    var body: some View {
        content()
            .id(token)
            .environment(\.componentUsage, usage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { token += 1 } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset to defaults")
                }
            }
    }
}

#Preview {
    CatalogView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
