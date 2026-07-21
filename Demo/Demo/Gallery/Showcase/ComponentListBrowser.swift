//
//  ComponentListBrowser.swift
//  Demo
//  Created by İsa Mercan.
//
//  The vertical sibling of RichComponentsBrowser — a single top-to-bottom scroll
//  of EVERY component in the ComponentRegistry, in catalog order (Atoms →
//  Molecules → Organisms). Each entry is one simple block: the component name on
//  top, a live preview of the component under it, then an "Open playground" button
//  that opens the component's full interactive demo (canvas + knobs). A sticky
//  search box at the very top filters the whole list live, so the maintainer can
//  scroll and test every component in sequence on iPad. Shares the Showcase's
//  isolated theme — never Theme.shared.
//

import SwiftUI
import Combine
import ThemeKit

@available(iOS 17.0, *)
struct ComponentListBrowser: View {
    @Environment(\.dismiss) private var dismiss

    // Shares the Showcase's isolated theme — the same instance, never Theme.shared.
    let theme: Theme
    @Binding var preset: DemoTheme
    @Binding var isDark: Bool

    @State private var selected: ComponentEntry?
    // Deep-links for screenshots: launch with `-listQuery <text>` to pre-filter,
    // and `-openPlaygroundFor <name>` to open a component's playground directly.
    @State private var query = UserDefaults.standard.string(forKey: "listQuery") ?? ""
    @State private var autoCycle = false
    @State private var didDeepLink = false
    private let ticker = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    /// The live preview height per row — sized to show a demo's canvas while
    /// staying above the demo's theme bar (which sits ~216pt down), so the preview
    /// reads as the component alone. Taller components fade out at the bottom.
    private let previewHeight: CGFloat = 210
    /// Reading-width column, centered on the wide iPad canvas.
    private let columnWidth: CGFloat = 820

    private var accent: Color { theme.foreground(.systemcolorsFgInfo) }

    /// Trimmed, lowercased search needle (empty matches everything).
    private var needle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Registry entries in a category, alphabetized, filtered by the live query.
    private func filtered(_ category: ComponentCategory) -> [ComponentEntry] {
        ComponentRegistry.entries(in: category).filter { matches($0, needle) }
    }

    /// A component matches when its name, category, or usage snippet contains the
    /// search text (case-insensitive). An empty query matches everything.
    private func matches(_ entry: ComponentEntry, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return entry.name.lowercased().contains(needle)
            || entry.category.rawValue.lowercased().contains(needle)
            || (entry.usage?.lowercased().contains(needle) ?? false)
    }

    private var totalMatches: Int {
        ComponentCategory.allCases.reduce(0) { $0 + filtered($1).count }
    }

    private func applyTheme() { theme.loadTheme(named: preset.resourceName, dark: isDark) }

