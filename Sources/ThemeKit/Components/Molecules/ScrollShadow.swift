//
//  ScrollShadow.swift
//  ThemeKit
//  Created by İsa Mercan on 09.07.2026.
//
//  Molecule. HeroUI Native's **ScrollShadow** — wraps a caller-provided scroll
//  view and fades its clipped edges with token-fed gradient scrims that react to
//  the scroll position, hinting that more content lies beyond the fold.
//
//  The content is *the caller's* `ScrollView`/`List`; ScrollShadow never creates
//  its own. Because SwiftUI cannot introspect the child's scroll axis, set it
//  explicitly with `.axis(.horizontal)` when wrapping a horizontal scroller.
//
//  Scroll detection: on iOS 18 / macOS 15+ the component observes the wrapped
//  scroll view with `onScrollGeometryChange`, so `.auto` shows the start scrim
//  once the content is scrolled away from its start (offset > 0) and the end
//  scrim while more content remains (offset + viewport < content size). For a
//  horizontal axis the physical offset is normalized to logical-start
//  coordinates under right-to-left layout, so "start" always means the leading
//  edge — the visual right in RTL.
//
//  On the package's minimum OSes (iOS 17 / macOS 14) that observation API does not
//  exist, so `.auto` degrades to always-on scrims at both edges (`.both`
//  behavior); the explicit `.start` / `.end` / `.both` / `.none` modes are
//  position-independent and behave identically on every supported OS.
//

import SwiftUI

/// Which edge scrims a ``ScrollShadow`` shows. Start/end vocabulary (rather than
/// top/bottom/left/right) keeps the API RTL-safe: for a vertical axis *start* is
/// the top edge and *end* the bottom; for a horizontal axis *start* is the
/// leading edge and *end* the trailing edge, mirroring automatically under
/// right-to-left layouts. (HeroUI's separate `isEnabled` flag collapses into
/// `.none` here — disabling is just another visibility.)
public enum ScrollShadowVisibility: String, CaseIterable, Sendable {
    /// Scrims follow the scroll position (iOS 18 / macOS 15+); on older OSes
    /// this degrades to `.both`. The default.
    case auto
    /// Only the start (top / leading) scrim, always on.
    case start
    /// Only the end (bottom / trailing) scrim, always on.
    case end
    /// Both scrims, always on.
    case both
    /// No scrims — the effect is disabled.
    case none
}

/// Fades the clipped edges of a wrapped scroll view with theme-fed gradient
/// scrims — ThemeKit's port of HeroUI Native's `ScrollShadow`.
///
/// ```swift
/// ScrollShadow {
///     ScrollView { articleBody }
/// }
///
/// ScrollShadow {
///     ScrollView(.horizontal) { chipRow }
/// }
/// .axis(.horizontal)
/// .length(.lg)
/// .fadeColor(.bgWhite)
/// ```
///
/// The scrims are purely decorative: they never intercept touches and are
/// hidden from assistive technologies. Their opacity animates with the theme's
/// fast motion token when a threshold crosses, and snaps instantly when the
/// system Reduce Motion setting (or `.microAnimations(false)`) is active.
public struct ScrollShadow<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content: Content

    // Appearance — mutated only through the modifiers below (R2).
    private var axis: Axis = .vertical
    private var visibility: ScrollShadowVisibility = .auto
    private var lengthKey: Theme.SpacingKey = .xl          // 40pt ≈ HeroUI's 50px default
    private var fadeKey: Theme.BackgroundColorKey = .bgBase

    // Scroll metrics (iOS 18 / macOS 15+ only) — local UI state, nothing more.
    @State private var isScrolledFromStart = false
    @State private var hasTrailingOverflow = false

    /// Wraps `content` — the caller's `ScrollView`/`List` — with edge scrims.
    public init(@ViewBuilder content: () -> Content) {   // R1: content only
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            observed.modifier(scrims(
                start: showsStart(auto: isScrolledFromStart),
                end: showsEnd(auto: hasTrailingOverflow)))
        } else {
            // No scroll observation below iOS 18 / macOS 15: `.auto` → `.both`.
            content.modifier(scrims(
                start: showsStart(auto: true),
                end: showsEnd(auto: true)))
        }
    }

    // MARK: Scroll observation (iOS 18 / macOS 15+)

    @available(iOS 18.0, macOS 15.0, *)
    private var observed: some View {
        let axis = axis                         // capture the values, not the view struct
        let layoutDirection = layoutDirection
        return content.onScrollGeometryChange(for: ScrollShadowEdgeState.self) { geometry in
            ScrollShadowEdgeState(geometry: geometry, axis: axis, layoutDirection: layoutDirection)
        } action: { _, state in
            isScrolledFromStart = state.isScrolledFromStart
            hasTrailingOverflow = state.hasTrailingOverflow
        }
    }

    // MARK: Visibility resolution

    private func showsStart(auto: Bool) -> Bool {
        switch visibility {
        case .auto: return auto
        case .start, .both: return true
        case .end, .none: return false
        }
    }

    private func showsEnd(auto: Bool) -> Bool {
        switch visibility {
        case .auto: return auto
        case .end, .both: return true
        case .start, .none: return false
        }
    }

    // MARK: Scrim chrome

    private func scrims(start: Bool, end: Bool) -> ScrollShadowScrims {
        ScrollShadowScrims(
            axis: axis,
            showsStart: start,
            showsEnd: end,
            length: theme.spacing(lengthKey),
            fill: theme.background(fadeKey),
            motion: MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion))
    }
}

