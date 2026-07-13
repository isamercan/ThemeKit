//
//  BorderBeam.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A premium animated border-beam: a bright comet travels at CONSTANT speed along
//  the rounded-rectangle edge (arc-length-parametrised via `trimmedPath`, so it
//  doesn't speed up at corners), leaving a smoothly-fading tail, a neon glow halo
//  and a white-hot head spark — over a faint static outline. Driven by
//  `TimelineView(.animation)` for buttery 120fps. Apply with `.borderBeam()`.
//  (magicui "Border Beam", levelled up.)
//

import SwiftUI

public extension View {
    /// A comet that orbits the rounded-rectangle border with a glowing trail.
    /// - Parameters:
    ///   - cornerRadius: corner radius of the border path.
    ///   - lineWidth: beam thickness (Ant `lineWidth`).
    ///   - duration: seconds for one full lap (Ant `duration`).
    ///   - beamLength: comet length as a fraction of the perimeter (0…1) (Ant `size`).
    ///   - outset: how far the beam sits outside the container edge; `0` clips to the edge (Ant `outset`).
    ///   - reverse: orbit counter-clockwise (Ant `reverse`).
    ///   - glow: draw the soft neon halo behind the beam.
    ///   - colors: beam colors (head→tail). Defaults to the theme accent + turquoise.
    func borderBeam(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        duration: Double = 4,
        beamLength: CGFloat = 0.22,
        outset: CGFloat = 0,
        reverse: Bool = false,
        glow: Bool = true,
        colors: [Color]? = nil
    ) -> some View {
        modifier(BorderBeamModifier(
            cornerRadius: cornerRadius, lineWidth: lineWidth, duration: duration,
            beamLength: beamLength, outset: outset, reverse: reverse, glow: glow, colors: colors
        ))
    }
}

// A wrap-safe trimmed segment of the rounded-rectangle border path.
private struct BeamTrail: Shape {
    var cornerRadius: CGFloat
    var inset: CGFloat
    var from: CGFloat
    var to: CGFloat

    func path(in rect: CGRect) -> Path {
        let base = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: rect.insetBy(dx: inset, dy: inset))
        let a = from - floor(from)   // normalise into 0..<1
        let b = to - floor(to)
        if abs(a - b) < 0.0001 { return Path() }
        if a < b {
            return base.trimmedPath(from: a, to: b)
        }
        // Wrapped across the seam — draw the two halves.
        var p = base.trimmedPath(from: a, to: 1)
        p.addPath(base.trimmedPath(from: 0, to: b))
        return p
    }
}

private struct BorderBeamModifier: ViewModifier {
    /// White-hot comet-head spark — optical glow, intentionally non-thematic (see `MediaScrim`).
    private static let headSparkColor = Color.white.opacity(0.95)
    /// Defensive fallback when a caller passes an empty `colors:` palette — a
    /// neutral light stop (intentionally non-thematic, like the spark above).
    private static let fallbackBeamColor = Color.white

    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let duration: Double
    let beamLength: CGFloat
    let outset: CGFloat
    let reverse: Bool
    let glow: Bool
    let colors: [Color]?

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme

    private let segments = 22

    /// Inset of the beam path — pushed outward by `outset` (Ant `outset`).
    private var beamInset: CGFloat { lineWidth / 2 - outset }

    private var palette: [Color] {
        colors ?? [theme.background(.bgHero), theme.resolve(.turquoise).base]
    }

    func body(content: Content) -> some View {
        content.overlay {
            if reduceMotion {
                // Honor Reduce Motion: a calm static accent border, no traveling beam.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder((palette.first ?? Self.fallbackBeamColor).opacity(0.7), lineWidth: lineWidth)
                    .allowsHitTesting(false)
            } else {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    let progress = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)
                    let head = reverse ? 1 - progress : progress
                    ZStack {
                        // Faint persistent outline so the edge reads even between laps.
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder((palette.first ?? Self.fallbackBeamColor).opacity(0.12), lineWidth: lineWidth)

                        if glow {
                            comet(head)
                                .blur(radius: lineWidth * 3.5)
                                .opacity(0.85)
                        }
                        comet(head)
                        headSpark(head)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    /// The fading comet: stacked sub-segments from the head backwards, opacity
    /// ramping to clear at the tail (two-tone if two colors are supplied).
    private func comet(_ head: CGFloat) -> some View {
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let f0 = CGFloat(i) / CGFloat(segments)
                let f1 = CGFloat(i + 1) / CGFloat(segments)
                BeamTrail(
                    cornerRadius: cornerRadius, inset: beamInset,
                    from: head - f1 * beamLength,
                    to: head - f0 * beamLength + 0.004
                )
                .stroke(
                    segmentColor(f0).opacity(pow(1 - f0, 1.5)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
    }

    private func headSpark(_ head: CGFloat) -> some View {
        BeamTrail(cornerRadius: cornerRadius, inset: beamInset, from: head - 0.018, to: head + 0.004)
            .stroke(Self.headSparkColor, style: StrokeStyle(lineWidth: lineWidth * 1.25, lineCap: .round))
            .blur(radius: lineWidth * 0.7)
    }

    private func segmentColor(_ f: CGFloat) -> Color {
        guard palette.count >= 2 else { return palette.first ?? Self.fallbackBeamColor }
        return f < 0.5 ? palette[0] : palette[1]
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    PreviewMatrix("BorderBeam") {
        PreviewCase("Card beam (theme accent)") {
            Text("Featured")
                .textStyle(.headingSm)
                .padding(40)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
                .borderBeam(cornerRadius: 20, lineWidth: 2.5)
                .padding(16)
        }
        PreviewCase("Capsule beam (custom colors)") {
            Text("Pro")
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(theme.background(.bgElevatorTertiary), in: Capsule())
                .borderBeam(cornerRadius: 100, lineWidth: 2, duration: 3,
                            colors: [SemanticColor.purple.base, SemanticColor.pink.base])
                .padding(16)
        }
        PreviewCase("No glow, reversed") {
            Text("Quiet")
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 12))
                .borderBeam(cornerRadius: 12, lineWidth: 2, reverse: true, glow: false)
                .padding(16)
        }
    }
}
