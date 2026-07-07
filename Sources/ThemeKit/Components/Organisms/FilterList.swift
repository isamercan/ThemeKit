//
//  FilterList.swift
//  ThemeKit
//
//  Organism. A filter-panel section — an optional title over a stack of selectable
//  ``FilterRow``s (checkbox + name + result count), with optional separators, an
//  optional "select all" master and an optional bordered container. Selection is a
//  single `Set` binding owned by the caller. Token-bound and generic (hotels,
//  flights, anything). Compose several for a full filter sidebar.
//
//  ```swift
//  FilterList([FilterOption("Direct", count: 128), FilterOption("1 stop", count: 64)],
//             selection: $stops).title("Stops").bordered()
//  ```
//

import SwiftUI

/// One option in a ``FilterList`` — a title, an optional result count and an optional icon.
public struct FilterOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let count: Int?
    public let icon: String?
    public init(_ title: String, count: Int? = nil, icon: String? = nil, id: String? = nil) {
        self.title = title
        self.count = count
        self.icon = icon
        self.id = id ?? title
    }
}

public struct FilterList: View {
    @Environment(\.theme) private var theme

    private let options: [FilterOption]
    @Binding private var selection: Set<String>
    // Appearance/config — mutated only through the modifiers below (R2).
    private var title: String?
    private var bordered = false
    private var showsSeparators = true
    private var selectAllTitle: String?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase

    public init(_ options: [FilterOption], selection: Binding<Set<String>>) {   // R1
        self.options = options
        self._selection = selection
    }

    private func binding(for option: FilterOption) -> Binding<Bool> {
        Binding(
            get: { selection.contains(option.id) },
            set: { if $0 { selection.insert(option.id) } else { selection.remove(option.id) } }
        )
    }
    private var allSelected: Bool { !options.isEmpty && options.allSatisfy { selection.contains($0.id) } }
    private var someSelected: Bool { options.contains { selection.contains($0.id) } && !allSelected }
    private func toggleAll() {
        if allSelected { options.forEach { selection.remove($0.id) } }
        else { options.forEach { selection.insert($0.id) } }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous) }
    private var rowPadding: CGFloat { bordered ? Theme.SpacingKey.md.value : 0 }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
            }
            rows
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            if let selectAllTitle { selectAllRow(selectAllTitle) }
            ForEach(Array(options.enumerated()), id: \.element.id) { i, option in
                FilterRow(option.title, isOn: binding(for: option))
                    .count(option.count)
                    .icon(option.icon)
                    .showsSeparator(showsSeparators && i < options.count - 1)
                    .padding(.horizontal, rowPadding)
            }
        }
        .background(bordered ? theme.background(surfaceKey) : .clear, in: shape)
        .overlay { if bordered { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
    }

    private func selectAllRow(_ text: String) -> some View {
        Button(action: toggleAll) {
            VStack(spacing: 0) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Checkbox(isChecked: .constant(allSelected)).indeterminate(someSelected)
                    Text(text).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
                    Spacer()
                }
                .padding(.vertical, Theme.SpacingKey.sm.value)
                .frame(minHeight: 44)
                DividerView().size(.small)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, rowPadding)
        .accessibilityLabel(text)
        .accessibilityAddTraits(allSelected ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterList {
    /// A section title above the list.
    func title(_ text: String?) -> Self { copy { $0.title = text } }
    /// Wrap the rows in a bordered, rounded container (the "popular filters" card).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }
    /// Hairline separators between rows (default on).
    func showsSeparators(_ on: Bool = true) -> Self { copy { $0.showsSeparators = on } }
    /// Adds a "select all" master row with the given title (nil hides it).
    func selectAll(_ title: String?) -> Self { copy { $0.selectAllTitle = title } }
    /// Surface fill (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel: Set<String> = ["Direct"]
        var body: some View {
            FilterList([
                FilterOption("Direct", count: 128),
                FilterOption("1 stop", count: 64),
                FilterOption("2+ stops", count: 12),
            ], selection: $sel)
            .title("Stops").bordered().selectAll("All")
            .padding()
        }
    }
    return Demo()
}