// MARK: - Modifiers (R2 copy-on-write · single mutation point)

public extension ScrollShadow {
    /// The scroll axis of the wrapped content (default `.vertical`). Explicit
    /// because SwiftUI cannot introspect the child scroll view's axis.
    func axis(_ axis: Axis) -> Self { copy { $0.axis = axis } }
    /// Which edge scrims to show (default `.auto`). See ``ScrollShadowVisibility``.
    func visibility(_ v: ScrollShadowVisibility) -> Self { copy { $0.visibility = v } }
    /// Scrim depth along the scroll axis, as a spacing token (default `.xl`).
    func length(_ key: Theme.SpacingKey) -> Self { copy { $0.lengthKey = key } }
    /// The surface the scrims fade from (default `.bgBase`) — match it to the
    /// background the scroll view sits on so the fade reads as depth, not tint.
    func fadeColor(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.fadeKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Private chrome

/// Overlays the two edge scrims. Alignments and gradient anchors use
/// leading/trailing `UnitPoint`s only, so horizontal scrims mirror under RTL.
private struct ScrollShadowScrims: ViewModifier {
    let axis: Axis
    let showsStart: Bool
    let showsEnd: Bool
    let length: CGFloat
    let fill: Color
    let motion: Animation?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: axis == .vertical ? .top : .leading) {
                scrim(visible: showsStart,
                      from: axis == .vertical ? .top : .leading,
                      to: axis == .vertical ? .bottom : .trailing)
            }
            .overlay(alignment: axis == .vertical ? .bottom : .trailing) {
                scrim(visible: showsEnd,
                      from: axis == .vertical ? .bottom : .trailing,
                      to: axis == .vertical ? .top : .leading)
            }
    }

    private func scrim(visible: Bool, from: UnitPoint, to: UnitPoint) -> some View {
        LinearGradient(colors: [fill, fill.opacity(0)], startPoint: from, endPoint: to)
            .frame(width: axis == .horizontal ? length : nil,
                   height: axis == .vertical ? length : nil)
            .opacity(visible ? 1 : 0)
            .animation(motion, value: visible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Scroll metrics (iOS 18 / macOS 15+)

@available(iOS 18.0, macOS 15.0, *)
private struct ScrollShadowEdgeState: Equatable {
    var isScrolledFromStart: Bool
    var hasTrailingOverflow: Bool

    init(geometry: ScrollGeometry, axis: Axis, layoutDirection: LayoutDirection) {
        let epsilon: CGFloat = 1   // sub-point jitter shouldn't flicker the scrims
        let offset: CGFloat
        let viewport: CGFloat
        let contentLength: CGFloat
        switch axis {
        case .vertical:
            offset = geometry.contentOffset.y + geometry.contentInsets.top
            viewport = geometry.containerSize.height
            contentLength = geometry.contentSize.height
        case .horizontal:
            viewport = geometry.containerSize.width
            contentLength = geometry.contentSize.width
            if layoutDirection == .rightToLeft {
                // `contentOffset` is physical: a right-to-left horizontal
                // scroller *rests* at its maximum x (content starts at the
                // visual right), so normalize to logical-start coordinates —
                // distance scrolled away from the leading (right) edge.
                offset = contentLength + geometry.contentInsets.leading
                    - viewport - geometry.contentOffset.x
            } else {
                offset = geometry.contentOffset.x + geometry.contentInsets.leading
            }
        }
        isScrolledFromStart = offset > epsilon
        hasTrailingOverflow = offset + viewport < contentLength - epsilon
    }
}

// MARK: - Previews

#Preview("Vertical · visibility modes") {
    HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) {
        ForEach(ScrollShadowVisibility.allCases, id: \.self) { mode in
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Text(mode.rawValue)
                    .textStyle(.labelSm600)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                ScrollShadow {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                            ForEach(1..<21) { line in
                                Text("Line \(line)")
                                    .textStyle(.bodySm400)
                                    .foregroundStyle(Theme.shared.text(.textPrimary))
                            }
                        }
                        .padding(Theme.SpacingKey.sm.value)
                    }
                }
                .visibility(mode)
                .length(.lg)
                .frame(height: 180)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding()
    .background(Theme.shared.background(.bgBase))
}

#Preview("Horizontal · chip row") {
    VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
        Text("Filters")
            .textStyle(.headingSm)
            .foregroundStyle(Theme.shared.text(.textPrimary))
        ScrollShadow {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ForEach(["Nonstop", "1 stop", "Morning", "Evening",
                             "Refundable", "Baggage included", "Window seat"], id: \.self) { title in
                        Chip(title, isSelected: .constant(false))
                    }
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
            }
        }
        .axis(.horizontal)
        .length(.md)
    }
    .padding(.vertical)
    .background(Theme.shared.background(.bgBase))
}

#Preview("Themed fade · dark") {
    ScrollShadow {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                ForEach(1..<26) { line in
                    Text("Terms & conditions, clause \(line)")
                        .textStyle(.bodyBase400)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                }
            }
            .padding(Theme.SpacingKey.md.value)
        }
    }
    .visibility(.both)
    .fadeColor(.bgSecondaryLight)
    .frame(height: 260)
    .background(Theme.shared.background(.bgSecondaryLight))
    .padding()
    .preferredColorScheme(.dark)
}
