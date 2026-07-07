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
    @State private var query = ""
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(ComponentCategory.allCases) { category in
                    let entries = filtered(category)
                    if !entries.isEmpty {
                        Section("\(category.rawValue) · \(entries.count)") {
                            ForEach(entries) { entry in
                                NavigationLink(value: entry.name) { Text(entry.name) }
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeSwitcherMenu() } }
            .onAppear {
                // Deep-link for screenshots: launch with `-openDemo <name>`.
                if path.isEmpty, let demo = UserDefaults.standard.string(forKey: "openDemo"), !demo.isEmpty {
                    path = [demo]
                }
            }
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
