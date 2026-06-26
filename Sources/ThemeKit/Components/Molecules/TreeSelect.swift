//
//  TreeSelect.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Hierarchical (nested) select with expand/collapse and multi-selection.
//  (Ant TreeSelect.) Nodes are a simple value tree; selection is a set of node ids.
//

import SwiftUI

public struct TreeNode: Identifiable {
    public let id: String
    let title: String
    let systemImage: String?
    let children: [TreeNode]
    public init(id: String, _ title: String, systemImage: String? = nil, children: [TreeNode] = []) {
        self.id = id; self.title = title; self.systemImage = systemImage; self.children = children
    }
}

public struct TreeSelect: View {
    private let label: String?
    private let nodes: [TreeNode]
    @Binding private var selection: Set<String>
    private let placeholder: String
    private let cascade: Bool
    private let searchable: Bool
    private let isEnabled: Bool
    private let isLoading: Bool
    private let isNodeEnabled: ((TreeNode) -> Bool)?

    @State private var open = false
    @State private var expanded: Set<String>
    @State private var searchText = ""

    public init(
        label: String? = nil,
        nodes: [TreeNode],
        selection: Binding<Set<String>>,
        placeholder: String = String(themeKit: "Select"),
        cascade: Bool = false,
        searchable: Bool = false,
        initiallyExpanded: Set<String> = [],
        isEnabled: Bool = true,
        isLoading: Bool = false,
        isNodeEnabled: ((TreeNode) -> Bool)? = nil
    ) {
        self.label = label
        self.nodes = nodes
        self._selection = selection
        self.placeholder = placeholder
        self.cascade = cascade
        self.searchable = searchable
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isNodeEnabled = isNodeEnabled
        self._expanded = State(initialValue: initiallyExpanded)
    }

