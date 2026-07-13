//
//  CommandPalette.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A ⌘K-style command palette: a scrim + centered card with a pinned search
//  field over sectioned, keyboard-navigable actions. (HeroUI Pro "Command".)
//  Composes the shipped SearchBar / Kbd / Backdrop / EmptyState. Controlled-only
//  — a palette is summoned by an app-level shortcut the app owns.
//

import SwiftUI

/// One runnable command. `keywords` widen the fuzzy match; `shortcut` renders as
/// `Kbd` chips (e.g. `["⌘", "K"]`).
public struct CommandItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let keywords: [String]
    public let shortcut: [String]
    public let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, keywords: [String] = [],
                shortcut: [String] = [], id: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.keywords = keywords
        self.shortcut = shortcut
        self.id = id ?? title
        self.action = action
    }
}

/// A titled group of commands.
public struct CommandSection: Identifiable {
    public let id: String
    public let heading: String?
    public let items: [CommandItem]

    public init(_ heading: String? = nil, items: [CommandItem]) {
        self.heading = heading
        self.items = items
        self.id = heading ?? items.first.map { "section-\($0.id)" } ?? "section-empty"
    }
}

/// Case- and diacritic-insensitive token filter: every whitespace-separated
/// query token must prefix-match some word of an item's title or keywords.
/// Pure and unit-tested; empty/whitespace query returns everything.
func commandFilter(_ sections: [CommandSection], query: String) -> [CommandSection] {
    let folded = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !folded.isEmpty else { return sections }
    let tokens = folded.split(separator: " ").map(String.init)

    func matches(_ item: CommandItem) -> Bool {
        let fields = ([item.title] + item.keywords).map {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        return tokens.allSatisfy { token in
            fields.contains { field in
                field.hasPrefix(token) || field.split(separator: " ").contains { $0.hasPrefix(token) }
            }
        }
    }

    return sections.compactMap { section in
        let hits = section.items.filter(matches)
        return hits.isEmpty ? nil : CommandSection(section.heading, items: hits)
    }
}

private struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let sections: [CommandSection]

    @Environment(\.theme) private var theme
    @State private var query = ""
    @State private var highlightedID: String?
    @FocusState private var searchFocused: Bool

    private var filtered: [CommandSection] { commandFilter(sections, query: query) }
    private var flatItems: [CommandItem] { filtered.flatMap(\.items) }

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(fade: 1)
                .ignoresSafeArea()
                .onTapGesture { close() }
            card
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.top, 72)
        }
        .onAppear {
            searchFocused = true
            highlightedID = flatItems.first?.id
        }
        .onChange(of: query) { highlightedID = flatItems.first?.id }
    }

    private var card: some View {
        VStack(spacing: 0) {
            SearchBar(text: $query)
                .focused($searchFocused)
                .padding(Theme.SpacingKey.sm.value)
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
            results
        }
        .frame(maxWidth: 560)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.elevated)
        // Hardware-keyboard navigation (macOS / iPad); taps work everywhere.
        .onKeyPress(.downArrow) { moveHighlight(1); return .handled }
        .onKeyPress(.upArrow) { moveHighlight(-1); return .handled }
        .onKeyPress(.return) { executeHighlighted(); return .handled }
        .onKeyPress(.escape) { close(); return .handled }
    }

    @ViewBuilder private var results: some View {
        if flatItems.isEmpty {
            EmptyState(String(themeKit: "No commands found"))
                .icon("magnifyingglass")
                .padding(Theme.SpacingKey.lg.value)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { section in
                        if let heading = section.heading {
                            Text(heading)
                                .textStyle(.overline500)
                                .foregroundStyle(theme.text(.textTertiary))
                                .padding(.horizontal, Theme.SpacingKey.md.value)
                                .padding(.top, Theme.SpacingKey.sm.value)
                                .padding(.bottom, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(section.items) { row($0) }
                    }
                }
                .padding(.vertical, Theme.SpacingKey.xs.value)
            }
            .frame(maxHeight: 360)
        }
    }

    private func row(_ item: CommandItem) -> some View {
        let isHighlighted = item.id == highlightedID
        return Button {
            execute(item)
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let systemImage = item.systemImage {
                    Icon(systemName: systemImage).size(.sm).color(theme.text(.textSecondary))
                }
                Text(item.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                Spacer(minLength: 8)
                HStack(spacing: 3) {
                    ForEach(item.shortcut, id: \.self) { Kbd($0) }
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? theme.resolve(.primary).soft : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    // MARK: - Actions

    private func execute(_ item: CommandItem) {
        close()
        item.action()
    }

    private func executeHighlighted() {
        guard let id = highlightedID, let item = flatItems.first(where: { $0.id == id }) else { return }
        execute(item)
    }

    private func moveHighlight(_ delta: Int) {
        let items = flatItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == highlightedID } ?? -1
        let next = min(max(current + delta, 0), items.count - 1)
        highlightedID = items[next].id
    }

    private func close() {
        isPresented = false
        query = ""
    }
}

private struct CommandPaletteHost: ViewModifier {
    @Binding var isPresented: Bool
    let sections: [CommandSection]

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                CommandPaletteView(isPresented: $isPresented, sections: sections)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: isPresented)
    }
}

public extension View {
    /// Present a ⌘K-style command palette over this view while `isPresented`.
    /// The app owns the shortcut that flips the binding; the palette handles
    /// search, keyboard navigation and dismissal.
    ///
    ///     RootView().commandPalette(isPresented: $showPalette, sections: [
    ///         CommandSection("Actions", items: [
    ///             CommandItem("New booking", systemImage: "plus", shortcut: ["⌘", "N"]) { … },
    ///         ]),
    ///     ])
    func commandPalette(isPresented: Binding<Bool>, sections: [CommandSection]) -> some View {
        modifier(CommandPaletteHost(isPresented: isPresented, sections: sections))
    }
}

#Preview {
    let sections = [
        CommandSection("Actions", items: [
            CommandItem("New booking", systemImage: "plus.circle", keywords: ["create", "add"], shortcut: ["⌘", "N"]) {},
            CommandItem("Search flights", systemImage: "airplane", keywords: ["find"], shortcut: ["⌘", "F"]) {},
        ]),
        CommandSection("Navigation", items: [
            CommandItem("Go to trips", systemImage: "suitcase", keywords: ["bookings"]) {},
            CommandItem("Settings", systemImage: "gearshape", shortcut: ["⌘", ","]) {},
        ]),
    ]
    // Overlay organism — the palette is a plain overlay (not a modal), so it
    // renders inline per column when pinned open with `.constant(true)` inside
    // a tall fixed-height cell.
    return PreviewMatrix("CommandPalette") {
        PreviewCase("Open") {
            Color.gray.opacity(0.1)
                .frame(height: 480)
                .commandPalette(isPresented: .constant(true), sections: sections)
        }
    }
}