    var body: some View {
        ZStack(alignment: .top) {
            theme.background(.bgBase).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                titleBlock
                searchBar
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                Divider().opacity(0.4)
                list
            }
        }
        .environment(\.locale, Locale(identifier: "en_US"))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: preset) { _, _ in applyTheme() }
        .onChange(of: isDark) { _, _ in applyTheme() }
        .onReceive(ticker) { _ in if autoCycle { advanceTheme() } }
        .onAppear {
            guard !didDeepLink else { return }
            didDeepLink = true
            if let name = UserDefaults.standard.string(forKey: "openPlaygroundFor"), !name.isEmpty {
                // Defer so the sheet presents after this cover finishes appearing
                // (a sheet raised while the cover is still animating gets dropped).
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    selected = ComponentRegistry.all.first { $0.name.lowercased() == name.lowercased() }
                }
            }
        }
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
            .feedbackHost()
            .sheetHost()
            .drawerHost()
        }
    }

    // MARK: - Header (theme row + close)

    private var header: some View {
        HStack(spacing: 16) {
            Spacer()
            ThemePresetRow(theme: theme, preset: $preset, isDark: $isDark, autoCycle: $autoCycle)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(theme.background(.bgWhite), in: Capsule())
                .overlay(Capsule().stroke(theme.border(.borderPrimary), lineWidth: 0.5))
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
        VStack(spacing: 6) {
            Text("All components")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Every component in order — preview each, then tap Open playground to test & edit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    // MARK: - Sticky search

    private var searchBar: some View {
        SearchBar(text: $query)
            .placeholder("Search \(ComponentRegistry.all.count) components…")
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
    }

    // MARK: - The single vertical list

    @ViewBuilder
    private var list: some View {
        if totalMatches == 0 {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(ComponentCategory.allCases) { category in
                        let entries = filtered(category)
                        if !entries.isEmpty {
                            Section {
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                    ComponentRow(
                                        entry: entry,
                                        ordinal: index + 1,
                                        previewHeight: previewHeight,
                                        onOpen: { selected = entry }
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 18)

                                    if index < entries.count - 1 {
                                        Divider().opacity(0.35).padding(.horizontal, 24)
                                    }
                                }
                            } header: {
                                categoryHeader(category, count: entries.count)
                            }
                        }
                    }
                }
                .frame(maxWidth: columnWidth)
                .frame(maxWidth: .infinity)   // center the reading column
                .padding(.bottom, 48)
            }
        }
    }

    private func categoryHeader(_ category: ComponentCategory, count: Int) -> some View {
        HStack(spacing: 10) {
            Text(category.rawValue)
                .font(.title3.weight(.bold))
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(accent.opacity(0.14), in: Capsule())
            Spacer()
        }
        .frame(maxWidth: columnWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(theme.background(.bgBase))   // opaque so pinned header hides scrolled content
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No components match “\(query)”")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Auto theme-cycle (off unless the user turns it on)

    private func advanceTheme() {
        let cases = DemoTheme.allCases
        guard let idx = cases.firstIndex(of: preset) else { return }
        let next = (idx + 1) % cases.count
        preset = cases[next]                 // onChange(of:) applies it to the shared theme
        if next == 0 { isDark.toggle() }
    }
}

// MARK: - One component block: name → live preview → playground button

@available(iOS 17.0, *)
private struct ComponentRow: View {
    @Environment(\.theme) private var theme
    let entry: ComponentEntry
    let ordinal: Int
    let previewHeight: CGFloat
    let onOpen: () -> Void

    private var accent: Color { theme.foreground(.systemcolorsFgInfo) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            nameRow
            preview
            playgroundButton
        }
    }

    // 1 · Component name (with its ordinal + category + New badge)
    private var nameRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(ordinal).")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
            Text(entry.name)
                .font(.title3.weight(.bold))
                .lineLimit(1)
            if entry.isNew {
                Badge("New").badgeStyle(.success).size(.small)
            }
            Spacer(minLength: 0)
            Text(entry.category.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
        }
    }

    // 2 · Live preview of the component (its demo's canvas, clipped, non-interactive)
    private var preview: some View {
        entry.make()
            .frame(maxWidth: .infinity)
            .frame(height: previewHeight, alignment: .top)
            .clipped()
            .allowsHitTesting(false)   // clean static preview; testing happens in the playground
            .overlay(alignment: .bottom) {
                // Fade the bottom edge into the card so a clipped-tall component (or a
                // peeking theme bar) reads as "there's more — open the playground".
                LinearGradient(
                    colors: [theme.background(.bgWhite).opacity(0), theme.background(.bgWhite)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 46)
                .allowsHitTesting(false)
            }
            .background(theme.background(.bgWhite))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border(.borderPrimary), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture(perform: onOpen)   // tapping the preview also opens the playground
    }

    // 3 · Open the full interactive demo (canvas + knobs)
    private var playgroundButton: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text("Open playground")
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(entry.name) playground")
    }
}
