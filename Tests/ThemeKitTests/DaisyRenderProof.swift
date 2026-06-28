import XCTest
import SwiftUI
@testable import ThemeKit

/// Visual proof for the daisyUI theme gallery. Run explicitly:
///   RENDER_DAISY=1 swift test --filter DaisyRenderProof
/// Writes Screenshots/DaisyThemes.png (the picker) and Screenshots/DaisyShowcase.png
/// (the same UI under four injected daisyUI themes). Skipped in normal runs.
final class DaisyRenderProof: XCTestCase {

    @MainActor
    func testRenderPicker() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RENDER_DAISY"] == "1", "set RENDER_DAISY=1")

        let grid = ThemePicker(selection: .constant("dracula"), onSelect: { _ in })
            .environment(Theme.shared)
            .frame(width: 760)
            .padding(20)
            .background(Color(white: 0.96))
        try write(grid, to: "DaisyThemes.png")
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    @MainActor
    func testRenderShowcase() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RENDER_DAISY"] == "1", "set RENDER_DAISY=1")

        // One fresh Theme per daisyUI config — injected into its own subtree.
        func themed(_ id: String) -> Theme { let t = Theme(); DaisyTheme.named(id)!.apply(to: t); return t }
        let columns: [(String, Theme)] = [
            ("Cupcake", themed("cupcake")), ("Synthwave", themed("synthwave")),
            ("Cyberpunk", themed("cyberpunk")), ("Nord", themed("nord")),
        ]

        @ViewBuilder func sample() -> some View {
            HStack(spacing: 6) {
                Badge("Primary", style: .info, variant: .solid)
                Badge("New", style: .success)
                Badge("Sale", style: .error)
            }
            ProgressBar(value: 0.68, showPercentage: true)
            Rating(value: 4.5).starSize(15)
            HStack(spacing: 8) {
                Chip("Pool", isSelected: .constant(true))
                Chip("Wifi", isSelected: .constant(false))
            }
            HStack(spacing: 8) {
                PrimaryButton("Book", block: true) {}
                SecondaryButton("Save") {}
            }
        }

        func column(_ title: String, _ theme: Theme) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.text(.textPrimary))
                Text("Same components · injected theme")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text(.textSecondary))
                sample()
            }
            .frame(width: 240, alignment: .leading)
            .padding(16)
            .background(theme.background(.bgWhite))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border(.borderPrimary), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .theme(theme)
        }

        let strip = HStack(alignment: .top, spacing: 16) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, c in column(c.0, c.1) }
        }
        .padding(24)
        .background(Color(white: 0.95))

        try write(strip, to: "DaisyShowcase.png")
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    @MainActor
    private func write(_ view: some View, to name: String) throws {
        #if canImport(AppKit)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return XCTFail("no image for \(name)") }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return XCTFail("no png for \(name)") }
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(name))
        #endif
    }
}
