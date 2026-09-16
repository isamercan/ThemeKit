//
//  DividerStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `DividerStyle` (1.5.0) and the dashed-divider RTL fix:
//
//  - the stock path still renders, and `.dividerStyle(.default)` draws the same
//    pixels as the untouched environment for every axis / dash / size / title;
//  - a custom style receives the divider's title, stock label and axes, and
//    ThemeKit's own dividers (Card, FilterRow) pick up a container style;
//  - a dashed divider is pixel-identical to the v1.4.0 recipe in LTR and its
//    mirror image in RTL; a solid one doesn't change under RTL.
//
//  Two renders of the same view can differ by ±1 in a few antialiased pixels
//  (text edges), so pixel comparisons allow a small per-channel tolerance.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class DividerStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: - Probes

    @MainActor
    private final class Recorder {
        var configurations: [DividerStyleConfiguration] = []
    }

    private struct RecordingDividerStyle: DividerStyle {
        let recorder: Recorder
        func makeBody(configuration: DividerStyleConfiguration) -> some View {
            recorder.configurations.append(configuration)
            return Color.clear.frame(height: 1)
        }
    }

    /// Draws only the stock label a configuration carries.
    private struct LabelOnlyDividerStyle: DividerStyle {
        func makeBody(configuration: DividerStyleConfiguration) -> some View {
            configuration.label
        }
    }

    private struct HeroRuleDividerStyle: DividerStyle {
        func makeBody(configuration: DividerStyleConfiguration) -> some View {
            HeroRule()
        }
    }

    private struct HeroRule: View {
        @Environment(\.theme) private var theme
        var body: some View { Rectangle().fill(theme.border(.borderHero)).frame(height: 2) }
    }

    /// The v1.4.0 dashed-line recipe, verbatim: a mid-height path from minX to
    /// maxX stroked 1 pt, 4-on-4, with no RTL flip.
    private struct V140Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }

    private var v140Dashed: some View {
        V140Line()
            .stroke(Theme.shared.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Default path

    private var stockCases: [(String, AnyView)] {
        [
            ("solid small", AnyView(DividerView().size(.small))),
            ("solid medium", AnyView(DividerView().size(.medium))),
            ("solid large", AnyView(DividerView().size(.large))),
            ("dashed", AnyView(DividerView().dashed())),
            ("titled center", AnyView(DividerView("OR"))),
            ("titled leading", AnyView(DividerView("Left").titleAlign(.leading))),
            ("titled trailing dashed", AnyView(DividerView("Right").titleAlign(.trailing).dashed())),
            ("vertical", AnyView(HStack { Text("A"); DividerView().axis(.vertical); Text("B") }.frame(height: 24))),
            ("vertical dashed", AnyView(HStack { Text("A"); DividerView().axis(.vertical).dashed(); Text("B") }.frame(height: 24))),
        ]
    }

    func testStockDividersStillRender() {
        for (name, divider) in stockCases {
            XCTAssertNotNil(pixels(divider), name)
        }
    }

    func testDefaultStyleDrawsTheStockPixels() throws {
        for (name, divider) in stockCases {
            let stock = try XCTUnwrap(pixels(divider), name)
            let viaDefault = try XCTUnwrap(pixels(divider.dividerStyle(.default)), name)
            XCTAssertTrue(matches(stock, viaDefault), "\(name): .dividerStyle(.default) must draw the stock divider")
        }
    }

    func testCustomStyleReplacesTheStockPaint() throws {
        let stock = try XCTUnwrap(pixels(DividerView()))
        let custom = try XCTUnwrap(pixels(DividerView().dividerStyle(HeroRuleDividerStyle())))
        XCTAssertFalse(matches(stock, custom))
    }

    // MARK: - Configuration

    func testCustomStyleReceivesTheDividersInputs() throws {
        let recorder = Recorder()
        render(VStack {
            DividerView()
            DividerView("OR").titleAlign(.trailing).dashed().size(.large)
            DividerView().axis(.vertical).size(.medium)
        }
        .dividerStyle(RecordingDividerStyle(recorder: recorder)))

        // SwiftUI doesn't promise an evaluation order for siblings — find each by content.
        let seen = recorder.configurations
        let bare = try XCTUnwrap(seen.first { $0.axis == .horizontal && $0.title == nil })
        XCTAssertNil(bare.label, "a bare divider has no label")
        XCTAssertFalse(bare.isDashed)
        XCTAssertEqual(bare.size, .small)
        XCTAssertEqual(bare.titleAlignment, .center)

        let titled = try XCTUnwrap(seen.first { $0.title == "OR" })
        XCTAssertNotNil(titled.label)
        XCTAssertEqual(titled.axis, .horizontal)
        XCTAssertTrue(titled.isDashed)
        XCTAssertEqual(titled.size, .large)
        XCTAssertEqual(titled.titleAlignment, .trailing)

        let vertical = try XCTUnwrap(seen.first { $0.axis == .vertical })
        XCTAssertNil(vertical.title)
        XCTAssertFalse(vertical.isDashed)
        XCTAssertEqual(vertical.size, .medium)
    }

    func testLabelIsTheStockTitle() throws {
        let label = try XCTUnwrap(pixels(DividerView("OR").dividerStyle(LabelOnlyDividerStyle())))
        let stockTitle = try XCTUnwrap(pixels(
            Text("OR")
                .textStyle(.labelSm600)
                .foregroundStyle(Theme.shared.text(.textTertiary))
                .fixedSize()
        ))
        XCTAssertTrue(matches(label, stockTitle))
    }

    func testThemeKitDividersPickUpTheEnvironmentStyle() {
        let card = Recorder()
        render(Card("Trip") { Text("Body") }
            .dividerStyle(RecordingDividerStyle(recorder: card)))
        XCTAssertFalse(card.configurations.isEmpty, "Card's header rule is a DividerView")

        let row = Recorder()
        render(FilterRow("Direct", isOn: .constant(true))
            .showsSeparator()
            .dividerStyle(RecordingDividerStyle(recorder: row)))
        XCTAssertEqual(row.configurations.first?.size, .small)
        XCTAssertEqual(row.configurations.first?.axis, .horizontal)
    }

    // MARK: - RTL

    func testDashedDividerIsUnchangedInLTRAndMirroredInRTL() throws {
        // 102 pt is not a multiple of the 8 pt dash period, so the pattern is asymmetric.
        let width: CGFloat = 102
        let ltrOld = try XCTUnwrap(bitmap(v140Dashed.frame(width: width), direction: .leftToRight))
        let ltrNew = try XCTUnwrap(bitmap(DividerView().dashed().frame(width: width), direction: .leftToRight))
        let rtlNew = try XCTUnwrap(bitmap(DividerView().dashed().frame(width: width), direction: .rightToLeft))

        XCTAssertTrue(ltrNew.matches(ltrOld), "LTR pixels match the v1.4.0 dashed line")
        XCTAssertFalse(rtlNew.matches(ltrOld), "the dash pattern is asymmetric at this width")
        XCTAssertTrue(rtlNew.matches(ltrOld.mirrored()), "RTL starts the pattern at the leading (right) edge")
    }

    func testSolidDividerDoesNotChangeUnderRTL() throws {
        let ltr = try XCTUnwrap(bitmap(DividerView().frame(width: 102), direction: .leftToRight))
        let rtl = try XCTUnwrap(bitmap(DividerView().frame(width: 102), direction: .rightToLeft))
        XCTAssertTrue(ltr.matches(rtl))
    }

    // MARK: - Rendering helpers

    /// Same size, and no channel of any pixel more than `tolerance` apart.
    private func matches(_ lhs: Data, _ rhs: Data, tolerance: UInt8 = 2) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { max($0, $1) - min($0, $1) <= tolerance }
    }

    private func render(_ view: some View) {
        _ = pixels(view)
    }

    private func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: 220).padding(4).background(Color.white))
        renderer.scale = 2
        return renderer.cgImage?.dataProvider?.data as Data?
    }

    /// RGBA8 pixels in a fixed sRGB layout, so rows can be mirrored and compared.
    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func matches(_ other: Bitmap, tolerance: UInt8 = 2) -> Bool {
            guard width == other.width, height == other.height else { return false }
            return zip(bytes, other.bytes).allSatisfy { max($0, $1) - min($0, $1) <= tolerance }
        }

        func mirrored() -> Bitmap {
            var out = bytes
            for y in 0..<height {
                for x in 0..<width {
                    let src = (y * width + x) * 4
                    let dst = (y * width + (width - 1 - x)) * 4
                    for c in 0..<4 { out[dst + c] = bytes[src + c] }
                }
            }
            return Bitmap(width: width, height: height, bytes: out)
        }
    }

    private func bitmap(_ view: some View, direction: LayoutDirection) -> Bitmap? {
        let renderer = ImageRenderer(content: view
            .background(Color.white)
            .environment(\.layoutDirection, direction))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Bitmap(width: width, height: height, bytes: bytes) : nil
    }
}
