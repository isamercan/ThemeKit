//
//  ChipStyleTitleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  A ChipStyle can set the title's font; without one, the title keeps the
//  chip's own text style (an outside font still can't reach it) and slot
//  content keeps the font around the chip, as in 1.4.0. The configuration
//  carries the raw title. Plain `import ThemeKit`: a host app writes these
//  styles.
//

import XCTest
import SwiftUI
import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ChipStyleTitleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func size<V: View>(_ view: V) -> CGSize {
        guard let image = render(view) else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }

    /// Raw pixels, rendered twice and keeping the second (the first render of
    /// new glyphs can antialias a few bytes differently).
    private func pixels<V: View>(_ view: V) -> Data? {
        _ = render(view)
        return render(view)?.dataProvider?.data as Data?
    }

    func testBuiltInChipsRender() {
        XCTAssertNotNil(render(Chip("Tonal", isSelected: .constant(true))))
        XCTAssertNotNil(render(Chip("Solid", isSelected: .constant(true)).chipStyle(.solid)))
        XCTAssertNotNil(render(Chip("Status").type(.success).variant(.soft).onClose {}))
    }

    func testStyleReceivesTheRawTitle() {
        let box = ChipConfigurationBox()
        _ = render(Chip("Nonstop", isSelected: .constant(true)).size(.large).chipStyle(CapturingChipStyle(box: box)))
        guard let c = box.configurations.last else { return XCTFail("the style was never asked to draw") }
        XCTAssertEqual(c.title, "Nonstop")
        XCTAssertTrue(c.isSelected)
        XCTAssertTrue(c.isEnabled)
        XCTAssertEqual(c.size, .large)
    }

    func testStatusChipCarriesItsTitleToo() {
        let box = ChipConfigurationBox()
        _ = render(Chip("Sold out").exists(false).chipStyle(CapturingChipStyle(box: box)))
        // A status chip without `.type(_:)` draws through the environment style too.
        XCTAssertEqual(box.configurations.last?.title, "Sold out")
        XCTAssertEqual(box.configurations.last?.isEnabled, false, "a non-existent item draws disabled")
    }

    /// The fix: a font set by the style re-fonts the title. Before it, the
    /// title's own text style sat on the Text and always won.
    func testStyleFontReachesTheTitle() {
        let plain = size(Chip("Title", isSelected: .constant(false)).chipStyle(BareChipStyle(font: nil)))
        let large = size(Chip("Title", isSelected: .constant(false)).chipStyle(BareChipStyle(font: .headingXl)))
        XCTAssertGreaterThan(large.height, plain.height)
        XCTAssertGreaterThan(large.width, plain.width)
    }

    /// The chip's title style is still the innermost default for everything a
    /// caller wraps around the chip — an ancestor font doesn't reach the title.
    /// (A 40pt title would change the footprint, so the size is the check.)
    func testOutsideFontStillDoesNotReachTheTitle() {
        let chip = Chip("Recommended", isSelected: .constant(true))
        XCTAssertEqual(size(chip), size(chip.font(.system(size: 40))))
        let status = Chip("Accent").type(.accent).size(.large)
        XCTAssertEqual(size(status), size(status.font(.system(size: 40))))
    }

    /// Slot content without a font of its own keeps the font around the chip,
    /// as in 1.4.0: the chip draws exactly what it draws with that font
    /// written on the slot itself — `.body` (SwiftUI's default) when nothing
    /// is set, the ambient font when an ancestor sets one.
    func testUnfontedSlotKeepsTheAmbientFont() {
        func chip(_ slotFont: Font?) -> Chip {
            Chip("Slots", isSelected: .constant(false)).leading { SlotText("AAAA", font: slotFont) }
        }
        func status(_ slotFont: Font?) -> Chip {
            Chip("Status").type(.success).variant(.soft).trailing { SlotText("12", font: slotFont) }
        }
        let ambient = Font.system(size: 30)
        XCTAssertEqual(pixels(chip(nil)), pixels(chip(.body)), "no ambient font: the slot draws in .body")
        XCTAssertEqual(pixels(chip(nil).font(ambient)), pixels(chip(ambient)), "the ambient font reaches the slot")
        XCTAssertEqual(pixels(status(nil).font(ambient)), pixels(status(ambient)), "status chip: the ambient font reaches the slot")
        // Control: the comparison sees a slot font change, and the title keeps
        // its own style under the ambient font.
        XCTAssertNotEqual(pixels(chip(nil)), pixels(chip(ambient)))
        XCTAssertGreaterThan(size(chip(nil).font(ambient)).height, size(chip(nil)).height)
        let plain = Chip("Slots", isSelected: .constant(false))
        XCTAssertEqual(size(plain), size(plain.font(ambient)), "the title ignores the ambient font")
    }

    /// A style's font still reaches unfonted slots along with the title.
    func testStyleFontReachesUnfontedSlots() {
        func chip(_ slotFont: Font?) -> Chip {
            Chip("Slots", isSelected: .constant(false)).leading { SlotText("AAAA", font: slotFont) }
        }
        let styled = BareChipStyle(font: .headingXl)
        XCTAssertEqual(pixels(chip(nil).chipStyle(styled)), pixels(chip(TextStyle.headingXl.font).chipStyle(styled)))
    }

    func testMoleculesDrawingThroughTheStyleHaveAnEmptyTitle() {
        let box = ChipConfigurationBox()
        _ = render(FilterChip("Direct").chipStyle(CapturingChipStyle(box: box)))
        XCTAssertEqual(box.configurations.last?.title, "")
    }
}

// MARK: - Test styles

/// Slot text with its own font, or none at all (`Text.font(nil)` would pin
/// the default font instead of inheriting).
private struct SlotText: View {
    let text: String
    let font: Font?

    init(_ text: String, font: Font?) {
        self.text = text
        self.font = font
    }

    var body: some View {
        if let font {
            Text(verbatim: text).font(font)
        } else {
            Text(verbatim: text)
        }
    }
}

@MainActor
private final class ChipConfigurationBox {
    var configurations: [ChipStyleConfiguration] = []
}

private struct CapturingChipStyle: ChipStyle {
    let box: ChipConfigurationBox

    func makeBody(configuration: ChipStyleConfiguration) -> some View {
        box.configurations.append(configuration)
        return TonalChipStyle().makeBody(configuration: configuration)
    }
}

/// Content only, optionally re-fonted — no chroma to muddy the size check.
private struct BareChipStyle: ChipStyle {
    let font: TextStyle?

    func makeBody(configuration: ChipStyleConfiguration) -> some View {
        if let font {
            configuration.content.textStyle(font)
        } else {
            configuration.content
        }
    }
}
