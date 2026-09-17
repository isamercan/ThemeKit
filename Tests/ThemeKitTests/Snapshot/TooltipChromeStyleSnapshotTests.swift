//
//  TooltipChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  Visual-regression coverage for the `TooltipStyle` path: a custom card
//  (title, body and a close button on a bordered white surface, with the
//  configuration's arrow) and its dark variant on all four edges, the card in
//  RTL and in the dark scheme, plain-text and tinted tooltips in the card, and
//  the explicit `.default` style.
//
//  Each case presents a real `.tooltip(…)` once to capture the configuration
//  ThemeKit hands the style (under the case's layout direction, so the arrow
//  arrives turned), then draws the style's body beside an anchor glyph on the
//  configuration's edge. Placement itself is pinned by
//  `TooltipStyleConfigurationTests` (the style path lands where the built-in
//  bubble does).
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@available(iOS 16.0, *)
@MainActor
final class TooltipChromeStyleSnapshotTests: SnapshotTestCase {

    func testCustomCard_edges() {
        assertComponentSnapshot(edgeMatrix(SnapshotTooltipCard(tone: .light), direction: .leftToRight))
    }
    func testCustomCard_edges_rtl() {
        assertComponentSnapshot(edgeMatrix(SnapshotTooltipCard(tone: .light), direction: .rightToLeft),
                                layoutDirection: .rightToLeft)
    }
    func testCustomCard_edges_darkScheme() {
        assertComponentSnapshot(edgeMatrix(SnapshotTooltipCard(tone: .light), direction: .leftToRight),
                                colorScheme: .dark)
    }
    func testCustomDarkCard_edges() {
        assertComponentSnapshot(edgeMatrix(SnapshotTooltipCard(tone: .dark), direction: .leftToRight))
    }
    func testCustomDarkCard_edges_rtl() {
        assertComponentSnapshot(edgeMatrix(SnapshotTooltipCard(tone: .dark), direction: .rightToLeft),
                                layoutDirection: .rightToLeft)
    }
    func testCustomCard_plainTextAndTints() {
        let tooltips: [AnyView] = [
            AnyView(anchor.tooltip("Seats are assigned at check-in.", isPresented: .constant(true), edge: .bottom)),
            AnyView(anchor.tooltip("Checked bags are not included in this fare.", isPresented: .constant(true),
                                   edge: .top, color: .warning, maxWidth: 200)),
            AnyView(anchor.tooltip("Free cancellation until 24 hours before departure.", isPresented: .constant(true),
                                   edge: .trailing, style: .success, maxWidth: 200)),
        ]
        assertComponentSnapshot(presented(tooltips, style: SnapshotTooltipCard(tone: .light), direction: .leftToRight))
    }
    func testDefaultStyleExplicit_edges() {
        let tooltips: [AnyView] = [
            AnyView(anchor.tooltip("Above the anchor", isPresented: .constant(true), edge: .top)),
            AnyView(anchor.tooltip("Below the anchor", isPresented: .constant(true), edge: .bottom, style: .info)),
            AnyView(anchor.tooltip("Before the anchor", isPresented: .constant(true), edge: .leading, color: .primary)),
            AnyView(anchor.tooltip(isPresented: .constant(true), edge: .trailing) { cardContent("After the anchor") }),
        ]
        assertComponentSnapshot(presented(tooltips, style: DefaultTooltipStyle(), direction: .leftToRight))
    }

    // MARK: Fixture layout

    /// The card on each edge: rich title + body, one of them tinted.
    private func edgeMatrix(_ style: SnapshotTooltipCard, direction: LayoutDirection) -> some View {
        presented([
            AnyView(anchor.tooltip(isPresented: .constant(true), edge: .top, maxWidth: 220) { cardContent("Above the anchor") }),
            AnyView(anchor.tooltip(isPresented: .constant(true), edge: .bottom, color: .info, maxWidth: 220) {
                cardContent("Below the anchor")
            }),
            AnyView(anchor.tooltip(isPresented: .constant(true), edge: .leading, maxWidth: 220) { cardContent("Before the anchor") }),
            AnyView(anchor.tooltip(isPresented: .constant(true), edge: .trailing, maxWidth: 220) { cardContent("After the anchor") }),
        ], style: style, direction: direction)
    }

