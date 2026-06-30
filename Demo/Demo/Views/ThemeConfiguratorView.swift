//
//  ThemeConfiguratorView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  A LIVE theme generator: edit the role colors (primary / secondary / accent /
//  base surface) + scale knobs (radius / spacing / font / shadow) + font + dark,
//  and the whole Ant-style palette regenerates on the fly via `ThemeConfig` +
//  `ThemeGenerator` (the runtime port of `tools/gen_tokens.py`).
//
//  It SEEDS from the currently active theme (preset, custom, or bundled) so you
//  tweak what you see — opening it never resets your theme. Edits are a live
//  preview only; **Apply** commits the recipe (and syncs the demo's theme store),
//  **Cancel** reverts to the previously active theme. Export the recipe as a
//  Codable `theme.json`, an `apply(...)` snippet, or a full baked token JSON.
//

import SwiftUI
import ThemeKit

struct ThemeConfiguratorView: View {
    @ThemeContext private var theme
    @EnvironmentObject private var store: DemoThemeStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ConfigState()
    @State private var applied = false
    @State private var live = false            // gates the seeding change from applying
    @State private var applyTask: Task<Void, Never>?
    @State private var chipOn = true
    // Theme-wide micro-animation switch — shared with the app root via the same key.
    @AppStorage("themekit.microAnimations") private var microAnimations = true

    private let fonts = ["Montserrat", "System", "SystemRounded", "SystemSerif", "SystemMono"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    preview
                    colorsSection
                    scaleSection
                    fontSection
                    exportSection
                    Button("Reset to default") { draft = ConfigState() }
                        .font(.callout)
                }
                .padding()
            }
            .navigationTitle("Theme Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { commit() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = seed()
                // Let the seeding assignment settle before live edits apply, so
                // opening the sheet doesn't regenerate a bundled theme.
                DispatchQueue.main.async { live = true }
            }
            .onChange(of: draft) { _, new in
                if live { scheduleApply(new) }   // debounced live preview (no per-tick regen)
            }
            .onDisappear {
                applyTask?.cancel()
                if !applied { store.reapplyActive() }   // revert preview on cancel
            }
        }
    }

    /// Commit the draft: persist + apply + sync the demo's theme store.
    private func commit() {
        applyTask?.cancel()
        store.applyGenerated(draft.themeConfig)
        applied = true
        dismiss()
    }

    /// Debounced live preview: coalesce rapid slider / color-picker changes and
    /// regenerate the whole palette only once movement settles, so dragging stays
    /// smooth instead of regenerating on every tick.
    private func scheduleApply(_ state: ConfigState) {
        applyTask?.cancel()
        applyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)   // ~110ms quiet period
            if Task.isCancelled { return }
            Theme.shared.apply(state.themeConfig)
        }
    }

    /// Apply immediately — used the instant a slider drag ends, so release feels crisp.
    private func applyNow() {
        applyTask?.cancel()
        Theme.shared.apply(draft.themeConfig)
    }

    /// Seed the UI from the active theme — a preset / custom recipe exactly, or a
    /// bundled JSON theme approximated from its live primary + surface colors.
    private func seed() -> ConfigState {
        if let cfg = store.activeConfig { return ConfigState(cfg) }
        if let id = store.presetID, let preset = ThemePreset.named(id) { return ConfigState(preset.config) }
        return ConfigState(ThemeConfig(primaryHex: SemanticColor.primary.solid.hexRGB,
                                       baseHex: theme.background(.bgWhite).hexRGB,
                                       dark: store.isDark))
    }

    // MARK: Live preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            Text("Live preview").font(.caption).foregroundStyle(.secondary)
            Card {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                    HStack {
                        Text("Title").textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                        Badge("New").badgeStyle(.info)
                    }
                    Text("The theme regenerates live — primary, secondary, accent, surfaces, all of it.")
                        .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    ButtonGroup(.horizontal) {
                        PrimaryButton("Primary") {}
                        SecondaryButton("Secondary") {}
                        OutlineButton("Outline") {}
                    }
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Chip("Selected", isSelected: $chipOn).chipStyle(.solid)
                        Chip("Empty", isSelected: .constant(false))
                    }
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        InfoBanner("Info", type: .info)
                        InfoBanner("Success", type: .success)
                    }
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        InfoBanner("Warning", type: .warning)
                        InfoBanner("Error", type: .error)
                    }
                    ladder("Primary", .primary)
                    ladder("Secondary", .secondary)
                    ladder("Accent", .accent)
                }
            }
            // Force the whole preview subtree to rebuild on each theme change so
            // every leaf (chip / banner / ladder) re-reads the regenerated tokens.
            .id(theme.revision)
        }
    }

    private func ladder(_ label: String, _ color: SemanticColor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(SemanticColor.Shade.allCases, id: \.self) { shade in
                    Rectangle().fill(color.shade(shade)).frame(height: 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: Controls

    private var colorsSection: some View {
        section("Colors") {
            VStack(spacing: 14) {
                ColorPicker("Primary", selection: $draft.primary, supportsOpacity: false)
                ColorPicker("Secondary", selection: $draft.secondary, supportsOpacity: false)
                ColorPicker("Accent", selection: $draft.accent, supportsOpacity: false)
                ColorPicker("Base (surface)", selection: $draft.base, supportsOpacity: false)
                sliderRow("Tint (re-skin strength)", $draft.tint, 0...0.25, "%.2f")
                Toggle("Dark mode", isOn: $draft.dark)
                Toggle("Micro-animations (theme-wide)", isOn: $microAnimations)
            }
        }
    }

    private var scaleSection: some View {
        section("Scale") {
            VStack(spacing: 14) {
                sliderRow("Radius ×", $draft.radiusScale, 0.25...2, "%.2f")
                sliderRow("Spacing ×", $draft.spacingScale, 0.7...1.5, "%.2f")
                sliderRow("Shadow ×", $draft.shadowScale, 0...2, "%.2f")
            }
        }
    }

    private var fontSection: some View {
        section("Typography") {
            VStack(spacing: 14) {
                Picker("Font", selection: $draft.font) {
                    ForEach(fonts, id: \.self) { Text($0).tag($0) }
                }
                sliderRow("Font ×", $draft.fontScale, 0.85...1.25, "%.2f")
            }
        }
    }

    private var exportSection: some View {
        section("Export") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drop this into your project — add the package, then apply the recipe at launch.")
                    .font(.caption).foregroundStyle(.secondary)

                codeCard("theme.json  (Codable recipe)", configJSON) {
                    UIPasteboard.general.string = configJSON; flash("Config JSON copied")
                }
                codeCard("Apply (Swift)", usageSwift) {
                    UIPasteboard.general.string = usageSwift; flash("Swift code copied")
                }
                Button {
                    if let data = Theme.shared.generatedTokenJSON(for: draft.themeConfig),
                       let s = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = s; flash("Full token JSON copied (\(data.count) bytes)")
                    }
                } label: {
                    Label("Copy full token JSON (Python-free, bundle + loadTheme)", systemImage: "doc.on.doc").font(.caption)
                }
            }
        }
    }

    private func codeCard(_ title: String, _ code: String, copy: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: copy) { Image(systemName: "doc.on.doc").font(.caption) }
            }
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.text(.textSecondary))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(theme.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var configJSON: String {
        (try? draft.themeConfig.jsonData()).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private var usageSwift: String {
        """
        // 1) at launch — restore/apply:
        let data = Data(contentsOf: themeJSONURL)
        try Theme.shared.apply(ThemeConfig(jsonData: data))
        // 2) at the root:
        ContentView().themeKit()
        """
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).textStyle(.headingSm).foregroundStyle(.secondary)
            content()
        }
    }

    private func sliderRow(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: fmt, value.wrappedValue))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { applyNow() }   // commit the final value the moment the drag ends
            })
        }
    }
}

