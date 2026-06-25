//
//  ThemeConfiguratorView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  A LIVE theme configurator: pick an accent color + tint + scale knobs (radius /
//  spacing / font / shadow) + font family + dark, and the whole app re-skins
//  instantly via `Theme.shared.applyGenerated(...)` — the runtime port of
//  `tools/gen_tokens.py`. Includes an Export that prints the equivalent
//  `applyGenerated` call and the `build_theme(...)` params for a permanent theme.
//

import SwiftUI
import ThemeKit

struct ThemeConfiguratorView: View {
    @ThemeContext private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var config = ConfigState()
    @State private var chipOn = true

    private let fonts = ["Montserrat", "System", "SystemRounded", "SystemSerif", "SystemMono"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    preview
                    accentSection
                    scaleSection
                    fontSection
                    exportSection
                    Button("Reset to default") { config = ConfigState(); apply(config) }
                        .font(.callout)
                }
                .padding()
            }
            .navigationTitle("Theme Configurator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { apply(config) }
            .onChange(of: config) { _, new in apply(new) }
        }
    }

    private func apply(_ c: ConfigState) {
        Theme.shared.apply(c.themeConfig)
    }

    // MARK: Live preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            Text("Live preview").font(.caption).foregroundStyle(.secondary)
            Card {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                    HStack {
                        Text("Başlık").textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                        Badge("Yeni", style: .info)
                    }
                    Text("Tema canlı olarak yeniden üretiliyor — accent, neutral, yüzeyler hepsi.")
                        .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        PrimaryButton("Birincil") {}
                        OutlineButton("İkincil") {}
                    }
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Chip("Seçili", isSelected: $chipOn, selectionStyle: .solid)
                        Chip("Boş", isSelected: .constant(false))
                    }
                    InfoBanner("Bilgilendirme mesajı.", type: .info)
                    ladder
                }
            }
            // Force the whole preview subtree to rebuild on each theme change so
            // every leaf (chip / banner / ladder) re-reads the regenerated tokens.
            .id(theme.revision)
        }
    }

    private var ladder: some View {
        HStack(spacing: 0) {
            ForEach(SemanticColor.Shade.allCases, id: \.self) { shade in
                Rectangle().fill(SemanticColor.primary.shade(shade)).frame(height: 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: Controls

    private var accentSection: some View {
        section("Accent") {
            VStack(spacing: 14) {
                ColorPicker("Primary color", selection: $config.primary, supportsOpacity: false)
                sliderRow("Tint (re-skin strength)", $config.tint, 0...0.25, "%.2f")
                Toggle("Dark mode", isOn: $config.dark)
            }
        }
    }

    private var scaleSection: some View {
        section("Scale") {
            VStack(spacing: 14) {
                sliderRow("Radius ×", $config.radiusScale, 0.25...2, "%.2f")
                sliderRow("Spacing ×", $config.spacingScale, 0.7...1.5, "%.2f")
                sliderRow("Shadow ×", $config.shadowScale, 0...2, "%.2f")
            }
        }
    }

    private var fontSection: some View {
        section("Typography") {
            VStack(spacing: 14) {
                Picker("Font", selection: $config.font) {
                    ForEach(fonts, id: \.self) { Text($0).tag($0) }
                }
                sliderRow("Font ×", $config.fontScale, 0.85...1.25, "%.2f")
            }
        }
    }

    private var exportSection: some View {
        section("Export") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drop this into your project — add the package, then apply the recipe at launch.")
                    .font(.caption).foregroundStyle(.secondary)

                codeCard("theme.json  (Codable recipe)", configJSON) {
                    UIPasteboard.general.string = configJSON; flash("Config JSON kopyalandı")
                }
                codeCard("Apply (Swift)", usageSwift) {
                    UIPasteboard.general.string = usageSwift; flash("Swift kodu kopyalandı")
                }
                Button {
                    if let data = Theme.shared.generatedTokenJSON(for: config.themeConfig),
                       let s = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = s; flash("Full token JSON kopyalandı (\(data.count) byte)")
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
        (try? config.themeConfig.jsonData()).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private var usageSwift: String {
        """
        // 1) at launch — restore/apply:
        let data = Data(contentsOf: themeJSONURL)
        try Theme.shared.apply(ThemeConfig(jsonData: data))
        // 2) at the root:
        ContentView().globalUITheme()
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
            Slider(value: value, in: range)
        }
    }
}

struct ConfigState: Equatable {
    var primary: Color = Color(hex: "056bfd")
    var tint: Double = 0.06
    var radiusScale: Double = 1.0
    var spacingScale: Double = 1.0
    var fontScale: Double = 1.0
    var shadowScale: Double = 1.0
    var font: String = "Montserrat"
    var dark: Bool = false

    /// The portable, Codable recipe this UI state represents.
    var themeConfig: ThemeConfig {
        ThemeConfig(primaryHex: primary.hexRGB, tint: tint, dark: dark, font: font,
                    fontScale: fontScale, radiusScale: radiusScale, spacingScale: spacingScale, shadowScale: shadowScale)
    }
}

extension Color {
    /// 6-digit RRGGBB hex of this color (for the theme generator).
    var hexRGB: String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        #else
        return "056bfd"
        #endif
    }
}

#Preview {
    ThemeConfiguratorView()
        .environmentObject(Theme.shared)
        .environmentObject(DemoThemeStore())
}
