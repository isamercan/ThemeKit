//
//  SuggestionRow.swift
//  ThemeKit
//
//  Molecule. An autocomplete / search-suggestion result row — a leading icon tile,
//  a title with an optional code (ANK) and subtitle, an optional nested (child)
//  indent for sub-items (airports under a city), a selected state, query-match
//  highlighting and a trailing accessory. Token-bound; the workhorse of a location /
//  destination search sheet.
//
//  ```swift
//  SuggestionRow("Ankara, Turkey") { pick() }.icon("airplane").code("ANK").subtitle("Any")
//  SuggestionRow("Stansted") { pick() }.icon("airplane").code("ESB").subtitle("Ankara").nested()
//  ```
//

import SwiftUI

/// Trailing accessory of a ``SuggestionRow``.
public enum SuggestionAccessory: Sendable { case none, chevron, add }

public struct SuggestionRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let title: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var systemImage = "mappin"
    private var code: String?
    private var subtitle: String?
    private var nested = false
    private var isSelected = false
    private var highlightQuery: String?
    private var showsTile = true
    private var accessory: SuggestionAccessory = .none
    private var trailingSlot: AnyView?
    private var accent: SemanticColor?
    private var iconColorKey: Theme.TextColorKey?

    public init(_ title: String, action: @escaping () -> Void = {}) {   // R1
        self.title = title
        self.action = action
    }

    private var accentBase: Color { (accent ?? .primary).base }
    private var rowShape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }
    private var tileShape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous) }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                if nested {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text(.textPrimary)).frame(width: 24).mirrorsInRTL()
                }
                iconTile
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        titleView
                        if let code { Text(code).textStyle(.bodyBase400).foregroundStyle(theme.text(.textTertiary)) }
                    }
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 4)
                if let trailingSlot { trailingSlot } else { accessoryView }
            }
            .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? (accent ?? .primary).bg : .clear, in: rowShape)
            .contentShape(rowShape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, code, subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var iconTile: some View {
        if showsTile {
            IconTile(systemImage).iconSize(17).iconColor(iconColorKey ?? .textPrimary)
        } else {
            Image(systemName: systemImage).font(.system(size: 17))
                .foregroundStyle(iconColorKey.map { theme.text($0) } ?? theme.text(.textPrimary)).frame(width: 28)
        }
    }

    /// Title, semibold, with the matched query substring bolded when `.highlight(_)` is set.
    @ViewBuilder private var titleView: some View {
        if let q = highlightQuery, !q.isEmpty, let r = title.range(of: q, options: .caseInsensitive) {
            let pre = String(title[..<r.lowerBound])
            let mid = String(title[r])
            let post = String(title[r.upperBound...])
            (Text(pre) + Text(mid).foregroundColor(accentBase).bold() + Text(post))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.text(.textPrimary))
                .lineLimit(1)
        } else {
            Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
        }
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .none: EmptyView()
        case .chevron: Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
        case .add: Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(accentBase)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SuggestionRow {
    /// Leading SF Symbol (in the icon tile).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Icon colour (text token key).
    func iconColor(_ key: Theme.TextColorKey) -> Self { copy { $0.iconColorKey = key } }
    /// Show the rounded tile behind the icon (default on).
    func iconTile(_ on: Bool) -> Self { copy { $0.showsTile = on } }
    /// A trailing code next to the title, e.g. an airport code "ANK".
    func code(_ text: String?) -> Self { copy { $0.code = text } }
    /// The secondary line under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// Renders as a nested child (indent + ↳ arrow) — e.g. an airport under a city.
    func nested(_ on: Bool = true) -> Self { copy { $0.nested = on } }
    /// Selected/active state (accent-tinted background).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Bold + tint the substring of the title matching this query (autocomplete highlight).
    func highlight(_ query: String?) -> Self { copy { $0.highlightQuery = query } }
    /// Trailing accessory: none (default) / chevron / add.
    func accessory(_ a: SuggestionAccessory) -> Self { copy { $0.accessory = a } }
    /// A fully custom trailing accessory (distance, star…).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    /// Token-fed accent for the selected background / highlight (default primary).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 2) {
        SuggestionRow("Ankara, Turkey") { }.icon("airplane").code("ANK").subtitle("Any").selected().highlight("Ank")
        SuggestionRow("Stansted") { }.icon("airplane").code("ESB").subtitle("Ankara, Turkey").nested()
        SuggestionRow("Istanbul Airport") { }.icon("airplane").code("IST").subtitle("Istanbul, Turkey").nested().accessory(.chevron)
    }
    .padding()
}
