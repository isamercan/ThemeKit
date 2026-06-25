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

    public init(
        prompt: String = String(themeKit: "Add a photo from your device or take one with the camera."),
        buttonTitle: String = String(themeKit: "Upload Photo"),
        files: [UploadFile] = [],
        onPick: @escaping () -> Void = {},
        onRemove: @escaping (UploadFile) -> Void = { _ in }
    ) {
        self.prompt = prompt
        self.buttonTitle = buttonTitle
        self.files = files
        self.onPick = onPick
        self.onRemove = onRemove
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

#Preview {
    Upload(files: [
        UploadFile(name: "room-1.jpg", status: .uploading(0.6)),
        UploadFile(name: "room-2.jpg", status: .done),
        UploadFile(name: "huge-file.jpg", status: .failed("Dosya çok büyük")),
    ])
    .padding()
}
