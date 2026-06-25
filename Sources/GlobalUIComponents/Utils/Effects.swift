//
//  Effects.swift
//  GlobalUIComponents
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
