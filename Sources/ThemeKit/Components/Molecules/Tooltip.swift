//
//  Tooltip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A small bubble with an arrow, attached to one of four edges of an
//  anchor via the `.tooltip(...)` modifier. Defaults to the original dark bubble;
//  an optional semantic `style` recolors it (Ant Tooltip `color`), and `maxWidth`
//  lets the text wrap onto multiple lines. Two entry points: a binding-driven
//  modifier and a self-managed tap-to-toggle convenience. (Ant Tooltip parity.)
//

import SwiftUI

/// Placement of the tooltip bubble relative to its anchor. (Ant Tooltip `placement`.)
public enum TooltipEdge: Sendable {
    case top, bottom, leading, trailing

    /// `true` for the vertically-stacked edges (bubble above/below the anchor).
    var isVertical: Bool { self == .top || self == .bottom }

    /// The overlay alignment that pins the bubble to this edge of the anchor.
    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

/// A triangle whose apex points toward the anchor for the given edge.
private struct TooltipArrow: Shape {
    let edge: TooltipEdge

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch edge {
        case .top: // bubble above the anchor → point down
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .bottom: // bubble below → point up
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .leading: // bubble to the left → point right
            p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .trailing: // bubble to the right → point left
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

private struct TooltipBubble: View {
    let text: String
    let edge: TooltipEdge
    let style: BadgeStyle?
    let maxWidth: CGFloat?

    private var bubbleColor: Color { style?.semantic.solid ?? Theme.shared.background(.bgTertiary) }
    private var textColor: Color { style?.semantic.onSolid ?? Theme.shared.foreground(.fgSecondary) }

    var body: some View {
        let bubble = Text(text)
            .textStyle(.bodySm400)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(bubbleColor,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))

        let arrow = TooltipArrow(edge: edge)
            .fill(bubbleColor)
            .frame(width: edge.isVertical ? 12 : 6, height: edge.isVertical ? 6 : 12)

        switch edge {
        case .top: VStack(spacing: -1) { bubble; arrow }
        case .bottom: VStack(spacing: -1) { arrow; bubble }
        case .leading: HStack(spacing: -1) { bubble; arrow }
        case .trailing: HStack(spacing: -1) { arrow; bubble }
        }
    }
}

/// Pushes the bubble just outside the chosen edge of the anchor.
private struct TooltipPlacement: ViewModifier {
    let edge: TooltipEdge

    func body(content: Content) -> some View {
        switch edge {
        case .top: content.offset(y: -8).alignmentGuide(.top) { $0[.bottom] }
        case .bottom: content.offset(y: 8).alignmentGuide(.bottom) { $0[.top] }
        case .leading: content.offset(x: -8).alignmentGuide(.leading) { $0[.trailing] }
        case .trailing: content.offset(x: 8).alignmentGuide(.trailing) { $0[.leading] }
        }
    }
}

/// Binding-driven tooltip presentation — gates its fade on `microAnimations`.
private struct BindingTooltip: ViewModifier {
    let text: String
    @Binding var isPresented: Bool
    let edge: TooltipEdge
    let style: BadgeStyle?
    let maxWidth: CGFloat?
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge.alignment) {
                if isPresented {
                    TooltipBubble(text: text, edge: edge, style: style, maxWidth: maxWidth)
                        .fixedSize(horizontal: maxWidth == nil, vertical: true)
                        .modifier(TooltipPlacement(edge: edge))
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(motion, value: isPresented)
    }
}

/// Wraps an anchor so a tap toggles its own tooltip — no external binding needed.
private struct SelfTooltip: ViewModifier {
    let text: String
    let edge: TooltipEdge
    let style: BadgeStyle?
    let maxWidth: CGFloat?
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .tooltip(text, isPresented: $shown, edge: edge, style: style, maxWidth: maxWidth)
            .contentShape(Rectangle())
            .onTapGesture { shown.toggle() }
            .accessibilityHint(Text(text))
    }
}

public extension View {
    /// Binding-driven tooltip. `edge` chooses which side of the anchor it points
    /// from; `style` recolors the bubble (nil keeps the dark default); `maxWidth`
    /// lets long text wrap.
    func tooltip(
        _ text: String,
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        style: BadgeStyle? = nil,
        maxWidth: CGFloat? = nil
    ) -> some View {
        modifier(BindingTooltip(text: text, isPresented: isPresented, edge: edge, style: style, maxWidth: maxWidth))
    }

    /// Self-managed tooltip: tap the anchor to toggle it (tap again to dismiss).
    /// No external state required — use for simple hint glyphs.
    func tooltip(
        _ text: String,
        edge: TooltipEdge = .top,
        style: BadgeStyle? = nil,
        maxWidth: CGFloat? = nil
    ) -> some View {
        modifier(SelfTooltip(text: text, edge: edge, style: style, maxWidth: maxWidth))
    }
}

#Preview {
    struct Demo: View {
    @Environment(\.theme) private var theme

        @State var show = true
        var body: some View {
            VStack(spacing: 64) {
                Icon(systemName: "info.circle", size: .md, color: theme.foreground(.fgHero))
                    .tooltip("Helpful hint", isPresented: $show)
                HStack(spacing: 56) {
                    Icon(systemName: "questionmark.circle", size: .md, color: theme.foreground(.fgHero))
                        .tooltip("On the trailing side", edge: .trailing, style: .info)
                    Icon(systemName: "exclamationmark.triangle", size: .md, color: theme.foreground(.fgHero))
                        .tooltip("A longer hint that wraps onto several lines", edge: .leading, style: .warning, maxWidth: 140)
                }
            }
            .padding(80)
        }
    }
    return Demo()
}
