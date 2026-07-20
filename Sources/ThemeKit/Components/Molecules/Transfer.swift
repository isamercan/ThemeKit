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

/// Which way a ``Transfer`` move went (Ant `onChange` direction).
public enum TransferDirection: Sendable { case toTarget, toSource }

/// Validation tint for a ``Transfer``'s list borders (Ant `status`).
public enum TransferStatus: Sendable { case normal, error, warning }

public struct Transfer: View {
    @Environment(\.theme) private var theme
    /// Whole-control disable (Ant `disabled`) — set natively by `.disabled(_:)`.
    @Environment(\.isEnabled) private var isEnabled

    private let items: [TransferItem]
    @Binding private var target: Set<String>
    // Appearance — mutated only through the modifiers below.
    private var titles: (String, String) = (String(themeKit: "Source"), String(themeKit: "Target"))
    private var isSearchable = false
    /// Per-item enablement predicate (nil enables every item) — the
    /// kit-standard `optionEnabled` idiom (Ant Transfer per-item `disabled`).
    private var isItemEnabled: ((TransferItem) -> Bool)?
    /// Header select-all checkbox in each box (Ant `showSelectAll`); off by default.
    private var showsSelectAll = false
    /// Validation tint for the list borders (Ant `status`).
    private var status: TransferStatus = .normal
    /// Fired after a move with the new target set, the direction, and moved keys
    /// (Ant `onChange(targetKeys, direction, moveKeys)`).
    private var onChangeHandler: ((_ target: Set<String>, _ direction: TransferDirection, _ movedKeys: [String]) -> Void)?

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
        // Whole-control disabled (Ant `disabled`): native `.disabled` inert-ifies
        // the inner buttons; the dim makes the state visible.
        .opacity(isEnabled ? 1 : 0.5)
    }

    // MARK: Select-all (Ant `showSelectAll`)

    /// The enabled, currently-visible (post-filter) items in a box — the set a
    /// header select-all toggles.
    private func selectableKeys(_ items: [TransferItem], query: String) -> [String] {
        filtered(items, query: query).filter(itemEnabled).map(\.key)
    }

    private func allChecked(_ keys: [String]) -> Bool {
        !keys.isEmpty && keys.allSatisfy { checked.contains($0) }
    }

    private func toggleAll(_ keys: [String]) {
        if allChecked(keys) { checked.subtract(keys) } else { checked.formUnion(keys) }
    }

    /// The list-box border tint for the current `status` (Ant `status`).
    private var borderColor: Color {
        switch status {
        case .normal: return theme.border(.borderPrimary)
        case .error: return theme.border(.systemcolorsBorderError)
        case .warning: return theme.border(.systemcolorsBorderWarning)
        }
    }

    private func listBox(_ title: String, items: [TransferItem], query: Binding<String>) -> some View {
        let selectable = selectableKeys(items, query: query.wrappedValue)
        return VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if showsSelectAll {
                    Button { toggleAll(selectable) } label: {
                        Image(systemName: allChecked(selectable) ? "checkmark.square.fill" : "square")
                            .font(.system(size: 15))
                            .foregroundStyle(selectable.isEmpty ? theme.text(.textDisabled)
                                             : (allChecked(selectable) ? theme.text(.textHero) : theme.text(.textTertiary)))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectable.isEmpty)
                    .accessibilityLabel(String(themeKit: allChecked(selectable) ? "Deselect all" : "Select all"))
                }
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
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value)
            .strokeBorder(borderColor, lineWidth: status == .normal ? 1 : 2))
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
            .background(isOn && enabled ? theme.resolve(.primary).soft.opacity(0.5) : .clear)
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
                .foregroundStyle(enabled ? theme.resolve(.primary).onSolid : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
                .background(enabled ? theme.resolve(.primary).solid : theme.background(.bgElevatorTertiary),
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
        guard !moving.isEmpty else { return }
        target.formUnion(moving)
        checked.subtract(moving)
        onChangeHandler?(target, .toTarget, moving)
    }

    private func moveToSource() {
        let moving = targeted.filter { checked.contains($0.key) && itemEnabled($0) }.map(\.key)
        guard !moving.isEmpty else { return }
        target.subtract(moving)
        checked.subtract(moving)
        onChangeHandler?(target, .toSource, moving)
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

    /// Show a select-all checkbox in each box header that toggles every
    /// enabled, currently-visible row in that box (Ant `showSelectAll`).
    func showsSelectAll(_ on: Bool = true) -> Self { copy { $0.showsSelectAll = on } }

    /// Validation tint for the list borders (Ant `status`): normal / error / warning.
    func status(_ status: TransferStatus) -> Self { copy { $0.status = status } }

    /// Called after items move, with the new target set, the direction, and the
    /// moved keys (Ant `onChange(targetKeys, direction, moveKeys)`).
    func onChange(_ handler: @escaping (_ target: Set<String>, _ direction: TransferDirection, _ movedKeys: [String]) -> Void) -> Self {
        copy { $0.onChangeHandler = handler }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var target: Set<String> = ["wifi"]
    let items = [TransferItem("wifi", title: "Wi-Fi"), TransferItem("bkfst", title: "Breakfast"),
                 TransferItem("pool", title: "Pool"), TransferItem("gym", title: "Gym"),
                 TransferItem("spa", title: "Spa"), TransferItem("park", title: "Parking")]
    PreviewMatrix("Transfer") {
        PreviewCase("Default") {
            Transfer(items, target: $target).titles("Available", "Included")
        }
        // Header select-all (Ant `showSelectAll`) + error status border.
        PreviewCase("Select-all + error status") {
            Transfer(items, target: $target)
                .titles("Available", "Included")
                .showsSelectAll()
                .status(.error)
        }
    }
    .environment(\.theme, Theme.shared)
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
        .environment(\.theme, Theme.shared)
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
    return Demo().environment(\.theme, Theme.shared)
}
