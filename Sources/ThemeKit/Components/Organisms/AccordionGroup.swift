//
//  AccordionGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum AccordionExpandMode { case single, multiple }

/// A group of accordion rows with single- or multiple-open behavior (the
/// reference `AccordionView` tracks a `Set` of open ids). Single mode collapses
/// the others when one opens.
public struct AccordionGroup<Item: Identifiable, Content: View>: View {
    @Environment(\.theme) private var theme

    private let items: [Item]
    private let title: ((Item) -> String)?
    /// Custom header slot (item + isExpanded) replacing the title text.
    /// AnyView slot storage is the house pattern for optional builders.
    private let header: ((Item, Bool) -> AnyView)?
    private let content: (Item) -> Content

    // Behavior — mutated only through the modifiers below (R2).
    private var mode: AccordionExpandMode = .single
    private var indicator: AccordionIndicator = .chevron
    private var showSurface: Bool = true
    private var showDividers: Bool = true
    private var isCollapsible: Bool = true
    private var isItemDisabled: ((Item) -> Bool)? = nil

    /// Open-row ids — uncontrolled (`initiallyExpanded:` seeds @State) or
    /// controlled (the caller's `expanded:` binding drives toggling), unified
    /// by `ControllableState` (ADR-4).
    @ControllableState private var expanded: Set<Item.ID>
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(   // R1 — `initiallyExpanded` seeds @State, so it stays in the init
        _ items: [Item],
        initiallyExpanded: Set<Item.ID> = [],
        title: @escaping (Item) -> String,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.title = title
        self.header = nil
        self.content = content
        self._expanded = ControllableState(wrappedValue: initiallyExpanded)
    }

    public init(   // R1 — controlled expansion; toggling goes through the binding
        _ items: [Item],
        expanded: Binding<Set<Item.ID>>,
        title: @escaping (Item) -> String,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.title = title
        self.header = nil
        self.content = content
        self._expanded = ControllableState(wrappedValue: [], external: expanded)
    }

    public init<Header: View>(   // R1 — custom header (item + isExpanded) replaces the title text
        _ items: [Item],
        initiallyExpanded: Set<Item.ID> = [],
        @ViewBuilder header: @escaping (Item, Bool) -> Header,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.title = nil
        self.header = { AnyView(header($0, $1)) }
        self.content = content
        self._expanded = ControllableState(wrappedValue: initiallyExpanded)
    }

