//
//  VideoPlayerView.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import AVKit

/// Inline video on AVKit (reference `InlineVideoPlayerView`): autoplay, loop,
/// mute, aspect-fill, and active-gating (only the visible item plays). Optional
/// depth: a `progress` binding (0…1), resume-from-last-position, a tap overlay
/// that toggles play/pause, and a mute toggle button. Controls hidden by default.
/// iOS uses AVPlayerViewController; macOS falls back to the SwiftUI `VideoPlayer`.
public struct VideoPlayerView: View {
    @Environment(\.theme) private var theme

    private let url: URL?
    private let progress: Binding<Double>?
    private let externalMuted: Binding<Bool>?
    private let onTap: (() -> Void)?
    @Binding private var isActive: Bool
    // Playback flags — set via chainable modifiers (autoplay / loop / mute are on
    // by default, matching an inline auto-playing video).
    private var autoplay: Bool = true
    private var loop: Bool = true
    private var muted: Bool = true
    private var showMuteToggle: Bool = false
    private var tapToToggle: Bool = false

    public init(
        _ url: URL?,
        progress: Binding<Double>? = nil,
        isMuted: Binding<Bool>? = nil,
        onTap: (() -> Void)? = nil,
        isActive: Binding<Bool> = .constant(true)
    ) {
        self.url = url
        self.progress = progress
        self.externalMuted = isMuted
        self.onTap = onTap
        self._isActive = isActive
    }

    public var body: some View {
        Group {
            if let url {
                player(url)
            } else {
                ZStack {
                    theme.background(.bgTertiary)
                    Icon(systemName: "play.rectangle").size(.xl).color(theme.foreground(.fgSecondary))
                }
            }
        }
        .clipped()
    }

    private func player(_ url: URL) -> some View {
        InlineVideo(url: url, autoplay: autoplay, loop: loop, muted: muted,
                    showMuteToggle: showMuteToggle, tapToToggle: tapToToggle,
                    progress: progress, externalMuted: externalMuted, onTap: onTap,
                    isActive: $isActive)
    }
}

public extension VideoPlayerView {
    /// Whether the video starts playing on appear (default true).
    func autoplay(_ on: Bool = true) -> Self { copy { $0.autoplay = on } }
    /// Whether playback loops back to the start (default true).
    func loop(_ on: Bool = true) -> Self { copy { $0.loop = on } }
    /// Whether the audio starts muted (default true — required for iOS inline autoplay).
    func muted(_ on: Bool = true) -> Self { copy { $0.muted = on } }
    /// Shows a mute/unmute toggle button overlay.
    func muteToggle(_ on: Bool = true) -> Self { copy { $0.showMuteToggle = on } }
    /// Whether tapping the video toggles play/pause.
    func tapToToggle(_ on: Bool = true) -> Self { copy { $0.tapToToggle = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Stateful inline player that owns its `AVPlayer`, draws the overlays and
/// drives the optional `progress` binding via a periodic time observer.
/// Cross-platform — only the AVKit host view below is platform-conditional.
private struct InlineVideo: View {
    let url: URL
    let autoplay: Bool
    let loop: Bool
    let muted: Bool
    let showMuteToggle: Bool
    let tapToToggle: Bool
    let progress: Binding<Double>?
    let externalMuted: Binding<Bool>?
    let onTap: (() -> Void)?
    @Binding var isActive: Bool

    @State private var player: AVPlayer
    @State private var isPlaying = false
    @State private var isMuted: Bool
    @State private var lastTime: CMTime = .zero
    @State private var timeObserver: Any?
    @State private var loopObserver: NSObjectProtocol?

    init(url: URL, autoplay: Bool, loop: Bool, muted: Bool, showMuteToggle: Bool,
         tapToToggle: Bool, progress: Binding<Double>?, externalMuted: Binding<Bool>?,
         onTap: (() -> Void)?, isActive: Binding<Bool>) {
        self.url = url; self.autoplay = autoplay; self.loop = loop; self.muted = muted
        self.showMuteToggle = showMuteToggle; self.tapToToggle = tapToToggle
        self.progress = progress; self.externalMuted = externalMuted; self.onTap = onTap
        self._isActive = isActive
        let p = AVPlayer(url: url)
        p.isMuted = externalMuted?.wrappedValue ?? muted
        _player = State(wrappedValue: p)
        _isMuted = State(wrappedValue: externalMuted?.wrappedValue ?? muted)
    }

    var body: some View {
        ZStack {
            SimpleVideoPlayer(player: player)
                .onAppear {
                    addLoopObserver()
                    if let progress { addProgressObserver(progress) }
                    if autoplay, isActive { start(from: .zero) }
                }
                .onDisappear { pause(storeTime: true); removeObservers() }
                .onChange(of: isActive) { _, active in
                    if active {
                        if let progress { addProgressObserver(progress) }
                        if autoplay { start(from: lastTime) }
                    } else {
                        pause(storeTime: true)
                    }
                }
                .onChange(of: externalMuted?.wrappedValue ?? isMuted) { _, value in
                    isMuted = value; player.isMuted = value
                }

            if tapToToggle {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let onTap { onTap() } else { toggle() }
                    }
                if !isPlaying {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 6)
                        .allowsHitTesting(false)
                }
            } else if let onTap {
                Color.clear.contentShape(Rectangle()).onTapGesture { onTap() }
            }

            if showMuteToggle {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isMuted.toggle(); player.isMuted = isMuted
                            externalMuted?.wrappedValue = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(Theme.SpacingKey.md.value)
                    }
                }
            }
        }
    }

    private func start(from time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.play(); isPlaying = true
        }
    }

    private func pause(storeTime: Bool) {
        if storeTime { lastTime = player.currentTime() }
        player.pause(); isPlaying = false
    }

    private func toggle() {
        if isPlaying { pause(storeTime: true) } else { start(from: lastTime) }
    }

    private func addLoopObserver() {
        guard loopObserver == nil else { return }
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { _ in
            if loop, isActive {
                lastTime = .zero; progress?.wrappedValue = 0
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    player.play(); isPlaying = true
                }
            } else {
                isPlaying = false; lastTime = .zero; progress?.wrappedValue = 1
            }
        }
    }

    private func addProgressObserver(_ progress: Binding<Double>) {
        removeProgressObserver()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak player] _ in
            guard let player else { return }
            let current = player.currentTime().seconds
            let duration = player.currentItem?.duration.seconds ?? 0
            guard duration > 0, duration.isFinite else { progress.wrappedValue = 0; return }
            progress.wrappedValue = min(max(current / duration, 0), 1)
        }
    }

    private func removeProgressObserver() {
        if let token = timeObserver { player.removeTimeObserver(token); timeObserver = nil }
    }

    private func removeObservers() {
        removeProgressObserver()
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver); self.loopObserver = nil }
    }
}

#if os(iOS)
private struct SimpleVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
#elseif os(macOS)
private struct SimpleVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}
}
#endif
