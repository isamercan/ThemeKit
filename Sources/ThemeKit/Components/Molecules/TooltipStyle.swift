//
//  TooltipStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 17.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `.tooltip(…)`. The bubble — its
//  surface, the text's type style and colour, padding, corner and arrow —
//  lives in a `TooltipStyle` you set with `.tooltipStyle(_:)`, so a host design
//  system can draw its own tooltip while ThemeKit keeps the rest.
//
//      infoGlyph
//          .tooltip("Checked bags aren't included.", isPresented: $shown, edge: .bottom)
//          .tooltipStyle(HostTooltipCard())
//
//  ThemeKit keeps: the presentation (the binding or the self-managed toggle),
//  placement (edge, align, the gap to the anchor, the fixed-size bubble), the
//  fade and its motion gate, outside-tap dismissal, the self-managed form's
//  VoiceOver hint on the anchor, and the arrow's orientation under RTL (the
//  configuration's `arrowShape` arrives already turned).
//

import SwiftUI
// ColorContrast is an @_spi legibility helper in ThemeKitCore (not re-exported by
// ThemeKit's umbrella), so pull it in explicitly.
@_spi(ThemeKitInternal) import ThemeKitCore

/// The inputs a ``TooltipStyle`` renders: the tooltip's raw text and its
/// content, the placement and colour arguments passed to `.tooltip(…)`, the
/// arrow shape for this placement, the resolved motion flag and the dismiss
/// action.
///
/// `text` is the raw string and `content` carries no font and no colour, so a
/// style picks its own type style and text colour. Fields a style doesn't use
/// are simply ignored; new fields may be added in a minor release.
public struct TooltipStyleConfiguration {
    /// The tooltip's text, as passed to `.tooltip(_:…)`. Empty for the rich
    /// `.tooltip(isPresented:…) { }` form, whose content is in ``content``.
    public let text: String
    /// What the bubble shows: the rich form's slot, or ``text`` as a `Text`
    /// that wraps with leading alignment. It has no font and no colour of its
    /// own, so `.textStyle(_:)` and `.foregroundStyle(_:)` applied to it take
    /// effect (views inside a rich slot keep any font or colour they set).
    public let content: AnyView
    /// The side of the anchor the bubble sits on (`edge:`).
    public let edge: TooltipEdge
    /// Where along that side the bubble lines up (`align:`). ThemeKit already
    /// places the bubble; a style uses this only to move its arrow.
    public let align: PopoverAlign
    /// The wrapping width passed to `.tooltip(…, maxWidth:)`; `nil` when the
    /// bubble should size to its content. With a value, the bubble is offered
    /// the anchor's width, so a style gives its own frame a width (for example
    /// `.frame(width: maxWidth)`) rather than only a `maxWidth`.
    public let maxWidth: CGFloat?
    /// The tone shorthand passed to `.tooltip(…, style:)`; `nil` when unset.
    public let style: BadgeStyle?
    /// The semantic colour passed to `.tooltip(…, color:)`; `nil` when unset.
    /// It wins over ``style``: ``tint`` applies that rule.
    public let color: SemanticColor?
    /// The arrow the stock bubble draws for ``edge``, already turned for the
    /// current layout direction, so a `.leading` or `.trailing` arrow keeps
    /// pointing at the anchor under RTL. Fill or stroke it as it is; don't add
    /// `.flipsForRightToLeftLayoutDirection(_:)`. The stock bubble draws it
    /// 12 × 6 pt (6 × 12 pt for a side edge) and overlaps the bubble by 1 pt.
    public let arrowShape: TooltipArrowShape
    /// Whether the tooltip may animate. ThemeKit already fades the bubble in
    /// and out with this gate, so a style uses it only for motion of its own.
    /// Already resolved: `false` under `.microAnimations(false)` and under
    /// Reduce Motion, so a style never reads the motion settings itself.
    public let isMotionEnabled: Bool
    /// Hides the tooltip: sets the binding-driven form's `isPresented` to
    /// `false`, or closes the self-managed form. Every `.tooltip` form sets
    /// it today; it's optional so a later presentation the bubble can't close
    /// can leave it out. A style that draws a close button calls it and gives
    /// the button a VoiceOver label.
    public let dismiss: (() -> Void)?
}

