//
//  TextRotate.swift
//  ThemeKit
//

import SwiftUI

/// Atom. Cross-fades through a list of words on a timer — a looping headline accent.
/// Honors Reduce Motion (holds the first word) and the micro-animations switch.
/// (daisyUI "Text Rotate".)
public struct TextRotate: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.microAnimations) private var micro

    private let words: [String]

    // Appearance — mutated only through the modifiers below (R2).
    private var interval: Double
    private var style: TextStyle = .headingSm
    private var accent: SemanticColor?

    @State private var index = 0

    public init(_ words: [String], interval: Double = 2) {
        self.words = words
        self.interval = interval
    }

    private var current: String { words.isEmpty ? "" : words[index % words.count] }

    public var body: some View {
        Text(current)
            .textStyle(style)
            .foregroundStyle(accent.map { $0.accent } ?? theme.text(.textHero))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: index)
            .onReceive(Timer.publish(every: interval, on: .main, in: .common).autoconnect()) { _ in
                guard micro, !reduceMotion, words.count > 1 else { return }
                index += 1
            }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TextRotate {
    /// Design-system type ramp for the rotating word (default `.headingSm`).
    func textStyle(_ s: TextStyle) -> Self { copy { $0.style = s } }
    /// Token-fed tint for the rotating word; `nil` keeps the hero text token.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Seconds between words (clamped to ≥ 0.1) — the chainable twin of the
    /// init's `interval:` parameter.
    func interval(_ seconds: Double) -> Self { copy { $0.interval = max(0.1, seconds) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 4) {
            Text("Build").textStyle(.headingSm)
            TextRotate(["faster.", "themed.", "accessible.", "everywhere."])
        }
        HStack(spacing: 4) {
            Text("Fly").textStyle(.labelMd700)
            TextRotate(["cheaper.", "direct.", "greener."])
                .textStyle(.labelMd700)
                .accent(.turquoise)
                .interval(1.5)
        }
    }
    .padding()
}
