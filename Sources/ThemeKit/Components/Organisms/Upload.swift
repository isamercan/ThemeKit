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
    private var buttonTitle: String = String(themeKit: "Upload Photo")
    private var maxCount: Int? = nil

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
            PrimaryButton(buttonTitle) { onPick() }.disabled(atLimit)
            if let maxCount {
                Text("\(files.count)/\(maxCount)")
                    .textStyle(.overline400)
                    .foregroundStyle(theme.text(.textTertiary))
            }

            if !files.isEmpty {
                VStack(spacing: 0) {
                    ForEach(files) { file in
                        row(for: file)
                        if file.id != files.last?.id { DividerView().size(.small) }
                    }
                }
            }
        }
    }

    private func row(for file: UploadFile) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                .fill(theme.background(.bgElevatorTertiary))
                .frame(width: 36, height: 36)
                .overlay(Icon(systemName: "photo", size: .sm, color: theme.foreground(.fgHero)))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .textStyle(.labelSm600)
                    .foregroundStyle(nameColor(for: file.status))
                status(for: file.status)
            }

            Spacer(minLength: 0)

            if let onRetry, case .failed = file.status {
                Button { onRetry(file) } label: {
                    Icon(systemName: "arrow.clockwise", size: .sm, color: theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Retry"))
            }

            Button { onRemove(file) } label: {
                Icon(systemName: "trash", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
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
    func buttonTitle(_ title: String) -> Self { copy { $0.buttonTitle = title } }

    /// Cap the number of files; once reached the picker is disabled and a count
    /// is shown. `nil` (default) means no limit.
    func maxCount(_ count: Int?) -> Self { copy { $0.maxCount = count } }

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
    private var prompt: String = String(themeKit: "Add a photo from your device or take one with the camera.")
    private var buttonTitle: String = String(themeKit: "Upload Photo")

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
    func prompt(_ text: String) -> Self { copy { $0.prompt = text } }

    /// Title of the file-picker button.
    func buttonTitle(_ text: String) -> Self { copy { $0.buttonTitle = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview("Static") {
    Upload(files: [
        UploadFile(name: "room-1.jpg", status: .uploading(0.6)),
        UploadFile(name: "room-2.jpg", status: .done),
        UploadFile(name: "huge-file.jpg", status: .failed("File too large")),
    ], onRetry: { _ in })
    .padding()
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
