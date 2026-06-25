//
//  LottieIllustration.swift
//  ThemeKitLottie
//  Created by İsa Mercan on 23.06.2026.
//
//  A thin SwiftUI wrapper over Lottie's `LottieView` for vector (After Effects /
//  JSON / dotLottie) animations. Lives in the OPTIONAL `ThemeKitLottie`
//  product so the core `ThemeKit` library stays zero-dependency —
//  import this module only when you actually need Lottie. For raster animations
//  (GIF / APNG) use the core's native `AnimatedImage` instead (no dependency).
//
//  Sources: bundled JSON (`init(_:bundle:)`), bundled dotLottie
//  (`init(dotLottieNamed:bundle:)`), remote JSON (`init(url:)`) and remote
//  dotLottie (`init(dotLottieURL:)`).
//

import SwiftUI
import Lottie

public struct LottieIllustration: View {
    private enum Source {
        case named(String, Bundle)
        case dotLottieNamed(String, Bundle)
        case url(URL)
        case dotLottieURL(URL)
    }

    private let source: Source
    private let loop: Bool

    /// A bundled `<name>.json` Lottie animation.
    public init(_ name: String, bundle: Bundle = .main, loop: Bool = true) {
        self.source = .named(name, bundle)
        self.loop = loop
    }

    /// A bundled `<name>.lottie` (dotLottie) animation.
    public init(dotLottieNamed name: String, bundle: Bundle = .main, loop: Bool = true) {
        self.source = .dotLottieNamed(name, bundle)
        self.loop = loop
    }

    /// A remote JSON Lottie animation loaded from `url`.
    public init(url: URL, loop: Bool = true) {
        self.source = .url(url)
        self.loop = loop
    }

    /// A remote `.lottie` (dotLottie) animation loaded from `url`.
    public init(dotLottieURL url: URL, loop: Bool = true) {
        self.source = .dotLottieURL(url)
        self.loop = loop
    }

    @ViewBuilder
    public var body: some View {
        switch source {
        case .named(let name, let bundle):
            play(LottieView(animation: .named(name, bundle: bundle)).resizable())
        case .dotLottieNamed(let name, let bundle):
            play(LottieView { () async throws -> DotLottieFile? in
                try await DotLottieFile.named(name, bundle: bundle)
            }.resizable())
        case .url(let url):
            play(LottieView { () async throws -> LottieAnimation? in
                await LottieAnimation.loadedFrom(url: url)
            }.resizable())
        case .dotLottieURL(let url):
            play(LottieView { () async throws -> DotLottieFile? in
                try await DotLottieFile.loadedFrom(url: url)
            }.resizable())
        }
    }

    @ViewBuilder
    private func play<Placeholder: View>(_ view: LottieView<Placeholder>) -> some View {
        if loop {
            view.looping()
        } else {
            view.playing()
        }
    }
}
