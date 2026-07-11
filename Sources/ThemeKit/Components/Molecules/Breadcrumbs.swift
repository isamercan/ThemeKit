//
//  Breadcrumbs.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Horizontal navigation path with chevron separators; the last crumb
/// is the current page. (daisyUI "Breadcrumbs" / Ant Design "Breadcrumb".)
/// When `maxItems` is set and exceeded, the middle crumbs collapse into a "…"
/// menu that still navigates to any hidden crumb.
public struct Breadcrumbs: View {
    @Environment(\.theme) private var theme

    public struct Crumb: Identifiable {
        public let id = UUID()
        let title: String
        let action: (() -> Void)?
        public init(_ title: String, action: (() -> Void)? = nil) { self.title = title; self.action = action }
    }

    /// A rendered position: a real crumb, or an ellipsis standing in for hidden ones.
    enum Entry: Equatable {
        case crumb(Int)
        case ellipsis([Int])
    }

    private let crumbs: [Crumb]
    private let maxItems: Int?

    // Appearance — mutated only through the modifiers below (R2).
    private var separatorSystemImage = "chevron.right"
    private var accent: SemanticColor?

    public init(_ crumbs: [Crumb], maxItems: Int? = nil) {
        self.crumbs = crumbs
        self.maxItems = maxItems
    }

    private var entries: [Entry] { Self.collapse(count: crumbs.count, maxItems: maxItems) }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(Array(entries.enumerated()), id: \.offset) { position, entry in
                    entryView(entry)
                    if position < entries.count - 1 { separator }
                }
            }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: Entry) -> some View {
        switch entry {
        case .crumb(let index):
            let isLast = index == crumbs.count - 1
            Button { crumbs[index].action?() } label: {
                Text(crumbs[index].title)
                    .textStyle(isLast ? .labelSm700 : .labelSm600)
                    .foregroundStyle(isLast ? currentColor : theme.text(.textHero))
            }
            .buttonStyle(.plain)
            .disabled(isLast || crumbs[index].action == nil)

        case .ellipsis(let hidden):
            Menu {
                ForEach(hidden, id: \.self) { index in
                    Button(crumbs[index].title) { crumbs[index].action?() }
                }
            } label: {
                Text("…")
                    .textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textHero))
                    .frame(minWidth: 20)
            }
            .accessibilityLabel(String(themeKit: "Show hidden breadcrumbs"))
        }
    }

    /// The current (last) crumb's tint — the accent token when set, else the
    /// primary text token.
    private var currentColor: Color {
        accent.map { $0.accent } ?? theme.text(.textPrimary)
    }

    private var separator: some View {
        Image(systemName: separatorSystemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.text(.textTertiary))
            .mirrorsInRTL()
    }

    // MARK: - Pure collapse (extracted for testing)

    /// Builds the rendered entries. With no `maxItems` (or when it isn't exceeded),
    /// every crumb shows. Otherwise the first crumb and the last `maxItems - 2`
    /// crumbs stay, and the middle collapses into one `.ellipsis` carrying the
    /// hidden indices.
    static func collapse(count: Int, maxItems: Int?) -> [Entry] {
        guard let maxItems, maxItems >= 1, count > maxItems else {
            return (0..<count).map { .crumb($0) }
        }
        let head = 1
        let tail = max(1, maxItems - head - 1)
        guard head + tail < count else { return (0..<count).map { .crumb($0) } }

        let hidden = Array(head..<(count - tail))
        var result: [Entry] = (0..<head).map { .crumb($0) }
        result.append(.ellipsis(hidden))
        result.append(contentsOf: ((count - tail)..<count).map { .crumb($0) })
        return result
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Breadcrumbs {
    /// SF Symbol drawn between crumbs (default `chevron.right`; mirrors in RTL).
    func separator(_ systemName: String) -> Self { copy { $0.separatorSystemImage = systemName } }
    /// Token-fed tint for the current (last) crumb; `nil` keeps the primary text token.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Breadcrumbs") {
        PreviewCase("Default") {
            Breadcrumbs([.init("Home", action: {}), .init("Hotels", action: {}), .init("Istanbul", action: {}), .init("Grand Hotel")])
        }
        PreviewCase("Collapsed (maxItems 4)") {
            Breadcrumbs([
                .init("Home", action: {}), .init("Hotels", action: {}), .init("Turkey", action: {}),
                .init("Marmara", action: {}), .init("Istanbul", action: {}), .init("Grand Hotel"),
            ], maxItems: 4)
        }
        PreviewCase("Custom separator + accent") {
            Breadcrumbs([.init("Home", action: {}), .init("Flights", action: {}), .init("IST → LHR")])
                .separator("arrow.right")
                .accent(.turquoise)
        }
    }
}
