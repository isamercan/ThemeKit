//
//  CheckboxChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `Checkbox` + `CheckboxChromeStyle`: the built-in path still draws the 1.10.0
//  pixels, `DefaultCheckboxChromeStyle` draws that same look through `makeBody`,
//  `.checkboxChromeStyle(.default)` restores the built-in path, a custom style
//  receives the resolved configuration, the caller's binding still drives the
//  chrome, the validation messages stay under the chrome, and the style reaches
//  the checkboxes ThemeKit composes without touching anything else.
//
//  Taps aren't simulated: a unit-test host builds no accessibility tree and a
//  SwiftUI button hands out no trigger, so the toggle — one `isChecked.toggle()`
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
final class CheckboxChromeStyleTests: XCTestCase {

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
        XCTAssertNotNil(bitmap(Checkbox("Checked", isChecked: .constant(true))))
        XCTAssertNotNil(bitmap(Checkbox(isChecked: .constant(false)).disabled(true)))
        XCTAssertNotNil(bitmap(CheckboxGroup(options: ["A", "B"], selection: .constant(["A"])) { $0 }))
    }

    /// With no style set the component draws the body it drew before the door
    /// existed: the 1.10.0 recipe, written out below, is the reference.
    func testBuiltInPathDrawsThe1100Pixels() {
        for fixture in checkboxCases {
            XCTAssertTrue(drawsInk(component(fixture)), "\(fixture.label): the fixture renders blank")
            assertSamePixels(component(fixture), recipe(fixture), fixture.label)
            // Control, same case: the recipe at 60% opacity must be caught.
            assertDifferentPixels(component(fixture), recipe(fixture, opacity: 0.6), "\(fixture.label) (control)")
        }
    }

    func testUnsetDescriptionChangesNothing() {
        assertSamePixels(
            Checkbox("Plain", isChecked: .constant(true)),
            Checkbox("Plain", isChecked: .constant(true)).description(nil),
            "description(nil)"
        )
    }

    // MARK: - Default style honesty

    func testDefaultChromeDrawsTheBuiltInLook() {
        for fixture in checkboxCases {
            let view = component(fixture)
            assertSamePixels(view, view.checkboxChromeStyle(ForwardingCheckboxChrome()), fixture.label)
            // Control, same case: a forwarding style that changes one thing
            // (the opacity) must be caught by the same comparison.
            assertDifferentPixels(view, view.checkboxChromeStyle(DimmedForwardingCheckboxChrome()),
                                  "\(fixture.label) (control)")
        }
    }

    func testExplicitDefaultRestoresTheBuiltInPath() {
        for fixture in checkboxCases {
            let view = component(fixture)
            assertSamePixels(
                view,
                view.checkboxChromeStyle(.default).checkboxChromeStyle(OutlineCheckboxChrome()),
                "\(fixture.label) under .default"
            )
            // Control, same case: without the `.default` in between, the outer
            // custom style draws — and the comparison must notice.
            assertDifferentPixels(view, view.checkboxChromeStyle(OutlineCheckboxChrome()),
                                  "\(fixture.label) (control)")
        }
    }

    func testCustomStyleReplacesTheChrome() {
        let builtIn = Checkbox("Styled", isChecked: .constant(true))
        let styled = builtIn.checkboxChromeStyle(OutlineCheckboxChrome())
        XCTAssertNotEqual(height(builtIn), height(styled), "the 30pt box and heading label change the footprint")
        // The styled checkbox is exactly the style's body — nothing of the
        // built-in chrome underneath, no dimming or press effect around it.
        assertSamePixels(styled, OutlineCheckboxChromeBody(isChecked: true, label: "Styled"), "checked")
        assertSamePixels(
            Checkbox("Styled", isChecked: .constant(false)).checkboxChromeStyle(OutlineCheckboxChrome()),
            OutlineCheckboxChromeBody(isChecked: false, label: "Styled"),
            "unchecked"
        )
        assertDifferentPixels(
            OutlineCheckboxChromeBody(isChecked: true, label: "Styled"),
            OutlineCheckboxChromeBody(isChecked: false, label: "Styled"),
            "control: the checked state changes the style's pixels"
        )
    }

    // MARK: - Configuration

    func testCustomStyleReceivesTheResolvedConfiguration() {
        let box = ConfigurationBox()
        _ = bitmap(
            Checkbox("Window seat", isChecked: .constant(true))
                .type(.inner)
                .variant(.secondary)
                .indeterminate()
                .description("Extra legroom")
                .accent(.success)
                .controlPlacement(.trailing)
                .alignment(.top)
                .lineThrough()
                .customSize(32)
                .infoMessages([InfoMessage("Heads up", kind: .warning), InfoMessage("Required", kind: .error)])
                .label { Text("Window seat") }
                .controlSize(.large)
                .readOnly()
                .disabled(true)
                .microAnimations(false)
                .checkboxChromeStyle(CapturingCheckboxChrome(box: box))
        )
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertEqual(c.label, "Window seat")
        XCTAssertNotNil(c.customLabel)
        XCTAssertEqual(c.description, "Extra legroom")
        XCTAssertTrue(c.descriptionLinks.isEmpty)
        XCTAssertTrue(c.isChecked)
        XCTAssertTrue(c.isIndeterminate)
        XCTAssertFalse(c.isEnabled)
        XCTAssertFalse(c.isPressed)
        XCTAssertTrue(c.isReadOnly)
        XCTAssertEqual(c.type, .inner)
        XCTAssertEqual(c.variant, .secondary)
        XCTAssertNil(c.swatch, "no customInner token was set")
        XCTAssertEqual(c.validation, .error, "the most severe message kind")
        XCTAssertEqual(c.accent, .success)
        XCTAssertEqual(c.controlSize, .large)
        XCTAssertEqual(c.customSize, 32)
        XCTAssertEqual(c.side, 32, "the custom size wins over the control-size metric")
        XCTAssertEqual(c.controlPlacement, .trailing)
        XCTAssertEqual(c.alignment, .top)
        XCTAssertTrue(c.lineThrough)
        XCTAssertNil(c.animation, "microAnimations(false) resolves to no animation")
    }

    func testConfigurationDefaults() {
        let box = ConfigurationBox()
        _ = bitmap(Checkbox(isChecked: .constant(false)).checkboxChromeStyle(CapturingCheckboxChrome(box: box)))
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertNil(c.label)
        XCTAssertNil(c.customLabel)
        XCTAssertNil(c.description)
        XCTAssertTrue(c.descriptionLinks.isEmpty)
        XCTAssertFalse(c.isChecked)
        XCTAssertFalse(c.isIndeterminate)
        XCTAssertTrue(c.isEnabled)
        XCTAssertFalse(c.isReadOnly)
        XCTAssertEqual(c.type, .plain)
        XCTAssertEqual(c.variant, .primary)
        XCTAssertNil(c.swatch)
        XCTAssertNil(c.validation)
        XCTAssertNil(c.accent)
        XCTAssertEqual(c.controlSize, .regular)
        XCTAssertNil(c.customSize)
        XCTAssertEqual(c.side, 24, "the default control size's Figma metric")
        XCTAssertEqual(c.controlPlacement, .leading)
        XCTAssertEqual(c.alignment, .center)
        XCTAssertFalse(c.lineThrough)
    }

    /// The token-bound `customInner(_:)` reaches the style as the token, not as
    /// the `.clear` placeholder its `type` carries.
    func testTokenBoundSwatchReachesTheStyleAsAToken() {
        let box = ConfigurationBox()
        _ = bitmap(Checkbox("Swatch", isChecked: .constant(true))
            .customInner(.warning)
            .checkboxChromeStyle(CapturingCheckboxChrome(box: box)))
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertEqual(c.swatch, .warning)
        guard case .customInner = c.type else { return XCTFail("the discriminant didn't reach the style") }
    }

    /// The description's links reach the style with their handlers intact, so a
    /// style that draws its own description can route the taps.
    func testDescriptionLinksReachTheStyle() {
        var opened = 0
        let box = ConfigurationBox()
        _ = bitmap(Checkbox("Terms", isChecked: .constant(false))
            .description("Read the Terms first.", links: [("Terms", { opened += 1 })])
            .checkboxChromeStyle(CapturingCheckboxChrome(box: box)))
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertEqual(c.description, "Read the Terms first.", "the description arrives raw, links and all")
        XCTAssertEqual(c.descriptionLinks.count, 1)
        XCTAssertEqual(c.descriptionLinks.first?.substring, "Terms")
        c.descriptionLinks.first?.action()
        XCTAssertEqual(opened, 1, "the link's handler reaches the style intact")
    }

    func testValidationMessagesStillRenderOnTheStylePath() {
        let plain = height(Checkbox("Accept", isChecked: .constant(false)).checkboxChromeStyle(OutlineCheckboxChrome()))
        let invalid = height(
            Checkbox("Accept", isChecked: .constant(false))
                .infoMessages([InfoMessage("This is required to continue", kind: .error)])
                .checkboxChromeStyle(OutlineCheckboxChrome())
        )
        XCTAssertGreaterThan(invalid, plain, "Checkbox keeps rendering its messages under the chrome")
    }

    // MARK: - Behaviour

    /// The caller's binding — not a copy the chrome owns — is what a styled
    /// checkbox draws: the value a style is handed is the binding's, render
    /// after render, and the write Checkbox's action makes lands on the caller.
    ///
    /// (A unit-test host neither taps nor exposes a SwiftUI button's trigger,
    /// so the tap itself isn't simulated — ADR-0009's testing strategy. The
    /// toggle is one `isChecked.toggle()` shared by both paths; what a test can
    /// see is that the binding it writes through is the caller's.)
    func testTheCallersBindingDrivesTheStyledChrome() {
        var value = false
        var writes: [Bool] = []
        let binding = Binding(get: { value }, set: { value = $0; writes.append($0) })
        let box = ConfigurationBox()
        let view = Checkbox("Accept", isChecked: binding).checkboxChromeStyle(CapturingCheckboxChrome(box: box))

        _ = bitmap(view)
        XCTAssertEqual(box.configurations.last?.isChecked, false)

        // What Checkbox's action does with the binding it was handed.
        binding.wrappedValue.toggle()
        XCTAssertEqual(writes, [true], "the checkbox's binding isn't the caller's")

        _ = bitmap(view)
        XCTAssertEqual(box.configurations.last?.isChecked, true, "the chrome didn't follow the binding")
    }

    /// The gates around that write stay Checkbox's: disabled and read-only
    /// reach the style as state to paint, while the component keeps blocking
    /// the taps and keeps drawing its messages.
    func testTheStylePathKeepsTheDisabledAndReadOnlyGates() {
        let box = ConfigurationBox()
        _ = bitmap(VStack {
            Checkbox("Open", isChecked: .constant(false))
            Checkbox("Off", isChecked: .constant(false)).disabled(true)
            Checkbox("Frozen", isChecked: .constant(false)).readOnly()
        }
        .checkboxChromeStyle(CapturingCheckboxChrome(box: box)))

        let rows = Dictionary(box.configurations.compactMap { c in c.label.map { ($0, c) } },
                              uniquingKeysWith: { _, last in last })
        XCTAssertEqual(rows["Open"]?.isEnabled, true)
        XCTAssertEqual(rows["Open"]?.isReadOnly, false)
        XCTAssertEqual(rows["Off"]?.isEnabled, false, "the disabled gate reaches the style")
        XCTAssertEqual(rows["Frozen"]?.isReadOnly, true, "read-only reaches the style")
        XCTAssertEqual(rows["Frozen"]?.isEnabled, true, "read-only is not disabled")
    }

    // MARK: - Scope

    /// With no style set up the tree, the checkbox never asks any style to
    /// draw: a style set on a sibling isn't consulted, and the checkbox still
    /// draws the built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let box = ConfigurationBox()
        let fixture = checkboxCases[0]
        _ = bitmap(VStack(spacing: 0) {
            component(fixture)
            Color.clear.frame(width: 320, height: 40).checkboxChromeStyle(CapturingCheckboxChrome(box: box))
        })
        XCTAssertTrue(box.configurations.isEmpty, "a style off the checkbox's path was consulted")
        assertSamePixels(component(fixture), recipe(fixture), "the built-in pixels")
    }

    /// The style reaches the checkbox it is set around and nothing else — not a
    /// sibling checkbox, and not the neighbouring controls that draw their own
    /// selection chrome.
    func testStyleDoesNotLeakToNeighbours() {
        let box = ConfigurationBox()
        _ = bitmap(VStack(spacing: 0) {
            Checkbox("Styled", isChecked: .constant(true)).checkboxChromeStyle(CapturingCheckboxChrome(box: box))
            Checkbox("Sibling", isChecked: .constant(false))
        })
        XCTAssertEqual(box.configurations.compactMap(\.label), ["Styled"],
                       "the style reached a checkbox it wasn't set around")

        // Controls that are not `Checkbox` are untouched by a checkbox style.
        let neighbours = VStack(spacing: 0) {
            RadioButton("Radio", isSelected: .constant(true))
            ThemeToggle(isOn: .constant(true))
        }
        assertSamePixels(neighbours, neighbours.checkboxChromeStyle(OutlineCheckboxChrome()),
                         "a checkbox style repainted a neighbouring control")
        XCTAssertTrue(drawsInk(neighbours), "the neighbour fixture renders blank")
    }

    /// A style set at a container reaches every checkbox below it — including
    /// the label-less ones ThemeKit composes inside its own components
    /// (ADR-0009 D6).
    func testComposedCheckboxesPickTheStyleUp() {
        let box = ConfigurationBox()
        _ = bitmap(
            VStack {
                CheckboxGroup(options: ["A", "B"], selection: .constant(["A"])) { $0 }
                ControlRow("Notify me", isOn: .constant(true)).control(.checkbox)
                ListRow("Row").trailing(.checkbox(.constant(true)))
            }
            .checkboxChromeStyle(CapturingCheckboxChrome(box: box))
        )
        XCTAssertGreaterThanOrEqual(box.configurations.count, 3)
        XCTAssertTrue(box.configurations.allSatisfy { $0.label == nil && $0.customLabel == nil && $0.description == nil },
                      "the composed boxes carry no label of their own")
        XCTAssertTrue(box.configurations.contains { $0.isChecked })
        XCTAssertTrue(box.configurations.contains { !$0.isChecked })
    }

    // MARK: - Fixtures

    private var checkboxCases: [CheckboxCase] {
        [
            CheckboxCase(label: "checked"),
            CheckboxCase(label: "unchecked", isChecked: false),
            CheckboxCase(label: "box only", title: nil),
            CheckboxCase(label: "indeterminate", isIndeterminate: true),
            CheckboxCase(label: "disabled checked", isEnabled: false),
            CheckboxCase(label: "disabled unchecked", isChecked: false, isEnabled: false),
            CheckboxCase(label: "inner", type: .inner),
            CheckboxCase(label: "inner indeterminate", isIndeterminate: true, type: .inner),
            CheckboxCase(label: "custom inner", type: .customInner(color: .orange)),
            // The token-bound `customInner(_:)` leaves a `.clear` placeholder
            // in `type` and carries the token beside it.
            CheckboxCase(label: "token swatch", type: .customInner(color: .clear), swatch: .warning),
            CheckboxCase(label: "secondary variant", isChecked: false, variant: .secondary),
            CheckboxCase(label: "accent", accent: .success),
            CheckboxCase(label: "disabled accent", isEnabled: false, accent: .success),
            CheckboxCase(label: "small", controlSize: .small),
            CheckboxCase(label: "large", controlSize: .large),
            CheckboxCase(label: "custom size", customSize: 32),
            CheckboxCase(label: "trailing", controlPlacement: .trailing),
            CheckboxCase(label: "description", isChecked: false, alignment: .top,
                         description: "Get notified when someone mentions you"),
            CheckboxCase(label: "disabled description", isEnabled: false,
                         description: "Get notified when someone mentions you"),
            CheckboxCase(label: "linked description",
                         description: "Read the Terms first.", descriptionLinks: [("Terms", {})]),
            CheckboxCase(label: "line-through", lineThrough: true),
            CheckboxCase(label: "line-through unchecked", isChecked: false, lineThrough: true),
            CheckboxCase(label: "label slot", slot: true),
            CheckboxCase(label: "label slot struck", lineThrough: true, slot: true),
            CheckboxCase(label: "error", isChecked: false,
                         messages: [InfoMessage("This is required to continue", kind: .error)], validation: .error),
            CheckboxCase(label: "warning", messages: [InfoMessage("Check this", kind: .warning)], validation: .warning),
            CheckboxCase(label: "read-only", isReadOnly: true),
        ]
    }

    /// The fixture as the component draws it.
    private func component(_ fixture: CheckboxCase) -> AnyView {
        var checkbox = Checkbox(fixture.title, isChecked: .constant(fixture.isChecked))
            .type(fixture.type)
            .variant(fixture.variant)
            .indeterminate(fixture.isIndeterminate)
            .alignment(fixture.alignment)
            .controlPlacement(fixture.controlPlacement)
            .lineThrough(fixture.lineThrough)
            .customSize(fixture.customSize)
            .accent(fixture.accent)
            .infoMessages(fixture.messages)
        if let swatch = fixture.swatch { checkbox = checkbox.customInner(swatch) }
        if let description = fixture.description {
            checkbox = fixture.descriptionLinks.isEmpty
                ? checkbox.description(description)
                : checkbox.description(description, links: fixture.descriptionLinks)
        }
        if fixture.slot { checkbox = checkbox.label { SlotLabel() } }
        return AnyView(stage(checkbox, fixture))
    }

    /// The same fixture as 1.10.0 drew it: the old body written out.
    private func recipe(_ fixture: CheckboxCase, opacity: Double = 1) -> AnyView {
        let body = V1100Checkbox(
            title: fixture.title,
            slot: fixture.slot,
            description: fixture.description,
            descriptionLinks: fixture.descriptionLinks,
            isChecked: fixture.isChecked,
            isIndeterminate: fixture.isIndeterminate,
            type: fixture.type,
            variant: fixture.variant,
            swatch: fixture.swatch,
            accent: fixture.accent,
            customSize: fixture.customSize,
            controlPlacement: fixture.controlPlacement,
            alignment: fixture.alignment,
            lineThrough: fixture.lineThrough,
            messages: fixture.messages,
            validation: fixture.validation
        )
        .opacity(opacity)
        return AnyView(stage(body, fixture))
    }

    /// The environment axes both the component and the recipe are placed under.
    private func stage(_ view: some View, _ fixture: CheckboxCase) -> some View {
        view.controlSize(fixture.controlSize)
            .disabled(!fixture.isEnabled)
            .readOnly(fixture.isReadOnly)
            .microAnimations(false)
    }
}

