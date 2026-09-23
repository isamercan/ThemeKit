//
//  ToggleChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `ThemeToggle` + `ToggleChromeStyle`: the built-in path still draws the
//  1.11.0 pixels, `DefaultToggleChromeStyle` draws that same look through
//  `makeBody`, `.toggleChromeStyle(.default)` restores the built-in path, a
//  custom style receives the resolved configuration, and the style reaches the
//  switches ThemeKit composes.
//
//  Taps aren't simulated: a unit-test host builds no accessibility tree and a
//  SwiftUI button hands out no trigger, so the flip — one `isOn.toggle()`
//  shared by both render paths — is checked through the binding it writes to,
//  the way ADR-0009's testing strategy treats the other tap-driven behaviour.
//
//  Deliberately a plain `import ThemeKit`: everything here must compile from a
//  host app's point of view.
//

import XCTest
import SwiftUI
import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ToggleChromeStyleTests: XCTestCase {

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

    private func bitmap<V: View>(_ view: V) -> Bitmap? {
        let renderer = ImageRenderer(content: view.fixedSize())
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

    /// `true` when the render carries more than one value — a fixture that
    /// draws nothing would let a pair of empty comparisons pass.
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
        // ±3 per channel absorbs rasterization noise between two renders; a real
        // drift (a colour, the disabled fade, a moved knob) is far larger.
        let differing = zip(lhs.bytes, rhs.bytes).filter { abs(Int($0) - Int($1)) > 3 }.count
        XCTAssertEqual(differing, 0, "\(message): \(differing) channel values differ", file: file, line: line)
    }

    /// The control for `assertSamePixels`: the same comparison must notice a
    /// real change.
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

    private struct Fixture {
        let label: String
        let isOn: Bool
        let isEnabled: Bool
        let compact: Bool
        var knobSymbols = false
        var trackSymbols = false
    }

    private var toggleCases: [Fixture] {
        [Fixture(label: "on", isOn: true, isEnabled: true, compact: false),
         Fixture(label: "off", isOn: false, isEnabled: true, compact: false),
         Fixture(label: "disabled", isOn: true, isEnabled: false, compact: false),
         Fixture(label: "small", isOn: true, isEnabled: true, compact: true),
         Fixture(label: "knob symbols", isOn: false, isEnabled: true, compact: false, knobSymbols: true),
         Fixture(label: "track symbols", isOn: true, isEnabled: true, compact: false, trackSymbols: true)]
    }

    @ViewBuilder
    private func component(_ fixture: Fixture) -> some View {
        ThemeToggle(isOn: .constant(fixture.isOn))
            .symbols(on: fixture.knobSymbols ? "checkmark" : nil, off: fixture.knobSymbols ? "xmark" : nil)
            .trackSymbols(on: fixture.trackSymbols ? "sun.max.fill" : nil,
                          off: fixture.trackSymbols ? "moon.fill" : nil)
            .controlSize(fixture.compact ? .small : .regular)
            .disabled(!fixture.isEnabled)
    }

    // MARK: - Built-in path

    func testBuiltInPathRenders() {
        for fixture in toggleCases {
            XCTAssertTrue(drawsInk(component(fixture)), "\(fixture.label): the fixture renders blank")
        }
    }

    // MARK: - Default style honesty

    /// The stock chrome through `makeBody` draws what the built-in path draws.
    func testDefaultChromeDrawsTheBuiltInLook() {
        for fixture in toggleCases {
            let view = component(fixture)
            assertSamePixels(view, view.toggleChromeStyle(ForwardingToggleChrome()), fixture.label)
            // Control, same case: a forwarding style that changes one thing
            // (the opacity) must be caught by the same comparison.
            assertDifferentPixels(view, view.toggleChromeStyle(DimmedForwardingToggleChrome()),
                                  "\(fixture.label) (control)")
        }
    }

    func testExplicitDefaultRestoresTheBuiltInPath() {
        for fixture in toggleCases {
            let view = component(fixture)
            assertSamePixels(
                view,
                view.toggleChromeStyle(.default).toggleChromeStyle(SquareToggleChrome()),
                "\(fixture.label) under .default"
            )
            // Control, same case: without the `.default` in between, the outer
            // custom style draws — and the comparison must notice.
            assertDifferentPixels(view, view.toggleChromeStyle(SquareToggleChrome()),
                                  "\(fixture.label) (control)")
        }
    }

    func testCustomStyleReplacesTheChrome() {
        let builtIn = ThemeToggle(isOn: .constant(true))
        let styled = builtIn.toggleChromeStyle(SquareToggleChrome())
        // The styled switch is exactly the style's body — nothing of the
        // built-in chrome underneath, no press scale or disabled fade around it.
        assertSamePixels(styled, SquareToggleChromeBody(isOn: true), "on")
        assertSamePixels(ThemeToggle(isOn: .constant(false)).toggleChromeStyle(SquareToggleChrome()),
                         SquareToggleChromeBody(isOn: false), "off")
        assertDifferentPixels(SquareToggleChromeBody(isOn: true), SquareToggleChromeBody(isOn: false),
                              "control: the state changes the style's pixels")
    }

    // MARK: - Configuration

    func testCustomStyleReceivesTheResolvedConfiguration() {
        let seen = Box()
        let view = ThemeToggle(isOn: .constant(true))
            .accent(.success)
            .symbols(on: "checkmark", off: "xmark")
            .trackSymbols(on: "sun.max.fill", off: "moon.fill")
            .controlSize(.small)
            .disabled(true)
            .toggleChromeStyle(RecordingToggleChrome(box: seen))
        _ = bitmap(view)

        let configuration = try? XCTUnwrap(seen.configuration)
        XCTAssertEqual(configuration?.isOn, true)
        XCTAssertEqual(configuration?.isEnabled, false, "a disabled switch reaches the style as disabled")
        XCTAssertEqual(configuration?.knobSymbol, "checkmark", "the on glyph, since the switch is on")
        XCTAssertEqual(configuration?.trackSymbol, "sun.max.fill")
        XCTAssertEqual(configuration?.accent, .success)
        XCTAssertEqual(configuration?.controlSize, .small)
        XCTAssertEqual(configuration?.trackSize, CGSize(width: 32, height: 20), "the compact metric")
        XCTAssertEqual(configuration?.knobSide, 16, "the track's height less its 2pt inset on each side")
    }

    /// The off state hands the style the *off* glyphs, not the on ones.
    func testTheOffStateCarriesTheOffGlyphs() {
        let seen = Box()
        _ = bitmap(ThemeToggle(isOn: .constant(false))
                    .symbols(on: "checkmark", off: "xmark")
                    .trackSymbols(on: "sun.max.fill", off: "moon.fill")
                    .toggleChromeStyle(RecordingToggleChrome(box: seen)))
        XCTAssertEqual(seen.configuration?.isOn, false)
        XCTAssertEqual(seen.configuration?.knobSymbol, "xmark")
        XCTAssertEqual(seen.configuration?.trackSymbol, "moon.fill")
    }

    /// A loading switch says so, and its thumb slot reaches the style.
    func testLoadingAndTheThumbSlotReachTheStyle() {
        let loading = Box()
        _ = bitmap(ThemeToggle(isOn: .constant(true)).loading()
                    .toggleChromeStyle(RecordingToggleChrome(box: loading)))
        XCTAssertEqual(loading.configuration?.isLoading, true)
        XCTAssertNil(loading.configuration?.thumb, "no thumb slot was set")

        let thumbed = Box()
        _ = bitmap(ThemeToggle(isOn: .constant(true)).thumbContent { _ in Text("A") }
                    .toggleChromeStyle(RecordingToggleChrome(box: thumbed)))
        XCTAssertNotNil(thumbed.configuration?.thumb, "the thumb slot never reached the style")
    }

    /// The default metrics: the classic 40×24 track with its 20pt knob.
    func testTheRegularMetrics() {
        let seen = Box()
        _ = bitmap(ThemeToggle(isOn: .constant(true)).toggleChromeStyle(RecordingToggleChrome(box: seen)))
        XCTAssertEqual(seen.configuration?.trackSize, CGSize(width: 40, height: 24))
        XCTAssertEqual(seen.configuration?.knobSide, 20)
    }

    // MARK: - Reach

    /// The style reaches the switches ThemeKit composes, not just a bare one.
    func testTheStyleReachesAComposedSwitch() {
        let seen = Box()
        _ = bitmap(ToggleGroup(options: ["A"], selection: .constant(["A"])) { $0 }
                    .toggleChromeStyle(RecordingToggleChrome(box: seen)))
        XCTAssertNotNil(seen.configuration, "the style never reached ToggleGroup's switch")
    }
}

