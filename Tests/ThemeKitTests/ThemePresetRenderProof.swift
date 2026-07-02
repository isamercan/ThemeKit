import XCTest
import SwiftUI
@testable import ThemeKit

/// Visual proof for the theme-preset gallery. Run explicitly:
///   RENDER_PRESETS=1 swift test --filter ThemePresetRenderProof
/// Writes Screenshots/ThemePresets.png (the picker) and Screenshots/ThemeShowcase.png
/// (the same UI under four injected theme presets). Skipped in normal runs.
final class ThemePresetRenderProof: XCTestCase {

    @MainActor
    func testRenderPicker() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RENDER_PRESETS"] == "1", "set RENDER_PRESETS=1")

        let grid = ThemePicker(selection: .constant("dracula"), onSelect: { _ in })
            .environment(Theme.shared)
            .frame(width: 760)
            .padding(20)
            .background(Color(white: 0.96))
        try write(grid, to: "ThemePresets.png")
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    @MainActor
    func testRenderShowcase() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RENDER_PRESETS"] == "1", "set RENDER_PRESETS=1")

        // One fresh Theme per daisyUI config — injected into its own subtree.
        func themed(_ id: String) -> Theme { let t = Theme(); ThemePreset.named(id)!.apply(to: t); return t }
        let columns: [(String, Theme)] = [
            ("Cupcake", themed("cupcake")), ("Synthwave", themed("synthwave")),
            ("Cyberpunk", themed("cyberpunk")), ("Nord", themed("nord")),
        ]

        @ViewBuilder func sample() -> some View {
            HStack(spacing: 6) {
                Badge("Primary").badgeStyle(.info).variant(.solid)
                Badge("New").badgeStyle(.success)
                Badge("Sale").badgeStyle(.error)
            }
            ProgressBar(value: 0.68).showsPercentage()
            Rating(value: 4.5).starSize(15)
            HStack(spacing: 8) {
                Chip("Pool", isSelected: .constant(true))
                Chip("Wifi", isSelected: .constant(false))
            }
            HStack(spacing: 8) {
                PrimaryButton("Book") {}.fullWidth()
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

        try write(strip, to: "ThemeShowcase.png")
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
