//
//  ThemeInjectionDemo.swift
//  Demo
//
//  Live proof of per-subtree theming: pick a Theme and it is injected into just
//  this preview via `.theme(_:)`. Every component below reads `@Environment(\.theme)`,
//  so the whole subtree re-skins — with no `Theme.shared` mutation and no effect on
//  the rest of the app.
//

import SwiftUI
import ThemeKit

struct ThemeInjectionDemo: View {
    private static func named(_ name: String) -> Theme {
        let t = Theme(); t.loadTheme(named: name); return t
    }

    /// Distinct Theme instances — two bundled, one generated on-device from a brand hex.
    private static let options: [(name: String, theme: Theme)] = {
        let grape = Theme(); grape.applyGenerated(primaryHex: "#7C3AED")
        return [
            ("Default", Theme.shared),
            ("Ocean", named("oceanTheme")),
            ("Sunset", named("sunsetTheme")),
            ("Grape", grape),
        ]
    }()

    @State private var selected = ThemeInjectionDemo.initialSelection
    private var active: Theme { Self.options.first { $0.name == selected }?.theme ?? Theme.shared }

    /// Deep-link the starting theme for screenshots: launch with `-injectTheme <name>`.
    private static var initialSelection: String {
        let arg = UserDefaults.standard.string(forKey: "injectTheme") ?? "Default"
        return options.contains { $0.name == arg } ? arg : "Default"
    }

    var body: some View {
        ComponentStage(
            "Theme Injection",
            inspector: [("injected", selected), ("mechanism", ".theme(_:) → \\.theme env")]
        ) {
            sample.theme(active)   // inject a Theme into just this subtree
        } knobs: {
            Picker("Injected theme", selection: $selected) {
                ForEach(Self.options.map(\.name), id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            Text("Every component below reads `@Environment(\\.theme)`. Injecting **\(selected)** re-skins this subtree only — `Theme.shared` is untouched, so the rest of the app keeps its theme.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sample: some View {
        VStack(alignment: .leading, spacing: 14) {
            Hero(title: "Stay", subtitle: "Find your spot", ctaTitle: "Book", action: {})
                .frame(height: 150)
            HStack(spacing: 8) {
                Badge("Info").badgeStyle(.info).icon("bell.fill")
                Tag("Filter", onRemove: {})
            }
            InfoBanner("Subtree-themed banner").variant(.success)
            Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))
            PrimaryButton("Continue", block: true) {}
        }
    }
}
