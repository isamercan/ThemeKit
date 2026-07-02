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
    private let title: (Item) -> String
    private let content: (Item) -> Content

    // Behavior — mutated only through the modifiers below (R2).
    private var mode: AccordionExpandMode = .single

    @State private var expanded: Set<Item.ID> = []
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
        self.content = content
        self._expanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isOpen = expanded.contains(item.id)
                Button { toggle(item.id) } label: {
                    HStack {
                        Text(title(item)).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                        Icon(systemName: "chevron.down", size: .sm, color: theme.text(.textTertiary))
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .padding(Theme.SpacingKey.md.value)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())

                if isOpen {
                    content(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.bottom, Theme.SpacingKey.md.value)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if index < items.count - 1 { DividerView().size(.small) }
            }
        }
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .animation(motion, value: expanded)
    }

    private func toggle(_ id: Item.ID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            if mode == .single { expanded = [id] } else { expanded.insert(id) }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AccordionGroup {
    /// Expand behavior: `.single` collapses the others when one opens (default), `.multiple` keeps them open.
    func mode(_ mode: AccordionExpandMode) -> Self { copy { $0.mode = mode } }

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
    return VStack(spacing: 24) {
        AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
        AccordionGroup(faqs) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
            .mode(.multiple)
    }
    .padding()
}
