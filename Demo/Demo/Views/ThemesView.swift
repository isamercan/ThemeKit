//
//  ThemesView.swift
//  Demo
//  Created by İsa Mercan on 29.06.2026.
//
//  The "Themes" tab — a daisyUI-style theme gallery. Tap any card to switch the
//  whole app's theme live; a preview strip up top shows real ThemeKit components
//  re-coloring with the active choice.
//

import SwiftUI
import ThemeKit

struct ThemesView: View {
    @EnvironmentObject private var store: DemoThemeStore
    @Environment(Theme.self) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    header
                    livePreview
                        // Force a full rebuild of the static-leaf preview on swap.
                        .id(theme.revision)
                    Text("\(DaisyTheme.all.count) themes from daisyUI — tap to switch")
                        .textStyle(.labelSm700)
                        .foregroundStyle(theme.text(.textTertiary))
                    ThemePicker(
                        selection: Binding(get: { store.daisyID }, set: { _ in }),
                        onSelect: { store.applyDaisy($0) }
                    )
                }
                .padding()
            }
            .background(theme.background(.bgElevatorPrimary).ignoresSafeArea())
            .navigationTitle("Themes")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.daisyID.flatMap { DaisyTheme.named($0)?.name } ?? "daisyUI Themes")
                .textStyle(.headingBase)
                .foregroundStyle(theme.text(.textPrimary))
            Text("Inject any daisyUI theme into ThemeKit and switch on the fly.")
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Real ThemeKit components, painted by the *active* theme tokens.
    private var livePreview: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Badge("Primary", style: .info, variant: .solid)
                    Badge("Success", style: .success)
                    Badge("Error", style: .error)
                }
                Text("The quick brown fox jumps over the lazy dog.")
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                // The three daisyUI brand colors — primary / secondary / accent.
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ThemeButton("Primary", color: .primary, variant: .solid) {}
                    ThemeButton("Secondary", color: .secondary, variant: .solid) {}
                    ThemeButton("Accent", color: .accent, variant: .solid) {}
                }
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    PrimaryButton("Continue") {}
                    SecondaryButton("Cancel") {}
                }
            }
        }
    }
}

#Preview {
    ThemesView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
