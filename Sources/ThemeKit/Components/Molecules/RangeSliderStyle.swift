//
//  RangeSliderStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `RangeSlider` — the two-thumb
//  slider a filter panel puts over a price, a duration or a departure window.
//  The whole block — the track, the span between the thumbs, the two knobs, the
//  readout at each end and the labelled ticks under it — lives in a
//  `RangeSliderStyle` you set with `.rangeSliderStyle(_:)`, so a host design
//  system can draw its own slider while `RangeSlider` keeps the behaviour.
//
//      RangeSlider(lowerValue: $low, upperValue: $high, in: 0...1000)
//          .step(50)
//          .valueLabel { "\(Int($0)) $" }
//          .rangeSliderStyle(HostRangeSliderStyle())
//
//  **Who owns what.** The style only draws. Everything that decides a value
//  stays in `RangeSlider`:
//
//  - the gesture — one drag that picks the thumb nearest to the touch and keeps
//    it for the rest of the drag, and the `onChangeEnd` commit on release;
//  - the geometry — the touch's distance along the track turned into a value —
//    together with the step, the clamping to the bounds and the order of the
//    pair (the lower thumb never crosses the upper one);
//  - the linked inputs' parsing, focus and validate-on-blur commit;
//  - the RTL mirroring: the gesture flips its own maths, and the fractions the
//    style is handed are measured from the track's *leading* edge, so they read
//    the same in both directions (``RangeSliderStyleConfiguration/offsetDirection``
//    covers the one thing SwiftUI won't mirror for you);
//  - the accessibility: each thumb stays its own VoiceOver-adjustable element,
//    labelled and speaking the same formatted value as the readout. ThemeKit
//    lays those two elements over whatever the style draws, so a styled slider
//    adjusts exactly like the stock one and a style writes no accessibility
//    modifier of its own.
//
//  So the configuration carries what it takes to *draw* a slider — the two
//  values, where they sit along the track, the formatted readouts, the marks,
//  the axes and the state — and nothing a style could use to re-implement any
//  of the above.
//
//  **The drag surface.** ThemeKit reads the frame of the style's body and
//  attaches its gesture around it, so a style never has to guess ThemeKit's
//  hit-testing: a touch lands on the value whose knob is drawn under it. The
//  surface is the whole body rather than the track alone, because only the
//  style knows where inside its block the track sits — so a tap on a readout
//  moves the nearest thumb, the way a tap anywhere on the stock track does.
//
//  Scope: `RangeSlider` itself, wherever it is placed, including the one
//  ThemeKit composes inside `PriceHistogram`. `Slider` (one thumb) and
//  `ColorSlider` are components of their own and are not drawn through this
//  style.
//

import SwiftUI

/// One of a `RangeSlider`'s two thumbs.
public enum RangeSliderThumb: Hashable, Sendable {
    /// The thumb at the low end of the selected range.
    case lower
    /// The thumb at the high end of the selected range.
    case upper
}

/// One labelled tick on a `RangeSlider`'s scale (``RangeSlider/marks(_:)``),
/// ready to place: the value it stands for, where it sits along the track, and
/// the text under it.
public struct RangeSliderStyleMark: Identifiable {
    /// The value the tick marks, as the caller passed it.
    public let value: Double
    /// How far along the track the tick sits — 0 at ``RangeSliderStyleConfiguration/bounds``'
    /// lower bound, 1 at its upper bound. Read it the way
    /// ``RangeSliderStyleConfiguration/lowerFraction`` is read.
    public let fraction: Double
    /// The tick's caption: the caller's ``RangeSlider/valueLabel(_:)`` applied
    /// to ``value``, else the value rounded to a whole number. It arrives as a
    /// string, not a styled `Text`, so a style picks its own type.
    public let label: String

    public var id: Double { value }
}

