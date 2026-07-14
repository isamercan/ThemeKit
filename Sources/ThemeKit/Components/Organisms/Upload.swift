//
//  Upload.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum UploadStatus: Equatable {
    case uploading(Double)
    case done
    case failed(String)
}

public struct UploadFile: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let status: UploadStatus
    public init(id: UUID = UUID(), name: String, status: UploadStatus) {
        self.id = id
        self.name = name
        self.status = status
    }
}

/// How ``Upload`` presents its files (Ant `listType`).
public enum UploadListType: Sendable {
    /// A vertical list of rows (thumbnail + name + status). The default.
    case list
    /// A grid of square thumbnail cards with an in-grid "add" tile.
    case pictureCard
}

/// Organism. A file-upload prompt plus a list of files with per-item status
/// (uploading / done / failed). State owned by the caller.
public struct Upload: View {
    @Environment(\.theme) private var theme

    private let prompt: String
    private let files: [UploadFile]
    private let onPick: () -> Void
    private let onRemove: (UploadFile) -> Void
    private let onRetry: ((UploadFile) -> Void)?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var buttonTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var buttonTitle: String { buttonTitleOverride ?? String(themeKit: "Upload Photo") }
    private var maxCount: Int? = nil
    /// Tapping a file's thumbnail fires this (Ant `onPreview`); `nil` = inert thumbnail.
    private var onPreview: ((UploadFile) -> Void)?
    /// Shows a per-file download icon on completed files and fires this (Ant
    /// `onDownload` / `showDownloadIcon`); `nil` = no download affordance.
    private var onDownload: ((UploadFile) -> Void)?
    /// Show the per-file remove (trash) icon (Ant `showRemoveIcon`; default on).
    private var showsRemoveIcon = true
    /// Render the file list at all (Ant `showUploadList`; default on) — off keeps
    /// the picker but hides the rows (the caller shows files elsewhere).
    private var showsList = true
    /// List presentation (Ant `listType`): `.list` rows (default) or a
    /// `.pictureCard` grid of thumbnails with an in-grid add tile.
    private var listType: UploadListType = .list

    public init(
        prompt: String = String(themeKit: "Add a photo from your device or take one with the camera."),
        files: [UploadFile] = [],
        onPick: @escaping () -> Void = {},
        onRemove: @escaping (UploadFile) -> Void = { _ in },
        onRetry: ((UploadFile) -> Void)? = nil
    ) {   // R1
        self.prompt = prompt
        self.files = files
        self.onPick = onPick
        self.onRemove = onRemove
        self.onRetry = onRetry
    }

    /// True once the file count reaches `maxCount` (if set) — the picker is then disabled.
    private var atLimit: Bool { maxCount.map { files.count >= $0 } ?? false }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text(prompt)
                .textStyle(.bodySm400)
                .foregroundStyle(theme.text(.textSecondary))

