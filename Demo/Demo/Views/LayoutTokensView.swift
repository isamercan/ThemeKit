//
//  LayoutTokensView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  A foundations screen for the LAYOUT tokens — spacing, padding, corner radius
//  and elevation. All values resolve from the active theme JSON, so switching
//  Default / Ocean / Sunset re-scales everything live (ocean radius ×1.5, sunset
//  ×0.5, spacing ×1.15 / ×0.9, etc.).
//

import SwiftUI
import GlobalUIComponents

struct LayoutTokensView: View {
    // Re-render when the theme (hence the resolved token values) changes.
    @EnvironmentObject private var theme: Theme

    private let spacingKeys = Theme.SpacingKey.allCases
    private let radiusKeys = Theme.RadiusKey.allCases
    private let shadowStyles = ShadowStyle.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    intro
                    spacingSection
                    paddingSection
                    radiusSection
                    shadowSection
                }
                .padding()
            }
            .navigationTitle("Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeSwitcherMenu() } }
        }
    }

    private var intro: some View {
        Text("Spacing · padding · radius · elevation — all from the theme JSON. Switch theme to see them re-scale.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: Spacing — a bar whose width equals the token, so the scale is literal.

    private var spacingSection: some View {
        section("Spacing") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(spacingKeys, id: \.self) { key in
                    HStack(spacing: 12) {
                        tokenLabel(name: caseName(key), raw: key.rawValue, value: key.value)
                            .frame(width: 132, alignment: .leading)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.shared.background(.bgHero))
                            .frame(width: max(key.value, 1), height: 14)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Padding — nested boxes; the inset gap IS the spacing token.

    private var paddingSection: some View {
        section("Padding") {
            let samples: [Theme.SpacingKey] = [.sm, .md, .base, .lg]
            return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                ForEach(samples, id: \.self) { key in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.shared.background(.bgHero).opacity(0.12))
                            Text("content")
                                .textStyle(.labelSm600)
                                .foregroundStyle(Theme.shared.text(.textHero))
                                .padding(key.value)
                                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .padding(6)
                        }
                        .frame(height: 96)
                        Text("\(caseName(key)) · \(Int(key.value))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Radius — a rounded square per token.

    private var radiusSection: some View {
        section("Corner radius") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 16) {
                ForEach(radiusKeys, id: \.self) { key in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: key.value, style: .continuous)
                            .fill(Theme.shared.background(.bgElevatorTertiary))
                            .overlay(
                                RoundedRectangle(cornerRadius: key.value, style: .continuous)
                                    .strokeBorder(Theme.shared.border(.borderHero), lineWidth: 1.5)
                            )
                            .frame(width: 72, height: 72)
                        Text(caseName(key))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.shared.text(.textPrimary))
                        Text("\(Int(key.value))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Elevation — a card per shadow token.

    private var shadowSection: some View {
        section("Elevation") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 16)], spacing: 16) {
                ForEach(shadowStyles, id: \.self) { style in
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.shared.background(.bgWhite))
                            .frame(height: 64)
                            .themeShadow(style)
                        Text(String(describing: style))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).textStyle(.headingSm).foregroundStyle(.secondary)
            content()
        }
    }

    private func tokenLabel(name: String, raw: String, value: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.shared.text(.textPrimary))
            Text("\(Int(value))").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func caseName<T>(_ value: T) -> String { String(describing: value) }
}

#Preview {
    LayoutTokensView()
        .environmentObject(Theme.shared)
        .environmentObject(DemoThemeStore())
}