/// The inputs a ``RangeSliderStyle`` renders: the pair of values and where they
/// sit along the track, the formatted readouts and marks, the axes the
/// modifiers set, and the state the component is in.
///
/// Nothing here writes a value — the gesture, the step, the clamping, the RTL
/// maths and the accessibility stay in `RangeSlider` (see the file's header).
/// Strings arrive raw, not as pre-styled `Text`, so a style picks its own type
/// styles and colours. Fields a style doesn't use are simply ignored; new
/// fields may be added in a minor release.
public struct RangeSliderStyleConfiguration {
    /// The low end of the selected range — the caller's binding, read.
    public let lowerValue: Double
    /// The high end of the selected range — the caller's binding, read.
    public let upperValue: Double
    /// The range the slider spans, as passed to
    /// ``RangeSlider/init(lowerValue:upperValue:in:)``.
    public let bounds: ClosedRange<Double>
    /// How far along the track the lower thumb sits: 0 at ``bounds``' lower
    /// bound, 1 at its upper bound.
    ///
    /// The track runs from its **leading** edge on the horizontal axis — which
    /// SwiftUI mirrors for you wherever you anchor with `.leading` — and from
    /// the **bottom** up on the vertical one. `.offset(x:)` and `.position(x:)`
    /// are physical rather than semantic, so multiply horizontal moves by
    /// ``offsetDirection``; `.offset(y:)` grows downward, so negate vertical
    /// ones.
    ///
    /// Positions are measured over the style's own length along the axis less
    /// ``thumbSize`` — half a knob of room at each end — which is the
    /// convention ThemeKit's drag uses too, so a knob drawn here sits exactly
    /// where a touch at that value lands. A binding whose value sits outside
    /// ``bounds`` lands outside 0…1, exactly as the stock track draws it.
    public let lowerFraction: Double
    /// Where the upper thumb sits; see ``lowerFraction``.
    public let upperFraction: Double
    /// The low end's readout — the caller's ``RangeSlider/valueLabel(_:)``
    /// applied to ``lowerValue``; `nil` when no format was set, which is when
    /// the stock block draws no readout row at all.
    public let lowerLabel: String?
    /// The high end's readout; see ``lowerLabel``.
    public let upperLabel: String?
    /// The labelled ticks the caller asked for (``RangeSlider/marks(_:)``), in
    /// the order they were given; empty when none were. The stock block draws
    /// them under the track on the horizontal axis only — a style may draw them
    /// on either.
    public let marks: [RangeSliderStyleMark]
    /// How the slider is laid out (``RangeSlider/axis(_:height:)``):
    /// `.horizontal` by default.
    public let axis: Axis
    /// The tint the caller asked for (``RangeSlider/accent(_:)``); `nil` keeps
    /// the hero tokens. It is a semantic colour, so resolve it from the
    /// environment theme (`theme.resolve(_:)`), never from `Theme.shared`.
    public let accent: SemanticColor?
    /// Whether the slider is enabled — the environment's `.disabled(_:)`. The
    /// stock block fades the track to 60%; a style draws whatever disabled look
    /// it wants. The gesture and the adjustable actions are gated on it either
    /// way, so a style that draws no disabled look still can't be dragged.
    public let isEnabled: Bool
    /// The snap increment (``RangeSlider/step(_:)``, 1 by default), for a style
    /// that draws a tick per step or rounds a readout of its own. ThemeKit
    /// already snaps every value it writes.
    public let step: Double
    /// Which thumb the current drag is moving, `nil` while no drag is running —
    /// for a style that lifts, grows or tints the knob under the finger. The
    /// stock knob scales to 90% (gated on the motion settings).
    public let draggingThumb: RangeSliderThumb?
    /// The linked min/max fields (``RangeSlider/inputs(_:titles:)``), ready to
    /// place and fully wired — their keyboard, focus, parsing, snapping and
    /// commit-on-blur are ThemeKit's; `nil` when the caller didn't ask for
    /// them. The stock block draws them above the track *instead of* the
    /// readout row.
    public let inputs: AnyView?
    /// The room ThemeKit's geometry keeps for a knob at each end of the track
    /// (24 pt, the stock knob's diameter): positions run over the style's
    /// length along the axis less this, starting half of it in from the leading
    /// edge. Lay a knob of a different size out around the same centre and the
    /// touch still lands on the value under it.
    public let thumbSize: CGFloat
    /// The track's length on the vertical axis, as
    /// ``RangeSlider/axis(_:height:)`` set it; `nil` on the horizontal axis,
    /// where the track takes the width it is offered. ThemeKit maps a vertical
    /// drag over this length from the **bottom** of the style's body, so draw a
    /// vertical track that tall and keep it at the bottom of the block.
    public let trackLength: CGFloat?
    /// The sign for hand-mirrored horizontal moves: `1` under a left-to-right
    /// layout, `-1` under a right-to-left one. Multiply an `.offset(x:)` by it,
    /// and mirror a `.position(x:)` inside its row while it is negative —
    /// SwiftUI mirrors alignment and stacks for you, but not absolute moves. It
    /// is `1` on the vertical axis, which doesn't mirror.
    public let offsetDirection: CGFloat
}

