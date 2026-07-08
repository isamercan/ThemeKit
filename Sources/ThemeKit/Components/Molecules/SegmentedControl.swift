//
//  SegmentedControl.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Ant Design's **Segmented** — an enclosed single-select control where
//  the active option is a raised, sliding thumb. Full Ant parity: string / icon /
//  icon-only / custom-content options, `block` (full width), `size`, `shape`
//  (default / round), `vertical`, per-item `disabled` + `tooltip`, and hover.
//
//  A `selectionStyle` extends Ant: `.thumb` (the white raised card) or `.outline`
//  (a hero-tinted bordered pill) — the latter lets richer controls like
//  ``DatePriceStrip`` wrap Segmented while keeping their own selected look.
//

import SwiftUI

/// One Segmented option. Carries a label + icon, an icon-only glyph, or fully
/// custom content (Ant's `ReactNode` label — e.g. an avatar over a name).
public struct SegmentItem {
    let title: String?
    let systemImage: String?
    let isEnabled: Bool
    let tooltip: String?
    let content: AnyView?

    /// Label, with an optional leading icon.
    public init(_ title: String, systemImage: String? = nil, isEnabled: Bool = true, tooltip: String? = nil) {
        self.title = title; self.systemImage = systemImage
        self.isEnabled = isEnabled; self.tooltip = tooltip; self.content = nil
    }
    /// Icon-only option.
    public init(icon systemImage: String, isEnabled: Bool = true, tooltip: String? = nil) {
        self.title = nil; self.systemImage = systemImage
        self.isEnabled = isEnabled; self.tooltip = tooltip; self.content = nil
    }
    /// Custom label content (Ant's `ReactNode` label).
    public init(isEnabled: Bool = true, tooltip: String? = nil, @ViewBuilder content: () -> some View) {
        self.title = nil; self.systemImage = nil
        self.isEnabled = isEnabled; self.tooltip = tooltip; self.content = AnyView(content())
    }

    var accessibilityText: String { title ?? tooltip ?? "" }
    var isIconOnly: Bool { title == nil && content == nil && systemImage != nil }
}

/// Height of the segments. (Ant Segmented `size`: large 40 / middle 32 / small 24.)
public enum SegmentedSize {
    case small, medium, large
    var verticalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.xs.value
        case .medium: return Theme.SpacingKey.sm.value
        case .large: return Theme.SpacingKey.md.value
        }
    }
}

/// Corner style. (Ant Segmented `shape`.)
public enum SegmentedShape { case `default`, round }

/// How the active option is drawn. `.thumb` is Ant's raised white card; `.outline`
/// is a hero-tinted bordered pill (used by wrappers like ``DatePriceStrip``).
public enum SegmentedSelectionStyle { case thumb, outline }

public struct SegmentedControl: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    private let items: [SegmentItem]
    @Binding private var selection: Int

    // Appearance/state — mutated only through the modifiers below (R2).
    private var isFullWidth = true
    private var size: SegmentedSize = .medium
    private var shape: SegmentedShape = .default
    private var selectionStyle: SegmentedSelectionStyle = .thumb
    private var isVertical = false
    private var accessibilityID: String? = nil

    @State private var hovered: Int?
    @Namespace private var pill
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ items: [SegmentItem], selection: Binding<Int>) {   // R1
        self.items = items
        self._selection = selection
    }

    public init(_ items: [String], selection: Binding<Int>) {   // R1
        self.init(items.map { SegmentItem($0) }, selection: selection)
    }

    private var trackShape: AnyShape {
        shape == .round
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
    private var thumbShape: AnyShape {
        shape == .round
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }

    public var body: some View {
        segments
            .padding(4)
            .background(theme.background(.bgBase), in: trackShape)
            .opacity(isEnabled ? 1 : 0.5)
            .a11y(A11yElement.Control.toggle, in: accessibilityID)
            .accessibilityValue(items.indices.contains(selection) ? items[selection].accessibilityText : "")
    }

    @ViewBuilder private var segments: some View {
        if isVertical {
            VStack(spacing: 4) { ForEach(Array(items.enumerated()), id: \.offset) { segment($0.offset, $0.element) } }
        } else {
            HStack(spacing: 4) { ForEach(Array(items.enumerated()), id: \.offset) { segment($0.offset, $0.element) } }
        }
    }

    private func segment(_ index: Int, _ item: SegmentItem) -> some View {
        let isActive = index == selection
        return Button {
            withAnimation(motion) { selection = index }
        } label: {
            label(item, isActive: isActive)
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, size.verticalPadding)
                .padding(.horizontal, item.isIconOnly ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value)
                .background { hoverFill(index: index, isActive: isActive, enabled: item.isEnabled) }
                .background { selectionFill(isActive: isActive) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || !item.isEnabled)
        .onHover { hovering in hovered = hovering ? index : (hovered == index ? nil : hovered) }
        .help(item.tooltip ?? "")
    }

    @ViewBuilder private func label(_ item: SegmentItem, isActive: Bool) -> some View {
        if let content = item.content {
            content
        } else {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let icon = item.systemImage {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                if let title = item.title {
                    Text(title).textStyle(isActive ? .labelBase700 : .labelBase600)
                }
            }
        }
    }

    @ViewBuilder private func selectionFill(isActive: Bool) -> some View {
        if isActive {
            switch selectionStyle {
            case .thumb:
                thumbShape.fill(theme.background(.bgWhite)).themeShadow(.soft)
                    .matchedGeometryEffect(id: "pill", in: pill)
            case .outline:
                thumbShape.fill(SemanticColor.primary.soft)
                    .overlay(thumbShape.stroke(theme.border(.borderHero), lineWidth: 2))
                    .matchedGeometryEffect(id: "pill", in: pill)
            }
        }
    }

    @ViewBuilder private func hoverFill(index: Int, isActive: Bool, enabled: Bool) -> some View {
        if hovered == index, !isActive, enabled, isEnabled {
            thumbShape.fill(theme.text(.textPrimary).opacity(0.06))
        }
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textHero) : theme.text(.textSecondary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SegmentedControl {
    /// Stretch each segment to fill the available width (Ant Segmented `block`).
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isFullWidth = on } }
    /// Segment height: small / medium / large (Ant Segmented `size`).
    func size(_ s: SegmentedSize) -> Self { copy { $0.size = s } }
    /// Corner style — default or a fully-round pill (Ant Segmented `shape`).
    func shape(_ s: SegmentedShape) -> Self { copy { $0.shape = s } }
    /// Stack the segments vertically (Ant Segmented `vertical`).
    func vertical(_ on: Bool = true) -> Self { copy { $0.isVertical = on } }
    /// How the active option is drawn — the raised white `.thumb` (default) or a
    /// hero-tinted `.outline` pill (for richer wrappers).
    func selectionStyle(_ s: SegmentedSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// Sets the accessibility-identifier namespace for this component.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var a = 0
        @State var b = 1
        @State var c = 0
        @State var d = 2
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $a)
                    SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $a).shape(.round)
                    SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                      SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                      SegmentItem("Map", systemImage: "map", isEnabled: false)], selection: $b)
                    SegmentedControl([SegmentItem(icon: "list.bullet"), SegmentItem(icon: "square.grid.2x2"),
                                      SegmentItem(icon: "map")], selection: $c).fullWidth(false)
                    SegmentedControl(["A", "B", "C"], selection: $d).vertical().fullWidth(false)
                }
                .padding()
            }
        }
    }
    return Demo()
}