// MARK: - Test styles

/// Hands every switch back to the stock chrome: the style path must draw what
/// the built-in path draws.
@available(iOS 16.0, macOS 13.0, *)
private struct ForwardingToggleChrome: ToggleChromeStyle {
    func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
        DefaultToggleChromeStyle().makeBody(configuration: configuration)
    }
}

/// The control for the forwarding style: the same body, one thing changed.
@available(iOS 16.0, macOS 13.0, *)
private struct DimmedForwardingToggleChrome: ToggleChromeStyle {
    func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
        DefaultToggleChromeStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// A chrome that shares no pixels with the stock one: a square track.
@available(iOS 16.0, macOS 13.0, *)
private struct SquareToggleChrome: ToggleChromeStyle {
    func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
        SquareToggleChromeBody(isOn: configuration.isOn)
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct SquareToggleChromeBody: View {
    let isOn: Bool

    var body: some View {
        Rectangle()
            .fill(isOn ? Color.green : Color.gray)
            .frame(width: 48, height: 28)
            .overlay(
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
            )
    }
}

/// Keeps the configuration it was handed, so a test can read it.
@available(iOS 16.0, macOS 13.0, *)
private final class Box: @unchecked Sendable {
    var configuration: ToggleChromeStyleConfiguration?
}

@available(iOS 16.0, macOS 13.0, *)
private struct RecordingToggleChrome: ToggleChromeStyle {
    let box: Box

    func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
        box.configuration = configuration
        return Color.clear.frame(width: 40, height: 24)
    }
}