/// Draws a `RangeSlider`. Implement `makeBody` to lay the configuration out —
/// the track, the span between the two fractions, a knob at each of them, the
/// readouts and the marks — and `RangeSlider` keeps every decision about the
/// values. Set one with `.rangeSliderStyle(_:)`; the default is
/// ``DefaultRangeSliderStyle``.
///
/// **The style draws the whole block:** the track's colour, thickness and
/// corner, the span between the thumbs, both knobs (their size, fill, ring and
/// shadow), the readout at each end, the labelled ticks, the spacing between
/// the rows, the disabled look and where the wired
/// ``RangeSliderStyleConfiguration/inputs`` go. ThemeKit wraps nothing around a
/// custom body but its own drag surface and the two adjustable accessibility
/// elements, neither of which paints or changes the layout.
///
/// **`RangeSlider` keeps the behaviour:** the drag and which thumb it moves,
/// the geometry and the step, the clamping and the ordered pair, the
/// `onChangeEnd` commit, the linked inputs' parsing and focus, the RTL
/// mirroring, and each thumb as its own VoiceOver-adjustable element.
///
/// **What reaches the style.** Every slider the component can hold: with or
/// without readouts, with or without marks, with the linked inputs instead of
/// the readouts, tinted or on the hero tokens, horizontal or vertical, enabled
/// or disabled, and mid-drag on either thumb.
///
/// **Where to set it.** On the `RangeSlider` itself or on any ancestor. One
/// style at the root reskins every slider at once, including the one ThemeKit
/// composes inside `PriceHistogram`.
///
/// ```swift
/// struct HostRangeSliderStyle: RangeSliderStyle {
///     func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
///         HostRangeSliderBody(configuration: configuration)
///     }
/// }
///
/// private struct HostRangeSliderBody: View {
///     let configuration: RangeSliderStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         VStack(spacing: Theme.SpacingKey.sm.value) {
///             GeometryReader { geo in
///                 let usable = max(geo.size.width - configuration.thumbSize, 1)
///                 let lower = CGFloat(configuration.lowerFraction) * usable
///                 let upper = CGFloat(configuration.upperFraction) * usable
///                 ZStack(alignment: .leading) {
///                     Capsule().fill(theme.border(.borderSecondary)).frame(height: 2)
///                     Capsule().fill(theme.background(.bgHero))
///                         .frame(width: max(upper - lower, 0), height: 2)
///                         .offset(x: configuration.offsetDirection * (lower + configuration.thumbSize / 2))
///                     knob.offset(x: configuration.offsetDirection * lower)
///                     knob.offset(x: configuration.offsetDirection * upper)
///                 }
///                 .frame(height: configuration.thumbSize)
///             }
///             .frame(height: configuration.thumbSize)
///
///             HStack {
///                 Text(configuration.lowerLabel ?? "")
///                 Spacer()
///                 Text(configuration.upperLabel ?? "")
///             }
///             .textStyle(.labelSm600)
///             .foregroundStyle(theme.text(.textSecondary))
///         }
///     }
///
///     private var knob: some View {
///         Circle().fill(theme.background(.bgHero))
///             .frame(width: configuration.thumbSize, height: configuration.thumbSize)
///     }
/// }
/// ```
public protocol RangeSliderStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: RangeSliderStyleConfiguration) -> Body
}

