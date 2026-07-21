//
//  KanbanBoard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A board of columns with cross-column drag. (HeroUI Pro "Kanban".) The card is
//  a required, type-preserved `@ViewBuilder` closure; all state lives in the
//  caller's `columns` binding, so the component stays stateless. Cards move
//  between columns by drag *and* by a VoiceOver "Move to <column>" action — the
//  a11y path is a first-class requirement, not an afterthought.
//

import SwiftUI
import UniformTypeIdentifiers

/// Width tiers for a ``KanbanBoard`` column (Ant Pro Board / HeroUI Pro kanban
/// column sizing) — an enum, not a raw `CGFloat`, per the token-signature rule.
public enum KanbanColumnWidth: Sendable {
    case compact, regular, wide

    /// Fixed column widths — genuine dimensions with no semantic token.
    var value: CGFloat {
        switch self {
        case .compact: return 240
        case .regular: return 280
        case .wide: return 320
        }
    }
}

/// One board column. `limit` (when exceeded) turns the count red. `accent` is
/// column *data* (a status hue travels with the column, like `title`), so it
/// stays a model argument — the documented exception to the modifiers-only
/// rule for appearance.
public struct KanbanColumn<Item: Identifiable & Equatable>: Identifiable {
    public let id: String
    public let title: String
    public let accent: SemanticColor?
    public var items: [Item]
    public let limit: Int?

    public init(_ title: String, items: [Item], accent: SemanticColor? = nil, limit: Int? = nil, id: String? = nil) {
        self.title = title
        self.items = items
        self.accent = accent
        self.limit = limit
        self.id = id ?? title
    }
}

