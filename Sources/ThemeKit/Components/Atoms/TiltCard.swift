//
//  TiltCard.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Touch-adapted 3D tilt (daisyUI "Hover 3D Card"): content rotates in
//  perspective toward the finger while dragging and springs back on release,
//  with an optional specular "shine" highlight that follows the touch. Ships as
//  the `.tilt3D()` modifier plus a `TiltCard` wrapper with chainable knobs.
//  Purely decorative motion — fully disabled by Reduce Motion / microAnimations.
//

import SwiftUI

/// Atom. Touch-adapted 3D tilt card (daisyUI Hover 3D Card): wraps content that
/// tilts in 3D following the drag location and springs back when released.
/// Prefer the `.tilt3D()` modifier for quick use; this wrapper adds the R2
/// chainable configuration (`.maxAngle`, `.shine`, `.radius`).
public struct TiltCard<Content: View>: View {
    private let content: Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var maxAngle: Angle = .degrees(10)
    private var shine: Bool = false
    private var radiusRole: Theme.RadiusRole = .box

    public init(@ViewBuilder content: () -> Content) {   // R1
        self.content = content()
    }

    public var body: some View {
        content.modifier(Tilt3DModifier(maxAngle: maxAngle, shine: shine, radiusRole: radiusRole))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TiltCard {
    /// Maximum tilt from rest when the finger reaches an edge (default 10°).
    func maxAngle(_ angle: Angle) -> Self { copy { $0.maxAngle = angle } }

    /// Adds a specular highlight that follows the touch point (default off).
    func shine(_ on: Bool = true) -> Self { copy { $0.shine = on } }

    /// Corner radius role used to clip the shine highlight (default `.box`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - .tilt3D() view modifier

public extension View {
    /// Tilts this view in 3D toward the drag location, springing back on release
    /// (daisyUI Hover 3D Card, touch-adapted).
    /// - Parameters:
    ///   - maxAngle: maximum tilt when the finger reaches an edge.
    ///   - shine: overlay a specular highlight that follows the touch.
    ///   - radius: corner radius role used to clip the shine highlight.
    func tilt3D(
        maxAngle: Angle = .degrees(10),
        shine: Bool = false,
        radius: Theme.RadiusRole = .box
    ) -> some View {
        modifier(Tilt3DModifier(maxAngle: maxAngle, shine: shine, radiusRole: radius))
    }
}

private struct Tilt3DModifier: ViewModifier {
    /// Optical specular sheen — intentionally non-thematic white (see `MediaScrim`).
    private static let specularHighlight = Color.white.opacity(0.35)

    let maxAngle: Angle
    let shine: Bool
    let radiusRole: Theme.RadiusRole

    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Normalized tilt: width/height each in -1…1 (finger offset from center).
    @State private var tilt: CGSize = .zero
    @State private var size: CGSize = .zero

    private var active: Bool { micro && !reduceMotion }
    private var magnitude: CGFloat { min(1, hypot(tilt.width, tilt.height)) }

    func body(content: Content) -> some View {
        content
            .overlay {
                if shine && active {
                    shineOverlay
                }
            }
            .rotation3DEffect(
                .degrees(maxAngle.degrees * magnitude),
                // Axis perpendicular to the finger's offset vector, so the card
                // leans toward the touch point.
                axis: magnitude > 0.001 ? (x: -tilt.height, y: tilt.width, z: 0) : (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { size = geo.size }
                        .onChange(of: geo.size) { _, newSize in size = newSize }
                }
            )
            .simultaneousGesture(active ? drag : nil)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                // Track the finger directly — the spring is saved for release.
                tilt = CGSize(
                    width: min(max(value.location.x / size.width * 2 - 1, -1), 1),
                    height: min(max(value.location.y / size.height * 2 - 1, -1), 1)
                )
            }
            .onEnded { _ in
                withAnimation(Motion.slow.spring) { tilt = .zero }
            }
    }

    /// Specular highlight riding the touch point; fades out entirely at rest.
    private var shineOverlay: some View {
        RadialGradient(
            colors: [Self.specularHighlight, Self.specularHighlight.opacity(0)],
            center: UnitPoint(x: 0.5 + tilt.width / 2, y: 0.5 + tilt.height / 2),
            startRadius: 0,
            endRadius: max(size.width, size.height)
        )
        .opacity(magnitude)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius(radiusRole), style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)   // purely decorative
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    // Drag-driven tilt still works inside each cell; a matrix row shows the
    // at-rest frame per form.
    PreviewMatrix("TiltCard") {
        PreviewCase("Modifier form · shine") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium Cabin").textStyle(.headingSm)
                Text("Drag me around").textStyle(.bodySm400)
            }
            .padding(32)
            .frame(width: 260)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
            .themeShadow(.elevated)
            .tilt3D(shine: true)
        }
        PreviewCase("Wrapper form · custom angle") {
            TiltCard {
                Text("Wrapper form")
                    .padding(40)
                    .background(theme.background(.bgElevatorTertiary), in: RoundedRectangle(cornerRadius: 16))
            }
            .maxAngle(.degrees(14))
            .shine()
            .radius(.field)
        }
    }
}
