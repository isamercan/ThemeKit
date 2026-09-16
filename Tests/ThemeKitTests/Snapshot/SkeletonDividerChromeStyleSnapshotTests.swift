//
//  SkeletonDividerChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for the 1.5.0 style path of `Skeleton`
//  (`SkeletonStyle`) and `DividerView` (`DividerStyle`): custom styles, the
//  explicit `.default` style (must match the stock references), a container
//  style reaching ThemeKit's own placeholders and separators, and the dashed
//  divider under RTL (the one intended visual change: its pattern now starts
//  at the leading edge).
//
//  Stock skeletons render with `.microAnimations(false)` so every capture is
//  the static fill, whatever the settle pass does to a running loop.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class SkeletonDividerChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: - Styles under test

    /// A static placeholder: the outline filled with the highlight's soft
    /// shade (neutral by default) and a hero hairline.
    private struct OutlinedSkeletonStyle: SkeletonStyle {
        func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
            OutlinedSkeleton(configuration: configuration)
        }
    }

    private struct OutlinedSkeleton: View {
        @Environment(\.theme) private var theme
        let configuration: SkeletonStyleConfiguration

        var body: some View {
            configuration.shape.anyShape
                .fill(theme.resolve(configuration.highlight ?? .neutral).soft)
                .overlay(configuration.shape.anyShape.stroke(theme.border(.borderHero), lineWidth: 1))
        }
    }

    /// Hero 2 pt rules — dashed 2-on-5 with round caps, flipped for RTL — and a
    /// body-type title (or the stock label when `keepsStockLabel`).
    private struct HeroDividerStyle: DividerStyle {
        var keepsStockLabel = false
        func makeBody(configuration: DividerStyleConfiguration) -> some View {
            HeroDivider(configuration: configuration, keepsStockLabel: keepsStockLabel)
        }
    }

    private struct HeroRule: Shape {
        let vertical: Bool
        func path(in rect: CGRect) -> Path {
            var path = Path()
            if vertical {
                path.move(to: CGPoint(x: rect.midX, y: rect.minY + 1))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
            } else {
                path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.midY))
            }
            return path
        }
    }

    private struct HeroDivider: View {
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
            HeroRule(vertical: vertical)
                .stroke(theme.border(.borderHero),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: configuration.isDashed ? [2, 5] : []))
                .flipsForRightToLeftLayoutDirection(configuration.isDashed)
        }
    }

    // MARK: - Fixtures

    private var skeletonBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Skeleton(.circle).size(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 8) {
                    Skeleton(.capsule).size(width: 160, height: 12)
                    Skeleton(.capsule).size(width: 100, height: 12)
                }
            }
            Skeleton(.rounded(.box)).size(height: 64)
            Skeleton(.rounded(.field)).highlight(.info).size(width: 200, height: 32)
            Text("Modifier-applied placeholder").skeleton(true, radius: .selector)
        }
    }

    private var dividers: some View {
        VStack(alignment: .leading, spacing: 16) {
            DividerView().size(.small)
            DividerView().size(.large)
            DividerView().dashed()
            DividerView("OR")
            DividerView("Leading").titleAlign(.leading).dashed()
            DividerView("Trailing").titleAlign(.trailing)
            HStack {
                Text("A"); DividerView().axis(.vertical); Text("B"); DividerView().axis(.vertical).dashed(); Text("C")
            }
            .frame(height: 24)
        }
    }

    // MARK: - SkeletonStyle

    func testSkeletonStyle_custom() {
        assertComponentSnapshot(skeletonBlocks.skeletonStyle(OutlinedSkeletonStyle()))
    }

    func testSkeletonStyle_custom_dark() {
        assertComponentSnapshot(skeletonBlocks.skeletonStyle(OutlinedSkeletonStyle()), colorScheme: .dark)
    }

    /// Must match `testSkeletonStyle_stock` pixel for pixel.
    func testSkeletonStyle_default() {
        assertComponentSnapshot(skeletonBlocks.skeletonStyle(.default).microAnimations(false))
    }

    func testSkeletonStyle_stock() {
        assertComponentSnapshot(skeletonBlocks.microAnimations(false))
    }

    func testSkeletonStyle_containerReachesThemeKitPlaceholders() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Card("Loading card") { EmptyView() }.loading()
                SkeletonGroup {
                    Text("Group-driven title").textStyle(.headingSm).skeleton()
                    Text("Group-driven line").skeleton(shape: .capsule)
                }
                .loading()
            }
            .skeletonStyle(OutlinedSkeletonStyle())
        )
    }

    // MARK: - DividerStyle

    func testDividerStyle_custom() {
        assertComponentSnapshot(dividers.dividerStyle(HeroDividerStyle()))
    }

    func testDividerStyle_custom_rtl() {
        assertComponentSnapshot(dividers.dividerStyle(HeroDividerStyle()), layoutDirection: .rightToLeft)
    }

    func testDividerStyle_customLines_stockLabel() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                DividerView("Stock label")
                DividerView("Stock label, dashed").dashed()
            }
            .dividerStyle(HeroDividerStyle(keepsStockLabel: true))
        )
    }

    /// Must match `testDividerStyle_stock` pixel for pixel.
    func testDividerStyle_default() {
        assertComponentSnapshot(dividers.dividerStyle(.default))
    }

    func testDividerStyle_stock() {
        assertComponentSnapshot(dividers)
    }

    /// Intended change: the stock dashed pattern starts at the leading (right)
    /// edge under RTL. Solid lines and titles are unchanged.
    func testDividerView_stock_rtl() {
        assertComponentSnapshot(dividers, layoutDirection: .rightToLeft)
    }

    func testDividerStyle_containerReachesThemeKitSeparators() {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                Card("Header rule") {
                    Text("Body").textStyle(.bodyBase400)
                }
                .footer { Text("Footer rule").textStyle(.bodySm400) }
                VStack(spacing: 0) {
                    FilterRow("Direct", isOn: .constant(true)).count(128).showsSeparator()
                    FilterRow("1 stop", isOn: .constant(false)).count(64)
                }
            }
            .dividerStyle(HeroDividerStyle())
        )
    }
}
#endif
