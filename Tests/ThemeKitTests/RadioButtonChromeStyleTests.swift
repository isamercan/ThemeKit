//
//  RadioButtonChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  RadioButtonChromeStyle: the built-in path still renders and is untouched by
//  `.description(nil)`, `DefaultRadioButtonChromeStyle` draws the built-in
//  look pixel for pixel, `.radioButtonChromeStyle(.default)` restores the
//  built-in path, a custom style receives the resolved configuration, and
//  RadioGroup / the indicator-only internal radios hand it the right rows.
//
//  Deliberately a plain `import ThemeKit`: everything here must compile from a
//  host app's point of view.
//

import XCTest
import SwiftUI
import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class RadioButtonChromeStyleTests: XCTestCase {

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
        let renderer = ImageRenderer(content: view.frame(width: width, alignment: .leading).fixedSize(horizontal: false, vertical: true))
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

    private func height<V: View>(_ view: V) -> Int {
        bitmap(view)?.height ?? 0
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
        // ±3 per channel absorbs glyph rasterization noise between two renders;
        // a real drift (a color, the half-opacity fade, a moved element) is far larger.
        let differing = zip(lhs.bytes, rhs.bytes).filter { abs(Int($0) - Int($1)) > 3 }.count
        XCTAssertEqual(differing, 0, "\(message): \(differing) channel values differ", file: file, line: line)
    }

    /// The control for `assertSamePixels`: the same comparison must notice a
    /// real change (a different size, or any channel beyond the noise).
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

    // MARK: - Built-in path

    func testBuiltInPathRenders() {
        XCTAssertNotNil(bitmap(RadioButton("Selected", isSelected: .constant(true))))
        XCTAssertNotNil(bitmap(RadioButton(isSelected: .constant(false)).disabled(true)))
        XCTAssertNotNil(bitmap(RadioGroup(title: "Class", options: ["A", "B"], selection: .constant("A")) { $0 }))
    }

    func testUnsetDescriptionChangesNothing() {
        assertSamePixels(
            RadioButton("Plain", isSelected: .constant(true)),
            RadioButton("Plain", isSelected: .constant(true)).description(nil),
            "description(nil)"
        )
    }

    func testDescriptionRendersUnderTheLabel() {
        let without = height(RadioButton("Pay later", isSelected: .constant(true)))
        let with = height(RadioButton("Pay later", isSelected: .constant(true)).description("Pay at the property."))
        XCTAssertGreaterThan(with, without, "the description adds a line under the label")
    }

    // MARK: - Default style honesty

    /// Every built-in axis, drawn once by RadioButton itself and once through
    /// the style path by a custom style that forwards to the default chrome.
    private var honestyCases: [(String, AnyView)] {
        [
            ("selected", AnyView(RadioButton("Selected", isSelected: .constant(true)))),
            ("unselected", AnyView(RadioButton("Unselected", isSelected: .constant(false)))),
            ("disabled selected", AnyView(RadioButton("Disabled", isSelected: .constant(true)).disabled(true))),
            ("disabled unselected", AnyView(RadioButton("Disabled", isSelected: .constant(false)).disabled(true))),
            ("check", AnyView(RadioButton("Check", isSelected: .constant(true)).type(.check))),
            ("check inner", AnyView(RadioButton("Inner", isSelected: .constant(true)).type(.check).radioStyle(.inner))),
            ("check accent", AnyView(RadioButton("Accent", isSelected: .constant(true)).type(.check).accent(.error))),
            ("select accent", AnyView(RadioButton("Accent", isSelected: .constant(true)).accent(.success))),
            ("disabled accent", AnyView(RadioButton("Accent", isSelected: .constant(true)).accent(.success).disabled(true))),
            ("small", AnyView(RadioButton("Small", isSelected: .constant(true)).controlSize(.small))),
            ("large", AnyView(RadioButton("Large", isSelected: .constant(true)).controlSize(.large))),
            ("trailing", AnyView(RadioButton("Trailing", isSelected: .constant(true)).controlPlacement(.trailing))),
            ("gap", AnyView(RadioButton("Gap", isSelected: .constant(true)).gap(.large))),
            ("indicator only", AnyView(RadioButton(isSelected: .constant(true)))),
            ("read-only", AnyView(RadioButton("Read-only", isSelected: .constant(true)).readOnly())),
            ("description", AnyView(
                RadioButton("Described", isSelected: .constant(false)).description("Supporting copy.").alignment(.top)
            )),
            ("disabled description", AnyView(
                RadioButton("Described", isSelected: .constant(true)).description("Supporting copy.").disabled(true)
            )),
            ("error", AnyView(
                RadioButton("Invalid", isSelected: .constant(false))
                    .infoMessages([InfoMessage("Pick one", kind: .error)])
            )),
            ("warning selected", AnyView(
                RadioButton("Warned", isSelected: .constant(true))
                    .infoMessages([InfoMessage("Check this", kind: .warning)])
            )),
            ("label slot", AnyView(
                RadioButton("Card", isSelected: .constant(true)).label { Text("Card payment").fontWeight(.semibold) }
            )),
        ]
    }

    func testDefaultChromeDrawsTheBuiltInLook() {
        for (name, view) in honestyCases {
            assertSamePixels(view, view.radioButtonChromeStyle(ForwardingRadioChrome()), name)
            // Control, same case: a forwarding style that changes one thing
            // (the opacity) must be caught by the same comparison.
            assertDifferentPixels(view, view.radioButtonChromeStyle(DimmedForwardingRadioChrome()), "\(name) (control)")
        }
    }

    func testExplicitDefaultRestoresTheBuiltInPath() {
        for (name, view) in honestyCases {
            assertSamePixels(
                view,
                view.radioButtonChromeStyle(.default).radioButtonChromeStyle(OutlineRadioChrome()),
                "\(name) under .default"
            )
            // Control, same case: without the `.default` in between, the outer
            // custom style draws — and the comparison must notice.
            assertDifferentPixels(view, view.radioButtonChromeStyle(OutlineRadioChrome()), "\(name) (control)")
        }
        let group = RadioGroup(title: "Class", options: ["Economy", "Business"], selection: .constant("Economy")) { $0 }
            .optionDescription { $0 == "Business" ? "Lounge access." : nil }
            .optionEnabled { $0 != "Business" }
        assertSamePixels(
            group,
            group.radioButtonChromeStyle(.default).radioButtonChromeStyle(OutlineRadioChrome()),
            "RadioGroup under .default"
        )
    }

    func testCustomStyleReplacesTheChrome() {
        let builtIn = RadioButton("Styled", isSelected: .constant(true))
        let styled = builtIn.radioButtonChromeStyle(OutlineRadioChrome())
        XCTAssertNotEqual(height(builtIn), height(styled), "the 30pt indicator and heading label change the footprint")
        // The styled radio is exactly the style's body — nothing of the
        // built-in chrome underneath, no dimming or press effect around it —
        // for a selected and an unselected radio alike.
        assertSamePixels(styled, OutlineRadioChromeBody(isSelected: true, label: "Styled"), "selected")
        assertSamePixels(
            RadioButton("Styled", isSelected: .constant(false)).radioButtonChromeStyle(OutlineRadioChrome()),
            OutlineRadioChromeBody(isSelected: false, label: "Styled"),
            "unselected"
        )
        assertDifferentPixels(
            OutlineRadioChromeBody(isSelected: true, label: "Styled"),
            OutlineRadioChromeBody(isSelected: false, label: "Styled"),
            "control: selection changes the style's pixels"
        )
    }

    // MARK: - Configuration

    func testCustomStyleReceivesTheResolvedConfiguration() {
        let box = ConfigurationBox()
        _ = bitmap(
            RadioButton("Window seat", isSelected: .constant(true))
                .type(.check)
                .radioStyle(.inner)
                .gap(.large)
                .description("Extra legroom")
                .accent(.success)
                .controlPlacement(.trailing)
                .alignment(.top)
                .infoMessages([InfoMessage("Heads up", kind: .warning), InfoMessage("Required", kind: .error)])
                .label { Text("Window seat") }
                .controlSize(.large)
                .readOnly()
                .disabled(true)
                .microAnimations(false)
                .radioButtonChromeStyle(CapturingRadioChrome(box: box))
        )
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertEqual(c.label, "Window seat")
        XCTAssertNotNil(c.customLabel)
        XCTAssertEqual(c.description, "Extra legroom")
        XCTAssertTrue(c.isSelected)
        XCTAssertFalse(c.isEnabled)
        XCTAssertFalse(c.isPressed)
        XCTAssertTrue(c.isReadOnly)
        XCTAssertEqual(c.type, .check)
        XCTAssertEqual(c.radioStyle, .inner)
        XCTAssertEqual(c.gap, .large)
        XCTAssertEqual(c.validation, .error, "the most severe message kind")
        XCTAssertEqual(c.accent, .success)
        XCTAssertEqual(c.controlSize, .large)
        XCTAssertEqual(c.controlPlacement, .trailing)
        XCTAssertEqual(c.alignment, .top)
        XCTAssertNil(c.animation, "microAnimations(false) resolves to no animation")
    }

    func testConfigurationDefaults() {
        let box = ConfigurationBox()
        _ = bitmap(RadioButton(isSelected: .constant(false)).radioButtonChromeStyle(CapturingRadioChrome(box: box)))
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertNil(c.label)
        XCTAssertNil(c.customLabel)
        XCTAssertNil(c.description)
        XCTAssertFalse(c.isSelected)
        XCTAssertTrue(c.isEnabled)
        XCTAssertFalse(c.isReadOnly)
        XCTAssertEqual(c.type, .select)
        XCTAssertEqual(c.radioStyle, .plain)
        XCTAssertEqual(c.gap, .small)
        XCTAssertNil(c.validation)
        XCTAssertNil(c.accent)
        XCTAssertEqual(c.controlSize, .regular)
        XCTAssertEqual(c.controlPlacement, .leading)
        XCTAssertEqual(c.alignment, .center)
    }

    func testValidationMessagesStillRenderOnTheStylePath() {
        let plain = height(RadioButton("Pick", isSelected: .constant(false)).radioButtonChromeStyle(OutlineRadioChrome()))
        let invalid = height(
            RadioButton("Pick", isSelected: .constant(false))
                .infoMessages([InfoMessage("Choose an option", kind: .error)])
                .radioButtonChromeStyle(OutlineRadioChrome())
        )
        XCTAssertGreaterThan(invalid, plain, "RadioButton keeps rendering its messages under the chrome")
    }

    // MARK: - Internal uses

    func testRadioGroupHandsTheStyleWholeRows() {
        let box = ConfigurationBox()
        _ = bitmap(
            RadioGroup(title: "Cabin", options: ["Economy", "Business", "First"], selection: .constant("Business")) { $0 }
                .optionDescription { $0 == "First" ? "Suites" : nil }
                .optionEnabled { $0 != "Economy" }
                .accent(.warning)
                .controlPlacement(.trailing)
                .radioButtonChromeStyle(CapturingRadioChrome(box: box))
        )
        let rows = Dictionary(box.configurations.compactMap { c in c.label.map { ($0, c) } }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(Set(rows.keys), ["Economy", "Business", "First"])
        XCTAssertEqual(rows["Business"]?.isSelected, true)
        XCTAssertEqual(rows["Economy"]?.isSelected, false)
        XCTAssertEqual(rows["Economy"]?.isEnabled, false, "per-option enablement reaches the style")
        XCTAssertEqual(rows["First"]?.isEnabled, true)
        XCTAssertEqual(rows["First"]?.description, "Suites")
        XCTAssertEqual(rows["First"]?.alignment, .top, "top-aligned when an option has a description")
        XCTAssertNil(rows["Business"]?.description)
        XCTAssertEqual(rows["Business"]?.alignment, .center)
        XCTAssertEqual(rows["Business"]?.accent, .warning)
        XCTAssertEqual(rows["Business"]?.controlPlacement, .trailing)
        XCTAssertFalse(box.configurations.contains { $0.label == nil }, "no separate indicator-only radios")
    }

    func testIndicatorOnlyRadiosPickTheStyleUp() {
        let box = ConfigurationBox()
        _ = bitmap(
            VStack {
                ControlRow("Notify me", isOn: .constant(true)).control(.radio)
                RadioCard("Standard", isSelected: true) {}
                ListRow("Row").leadingSelection(.constant(false))
            }
            .radioButtonChromeStyle(CapturingRadioChrome(box: box))
        )
        XCTAssertGreaterThanOrEqual(box.configurations.count, 3)
        XCTAssertTrue(box.configurations.allSatisfy { $0.label == nil && $0.customLabel == nil && $0.description == nil })
        XCTAssertTrue(box.configurations.contains { $0.isSelected })
        XCTAssertTrue(box.configurations.contains { !$0.isSelected })
    }
}

// MARK: - Test styles

/// Collects every configuration a style is asked to draw.
@MainActor
private final class ConfigurationBox {
    var configurations: [RadioButtonChromeStyleConfiguration] = []
}

private struct CapturingRadioChrome: RadioButtonChromeStyle {
    let box: ConfigurationBox

    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        box.configurations.append(configuration)
        return DefaultRadioButtonChromeStyle().makeBody(configuration: configuration)
    }
}

/// A custom style that hands everything back to the stock chrome — so it runs
/// through the style path (the bridge button) but should look built-in.
private struct ForwardingRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        DefaultRadioButtonChromeStyle().makeBody(configuration: configuration)
    }
}

/// A forwarding style that changes one visible thing — the control for the
/// pixel-parity loops.
private struct DimmedForwardingRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        DefaultRadioButtonChromeStyle().makeBody(configuration: configuration).opacity(0.3)
    }
}

/// A visibly different chrome: a bordered square indicator and the label.
private struct OutlineRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        OutlineRadioChromeBody(isSelected: configuration.isSelected, label: configuration.label)
    }
}

/// The outline chrome's body — also rendered on its own as the expected look.
private struct OutlineRadioChromeBody: View {
    let isSelected: Bool
    let label: String?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value)
                .strokeBorder(theme.border(isSelected ? .borderHero : .borderPrimary), lineWidth: 3)
                .frame(width: 30, height: 30)
            if let label {
                Text(label).textStyle(.headingSm)
            }
        }
    }
}
