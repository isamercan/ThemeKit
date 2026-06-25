//
//  Upload.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A file-upload prompt plus a list of files with per-item status
//  (uploading / done / failed). State owned by the caller.
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

public struct Upload: View {
    private let prompt: String
    private let buttonTitle: String
    private let files: [UploadFile]
    private let onPick: () -> Void
    private let onRemove: (UploadFile) -> Void
    private let onRetry: ((UploadFile) -> Void)?

    public init(
        prompt: String = String(themeKit: "Add a photo from your device or take one with the camera."),
        buttonTitle: String = String(themeKit: "Upload Photo"),
        files: [UploadFile] = [],
        onPick: @escaping () -> Void = {},
        onRemove: @escaping (UploadFile) -> Void = { _ in },
        onRetry: ((UploadFile) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.buttonTitle = buttonTitle
        self.files = files
        self.onPick = onPick
        self.onRemove = onRemove
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text(prompt)
                .textStyle(.bodySm400)
                .foregroundStyle(Theme.shared.text(.textSecondary))
            PrimaryButton(buttonTitle, isContentWidth: true) { onPick() }

            if !files.isEmpty {
                VStack(spacing: 0) {
                    ForEach(files) { file in
                        row(for: file)
                        if file.id != files.last?.id { DividerView(size: .small) }
                    }
                }
            }
        }
    }

    private func row(for file: UploadFile) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                .fill(Theme.shared.background(.bgElevatorTertiary))
                .frame(width: 36, height: 36)
                .overlay(Icon(systemName: "photo", size: .sm, color: Theme.shared.foreground(.fgHero)))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .textStyle(.labelSm600)
                    .foregroundStyle(nameColor(for: file.status))
                status(for: file.status)
            }

            Spacer(minLength: 0)

            if let onRetry, case .failed = file.status {
                Button { onRetry(file) } label: {
                    Icon(systemName: "arrow.clockwise", size: .sm, color: Theme.shared.foreground(.fgHero))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Retry"))
            }

            Button { onRemove(file) } label: {
                Icon(systemName: "trash", size: .sm, color: Theme.shared.text(.textTertiary))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    @ViewBuilder
    private func status(for status: UploadStatus) -> some View {
        switch status {
        case .uploading(let progress):
            ProgressBar(value: progress, height: 4)
        case .done:
            Callout(String(themeKit: "Uploaded"), type: .success)
        case .failed(let reason):
            Callout(reason, type: .error)
        }
    }

    private func nameColor(for status: UploadStatus) -> Color {
        if case .failed = status { return Theme.shared.foreground(.systemcolorsFgError) }
        return Theme.shared.text(.textPrimary)
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
public final class UploadController: ObservableObject {

    @Published public private(set) var files: [UploadFile] = []
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
    @ObservedObject private var controller: UploadController
    private let prompt: String
    private let buttonTitle: String
    private let onPick: () -> Void

    public init(
        controller: UploadController,
        prompt: String = String(themeKit: "Add a photo from your device or take one with the camera."),
        buttonTitle: String = String(themeKit: "Upload Photo"),
        onPick: @escaping () -> Void = {}
    ) {
        self.controller = controller
        self.prompt = prompt
        self.buttonTitle = buttonTitle
        self.onPick = onPick
    }

    public var body: some View {
        Upload(
            prompt: prompt,
            buttonTitle: buttonTitle,
            files: controller.files,
            onPick: onPick,
            onRemove: { controller.remove($0.id) },
            onRetry: { file in Task { await controller.retry(file.id) } }
        )
    }
}

#Preview("Static") {
    Upload(files: [
        UploadFile(name: "room-1.jpg", status: .uploading(0.6)),
        UploadFile(name: "room-2.jpg", status: .done),
        UploadFile(name: "huge-file.jpg", status: .failed("Dosya çok büyük")),
    ], onRetry: { _ in })
    .padding()
}

#Preview("Controller") {
    struct Demo: View {
        @StateObject private var uploads = UploadController()
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
