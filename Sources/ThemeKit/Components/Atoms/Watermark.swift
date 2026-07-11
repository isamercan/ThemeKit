//
//  Watermark.swift
//  ThemeKit
//
//  Ant Design's **Watermark** — tiles a faint, rotated label across a view so
//  screenshots and exports carry provenance without obscuring the content. Drawn
//  once in a `Canvas` (cheap, non-interactive) and re-tinted from the theme.
//
//      ReportCard().watermark("CONFIDENTIAL")
//      Preview().watermark("draft", rotation: .degrees(-30), fontSize: 14)
//

import SwiftUI

public extension View {
    /// Overlay a tiled, rotated watermark label (Ant `Watermark`).
    /// - Parameters:
    ///   - text: the repeated label.
    ///   - rotation: tile rotation (Ant default −22°).
    ///   - fontSize: label size in points.
    ///   - gap: empty space between tiles, horizontally and vertically.
    ///   - color: label color; defaults to a faint tertiary ink so it stays subtle.
    func watermark(
        _ text: String,
        rotation: Angle = .degrees(-22),
        fontSize: CGFloat = 16,
        gap: CGSize = CGSize(width: 56, height: 56),
        color: Color? = nil
    ) -> some View {
        modifier(WatermarkModifier(text: text, rotation: rotation, fontSize: fontSize, gap: gap, color: color))
    }
}

private struct WatermarkModifier: ViewModifier {
    let text: String
    let rotation: Angle
    let fontSize: CGFloat
    let gap: CGSize
    let color: Color?

    @Environment(\.theme) private var theme

    private var ink: Color { color ?? theme.text(.textTertiary).opacity(0.16) }

    func body(content: Content) -> some View {
        content.overlay {
            Canvas { context, size in
                let label = Text(text).font(.system(size: fontSize, weight: .semibold))
                let resolved = context.resolve(label.foregroundStyle(ink))
                let tile = resolved.measure(in: CGSize(width: 1000, height: fontSize * 3))
                let stepX = tile.width + gap.width
                let stepY = tile.height + gap.height
                guard stepX > 0, stepY > 0 else { return }

                // Draw over an expanded, rotated field so tiles still cover the
                // corners once rotated.
                let reach = hypot(size.width, size.height)
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.rotate(by: rotation)

                var y = -reach
                while y <= reach {
                    var x = -reach
                    while x <= reach {
                        context.draw(resolved, at: CGPoint(x: x, y: y))
                        x += stepX
                    }
                    y += stepY
                }
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    VStack(spacing: 12) {
        Text("Boarding pass").textStyle(.headingSm)
        Text("New York → London").textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
    }
    .frame(maxWidth: .infinity)
    .padding(40)
    .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
    .watermark("SPECIMEN")
    .padding(24)
    .environment(Theme.shared)
}
