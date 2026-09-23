//
//  SegmentedControlStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `SegmentedControl` — the enclosed
//  single-select pill whose active option is a sliding thumb. The whole control
//  — the track's fill, corner and padding, each option's type, glyph and
//  padding, the thumb (or the absence of one), the hairlines between options
//  and the disabled fade — lives in a `SegmentedControlStyle` you set with
//  `.segmentedControlStyle(_:)`, so a host design system can draw its own
//  two-option pill while `SegmentedControl` keeps the behaviour.
//
//      SegmentedControl(["One way", "Round trip"], selection: $trip)
//          .segmentedControlStyle(HostSegmentedControlStyle())
//
//  `SegmentedControl` keeps: the selection binding and the disabled gate (both
//  inside ``SegmentedControlStyleConfiguration/select``), the animation the
//  selection changes under, the geometry namespace a sliding thumb needs, and
//  the control's accessibility — one toggle element carrying the identifier
//  namespace and the selected option as its value. A style draws each option as
//  a button of its own and marks the chosen one `.isSelected`, exactly as the
//  built-in pill does.
//
//  Scope: `SegmentedControl` itself, wherever it is placed, including the ones
//  ThemeKit composes — `LanguageSwitcher`'s `.inline` mode and ThemeKitTravel's
//  `CabinClassSelector`. `RadioButtonGroup` and `SegmentedTabBar` are components
//  of their own and are not drawn through this style.
//

import SwiftUI

/// One option a ``SegmentedControlStyle`` draws — a `SegmentItem` as the
/// control resolved it.
///
/// Exactly one of ``title`` and ``content`` carries the option's label, and an
/// option may be an icon alone; see ``isIconOnly``. The title arrives raw, not
/// as a pre-styled `Text`, and the glyph arrives as an SF Symbol *name* rather
/// than a view, so a style can set it in its own type ramp and icon font.
public struct SegmentedControlStyleItem {
    /// The option's label (`SegmentItem(_:systemImage:)`); `nil` for an
    /// icon-only option and for one built from a ``content`` slot.
    public let title: String?
    /// The option's SF Symbol name, for a leading glyph or an icon-only
    /// option; `nil` when unset. The stock option draws it at 13 pt semibold.
    public let systemImage: String?
    /// The option's custom label (`SegmentItem(isEnabled:tooltip:content:)`),
    /// exactly as written and carrying no font or colour of its own; `nil` when
    /// the option is a title and/or a glyph. When it is set it *replaces* both.
    public let content: AnyView?
    /// Whether this option can be chosen (`SegmentItem(isEnabled:)`). The
    /// control's own `.disabled(_:)` is separate — see
    /// ``SegmentedControlStyleConfiguration/isEnabled``.
    public let isEnabled: Bool
    /// The option's pointer tooltip (`SegmentItem(tooltip:)`); `nil` when
    /// unset. The stock option hands it to `.help(_:)`.
    public let tooltip: String?

    /// `true` when the option is a bare glyph — no title and no ``content``.
    /// The stock option pads an icon-only segment by `sm` instead of `md`.
    public var isIconOnly: Bool { title == nil && content == nil && systemImage != nil }

    /// What VoiceOver should call this option: its ``title``, else its
    /// ``tooltip``, else nothing. It is the word the control speaks as its
    /// value while the option is the selected one.
    public var accessibilityLabel: String { title ?? tooltip ?? "" }
}