// MARK: - The 1.10.0 recipe (the built-in body written out)

/// `Checkbox`'s 1.10.0 body, written out: the reference the built-in path must
/// still draw. The accessibility modifiers and the read-only hit-test gate move
/// no pixels, so they are left out.
@available(iOS 16.0, macOS 13.0, *)
private struct V1100Checkbox: View {
    @Environment(\.theme) private var theme
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    var title: String?
    var slot = false
    var description: String?
    var descriptionLinks: [(substring: String, action: () -> Void)] = []
    var isChecked = false
    var isIndeterminate = false
    var type: CheckboxType = .plain
    var variant: CheckboxVariant = .primary
    var swatch: SemanticColor?
    var accent: SemanticColor?
    var customSize: CGFloat?
    var controlPlacement: HorizontalEdge = .leading
    var alignment: VerticalAlignment = .center
    var lineThrough = false
    var messages: [InfoMessage] = []
    var validation: InfoMessage.Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {} label: {
                HStack(alignment: alignment, spacing: Theme.SpacingKey.sm.value) {
                    if controlPlacement == .leading {
                        box
                        labelView
                    } else {
                        labelView
                        box
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            if !messages.isEmpty {
                InfoMessageList(messages)
            }
        }
    }

    /// The Figma "Control Items" metrics, spelled out rather than read from the
    /// library, so a change to them shows up here.
    private var side: CGFloat {
        if let customSize { return customSize }
        switch controlSize {
        case .mini, .small: return 20
        case .large, .extraLarge: return 28
        default: return 24
        }
    }

    private var radius: CGFloat { Theme.RadiusRole.selector.value }
    private var selected: Bool { isChecked || isIndeterminate }

    private var selectedFill: Color {
        if isEnabled, let accent { return theme.resolve(accent).solid }
        return theme.background(isEnabled ? .bgHero : .bgSecondary)
    }

    private var glyphColor: Color {
        if isEnabled, let accent { return theme.resolve(accent).onSolid }
        return theme.foreground(.fgSecondary)
    }

    private var fill: Color {
        if let swatch { return theme.resolve(swatch).solid }
        switch type {
        case .customInner(let color):
            return color
        case .plain, .inner:
            guard selected else { return variant == .secondary ? theme.background(.bgSecondaryLight) : .clear }
            if case .inner = type { return .clear }
            return selectedFill
        }
    }

    private var stroke: Color {
        if case .customInner = type { return .clear }
        if !isEnabled { return theme.border(.borderPrimary) }
        if validation == .error { return theme.border(.systemcolorsBorderError) }
        if validation == .warning { return theme.border(.systemcolorsBorderWarning) }
        guard selected else { return theme.border(.borderPrimary) }
        return accent.map { theme.resolve($0).border } ?? theme.border(.borderHero)
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1.5)
            )
            .frame(width: side, height: side)
            .overlay(glyph)
    }

    @ViewBuilder private var glyph: some View {
        if case .inner = type {
            if selected {
                RoundedRectangle(cornerRadius: max(radius - 2, 1), style: .continuous)
                    .fill(selectedFill)
                    .padding(side * 0.2)
                    .overlay {
                        if isIndeterminate {
                            Image(systemName: "minus")
                                .font(.system(size: side * 0.34, weight: .bold))
                                .foregroundStyle(glyphColor)
                        }
                    }
            }
        } else if selected {
            Image(systemName: isIndeterminate ? "minus" : "checkmark")
                .font(.system(size: side * 0.6, weight: .bold))
                .foregroundStyle(glyphColor)
        }
    }

    private var labelView: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            titleView
            if let description {
                HelperText(description).links(descriptionLinks)
            }
        }
    }

    @ViewBuilder private var titleView: some View {
        if slot {
            SlotLabel().strikethrough(lineThrough && isChecked)
        } else if let title {
            Text(title)
                .strikethrough(lineThrough && isChecked)
                .textStyle(.bodyBase400)
                .foregroundStyle(titleColor)
        }
    }

    private var titleColor: Color {
        if !isEnabled { return theme.text(.textDisabled) }
        if validation == .error { return theme.foreground(.systemcolorsFgError) }
        return theme.text(.textPrimary)
    }
}