struct ConfigState: Equatable {
    var primary: Color
    var secondary: Color
    var accent: Color
    var base: Color
    var tint: Double
    var radiusScale: Double
    var spacingScale: Double
    var fontScale: Double
    var shadowScale: Double
    var font: String
    var dark: Bool

    init(primary: Color = Color(hex: "056bfd"), secondary: Color = Color(hex: "7c3aed"),
         accent: Color = Color(hex: "0fb4ab"), base: Color = Color(hex: "ffffff"),
         tint: Double = 0.06, radiusScale: Double = 1, spacingScale: Double = 1,
         fontScale: Double = 1, shadowScale: Double = 1, font: String = "Montserrat", dark: Bool = false) {
        self.primary = primary; self.secondary = secondary; self.accent = accent; self.base = base
        self.tint = tint; self.radiusScale = radiusScale; self.spacingScale = spacingScale
        self.fontScale = fontScale; self.shadowScale = shadowScale; self.font = font; self.dark = dark
    }

    /// Seed the UI from a portable recipe (a preset, a saved custom config, or a
    /// bundled-theme approximation). Missing brand colors fall back to primary.
    init(_ c: ThemeConfig) {
        primary = Color(hex: c.primaryHex)
        secondary = Color(hex: c.secondaryHex ?? c.primaryHex)
        accent = Color(hex: c.accentHex ?? c.primaryHex)
        base = Color(hex: c.baseHex ?? (c.dark ? "1d232a" : "ffffff"))
        tint = c.tint; radiusScale = c.radiusScale; spacingScale = c.spacingScale
        fontScale = c.fontScale; shadowScale = c.shadowScale; font = c.font; dark = c.dark
    }

    /// The portable, Codable recipe this UI state represents.
    var themeConfig: ThemeConfig {
        ThemeConfig(primaryHex: primary.hexRGB, baseHex: base.hexRGB,
                    secondaryHex: secondary.hexRGB, accentHex: accent.hexRGB,
                    tint: tint, dark: dark, font: font, fontScale: fontScale,
                    radiusScale: radiusScale, spacingScale: spacingScale, shadowScale: shadowScale)
    }
}

extension Color {
    /// 6-digit RRGGBB hex of this color in **sRGB** — the space the generator
    /// works in. Converting first keeps wide-gamut / Display-P3 picks from drifting
    /// and clamps any out-of-range components.
    var hexRGB: String {
        #if canImport(UIKit)
        let cg = UIColor(self).cgColor
        let comps = CGColorSpace(name: CGColorSpace.sRGB)
            .flatMap { cg.converted(to: $0, intent: .defaultIntent, options: nil) }?.components
            ?? cg.components ?? [0, 0, 0, 1]
        func ch(_ i: Int) -> Int {
            let v = comps.count > i ? comps[i] : (comps.first ?? 0)   // grayscale → 1 component
            return Int((min(max(v, 0), 1) * 255).rounded())
        }
        return String(format: "%02x%02x%02x", ch(0), ch(1), ch(2))
        #else
        return "056bfd"
        #endif
    }
}

#Preview {
    ThemeConfiguratorView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