/// The stock slider — exactly what `RangeSlider` draws with no style set: the
/// readout row (or the linked inputs) over a 4 pt `borderPrimary` capsule, the
/// selected span filled in the accent's solid shade, a 24 pt white knob ringed
/// in the same shade at each end, and the labelled ticks under it. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct DefaultRangeSliderStyle: RangeSliderStyle, Sendable {
    public init() {}
    public func makeBody(configuration: RangeSliderStyleConfiguration) -> some View {
        DefaultRangeSliderChrome(configuration: configuration)
    }
}

/// Mirrors `RangeSlider`'s built-in body from the configuration.
/// `RangeSliderStyleTests` renders both and compares the pixels, so the two
/// can't drift apart unnoticed.
private struct DefaultRangeSliderChrome: View {
    let configuration: RangeSliderStyleConfiguration
    @Environment(\.theme) private var theme

    private var thumbSize: CGFloat { RangeSliderMetrics.thumbSize }
    private var dir: CGFloat { configuration.offsetDirection }

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            readout

            if configuration.axis == .vertical { verticalTrack } else { horizontalTrack }

            if configuration.axis == .horizontal, !configuration.marks.isEmpty {
                GeometryReader { geo in
                    marksRow(usable: max(geo.size.width - thumbSize, 1))
                }
                .frame(height: RangeSliderMetrics.marksRowHeight)
            }
        }
    }

    // MARK: Readout

    @ViewBuilder
    private var readout: some View {
        if let inputs = configuration.inputs {
            inputs
        } else if let lower = configuration.lowerLabel, let upper = configuration.upperLabel {
            if configuration.axis == .vertical {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(lower)
                    Text(verbatim: "–")
                    Text(upper)
                }
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
            } else {
                HStack {
                    Text(lower)
                    Spacer()
                    Text(upper)
                }
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
            }
        }
    }

    // MARK: Track

    private var horizontalTrack: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumbSize, 1)
            let lowerX = CGFloat(configuration.lowerFraction) * usable
            let upperX = CGFloat(configuration.upperFraction) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.border(.borderPrimary))
                    .frame(height: RangeSliderMetrics.trackHeight)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(upperX - lowerX, 0), height: RangeSliderMetrics.trackHeight)
                    .offset(x: dir * (lowerX + thumbSize / 2))

                knob(.lower).offset(x: dir * lowerX)
                knob(.upper).offset(x: dir * upperX)
            }
            .frame(height: thumbSize)
        }
        .frame(height: thumbSize)
        .opacity(configuration.isEnabled ? 1 : RangeSliderMetrics.disabledOpacity)
    }

    private var verticalTrack: some View {
        GeometryReader { geo in
            let usable = max(geo.size.height - thumbSize, 1)
            let lowerY = CGFloat(configuration.lowerFraction) * usable
            let upperY = CGFloat(configuration.upperFraction) * usable

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(theme.border(.borderPrimary))
                    .frame(width: RangeSliderMetrics.trackHeight)
                Capsule()
                    .fill(fillColor)
                    .frame(width: RangeSliderMetrics.trackHeight, height: max(upperY - lowerY, 0))
                    .offset(y: -(lowerY + thumbSize / 2))

                knob(.lower).offset(y: -lowerY)
                knob(.upper).offset(y: -upperY)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: thumbSize, height: configuration.trackLength ?? RangeSliderMetrics.verticalHeight)
        .opacity(configuration.isEnabled ? 1 : RangeSliderMetrics.disabledOpacity)
    }

    private func knob(_ thumb: RangeSliderThumb) -> some View {
        Circle()
            .fill(theme.background(.bgWhite))
            .overlay(Circle().strokeBorder(thumbRingColor, lineWidth: 2))
            .frame(width: thumbSize, height: thumbSize)
            .themeShadow(.soft)
            // Press feedback while dragging — gated on microAnimations + Reduce Motion.
            .microPressScale(configuration.draggingThumb == thumb, scale: RangeSliderMetrics.pressScale)
    }

    // MARK: Marks

    private func marksRow(usable: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(configuration.marks) { mark in
                let ltrX = thumbSize / 2 + CGFloat(mark.fraction) * usable
                // `.position(x:)` doesn't auto-mirror: flip within the row width.
                let centerX = dir < 0 ? (usable + thumbSize) - ltrX : ltrX
                VStack(spacing: RangeSliderMetrics.markLabelSpacing) {
                    Capsule()
                        .fill(theme.border(.borderPrimary))
                        .frame(width: 1, height: RangeSliderMetrics.markTickHeight)
                    Text(mark.label)
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textTertiary))
                        .fixedSize()
                }
                .position(x: centerX, y: RangeSliderMetrics.markCenterY)
            }
        }
    }

    // MARK: Colors

    private var fillColor: Color {
        RangeSliderMetrics.fillColor(theme: theme, accent: configuration.accent, isEnabled: configuration.isEnabled)
    }

    private var thumbRingColor: Color {
        RangeSliderMetrics.thumbRingColor(theme: theme, accent: configuration.accent, isEnabled: configuration.isEnabled)
    }
}