/// The inputs a ``SegmentedControlStyle`` renders: the control's options, which
/// one is selected, the closure that selects another, the axes the modifiers
/// set, and the geometry namespace a sliding thumb needs.
///
/// Strings arrive raw and slots unpainted, so a style picks its own type styles
/// and colours. Fields a style doesn't use are simply ignored; new fields may be
/// added in a minor release.
public struct SegmentedControlStyleConfiguration {
    /// The control's options in order, as the caller passed them.
    public let items: [SegmentedControlStyleItem]
    /// The index of the selected option — the caller's binding, read. It can
    /// sit outside ``items`` (the stock pill then draws no thumb), so index
    /// into `items` through `items.indices.contains(_:)`.
    public let selection: Int
    /// Selects the option at `index`: exactly what the stock option's button
    /// runs, the animation included, writing through the caller's binding.
    ///
    /// It keeps the control's gate: a call is ignored when `index` is outside
    /// ``items``, when that option is disabled, or while the control itself is
    /// (``isEnabled`` is `false`) — the guard the stock pill applies by
    /// disabling the button — so a style's own button without a `.disabled(_:)`
    /// of its own can't choose an option the control wouldn't.
    ///
    /// It runs on the main actor, so call it from inside a control's action
    /// closure (`Button { configuration.select(index) }`) rather than handing
    /// the closure over as an action value.
    public let select: @MainActor (Int) -> Void
    /// The height axis (`.size(_:)`), for a style to map onto its own metrics.
    /// The stock pill uses it as each option's vertical padding: 4 / 8 / 16 pt
    /// for small / medium / large.
    public let size: SegmentedSize
    /// The corner axis (`.shape(_:)`). The stock track is a `field`-radius
    /// rounded rectangle, or a capsule for `.round`.
    public let shape: SegmentedShape
    /// How the caller asked for the active option to be drawn
    /// (`.selectionStyle(_:)` / `.tinted(_:)`): the raised white `.thumb`, the
    /// bordered `.outline` pill, or the thumbless `.tinted` track. A style owns
    /// its own selected look and may ignore this.
    public let selectionStyle: SegmentedSelectionStyle
    /// `.fullWidth(_:)` as it was set — whether each option takes an equal
    /// share of the offered width. A style stretches its options with
    /// `.frame(maxWidth: .infinity)` while it is `true`, and lets them hug
    /// their content while it is `false`.
    public let fullWidth: Bool
    /// `.dividers(_:)` as it was set — whether the caller asked for a hairline
    /// between adjacent options. A style draws its own separator (or none); the
    /// stock pill draws a 1 pt `bgWhite` rule and drops the gap between options.
    public let showsDividers: Bool
    /// The resolved tint for the `.tinted` / `.outline` selection styles:
    /// the explicit `.accent(_:)` / `.tinted(_:)` colour, else the subtree
    /// ``ComponentDefaults`` accent, else `.primary`. It is a semantic colour,
    /// so resolve it from the environment theme (`theme.resolve(_:)`), never
    /// from `Theme.shared`.
    public let tint: SemanticColor
    /// Whether the control is enabled — the environment's `.disabled(_:)`. The
    /// stock pill halves its opacity while it is `false`; a style draws whatever
    /// disabled look it wants. ``select`` is gated on it either way.
    public let isEnabled: Bool
    /// How the options are stacked (`.vertical(_:)`): `.horizontal` by default.
    public let axis: Axis
    /// The geometry namespace of this control's sliding thumb. Pair it with
    /// ``selectionID`` in `matchedGeometryEffect(id:in:)` on the shape you draw
    /// only behind the selected option, and the thumb slides from option to
    /// option under ``animation``. Derive further ids from ``selectionID`` (for
    /// example `"\(configuration.selectionID).stroke"`) to slide more than one.
    public let selectionNamespace: Namespace.ID
    /// The geometry id of this control's sliding thumb; see ``selectionNamespace``.
    public let selectionID: String
    /// The animation the control writes the selection with, already resolved
    /// (`nil` under `.microAnimations(false)` or Reduce Motion), so a style
    /// never reads the motion settings itself. ``select`` already runs under it;
    /// it is here for a style that animates something of its own.
    public let animation: Animation?

    /// `true` while nothing (explicit or provider) re-tints the control.
    /// Internal: it exists so ``DefaultSegmentedControlStyle`` can paint exactly
    /// what the built-in path paints (whose `.outline` border keeps the
    /// historical hero chroma until someone re-tints it). Custom styles use
    /// ``tint``.
    let usesStockTint: Bool
}

