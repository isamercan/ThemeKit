//
//  PriceTrendChartStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `PriceTrendChart` + `PriceTrendChartStyle`: the built-in path still draws the 1.12.0 pixels,
//  `DefaultPriceTrendChartStyle` draws that same look through `makeBody`,
//  `.priceTrendChartStyle(.default)` restores the built-in path, a custom style receives the
//  resolved configuration for every column, and the chart keeps the selection and the layout.
//
//  Taps aren't simulated: a unit-test host builds no accessibility tree and a SwiftUI gesture
//  hands out no trigger, so the selection — one `selection = i` shared by both render paths —
//  is checked through the binding it writes to, the way ADR-0009's testing strategy treats the
//  other tap-driven behaviour.
//
//  Deliberately a plain `import ThemeKit`: everything here must compile from a host app's point
//  of view.
//

import XCTest
import SwiftUI
import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class PriceTrendChartStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: - Rendering helpers

    private struct Bitmap: Equatable {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private func bitmap<V: View>(_ view: V, width: CGFloat = 320) -> Bitmap? {
        let renderer = ImageRenderer(content: view.frame(width: width).fixedSize(horizontal: false, vertical: true))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? Bitmap(width: w, height: h, bytes: bytes) : nil
    }

    /// `true` when the render carries more than one value — a fixture that draws nothing would
    /// let a pair of empty comparisons pass.
    private func drawsInk<V: View>(_ view: V) -> Bool {
        guard let map = bitmap(view), let first = map.bytes.first else { return false }
        return map.bytes.contains { $0 != first }
    }

    private func assertSamePixels<A: View, B: View>(
        _ a: A, _ b: B, _ message: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let lhs = bitmap(a), let rhs = bitmap(b) else {
            return XCTFail("\(message): failed to render", file: file, line: line)
        }
        XCTAssertEqual(lhs.width, rhs.width, "\(message): width", file: file, line: line)
        XCTAssertEqual(lhs.height, rhs.height, "\(message): height", file: file, line: line)
        guard lhs.bytes.count == rhs.bytes.count else { return }
        // ±3 per channel absorbs glyph rasterization noise between two renders; a real drift
        // (a colour, a moved bar, a changed height) is far larger.
        let differing = zip(lhs.bytes, rhs.bytes).filter { abs(Int($0) - Int($1)) > 3 }.count
        XCTAssertEqual(differing, 0, "\(message): \(differing) channel values differ", file: file, line: line)
    }

    /// The control for `assertSamePixels`: the same comparison must notice a real change.
    private func assertDifferentPixels<A: View, B: View>(
        _ a: A, _ b: B, _ message: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let lhs = bitmap(a), let rhs = bitmap(b) else {
            return XCTFail("\(message): failed to render", file: file, line: line)
        }
        guard lhs.width == rhs.width, lhs.height == rhs.height else { return }
        let differing = zip(lhs.bytes, rhs.bytes).filter { abs(Int($0) - Int($1)) > 3 }.count
        XCTAssertGreaterThan(differing, 0, "\(message): the comparison saw no difference", file: file, line: line)
    }

    // MARK: - Fixtures

    private var points: [PriceTrendPoint] {
        [PriceTrendPoint("13", sublabel: "Sal", price: 4300),
         PriceTrendPoint("14", sublabel: "Çar", price: 5900),
         PriceTrendPoint("15", sublabel: "Per", price: 10900),
         PriceTrendPoint("16", sublabel: "Cum", price: 6000)]
    }

    private func chart(selection: Int = 2, showsValues: Bool = true, scrollable: Bool = false)
    -> some View {   // swiftlint:disable:this identifier_name
        PriceTrendChart(points, selection: .constant(selection))
            .currency("TRY")
            .showsValues(showsValues)
            .scrollable(scrollable)
    }

    // MARK: - Built-in path

    func testBuiltInPathRenders() {
        XCTAssertTrue(drawsInk(chart()), "the chart renders blank")
        XCTAssertTrue(drawsInk(chart(showsValues: false)), "the chart renders blank without values")
        // A scrollable chart isn't checked here: `ImageRenderer` draws nothing inside a
        // horizontal `ScrollView` — on the built-in path too, so it is the renderer's limit and
        // not the chart's. Its columns are checked through the style instead (below).
    }

    // MARK: - Default style honesty

    /// The stock column through `makeBody` draws what the built-in path draws.
    func testDefaultStyleDrawsTheBuiltInLook() {
        for (name, view) in [("values", AnyView(chart())),
                             ("no values", AnyView(chart(showsValues: false))),
                             ("first selected", AnyView(chart(selection: 0)))] {
            assertSamePixels(view, view.priceTrendChartStyle(ForwardingColumnStyle()), name)
            // Control, same case: a forwarding style that changes one thing must be caught.
            assertDifferentPixels(view, view.priceTrendChartStyle(DimmedForwardingColumnStyle()),
                                  "\(name) (control)")
        }
    }

    func testExplicitDefaultRestoresTheBuiltInPath() {
        let view = chart()
        assertSamePixels(view,
                         view.priceTrendChartStyle(.default).priceTrendChartStyle(BlockColumnStyle()),
                         "under .default")
        // Control: without the `.default` in between, the outer custom style draws.
        assertDifferentPixels(view, view.priceTrendChartStyle(BlockColumnStyle()), "control")
    }

    func testACustomStyleReplacesEveryColumn() {
        assertDifferentPixels(chart(), chart().priceTrendChartStyle(BlockColumnStyle()),
                              "the custom columns look the same as the stock ones")
        XCTAssertTrue(drawsInk(chart().priceTrendChartStyle(BlockColumnStyle())))
    }

    // MARK: - Configuration

    func testTheStyleIsAskedForEveryColumnInOrder() {
        let seen = Box()
        _ = bitmap(chart(selection: 2).priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        // SwiftUI may evaluate a body more than once, so a column can be asked for twice; what
        // matters is which columns were asked for, and in what order.
        XCTAssertEqual(seen.columns.map(\.index), [0, 1, 2, 3], "the columns came in another order")
        XCTAssertEqual(seen.columns.map(\.point.label), ["13", "14", "15", "16"])
        XCTAssertEqual(seen.columns.map(\.isSelected), [false, false, true, false])
    }

    /// A scrollable chart still hands the style every column, whatever the renderer draws.
    func testAScrollableChartStillAsksForEveryColumn() {
        let seen = Box()
        _ = bitmap(chart(scrollable: true).priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        XCTAssertEqual(seen.columns.map(\.point.label), ["13", "14", "15", "16"])
    }

    func testTheConfigurationCarriesTheChartsMeasurements() throws {
        let seen = Box()
        _ = bitmap(chart(selection: 2).priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let tallest = try XCTUnwrap(seen.configurations.first { $0.point.label == "15" })
        let cheapest = try XCTUnwrap(seen.configurations.first { $0.point.label == "13" })
        XCTAssertEqual(tallest.fraction, 1, accuracy: 0.001, "the tallest point is the full height")
        XCTAssertEqual(cheapest.fraction, 4300.0 / 10900.0, accuracy: 0.001)
        XCTAssertGreaterThan(tallest.barHeight, cheapest.barHeight, "a dearer day draws a taller bar")
        XCTAssertGreaterThan(tallest.barAreaHeight, 0)
        XCTAssertGreaterThan(tallest.labelReserve, 0, "the day needs room under the bar")
        XCTAssertTrue(tallest.showsValues)
        XCTAssertTrue(tallest.priceText.contains("10"), "the price reaches the style formatted: \(tallest.priceText)")
    }

    /// `showsValues(false)` reaches the style, and takes the room over the bars with it.
    func testValuesOffReachesTheStyle() throws {
        let seen = Box()
        _ = bitmap(chart(showsValues: false).priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let column = try XCTUnwrap(seen.configurations.first)
        XCTAssertFalse(column.showsValues)
        XCTAssertEqual(column.valueReserve, 0)
    }

    /// A bar is never shorter than 6pt, however cheap the day.
    func testTheCheapestDayStillHasABar() throws {
        let seen = Box()
        let flat = [PriceTrendPoint("1", price: 1), PriceTrendPoint("2", price: 100_000)]
        _ = bitmap(PriceTrendChart(flat, selection: .constant(1))
                    .priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let cheapest = try XCTUnwrap(seen.configurations.first)
        XCTAssertEqual(cheapest.barHeight, 6, accuracy: 0.001)
    }

    /// The accent tokens reach the style rather than being resolved away.
    func testTheAccentsReachTheStyle() throws {
        let seen = Box()
        _ = bitmap(PriceTrendChart(points, selection: .constant(0))
                    .currency("TRY")
                    .accent(.success)
                    .selectionAccent(.error)
                    .priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let column = try XCTUnwrap(seen.configurations.first)
        XCTAssertEqual(column.accent, .success)
        XCTAssertEqual(column.selectionAccent, .error)
    }

    // MARK: - The host's own words (1.14.0)

    /// A point worded by its host reaches the style as those words, not as the number the chart
    /// measured its bar against. A fare calendar hands the chart "4.300 TL" and a height; before
    /// this the chart formatted the height and both the column and VoiceOver said the wrong price.
    func testTheHostsOwnWordsReachTheStyleInsteadOfTheNumber() throws {
        let seen = Box()
        let worded = [PriceTrendPoint("13", sublabel: "Çar", price: 43, priceText: "4.300 TL"),
                      PriceTrendPoint("14", sublabel: "Per", price: 109, priceText: "10.900 TL")]
        _ = bitmap(PriceTrendChart(worded, selection: .constant(0))
                    .priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let first = try XCTUnwrap(seen.configurations.first { $0.point.label == "13" })
        XCTAssertEqual(first.priceText, "4.300 TL")
        let second = try XCTUnwrap(seen.configurations.first { $0.point.label == "14" })
        XCTAssertEqual(second.priceText, "10.900 TL")
    }

    /// The words say what the day costs; the number still says how tall its bar stands. A host
    /// that has only words passes a measurement beside them, and the chart must keep using it.
    func testTheWordsDoNotChangeHowTallABarStands() throws {
        let seen = Box()
        let worded = [PriceTrendPoint("13", price: 43, priceText: "4.300 TL"),
                      PriceTrendPoint("14", price: 109, priceText: "10.900 TL")]
        _ = bitmap(PriceTrendChart(worded, selection: .constant(0))
                    .priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let short = try XCTUnwrap(seen.configurations.first { $0.point.label == "13" })
        let tall = try XCTUnwrap(seen.configurations.first { $0.point.label == "14" })
        XCTAssertEqual(tall.fraction, 1, accuracy: 0.001)
        XCTAssertEqual(short.fraction, 43.0 / 109.0, accuracy: 0.001)
        XCTAssertGreaterThan(tall.barHeight, short.barHeight)
    }

    /// A point with no words of its own formats its number, exactly as every chart did before.
    func testAPointWithoutWordsStillFormatsItsNumber() throws {
        let seen = Box()
        _ = bitmap(PriceTrendChart(points, selection: .constant(0))
                    .currency("TRY")
                    .priceTrendChartStyle(RecordingColumnStyle(box: seen)))
        let column = try XCTUnwrap(seen.configurations.first)
        XCTAssertNil(column.point.priceText, "nothing was worded")
        XCTAssertTrue(column.priceText.contains("4"), "the number was formatted: \(column.priceText)")
    }

    /// The built-in column draws the words too — without a style set, the value over the selected
    /// bar is the host's own text, so the drawing and the announcement agree.
    func testTheBuiltInColumnDrawsTheWords() throws {
        let worded = [PriceTrendPoint("13", price: 43, priceText: "SOLD OUT"),
                      PriceTrendPoint("14", price: 109, priceText: "10.900 TL")]
        let plain = [PriceTrendPoint("13", price: 43),
                     PriceTrendPoint("14", price: 109)]
        let withWords = try XCTUnwrap(bitmap(PriceTrendChart(worded, selection: .constant(0)).showsValues()))
        let withNumbers = try XCTUnwrap(bitmap(PriceTrendChart(plain, selection: .constant(0)).showsValues()))
        XCTAssertNotEqual(withWords, withNumbers, "the column drew the number instead of the words")
    }
}

// MARK: - Test styles

/// Hands every column back to the stock one: the style path must draw what the built-in path draws.
@available(iOS 16.0, macOS 13.0, *)
private struct ForwardingColumnStyle: PriceTrendChartStyle {
    func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
        DefaultPriceTrendChartStyle().makeBody(configuration: configuration)
    }
}

/// The control for the forwarding style: the same body, one thing changed.
@available(iOS 16.0, macOS 13.0, *)
private struct DimmedForwardingColumnStyle: PriceTrendChartStyle {
    func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
        DefaultPriceTrendChartStyle().makeBody(configuration: configuration).opacity(0.5)
    }
}

/// A column that shares no pixels with the stock one.
@available(iOS 16.0, macOS 13.0, *)
private struct BlockColumnStyle: PriceTrendChartStyle {
    func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(configuration.isSelected ? Color.red : Color.green)
                .frame(height: configuration.barHeight)
            Text(configuration.point.label)
                .frame(height: configuration.labelReserve, alignment: .top)
        }
    }
}

/// Keeps every configuration it was handed, in order.
@available(iOS 16.0, macOS 13.0, *)
private final class Box: @unchecked Sendable {
    var configurations: [PriceTrendChartStyleConfiguration] = []

    /// One configuration per column, in the order they were first asked for — SwiftUI may
    /// evaluate a body more than once, and a repeat says nothing about the chart.
    var columns: [PriceTrendChartStyleConfiguration] {
        var seen = Set<Int>()
        return configurations.filter { seen.insert($0.index).inserted }
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RecordingColumnStyle: PriceTrendChartStyle {
    let box: Box

    func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
        box.configurations.append(configuration)
        return Color.clear.frame(height: 40)
    }
}
