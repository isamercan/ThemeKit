//
//  RemoteImage.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Async remote image on native `AsyncImage` (no Kingfisher dependency): URL +
//  aspect ratio (number or "16:9" string) + shimmer placeholder + failure state.
//  Covers the reference `ImageView`/`CustomImageView` role.
//

import SwiftUI

/// Named aspect-ratio constants (Reference ImageRatio parity).
public enum RemoteImageRatio {
    case square          // 1:1
    case productImage    // 5:7 portrait product
    case fourToFive      // 4:5
    case fiveToFour      // 5:4
    case sixteenToNine   // 16:9
    case custom(CGFloat)

    var value: CGFloat {
        switch self {
        case .square: return 1
        case .productImage: return 5.0 / 7.0
        case .fourToFive: return 4.0 / 5.0
        case .fiveToFour: return 5.0 / 4.0
        case .sixteenToNine: return 16.0 / 9.0
        case .custom(let r): return r
        }
    }
}

public struct RemoteImage: View {
    private let url: URL?
    private let aspectRatio: CGFloat?
    private let contentMode: ContentMode
    private let cornerRadius: CGFloat
    private let circle: Bool

    public init(_ url: URL?, aspectRatio: CGFloat? = nil, contentMode: ContentMode = .fill, cornerRadius: CGFloat = 0, circle: Bool = false) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.circle = circle
    }

    /// Aspect ratio from an API string like "16:9" / "5:7".
    public init(_ url: URL?, ratio: String, contentMode: ContentMode = .fill, cornerRadius: CGFloat = 0, circle: Bool = false) {
        let parts = ratio.split(separator: ":").compactMap { Double($0) }
        let r: CGFloat? = (parts.count == 2 && parts[1] != 0) ? CGFloat(parts[0] / parts[1]) : nil
        self.init(url, aspectRatio: r, contentMode: contentMode, cornerRadius: cornerRadius, circle: circle)
    }

    /// A named aspect-ratio constant (square / productImage / 4:5 / 5:4 / 16:9 / custom).
    public init(_ url: URL?, ratio: RemoteImageRatio, contentMode: ContentMode = .fill, cornerRadius: CGFloat = 0, circle: Bool = false) {
        self.init(url, aspectRatio: ratio.value, contentMode: contentMode, cornerRadius: cornerRadius, circle: circle)
    }

    private var clip: AnyShape {
        circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Animated formats are decoded frame-by-frame by `AnimatedImage` (ImageIO);
    /// static AVIF / WebP / HEIC / PNG / JPEG go through `AsyncImage` (iOS 16+
    /// `UIImage` decodes AVIF natively).
    private var isAnimated: Bool {
        guard let ext = url?.pathExtension.lowercased() else { return false }
        return ext == "gif" || ext == "apng"
    }

    public var body: some View {
        Group {
            if isAnimated {
                AnimatedImage(url, contentMode: contentMode)
            } else {
                AsyncImage(url: url, transaction: Transaction(animation: Motion.base.animation)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder(icon: "photo")
                    case .empty:
                        placeholder(icon: nil)
                    @unknown default:
                        placeholder(icon: nil)
                    }
                }
            }
        }
        .modifier(RatioModifier(ratio: aspectRatio, contentMode: contentMode))
        .clipped()
        .clipShape(clip)
    }

    @ViewBuilder
    private func placeholder(icon: String?) -> some View {
        ZStack {
            Theme.shared.background(.bgSecondaryLight)
            if let icon { Icon(systemName: icon, size: .lg, color: Theme.shared.text(.textTertiary)) }
        }
        .skeleton(icon == nil)
    }
}

private struct RatioModifier: ViewModifier {
    let ratio: CGFloat?
    let contentMode: ContentMode
    func body(content: Content) -> some View {
        if let ratio {
            content.aspectRatio(ratio, contentMode: contentMode == .fill ? .fill : .fit)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RemoteImage(URL(string: "https://picsum.photos/400/225"), ratio: "16:9", cornerRadius: 12)
            .frame(height: 160)
        RemoteImage(nil, aspectRatio: 1, cornerRadius: 12).frame(width: 80, height: 80)  // placeholder
    }
    .padding()
}
