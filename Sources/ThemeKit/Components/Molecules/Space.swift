//
//  Space.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Space** — sets a consistent gap between inline or
//  stacked children, so a row/column of controls is evenly spaced without hand-
//  tuned padding. Horizontal or vertical, a preset or custom size, cross-axis
//  alignment, and optional wrapping (horizontal).
//
//      Space { Button("Save"){}; Button("Cancel"){} }            // 8pt row
//      Space { Tag("A"); Tag("B"); Tag("C") }.size(.large).wrap()
//      Space { title; subtitle }.vertical().align(.start)
//

import SwiftUI

/// Gap between ``Space`` children. (Ant Space `size` — small 8 / middle 16 / large 24.)
public enum SpaceSize: Sendable {
    case small, medium, large
    var value: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.sm.value      // 8
        case .medium: return Theme.SpacingKey.md.value     // 16
        case .large: return Theme.SpacingKey.base.value    // 24
        }
    }
}

/// Cross-axis alignment of ``Space`` children. (Ant Space `align`.)
public enum SpaceAlign: Sendable { case start, center, end, baseline }

public struct Space<Content: View>: View {
    private let content: Content
    // Appearance — mutated only through the modifiers below.
    private var axis: Axis = .horizontal
    private var spacing: CGFloat = Theme.SpacingKey.sm.value   // Ant default: small
    private var alignment: SpaceAlign = .center
    private var wraps = false

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        if axis == .horizontal, wraps {
            FlowLayout(spacing: spacing, lineSpacing: spacing, alignment: horizontal) { content }
        } else if axis == .horizontal {
            HStack(alignment: vertical, spacing: spacing) { content }
        } else {
            VStack(alignment: horizontal, spacing: spacing) { content }
        }
    }

    private var vertical: VerticalAlignment {
        switch alignment {
        case .start: return .top
        case .center: return .center
        case .end: return .bottom
        case .baseline: return .firstTextBaseline
        }
    }
    private var horizontal: HorizontalAlignment {
        switch alignment {
        case .start, .baseline: return .leading
        case .center: return .center
        case .end: return .trailing
        }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Space {
    /// Layout direction (Ant Space `direction`/`orientation`). Default `.horizontal`.
    func direction(_ axis: Axis) -> Self { copy { $0.axis = axis } }
    /// Stack the children vertically.
    func vertical(_ on: Bool = true) -> Self { copy { $0.axis = on ? .vertical : .horizontal } }
    /// Gap from a preset size (small / medium / large).
    func size(_ size: SpaceSize) -> Self { copy { $0.spacing = size.value } }
    /// Gap from a theme spacing token.
    func size(_ key: Theme.SpacingKey) -> Self { copy { $0.spacing = key.value } }
    /// Gap from a raw point value.
    func size(_ value: CGFloat) -> Self { copy { $0.spacing = max(0, value) } }
    /// Cross-axis alignment (start / center / end / baseline).
    func align(_ alignment: SpaceAlign) -> Self { copy { $0.alignment = alignment } }
    /// Wrap onto multiple lines when horizontal (Ant Space `wrap`).
    func wrap(_ on: Bool = true) -> Self { copy { $0.wraps = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Space") {
        PreviewCase("Row (default gap)") { Space { ForEach(0..<3) { Tag("Tag \($0)") } } }
        PreviewCase("Wrap, medium gap") { Space { ForEach(0..<8) { Tag("Item \($0)") } }.size(.medium).wrap().frame(width: 260) }
        PreviewCase("Vertical, start-aligned") {
            Space { Text("Title").textStyle(.headingSm); Text("Subtitle").textStyle(.bodySm400) }
                .vertical().align(.start)
        }
    }
    .environment(Theme.shared)
}
