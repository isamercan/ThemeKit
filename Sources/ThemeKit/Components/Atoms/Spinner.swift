//
//  Spinner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Loading shape of a `Spinner`. (daisyUI Loading `loading-{shape}`.)
public enum SpinnerStyle: String, CaseIterable, Sendable {
    /// Rotating open ring (the classic spinner, default).
    case ring
    /// Three bouncing dots.
    case dots
    /// Three vertical bars scaling in sequence.
    case bars
    /// A single ball bouncing up and down.
    case ball
    /// A figure-eight stroke drawing itself in a loop.
    case infinity
}

/// Default diameter/stroke presets riding the native `.controlSize(_:)` cascade.
/// An explicit `.size(_:)` / `.lineWidth(_:)` override always wins (R5).
private extension ControlSize {
    var spinnerDiameter: CGFloat {
        switch self {
        case .mini, .small: return 16
        case .large, .extraLarge: return 40
        default: return 24   // .regular (default)
        }
    }

    var spinnerStroke: CGFloat {
        switch self {
        case .mini, .small: return 2
        case .large, .extraLarge: return 4
        default: return 3    // .regular (default)
        }
    }
}

/// Atom. Indeterminate loading indicator (token-tinted) in five shapes:
/// ring / dots / bars / ball / infinity. (daisyUI "Loading".)
///
/// Sizes ride the native `.controlSize(_:)` cascade (small ≈ 16/2, regular
/// 24/3, large 40/4) unless `.size(_:)`/`.lineWidth(_:)` override them.
/// `.indicator { … }` swaps the built-in shape for custom content spun by the
/// shared rotation driver. Honors Reduce Motion: every style renders a static
/// form (the ring becomes a fixed 270° arc with no rotation).
public struct Spinner: View {
    @Environment(\.theme) private var theme
    @Environment(\.controlSize) private var controlSize

    // Appearance/config — mutated only through the modifiers below (R2).
    private var size: CGFloat?
    private var lineWidth: CGFloat?
    private var color: Color?
    private var semantic: SemanticColor?
    private var style: SpinnerStyle = .ring
    private var indicator: AnyView?

    public init() {}   // R1

    /// Raw override wins, then the semantic accent, then the theme hero foreground.
    private var tint: Color { color ?? semantic?.accent ?? theme.foreground(.fgHero) }

    /// Explicit override wins; else the `.controlSize(_:)` preset.
    private var resolvedSize: CGFloat { size ?? controlSize.spinnerDiameter }
    private var resolvedLineWidth: CGFloat { lineWidth ?? controlSize.spinnerStroke }

    public var body: some View {
        Group {
            if let indicator {
                // Custom slot rides the shared rotor (static under Reduce Motion).
                SpinnerRotor {
                    indicator.frame(width: resolvedSize, height: resolvedSize)
                }
            } else {
                switch style {
                case .ring: SpinnerRing(tint: tint, size: resolvedSize, lineWidth: resolvedLineWidth)
                case .dots: SpinnerDots(tint: tint, size: resolvedSize)
                case .bars: SpinnerBars(tint: tint, size: resolvedSize)
                case .ball: SpinnerBall(tint: tint, size: resolvedSize)
                case .infinity: SpinnerInfinity(tint: tint, size: resolvedSize, lineWidth: resolvedLineWidth)
                }
            }
        }
        .accessibilityLabel(String(themeKit: "Loading"))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Spinner {
    /// Loading shape: ring (default) / dots / bars / ball / infinity.
    func style(_ s: SpinnerStyle) -> Self { copy { $0.style = s } }

    /// Diameter in points (default 24).
    func size(_ points: CGFloat) -> Self { copy { $0.size = points } }

    /// Stroke thickness in points (default 3) — used by the ring and infinity shapes.
    func lineWidth(_ width: CGFloat) -> Self { copy { $0.lineWidth = width } }

    /// Semantic tint; `nil` (default) uses the theme's hero foreground.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.semantic = color } }

    /// Raw tint override (back-compat); prefer `accent(_:)`. Wins over `accent`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: Color?) -> Self { copy { $0.color = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Shapes

/// Rotating open ring — the original `Spinner` body.
private struct SpinnerRing: View {
    let tint: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}

/// Three dots bouncing in sequence.
private struct SpinnerDots: View {
    let tint: Color
    let size: CGFloat
    @State private var bouncing = false

    var body: some View {
        HStack(spacing: size * 0.12) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .offset(y: bouncing ? -size * 0.16 : size * 0.16)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.13),
                        value: bouncing
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { bouncing = true }
    }
}

/// Three vertical bars scaling in sequence.
private struct SpinnerBars: View {
    let tint: Color
    let size: CGFloat
    @State private var scaled = false

    var body: some View {
        HStack(spacing: size * 0.14) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
                    .fill(tint)
                    .frame(width: size * 0.18, height: size)
                    .scaleEffect(y: scaled ? 1 : 0.4, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: scaled
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { scaled = true }
    }
}

/// A single ball bouncing up and down.
private struct SpinnerBall: View {
    let tint: Color
    let size: CGFloat
    @State private var up = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size * 0.5, height: size * 0.5)
            .offset(y: up ? -size * 0.25 : size * 0.25)
            .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: up)
            .frame(width: size, height: size)
            .onAppear { up = true }
    }
}

/// Figure-eight path for the infinity spinner.
private struct InfinityShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let center = CGPoint(x: rect.minX + w / 2, y: rect.minY + h / 2)
        // Control points overshoot the rect so the curve itself (which stays well
        // inside its control hull) fills it edge to edge without clipping.
        p.move(to: center)
        // Right lobe.
        p.addCurve(to: center,
                   control1: CGPoint(x: rect.minX + w * 1.15, y: rect.minY - h * 0.75),
                   control2: CGPoint(x: rect.minX + w * 1.15, y: rect.minY + h * 1.75))
        // Left lobe, vertically mirrored so the stroke crosses in the middle.
        p.addCurve(to: center,
                   control1: CGPoint(x: rect.minX - w * 0.15, y: rect.minY - h * 0.75),
                   control2: CGPoint(x: rect.minX - w * 0.15, y: rect.minY + h * 1.75))
        return p
    }
}

/// A comet segment sweeping along a faint figure-eight track.
private struct SpinnerInfinity: View {
    let tint: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            InfinityShape()
                .stroke(tint.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            InfinityShape()
                .trim(from: phase * 0.75, to: phase)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .frame(width: size * 1.7, height: size)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            Spinner().size(16).lineWidth(2)
            Spinner()
            Spinner().size(40).lineWidth(4)
        }
        HStack(spacing: 24) {
            Spinner().style(.dots)
            Spinner().style(.bars)
            Spinner().style(.ball)
            Spinner().style(.infinity)
        }
        HStack(spacing: 24) {
            Spinner().style(.dots).accent(.success).size(32)
            Spinner().style(.bars).accent(.warning).size(32)
            Spinner().style(.infinity).accent(.error).size(32)
        }
    }
    .padding()
}
