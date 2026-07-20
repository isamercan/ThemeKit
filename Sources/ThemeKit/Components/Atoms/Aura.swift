//
//  Aura.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  A soft, gently breathing glow — available as a standalone `Aura` blob or as
//  the `.aura()` modifier that halos any view from behind (like `.borderBeam()`,
//  but a diffuse ambient light instead of a traveling comet). Token-tinted via
//  `SemanticColor`; honors `microAnimations` and the system Reduce Motion.
//  (daisyUI "Aura".)
//

import SwiftUI

/// Atom. Soft animated glow (daisyUI Aura): a blurred radial blob that gently
/// breathes. Use standalone as an ambient accent, or apply `.aura()` to place
/// the glow behind existing content.
public struct Aura: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Appearance/config — mutated only through the modifiers below (R2).
    private var color: SemanticColor = .primary
    private var diameter: CGFloat = 120
    private var intensity: Double = 0.7

    @State private var breathing = false

    public init() {}   // R1

    private var animated: Bool { micro && !reduceMotion }

    public var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [theme.resolve(color).base.opacity(intensity), theme.resolve(color).base.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter / 8)
            .scaleEffect(animated && breathing ? 1.08 : 1)
            .opacity(animated && breathing ? 0.75 : 1)
            .onAppear {
                guard animated else { return }
                // Slow "breath" — deliberately calmer than the motion tokens,
                // so it reads as ambient light rather than UI animation.
                withAnimation(.easeInOut(duration: Motion.slower.duration * 4).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)   // purely decorative
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Aura {
    /// Semantic tint of the glow; `nil` restores the default (`.primary`).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.color = color ?? .primary } }

    /// Semantic tint of the glow (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: SemanticColor) -> Self { copy { $0.color = c } }

    /// Diameter of the blob in points (default 120).
    func size(_ points: CGFloat) -> Self { copy { $0.diameter = points } }

    /// Peak opacity of the glow, 0…1 (default 0.7).
    func intensity(_ value: Double) -> Self { copy { $0.intensity = min(max(value, 0), 1) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - .aura() view modifier

public extension View {
    /// A soft breathing glow behind this view (daisyUI Aura).
    /// - Parameters:
    ///   - color: semantic tint of the glow (blended `base` → `hover` ladder steps).
    ///   - radius: blur radius of the halo in points.
    ///   - intensity: peak opacity of the glow, 0…1.
    func aura(
        _ color: SemanticColor = .primary,
        radius: CGFloat = 24,
        intensity: Double = 0.55
    ) -> some View {
        modifier(AuraModifier(color: color, radius: radius, intensity: min(max(intensity, 0), 1)))
    }
}

private struct AuraModifier: ViewModifier {
    let color: SemanticColor
    let radius: CGFloat
    let intensity: Double

    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var animated: Bool { micro && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .background {
                // Two ladder steps of the same semantic color give the halo a
                // subtle direction without introducing a second color knob.
                LinearGradient(
                    colors: [theme.resolve(color).base, theme.resolve(color).hover],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .padding(-radius / 3)   // let the halo spill past the content edge
                .blur(radius: radius)
                .opacity(animated && breathing ? intensity * 0.6 : intensity)
                .scaleEffect(animated && breathing ? 0.97 : 1.02)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear {
                    guard animated else { return }
                    withAnimation(.easeInOut(duration: Motion.slower.duration * 4).repeatForever(autoreverses: true)) {
                        breathing = true
                    }
                }
            }
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("Aura") {
                PreviewCase("Halo (.aura())") {
                    Text("Featured")
                        .textStyle(.headingSm)
                        .padding(40)
                        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
                        .aura()
                        .padding(24)
                }
                PreviewCase("Tinted halo (purple)") {
                    Text("Limited offer")
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(theme.background(.bgWhite), in: Capsule())
                        .aura(.purple, radius: 32, intensity: 0.7)
                        .padding(24)
                }
                PreviewCase("Standalone blobs") {
                    HStack(spacing: 40) {
                        Aura().accent(.turquoise).size(90)
                        Aura().accent(.pink).intensity(0.9).size(90)
                    }
                }
            }
        }
    }
    return Demo()
}
