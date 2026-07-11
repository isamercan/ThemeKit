//
//  Transfer.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Transfer** — move items between a source list (left)
//  and a target list (right). Check items in either box, then use the middle
//  arrows to shift the checked ones across. `target` holds the keys on the right.
//
//      Transfer(features, target: $enabled).titles("Available", "Enabled")
//

import SwiftUI

/// One row in a ``Transfer``.
public struct TransferItem: Identifiable, Sendable {
    public let key: String
    public let title: String
    public init(_ key: String, title: String) {
        self.key = key
        self.title = title
    }
    public var id: String { key }
}

public struct Transfer: View {
    @Environment(\.theme) private var theme

    private let items: [TransferItem]
    @Binding private var target: Set<String>
    // Appearance — mutated only through the modifiers below.
    private var titles: (String, String) = (String(themeKit: "Source"), String(themeKit: "Target"))
    private var isSearchable = false
    /// Per-item enablement predicate (nil enables every item) — the
    /// kit-standard `optionEnabled` idiom (Ant Transfer per-item `disabled`).
    private var isItemEnabled: ((TransferItem) -> Bool)?

    @State private var checked: Set<String> = []
    @State private var sourceQuery = ""
    @State private var targetQuery = ""

    public init(_ items: [TransferItem], target: Binding<Set<String>>) {   // R1
        self.items = items
        self._target = target
    }

    private var source: [TransferItem] { items.filter { !target.contains($0.key) } }
    private var targeted: [TransferItem] { items.filter { target.contains($0.key) } }
    private var checkedInSource: Bool { source.contains { checked.contains($0.key) && itemEnabled($0) } }
    private var checkedInTarget: Bool { targeted.contains { checked.contains($0.key) && itemEnabled($0) } }

    private func itemEnabled(_ item: TransferItem) -> Bool { isItemEnabled?(item) ?? true }

    private func filtered(_ items: [TransferItem], query: String) -> [TransferItem] {
        guard isSearchable, !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            listBox(titles.0, items: source, query: $sourceQuery)
            VStack(spacing: Theme.SpacingKey.sm.value) {
                // `.forward`/`.backward` auto-mirror, so the arrows keep
                // pointing at the target/source box when the HStack flips
                // under RTL.
                arrow("chevron.forward", label: String(themeKit: "Move to \(titles.1)"), enabled: checkedInSource, action: moveToTarget)
                arrow("chevron.backward", label: String(themeKit: "Move to \(titles.0)"), enabled: checkedInTarget, action: moveToSource)
            }
            listBox(titles.1, items: targeted, query: $targetQuery)
        }
    }

    private func listBox(_ title: String, items: [TransferItem], query: Binding<String>) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                Text("\(items.count)").textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .frame(height: 36)
            .background(theme.background(.bgBase))

            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)

            // Per-list search (Ant Transfer `showSearch`) — the Select-panel idiom.
            if isSearchable {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Icon(systemName: "magnifyingglass").size(.xs).colorOverride(theme.text(.textTertiary))
                    TextField(String(themeKit: "Search"), text: query)
                        .textStyle(.bodySm400)
                        .tint(theme.foreground(.fgHero))
                }
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .scaledControlHeight(32)
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(filtered(items, query: query.wrappedValue)) { item in row(item) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    private func row(_ item: TransferItem) -> some View {
        let isOn = checked.contains(item.key)
        let enabled = itemEnabled(item)
        return Button {
            if isOn { checked.remove(item.key) } else { checked.insert(item.key) }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(!enabled ? theme.text(.textDisabled) : (isOn ? theme.text(.textHero) : theme.text(.textTertiary)))
                Text(item.title).textStyle(.bodySm400)
                    .foregroundStyle(enabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .frame(height: 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn && enabled ? SemanticColor.primary.soft.opacity(0.5) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func arrow(_ systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? SemanticColor.primary.onSolid : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
                .background(enabled ? SemanticColor.primary.solid : theme.background(.bgElevatorTertiary),
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func moveToTarget() {
        let moving = source.filter { checked.contains($0.key) && itemEnabled($0) }.map(\.key)
        target.formUnion(moving)
        checked.subtract(moving)
    }

    private func moveToSource() {
        let moving = targeted.filter { checked.contains($0.key) && itemEnabled($0) }.map(\.key)
        target.subtract(moving)
        checked.subtract(moving)
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Transfer {
    /// Header labels for the source and target boxes (Ant `titles`).
    func titles(_ source: String, _ target: String) -> Self { copy { $0.titles = (source, target) } }

    /// Show a search field in each list box, filtering its rows by title
    /// (Ant Transfer `showSearch`).
    func searchable(_ on: Bool = true) -> Self { copy { $0.isSearchable = on } }

    /// Per-item enablement predicate — disabled rows dim, can't be checked and
    /// never move (nil enables every item; the kit-standard `optionEnabled`
    /// idiom, Ant Transfer per-item `disabled`).
    func itemEnabled(_ predicate: ((TransferItem) -> Bool)?) -> Self { copy { $0.isItemEnabled = predicate } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var target: Set<String> = ["wifi"]
        let items = [TransferItem("wifi", title: "Wi-Fi"), TransferItem("bkfst", title: "Breakfast"),
                     TransferItem("pool", title: "Pool"), TransferItem("gym", title: "Gym"),
                     TransferItem("spa", title: "Spa"), TransferItem("park", title: "Parking")]
        var body: some View {
            Transfer(items, target: $target).titles("Available", "Included").padding()
        }
    }
    return Demo().environment(Theme.shared)
}

#Preview("RTL — boxes and arrows mirror") {
    struct Demo: View {
        @State private var target: Set<String> = ["wifi"]
        let items = [TransferItem("wifi", title: "Wi-Fi"), TransferItem("bkfst", title: "Breakfast"),
                     TransferItem("pool", title: "Pool"), TransferItem("gym", title: "Gym")]
        var body: some View {
            Transfer(items, target: $target).titles("Available", "Included").padding()
        }
    }
    return Demo()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(Theme.shared)
}

#Preview("Searchable + disabled items") {
    struct Demo: View {
        @State private var target: Set<String> = ["wifi"]
        let items = [TransferItem("wifi", title: "Wi-Fi"), TransferItem("bkfst", title: "Breakfast"),
                     TransferItem("pool", title: "Pool"), TransferItem("gym", title: "Gym"),
                     TransferItem("spa", title: "Spa"), TransferItem("park", title: "Parking")]
        var body: some View {
            Transfer(items, target: $target)
                .titles("Available", "Included")
                .searchable()                              // E8 — per-list search
                .itemEnabled { $0.key != "spa" }           // E8 — disabled rows never move
                .padding()
        }
    }
    return Demo().environment(Theme.shared)
}
