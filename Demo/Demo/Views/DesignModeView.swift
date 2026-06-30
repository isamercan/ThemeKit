//
//  DesignModeView.swift
//  Demo
//  Created by İsa Mercan on 30.06.2026.
//
//  Design Mode tab — bring every component into another app's look by importing a
//  free-form `design.md` (bundled catalog, file picker, or remote URL) or pasting
//  one. The markdown is parsed into a `ThemeConfig` (heuristic on-device, or
//  refined by Claude when an API key is set), previewed for confirmation, then
//  applied via the existing `DemoThemeStore` so it persists and re-skins the app.
//

import SwiftUI
import ThemeKit
import UniformTypeIdentifiers

struct DesignModeView: View {
    @EnvironmentObject private var store: DemoThemeStore
    @Environment(Theme.self) private var theme

    @AppStorage("themekit.anthropicKey") private var anthropicKey = ""

    private enum Tab: String, CaseIterable, Identifiable { case catalog = "Catalog", importer = "Import"; var id: String { rawValue } }
    @State private var tab: Tab = .catalog

    @State private var specs: [DesignSpec] = []
    @State private var urlText = ""
    @State private var pasteText = ""
    @State private var showFileImporter = false
    @State private var loading = false
    @State private var errorMessage: String?

    // The confirm/preview sheet payload.
    @State private var preview: PreviewPayload?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    header
                    Picker("Source", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .catalog: catalogSection
                    case .importer: importSection
                    }
                }
                .padding()
            }
            .background(theme.background(.bgElevatorPrimary).ignoresSafeArea())
            .navigationTitle("Design Mode")
            .overlay { if loading { ProgressView().controlSize(.large) } }
        }
        .onAppear { if specs.isEmpty { specs = DesignSpecCatalog.bundled() } }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: importableTypes) { result in
            handleFileImport(result)
        }
        .alert("Couldn't import design", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .sheet(item: $preview) { payload in
            DesignPreviewSheet(payload: payload) { committed in
                if committed {
                    store.applyDesign(payload.result, specID: payload.spec.specIDForPersistence)
                } else {
                    store.reapplyActive()   // revert the live preview
                }
                preview = nil
            }
            .environmentObject(store)
            .environment(theme)
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import a design.md and re-skin every component.")
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textSecondary))
            HStack(spacing: 6) {
                Image(systemName: anthropicKey.isEmpty ? "cpu" : "sparkles")
                Text(anthropicKey.isEmpty ? "Parsing on-device (heuristic)" : "Refined by Claude")
            }
            .textStyle(.labelSm700)
            .foregroundStyle(theme.text(.textTertiary))
            if let id = store.activeDesignSpecID {
                Text("Active design mode: \(id)")
                    .textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textHero))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var catalogSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)], spacing: 12) {
            ForEach(specs) { spec in
                Button { startPreview(for: spec) } label: { specCard(spec) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func specCard(_ spec: DesignSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spec.title)
                .textStyle(.labelLg600)
                .foregroundStyle(theme.text(.textPrimary))
            if let summary = spec.summary {
                Text(summary)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .lineLimit(3)
            }
            HStack {
                Spacer()
                Text(store.activeDesignSpecID == spec.id ? "Active" : "Apply")
                    .textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textHero))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                .stroke(store.activeDesignSpecID == spec.id ? theme.border(.borderHero) : theme.border(.borderPrimary), lineWidth: 1)
        )
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
            VStack(alignment: .leading, spacing: 8) {
                Text("From a file").textStyle(.headingSm).foregroundStyle(.secondary)
                Text("Pick another app's design.md (or any .md / .txt) from Files.")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                OutlineButton("Choose design.md…") { showFileImporter = true }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("From a URL").textStyle(.headingSm).foregroundStyle(.secondary)
                HStack {
                    TextField("https://…/design.md", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PrimaryButton("Fetch") { startRemoteImport() }
                        .disabled(urlText.isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste markdown").textStyle(.headingSm).foregroundStyle(.secondary)
                TextEditor(text: $pasteText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border(.borderPrimary)))
                OutlineButton("Use pasted design") { startPasteImport() }
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            keySection
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI parsing (optional)").textStyle(.headingSm).foregroundStyle(.secondary)
            Text("Add an Anthropic API key to let Claude interpret free-form docs. Leave empty to parse on-device.")
                .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            SecureField("sk-ant-…", text: $anthropicKey)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    // MARK: Actions

    private func startPreview(for spec: DesignSpec) {
        loading = true
        Task { @MainActor in
            let resolver = DemoDesignResolver.make(apiKey: anthropicKey)
            let seed = store.activeConfig ?? ThemeConfig()
            let result = await DesignMode.resolve(spec, seed: seed, using: resolver)
            Theme.shared.apply(result.config)   // live preview; reverted on cancel
            loading = false
            preview = PreviewPayload(spec: spec, result: result)
        }
    }

    private func startRemoteImport() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "That doesn't look like a valid URL."
            return
        }
        loading = true
        Task { @MainActor in
            do {
                let spec = try await DesignSpecCatalog.load(remoteURL: url)
                await finishImport(spec)
            } catch {
                loading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startPasteImport() {
        let spec = DesignSpecCatalog.pasted(pasteText)
        loading = true
        Task { @MainActor in await finishImport(spec) }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let spec = try DesignSpecCatalog.load(fileURL: url)
                loading = true
                Task { @MainActor in await finishImport(spec) }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func finishImport(_ spec: DesignSpec) async {
        let resolver = DemoDesignResolver.make(apiKey: anthropicKey)
        let seed = store.activeConfig ?? ThemeConfig()
        let result = await DesignMode.resolve(spec, seed: seed, using: resolver)
        Theme.shared.apply(result.config)
        loading = false
        preview = PreviewPayload(spec: spec, result: result)
    }

    private var importableTypes: [UTType] {
        [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText, .text]
            .compactMap { $0 }
    }
}

/// A spec + its parsed result, carried into the confirm sheet.
struct PreviewPayload: Identifiable {
    let id = UUID()
    let spec: DesignSpec
    let result: DesignParseResult
}

private extension DesignSpec {
    /// Only bundled specs get a persisted id badge (file/remote/pasted are one-offs).
    var specIDForPersistence: String? {
        if case .bundled = source { return id }
        return nil
    }
}