    /// Presents each tooltip once under `direction` to capture its
    /// configuration, then lays out `style`'s body for each one beside an
    /// anchor glyph on the configuration's edge.
    private func presented<S: TooltipStyle>(_ tooltips: [AnyView], style: sending S, direction: LayoutDirection) -> some View {
        var configurations: [TooltipStyleConfiguration] = []
        for tooltip in tooltips {
            let recorder = SnapshotTooltipRecorder()
            let renderer = ImageRenderer(content: tooltip
                .tooltipStyle(SnapshotRecordingTooltip(recorder: recorder))
                .environment(\.layoutDirection, direction))
            _ = renderer.cgImage
            guard let configuration = recorder.values.last else {
                XCTFail("a presented tooltip didn't reach the style")
                continue
            }
            configurations.append(configuration)
        }
        let drawn = AnyTooltipStyle(style)
        return VStack(spacing: 20) {
            ForEach(Array(configurations.enumerated()), id: \.offset) { _, configuration in
                SnapshotTooltipPlacement(edge: configuration.edge, bubble: drawn.makeBody(configuration: configuration))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cardContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold)
            Text("One cabin bag up to 8 kg is included.")
        }
    }

    private var anchor: some View { SnapshotTooltipAnchor() }
}

/// A bubble next to an anchor glyph, stacked along its edge with the kit's
/// `sm` gap: above, below, before or after the anchor.
private struct SnapshotTooltipPlacement: View {
    let edge: TooltipEdge
    let bubble: AnyView

    var body: some View {
        let gap = Theme.SpacingKey.sm.value
        switch edge {
        case .top: VStack(spacing: gap) { bubble; SnapshotTooltipAnchor() }
        case .bottom: VStack(spacing: gap) { SnapshotTooltipAnchor(); bubble }
        case .leading: HStack(spacing: gap) { bubble; SnapshotTooltipAnchor() }
        case .trailing: HStack(spacing: gap) { SnapshotTooltipAnchor(); bubble }
        }
    }
}

/// A 24 pt info glyph in the hero colour, resolved when it renders (so the
/// dark-scheme case paints it from the dark palette).
private struct SnapshotTooltipAnchor: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 20))
            .foregroundStyle(theme.foreground(.fgHero))
            .frame(width: 24, height: 24)
    }
}

@MainActor
private final class SnapshotTooltipRecorder {
    var values: [TooltipStyleConfiguration] = []
}

private struct SnapshotRecordingTooltip: TooltipStyle {
    let recorder: SnapshotTooltipRecorder

    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return EmptyView()
    }
}

// MARK: - Fixture style

/// A bordered card with a close button: white (light) or the stock dark
/// surface (dark), `box`-radius corners, the content in `bodySm400`, and the
/// configuration's arrow filled and stroked like the popconfirm card's. A
/// tint colours the border.
private struct SnapshotTooltipCard: TooltipStyle {
    enum Tone { case light, dark }
    let tone: Tone

    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        SnapshotTooltipCardBody(configuration: configuration, tone: tone)
    }
}

private struct SnapshotTooltipCardBody: View {
    let configuration: TooltipStyleConfiguration
    let tone: SnapshotTooltipCard.Tone
    @Environment(\.theme) private var theme

    var body: some View {
        let surface = tone == .light ? theme.background(.bgWhite) : theme.background(.bgTertiary)
        let stroke = configuration.tint.map { theme.resolve($0).border }
            ?? (tone == .light ? theme.border(.borderPrimary) : theme.background(.bgTertiary))
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)

        let card = HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            configuration.content
                .textStyle(.bodySm400)
                .foregroundStyle(tone == .light ? theme.text(.textPrimary) : theme.background(.bgWhite))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let dismiss = configuration.dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle().inset(by: -12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(tone == .light ? theme.text(.textTertiary) : theme.text(.textSecondaryInverse))
                .accessibilityLabel(Text("Close"))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(width: configuration.maxWidth ?? 240)
        .background(surface, in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 1))

        let vertical = configuration.edge == .top || configuration.edge == .bottom
        let arrow = configuration.arrowShape.fill(surface)
            .overlay(configuration.arrowShape.stroke(stroke, lineWidth: 1))
            .frame(width: vertical ? 16 : 8, height: vertical ? 8 : 16)
            .zIndex(1)

        switch configuration.edge {
        case .top: VStack(spacing: -1) { card; arrow }
        case .bottom: VStack(spacing: -1) { arrow; card }
        case .leading: HStack(spacing: -1) { card; arrow }
        case .trailing: HStack(spacing: -1) { arrow; card }
        }
    }
}
#endif