/// Organism. `KanbanBoard(columns: $columns) { item in Card(item) }`.
public struct KanbanBoard<Item: Identifiable & Equatable, CardContent: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var columns: [KanbanColumn<Item>]
    private let card: (Item) -> CardContent

    /// The card id captured at drag start. `onDrag`/`onDrop` (the iOS-15
    /// single-path replacement for the 16-only `draggable`/`dropDestination` —
    /// ADR-0007 §D2 rule 1) hand the payload over asynchronously via
    /// `NSItemProvider`; within the one board the id is resolved synchronously
    /// from this capture instead, so a drop mutates the binding immediately.
    /// Cross-app drops (which only the provider could describe) are ignored,
    /// matching the previous String-payload behavior in practice.
    @State private var draggedCardID: String?

    // Appearance — mutated only through the modifiers below (R2).
    private var columnWidth: KanbanColumnWidth = .regular
    private var spacingKey: Theme.SpacingKey = .md

    public init(columns: Binding<[KanbanColumn<Item>]>, @ViewBuilder card: @escaping (Item) -> CardContent) {   // R1
        self._columns = columns
        self.card = card
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: theme.spacing(spacingKey)) {
                ForEach(columns) { column in
                    columnView(column)
                }
            }
            .padding(Theme.SpacingKey.xs.value)
        }
        .animation(MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion), value: columns.map(\.items.count))
    }

    private func columnView(_ column: KanbanColumn<Item>) -> some View {
        let isOverLimit = column.limit.map { column.items.count > $0 } ?? false
        return VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Circle().fill(column.accent.map { theme.resolve($0).solid } ?? theme.resolve(.primary).solid).frame(width: 8, height: 8)
                Text(column.title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                Text(countText(column))
                    .textStyle(.labelSm600)
                    .foregroundStyle(isOverLimit ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.SpacingKey.xs.value)

            ForEach(column.items) { item in
                card(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onDrag {
                        draggedCardID = cardID(item)
                        return NSItemProvider(object: cardID(item) as NSString)
                    }
                    // Dropping onto a card inserts before it (within- or
                    // cross-column); dropping on column space appends (below).
                    .onDrop(of: [.text], isTargeted: nil) { _ in
                        dropDraggedCard(toColumn: column.id, before: cardID(item))
                    }
                    .modifier(AccessibilityNamedActions(actions: moveActionList(for: item, in: column)))
            }
        }
        .padding(Theme.SpacingKey.sm.value)
        .frame(width: columnWidth.value, alignment: .top)
        .background(theme.background(.bgSecondaryLight), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .onDrop(of: [.text], isTargeted: nil) { _ in
            dropDraggedCard(toColumn: column.id, before: nil)
        }
    }

    /// Completes the active drag: moves the captured card into `columnID`
    /// (before `targetID`, or appended) and clears the capture.
    private func dropDraggedCard(toColumn columnID: String, before targetID: String?) -> Bool {
        guard let id = draggedCardID else { return false }
        draggedCardID = nil
        move(cardID: id, toColumn: columnID, before: targetID)
        return true
    }

    /// VoiceOver equivalents of the drag — reorder within the column and move
    /// across columns, so the board isn't gated behind a drag gesture. Applied
    /// through ``AccessibilityNamedActions`` (`accessibilityAction(named:)` —
    /// the iOS-15-safe single-path form of the 16-only `accessibilityActions {}`;
    /// ADR-0007 §D2 rule 1).
    private func moveActionList(for item: Item, in column: KanbanColumn<Item>) -> [AccessibilityNamedActions.Action] {
        var actions: [AccessibilityNamedActions.Action] = []
        let index = column.items.firstIndex(of: item)
        if let index, index > 0 {
            actions.append(.init(label: String(themeKit: "Move up")) { reorder(item, in: column.id, to: index - 1) })
        }
        if let index, index < column.items.count - 1 {
            actions.append(.init(label: String(themeKit: "Move down")) { reorder(item, in: column.id, to: index + 1) })
        }
        for target in columns where target.id != column.id {
            actions.append(.init(label: String(themeKit: "Move to \(target.title)")) {
                move(cardID: cardID(item), toColumn: target.id, before: nil)
            })
        }
        return actions
    }

    private func countText(_ column: KanbanColumn<Item>) -> String {
        if let limit = column.limit { return "\(column.items.count)/\(limit)" }
        return "\(column.items.count)"
    }

    private func cardID(_ item: Item) -> String { String(describing: item.id) }

    /// Move the card with `id` into `columnID`, inserting before `targetID`
    /// (or appending when nil). Handles within-column reorder and cross-column
    /// moves through the one binding; index is recomputed after removal so
    /// same-column shifts stay correct.
    private func move(cardID id: String, toColumn columnID: String, before targetID: String?) {
        guard id != targetID else { return }
        guard let targetColIndex = columns.firstIndex(where: { $0.id == columnID }) else { return }
        var moved: Item?
        for sourceIndex in columns.indices {
            if let itemIndex = columns[sourceIndex].items.firstIndex(where: { cardID($0) == id }) {
                moved = columns[sourceIndex].items.remove(at: itemIndex)
                break
            }
        }
        guard let item = moved else { return }
        if let targetID, let insertIndex = columns[targetColIndex].items.firstIndex(where: { cardID($0) == targetID }) {
            columns[targetColIndex].items.insert(item, at: insertIndex)
        } else {
            columns[targetColIndex].items.append(item)
        }
    }

    /// Reorder a card within its column to `newIndex` (clamped).
    private func reorder(_ item: Item, in columnID: String, to newIndex: Int) {
        guard let ci = columns.firstIndex(where: { $0.id == columnID }),
              let oldIndex = columns[ci].items.firstIndex(of: item) else { return }
        let moved = columns[ci].items.remove(at: oldIndex)
        columns[ci].items.insert(moved, at: min(max(newIndex, 0), columns[ci].items.count))
    }
}

/// Applies a dynamic list of named VoiceOver actions via
/// `accessibilityAction(named:)` — available since iOS 13, so this is the
/// single-path replacement for the iOS-16-only `accessibilityActions {}`
/// builder (ADR-0007 §D2 rule 1). Internal so the suite can drive the action
/// list directly.
struct AccessibilityNamedActions: ViewModifier {
    struct Action {
        let label: String
        let perform: () -> Void

        init(label: String, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    let actions: [Action]

    func body(content: Content) -> some View {
        actions.reduce(AnyView(content)) { view, action in
            AnyView(view.accessibilityAction(named: Text(action.label), action.perform))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension KanbanBoard {
    /// Column width tier: compact / regular (default) / wide (Ant Pro Board /
    /// HeroUI Pro kanban column sizing).
    func columnWidth(_ w: KanbanColumnWidth) -> Self { copy { $0.columnWidth = w } }

    /// Gap between columns by spacing token (default `.md`).
    func spacing(_ key: Theme.SpacingKey) -> Self { copy { $0.spacingKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        struct Task: Identifiable, Equatable { let id: Int; let title: String }
        @State var columns: [KanbanColumn<Task>] = [
            .init("To do", items: [Task(id: 1, title: "Design tokens"), Task(id: 2, title: "Write docs")], accent: .neutral),
            .init("In progress", items: [Task(id: 3, title: "Build charts")], accent: .primary, limit: 2),
            .init("Done", items: [Task(id: 4, title: "Ship colors")], accent: .success),
        ]
        var body: some View {
            PreviewMatrix("KanbanBoard") {
                PreviewCase("Default (regular columns)") {
                    KanbanBoard(columns: $columns) { task in
                        Text(task.title)
                            .textStyle(.labelBase600)
                            .padding(Theme.SpacingKey.sm.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                    }
                }
                // D7 — width tier + token gap axes.
                PreviewCase("Compact columns · .sm gap") {
                    KanbanBoard(columns: $columns) { task in
                        Text(task.title)
                            .textStyle(.labelBase600)
                            .padding(Theme.SpacingKey.sm.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                    }
                    .columnWidth(.compact)
                    .spacing(.sm)
                }
            }
        }
    }
    return Demo()
}