// MARK: - Fixtures

private struct CheckboxCase {
    let label: String
    var title: String? = "I accept the terms"
    var isChecked = true
    var isIndeterminate = false
    var isEnabled = true
    var isReadOnly = false
    var type: CheckboxType = .plain
    var variant: CheckboxVariant = .primary
    var swatch: SemanticColor?
    var accent: SemanticColor?
    var controlSize: ControlSize = .regular
    var customSize: CGFloat?
    var controlPlacement: HorizontalEdge = .leading
    var alignment: VerticalAlignment = .center
    var description: String?
    var descriptionLinks: [(substring: String, action: () -> Void)] = []
    var lineThrough = false
    var slot = false
    var messages: [InfoMessage] = []
    var validation: InfoMessage.Kind?
}

/// The `.label { }` slot's content, shared by the component fixture and the
/// 1.10.0 recipe so the two draw the same thing.
private struct SlotLabel: View {
    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text("I accept the")
            Text("Terms of Service").underline().fontWeight(.semibold)
        }
        .textStyle(.bodyBase400)
    }
}

// MARK: - Test styles

/// Collects every configuration a style is asked to draw.
@MainActor
private final class ConfigurationBox {
    var configurations: [CheckboxChromeStyleConfiguration] = []
}

private struct CapturingCheckboxChrome: CheckboxChromeStyle {
    let box: ConfigurationBox

