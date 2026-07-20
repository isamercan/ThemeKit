//
//  Splitter.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Splitter** — two panes separated by a draggable
//  divider that resizes them. Horizontal (side-by-side) or vertical (stacked); the
//  split is clamped to a min/max fraction.
//
//      Splitter(.horizontal) { Sidebar() } second: { Detail() }
//      Splitter(.vertical, initialFraction: 0.35) { Map() } second: { List() }
//          .bounds(min: 0.2, max: 0.8)
//

import SwiftUI

public struct Splitter<First: View, Second: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    private let first: First
    private let second: Second
    // Appearance — mutated only through the modifiers below.
    private var axis: Axis
    private var minFraction: CGFloat = 0.15
    private var maxFraction: CGFloat = 0.85

    @State private var fraction: CGFloat
    @State private var dragAnchor: CGFloat?

    public init(
        _ axis: Axis = .horizontal,
        initialFraction: CGFloat = 0.5,
        @ViewBuilder first: () -> First,
        @ViewBuilder second: () -> Second
    ) {   // R1
        self.axis = axis
        self.first = first()
        self.second = second()
        self._fraction = State(initialValue: initialFraction)
    }

    private let handle: CGFloat = 12

    public var body: some View {
        GeometryReader { geo in
            let total = axis == .horizontal ? geo.size.width : geo.size.height
            let usable = max(1, total - handle)
            let firstMain = usable * fraction
            let secondMain = usable * (1 - fraction)
            let stack = axis == .horizontal
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))
            stack {
                pane(first, main: firstMain, geo: geo.size)
                divider(usable: usable)
                pane(second, main: secondMain, geo: geo.size)
            }
        }
    }

    private func pane(_ content: some View, main: CGFloat, geo: CGSize) -> some View {
        content
            .frame(width: axis == .horizontal ? max(0, main) : geo.width,
                   height: axis == .vertical ? max(0, main) : geo.height)
            .clipped()
    }

    private func divider(usable: CGFloat) -> some View {
        ZStack {
            theme.background(.bgBase)
            // Grip — a short capsule perpendicular to the drag axis.
            Capsule().fill(theme.text(.textTertiary).opacity(0.5))
                .frame(width: axis == .horizontal ? 3 : 28, height: axis == .horizontal ? 28 : 3)
            Rectangle().fill(theme.border(.borderPrimary))
                .frame(width: axis == .horizontal ? 1 : nil, height: axis == .vertical ? 1 : nil)
                .frame(maxWidth: axis == .vertical ? .infinity : nil, maxHeight: axis == .horizontal ? .infinity : nil)
        }
        .frame(width: axis == .horizontal ? handle : nil, height: axis == .vertical ? handle : nil)
        .frame(maxWidth: axis == .vertical ? .infinity : nil, maxHeight: axis == .horizontal ? .infinity : nil)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragAnchor == nil { dragAnchor = fraction }
                    let base = dragAnchor ?? fraction
                    // Gesture translations don't auto-mirror: in RTL the first
                    // pane sits on the RIGHT, so a leftward drag grows it —
                    // flip the horizontal delta's sign.
                    let raw = axis == .horizontal ? value.translation.width : value.translation.height
                    let delta = (axis == .horizontal && layoutDirection == .rightToLeft) ? -raw : raw
                    fraction = min(maxFraction, max(minFraction, base + delta / usable))
                }
                .onEnded { _ in dragAnchor = nil }
        )
        // The split is conveyed only by drag; make it VoiceOver-adjustable.
        .accessibilityElement()
        .accessibilityLabel(Text(String(themeKit: "Resize")))
        .accessibilityValue(Text(String(themeKit: "\(Int((fraction * 100).rounded())) percent")))
        .accessibilityAdjustableAction { direction in
            let increment: CGFloat = 0.05
            switch direction {
            case .increment: fraction = min(maxFraction, fraction + increment)
            case .decrement: fraction = max(minFraction, fraction - increment)
            @unknown default: break
            }
        }
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Splitter {
    /// Clamp the split fraction (Ant Panel `min` / `max`).
    func bounds(min: CGFloat, max: CGFloat) -> Self {
        copy { $0.minFraction = Swift.max(0, min); $0.maxFraction = Swift.min(1, max) }
    }

    /// Stack the panes vertically (Ant Splitter `layout="vertical"`) — the
    /// kit-standard axis vocabulary (cf. `SegmentedControl.vertical`) and the
    /// modifier twin of the `axis:` init argument; `false` restores the
    /// side-by-side layout.
    func vertical(_ on: Bool = true) -> Self { copy { $0.axis = on ? .vertical : .horizontal } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    PreviewMatrix("Splitter") {
        PreviewCase("Horizontal") {
            Splitter(.horizontal) {
                Text("Sidebar").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgElevatorPrimary))
            } second: {
                Text("Detail").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgWhite))
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        }
        // The `.vertical()` modifier twin of `Splitter(.vertical) { … }`.
        PreviewCase("Vertical") {
            Splitter {
                Text("Map").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgElevatorPrimary))
            } second: {
                Text("List").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgWhite))
            }
            .vertical()
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        }
    }
    .environment(\.theme, Theme.shared)
}

#Preview("RTL") {
    @Previewable @Environment(\.theme) var theme
    // Sidebar (first pane) sits on the RIGHT; dragging the divider left grows it.
    Splitter(.horizontal, initialFraction: 0.35) {
        Text("Sidebar").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgElevatorPrimary))
    } second: {
        Text("Detail").frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.background(.bgWhite))
    }
    .frame(height: 200)
    .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
    .padding()
    .environment(\.theme, Theme.shared)
    .environment(\.layoutDirection, .rightToLeft)
}
