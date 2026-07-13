//
//  Confetti.swift
//  ThemeKit
//
//  A one-shot celebration confetti burst — themed pieces fall and fade from the
//  top. Token-bound (colours default to the brand palette). Honours Reduce Motion
//  (renders a static scatter instead of animating). Dependency-free.
//

import SwiftUI

/// A token-bound confetti burst. Drop it in an overlay, or use `.confetti(trigger:)`.
///
/// ```swift
/// ZStack {
///     ThanksView()
///     Confetti().pieceCount(60)
/// }
/// // or, replay on a value change:
/// content.confetti(trigger: submissionCount)
/// ```
public struct Confetti: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Appearance — mutated only through the modifiers below (R2).
    private var pieceCount = 40
    private var colorsOverride: [SemanticColor]?
    private var duration: Double = 2.4

    @State private var pieces: [ConfettiPiece] = []
    @State private var progress: CGFloat = 0

    public init() {}

    private var palette: [Color] {
        colorsOverride.map { $0.map { theme.resolve($0).base } } ?? [
            theme.resolve(.primary).base, theme.resolve(.purple).base, theme.resolve(.pink).base,
            theme.resolve(.orange).base, theme.resolve(.success).base, theme.resolve(.warning).base,
        ]
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.6)
                        .rotationEffect(.degrees(piece.spin * Double(fall(piece))))
                        .position(
                            x: geo.size.width * (piece.startX + piece.drift * fall(piece)),
                            y: -20 + (geo.size.height + 40) * fall(piece)
                        )
                        .opacity(opacity(piece))
                }
            }
            .onAppear { start(in: geo.size) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Per-piece 0…1 progress, staggered by its delay so they don't fall in lockstep.
    private func fall(_ piece: ConfettiPiece) -> CGFloat {
        max(0, min(1, (progress - piece.delay) / max(0.01, 1 - piece.delay)))
    }
    private func opacity(_ piece: ConfettiPiece) -> Double {
        let p = fall(piece)
        return p > 0.8 ? Double(max(0, (1 - p) / 0.2)) : 1
    }

    private func start(in size: CGSize) {
        guard pieces.isEmpty else { return }
        pieces = (0..<max(1, pieceCount)).map { _ in
            ConfettiPiece(
                startX: CGFloat.random(in: 0.05...0.95),
                drift: CGFloat.random(in: -0.25...0.25),
                color: palette.randomElement() ?? theme.resolve(.primary).base,
                spin: Double.random(in: 240...900) * (Bool.random() ? 1 : -1),
                delay: reduceMotion ? 0 : CGFloat.random(in: 0...0.25),
                size: CGFloat.random(in: 6...11)
            )
        }
        if reduceMotion {
            progress = 0.5   // a static mid-air scatter, no motion
        } else {
            withAnimation(.easeIn(duration: duration)) { progress = 1 }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Confetti {
    /// Number of confetti pieces (default 40).
    func pieceCount(_ count: Int) -> Self { copy { $0.pieceCount = max(1, count) } }
    /// Override the brand palette.
    func colors(_ colors: [SemanticColor]?) -> Self { copy { $0.colorsOverride = colors } }
    /// Fall duration in seconds (default 2.4).
    func duration(_ seconds: Double) -> Self { copy { $0.duration = max(0.2, seconds) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension View {
    /// Overlays a one-shot confetti burst keyed on `trigger` — change `trigger`
    /// (e.g. bump a counter) to replay the celebration.
    func confetti<T: Hashable>(trigger: T, count: Int = 40) -> some View {
        overlay { Confetti().pieceCount(count).id(trigger) }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let drift: CGFloat
    let color: Color
    let spin: Double
    let delay: CGFloat
    let size: CGFloat
}

// The burst is a one-shot, full-bleed animation — each matrix cell shows a
// representative fixed-height scene rather than the ignores-safe-area overlay.
#Preview {
    @Previewable @Environment(\.theme) var theme
    PreviewMatrix("Confetti") {
        PreviewCase("Celebration burst") {
            ZStack {
                theme.background(.bgBase)
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(theme.foreground(.fgHero))
                    Text("Thanks for your feedback!").textStyle(.headingSm)
                }
                Confetti().pieceCount(60)
            }
            .frame(height: 220)
        }
        PreviewCase("Custom palette, slower") {
            ZStack {
                theme.background(.bgBase)
                Text("Booking confirmed").textStyle(.headingSm)
                Confetti().pieceCount(40).colors([.purple, .pink, .turquoise]).duration(4)
            }
            .frame(height: 180)
        }
    }
}
