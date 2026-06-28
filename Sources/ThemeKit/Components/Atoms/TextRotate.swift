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
    private let interval: Double

    @State private var index = 0

    public init(_ words: [String], interval: Double = 2) {
        self.words = words
        self.interval = interval
    }

    private var current: String { words.isEmpty ? "" : words[index % words.count] }

    public var body: some View {
        Text(current)
            .textStyle(.headingSm)
            .foregroundStyle(theme.text(.textHero))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: index)
            .onReceive(Timer.publish(every: interval, on: .main, in: .common).autoconnect()) { _ in
                guard micro, !reduceMotion, words.count > 1 else { return }
                index += 1
            }
    }
}

#Preview {
    HStack(spacing: 4) {
        Text("Build").textStyle(.headingSm)
        TextRotate(["faster.", "themed.", "accessible.", "everywhere."])
    }
    .padding()
}
