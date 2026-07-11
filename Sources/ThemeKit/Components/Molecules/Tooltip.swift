//
//  Tooltip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A small bubble with an arrow, attached to one of four edges of an
//  anchor via the `.tooltip(...)` modifier. Defaults to the original dark bubble;
//  an optional semantic `style` recolors it (Ant Tooltip `color`), `maxWidth`
//  lets the text wrap onto multiple lines, and `align` slides the bubble along
//  the anchored edge (HeroUI Popover `align`). Two entry points: a binding-driven
//  modifier and a self-managed tap-to-toggle convenience that also dismisses on
//  an outside tap. (Ant Tooltip / HeroUI Popover parity.)
//

import SwiftUI
// ColorContrast is an @_spi legibility helper in ThemeKitCore (not re-exported by
// ThemeKit's umbrella), so pull it in explicitly.
@_spi(ThemeKitInternal) import ThemeKitCore

/// Placement of the tooltip bubble relative to its anchor. (Ant Tooltip `placement`.)
public enum TooltipEdge: Sendable {
    case top, bottom, leading, trailing

    /// `true` for the vertically-stacked edges (bubble above/below the anchor).
    var isVertical: Bool { self == .top || self == .bottom }

    /// The overlay alignment that pins the bubble to this edge of the anchor.
    var alignment: Alignment { alignment(.center) }

    /// Overlay alignment for this edge with `align` choosing where along that
    /// edge the bubble/card anchors (leading/top for `.start`, centered, or
    /// trailing/bottom for `.end`). `.center` reproduces `alignment`.
    func alignment(_ align: PopoverAlign) -> Alignment {
        if isVertical {
            let horizontal: HorizontalAlignment
            switch align {
            case .start: horizontal = .leading
            case .center: horizontal = .center
            case .end: horizontal = .trailing
            }
            return Alignment(horizontal: horizontal, vertical: self == .top ? .top : .bottom)
        } else {
            let vertical: VerticalAlignment
            switch align {
            case .start: vertical = .top
            case .center: vertical = .center
            case .end: vertical = .bottom
            }
            return Alignment(horizontal: self == .leading ? .leading : .trailing, vertical: vertical)
        }
    }
}

/// Cross-axis alignment of an anchored bubble or card along its edge —
/// `.start` lines up the leading (or top) edges, `.end` the trailing (or
/// bottom) edges, `.center` keeps the historical centered placement.
/// (HeroUI Popover `align`.) Shared by `.tooltip`, `.popconfirm` and
/// `.themePopover`.
public enum PopoverAlign: Sendable {
    case start, center, end
}

/// A triangle whose apex points toward the anchor for the given edge.
/// The path runs base-corner → apex → base-corner and is left *open* along the
/// base: `fill` closes it implicitly (same triangle as before), while `stroke`
/// draws a hairline on the two exposed sides only — exactly what a bordered
/// card arrow needs (HeroUI Popover.Arrow's fill + open stroke path). Internal
/// so `Popconfirm` can compose the same arrow onto its card.
struct TooltipArrow: Shape {
    let edge: TooltipEdge

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch edge {
        case .top: // bubble above the anchor → point down
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .bottom: // bubble below → point up
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .leading: // bubble to the left → point right
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .trailing: // bubble to the right → point left
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return p
    }
}

/// A transparent, effectively screen-covering hit target placed *behind* an
/// anchored bubble/card so a tap anywhere outside it dismisses the popover
/// (HeroUI Popover overlay `closeOnPress`). Only mounted while presented, so
/// the anchor stays fully interactive when nothing is shown. Internal — shared
/// by the self-managed tooltip and the Popconfirm/ThemePopover presenter.
struct PopoverTapCatcher: View {
    let onTap: () -> Void

    /// Fixed catch radius around the anchor — a genuine dimension with no
    /// semantic token; generous enough to cover any window from any anchor.
    private static let side: CGFloat = 10_000

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture(perform: onTap)
            .accessibilityHidden(true)
    }
}

private struct TooltipBubble: View {
    @Environment(\.theme) private var theme

    let text: String
    /// Rich slot content (the `.tooltip(isPresented:…) { }` overload); when set
    /// it replaces the plain `Text` inside the same bubble chrome. It inherits
    /// the bubble's auto-contrast foreground and `bodySm400` type ramp, so
    /// plain `Text`/`Image(systemName:)` children render correctly with zero
    /// configuration (slot convention).
    var rich: SlotContent? = nil
    let edge: TooltipEdge
    let style: BadgeStyle?
    let color: SemanticColor?
    let maxWidth: CGFloat?

    // `color` (full semantic palette, incl. primary/secondary/accent) wins over
    // the badge-style shorthand; nil-nil keeps the dark default.
    private var bubbleColor: Color { color?.solid ?? style?.semantic.solid ?? theme.background(.bgTertiary) }
    // Auto-contrast against whatever bubble is shown (styled solid or the dark default).
    private var textColor: Color { ColorContrast.content(on: bubbleColor) }

    var body: some View {
        let bubble = Group {
            if let rich {
                rich
            } else {
                Text(text).multilineTextAlignment(.leading)
            }
        }
            .textStyle(.bodySm400)
            .foregroundStyle(textColor)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(bubbleColor,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))

