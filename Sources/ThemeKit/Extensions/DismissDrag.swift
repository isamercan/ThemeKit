//
//  DismissDrag.swift
//  ThemeKit
//
//  The library's one dismiss gesture (ADR-7), extracted from the three
//  hand-rolled copies in Dialog, the toast rows and Drawer: drag along an
//  edge, the surface offsets with the finger, an optional `progress` binding
//  reports 0…1 so the presenter can fade its scrim (or the row its opacity),
//  releasing past the threshold calls `onDismiss`, anything less springs back.
//  Gated by `microAnimations` + Reduce Motion: the gesture always works with
//  motion off — only the spring-back animation drops (it snaps instantly).
//  Dialog's tuned feel is the reference implementation.
//
//  Internal first (per ADR-7); promote to public only if a third-party
//  presenter needs it later.
//

import SwiftUI

/// How far a dismiss drag must have travelled, on release, to dismiss.
enum DismissDragThreshold {
    /// A fraction of the surface's measured size along the drag axis
    /// (Dialog / Drawer: a third of the card height / panel width).
    case fraction(CGFloat)
    /// An absolute distance in points (toast rows: 60pt).
    case points(CGFloat)
}

extension View {
    /// Attaches the standard dismiss drag toward `edge`.
    ///
    /// - Parameters:
    ///   - edge: the edge the surface is dismissed toward (`.bottom` for a
    ///     dialog card, the anchored edge for a toast, the panel's own edge
    ///     for a drawer). Drag math is in screen coordinates, matching the
    ///     presenters' existing behavior (no RTL flip — a leading drawer
    ///     always dismisses toward the left edge it slides from).
    ///   - threshold: release distance that dismisses (default: a third of the
    ///     measured size along the drag axis).
    ///   - isEnabled: `false` parks the gesture (`.subviews` mask) so inner
    ///     scroll views and controls keep working — Dialog's
    ///     `swipeToDismiss`/loading gating.
    ///   - minimumDragDistance: points before the gesture engages (default 8,
    ///     the Dialog/toast tuning; Drawer passes 10, its historical value).
    ///   - progressSpan: points of travel over which `progress` goes 0 → 1;
    ///     `nil` (default) uses the measured size along the drag axis. Toast
    ///     rows pass 120 (their historical fade distance).
    ///   - progress: reports dismissal progress 0…1 — feed it to
    ///     `Backdrop(fade: 1 - progress)` or an `.opacity(1 - progress)`.
    ///   - onDismiss: called when a release passes `threshold`.
    func dismissDrag(
        edge: Edge,
        threshold: DismissDragThreshold = .fraction(1 / 3),
        isEnabled: Bool = true,
        minimumDragDistance: CGFloat = 8,
        progressSpan: CGFloat? = nil,
        progress: Binding<Double>? = nil,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(DismissDragModifier(
            edge: edge, threshold: threshold, isEnabled: isEnabled,
            minimumDragDistance: minimumDragDistance, progressSpan: progressSpan,
            progress: progress, onDismiss: onDismiss
        ))
    }
}

private struct DismissDragModifier: ViewModifier {
    let edge: Edge
    let threshold: DismissDragThreshold
    let isEnabled: Bool
    let minimumDragDistance: CGFloat
    let progressSpan: CGFloat?
    let progress: Binding<Double>?
    let onDismiss: () -> Void

    /// Distance dragged toward the dismiss edge (≥ 0). Direct manipulation —
    /// it always follows the finger; only the spring-back is motion-gated.
    @State private var offset: CGFloat = 0
    /// Measured size of the surface along the drag axis (Dialog's card-height
    /// measurement, generalized).
    @State private var axisSize: CGFloat = 0

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionEnabled: Bool { micro && !reduceMotion }
    private var isHorizontal: Bool { edge == .leading || edge == .trailing }
    /// +1 when the dismiss direction runs along the positive axis (bottom/trailing).
    private var direction: CGFloat { (edge == .bottom || edge == .trailing) ? 1 : -1 }

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                let size = isHorizontal ? geo.size.width : geo.size.height
                Color.clear
                    .onAppear { axisSize = size }
                    .onChange(of: size) { axisSize = $1 }
            })
            .offset(x: isHorizontal ? offset * direction : 0,
                    y: isHorizontal ? 0 : offset * direction)
            .gesture(drag, including: isEnabled ? .all : .subviews)
    }

    /// 0…1 dismissal progress over `progressSpan` (measured size by default).
    private func currentProgress(at offset: CGFloat) -> Double {
        let span = progressSpan ?? axisSize
        guard span > 0, offset > 0 else { return 0 }
        return min(Double(offset / span), 1)
    }

    /// Release distance that dismisses; `nil` while unmeasured (never dismiss).
    private var dismissDistance: CGFloat? {
        switch threshold {
        case .points(let points): return points
        case .fraction(let fraction): return axisSize > 0 ? axisSize * fraction : nil
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: minimumDragDistance)
            .onChanged { value in
                let along = isHorizontal ? value.translation.width : value.translation.height
                offset = max(0, along * direction)
                progress?.wrappedValue = currentProgress(at: offset)
            }
            .onEnded { _ in
                if let dismissDistance, offset > dismissDistance {
                    onDismiss()
                } else {
                    withAnimation(motionEnabled ? Motion.fast.spring : nil) {
                        offset = 0
                        progress?.wrappedValue = 0
                    }
                }
            }
    }
}
