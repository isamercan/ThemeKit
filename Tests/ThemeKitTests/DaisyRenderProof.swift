import XCTest
import SwiftUI
@testable import ThemeKit

/// One-off visual proof for the daisyUI theme gallery. Run explicitly:
///   RENDER_DAISY=1 swift test --filter DaisyRenderProof
/// Writes Screenshots/DaisyThemes.png. Skipped in normal runs.
final class DaisyRenderProof: XCTestCase {
    @MainActor
    func testRenderPicker() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RENDER_DAISY"] == "1", "set RENDER_DAISY=1")

        let grid = ThemePicker(selection: .constant("dracula"), onSelect: { _ in })
            .environment(Theme.shared)
            .frame(width: 760)
            .padding(20)
            .background(Color(white: 0.96))

        let renderer = ImageRenderer(content: grid)
        renderer.scale = 2
        #if canImport(AppKit)
        guard let cg = renderer.cgImage else { return XCTFail("no image") }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return XCTFail("no png") }
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent("DaisyThemes.png"))
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        #endif
    }
}
