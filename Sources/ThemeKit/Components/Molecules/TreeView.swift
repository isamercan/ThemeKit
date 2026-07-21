//
//  TreeView.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Tree** — a standalone hierarchical tree with
//  expand/collapse disclosure and optional checkboxes. Reuses ``TreeNode`` (from
//  ``TreeSelect``); `selection` is the set of chosen node ids. Checking a parent
//  cascades to its subtree. Named `TreeView` because a bare `Tree` reads poorly
//  next to SwiftUI's tree terminology.
//
//      TreeView(nodes, selection: $checked).checkable()
//

import SwiftUI

public struct TreeView: View {
    @Environment(\.theme) private var theme

    private let nodes: [TreeNode]
    @Binding private var selection: Set<String>
    // Appearance — mutated only through the modifiers below.
    private var checkable = false

    @State private var expanded: Set<String>

    public init(_ nodes: [TreeNode], selection: Binding<Set<String>>) {   // R1
        self.nodes = nodes
        self._selection = selection
        // Expand the first level by default.
        self._expanded = State(initialValue: Set(nodes.map(\.id)))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleRows, id: \.node.id) { row in
                nodeRow(row.node, depth: row.depth)
            }
        }
        .animation(ThemeMotion.snappy(.fast), value: expanded)
    }

    private func nodeRow(_ node: TreeNode, depth: Int) -> some View {
        let hasChildren = !node.children.isEmpty
        let isOn = selection.contains(node.id)
        return HStack(spacing: Theme.SpacingKey.xs.value) {
            // Disclosure chevron
            Button { toggleExpanded(node) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text(.textTertiary))
                    .mirrorsInRTL()
                    .rotationEffect(.degrees(expanded.contains(node.id) ? 90 : 0))
                    .frame(width: 20, height: 20)
                    .opacity(hasChildren ? 1 : 0)
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)
            .accessibilityLabel(expanded.contains(node.id) ? String(themeKit: "Collapse") : String(themeKit: "Expand"))

            // Row body (checkbox + icon + title)
            Button { checkable ? toggleChecked(node) : toggleExpanded(node) } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if checkable {
                        Image(systemName: isOn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 15))
                            .foregroundStyle(isOn ? theme.text(.textHero) : theme.text(.textTertiary))
                    }
                    if let icon = node.systemImage {
                        Image(systemName: icon).font(.system(size: 13)).foregroundStyle(theme.text(.textSecondary))
                    }
                    Text(node.title)
                        .textStyle(isOn ? .labelSm600 : .bodySm400)
                        .foregroundStyle(theme.text(.textPrimary))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(checkable && isOn ? .isSelected : [])
        }
        .padding(.vertical, 5)
        .padding(.leading, CGFloat(depth) * Theme.SpacingKey.md.value)
    }

    /// The flattened list of currently-visible nodes (respecting `expanded`).
    private var visibleRows: [(node: TreeNode, depth: Int)] {
        var out: [(TreeNode, Int)] = []
        func walk(_ ns: [TreeNode], _ depth: Int) {
            for n in ns {
                out.append((n, depth))
                if expanded.contains(n.id) { walk(n.children, depth + 1) }
            }
        }
        walk(nodes, 0)
        return out
    }

    private func toggleExpanded(_ node: TreeNode) {
        if expanded.contains(node.id) { expanded.remove(node.id) } else { expanded.insert(node.id) }
    }

    private func toggleChecked(_ node: TreeNode) {
        let ids = subtreeIDs(node)
        if selection.contains(node.id) { selection.subtract(ids) } else { selection.formUnion(ids) }
    }

    private func subtreeIDs(_ node: TreeNode) -> Set<String> {
        var ids: Set<String> = [node.id]
        for child in node.children { ids.formUnion(subtreeIDs(child)) }
        return ids
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension TreeView {
    /// Show checkboxes; checking a parent cascades to its subtree (Ant `checkable`).
    func checkable(_ on: Bool = true) -> Self { copy { $0.checkable = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var checked: Set<String> = []
        var body: some View {
            let nodes = [
                TreeNode(id: "docs", "Documents", systemImage: "folder", children: [
                    TreeNode(id: "cv", "Resume.pdf", systemImage: "doc"),
                    TreeNode(id: "img", "Images", systemImage: "folder", children: [
                        TreeNode(id: "a", "beach.jpg", systemImage: "photo"),
                        TreeNode(id: "b", "city.jpg", systemImage: "photo")])]),
                TreeNode(id: "music", "Music", systemImage: "folder", children: [
                    TreeNode(id: "s1", "song.mp3", systemImage: "music.note")]),
            ]
            PreviewMatrix("TreeView") {
                PreviewCase("Checkable") { TreeView(nodes, selection: $checked).checkable() }
                PreviewCase("Plain (no checkboxes)") { TreeView(nodes, selection: .constant([])) }
            }
            .environment(\.theme, Theme.shared)
        }
    }
    return Demo()
}
