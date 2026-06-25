//
//  DividerView.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  A theme-driven divider: horizontal / vertical, solid / dashed, with an
//  optional inline text label (left / center / right). (Ant Divider parity.)
//  Colors come exclusively from the active theme.
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

public struct DividerView: View {
    private let size: DividerViewSize
    private let axis: DividerAxis
    private let dashed: Bool
    private let title: String?
    private let titleAlign: DividerTextAlign

    public init(
        size: DividerViewSize = .small,
        axis: DividerAxis = .horizontal,
        dashed: Bool = false,
        title: String? = nil,
        titleAlign: DividerTextAlign = .center
    ) {
        self.size = size
        self.axis = axis
        self.dashed = dashed
        self.title = title
        self.titleAlign = titleAlign
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
                        .foregroundStyle(Theme.shared.text(.textTertiary))
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
                Theme.shared.border(.borderPrimary).frame(height: 1)
            case .medium, .large:
                Theme.shared.border(.borderPrimary).frame(height: 1)
                Theme.shared.background(.bgElevatorPrimary).frame(height: size.height - 1)
            }
        }
    }

    private func line(vertical: Bool) -> some View {
        LineShape(vertical: vertical)
            .stroke(Theme.shared.border(.borderPrimary),
                    style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 4] : []))
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
        DividerView(size: .small)
        DividerView(dashed: true)
        DividerView(title: "OR")
        DividerView(title: "Left", titleAlign: .leading)
        HStack {
            Text("A"); DividerView(axis: .vertical); Text("B"); DividerView(axis: .vertical, dashed: true); Text("C")
        }
        .frame(height: 24)
    }
    .padding()
}
