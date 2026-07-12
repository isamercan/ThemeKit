//
//  AnimatedImageLoaderTests.swift
//  ThemeKitTests
//
//  P1-3 — `AnimatedImage.load()` fetches bytes through an injectable
//  `AnimatedImageLoader` (`@Environment(\.animatedImageLoader)`) rather than a
//  hardcoded `URLSession.shared` call. Proves: (1) the default is the sanctioned
//  URLSession-backed loader, and (2) a hosted `AnimatedImage` actually calls an
//  injected stub instead of touching the network.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
final class AnimatedImageLoaderTests: XCTestCase {

    /// Thread-safe call recorder — the injected loader runs off the main actor
    /// inside `AnimatedImage`'s `.task(id:)`.
    private final class CallRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _urls: [URL] = []
        var urls: [URL] { lock.lock(); defer { lock.unlock() }; return _urls }
        func record(_ url: URL) { lock.lock(); _urls.append(url); lock.unlock() }
    }

    /// No network: returns canned bytes and records the requested URL.
    private struct StubLoader: AnimatedImageLoader {
        let recorder: CallRecorder
        let data: Data
        func data(from url: URL) async throws -> Data {
            recorder.record(url)
            return data
        }
    }

    /// A valid 1×1 transparent GIF, so the stubbed fetch also exercises the real
    /// ImageIO decode path (not just the loader call).
    private static let onePixelGIF = Data(
        base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
    )!

    /// Hosts a view offscreen and pumps the run loop so `.task`/`.onAppear` fire
    /// (mirrors `ControllableStateTests.host` / `GifGenerator.hostedCGImage`).
    @MainActor
    private func host(_ view: some View, for duration: TimeInterval = 0.4) {
        #if canImport(AppKit)
        let hostView = NSHostingView(rootView: view)
        hostView.frame = NSRect(x: 0, y: 0, width: 8, height: 8)
        let window = NSWindow(contentRect: hostView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hostView
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        window.orderOut(nil)
        #elseif canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        window.isHidden = true
        #endif
    }

    /// The default environment value is the sanctioned URLSession-backed loader —
    /// byte-identical default behavior, no opt-in required.
    func testDefaultLoaderIsURLSessionBacked() {
        XCTAssertTrue(EnvironmentValues().animatedImageLoader is URLSessionAnimatedImageLoader)
    }

    /// End-to-end: a hosted `AnimatedImage` with `.animatedImageLoader(_:)` set
    /// must call the injected loader — never `URLSession.shared` — for its URL.
    @MainActor
    func testInjectedLoaderIsUsedInsteadOfNetwork() {
        let recorder = CallRecorder()
        let url = URL(string: "https://example.invalid/stub.gif")!
        let stub = StubLoader(recorder: recorder, data: Self.onePixelGIF)

        host(AnimatedImage(url).animatedImageLoader(stub))

        XCTAssertEqual(
            recorder.urls, [url],
            "AnimatedImage.load() must call the injected loader (not URLSession) exactly once, with the view's URL."
        )
    }
}
