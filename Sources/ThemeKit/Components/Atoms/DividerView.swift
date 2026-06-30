//
//  DividerView.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum DividerViewSize {
    case small
    case medium
    case large

    public var height: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.xs.value     // 4
        case .medium: return Theme.SpacingKey.sm.value     // 8
        case .large: return Theme.SpacingKey.md.value      // 16
        }
    }
}

public enum DividerAxis { case horizontal, vertical }
public enum DividerTextAlign { case leading, center, trailing }

/// A theme-driven divider: horizontal / vertical, solid / dashed, with an
/// optional inline text label (left / center / right). (Ant Divider parity.)
/// Colors come exclusively from the active theme.
public struct DividerView: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var size: DividerViewSize = .small
    private var axis: DividerAxis = .horizontal
    private var dashed: Bool = false
    private var titleAlign: DividerTextAlign = .center

    private let title: String?

    public init(_ title: String? = nil) {   // R1
        self.title = title
    }

    public var body: some View {
        switch axis {
        case .vertical:
            line(vertical: true)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        case .horizontal:
            if let title {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    line(vertical: false).frame(maxWidth: .infinity).frame(width: titleAlign == .leading ? 16 : nil)
                    Text(title)
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textTertiary))
                        .fixedSize()
                    line(vertical: false).frame(maxWidth: .infinity).frame(width: titleAlign == .trailing ? 16 : nil)
                }
                .frame(height: 20)
            } else if dashed {
                line(vertical: false).frame(height: 1).frame(maxWidth: .infinity)
            } else {
                plain
            }
        }
    }

    private var plain: some View {
        VStack(spacing: 0) {
            switch size {
            case .small:
                theme.border(.borderPrimary).frame(height: 1)
            case .medium, .large:
                theme.border(.borderPrimary).frame(height: 1)
                theme.background(.bgElevatorPrimary).frame(height: size.height - 1)
            }
        }
    }

    private func line(vertical: Bool) -> some View {
        LineShape(vertical: vertical)
            .stroke(theme.border(.borderPrimary),
                    style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 4] : []))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DividerView {
    /// Thickness tier of the (non-titled, non-dashed) divider: small / medium / large.
    func size(_ s: DividerViewSize) -> Self { copy { $0.size = s } }

    /// Orientation: horizontal (default) or vertical.
    func axis(_ a: DividerAxis) -> Self { copy { $0.axis = a } }

    /// Render the line as a dashed stroke.
    func dashed(_ on: Bool = true) -> Self { copy { $0.dashed = on } }

    /// Inline title placement: leading / center / trailing.
    func titleAlign(_ a: DividerTextAlign) -> Self { copy { $0.titleAlign = a } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

private struct LineShape: Shape {
    let vertical: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if vertical {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return p
    }
}

#Preview {
    VStack(spacing: 20) {
        DividerView().size(.small)
        DividerView().dashed()
        DividerView("OR")
        DividerView("Left").titleAlign(.leading)
        HStack {
            Text("A"); DividerView().axis(.vertical); Text("B"); DividerView().axis(.vertical).dashed(); Text("C")
        }
        .frame(height: 24)
    }
    .padding()
}