public extension TooltipStyleConfiguration {
    /// The semantic colour the stock bubble is filled with: ``color`` when
    /// set, else ``style``'s hue, else `nil` (the stock bubble then uses the
    /// dark `bgTertiary` surface).
    var tint: SemanticColor? { color ?? style?.semantic }
}

/// A triangle whose apex points at the anchor for the given edge: the arrow
/// ThemeKit's tooltip bubble draws (and the popconfirm and popover cards),
/// public so a ``TooltipStyle`` can draw the same one.
///
/// The path runs base corner → apex → base corner and stays open along the
/// base: `fill` closes it, and `stroke` outlines only the two exposed sides,
/// which is what a bordered card's arrow needs.
///
/// Built with ``init(edge:)``, the path is laid out left to right. Under a
/// right-to-left layout, a `.leading` or `.trailing` arrow then needs
/// `.flipsForRightToLeftLayoutDirection(true)` to keep pointing at the anchor.
/// ``TooltipStyleConfiguration/arrowShape`` is already turned for the layout
/// direction, so a style can use it without the flip.
public struct TooltipArrowShape: Shape {
    /// The side of the anchor the bubble sits on; the apex points back at the anchor.
    public let edge: TooltipEdge
    /// Whether a side edge's apex is mirrored for a right-to-left layout.
    /// Set only by ThemeKit (the configuration's resolved shape); `.top` and
    /// `.bottom` arrows are symmetric, so it changes nothing for them.
    let isMirrored: Bool

    /// The arrow for `edge`, laid out left to right.
    public init(edge: TooltipEdge) {
        self.init(edge: edge, isMirrored: false)
    }

    /// The arrow for `edge`, turned for `layoutDirection`.
    init(edge: TooltipEdge, layoutDirection: LayoutDirection) {
        self.init(edge: edge, isMirrored: layoutDirection == .rightToLeft)
    }

    private init(edge: TooltipEdge, isMirrored: Bool) {
        self.edge = edge
        self.isMirrored = isMirrored
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        switch drawnEdge {
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

    /// The path is never mirrored by SwiftUI itself, on any deployment target.
    /// (The stock `.mirrors` default applies only to apps deploying to iOS 17 /
    /// macOS 14 or later; `.fixed` keeps ``init(edge:)`` left to right and the
    /// configuration's turned shape turned exactly once, everywhere.)
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    public var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }

    /// The edge whose left-to-right path is drawn: a mirrored side arrow
    /// takes the opposite side's path, which is its left-to-right mirror image.
    private var drawnEdge: TooltipEdge {
        guard isMirrored else { return edge }
        switch edge {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top, .bottom: return edge
        }
    }
}

/// Draws a tooltip's bubble. Implement `makeBody` to paint the
/// configuration's content on a surface, with an arrow on the side that faces
/// the anchor. Set one with `.tooltipStyle(_:)`; the default is
/// ``DefaultTooltipStyle``.
///
/// The style draws; ThemeKit keeps the behaviour. It shows and hides what the
/// style returns (the binding, or the self-managed tap toggle), places it
/// outside the anchor's chosen edge at its ideal size, fades it with the
/// motion gate, dismisses the self-managed form on an outside tap, and gives
/// that form's anchor its VoiceOver hint. The configuration's `dismiss`
/// closes the tooltip from a button the style draws.
///
/// The style is read where `.tooltip(…)` is applied, so set it on that call's
/// result (`anchor.tooltip(…).tooltipStyle(…)`) or on any ancestor; a style set
/// on the anchor before the `.tooltip(…)` call doesn't reach it. It also
/// restyles the tooltips ThemeKit composes: `InputLabel.infoTooltip(_:)` (and
/// the labels of the fields built on it).
///
/// ```swift
/// struct CardTooltip: TooltipStyle {
///     func makeBody(configuration: TooltipStyleConfiguration) -> some View {
///         CardTooltipBody(configuration: configuration)
///     }
/// }
///
/// private struct CardTooltipBody: View {
///     let configuration: TooltipStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         let surface = theme.background(.bgWhite)
///         let card = HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
///             configuration.content
///                 .textStyle(.bodySm400)
///                 .foregroundStyle(theme.text(.textPrimary))
///             if let dismiss = configuration.dismiss {
///                 Button(action: dismiss) { Image(systemName: "xmark") }
///                     .buttonStyle(.plain)
///                     .foregroundStyle(theme.text(.textTertiary))
///                     .accessibilityLabel(Text("Close"))
///             }
///         }
///         .padding(Theme.SpacingKey.md.value)
///         .background(surface, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
///
///         let vertical = configuration.edge == .top || configuration.edge == .bottom
///         let arrow = configuration.arrowShape
///             .fill(surface)
///             .frame(width: vertical ? 16 : 8, height: vertical ? 8 : 16)
///
///         switch configuration.edge {
///         case .top: VStack(spacing: -1) { card; arrow }
///         case .bottom: VStack(spacing: -1) { arrow; card }
///         case .leading: HStack(spacing: -1) { card; arrow }
///         case .trailing: HStack(spacing: -1) { arrow; card }
///         }
///     }
/// }
/// ```
public protocol TooltipStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: TooltipStyleConfiguration) -> Body
}

