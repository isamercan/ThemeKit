//
//  AccordionGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A group of accordion rows with single- or multiple-open behavior (the
//  reference `AccordionView` tracks a `Set` of open ids). Single mode collapses
//  the others when one opens.
//

import SwiftUI

public enum AccordionExpandMode { case single, multiple }

public struct AccordionGroup<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let mode: AccordionExpandMode
    private let title: (Item) -> String
    private let content: (Item) -> Content

    @State private var expanded: Set<Item.ID> = []

    public init(
        _ items: [Item],
        mode: AccordionExpandMode = .single,
        initiallyExpanded: Set<Item.ID> = [],
        title: @escaping (Item) -> String,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.mode = mode
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
                        Text(title(item)).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
                        Spacer()
                        Icon(systemName: "chevron.down", size: .sm, color: Theme.shared.text(.textTertiary))
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

                if index < items.count - 1 { DividerView(size: .small) }
            }
        }
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
        .animation(Motion.fast.animation, value: expanded)
    }

    private func toggle(_ id: Item.ID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            if mode == .single { expanded = [id] } else { expanded.insert(id) }
        }
    }
}

#Preview {
    struct FAQ: Identifiable { let id = UUID(); let q: String; let a: String }
    let faqs = [FAQ(q: "İptal edebilir miyim?", a: "Evet, 24 saat öncesine kadar ücretsiz."),
                FAQ(q: "Ödeme seçenekleri?", a: "Kredi kartı ve havale.")]
    return VStack(spacing: 24) {
        AccordionGroup(faqs, mode: .single) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
        AccordionGroup(faqs, mode: .multiple) { $0.q } content: { Text($0.a).textStyle(.bodyBase400) }
    }
    .padding()
}