        let arrow = TooltipArrow(edge: edge)
            .fill(bubbleColor)
            .frame(width: edge.isVertical ? 12 : 6, height: edge.isVertical ? 6 : 12)
            // Path coordinates don't auto-mirror — flip so leading/trailing
            // arrows keep pointing at the anchor under RTL (top/bottom arrows
            // are symmetric, so the flip is a no-op for them).
            .flipsForRightToLeftLayoutDirection(true)

        switch edge {
        case .top: VStack(spacing: -1) { bubble; arrow }
        case .bottom: VStack(spacing: -1) { arrow; bubble }
        case .leading: HStack(spacing: -1) { bubble; arrow }
        case .trailing: HStack(spacing: -1) { arrow; bubble }
        }
    }
}

/// Pushes the bubble just outside the chosen edge of the anchor, separated by
/// the small spacing token.
private struct TooltipPlacement: ViewModifier {
    let edge: TooltipEdge
    @Environment(\.layoutDirection) private var layoutDirection

    private var gap: CGFloat { Theme.SpacingKey.sm.value }
    /// `.offset(x:)` is absolute (doesn't auto-mirror) — flip the horizontal
    /// push-out under RTL so the bubble still moves away from the anchor.
    private var direction: CGFloat { layoutDirection == .rightToLeft ? -1 : 1 }

    func body(content: Content) -> some View {
        switch edge {
        case .top: content.offset(y: -gap).alignmentGuide(.top) { $0[.bottom] }
        case .bottom: content.offset(y: gap).alignmentGuide(.bottom) { $0[.top] }
        case .leading: content.offset(x: -gap * direction).alignmentGuide(.leading) { $0[.trailing] }
        case .trailing: content.offset(x: gap * direction).alignmentGuide(.trailing) { $0[.leading] }
        }
    }
}

/// Binding-driven tooltip presentation — gates its fade on `microAnimations`.
private struct BindingTooltip: ViewModifier {
    let text: String
    /// Rich slot content — replaces the plain text inside the bubble (D2).
    var rich: SlotContent? = nil
    @Binding var isPresented: Bool
    let edge: TooltipEdge
    let align: PopoverAlign
    let style: BadgeStyle?
    let color: SemanticColor?
    let maxWidth: CGFloat?
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge.alignment(align)) {
                if isPresented {
                    TooltipBubble(text: text, rich: rich, edge: edge, style: style, color: color, maxWidth: maxWidth)
                        .fixedSize(horizontal: maxWidth == nil, vertical: true)
                        .modifier(TooltipPlacement(edge: edge))
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(motion, value: isPresented)
    }
}

/// Wraps an anchor so a tap toggles its own tooltip — no external binding
/// needed. While shown (and unless opted out), a transparent tap-catcher sits
/// behind the bubble so tapping anywhere else dismisses it.
private struct SelfTooltip: ViewModifier {
    let text: String
    let edge: TooltipEdge
    let align: PopoverAlign
    let style: BadgeStyle?
    let color: SemanticColor?
    let maxWidth: CGFloat?
    let dismissOnOutsideTap: Bool
    /// Self-managed (uncontrolled) presentation state on the library-standard
    /// `ControllableState` (ADR-4); its projected binding feeds the
    /// binding-driven `.tooltip` below, so both entry points share one
    /// presentation path.
    @ControllableState private var shown = false

    func body(content: Content) -> some View {
        content
            .overlay { // Declared before the bubble's overlay so it stays behind it.
                if shown && dismissOnOutsideTap {
                    PopoverTapCatcher { shown = false }
                }
            }
            .tooltip(text, isPresented: $shown, edge: edge, align: align, style: style, color: color, maxWidth: maxWidth)
            .contentShape(Rectangle())
            .onTapGesture { shown.toggle() }
            .accessibilityHint(Text(text))
    }
}

public extension View {
    /// Binding-driven tooltip. `edge` chooses which side of the anchor it points
    /// from; `align` slides the bubble along that edge (HeroUI Popover `align`;
    /// `.center` keeps the historical placement); `style` recolors the bubble
    /// (nil keeps the dark default); `color` tints it with any semantic color
    /// and wins over `style` (daisyUI `tooltip-{color}`); `maxWidth` lets long
    /// text wrap.
    func tooltip(
        _ text: String,
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        style: BadgeStyle? = nil,
        color: SemanticColor? = nil,
        maxWidth: CGFloat? = nil
    ) -> some View {
        modifier(BindingTooltip(text: text, isPresented: isPresented, edge: edge, align: align, style: style, color: color, maxWidth: maxWidth))
    }