/// Draws a `SegmentedControl`. Implement `makeBody` to lay the configuration's
/// options out — each one a button that calls
/// ``SegmentedControlStyleConfiguration/select`` — and to paint the track and
/// the selected option. Set one with `.segmentedControlStyle(_:)`; the default
/// is ``DefaultSegmentedControlStyle``.
///
/// **The style draws the whole control:** the track's fill, corner and padding,
/// the gap between options, each option's type, glyph, colour and padding, the
/// hairlines, the disabled look and **the thumb** — on this path the control
/// draws neither its raised card nor its outline pill. Draw your own behind the
/// selected option and give it
/// `matchedGeometryEffect(id: configuration.selectionID, in: configuration.selectionNamespace)`
/// to make it slide. ThemeKit wraps nothing around a custom body but the
/// control's animation and its accessibility element.
///
/// **`SegmentedControl` keeps the behaviour:** the caller's binding and the
/// disabled gate (both inside ``SegmentedControlStyleConfiguration/select``),
/// the animation the selection changes under, the thumb's geometry namespace,
/// and the control's accessibility — one toggle element carrying the
/// `.a11yID(_:)` namespace and the selected option's label as its value. A
/// style's own option buttons carry the rest: give each the option's
/// ``SegmentedControlStyleItem/accessibilityLabel`` and add `.isSelected` to the
/// chosen one, the way the built-in pill does.
///
/// **What reaches the style.** Every control the component can hold: titles,
/// titles with a leading glyph, icon-only options and fully custom ones, any of
/// the three selection styles, a round or default corner, full-width or
/// content-hugging, horizontal or vertical, with or without hairlines, disabled
/// options inside an enabled control, and a disabled control.
///
/// **Where to set it.** On the `SegmentedControl` itself or on any ancestor.
/// One style at the root reskins every pill at once, including the ones ThemeKit
/// composes (`LanguageSwitcher`'s `.inline` mode, `CabinClassSelector`).
///
/// ```swift
/// struct HostSegmentedControlStyle: SegmentedControlStyle {
///     func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
///         HostSegmentedControlBody(configuration: configuration)
///     }
/// }
///
/// private struct HostSegmentedControlBody: View {
///     let configuration: SegmentedControlStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         HStack(spacing: 0) {
///             ForEach(Array(configuration.items.enumerated()), id: \.offset) { index, item in
///                 let isSelected = index == configuration.selection
///                 Button { configuration.select(index) } label: {
///                     Text(item.title ?? "")
///                         .textStyle(isSelected ? .labelBase700 : .labelBase600)
///                         .foregroundStyle(isSelected ? theme.text(.textPrimary) : theme.text(.textSecondary))
///                         .frame(maxWidth: .infinity)
///                         .padding(.vertical, Theme.SpacingKey.sm.value)
///                         .background {
///                             if isSelected {
///                                 Capsule().fill(theme.background(.bgWhite)).themeShadow(.soft)
///                                     .matchedGeometryEffect(id: configuration.selectionID,
///                                                            in: configuration.selectionNamespace)
///                             }
///                         }
///                         .contentShape(Rectangle())
///                 }
///                 .buttonStyle(.plain)
///                 .disabled(!item.isEnabled)
///                 .accessibilityLabel(item.accessibilityLabel)
///                 .accessibilityAddTraits(isSelected ? .isSelected : [])
///             }
///         }
///         .padding(4)
///         .background(theme.resolve(configuration.tint).soft, in: Capsule())
///         .opacity(configuration.isEnabled ? 1 : 0.5)
///     }
/// }
/// ```
public protocol SegmentedControlStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SegmentedControlStyleConfiguration) -> Body
}

/// The stock pill — exactly what `SegmentedControl` draws with no style set: the
/// options on a neutral (or, for `.tinted`, softly washed) track, each one a
/// plain button with the size's vertical padding, the active one carrying the
/// raised white thumb, the bordered outline pill or nothing at all, and the
/// whole control halved while it is disabled. Reads the active `\.theme`, so an
/// injected theme re-skins it too.
public struct DefaultSegmentedControlStyle: SegmentedControlStyle, Sendable {
    public init() {}
    public func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
        DefaultSegmentedControlChrome(configuration: configuration)
    }
}

/// Mirrors `SegmentedControl`'s built-in body from the configuration.
/// `SegmentedControlStyleTests` renders both and compares the pixels, so the two
/// can't drift apart unnoticed.
private struct DefaultSegmentedControlChrome: View {
    let configuration: SegmentedControlStyleConfiguration
    @Environment(\.theme) private var theme
    /// The stock pill tracks the pointer itself, so the configuration carries
    /// no hover state: a custom style does its own `.onHover`.
    @State private var hovered: Int?

    var body: some View {
        segments
            .padding(configuration.selectionStyle == .tinted ? 0 : SegmentedControlMetrics.trackPadding)
            .background(trackFill, in: configuration.shape.trackShape)
            .opacity(configuration.isEnabled ? 1 : 0.5)
    }

    @ViewBuilder private var segments: some View {
        let spacing = configuration.showsDividers ? 0 : SegmentedControlMetrics.segmentSpacing
        if configuration.axis == .vertical {
            VStack(spacing: spacing) { segmentRows }
        } else {
            HStack(spacing: spacing) { segmentRows }
        }
    }

    @ViewBuilder private var segmentRows: some View {
        ForEach(Array(configuration.items.enumerated()), id: \.offset) { index, item in
            segment(index, item)
            if configuration.showsDividers && index < configuration.items.count - 1 { divider }
        }
    }

    /// A hairline between adjacent segments (the design-system icon toggle).
    @ViewBuilder private var divider: some View {
        if configuration.axis == .vertical {
            Rectangle().fill(theme.background(.bgWhite)).frame(height: 1).padding(.horizontal, 6)
        } else {
            Rectangle().fill(theme.background(.bgWhite)).frame(width: 1).padding(.vertical, 6)
        }
    }

