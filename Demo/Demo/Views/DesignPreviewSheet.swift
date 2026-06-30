//
//  DesignPreviewSheet.swift
//  Demo
//  Created by İsa Mercan on 30.06.2026.
//
//  Confirm step for an imported design.md. The parsed config is already applied
//  live (so the preview shows real ThemeKit components in the new look); this
//  sheet surfaces exactly what was derived from the free text — values, warnings,
//  and a confidence badge — before the user commits or reverts.
//

import SwiftUI
import ThemeKit

struct DesignPreviewSheet: View {
    @Environment(Theme.self) private var theme
    let payload: PreviewPayload
    /// Called with `true` to commit, `false` to revert.
    let onFinish: (Bool) -> Void

    private var result: DesignParseResult { payload.result }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    provenance
                    livePreview.id(theme.revision)
                    derivedValues
                    if !result.warnings.isEmpty { warnings }
                }
                .padding()
            }
            .navigationTitle(payload.spec.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onFinish(false) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { onFinish(true) }.fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled()   // force an explicit Apply / Cancel
        }
    }

    private var provenance: some View {
        HStack(spacing: 8) {
            Label(methodLabel, systemImage: methodIcon)
            Spacer()
            Text(confidenceLabel)
                .textStyle(.labelSm700)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(confidenceColor.opacity(0.15), in: Capsule())
                .foregroundStyle(confidenceColor)
        }
        .textStyle(.labelSm700)
        .foregroundStyle(theme.text(.textSecondary))
    }

    private var livePreview: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                HStack {
                    Text("Live preview").textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    Spacer()
                    Badge("New").badgeStyle(.info)
                }
                Text("Every component re-skins to the imported look.")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                ButtonGroup(.horizontal) {
                    PrimaryButton("Primary") {}
                    SecondaryButton("Secondary") {}
                    OutlineButton("Outline") {}
                }
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    InfoBanner("Info").variant(.info)
                    InfoBanner("Success").variant(.success)
                }
            }
        }
    }

    private var derivedValues: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Derived from design.md").textStyle(.headingSm).foregroundStyle(.secondary)
            ForEach(DesignParseResult.Field.allCases, id: \.self) { field in
                if let value = result.extracted[field] {
                    HStack {
                        Text(field.rawValue).textStyle(.labelSm700).foregroundStyle(theme.text(.textSecondary))
                        Spacer()
                        Text(value).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.text(.textPrimary))
                    }
                }
            }
        }
        .padding()
        .background(theme.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(result.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
        }
    }

    // MARK: Labels

    private var methodLabel: String {
        switch result.method {
        case .heuristic: return "Parsed on-device"
        case .resolver(let name): return "Refined by \(name.capitalized)"
        }
    }
    private var methodIcon: String {
        switch result.method {
        case .heuristic: return "cpu"
        case .resolver: return "sparkles"
        }
    }
    private var confidenceLabel: String {
        switch result.confidence {
        case .low: return "Low confidence"
        case .medium: return "Medium confidence"
        case .high: return "High confidence"
        }
    }
    private var confidenceColor: Color {
        switch result.confidence {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
}
