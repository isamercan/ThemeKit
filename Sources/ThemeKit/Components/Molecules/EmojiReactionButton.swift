//
//  EmojiReactionButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A reaction toggle: an emoji plus a live count in a capsule that tints when
//  active. (HeroUI Pro "Emoji Reaction Button".) Controlled or uncontrolled via
//  `ControllableState`; a spring pop + haptic on react, both suppressed under
//  Reduce Motion.
//

import SwiftUI

/// Molecule. `EmojiReactionButton("👍", count: 12)`.
///
///     EmojiReactionButton("🎉", count: 4, isReacted: $reacted)
public struct EmojiReactionButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let emoji: String
    /// Base count of *other* reactions; the current user's reaction adds one.
    private let count: Int

    @ControllableState private var reacted: Bool
    @State private var pop = false

    public init(_ emoji: String, count: Int, initiallyReacted: Bool = false) {   // R1 — uncontrolled
        self.emoji = emoji
        self.count = count
        self._reacted = ControllableState(wrappedValue: initiallyReacted)
    }

    public init(_ emoji: String, count: Int, isReacted: Binding<Bool>) {   // R1 — controlled
        self.emoji = emoji
        self.count = count
        self._reacted = ControllableState(wrappedValue: isReacted.wrappedValue, external: isReacted)
    }

    private var displayCount: Int { count + (reacted ? 1 : 0) }

    public var body: some View {
        Button(action: toggle) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 15))
                    .scaleEffect(pop ? 1.35 : 1)
                RollingNumber(displayCount)
                    .size(13)
                    .weight(.semibold)
                    .color(reacted ? theme.text(.textHero) : theme.text(.textSecondary))
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, 5)
            .background(reacted ? SemanticColor.primary.soft : theme.background(.bgSecondaryLight), in: Capsule())
            .overlay(Capsule().stroke(reacted ? theme.border(.borderHero) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(themeKit: "React with \(emoji), \(displayCount) reactions")))
        .accessibilityAddTraits(reacted ? .isSelected : [])
    }

    private func toggle() {
        reacted.toggle()
        Haptics.tap()
        // One-shot pop, animated back on completion; skipped under Reduce Motion.
        if reacted, micro, !reduceMotion {
            withAnimation(Motion.fast.animation) { pop = true } completion: {
                withAnimation(Motion.fast.animation) { pop = false }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var liked = false
        var body: some View {
            HStack(spacing: 10) {
                EmojiReactionButton("👍", count: 12, isReacted: $liked)
                EmojiReactionButton("🎉", count: 4, initiallyReacted: true)
                EmojiReactionButton("🔥", count: 0)
            }
            .padding()
        }
    }
    return Demo()
}
