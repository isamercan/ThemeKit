//
//  Mask.swift
//  ThemeKit
//

import SwiftUI

/// A decorative clip shape for images / avatars. (daisyUI "Mask".)
public enum MaskShape: Sendable, CaseIterable {
    case circle, squircle, hexagon, star

    var shape: ThemeAnyShape {
        switch self {
        case .circle:   return ThemeAnyShape(Circle())
        case .squircle: return ThemeAnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        case .hexagon:  return ThemeAnyShape(PolygonShape(sides: 6, rotation: .pi / 6))
        case .star:     return ThemeAnyShape(StarShape(points: 5))
        }
    }
}

public extension View {
    /// Clips this view to a decorative ``MaskShape`` (daisyUI "Mask") — squircle,
    /// hexagon, star… Apply to images or avatars.
    func themeMask(_ shape: MaskShape) -> some View {
        clipShape(shape.shape)
    }
}

/// A regular n-gon inscribed in the rect.
struct PolygonShape: Shape {
    let sides: Int
    var rotation: Double = 0

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<max(sides, 3) {
            let angle = (Double(i) / Double(sides)) * 2 * .pi + rotation - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// A pointed star (outer/inner radius alternation).
struct StarShape: Shape {
    var points: Int = 5
    var innerRatio: Double = 0.42

    func path(in rect: CGRect) -> Path {
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(MaskShape.allCases, id: \.self) { shape in
            Rectangle().fill(.blue.gradient).frame(width: 56, height: 56).themeMask(shape)
        }
    }
    .padding()
}