    public init<Header: View>(   // R1 — controlled expansion + custom header
        _ items: [Item],
        expanded: Binding<Set<Item.ID>>,
        @ViewBuilder header: @escaping (Item, Bool) -> Header,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.title = nil
        self.header = { AnyView(header($0, $1)) }
        self.content = content
        self._expanded = ControllableState(wrappedValue: [], external: expanded)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isOpen = expanded.contains(item.id)
                let isDisabled = isItemDisabled?(item) ?? false
                Button { toggle(item.id) } label: {
                    HStack {
                        headerView(for: item, isOpen: isOpen, isDisabled: isDisabled)
                        Spacer()
                        indicatorIcon(isOpen: isOpen, isDisabled: isDisabled)
                    }
                    .padding(Theme.SpacingKey.md.value)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())
                .disabled(isDisabled)
                // State-aware for VoiceOver (Dropdown's disclosure convention);
                // essential for icon-only custom headers with no textual cue.
                .accessibilityValue(isOpen ? String(themeKit: "Expanded") : String(themeKit: "Collapsed"))

                if isOpen {
                    content(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.bottom, Theme.SpacingKey.md.value)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if showDividers && index < items.count - 1 { DividerView().size(.small) }
            }
        }
        .background(
            showSurface ? theme.background(.bgWhite) : Color.clear,
            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: showSurface ? 1 : 0)
        )
        .animation(motion, value: expanded)
    }

    @ViewBuilder
    private func headerView(for item: Item, isOpen: Bool, isDisabled: Bool) -> some View {
        if let header {
            header(item, isOpen)
                .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
        } else {
            Text(title?(item) ?? "")
                .textStyle(.labelBase600)
                .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
        }
    }

    @ViewBuilder
    private func indicatorIcon(isOpen: Bool, isDisabled: Bool) -> some View {
        let color = isDisabled ? theme.text(.textDisabled) : theme.text(.textTertiary)
        switch indicator {
        case .chevron:
            Icon(systemName: "chevron.down").size(.sm).colorOverride(color)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        case .plusMinus:
            Icon(systemName: isOpen ? "minus" : "plus").size(.sm).colorOverride(color)
        case .custom(let expand, let collapse):
            Icon(systemName: isOpen ? collapse : expand).size(.sm).colorOverride(color)
        }
    }

    @MainActor
    private func toggle(_ id: Item.ID) {
        var ids = expanded
        if ids.contains(id) {
            // Non-collapsible single mode keeps the sole open item open.
            if mode == .single && !isCollapsible { return }
            ids.remove(id)
        } else {
            if mode == .single { ids = [id] } else { ids.insert(id) }
        }
        expanded = ids
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AccordionGroup {
    /// Expand behavior: `.single` collapses the others when one opens (default), `.multiple` keeps them open.
    func mode(_ mode: AccordionExpandMode) -> Self { copy { $0.mode = mode } }
    /// Expand/collapse indicator glyph applied to every row (chevron / plus-minus / custom).
    func indicator(_ indicator: AccordionIndicator) -> Self { copy { $0.indicator = indicator } }
    /// Whether to draw the card chrome — background fill + stroke (default true).
    /// `false` yields the plain variant: rows only, no surface.
    func surface(_ on: Bool = true) -> Self { copy { $0.showSurface = on } }
    /// Whether to draw the dividers between rows (default true).
    func dividers(_ on: Bool = true) -> Self { copy { $0.showDividers = on } }
    /// Whether an open item can be collapsed again (default true). When `false`
    /// in `.single` mode, tapping the sole open item keeps it open.
    func collapsible(_ on: Bool = true) -> Self { copy { $0.isCollapsible = on } }
    /// Per-item disabled predicate — disabled rows render in the disabled text
    /// token and don't respond to taps.
    func itemDisabled(_ isDisabled: @escaping (Item) -> Bool) -> Self { copy { $0.isItemDisabled = isDisabled } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct FAQ: Identifiable { let id = UUID(); let q: String; let a: String }
    let faqs = [FAQ(q: "Can I cancel?", a: "Yes, free up to 24 hours before."),
                FAQ(q: "Payment options?", a: "Credit card and bank transfer.")]
    return PreviewMatrix("AccordionGroup") {
        PreviewCase("Single mode") {
            AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
        }
        PreviewCase("Multiple mode") {
            AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
                .mode(.multiple)
        }
        // Custom header (item + isExpanded) with a plus/minus indicator.
        PreviewCase("Custom header + plus/minus") {
            AccordionGroup(faqs) { faq, isOpen in
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Icon(systemName: isOpen ? "folder.badge.minus" : "folder").size(.sm)
                    Text(faq.q).textStyle(isOpen ? .labelBase600 : .bodyBase400)
                }
            } content: { Text($0.a).textStyle(.bodyBase400) }
                .indicator(.plusMinus)
        }
        // Plain variant — no card chrome, no dividers.
        PreviewCase("Plain (no chrome)") {
            AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
                .surface(false)
                .dividers(false)
        }
        // Non-collapsible single mode — one row always stays open.
        PreviewCase("Non-collapsible") {
            AccordionGroup(faqs, initiallyExpanded: [faqs[0].id]) { $0.q } content: {
                Text($0.a).textStyle(.bodyBase400)
            }
            .collapsible(false)
        }
        PreviewCase("Per-item disabled") {
            AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
                .itemDisabled { $0.q.contains("Payment") }
        }
    }
}

#Preview("Controlled") {
    struct ControlledDemo: View {
        struct FAQ: Identifiable { let id: Int; let q: String; let a: String }
        let faqs = [FAQ(id: 0, q: "Can I cancel?", a: "Yes, free up to 24 hours before."),
                    FAQ(id: 1, q: "Payment options?", a: "Credit card and bank transfer.")]
        @State private var open: Set<Int> = []

        var body: some View {
            VStack(spacing: 24) {
                // Controlled expansion — external buttons drive the same binding.
                AccordionGroup(faqs, expanded: $open) { $0.q } content: {
                    Text($0.a).textStyle(.bodyBase400)
                }
                .mode(.multiple)
                HStack {
                    Button("Expand all") { open = Set(faqs.map(\.id)) }
                    Button("Collapse all") { open = [] }
                }
            }
            .padding()
        }
    }
    return ControlledDemo()
}
