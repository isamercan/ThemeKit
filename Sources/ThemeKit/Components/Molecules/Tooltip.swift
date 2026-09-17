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
//  an outside tap. (Ant Tooltip / HeroUI Popover parity.) A `TooltipStyle`
//  set with `.tooltipStyle(_:)` draws the bubble instead (TooltipStyle.swift);
//  presentation, placement, motion, dismissal and accessibility stay here.
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
    private var bubbleColor: Color { color.map { theme.resolve($0).solid } ?? style.map { theme.resolve($0.semantic).solid } ?? theme.background(.bgTertiary) }
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

        let arrow = TooltipArrowShape(edge: edge)
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

    // Unconditional: a `switch` (or `if`) here is conditional content, and SwiftUI drops
    // alignment guides set inside it — the bubble then sat on its anchor instead of beside it.
    func body(content: Content) -> some View {
        let edge = edge
        return content
            .offset(x: edge == .leading ? -gap * direction : edge == .trailing ? gap * direction : 0,
                    y: edge == .top ? -gap : edge == .bottom ? gap : 0)
            .alignmentGuide(.top) { edge == .top ? $0[.bottom] : $0[.top] }
            .alignmentGuide(.bottom) { edge == .bottom ? $0[.top] : $0[.bottom] }
            .alignmentGuide(.leading) { edge == .leading ? $0[.trailing] : $0[.leading] }
            .alignmentGuide(.trailing) { edge == .trailing ? $0[.leading] : $0[.trailing] }
    }
}

/// Binding-driven tooltip presentation — gates its fade on `microAnimations`.
/// Both render paths share it: the built-in bubble, or the environment
/// `TooltipStyle`'s body, gets the same size, placement, fade and z-order.
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
    @Environment(\.tooltipStyle) private var tooltipStyle
    @Environment(\.layoutDirection) private var layoutDirection
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge.alignment(align)) {
                // The placement sits on a stack, not on the `if`: guides set on conditional
                // content are dropped, which put the bubble over its anchor.
                ZStack {
                    if isPresented {
                        bubble
                            .fixedSize(horizontal: maxWidth == nil, vertical: true)
                            .transition(.opacity)
                    }
                }
                .modifier(TooltipPlacement(edge: edge))
                .zIndex(1)
            }
            .animation(motion, value: isPresented)
    }

    /// The built-in bubble while the environment carries the stock default
    /// (ADR-0009 D3); otherwise whatever the set style draws.
    @ViewBuilder private var bubble: some View {
        if tooltipStyle.isDefault {
            TooltipBubble(text: text, rich: rich, edge: edge, style: style, color: color, maxWidth: maxWidth)
        } else {
            tooltipStyle.makeBody(configuration: configuration)
        }
    }

    private var configuration: TooltipStyleConfiguration {
        let presented = $isPresented
        return TooltipStyleConfiguration(
            text: text,
            // No font and no colour of its own, so the style's type and
            // colour apply; the plain text wraps as the built-in bubble's does.
            content: rich.map { AnyView($0) } ?? AnyView(Text(text).multilineTextAlignment(.leading)),
            edge: edge,
            align: align,
            maxWidth: maxWidth,
            style: style,
            color: color,
            arrowShape: TooltipArrowShape(edge: edge, layoutDirection: layoutDirection),
            isMotionEnabled: motion != nil,
            // The self-managed form presents through this modifier with its
            // own state's binding, so this closes both forms.
            dismiss: { presented.wrappedValue = false }
        )
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
    /// text wrap. A ``TooltipStyle`` set after this call (`.tooltipStyle(_:)`)
    /// draws the bubble; the arguments reach it through its configuration.
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
    /// configuration. Under a ``TooltipStyle``, the slot arrives as the
    /// configuration's `content` and takes the style's type and colour instead.
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
    /// the anchor again. A ``TooltipStyle`` draws this bubble too, and its
    /// configuration's `dismiss` closes it.
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
    struct Demo: View {
        @Environment(\.theme) var theme
        @State var top = true
        @State var trailing = true
        @State var leading = true
        @State var bottom = true
        var body: some View {
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
    }
    return Demo()
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
