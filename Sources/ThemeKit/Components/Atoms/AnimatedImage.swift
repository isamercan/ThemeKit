//
//  AnimatedImage.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import ImageIO

/// Animated GIF / APNG playback with NO third-party dependency — frames and
/// per-frame delays are decoded natively via ImageIO (`CGImageSource`) and driven
/// by a `TimelineView(.animation)`. Handles variable frame durations and loops.
/// (Reference AVIFAnimatedImage / animated `ImageView` role, native.)
public struct AnimatedImage: View {
    @Environment(\.theme) private var theme

    private let url: URL?
    // Appearance/config — mutated only through the modifiers below (R2).
    private var contentMode: ContentMode = .fill
    private var cornerRadius: CGFloat = 0

    @State private var frames: [CGImage] = []
    @State private var cumulative: [Double] = []   // cumulative end-time of each frame
    @State private var total: Double = 0
    @State private var start = Date()
    @State private var failed = false

    public init(_ url: URL?) {   // R1 — content only
        self.url = url
    }

    public var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if frames.count > 1, total > 0 {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: total)
                Image(decorative: frame(at: t), scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        } else if let first = frames.first {
            Image(decorative: first, scale: 1)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                theme.background(.bgSecondaryLight)
                if failed { Icon(systemName: "photo").size(.lg).color(theme.text(.textTertiary)) }
            }
            .skeleton(!failed)
        }
    }

    private func frame(at t: Double) -> CGImage {
        for (i, end) in cumulative.enumerated() where t < end { return frames[i] }
        return frames.last ?? frames[0]
    }

    private func load() async {
        guard let url else { failed = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                await MainActor.run { failed = true }; return
            }
            let count = CGImageSourceGetCount(source)
            var imgs: [CGImage] = []
            var cum: [Double] = []
            var acc = 0.0
            for i in 0..<count {
                guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                imgs.append(cg)
                acc += Self.frameDelay(source, i)
                cum.append(acc)
            }
            let snapshot = (imgs, cum, acc)
            await MainActor.run {
                frames = snapshot.0
                cumulative = snapshot.1
                total = snapshot.2
                start = Date()
                failed = imgs.isEmpty
            }
        } catch {
            await MainActor.run { failed = true }
        }
    }

    /// Per-frame delay from the GIF/APNG metadata (unclamped preferred), 0.1s floor.
    private static func frameDelay(_ source: CGImageSource, _ index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else { return 0.1 }
        if let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            if let d = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, d > 0 { return d }
            if let d = gif[kCGImagePropertyGIFDelayTime] as? Double, d > 0 { return d }
        }
        if let png = props[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            if let d = png[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, d > 0 { return d }
            if let d = png[kCGImagePropertyAPNGDelayTime] as? Double, d > 0 { return d }
        }
        return 0.1
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AnimatedImage {
    /// How the frames fill the available space (default .fill).
    func contentMode(_ mode: ContentMode) -> Self { copy { $0.contentMode = mode } }

    /// Clipping corner radius in points (default 0).
    func cornerRadius(_ r: CGFloat) -> Self { copy { $0.cornerRadius = r } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    AnimatedImage(URL(string: "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif"))
        .frame(width: 200, height: 200)
        .padding()
}