    func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
        box.configurations.append(configuration)
        return DefaultCheckboxChromeStyle().makeBody(configuration: configuration)
    }
}

/// A custom style that hands everything back to the stock chrome — so it runs
/// through the style path (the bridge button) but should look built-in.
private struct ForwardingCheckboxChrome: CheckboxChromeStyle {
    func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
        DefaultCheckboxChromeStyle().makeBody(configuration: configuration)
    }
}

/// A forwarding style that changes one visible thing — the control for the
/// pixel-parity loops.
private struct DimmedForwardingCheckboxChrome: CheckboxChromeStyle {
    func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
        DefaultCheckboxChromeStyle().makeBody(configuration: configuration).opacity(0.3)
    }
}

/// A visibly different chrome: a bordered square box and the label.
private struct OutlineCheckboxChrome: CheckboxChromeStyle {
    func makeBody(configuration: CheckboxChromeStyleConfiguration) -> some View {
        OutlineCheckboxChromeBody(isChecked: configuration.isChecked, label: configuration.label)
    }
}

/// The outline chrome's body — also rendered on its own as the expected look.
private struct OutlineCheckboxChromeBody: View {
    let isChecked: Bool
    let label: String?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Rectangle()
                .strokeBorder(theme.border(isChecked ? .borderHero : .borderPrimary), lineWidth: 3)
                .frame(width: 30, height: 30)
            if let label {
                Text(label).textStyle(.headingSm)
            }
        }
        .contentShape(Rectangle())
    }
}
