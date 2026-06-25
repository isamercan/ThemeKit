//
//  ImageCollage.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  A gallery collage of remote images with count-aware layouts (1 / 2 / 3 / 4+)
//  and a "+N" overlay on the last visible tile. Brand-neutral, token-bound; uses
//  `RemoteImage` (native AsyncImage), no asset/Kingfisher dependency.
//

import SwiftUI

public struct ImageCollage: View {
    private let urls: [URL]
    private let height: CGFloat
    private let spacing: CGFloat
    private let cornerRadius: CGFloat
    private let onTap: ((Int) -> Void)?

    public init(
        _ urls: [URL],
        height: CGFloat = 220,
        spacing: CGFloat = 4,
        cornerRadius: CGFloat = 12,
        onTap: ((Int) -> Void)? = nil
    ) {
        self.urls = urls
        self.height = height
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            switch urls.count {
            case 0:
                placeholder
            case 1:
                tile(0)
            case 2:
                HStack(spacing: spacing) { tile(0); tile(1) }
            case 3:
                HStack(spacing: spacing) {
                    tile(0)
                    VStack(spacing: spacing) { tile(1); tile(2) }
                }
            default:
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) { tile(0); tile(1) }
                    HStack(spacing: spacing) { tile(2); tile(3, overlayExtra: urls.count - 4) }
                }
            }
        }
        .frame(height: height)
    }

    private func tile(_ index: Int, overlayExtra: Int = 0) -> some View {
        ZStack {
            RemoteImage(urls[index], contentMode: .fill, cornerRadius: cornerRadius)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if overlayExtra > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                Text("+\(overlayExtra)")
                    .textStyle(.headingBase)
                    .foregroundStyle(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?(index) }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.shared.background(.bgSecondaryLight))
            .overlay(Icon(systemName: "photo.on.rectangle", size: .lg, color: Theme.shared.text(.textTertiary)))
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    let urls = (1...6).compactMap { URL(string: "https://picsum.photos/seed/collage\($0)/400/300") }
    return VStack(spacing: 16) {
        ImageCollage(Array(urls.prefix(3)), height: 180)
        ImageCollage(urls, height: 220)
    }
    .padding()
}