            switch listType {
            case .list:
                PrimaryButton(buttonTitle) { onPick() }.disabled(atLimit)
                if let maxCount {
                    Text("\(files.count)/\(maxCount)")
                        .textStyle(.overline400)
                        .foregroundStyle(theme.text(.textTertiary))
                }
                if showsList && !files.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(files) { file in
                            row(for: file)
                            if file.id != files.last?.id { DividerView().size(.small) }
                        }
                    }
                }
            case .pictureCard:
                // The add tile IS the picker in card mode; the button is dropped.
                pictureCardGrid
            }
        }
    }

    // MARK: - Picture-card grid (Ant `listType="picture-card"`)

    private var cardSide: CGFloat { 88 }

    private var pictureCardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cardSide), spacing: Theme.SpacingKey.sm.value)],
                  spacing: Theme.SpacingKey.sm.value) {
            if showsList {
                ForEach(files) { file in pictureCardCell(for: file) }
            }
            if !atLimit { addTile }
        }
    }

    private var addTile: some View {
        Button { onPick() } label: {
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: cardSide, height: cardSide)
                .overlay {
                    VStack(spacing: Theme.SpacingKey.xs.value) {
                        Icon(systemName: "plus").size(.md).color(theme.text(.textTertiary))
                        Text(buttonTitle).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                            .lineLimit(1)
                    }
                    .padding(Theme.SpacingKey.xs.value)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(buttonTitle)
    }

    private func pictureCardCell(for file: UploadFile) -> some View {
        // The preview tap covers the tile *background* only; the remove / retry /
        // download controls are overlaid ABOVE it (not nested inside the preview
        // button), so their taps reach the intended action.
        previewBase(for: file)
            .overlay(alignment: .topTrailing) {
                if showsRemoveIcon {
                    cardControl("xmark.circle.fill", label: String(themeKit: "Remove \(file.name)")) { onRemove(file) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Only for completed files with a download handler (parity with list mode).
                if onDownload != nil, case .done = file.status {
                    cardControl("arrow.down.circle.fill", label: String(themeKit: "Download \(file.name)")) { onDownload?(file) }
                }
            }
            .overlay(alignment: .bottom) {
                // Retry only when a handler exists (no dead control), like list mode.
                if onRetry != nil, case .failed = file.status {
                    cardControl("arrow.clockwise", label: String(themeKit: "Retry"), error: true) { onRetry?(file) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(cardBorder(for: file.status), lineWidth: 1))
    }

    /// The preview-tappable tile: photo glyph + upload progress, and nothing
    /// interactive nested inside (the action controls are separate overlays).
    @ViewBuilder
    private func previewBase(for file: UploadFile) -> some View {
        let tile = RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
            .fill(theme.background(.bgElevatorTertiary))
            .frame(width: cardSide, height: cardSide)
            .overlay {
                VStack(spacing: Theme.SpacingKey.xs.value) {
                    Icon(systemName: "photo").size(.md).color(theme.foreground(.fgHero))
                    if case .uploading(let progress) = file.status {
                        ProgressBar(value: progress).barHeight(3).frame(width: cardSide - 24)
                    }
                }
                .padding(.horizontal, Theme.SpacingKey.xs.value)
            }
        if let onPreview {
            Button { onPreview(file) } label: { tile.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Preview \(file.name)"))
        } else {
            tile
        }
    }

    /// A small overlaid card action button (remove / download / retry).
    private func cardControl(_ systemImage: String, label: String, error: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemImage).size(.sm)
                .color(error ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cardBorder(for status: UploadStatus) -> Color {
        if case .failed = status { return theme.border(.systemcolorsBorderError) }
        return theme.border(.borderPrimary)
    }

    private func row(for file: UploadFile) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            thumbnail(for: file)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .textStyle(.labelSm600)
                    .foregroundStyle(nameColor(for: file.status))
                status(for: file.status)
            }

            Spacer(minLength: 0)

            if let onRetry, case .failed = file.status {
                Button { onRetry(file) } label: {
                    Icon(systemName: "arrow.clockwise").size(.sm).color(theme.foreground(.fgHero))
                        .frame(minWidth: 44, minHeight: 44)   // >=44pt hit area (WCAG 2.5.5); glyph stays .sm
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Retry"))
            }

            // Download affordance on completed files (Ant `showDownloadIcon` / `onDownload`).
            if let onDownload, case .done = file.status {
                Button { onDownload(file) } label: {
                    Icon(systemName: "arrow.down.circle").size(.sm).color(theme.text(.textTertiary))
                        .frame(minWidth: 44, minHeight: 44)   // >=44pt hit area (WCAG 2.5.5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Download \(file.name)"))
            }

            if showsRemoveIcon {
                Button { onRemove(file) } label: {
                    Icon(systemName: "trash").size(.sm).color(theme.text(.textTertiary))
                        .frame(minWidth: 44, minHeight: 44)   // >=44pt hit area (WCAG 2.5.5); glyph stays .sm
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Remove \(file.name)"))
            }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    /// The file's thumbnail placeholder — a tappable preview button when
    /// `onPreview` is set (Ant `onPreview`), otherwise a decorative tile.
    @ViewBuilder
    private func thumbnail(for file: UploadFile) -> some View {
        let tile = RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
            .fill(theme.background(.bgElevatorTertiary))
            .frame(width: 36, height: 36)
            .overlay(Icon(systemName: "photo").size(.sm).color(theme.foreground(.fgHero)))
        if let onPreview {
            Button { onPreview(file) } label: {
                // >=44pt hit area (WCAG 2.5.5) while the visual thumbnail stays 36pt.
                tile.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Preview \(file.name)"))
        } else {
            tile.accessibilityHidden(true)   // decorative thumbnail placeholder
        }
    }

    @ViewBuilder
    private func status(for status: UploadStatus) -> some View {
        switch status {
        case .uploading(let progress):
            ProgressBar(value: progress).barHeight(4)
        case .done:
            Callout(String(themeKit: "Uploaded")).variant(.success)
        case .failed(let reason):
            Callout(reason).variant(.error)
        }
    }

    private func nameColor(for status: UploadStatus) -> Color {
        if case .failed = status { return theme.foreground(.systemcolorsFgError) }
        return theme.text(.textPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Upload {
    /// Title of the file-picker button.
    func buttonTitle(_ title: String) -> Self { copy { $0.buttonTitleOverride = title } }

    /// Cap the number of files; once reached the picker is disabled and a count
    /// is shown. `nil` (default) means no limit.
    func maxCount(_ count: Int?) -> Self { copy { $0.maxCount = count } }

    /// Make each file's thumbnail a tappable preview (Ant `onPreview`) — e.g. to
    /// open a full-size viewer. Omit for an inert thumbnail.
    func onPreview(_ handler: ((UploadFile) -> Void)?) -> Self { copy { $0.onPreview = handler } }

    /// Show a download icon on completed files and fire this when tapped
    /// (Ant `onDownload` / `showDownloadIcon`). Omit for no download affordance.
    func onDownload(_ handler: ((UploadFile) -> Void)?) -> Self { copy { $0.onDownload = handler } }

    /// Show the per-file remove (trash) icon (Ant `showRemoveIcon`; default on).
    func showsRemoveIcon(_ on: Bool = true) -> Self { copy { $0.showsRemoveIcon = on } }

    /// Render the file list (Ant `showUploadList`; default on). Off keeps the
    /// picker but hides the rows — for when the caller lists files elsewhere.
    func showsList(_ on: Bool = true) -> Self { copy { $0.showsList = on } }

    /// Presentation of the file list (Ant `listType`): `.list` rows (default) or
    /// a `.pictureCard` thumbnail grid whose trailing add tile is the picker.
    func listType(_ type: UploadListType) -> Self { copy { $0.listType = type } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Async controller

/// Reports upload progress in `0...1`. Marshal to the main actor by the caller
/// (`await progress(p)` from a background task).
public typealias UploadProgress = @MainActor (Double) -> Void

/// The async work that uploads one file, periodically reporting progress.
public typealias UploadOperation = (@escaping UploadProgress) async throws -> Void

/// Drives the upload lifecycle for a list of files: each `upload(...)` adds a file
/// in `.uploading(0)`, runs the async operation (reporting progress), then settles
/// to `.done` or `.failed`. Mirrors the toast `toastTask` pattern. Bind it to the
/// UI with `UploadList(controller:)`.
@MainActor
@Observable
public final class UploadController {

    public private(set) var files: [UploadFile] = []
    private var operations: [UUID: UploadOperation] = [:]

    public init() {}

    /// Add a file and run its upload to completion (`.done` / `.failed`).
    @discardableResult
    public func upload(name: String, _ operation: @escaping UploadOperation) async -> UUID {
        let id = UUID()
        files.append(UploadFile(id: id, name: name, status: .uploading(0)))
        operations[id] = operation
        await run(id)
        return id
    }

    /// Re-run a previously-added file's upload (e.g. after a failure).
    public func retry(_ id: UUID) async {
        guard operations[id] != nil else { return }
        setStatus(id, .uploading(0))
        await run(id)
    }

    public func remove(_ id: UUID) {
        files.removeAll { $0.id == id }
        operations[id] = nil
    }

    private func run(_ id: UUID) async {
        guard let operation = operations[id] else { return }
        do {
            try await operation { [weak self] progress in
                self?.setStatus(id, .uploading(min(max(progress, 0), 1)))
            }
            setStatus(id, .done)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? String(themeKit: "Upload failed")
            setStatus(id, .failed(reason))
        }
    }

    private func setStatus(_ id: UUID, _ status: UploadStatus) {
        guard let i = files.firstIndex(where: { $0.id == id }) else { return }
        files[i] = UploadFile(id: id, name: files[i].name, status: status)
    }
}

/// `Upload` wired to an `UploadController` — renders its files with remove + retry.
public struct UploadList: View {
    private var controller: UploadController
    private let onPick: () -> Void

    // Appearance/config — mutated only through the modifiers below (R2).
    private var promptOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var prompt: String { promptOverride ?? String(themeKit: "Add a photo from your device or take one with the camera.") }
    private var buttonTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var buttonTitle: String { buttonTitleOverride ?? String(themeKit: "Upload Photo") }

    public init(controller: UploadController, onPick: @escaping () -> Void = {}) {   // R1
        self.controller = controller
        self.onPick = onPick
    }

    public var body: some View {
        Upload(
            prompt: prompt,
            files: controller.files,
            onPick: onPick,
            onRemove: { controller.remove($0.id) },
            onRetry: { file in Task { await controller.retry(file.id) } }
        )
        .buttonTitle(buttonTitle)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension UploadList {
    /// Prompt text shown above the picker button.
    func prompt(_ text: String) -> Self { copy { $0.promptOverride = text } }

    /// Title of the file-picker button.
    func buttonTitle(_ text: String) -> Self { copy { $0.buttonTitleOverride = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview("Static") {
    PreviewMatrix("Upload") {
        PreviewCase("Statuses · uploading / done / failed + retry") {
            Upload(files: [
                UploadFile(name: "room-1.jpg", status: .uploading(0.6)),
                UploadFile(name: "room-2.jpg", status: .done),
                UploadFile(name: "huge-file.jpg", status: .failed("File too large")),
            ], onRetry: { _ in })
        }
        PreviewCase("Empty · prompt + picker") {
            Upload()
        }
        PreviewCase("At limit · picker disabled + count") {
            Upload(files: [
                UploadFile(name: "room-1.jpg", status: .done),
                UploadFile(name: "room-2.jpg", status: .done),
            ]).maxCount(2)
        }
        // Picture-card grid (Ant listType="picture-card") — thumbnails + add tile.
        PreviewCase("Picture-card grid") {
            Upload(files: [
                UploadFile(name: "room-1.jpg", status: .done),
                UploadFile(name: "room-2.jpg", status: .uploading(0.6)),
                UploadFile(name: "room-3.jpg", status: .failed("Too large")),
            ], onRetry: { _ in })
            .listType(.pictureCard)
            .maxCount(6)
        }
        // Preview + download affordances (Ant onPreview / onDownload); remove hidden.
        PreviewCase("Preview + download · remove hidden") {
            Upload(files: [
                UploadFile(name: "room-1.jpg", status: .done),
                UploadFile(name: "room-2.jpg", status: .done),
            ])
            .onPreview { _ in }
            .onDownload { _ in }
            .showsRemoveIcon(false)
        }
    }
}

#Preview("Controller") {
    struct Demo: View {
        @State private var uploads = UploadController()
        var body: some View {
            UploadList(controller: uploads) {
                Task {
                    await uploads.upload(name: "photo.jpg") { progress in
                        for step in 1 ... 5 {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            progress(Double(step) / 5)
                        }
                    }
                }
            }
            .padding()
        }
    }
    return Demo()
}
