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
///
/// The paint is drawn by the active ``DividerStyle``: the environment style set
/// with `.dividerStyle(_:)` on any ancestor, or the stock
/// ``DefaultDividerStyle`` look. The divider keeps its content model and
/// accessibility either way.
public struct DividerView: View {
    @Environment(\.dividerStyle) private var style

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
        if style.isDefault {
            DefaultDividerChrome(configuration: configuration(withLabel: false))
        } else {
            style.makeBody(configuration: configuration(withLabel: true))
                .modifier(DividerStyleAccessibility(title: title))
        }
    }

    /// The configuration; the stock chrome draws the title itself, so the
    /// type-erased `label` is built only for a style that may place it.
    private func configuration(withLabel: Bool) -> DividerStyleConfiguration {
        DividerStyleConfiguration(
            title: title,
            label: withLabel ? title.map { AnyView(DividerTitle(text: $0)) } : nil,
            axis: axis,
            isDashed: dashed,
            size: size,
            titleAlignment: titleAlign
        )
    }
}

/// The stock divider — ``DefaultDividerStyle``'s body.
struct DefaultDividerChrome: View {
    @Environment(\.theme) private var theme

    let configuration: DividerStyleConfiguration

    private var size: DividerViewSize { configuration.size }
    private var dashed: Bool { configuration.isDashed }
    private var titleAlign: DividerTextAlign { configuration.titleAlignment }

    var body: some View {
        switch configuration.axis {
        case .vertical:
            line(vertical: true)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        case .horizontal:
            if let title = configuration.title {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    line(vertical: false).frame(maxWidth: .infinity).frame(width: titleAlign == .leading ? 16 : nil)
                    DividerTitle(text: title)
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
                theme.background(.bgBase).frame(height: size.height - 1)
            }
        }
    }

    private func line(vertical: Bool) -> some View {
        LineShape(vertical: vertical)
            .stroke(theme.border(.borderPrimary),
                    style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 4] : []))
            // The dash pattern runs from the path's start, so mirror it under
            // RTL to start at the leading edge. A solid line is symmetric —
            // only the dashed one flips.
            .flipsForRightToLeftLayoutDirection(dashed)
    }
}

/// The inline title in the stock type and colour — drawn by the stock chrome and
/// handed to custom styles as `configuration.label`.
private struct DividerTitle: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.labelSm600)
            .foregroundStyle(theme.text(.textTertiary))
            .fixedSize()
    }
}

/// A custom style's divider reads like the stock one: a bare line is
/// decorative, a titled divider is its title — once, whatever the style draws.
private struct DividerStyleAccessibility: ViewModifier {
    let title: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let title {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
        } else {
            content.accessibilityHidden(true)
        }
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
    PreviewMatrix("DividerView") {
        PreviewCase("Solid") { DividerView().size(.small) }
        PreviewCase("Dashed") { DividerView().dashed() }
        PreviewCase("Titled (center)") { DividerView("OR") }
        PreviewCase("Titled (leading)") { DividerView("Left").titleAlign(.leading) }
        PreviewCase("Vertical") {
            HStack {
                Text("A"); DividerView().axis(.vertical); Text("B"); DividerView().axis(.vertical).dashed(); Text("C")
            }
            .frame(height: 24)
        }
    }
}

#Preview("Custom DividerStyle") {
    /// Hero-coloured 2 pt rules with a body-type title; dashed rules use a short
    /// dash with round caps, flipped for RTL. `keepsStockLabel` places ThemeKit's
    /// own title instead.
    struct HeroDividerStyle: DividerStyle {
        var keepsStockLabel = false
        func makeBody(configuration: DividerStyleConfiguration) -> some View {
            HeroDivider(configuration: configuration, keepsStockLabel: keepsStockLabel)
        }
    }
    /// A line along the rect's long axis, inset by half the line width so round
    /// caps stay inside the frame.
    struct Rule: Shape {
        let vertical: Bool
        let inset: CGFloat
        func path(in rect: CGRect) -> Path {
            var path = Path()
            if vertical {
                path.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - inset))
            } else {
                path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
            }
            return path
        }
    }
    struct HeroDivider: View {
        @Environment(\.theme) private var theme
        let configuration: DividerStyleConfiguration
        let keepsStockLabel: Bool

        var body: some View {
            switch configuration.axis {
            case .horizontal:
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    rule(vertical: false).frame(height: 2).frame(maxWidth: .infinity)
                    if let title = configuration.title {
                        if keepsStockLabel, let label = configuration.label {
                            label
                        } else {
                            Text(title).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).fixedSize()
                        }
                        rule(vertical: false).frame(height: 2).frame(maxWidth: .infinity)
                    }
                }
            case .vertical:
                rule(vertical: true).frame(width: 2).frame(maxHeight: .infinity)
            }
        }

        private func rule(vertical: Bool) -> some View {
            Rule(vertical: vertical, inset: 1)
                .stroke(theme.border(.borderHero),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: configuration.isDashed ? [2, 5] : []))
                .flipsForRightToLeftLayoutDirection(configuration.isDashed)
        }
    }

    return PreviewMatrix("DividerStyle", rtl: true) {
        PreviewCase("Custom style — solid") { DividerView().dividerStyle(HeroDividerStyle()) }
        PreviewCase("Custom style — dashed") { DividerView().dashed().dividerStyle(HeroDividerStyle()) }
        PreviewCase("Custom style — titled") { DividerView("OR").dividerStyle(HeroDividerStyle()) }
        PreviewCase("Custom lines, stock label") {
            DividerView("Stock label").dashed().dividerStyle(HeroDividerStyle(keepsStockLabel: true))
        }
        PreviewCase("Custom style — vertical") {
            HStack {
                Text("A"); DividerView().axis(.vertical); Text("B"); DividerView().axis(.vertical).dashed(); Text("C")
            }
            .frame(height: 24)
            .dividerStyle(HeroDividerStyle())
        }
        PreviewCase(".default — the stock look, dashed") { DividerView().dashed().dividerStyle(.default) }
        PreviewCase("Stock dashed — starts at the leading edge") { DividerView().dashed().frame(width: 102) }
    }
}
