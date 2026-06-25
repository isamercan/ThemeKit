//
//  ComponentStage.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Shared shell for every component demo: a live preview canvas (light/dark +
//  theme switcher), the knob controls, and a live state inspector.
//

import SwiftUI
import UIKit
import ThemeKit

struct ComponentStage<Preview: View, Knobs: View>: View {
    private let title: String
    private let inspector: [(String, String)]
    private let hasKnobs: Bool
    @ViewBuilder private let preview: () -> Preview
    @ViewBuilder private let knobs: () -> Knobs

    @EnvironmentObject private var themeStore: DemoThemeStore
    @Environment(\.componentUsage) private var usage
    @State private var copied = false

    private init(
        title: String,
        inspector: [(String, String)],
        hasKnobs: Bool,
        preview: @escaping () -> Preview,
        knobs: @escaping () -> Knobs
    ) {
        self.title = title
        self.inspector = inspector
        self.hasKnobs = hasKnobs
        self.preview = preview
        self.knobs = knobs
    }

    init(
        _ title: String,
        inspector: [(String, String)] = [],
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder knobs: @escaping () -> Knobs
    ) {
        self.init(title: title, inspector: inspector, hasKnobs: true, preview: preview, knobs: knobs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                canvas
                themeBar
                if hasKnobs { sectionCard("Properties") { knobs() } }
                if !inspector.isEmpty { inspectorCard }
                if let usage { usageCard(usage) }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            Theme.shared.background(.bgWhite)
            preview()
                .padding(24)
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.shared.border(.borderPrimary), lineWidth: 0.5))
    }

    private var themeBar: some View {
        HStack {
            Picker("Theme", selection: Binding(get: { themeStore.current }, set: { themeStore.select($0) })) {
                ForEach(DemoTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Dark", isOn: Binding(get: { themeStore.isDark }, set: { themeStore.setDark($0) }))
                .labelsHidden()
            Image(systemName: themeStore.isDark ? "moon.fill" : "moon").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Cards

    private func sectionCard<Content: View>(_ heading: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func usageCard(_ code: String) -> some View {
        sectionCard("Usage") {
            VStack(alignment: .leading, spacing: 10) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var inspectorCard: some View {
        sectionCard("State") {
            VStack(spacing: 6) {
                ForEach(Array(inspector.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text(item.1).font(.system(.caption, design: .monospaced).weight(.semibold))
                    }
                }
            }
        }
    }
}

// Convenience for static previews (no knobs).
extension ComponentStage where Knobs == EmptyView {
    init(
        _ title: String,
        inspector: [(String, String)] = [],
        @ViewBuilder preview: @escaping () -> Preview
    ) {
        self.init(title: title, inspector: inspector, hasKnobs: false, preview: preview, knobs: { EmptyView() })
    }
}
