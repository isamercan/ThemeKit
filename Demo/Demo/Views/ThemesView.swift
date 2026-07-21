//
//  ThemesView.swift
//  Demo
//  Created by İsa Mercan on 29.06.2026.
//
//  The "Themes" tab — a theme-preset gallery. Tap any card to switch the
//  whole app's theme live; a preview strip up top shows real ThemeKit components
//  re-coloring with the active choice.
//

import SwiftUI
import ThemeKit

struct ThemesView: View {
    @EnvironmentObject private var store: DemoThemeStore
    @Environment(\.theme) private var theme

    var body: some View {
        CompatNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    header
                    livePreview
                        // Force a full rebuild of the static-leaf preview on swap.
                        .id(theme.revision)
                    brandThemes
                    Text("\(ThemePreset.all.count) theme presets — tap to switch")
                        .textStyle(.labelSm700)
                        .foregroundStyle(theme.text(.textTertiary))
                    ThemePicker(
                        selection: Binding(get: { store.presetID }, set: { _ in }),
                        onSelect: { store.applyPreset($0) }
                    )
                }
                .padding()
            }
            .background(theme.background(.bgBase).ignoresSafeArea())
            .navigationTitle("Themes")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.presetID.flatMap { ThemePreset.named($0)?.name } ?? "Theme presets")
                .textStyle(.headingBase)
                .foregroundStyle(theme.text(.textPrimary))
            Text("Inject any theme preset into ThemeKit and switch on the fly.")
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Brand themes distilled from the exported Figma component-token files
    /// (ETS / UB). Tapping one applies its full recipe — brand seeds + font +
    /// card radius — via the generated-config path (so it persists across launch).
    private var brandThemes: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text("Brand themes — from Figma component tokens")
                .textStyle(.labelSm700)
                .foregroundStyle(theme.text(.textTertiary))
            ThemePicker(
                selection: Binding(
                    get: { BrandTheme.matching(store.activeConfig)?.id },
                    set: { _ in }
                ),
                themes: BrandTheme.presets,
                onSelect: { preset in
                    if let brand = BrandTheme.all.first(where: { $0.id == preset.id }) {
                        store.applyGenerated(brand.config)
                    }
                }
            )
        }
    }

    /// Real ThemeKit components, painted by the *active* theme tokens.
    private var livePreview: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Badge("Primary").badgeStyle(.info).variant(.solid)
                    Badge("Success").badgeStyle(.success)
                    Badge("Error").badgeStyle(.error)
                }
                Text("The quick brown fox jumps over the lazy dog.")
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                // The three brand colors — primary / secondary / accent. A ButtonGroup
                // keeps each label on one line and wraps to the next row when they
                // don't fit, instead of squeezing the text onto two lines.
                ButtonGroup(.horizontal) {
                    ThemeButton("Primary") {}.color(.primary).variant(.solid)
                    ThemeButton("Secondary") {}.color(.secondary).variant(.solid)
                    ThemeButton("Accent") {}.color(.accent).variant(.solid)
                }
                ButtonGroup(.horizontal) {
                    PrimaryButton("Continue") {}
                    SecondaryButton("Cancel") {}
                }
            }
        }
    }
}

#Preview {
    ThemesView()
        .environment(\.theme, Theme.shared)
        .environmentObject(DemoThemeStore())
}
