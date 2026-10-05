//
//  Shake.swift
//  ThemeKit
//  Created by İsa Mercan on 05.10.2026.
//
//  A field or a card that says "not like this": a short side-to-side shake when something the
//  user must fix is pointed at — a coupon the service turned down, an agreement left unticked.
//  Four beats, each 60% of the last (16 → 9.6 → 5.8 → 3.5pt), on the `nudge` spring, then a
//  `settle` back to rest; a selection tick with every beat. With Reduce Motion or
//  `microAnimations(false)` the view stays still and only the ticks play.
//
//    CouponField(...)
//        .shake(trigger: rejections)   // any Equatable that changes on each rejection
//

import SwiftUI

public extension View {
    /// Shakes the view each time `trigger` changes (not when it first appears).
    ///
    /// - Parameters:
    ///   - trigger: a value that changes once per shake — a counter is enough.
    ///   - amplitude: the first beat's reach, in points; 16 by default.
    func shake<Trigger: Equatable>(trigger: Trigger, amplitude: CGFloat = 16) -> some View {
        modifier(ShakeModifier(trigger: trigger, amplitude: amplitude))
    }
}

/// The shake's beats: where each one reaches, alternating sides, each `decay` of the last.
public enum ShakeBeats {
    public static func offsets(amplitude: CGFloat, beats: Int = 4, decay: CGFloat = 0.6) -> [CGFloat] {
        (0..<max(beats, 0)).map { index in
            amplitude * pow(decay, CGFloat(index)) * (index.isMultiple(of: 2) ? 1 : -1)
        }
    }
}

private struct ShakeModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let amplitude: CGFloat

    @State private var offset: CGFloat = 0
    @State private var run: Task<Void, Never>?
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Drawn moved, laid out in place: the shake doesn't push its neighbours.
            .offset(x: offset)
            .onChangeCompat(of: trigger) { shake() }
            .onDisappear { run?.cancel() }
    }

    private func shake() {
        run?.cancel()
        let moves = micro && !reduceMotion
        let beats = ShakeBeats.offsets(amplitude: amplitude)
        // One beat's time: the nudge spring has settled by about 1.4 periods.
        let beat = UInt64(MotionSpring.nudge.response * 1.1 * 1_000_000_000)
        run = Task { @MainActor in
            for reach in beats {
                guard !Task.isCancelled else { break }
                Haptics.selection()
                if moves { withAnimation(MotionSpring.nudge.animation) { offset = reach } }
                try? await Task.sleep(nanoseconds: beat)
            }
            if moves { withAnimation(MotionSpring.settle.animation) { offset = 0 } }
        }
    }
}
