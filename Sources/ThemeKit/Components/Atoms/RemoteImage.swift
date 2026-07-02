//
//  RemoteImage.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
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

/// Async remote image on native `AsyncImage` (no Kingfisher dependency): URL +
/// aspect ratio (number or "16:9" string) + shimmer placeholder + failure state.
/// Covers the reference `ImageView`/`CustomImageView` role.
public struct RemoteImage: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var aspectRatio: CGFloat?
    private var contentMode: ContentMode = .fill
    private var cornerRadius: CGFloat = 0
    private var circle: Bool = false

    private let url: URL?

    public init(_ url: URL?) {   // R1
        self.url = url
    }

    /// Aspect ratio from an API string like "16:9" / "5:7" (genuine data overload).
    public init(_ url: URL?, ratio: String) {
        self.init(url)
        let parts = ratio.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2, parts[1] != 0 { self.aspectRatio = CGFloat(parts[0] / parts[1]) }
    }

    /// A named aspect-ratio constant (square / productImage / 4:5 / 5:4 / 16:9 / custom).
    public init(_ url: URL?, ratio: RemoteImageRatio) {
        self.init(url)
        self.aspectRatio = ratio.value
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
                AnimatedImage(url).contentMode(contentMode)
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
            theme.background(.bgSecondaryLight)
            if let icon { Icon(systemName: icon).size(.lg).color(theme.text(.textTertiary)) }
        }
        .skeleton(icon == nil)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RemoteImage {
    /// Numeric aspect ratio (width / height). Renamed from `aspectRatio:` to avoid
    /// clashing with SwiftUI's native `.aspectRatio(_:contentMode:)`. The String /
    /// `RemoteImageRatio` init overloads remain the data-driven entry points.
    func ratio(_ r: CGFloat?) -> Self { copy { $0.aspectRatio = r } }

    /// How the image fills its ratio box: fill (default) or fit.
    func contentMode(_ m: ContentMode) -> Self { copy { $0.contentMode = m } }

    /// Corner radius of the clip shape (ignored when `.circle()`).
    func cornerRadius(_ r: CGFloat) -> Self { copy { $0.cornerRadius = r } }

    /// Clip to a circle instead of a rounded rectangle.
    func circle(_ on: Bool = true) -> Self { copy { $0.circle = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
        RemoteImage(URL(string: "https://picsum.photos/400/225"), ratio: "16:9").cornerRadius(12)
            .frame(height: 160)
        RemoteImage(nil).ratio(1).cornerRadius(12).frame(width: 80, height: 80)  // placeholder
    }
    .padding()
}
