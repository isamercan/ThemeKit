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

    // Appearance — mutated only through the modifiers below (R2).
    private var size: ChipSize = .small
    private var accent: SemanticColor?

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

    // Size ramp — shares Chip's `ChipSize` vocabulary; `.small` reproduces the
    // original metrics exactly. Fixed glyph constants (no semantic token).
    private var emojiPointSize: CGFloat {
        switch size {
        case .small: return 15
        case .medium: return 17
        case .large: return 19
        }
    }
    private var countPointSize: CGFloat {
        switch size {
        case .small: return 13
        case .medium: return 14
        case .large: return 15
        }
    }
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 5
        case .medium: return 7
        case .large: return 9
        }
    }
    private var horizontalPadding: CGFloat {
        size == .large ? Theme.SpacingKey.md.value : Theme.SpacingKey.sm.value
    }

    /// Chroma when reacted — the semantic accent when set, else the stock hero
    /// treatment (unchanged default).
    private var reactedFill: Color { accent.map { theme.resolve($0).soft } ?? theme.resolve(.primary).soft }
    private var reactedBorder: Color { accent.map { theme.resolve($0).border } ?? theme.border(.borderHero) }
    private var reactedCount: Color { accent.map { theme.resolve($0).accent } ?? theme.text(.textHero) }

    public var body: some View {
        Button(action: toggle) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: emojiPointSize))
                    .scaleEffect(pop ? 1.35 : 1)
                RollingNumber(displayCount)
                    .size(countPointSize)
                    .weight(.semibold)
                    .colorOverride(reacted ? reactedCount : theme.text(.textSecondary))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(reacted ? reactedFill : theme.background(.bgSecondaryLight), in: Capsule())
            .overlay(Capsule().stroke(reacted ? reactedBorder : .clear, lineWidth: 1))
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension EmojiReactionButton {
    /// Control size: small (default) / medium / large — shares Chip's
    /// ``ChipSize`` vocabulary and drives the emoji/count sizes and paddings.
    func size(_ s: ChipSize) -> Self { copy { $0.size = s } }

    /// Semantic tint for the reacted state (soft fill, border and count);
    /// `nil` (default) keeps the stock hero treatment.
    func accent(_ c: SemanticColor?) -> Self { copy { $0.accent = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var liked = false
        var body: some View {
            PreviewMatrix("EmojiReactionButton") {
                PreviewCase("Controlled / reacted / zero") {
                    HStack(spacing: 10) {
                        EmojiReactionButton("👍", count: 12, isReacted: $liked)
                        EmojiReactionButton("🎉", count: 4, initiallyReacted: true)
                        EmojiReactionButton("🔥", count: 0)
                    }
                }
                // D8 — size ramp + semantic accent for the reacted state.
                PreviewCase("Size ramp + semantic accents") {
                    HStack(spacing: 10) {
                        EmojiReactionButton("👍", count: 3, initiallyReacted: true).size(.medium)
                        EmojiReactionButton("❤️", count: 9, initiallyReacted: true).size(.large).accent(.error)
                        EmojiReactionButton("✅", count: 2, initiallyReacted: true).accent(.success)
                    }
                }
            }
        }
    }
    return Demo()
}
