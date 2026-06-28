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
    ///   - lineWidth: beam thickness.
    ///   - duration: seconds for one full lap.
    ///   - beamLength: comet length as a fraction of the perimeter (0…1).
    ///   - glow: draw the soft neon halo behind the beam.
    ///   - colors: beam colors (head→tail). Defaults to the theme accent + turquoise.
    func borderBeam(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        duration: Double = 4,
        beamLength: CGFloat = 0.22,
        glow: Bool = true,
        colors: [Color]? = nil
    ) -> some View {
        modifier(BorderBeamModifier(
            cornerRadius: cornerRadius, lineWidth: lineWidth, duration: duration,
            beamLength: beamLength, glow: glow, colors: colors
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
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let duration: Double
    let beamLength: CGFloat
    let glow: Bool
    let colors: [Color]?

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme

    private let segments = 22

    private var palette: [Color] {
        colors ?? [theme.background(.bgHero), SemanticColor.turquoise.base]
    }

    func body(content: Content) -> some View {
        content.overlay {
            if reduceMotion {
                // Honor Reduce Motion: a calm static accent border, no traveling beam.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder((palette.first ?? .white).opacity(0.7), lineWidth: lineWidth)
                    .allowsHitTesting(false)
            } else {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    let head = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)
                    ZStack {
                        // Faint persistent outline so the edge reads even between laps.
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder((palette.first ?? .white).opacity(0.12), lineWidth: lineWidth)

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
                    cornerRadius: cornerRadius, inset: lineWidth / 2,
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
        BeamTrail(cornerRadius: cornerRadius, inset: lineWidth / 2, from: head - 0.018, to: head + 0.004)
            .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: lineWidth * 1.25, lineCap: .round))
            .blur(radius: lineWidth * 0.7)
    }

    private func segmentColor(_ f: CGFloat) -> Color {
        guard palette.count >= 2 else { return palette.first ?? .white }
        return f < 0.5 ? palette[0] : palette[1]
    }
}

#Preview {
    VStack(spacing: 36) {
        Text("Featured")
            .textStyle(.headingSm)
            .padding(40)
            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
            .borderBeam(cornerRadius: 20, lineWidth: 2.5)

        Text("Pro")
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Theme.shared.background(.bgElevatorTertiary), in: Capsule())
            .borderBeam(cornerRadius: 100, lineWidth: 2, duration: 3,
                        colors: [SemanticColor.purple.base, SemanticColor.pink.base])
    }
    .padding(48)
    .background(Theme.shared.background(.bgTertiary))
}
