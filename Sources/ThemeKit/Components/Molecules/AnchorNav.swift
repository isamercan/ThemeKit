//
//  AnchorNav.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Anchor** — a scroll-spy link rail. Each link jumps to
//  a section (via `onSelect`, wired to a `ScrollViewReader`), and the active link
//  is highlighted with a moving hero indicator as the reader reports the current
//  section. Vertical (default) or horizontal. Named `AnchorNav` because SwiftUI
//  already defines a generic `Anchor<Value>` for anchor preferences.
//
//      ScrollViewReader { proxy in
//          AnchorNav(sections, active: $current).onSelect { proxy.scrollTo($0, anchor: .top) }
//      }
//
//  Pair with ``Affix`` on the enclosing view to pin the rail while scrolling.
//

import SwiftUI

/// One entry in an ``AnchorNav`` rail. `level` indents nested links (Ant sub-anchors).
public struct AnchorItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public var level: Int
    public init(_ id: String, title: String, level: Int = 0) {
        self.id = id
        self.title = title
        self.level = level
    }
}

public struct AnchorNav: View {
    @Environment(\.theme) private var theme
    @Namespace private var indicator

    private let items: [AnchorItem]
    @Binding private var active: String
    // Appearance — mutated only through the modifiers below.
    private var axis: Axis = .vertical
    private var onSelect: ((String) -> Void)?

    public init(_ items: [AnchorItem], active: Binding<String>) {   // R1
        self.items = items
        self._active = active
    }

    public var body: some View {
        // iOS 15.6 floor: `AnyLayout(H/VStackLayout)` is iOS 16 — branch into
        // explicit stacks instead. An axis change swaps the container identity,
        // so it isn't animated as a single cross-fade (acceptable: the axis is
        // a configuration, not runtime state; Reduce-Motion-safe either way).
        Group {
            if axis == .vertical {
                VStack(alignment: .leading, spacing: 2) { links }
            } else {
                HStack(spacing: Theme.SpacingKey.sm.value) { links }
            }
        }
        .animation(ThemeMotion.snappy(.fast), value: active)
    }

    private var links: some View {
        ForEach(items) { item in link(item) }
    }

    private func link(_ item: AnchorItem) -> some View {
        let isActive = item.id == active
        return Button {
            active = item.id
            onSelect?(item.id)
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if axis == .vertical { rail(isActive: isActive) }
                Text(item.title)
                    .textStyle(isActive ? .labelBase700 : .bodyBase400)
                    .foregroundStyle(isActive ? theme.text(.textHero) : theme.text(.textSecondary))
                    .padding(.leading, axis == .vertical ? CGFloat(item.level) * Theme.SpacingKey.md.value : 0)
            }
            .padding(.vertical, axis == .vertical ? 4 : 6)
            .padding(.horizontal, axis == .horizontal ? Theme.SpacingKey.sm.value : 0)
            .overlay(alignment: .bottom) {
                if axis == .horizontal, isActive {
                    Rectangle().fill(theme.border(.borderHero)).frame(height: 2)
                        .matchedGeometryEffect(id: "bar", in: indicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func rail(isActive: Bool) -> some View {
        ZStack {
            Capsule().fill(theme.background(.bgElevatorTertiary)).frame(width: 2)
            if isActive {
                Capsule().fill(theme.border(.borderHero)).frame(width: 2)
                    .matchedGeometryEffect(id: "bar", in: indicator)
            }
        }
        .frame(width: 2)
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension AnchorNav {
    /// Called when a link is tapped — wire to `proxy.scrollTo(id, anchor: .top)`.
    func onSelect(_ action: @escaping (String) -> Void) -> Self { copy { $0.onSelect = action } }
    /// Lay the rail out horizontally (Ant Anchor `direction`).
    func direction(_ axis: Axis) -> Self { copy { $0.axis = axis } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let items = [AnchorItem("intro", title: "Introduction"),
                 AnchorItem("install", title: "Installation"),
                 AnchorItem("usage", title: "Usage", level: 1),
                 AnchorItem("api", title: "API")]
    PreviewMatrix("AnchorNav") {
        PreviewCase("Vertical (default)") { AnchorNav(items, active: .constant("intro")) }
        PreviewCase("Nested link active") { AnchorNav(items, active: .constant("usage")) }
        PreviewCase("Horizontal") { AnchorNav(items, active: .constant("install")).direction(.horizontal) }
    }
    .environment(\.theme, Theme.shared)
}
