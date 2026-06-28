//
//  ThemeGalleryView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import ThemeKit

struct ThemeGalleryView: View {
    @ThemeContext private var theme
    @EnvironmentObject private var themeStore: DemoThemeStore
    @State private var showConfigurator = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    controlBar
                    configuratorButton
                    paletteSection
                    section("Foreground", Theme.ForegroundColorKey.allCases) { theme.foreground($0) }
                    section("Background", Theme.BackgroundColorKey.allCases) { theme.background($0) }
                    section("Border", Theme.BorderColorKey.allCases) { theme.border($0) }
                    section("Text", Theme.TextColorKey.allCases) { theme.text($0) }
                }
                .padding()
            }
            .navigationTitle("Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeSwitcherMenu() } }
            .sheet(isPresented: $showConfigurator) { ThemeConfiguratorView() }
        }
    }

    private var configuratorButton: some View {
        Button { showConfigurator = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme Configurator").textStyle(.labelBase600)
                    Text("Canlı renk + tint + ölçek + font").textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(theme.text(.textPrimary))
            .padding()
            .background(theme.background(.bgElevatorTertiary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.border(.borderHero), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme + dark control

    private var controlBar: some View {
        HStack {
            Picker("Theme", selection: Binding(get: { themeStore.current }, set: { themeStore.select($0) })) {
                ForEach(DemoTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Dark", isOn: Binding(get: { themeStore.isDark }, set: { themeStore.setDark($0) }))
                .labelsHidden()
            Image(systemName: themeStore.isDark ? "moon.fill" : "moon")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Palette ladders (Ant-style 50…900)

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palette · 50…900").textStyle(.headingBase)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Each semantic color expanded into an Ant-style ladder. **Full re-skin**: switching theme re-tints **Primary**, **Info**, and the **Neutral** ramp (surfaces / borders / text) toward the theme hue. **Success / Warning / Error** keep their meaning. Dark mode inverts every ladder.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(SemanticColor.allCases, id: \.self) { color in
                VStack(alignment: .leading, spacing: 3) {
                    Text(color == .primary ? "Primary · theme accent" : color.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color == .primary ? theme.text(.textHero) : theme.text(.textSecondary))
                    HStack(spacing: 0) {
                        ForEach(SemanticColor.Shade.allCases, id: \.self) { step in
                            color.shade(step)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border(.borderPrimary), lineWidth: 0.5))
                }
            }
        }
    }

    private func section<Key: RawRepresentable & Hashable>(
        _ title: String,
        _ keys: [Key],
        color: @escaping (Key) -> Color
    ) -> some View where Key.RawValue == String {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.headingBase)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    VStack(spacing: 4) {
                        color(key)
                            .frame(height: 52)
                            .cornerRadius(.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value)
                                    .stroke(theme.border(.borderPrimary), lineWidth: 0.5)
                            )
                        Text(key.rawValue.replacingOccurrences(of: ".", with: "/"))
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}

#Preview {
    ThemeGalleryView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
