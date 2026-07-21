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
    // The `-openDemo <name>` deep-link target, pushed via a hidden programmatic
    // NavigationLink (iOS-15-compatible; ADR-0007 dropped NavigationStack(path:)).
    @State private var deepLink: String?

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
        NavigationView {
            List {
                ForEach(ComponentCategory.allCases) { category in
                    let entries = filtered(category)
                    if !entries.isEmpty {
                        Section("\(category.rawValue) · \(entries.count)") {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    demoPage(entry.name)
                                } label: {
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
            // Hidden programmatic push for the screenshot deep-link — rows above
            // push directly; this link exists solely so `-openDemo` works even
            // when the target row isn't materialized by the lazy List.
            .background(
                NavigationLink(isActive: deepLinkActive) {
                    if let name = deepLink { demoPage(name) }
                } label: { EmptyView() }
                .hidden()
            )
            .searchable(text: $query, prompt: "Search components")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showTestList = true } label: {
                        Label("Test list", systemImage: "list.bullet.rectangle.portrait")
                    }
                    .accessibilityLabel("Test list")
                }
                ToolbarItem(placement: .navigationBarTrailing) { ThemeSwitcherMenu() }
            }
            .onAppear {
                // Deep-link for screenshots: launch with `-openDemo <name>`.
                if deepLink == nil, let demo = UserDefaults.standard.string(forKey: "openDemo"), !demo.isEmpty {
                    deepLink = demo
                }
            }
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $showTestList) {
            // The full-bleed component browser leans on iOS-17 API (see
            // Gallery/Showcase); below 17 the button shows a short notice instead.
            if #available(iOS 17.0, *) {
                ComponentListBrowser(theme: listTheme, preset: $listPreset, isDark: $listDark)
                    .theme(listTheme)
                    .environmentObject(themeStore)
                    .feedbackHost()
                    .sheetHost()
                    .drawerHost()
            } else {
                TestListUnavailableNote(dismiss: { showTestList = false })
            }
        }
    }

    /// The pushed demo page for a registry entry.
    @ViewBuilder private func demoPage(_ name: String) -> some View {
        if let entry = ComponentRegistry.all.first(where: { $0.name == name }) {
            ResettableDemo(usage: entry.usage) { entry.make() }
        }
    }

    private var deepLinkActive: Binding<Bool> {
        Binding(get: { deepLink != nil }, set: { if !$0 { deepLink = nil } })
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { token += 1 } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset to defaults")
                }
            }
    }
}

/// Shown below iOS 17 in place of the full-bleed component browser.
private struct TestListUnavailableNote: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("Test list needs iOS 17").font(.headline)
            Text("The full-screen component browser uses iOS 17 APIs. Browse every component from the catalog list instead.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close", action: dismiss)
        }
        .padding()
    }
}

#Preview {
    CatalogView()
        .environment(\.theme, Theme.shared)
        .environmentObject(DemoThemeStore())
}
