// REGISTER: Live Localization · deep-link "Live Localization" · molecule · isNew
//
//  LiveLocalizationDemo.swift
//  Demo
//
//  ADR-0003 phase 2 — restart-free language switching, end to end:
//  `LanguageSwitcher` drives `ThemeKitStrings.languageBinding`, the stage sits
//  under `.themeKitLocalized()`, and BOTH string classes flip live EN ↔ TR:
//
//  - a View string (`Coupon`'s built-in "Promo code:" label, the
//    "Select language" placeholder),
//  - a NON-View enum string (`ColorChannel.title` — a computed property on an
//    enum, nowhere near `@Environment`).
//
//  The Turkish values come from this app target's own `ThemeKit.xcstrings`
//  (Demo/Demo/ThemeKit.xcstrings) via the ZERO-CONFIG path: the resolver
//  probes `Bundle.main`'s "ThemeKit" table — the demo never calls
//  `register`. Arabic is included to show the automatic RTL flip.
//

import SwiftUI
import ThemeKit

struct LiveLocalizationDemo: View {
    @State private var showsRTL = false

    private var languages: [AppLanguage] {
        showsRTL
            ? [AppLanguage(code: "en"), AppLanguage(code: "tr"), AppLanguage(code: "ar")]
            : [AppLanguage(code: "en"), AppLanguage(code: "tr")]
    }

    var body: some View {
        ComponentStage(".themeKitLocalized()", inspector: [
            ("root modifier", ".themeKitLocalized()"),
            ("switch driver", "ThemeKitStrings.languageBinding"),
            ("catalog", "Demo target's ThemeKit.xcstrings (zero-config)"),
        ]) {
            // In an app this modifier sits ONCE at the root; scoping it to the
            // stage keeps the demo chrome (knobs, nav) in English.
            stage.themeKitLocalized()
        } knobs: {
            Toggle("Offer Arabic (RTL flip)", isOn: $showsRTL)
            Text("Strings resolve from the demo app's ThemeKit.xcstrings — drop-a-file, no setup. "
                 + "The switch is restart-free: the root provider re-identifies the tree, so even "
                 + "enum-computed strings (Hue/Saturation/…) re-resolve.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var stage: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
            LanguageSwitcher(languages, selection: ThemeKitStrings.languageBinding)
                .variant(.inline)

            // View-graph default string — Coupon's built-in label.
            Coupon(code: "THEME25")

            // NON-View enum strings — ColorChannel.title is a computed
            // property on an enum; it flips because it re-resolves through the
            // process-global when the re-identified bodies re-run.
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(ColorChannel.allCases, id: \.self) { channel in
                    Badge(channel.title)
                }
            }
        }
    }
}