    private enum NodeCheck { case off, partial, on }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }
            field
            if open {
                VStack(spacing: 0) {
                    if searchable {
                        searchField
                        DividerView(size: .small)
                    }
                    if isLoading {
                        loadingRow
                    } else {
                        let rows = visibleRows(nodes, depth: 0)
                        if rows.isEmpty {
                            emptyRow
                        } else {
                            ForEach(rows, id: \.node.id) { entry in
                                row(entry.node, depth: entry.depth)
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
                .themeShadow(.soft)
            }
        }
        .animation(Motion.fast.animation, value: open)
        .animation(Motion.fast.animation, value: expanded)
    }

    private var searchField: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: "magnifyingglass", size: .sm, color: Theme.shared.text(.textTertiary))
            TextField("Ara", text: $searchText)
                .textStyle(.bodyBase400)
                .foregroundStyle(Theme.shared.text(.textPrimary))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    private var loadingRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Spinner(size: IconSize.sm.value, lineWidth: 2)
            Text(String(themeKit: "Searching…")).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textTertiary))
            Spacer()
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    private var emptyRow: some View {
        Text(String(themeKit: "No results"))
            .textStyle(.bodySm400)
            .foregroundStyle(Theme.shared.text(.textTertiary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    private var field: some View {
        Button { if isEnabled { open.toggle() } } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Text(summary)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(selection.isEmpty ? Theme.shared.text(.textTertiary) : Theme.shared.text(.textPrimary))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Icon(systemName: open ? "chevron.up" : "chevron.down", size: .sm, color: Theme.shared.text(.textTertiary))
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(56)
            .frame(maxWidth: .infinity)
            .background(Theme.shared.background(isEnabled ? .bgWhite : .bgSecondaryLight), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(
                        open ? Theme.shared.border(.borderHero) : Theme.shared.border(.borderPrimary),
                        lineWidth: open ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var summary: String {
        let titles = allNodes(nodes).filter { selection.contains($0.id) }.map(\.title)
        return titles.isEmpty ? placeholder : titles.joined(separator: ", ")
    }

    private func row(_ node: TreeNode, depth: Int) -> some View {
        let enabled = nodeEnabled(node)
        return HStack(spacing: Theme.SpacingKey.sm.value) {
            if node.children.isEmpty {
                Color.clear.frame(width: 16, height: 16)
            } else {
                Button { toggleExpand(node.id) } label: {
                    Icon(systemName: expanded.contains(node.id) ? "chevron.down" : "chevron.right", size: .xs, color: Theme.shared.text(.textTertiary))
                        .frame(width: 16, height: 16)
                        .mirrorsInRTL()
                }
                .buttonStyle(.plain)
            }
            Button { toggleSelect(node) } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    let state = checkState(node)
                    Checkbox(isChecked: .constant(state == .on), size: .small, isIndeterminate: state == .partial)
                        .allowsHitTesting(false)
                    if let icon = node.systemImage {
                        Icon(systemName: icon, size: .sm, color: Theme.shared.text(.textTertiary))
                    }
                    Text(node.title).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textPrimary))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
        }
        .padding(.leading, CGFloat(depth) * 18 + Theme.SpacingKey.md.value)
        .padding(.trailing, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
    }

    private func visibleRows(_ nodes: [TreeNode], depth: Int) -> [(node: TreeNode, depth: Int)] {
        var out: [(node: TreeNode, depth: Int)] = []
        let searching = searchable && !searchText.isEmpty
        for n in nodes where !searching || matches(n) {
            out.append((n, depth))
            let showChildren = searching ? true : expanded.contains(n.id)
            if showChildren, !n.children.isEmpty {
                out.append(contentsOf: visibleRows(n.children, depth: depth + 1))
            }
        }
        return out
    }

    private func matches(_ node: TreeNode) -> Bool {
        if searchText.isEmpty { return true }
        if node.title.localizedCaseInsensitiveContains(searchText) { return true }
        return node.children.contains { matches($0) }
    }

    private func allNodes(_ nodes: [TreeNode]) -> [TreeNode] {
        nodes.flatMap { [$0] + allNodes($0.children) }
    }

    private func nodeEnabled(_ node: TreeNode) -> Bool { isNodeEnabled?(node) ?? true }

    /// Leaf-descendant nodes (a leaf is its own only leaf).
    private func leafNodes(_ node: TreeNode) -> [TreeNode] {
        node.children.isEmpty ? [node] : node.children.flatMap { leafNodes($0) }
    }

    /// Enabled leaf ids — the only ones a cascade toggle is allowed to flip.
    private func selectableLeafIDs(_ node: TreeNode) -> [String] {
        leafNodes(node).filter { nodeEnabled($0) }.map(\.id)
    }

    /// Tri-state checkbox: in cascade mode a parent is on/partial/off from its
    /// selectable leaves; otherwise a node is simply on/off by its own id.
    private func checkState(_ node: TreeNode) -> NodeCheck {
        guard cascade, !node.children.isEmpty else {
            return selection.contains(node.id) ? .on : .off
        }
        let leaves = selectableLeafIDs(node)
        let selected = leaves.filter { selection.contains($0) }.count
        if selected == 0 { return .off }
        return selected == leaves.count ? .on : .partial
    }

    private func toggleExpand(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func toggleSelect(_ node: TreeNode) {
        guard nodeEnabled(node) else { return }
        if cascade {
            let leaves = selectableLeafIDs(node)
            if checkState(node) == .on { leaves.forEach { selection.remove($0) } }
            else { leaves.forEach { selection.insert($0) } }
        } else {
            if selection.contains(node.id) { selection.remove(node.id) } else { selection.insert(node.id) }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var picks: Set<String> = ["ist"]
        let tree = [
            TreeNode(id: "tr", "Türkiye", systemImage: "flag", children: [
                TreeNode(id: "ist", "İstanbul"),
                TreeNode(id: "ank", "Ankara"),
            ]),
            TreeNode(id: "de", "Almanya", systemImage: "flag", children: [
                TreeNode(id: "ber", "Berlin"),
                TreeNode(id: "mun", "Münih"),
            ]),
        ]
        var body: some View {
            TreeSelect(label: "Şehirler", nodes: tree, selection: $picks, initiallyExpanded: ["tr"]).padding()
        }
    }
    return Demo()
}
