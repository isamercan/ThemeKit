//
//  Effects.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Small reusable effect primitives from the reference Utils: per-edge borders
//  (EdgeBorder) and a fade-to-transparent edge scrim (ProgressiveBlurEffect's
//  lighter cousin).
//

import SwiftUI

public extension View {
    /// Draws a border on only the given edges (SwiftUI has no per-side border).
    func edgeBorder(_ edges: [Edge], width: CGFloat = 1, color: Color? = nil) -> some View {
        overlay(EdgeBorderShape(edges: edges, width: width)
            .fill(color ?? Theme.shared.border(.borderPrimary)))
    }

    /// Overlays a gradient scrim fading from `color` (default surface) to clear at
    /// the given edge — e.g. a soft fade at the bottom of a scroll area.
    func fadeEdge(_ edge: Alignment = .bottom, length: CGFloat = 40, color: Color? = nil) -> some View {
        let fill = color ?? Theme.shared.background(.bgWhite)
        let vertical = edge == .top || edge == .bottom
        let start: UnitPoint = edge == .top ? .top : edge == .bottom ? .bottom : edge == .leading ? .leading : .trailing
        let end: UnitPoint = edge == .top ? .bottom : edge == .bottom ? .top : edge == .leading ? .trailing : .leading
        return overlay(alignment: edge) {
            LinearGradient(colors: [fill, fill.opacity(0)], startPoint: start, endPoint: end)
                .frame(width: vertical ? nil : length, height: vertical ? length : nil)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Media scrim (always-dark, over imagery)

/// Shared constants for the always-dark scrims layered **over photos and video**
/// so overlaid glyphs, chips and labels stay legible on any imagery.
///
/// Deliberately raw `Color.black` and **not** a theme token: a media scrim sits
/// on top of a photograph, so it must stay dark in dark mode and must not
/// re-tint when the brand theme changes — theming it would wash out or tint the
/// photo treatment. This is the sanctioned exemption from the "no raw `Color`"
/// rule. For modal/backdrop scrims (which *do* theme), use the `Backdrop` atom /
/// `bgBackdrop` token instead.
public enum MediaScrim {
    /// Solid scrim behind small controls and chips over imagery — favourite
    /// hearts, mute buttons, capsule tags, "+N" collage counts.
    public static let solid = Color.black.opacity(0.35)

    /// Bottom-anchored legibility gradient for text over imagery: clear at the
    /// top fading to dark at the bottom.
    public static let gradient = LinearGradient(
        colors: [.black.opacity(0), .black.opacity(0.65)],
        startPoint: .top, endPoint: .bottom
    )

    /// Foreground content — glyphs, counts, labels — laid *over* imagery or a
    /// `.solid`/`.gradient` scrim. Stays light regardless of the active theme
    /// (same sanctioned exemption as the scrims above: the pixels underneath
    /// aren't theme-controlled, so on-media content must not re-tint). Use this
    /// instead of a raw `Color.white` for the "+N" collage count, video overlay
    /// glyphs, on-image page-header titles, QR quiet-zones, etc.
    public static let onContent = Color.white

    /// Dimmed on-media content (inactive page dots, secondary captions).
    public static let onContentSecondary = Color.white.opacity(0.7)
}

struct EdgeBorderShape: Shape {
    let edges: [Edge]
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            switch edge {
            case .top: path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: width))
            case .bottom: path.addRect(CGRect(x: rect.minX, y: rect.maxY - width, width: rect.width, height: width))
            case .leading: path.addRect(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
            case .trailing: path.addRect(CGRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height))
            }
        }
        return path
    }
}
