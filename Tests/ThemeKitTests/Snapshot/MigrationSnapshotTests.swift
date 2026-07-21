//
//  MigrationSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the components reimplemented by the iOS
//  15.6-floor migration (ADR-0007): GaugeView (native `Gauge` → token-fed
//  ring/bar `Path` drawing), the measured-layout trio FlowLayout / Masonry /
//  Flex (custom `Layout` → `_VariadicView` + `MeasuredLayoutSupport` probes —
//  exactly the settle-then-size case SnapshotSupport exists for), and
//  BoardingPass (`Grid` → paired rows).
//
//  Determinism rules for THIS suite (the pinned simulator runs tr-TR, so any
//  locale leak bakes Turkish into the reference):
//  - Every test pins `\.locale` to en_US — GaugeView formats its percent
//    readout from the environment locale (tr_TR renders "%66", en_US "66%").
//  - All other inputs are literal ASCII strings and integer/fixed values — no
//    `Date`, no formatters. BoardingPass takes pre-formatted display strings
//    by design; its Code-128 barcode is CoreImage-generated and rendered with
//    `.interpolation(.none)` (bit-exact).
//  - LocationCard is deliberately NOT snapshotted: `MKMapSnapshotter` loads
//    async network tiles, which are non-deterministic by construction.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
@testable import ThemeKitTravel

@MainActor
final class MigrationSnapshotTests: SnapshotTestCase {

    /// Pinned formatting locale — see the header note.
    private let en = Locale(identifier: "en_US")

    // MARK: - GaugeView (ring/bar drawing replaced the iOS 16 native Gauge)

    func testGaugeView_circular() {
        assertComponentSnapshot(
            GaugeView(value: 0.66, label: "Load")
                .environment(\.locale, en)
        )
    }

    func testGaugeView_circular_dark() {
        assertComponentSnapshot(
            GaugeView(value: 0.66, label: "Load")
                .environment(\.locale, en),
            colorScheme: .dark
        )
    }

    func testGaugeView_linear() {
        assertComponentSnapshot(
            GaugeView(value: 0.66, label: "Storage")
                .gaugeStyle(.linear)
                .environment(\.locale, en)
        )
    }

    // MARK: - FlowLayout (measured rows replaced the iOS 16 custom Layout)

    func testFlowLayout_wrappingTags() {
        assertComponentSnapshot(
            FlowLayout {
                ForEach(0..<8, id: \.self) { Tag("Tag \($0)") }
            }
            .environment(\.locale, en)
        )
    }

    // MARK: - Flex (measured justify/align replaced the iOS 16 custom Layout)

    func testFlex_justifyMatrix() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 16) {
                Flex { ForEach(0..<3, id: \.self) { Tag("Tag \($0)") } }
                Flex { ForEach(0..<3, id: \.self) { Tag("Tag \($0)") } }.justify(.center)
                Flex { ForEach(0..<3, id: \.self) { Tag("Tag \($0)") } }.justify(.end)
                Flex { ForEach(0..<3, id: \.self) { Tag("Tag \($0)") } }.justify(.spaceBetween)
            }
            .environment(\.locale, en)
        )
    }

    // MARK: - Masonry (measured shortest-column packing replaced the Layout)

    func testMasonry_threeColumns() {
        let heights: [CGFloat] = [90, 140, 70, 120, 100, 160, 80, 110]
        assertComponentSnapshot(
            Masonry {
                ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value)
                        .fill(SemanticColor.primary.soft)
                        .frame(height: height)
                        .overlay(Text("\(index)").textStyle(.labelBase700))
                }
            }
            .columns(3)
            .environment(\.locale, en)
        )
    }

    // MARK: - BoardingPass (paired rows replaced the iOS 16 Grid)

    func testBoardingPass_classic() {
        assertComponentSnapshot(
            BoardingPass(passenger: "Jordan Lee", from: "SAW", to: "BER")
                .airline("Sunrise Air").flightNo("SA 1234").cabin("Economy")
                .cities(from: "Istanbul", to: "Berlin")
                .times(departure: "13:15", arrival: "16:05")
                .date("13 Sep")   // literal, pre-formatted — never a Date
                .gate("A12", seat: "14C", boarding: "12:45", terminal: "1")
                .bookingRef("PNR: X7K2QF")
                .barcode("SA1234SAWBER14C")
                .environment(\.locale, en)
        )
    }
}
#endif