    /// Binding-driven tooltip with **rich content** (HeroUI/Ant Tooltip content
    /// node): the `content` slot replaces the plain text inside the same bubble
    /// chrome (fill, arrow, placement, motion). Slot content inherits the
    /// bubble's auto-contrast foreground and `bodySm400` ramp, so plain
    /// `Text`/`Image(systemName:)` children render correctly with zero
    /// configuration.
    ///
    ///     icon.tooltip(isPresented: $show, edge: .bottom) {
    ///         HStack { Image(systemName: "wifi"); Text("Free Wi-Fi") }
    ///     }
    func tooltip<C: View>(
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        style: BadgeStyle? = nil,
        color: SemanticColor? = nil,
        maxWidth: CGFloat? = nil,
        @ViewBuilder content: () -> C
    ) -> some View {
        modifier(BindingTooltip(text: "", rich: SlotContent(content), isPresented: isPresented,
                                edge: edge, align: align, style: style, color: color, maxWidth: maxWidth))
    }

    /// Self-managed tooltip: tap the anchor to toggle it (tap again to dismiss).
    /// No external state required — use for simple hint glyphs. While shown, a
    /// tap anywhere outside the bubble also dismisses it (HeroUI Popover
    /// `closeOnPress`); pass `dismissOnOutsideTap: false` to require tapping
    /// the anchor again.
    func tooltip(
        _ text: String,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        style: BadgeStyle? = nil,
        color: SemanticColor? = nil,
        maxWidth: CGFloat? = nil,
        dismissOnOutsideTap: Bool = true
    ) -> some View {
        modifier(SelfTooltip(text: text, edge: edge, align: align, style: style, color: color, maxWidth: maxWidth, dismissOnOutsideTap: dismissOnOutsideTap))
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    @Previewable @State var top = true
    @Previewable @State var trailing = true
    @Previewable @State var leading = true
    @Previewable @State var bottom = true
    PreviewMatrix("Tooltip") {
        PreviewCase("Top (default)") {
            Icon(systemName: "info.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                .tooltip("Helpful hint", isPresented: $top)
                .padding(.top, 56).padding(.bottom, 8)
                .frame(maxWidth: .infinity)
        }
        PreviewCase("Trailing · info") {
            Icon(systemName: "questionmark.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                .tooltip("On the trailing side", isPresented: $trailing, edge: .trailing, style: .info)
                .padding(.vertical, 16)
        }
        PreviewCase("Leading · warning · wraps") {
            Icon(systemName: "exclamationmark.triangle").size(.md).colorOverride(theme.foreground(.fgHero))
                .tooltip("A longer hint that wraps onto several lines", isPresented: $leading, edge: .leading, style: .warning, maxWidth: 140)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        PreviewCase("Bottom · primary tint") {
            Icon(systemName: "star.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                .tooltip("Primary-tinted tooltip", isPresented: $bottom, edge: .bottom, color: .primary)
                .padding(.bottom, 56).padding(.top, 8)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Rich content slot") {
    struct Demo: View {
        @State var plain = true
        @State var tinted = true
        var body: some View {
            VStack(spacing: 72) {
                // Custom content in the standard bubble chrome — inherits the
                // auto-contrast foreground and bodySm400 ramp.
                Icon(systemName: "wifi").size(.md)
                    .tooltip(isPresented: $plain, edge: .top) {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            Image(systemName: "wifi")
                            Text("Free Wi-Fi")
                            Badge("New").badgeStyle(.success).size(.small)
                        }
                    }
                // Rich content on a tinted bubble.
                Icon(systemName: "creditcard").size(.md)
                    .tooltip(isPresented: $tinted, edge: .bottom, color: .info, maxWidth: 180) {
                        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                            Text("Installments available").fontWeight(.semibold)
                            Text("Split the total into 3 payments at no extra cost.")
                        }
                    }
            }
            .padding(80)
        }
    }
    return Demo()
}

#Preview("RTL — arrows point at the anchor") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State var top = true
        @State var trailing = true
        @State var leading = true
        var body: some View {
            VStack(spacing: 64) {
                Icon(systemName: "info.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                    .tooltip("Helpful hint", isPresented: $top)
                HStack(spacing: 56) {
                    Icon(systemName: "questionmark.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                        .tooltip("On the trailing side", isPresented: $trailing, edge: .trailing, style: .info)
                    Icon(systemName: "exclamationmark.triangle").size(.md).colorOverride(theme.foreground(.fgHero))
                        .tooltip("On the leading side", isPresented: $leading, edge: .leading, style: .warning)
                }
            }
            .padding(80)
        }
    }
    return Demo().environment(\.layoutDirection, .rightToLeft)
}

#Preview("Align start / end") {
    struct Demo: View {
        @State var start = true
        @State var end = true
        var body: some View {
            VStack(spacing: 72) {
                // .start lines the bubble's leading edge up with the anchor's.
                ThemeButton("Align start") { start.toggle() }.variant(.outline)
                    .tooltip("Leading edges aligned", isPresented: $start, edge: .top, align: .start)
                // .end lines the trailing edges up instead.
                ThemeButton("Align end") { end.toggle() }.variant(.outline)
                    .tooltip("Trailing edges aligned", isPresented: $end, edge: .bottom, align: .end, style: .info)
                // Self-managed: tap the glyph to show; tap anywhere else to dismiss.
                Icon(systemName: "hand.tap").size(.md)
                    .tooltip("Tap outside to dismiss", edge: .trailing, align: .start)
            }
            .padding(80)
        }
    }
    return Demo()
}