/// The stock tooltip bubble — exactly the look `.tooltip(…)` draws with no
/// style set: the content in `bodySm400`, wrapped at `maxWidth`, in a
/// contrasting text colour on an `xs`-radius bubble with `sm` / `xs` padding,
/// filled with the ``TooltipStyleConfiguration/tint``'s solid shade (or the
/// dark `bgTertiary` surface), and a 12 × 6 pt arrow in the same fill on the
/// anchor side. It draws no close button. Reads the active `\.theme`, so an
/// injected theme re-skins it too.
public struct DefaultTooltipStyle: TooltipStyle, Sendable {
    public init() {}
    public func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DefaultTooltipChrome(configuration: configuration)
    }
}

private struct DefaultTooltipChrome: View {
    let configuration: TooltipStyleConfiguration
    @Environment(\.theme) private var theme

    // `color` wins over the `style` shorthand (``tint``); neither keeps the
    // dark default. Same fill as the built-in bubble.
    private var bubbleColor: Color {
        configuration.tint.map { theme.resolve($0).solid } ?? theme.background(.bgTertiary)
    }

    // Mirrors the built-in `TooltipBubble` modifier for modifier, so
    // `.tooltipStyle(.default)` renders the same pixels.
    var body: some View {
        let fill = bubbleColor
        let bubble = configuration.content
            .textStyle(.bodySm400)
            .foregroundStyle(ColorContrast.content(on: fill))
            .frame(maxWidth: configuration.maxWidth, alignment: .leading)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(fill,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))

        let edge = configuration.edge
        // Already turned for the layout direction, so no RTL flip here.
        let arrow = configuration.arrowShape
            .fill(fill)
            .frame(width: edge.isVertical ? 12 : 6, height: edge.isVertical ? 6 : 12)

        switch edge {
        case .top: VStack(spacing: -1) { bubble; arrow }
        case .bottom: VStack(spacing: -1) { arrow; bubble }
        case .leading: HStack(spacing: -1) { bubble; arrow }
        case .trailing: HStack(spacing: -1) { arrow; bubble }
        }
    }
}

public extension TooltipStyle where Self == DefaultTooltipStyle {
    /// The stock tooltip bubble (today's `.tooltip(…)` look).
    static var `default`: DefaultTooltipStyle { DefaultTooltipStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyTooltipStyle: TooltipStyle {
    /// `true` only for the environment key's stock default below. `.tooltip`
    /// checks it: while the environment still carries the default it draws the
    /// built-in bubble, unchanged; any style set with `.tooltipStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (TooltipStyleConfiguration) -> AnyView
    init<S: TooltipStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: TooltipStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct TooltipStyleKey: EnvironmentKey {
    static let defaultValue = AnyTooltipStyle(DefaultTooltipStyle(), isDefault: true)
}

extension EnvironmentValues {
    var tooltipStyle: AnyTooltipStyle {
        get { self[TooltipStyleKey.self] }
        set { self[TooltipStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``TooltipStyle`` for the tooltips attached in this view and its
    /// descendants. Apply it after `.tooltip(…)` (or on an ancestor).
    func tooltipStyle<S: TooltipStyle>(_ style: sending S) -> some View {
        environment(\.tooltipStyle, AnyTooltipStyle(style))
    }
}