/// The stock slider's fixed geometry and shades, shared by `RangeSlider`'s
/// built-in body and ``DefaultRangeSliderStyle`` so the two can't drift apart.
enum RangeSliderMetrics {
    /// The knob's diameter, and the room the geometry keeps for it at each end
    /// of the track.
    static let thumbSize: CGFloat = 24
    /// The track's thickness.
    static let trackHeight: CGFloat = 4
    /// Extra tappable slop around the stock track so tap-to-set is easy to hit.
    static let hitSlop: CGFloat = 8
    /// HeroUI-style press feedback: the active thumb scales down while dragging.
    static let pressScale: CGFloat = 0.9
    /// The stock vertical track's height when the caller sets none.
    static let verticalHeight: CGFloat = 160
    /// How far the stock block fades while it is disabled.
    static let disabledOpacity: Double = 0.6
    /// The marks row's height, and where a tick's stack is centred in it.
    static let marksRowHeight: CGFloat = 22
    static let markCenterY: CGFloat = 11
    /// A tick's line, and the gap under it.
    static let markTickHeight: CGFloat = 5
    static let markLabelSpacing: CGFloat = 2

    /// Track-fill shade — the accent's solid shade when set, else the hero token.
    @MainActor
    static func fillColor(theme: Theme, accent: SemanticColor?, isEnabled: Bool) -> Color {
        guard isEnabled else { return theme.background(.bgSecondaryLight) }
        return accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero)
    }

    /// Thumb-ring shade — the accent's solid shade when set, else the hero border.
    @MainActor
    static func thumbRingColor(theme: Theme, accent: SemanticColor?, isEnabled: Bool) -> Color {
        guard isEnabled else { return theme.border(.borderPrimary) }
        return accent.map { theme.resolve($0).solid } ?? theme.border(.borderHero)
    }
}

public extension RangeSliderStyle where Self == DefaultRangeSliderStyle {
    /// The stock slider (today's `RangeSlider` look).
    static var `default`: DefaultRangeSliderStyle { DefaultRangeSliderStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyRangeSliderStyle: RangeSliderStyle {
    /// `true` only for the environment key's stock default below. `RangeSlider`
    /// checks it: while the environment still carries the default it draws its
    /// own body, unchanged; any style set with `.rangeSliderStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (RangeSliderStyleConfiguration) -> AnyView
    init<S: RangeSliderStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: RangeSliderStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct RangeSliderStyleKey: EnvironmentKey {
    static let defaultValue = AnyRangeSliderStyle(DefaultRangeSliderStyle(), isDefault: true)
}

extension EnvironmentValues {
    var rangeSliderStyle: AnyRangeSliderStyle {
        get { self[RangeSliderStyleKey.self] }
        set { self[RangeSliderStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``RangeSliderStyle`` for the `RangeSlider`s in this view and its
    /// descendants.
    func rangeSliderStyle<S: RangeSliderStyle>(_ style: sending S) -> some View {
        environment(\.rangeSliderStyle, AnyRangeSliderStyle(style))
    }
}
