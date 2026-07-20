//
//  ChartCanvasTests.swift
//  ThemeKitTests
//
//  Logic coverage for the Canvas chart family's iOS 15.6-floor renderer
//  plumbing (ADR-0007 — the Swift Charts DSL replacement): the automatic
//  "nice" y ticks, the merged categorical x domain, cumulative stacking,
//  monotone/linear path building, plot-geometry mapping, and the donut wedge
//  fractions/shape. Pixel output is pinned separately by the chart snapshots
//  (HeroUIGapSnapshotTests).
//

import SwiftUI
import XCTest
@testable import ThemeKit

final class ChartCanvasTests: XCTestCase {

    // MARK: Ticks

    func testNiceTicksPickNiceStepAndCoverDataMax() {
        XCTAssertEqual(ChartTicks.values(dataMax: 172), [0, 50, 100, 150, 200])
        XCTAssertEqual(ChartTicks.values(dataMax: 28), [0, 10, 20, 30])
        XCTAssertEqual(ChartTicks.values(dataMax: 100), [0, 50, 100])
    }

    func testNiceTicksTopAlwaysReachesDataMax() {
        for dataMax in [0.7, 3.0, 9.99, 42.0, 999.0, 12_345.0] {
            let ticks = ChartTicks.values(dataMax: dataMax)
            XCTAssertGreaterThanOrEqual(ticks.last ?? 0, dataMax, "Top tick must cover the data max \(dataMax).")
            XCTAssertEqual(ticks.first, 0, "The family's y scale is zero-based.")
        }
    }

    func testNiceTicksDegenerateInputsFallBackToUnitScale() {
        XCTAssertEqual(ChartTicks.values(dataMax: 0), [0, 1])
        XCTAssertEqual(ChartTicks.values(dataMax: -5), [0, 1])
        XCTAssertEqual(ChartTicks.values(dataMax: .nan), [0, 1])
    }

    // MARK: Categorical domain

    func testChartCategoriesMergeInFirstAppearanceOrder() {
        let series = [
            ChartSeries("A", [ChartPoint("Jan", 1), ChartPoint("Feb", 2)]),
            ChartSeries("B", [ChartPoint("Feb", 3), ChartPoint("Mar", 4)]),
        ]
        XCTAssertEqual(chartCategories(series), ["Jan", "Feb", "Mar"])
    }

    // MARK: Stacking

    func testStackingBandsAreCumulativeWithMissingPointsAsZero() {
        let series = [
            ChartSeries("A", [ChartPoint("Q1", 10), ChartPoint("Q2", 20)]),
            ChartSeries("B", [ChartPoint("Q1", 5)]),   // no Q2 mark
        ]
        let bands = ChartStacking.bands(series: series, categories: ["Q1", "Q2"])

        XCTAssertEqual(bands[0][0].bottom, 0)
        XCTAssertEqual(bands[0][0].top, 10)
        XCTAssertEqual(bands[1][0].bottom, 10)
        XCTAssertEqual(bands[1][0].top, 15)
        XCTAssertEqual(bands[1][1].bottom, 20, "A missing point stacks with zero height.")
        XCTAssertEqual(bands[1][1].top, 20)
        XCTAssertEqual(ChartStacking.maxTotal(series: series, categories: ["Q1", "Q2"]), 20)
    }

    // MARK: Paths

    func testLinearAndMonotonePathsSpanTheDataEndpoints() {
        let points = [CGPoint(x: 0, y: 100), CGPoint(x: 50, y: 20), CGPoint(x: 100, y: 60)]

        for path in [ChartLinePath.linear(points), ChartLinePath.monotone(points)] {
            let box = path.boundingRect
            XCTAssertEqual(box.minX, 0)
            XCTAssertEqual(box.maxX, 100)
            XCTAssertFalse(path.isEmpty)
        }
    }

    func testMonotoneSegmentsFlattenAtLocalExtrema() {
        // y dips then rises: the middle tangent must be 0 (no overshoot below
        // the data minimum — the Fritsch–Carlson property).
        let points = [CGPoint(x: 0, y: 100), CGPoint(x: 50, y: 20), CGPoint(x: 100, y: 60)]
        let segments = ChartLinePath.monotoneSegments(points)

        XCTAssertEqual(segments.count, 2)
        // Flat tangent at the extremum: the control point next to the middle
        // vertex stays at the vertex's own y.
        XCTAssertEqual(segments[0].c2.y, 20, accuracy: 0.001)
        XCTAssertEqual(segments[1].c1.y, 20, accuracy: 0.001)
        // And the curve never leaves the data envelope at the joint.
        XCTAssertGreaterThanOrEqual(segments[0].c2.y, 20)
    }

