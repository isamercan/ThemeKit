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
/// is a hero-tinted bordered pill; `.tinted` drops the thumb for a soft hero-wash
/// track (the active option just switches to the hero foreground) — pair it with
/// `.dividers()` for the design-system icon toggle (chart / grid view switch).
public enum SegmentedSelectionStyle { case thumb, outline, tinted }

public struct SegmentedControl: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    @Environment(\.componentDefaults) private var componentDefaults

    private let items: [SegmentItem]
    @Binding private var selection: Int

    // Appearance/state — mutated only through the modifiers below (R2).
    private var isFullWidth = true
    private var size: SegmentedSize = .medium
    private var shape: SegmentedShape = .default
    private var selectionStyle: SegmentedSelectionStyle = .thumb
    /// Explicit `.accent(_:)` / `.tinted(_:)` color; `nil` defers to the
    /// subtree `componentDefaults` accent, then `.primary` (provider cascade, F3).
    private var tintColor: SemanticColor?
    private var isVertical = false
    private var showsDividers = false
    private var accessibilityID: String? = nil

    /// The resolved tint for the `.tinted` / `.outline` selection styles:
    /// explicit modifier ?? subtree `componentDefaults.accent` ?? `.primary`.
    private var resolvedTint: SemanticColor { tintColor ?? componentDefaults.accent ?? .primary }
    /// `true` while nothing (explicit or provider) re-tints the control — the
    /// stock hero chroma applies, keeping the default look pixel-identical.
    private var usesStockTint: Bool { tintColor == nil && componentDefaults.accent == nil }

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

    /// The track fill — the tint's soft wash for `.tinted`, else the neutral base.
    private var trackFill: Color {
        selectionStyle == .tinted ? theme.resolve(resolvedTint).soft : theme.background(.bgBase)
    }

    public var body: some View {
        segments
            .padding(selectionStyle == .tinted ? 0 : 4)
            .background(trackFill, in: trackShape)
            .opacity(isEnabled ? 1 : 0.5)
            .a11y(A11yElement.Control.toggle, in: accessibilityID)
            .accessibilityValue(items.indices.contains(selection) ? items[selection].accessibilityText : "")
    }

    @ViewBuilder private var segments: some View {
        if isVertical {
            VStack(spacing: showsDividers ? 0 : 4) { segmentRows }
        } else {
            HStack(spacing: showsDividers ? 0 : 4) { segmentRows }
        }
    }

    @ViewBuilder private var segmentRows: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            segment(index, item)
            if showsDividers && index < items.count - 1 { divider }
        }
    }

    /// A hairline between adjacent segments (the design-system icon toggle).
    @ViewBuilder private var divider: some View {
        if isVertical {
            Rectangle().fill(theme.background(.bgWhite)).frame(height: 1).padding(.horizontal, 6)
        } else {
            Rectangle().fill(theme.background(.bgWhite)).frame(width: 1).padding(.vertical, 6)
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
                // Stock hue keeps the historical hero-border chroma exactly;
                // an explicit/provider accent re-tints the pill + stroke.
                thumbShape.fill(theme.resolve(resolvedTint).soft)
                    .overlay(thumbShape.stroke(usesStockTint ? theme.border(.borderHero) : theme.resolve(resolvedTint).border, lineWidth: 2))
                    .matchedGeometryEffect(id: "pill", in: pill)
            case .tinted:
                EmptyView()   // no thumb — the soft track + hero foreground carry selection
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
        guard isActive else { return theme.text(.textSecondary) }
        // The tinted style follows its base color's accent; others use the hero.
        return selectionStyle == .tinted ? theme.resolve(resolvedTint).accent : theme.text(.textHero)
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
    /// How the active option is drawn — the raised white `.thumb` (default), a
    /// hero-tinted `.outline` pill, or a thumbless `.tinted` soft track.
    func selectionStyle(_ s: SegmentedSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// Draw a hairline between adjacent segments — pair with `.tinted()` / `.shape(.round)`
    /// for the design-system icon toggle (chart / grid switch).
    func dividers(_ on: Bool = true) -> Self { copy { $0.showsDividers = on } }
    /// The thumbless soft-track selection style, tinted with a base `color`:
    /// the track uses `color.soft`, the active option `color.accent`. `nil`
    /// (default) defers to the subtree ``ComponentDefaults`` accent, then the
    /// hero primary. Shortcut for `.selectionStyle(.tinted)` with a color.
    func tinted(_ color: SemanticColor? = nil) -> Self {
        copy { $0.selectionStyle = .tinted; $0.tintColor = color }
    }

    /// Semantic tint for the `.tinted` / `.outline` selection styles (standard
    /// accent vocabulary); `nil` (default) defers to the subtree
    /// ``ComponentDefaults`` accent (set once with
    /// `.componentDefaults(accent:)`), then `.primary`. The stock `.thumb`
    /// style keeps its neutral chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.tintColor = color } }
    /// Sets the accessibility-identifier namespace for this component.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var a = 0
    @Previewable @State var b = 1
    @Previewable @State var c = 0
    @Previewable @State var d = 2
    PreviewMatrix("SegmentedControl") {
        PreviewCase("Default") { SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $a) }
        PreviewCase("Round") { SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $a).shape(.round) }
        PreviewCase("Icons + disabled item") {
            SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                              SegmentItem("Grid", systemImage: "square.grid.2x2"),
                              SegmentItem("Map", systemImage: "map", isEnabled: false)], selection: $b)
        }
        PreviewCase("Icon-only") {
            SegmentedControl([SegmentItem(icon: "list.bullet"), SegmentItem(icon: "square.grid.2x2"),
                              SegmentItem(icon: "map")], selection: $c).fullWidth(false)
        }
        PreviewCase("Vertical") { SegmentedControl(["A", "B", "C"], selection: $d).vertical().fullWidth(false) }
        // F3 — provider cascade: no explicit accent → the subtree
        // componentDefaults re-tints .tinted/.outline; explicit wins.
        PreviewCase("Provider cascade (F3)") {
            VStack(alignment: .leading, spacing: 8) {
                SegmentedControl(["Chart", "Grid"], selection: $a).tinted().dividers().fullWidth(false)
                SegmentedControl(["Day", "Week"], selection: $b).selectionStyle(.outline)
                SegmentedControl(["On", "Off"], selection: $c).tinted(.success).fullWidth(false)
            }
            .componentDefaults(accent: .turquoise)
        }
    }
}
