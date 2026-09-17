//
//  TooltipStyleConfigurationTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  What a `TooltipStyle` is handed, and what it can do with it: the text,
//  content and `.tooltip(…)` arguments, the resolved motion flag, a working
//  dismiss action, and the public arrow shape. Plain `import ThemeKit`: a host
//  app writes these styles.
//

import XCTest
import SwiftUI
import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class TooltipStyleConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Configuration

    func testPlainTooltipHandsOverItsArguments() throws {
        let recorder = TooltipRecorder()
        let tooltip = anchor.tooltip("Checked bags aren't included.", isPresented: .constant(true),
                                     edge: .leading, align: .end, style: .warning, color: .info, maxWidth: 160)
        _ = render(stage(tooltip).tooltipStyle(RecordingTooltip(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.text, "Checked bags aren't included.")
        XCTAssertEqual(c.edge, .leading)
        XCTAssertEqual(c.align, .end)
        XCTAssertEqual(c.maxWidth, 160)
        XCTAssertEqual(c.style, .warning)
        XCTAssertEqual(c.color, .info)
        XCTAssertEqual(c.tint, .info, "color wins over style")
        XCTAssertEqual(c.arrowShape.edge, .leading)
        XCTAssertTrue(c.isMotionEnabled)
        XCTAssertNotNil(c.dismiss)
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = TooltipRecorder()
        _ = render(stage(anchor.tooltip("Hint", isPresented: .constant(true)))
            .tooltipStyle(RecordingTooltip(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.edge, .top)
        XCTAssertEqual(c.align, .center)
        XCTAssertNil(c.maxWidth)
        XCTAssertNil(c.style)
        XCTAssertNil(c.color)
        XCTAssertNil(c.tint, "no colour: the style picks its own surface")
    }

    func testStyleShorthandIsTheTintWithoutAColor() throws {
        let recorder = TooltipRecorder()
        _ = render(stage(anchor.tooltip("Hint", isPresented: .constant(true), style: .success))
            .tooltipStyle(RecordingTooltip(recorder: recorder)))
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).tint, .success)
    }

    /// The rich form hands over an empty `text`, and its slot as `content`:
    /// a style that draws `content` shows the slot, not the (empty) text.
    func testRichTooltipHandsOverItsSlot() throws {
        let recorder = TooltipRecorder()
        let slot = VStack(alignment: .leading) {
            Text("Installments")
            Text("Split the total into 3 payments.")
        }
        _ = render(stage(anchor.tooltip(isPresented: .constant(true), edge: .bottom) { slot })
            .tooltipStyle(RecordingTooltip(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.text, "")
        XCTAssertEqual(c.edge, .bottom)
        XCTAssertNotNil(c.dismiss)
        let drawn = try XCTUnwrap(pixels(ContentOnly(content: c.content)))
        XCTAssertTrue(drawn == (try XCTUnwrap(pixels(ContentOnly(content: AnyView(slot))))), "content is the slot")
        XCTAssertTrue(drawn != (try XCTUnwrap(pixels(ContentOnly(content: AnyView(Text("")))))), "control: an empty text draws nothing")
    }

    /// `content` carries no font or colour of its own: the style's type and
    /// colour reach the plain text.
    func testPlainContentTakesTheStylesTypeAndColour() throws {
        let recorder = TooltipRecorder()
        _ = render(stage(anchor.tooltip("Hint", isPresented: .constant(true)))
            .tooltipStyle(RecordingTooltip(recorder: recorder)))
        let content = try XCTUnwrap(recorder.values.last).content

        let styled = try XCTUnwrap(pixels(content.textStyle(.headingLg).foregroundStyle(Color.red)))
        let expected = try XCTUnwrap(pixels(Text("Hint").textStyle(.headingLg).foregroundStyle(Color.red)))
        XCTAssertTrue(styled == expected, "the style's type and colour reach the text")
        XCTAssertTrue(styled != (try XCTUnwrap(pixels(content))), "control: the type and colour change the render")
    }

    func testMotionFlagArrivesResolved() throws {
        let recorder = TooltipRecorder()
        let tooltip = stage(anchor.tooltip("Hint", isPresented: .constant(true)))
        _ = render(tooltip.tooltipStyle(RecordingTooltip(recorder: recorder)).microAnimations(false))
        XCTAssertFalse(try XCTUnwrap(recorder.values.last).isMotionEnabled, "microAnimations(false)")

        _ = render(tooltip.tooltipStyle(RecordingTooltip(recorder: recorder))
            .environment(\._accessibilityReduceMotion, true))
        XCTAssertFalse(try XCTUnwrap(recorder.values.last).isMotionEnabled, "Reduce Motion")

        _ = render(tooltip.tooltipStyle(RecordingTooltip(recorder: recorder)))
        XCTAssertTrue(try XCTUnwrap(recorder.values.last).isMotionEnabled, "motion on")
    }

    // MARK: Dismiss

    /// The configuration's `dismiss` writes `false` through the caller's
    /// binding, and the next render draws no bubble.
    func testDismissClosesTheBindingDrivenTooltip() throws {
        var isPresented = true
        let binding = Binding(get: { isPresented }, set: { isPresented = $0 })
        let recorder = TooltipRecorder()
        let view = stage(anchor.tooltip("Hint", isPresented: binding))
            .tooltipStyle(RecordingTooltip(recorder: recorder))

        _ = render(view)
        let shown = try XCTUnwrap(recorder.values.last, "the presented tooltip went through the style")
        let dismiss = try XCTUnwrap(shown.dismiss)
        dismiss()
        XCTAssertFalse(isPresented, "dismiss wrote through the binding")

        let calls = recorder.values.count
        _ = render(view)
        XCTAssertEqual(recorder.values.count, calls, "a dismissed tooltip isn't drawn")
    }

    func testDismissClosesTheRichTooltip() throws {
        var isPresented = true
        let binding = Binding(get: { isPresented }, set: { isPresented = $0 })
        let recorder = TooltipRecorder()
        _ = render(stage(anchor.tooltip(isPresented: binding) { Text("Rich") })
            .tooltipStyle(RecordingTooltip(recorder: recorder)))
        try XCTUnwrap(recorder.values.last?.dismiss)()
        XCTAssertFalse(isPresented)
    }

    /// A hidden tooltip never reaches the style.
    func testHiddenTooltipsDontReachTheStyle() {
        let recorder = TooltipRecorder()
        _ = render(VStack {
            anchor.tooltip("Hidden", isPresented: .constant(false))
            anchor.tooltip("Self-managed, not tapped")
            InputLabel("Email").infoTooltip("Shown on your profile.")
        }
        .padding(80)
        .tooltipStyle(RecordingTooltip(recorder: recorder)))
        XCTAssertTrue(recorder.values.isEmpty)
    }

    /// A style set before `.tooltip(…)` doesn't reach it (documented); the
    /// built-in bubble draws instead.
    func testStyleSetBeforeTheTooltipCallDoesNotReachIt() {
        let recorder = TooltipRecorder()
        _ = render(stage(anchor.tooltipStyle(RecordingTooltip(recorder: recorder))
            .tooltip("Hint", isPresented: .constant(true))))
        XCTAssertTrue(recorder.values.isEmpty)
    }

    /// A style's body is placed exactly where the built-in bubble goes: a
    /// style drawing the stock bubble in inverted colours changes the same
    /// pixel bounds as the built-in bubble, on every edge and alignment.
    func testStylePathIsPlacedLikeTheBuiltInBubble() throws {
        let placements: [(TooltipEdge, PopoverAlign)] = [
            (.top, .center), (.bottom, .center), (.leading, .center), (.trailing, .center),
            (.top, .start), (.bottom, .end), (.leading, .start), (.trailing, .end),
        ]
        for (edge, align) in placements {
            let label = "\(edge) \(align)"
            let hidden = try XCTUnwrap(bitmap(stage(anchor.tooltip("Hint", isPresented: .constant(false), edge: edge, align: align))))
            let tooltip = anchor.tooltip("Hint", isPresented: .constant(true), edge: edge, align: align)
            let builtIn = try XCTUnwrap(changedBounds(hidden, try XCTUnwrap(bitmap(stage(tooltip)))), label)
            let styled = changedBounds(hidden, try XCTUnwrap(bitmap(stage(tooltip).tooltipStyle(InvertedStockTooltip()))))
            XCTAssertEqual(styled, builtIn, "\(label): the style's body landed elsewhere")
            // Control: the same body moved by 4 pt must be caught.
            let nudged = changedBounds(hidden, try XCTUnwrap(bitmap(stage(tooltip).tooltipStyle(NudgedStockTooltip()))))
            XCTAssertNotEqual(nudged, builtIn, "\(label) (control): the comparison saw no move")
        }
    }

    /// A style returning its own card replaces the bubble.
    func testCustomStyleReplacesTheBubble() throws {
        let tooltip = anchor.tooltip("Hint", isPresented: .constant(true), edge: .bottom)
        let builtIn = try XCTUnwrap(bitmap(stage(tooltip)))
        let card = try XCTUnwrap(bitmap(stage(tooltip).tooltipStyle(CardTooltip())))
        XCTAssertEqual(builtIn.width, card.width)
        XCTAssertEqual(builtIn.height, card.height)
        XCTAssertTrue(builtIn.bytes != card.bytes, "the card replaced the bubble")
    }

    // MARK: Stock style + shape

    /// Compile-time: the stock style is `Sendable`, so one shared instance
    /// can be set on any number of tooltips.
    func testStockStyleIsSendableAndReusable() {
        requireSendable(SharedTooltipStyle.stock)
        XCTAssertNotNil(render(VStack(spacing: 60) {
            anchor.tooltip("One", isPresented: .constant(true)).tooltipStyle(SharedTooltipStyle.stock)
            anchor.tooltip("Two", isPresented: .constant(true)).tooltipStyle(SharedTooltipStyle.stock)
            anchor.tooltip("Three", isPresented: .constant(true)).tooltipStyle(.default)
        }.padding(80)))
    }

    private func requireSendable(_ style: some Sendable) {}

    /// The public shape points its apex back at the anchor.
    func testArrowShapePointsAtTheAnchor() {
        let rect = CGRect(x: 0, y: 0, width: 12, height: 12)
        func apex(_ edge: TooltipEdge) -> CGPoint? {
            var points: [CGPoint] = []
            TooltipArrowShape(edge: edge).path(in: rect).forEach { element in
                switch element {
                case .move(to: let p), .line(to: let p): points.append(p)
                default: break
                }
            }
            return points.count == 3 ? points[1] : nil
        }
        XCTAssertEqual(apex(.top), CGPoint(x: 6, y: 12), "bubble above → points down")
        XCTAssertEqual(apex(.bottom), CGPoint(x: 6, y: 0), "bubble below → points up")
        XCTAssertEqual(apex(.leading), CGPoint(x: 12, y: 6), "bubble before → points toward the end")
        XCTAssertEqual(apex(.trailing), CGPoint(x: 0, y: 6), "bubble after → points toward the start")
        XCTAssertEqual(TooltipArrowShape(edge: .bottom).edge, .bottom)
    }

    // MARK: Helpers

    private var anchor: some View {
        Rectangle().fill(Color.gray).frame(width: 24, height: 24)
    }

    private func stage(_ tooltip: some View) -> some View {
        tooltip.padding(.horizontal, 180).padding(.vertical, 80)
    }

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// Raw pixels, rendered twice and keeping the second (the first render of
    /// new glyphs can antialias a few bytes differently).
    private func pixels<V: View>(_ view: V) -> Data? {
        _ = render(view)
        return render(view)?.dataProvider?.data as Data?
    }

    /// The pixel rectangle (x, y, width, height) where two same-size bitmaps
    /// differ at all; `nil` when they're identical.
    private func changedBounds(
        _ lhs: (width: Int, height: Int, bytes: [UInt8]),
        _ rhs: (width: Int, height: Int, bytes: [UInt8])
    ) -> [Int]? {
        guard lhs.width == rhs.width, lhs.height == rhs.height else { return [-1] }
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<lhs.height {
            for x in 0..<lhs.width {
                let i = (y * lhs.width + x) * 4
                if lhs.bytes[i..<i + 4] != rhs.bytes[i..<i + 4] {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        return maxX < 0 ? nil : [minX, minY, maxX - minX + 1, maxY - minY + 1]
    }

    /// RGBA bytes, top row first, rendered twice and keeping the second.
    private func bitmap<V: View>(_ view: V) -> (width: Int, height: Int, bytes: [UInt8])? {
        _ = render(view)
        guard let image = render(view) else { return nil }
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
        return drawn ? (w, h, bytes) : nil
    }
}

// MARK: - Fixtures

@MainActor
private final class TooltipRecorder {
    var values: [TooltipStyleConfiguration] = []
}

private struct RecordingTooltip: TooltipStyle {
    let recorder: TooltipRecorder

    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return configuration.content
    }
}

/// A white card with a close button and the shared arrow shape.
private struct CardTooltip: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        VStack(spacing: -1) {
            configuration.arrowShape.fill(Color.white).frame(width: 16, height: 8)
            HStack {
                configuration.content.textStyle(.bodyBase500).foregroundStyle(Color.black)
                if let dismiss = configuration.dismiss {
                    Button(action: dismiss) { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Close"))
                }
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// The stock bubble with its colours inverted (same shape, same alpha).
private struct InvertedStockTooltip: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DefaultTooltipStyle().makeBody(configuration: configuration).colorInvert()
    }
}

/// The stock bubble drawn 4 pt to the side — the control for the placement check.
private struct NudgedStockTooltip: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DefaultTooltipStyle().makeBody(configuration: configuration).colorInvert().offset(x: 4)
    }
}

/// Lays `content` out alone at a fixed width, for pixel comparisons.
private struct ContentOnly: View {
    let content: AnyView
    var body: some View {
        content.frame(width: 240, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}

private enum SharedTooltipStyle {
    static let stock = DefaultTooltipStyle()
}