    func testAreaAndBandPathsClose() {
        let top = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 10)]
        let bottom = [CGPoint(x: 0, y: 80), CGPoint(x: 100, y: 60)]

        let area = ChartLinePath.area(top, baseline: 100, curved: false)
        XCTAssertTrue(area.contains(CGPoint(x: 50, y: 90)), "The wash fills down to the baseline.")

        for curved in [false, true] {
            let band = ChartLinePath.band(top: top, bottom: bottom, curved: curved)
            XCTAssertTrue(band.contains(CGPoint(x: 50, y: 50)), "The band fills between its edges (curved=\(curved)).")
            XCTAssertFalse(band.contains(CGPoint(x: 50, y: 95)), "Below the bottom edge is outside (curved=\(curved)).")
        }
    }

    // MARK: Plot geometry

    func testPlotGeometryMapsCategoriesAndValues() {
        let geom = ChartPlotGeometry(rect: CGRect(x: 0, y: 0, width: 300, height: 100),
                                     categories: ["Jan", "Feb", "Mar"],
                                     yTop: 200)

        XCTAssertEqual(geom.bandWidth, 100)
        XCTAssertEqual(geom.xCenter(0), 50)
        XCTAssertEqual(geom.xCenter(2), 250)
        XCTAssertEqual(geom.index(of: "Feb"), 1)
        XCTAssertNil(geom.index(of: "Apr"))
        XCTAssertEqual(geom.y(0), 100, "Zero sits on the baseline.")
        XCTAssertEqual(geom.y(200), 0, "The top tick sits on the plot's top edge.")
        XCTAssertEqual(geom.y(100), 50)
    }

    func testPlotGeometryGuardsDegenerateScale() {
        let geom = ChartPlotGeometry(rect: CGRect(x: 0, y: 0, width: 100, height: 100),
                                     categories: [], yTop: 0)
        XCTAssertEqual(geom.yTop, 1, "A zero domain falls back to the unit scale.")
        XCTAssertEqual(geom.bandWidth, 100, "No categories must not divide by zero.")
    }

    // MARK: Donut

    func testWedgeFractionsAreProportionalAndCoverTheTurn() {
        let fractions = DonutChart.wedgeFractions([
            ChartSlice("A", 50), ChartSlice("B", 30), ChartSlice("C", 20),
        ])

        XCTAssertEqual(fractions[0].start, 0)
        XCTAssertEqual(fractions[0].end, 0.5, accuracy: 0.0001)
        XCTAssertEqual(fractions[1].end, 0.8, accuracy: 0.0001)
        XCTAssertEqual(fractions[2].end, 1.0, accuracy: 0.0001)
        // Contiguous: each wedge starts where the previous ended.
        XCTAssertEqual(fractions[1].start, fractions[0].end)
        XCTAssertEqual(fractions[2].start, fractions[1].end)
    }

    func testWedgeFractionsZeroTotalCollapses() {
        let fractions = DonutChart.wedgeFractions([ChartSlice("A", 0)])
        XCTAssertEqual(fractions[0].start, 0)
        XCTAssertEqual(fractions[0].end, 0)
    }

    func testDonutWedgeShapeRingHasAHoleAndPieDoesNot() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let center = CGPoint(x: 50, y: 50)

        let ring = DonutWedgeShape(start: 0, end: 0.75, innerRatio: 0.6).path(in: rect)
        XCTAssertFalse(ring.isEmpty)
        XCTAssertFalse(ring.contains(center), "A ring wedge leaves the hole empty.")

        let pie = DonutWedgeShape(start: 0, end: 0.75, innerRatio: 0).path(in: rect)
        XCTAssertTrue(pie.contains(CGPoint(x: 60, y: 50)), "A pie wedge fills to the center.")
        XCTAssertFalse(ring.contains(CGPoint(x: 60, y: 50)), "The same point sits in the ring's hole.")

        let sliver = DonutWedgeShape(start: 0.5, end: 0.5001, innerRatio: 0.6).path(in: rect)
        _ = sliver   // thinner than the angular gap — must not crash or invert
    }
}