    private func segment(_ index: Int, _ item: SegmentedControlStyleItem) -> some View {
        let isActive = index == configuration.selection
        return Button {
            configuration.select(index)
        } label: {
            label(item, isActive: isActive)
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
                .padding(.vertical, configuration.size.verticalPadding)
                .padding(.horizontal, item.isIconOnly ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value)
                .background { hoverFill(index: index, isActive: isActive, enabled: item.isEnabled) }
                .background { selectionFill(isActive: isActive) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!configuration.isEnabled || !item.isEnabled)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .onHover { hovering in hovered = hovering ? index : (hovered == index ? nil : hovered) }
        .help(item.tooltip ?? "")
    }

    @ViewBuilder private func label(_ item: SegmentedControlStyleItem, isActive: Bool) -> some View {
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
            let thumbShape = configuration.shape.thumbShape
            switch configuration.selectionStyle {
            case .thumb:
                thumbShape.fill(theme.background(.bgWhite)).themeShadow(.soft)
                    .matchedGeometryEffect(id: configuration.selectionID, in: configuration.selectionNamespace)
            case .outline:
                // Stock hue keeps the historical hero-border chroma exactly;
                // an explicit/provider accent re-tints the pill + stroke.
                thumbShape.fill(theme.resolve(configuration.tint).soft)
                    .overlay(thumbShape.stroke(configuration.usesStockTint
                                               ? theme.border(.borderHero)
                                               : theme.resolve(configuration.tint).border,
                                               lineWidth: 2))
                    .matchedGeometryEffect(id: configuration.selectionID, in: configuration.selectionNamespace)
            case .tinted:
                EmptyView()   // no thumb — the soft track + hero foreground carry selection
            }
        }
    }

    @ViewBuilder private func hoverFill(index: Int, isActive: Bool, enabled: Bool) -> some View {
        if hovered == index, !isActive, enabled, configuration.isEnabled {
            configuration.shape.thumbShape.fill(theme.text(.textPrimary).opacity(0.06))
        }
    }

    /// The track fill — the tint's soft wash for `.tinted`, else the neutral base.
    private var trackFill: Color {
        configuration.selectionStyle == .tinted
            ? theme.resolve(configuration.tint).soft
            : theme.background(.bgBase)
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        guard isActive else { return theme.text(.textSecondary) }
        // The tinted style follows its base color's accent; others use the hero.
        return configuration.selectionStyle == .tinted
            ? theme.resolve(configuration.tint).accent
            : theme.text(.textHero)
    }
}

// MARK: - Shared geometry (both chrome paths)

/// The stock pill's fixed geometry, shared by `SegmentedControl`'s built-in body
/// and ``DefaultSegmentedControlStyle`` so the two can't drift apart.
enum SegmentedControlMetrics {
    /// Inset between the track's edge and the options (none for `.tinted`).
    static let trackPadding: CGFloat = 4
    /// Gap between adjacent options (none when hairlines are drawn).
    static let segmentSpacing: CGFloat = 4
    /// The geometry id the sliding thumb is matched on.
    static let selectionID = "pill"
}

extension SegmentedShape {
    /// The track's outline at this corner style.
    var trackShape: ThemeAnyShape {
        self == .round
            ? ThemeAnyShape(Capsule(style: .continuous))
            : ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }

    /// The thumb's outline at this corner style — a touch tighter than the track.
    var thumbShape: ThemeAnyShape {
        self == .round
            ? ThemeAnyShape(Capsule(style: .continuous))
            : ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }
}

public extension SegmentedControlStyle where Self == DefaultSegmentedControlStyle {
    /// The stock pill (today's `SegmentedControl` look).
    static var `default`: DefaultSegmentedControlStyle { DefaultSegmentedControlStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySegmentedControlStyle: SegmentedControlStyle {
    /// `true` only for the environment key's stock default below.
    /// `SegmentedControl` checks it: while the environment still carries the
    /// default it draws its own body, unchanged; any style set with
    /// `.segmentedControlStyle(_:)` — including `.default` — is unmarked and
    /// goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (SegmentedControlStyleConfiguration) -> AnyView
    init<S: SegmentedControlStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SegmentedControlStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SegmentedControlStyleKey: EnvironmentKey {
    static let defaultValue = AnySegmentedControlStyle(DefaultSegmentedControlStyle(), isDefault: true)
}

extension EnvironmentValues {
    var segmentedControlStyle: AnySegmentedControlStyle {
        get { self[SegmentedControlStyleKey.self] }
        set { self[SegmentedControlStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SegmentedControlStyle`` for the `SegmentedControl`s in this
    /// view and its descendants. The style draws the whole control.
    func segmentedControlStyle<S: SegmentedControlStyle>(_ style: sending S) -> some View {
        environment(\.segmentedControlStyle, AnySegmentedControlStyle(style))
    }
}
