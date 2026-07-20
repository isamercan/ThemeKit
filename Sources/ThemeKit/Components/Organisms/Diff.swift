//
//  Diff.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Before / after comparison with a draggable divider that reveals the
/// two layers. (daisyUI "Diff".)
public struct Diff<Before: View, After: View>: View {
    @Environment(\.theme) private var theme
    // `.offset(x:)` and gesture coordinates don't auto-mirror — the divider
    // position and drag delta branch on this under RTL. `fraction` always
    // measures the split from the LEADING edge (the mask's `.leading`
    // alignment mirrors on its own).
    @Environment(\.layoutDirection) private var layoutDirection

    private let before: () -> Before
    private let after: () -> After

    // Appearance/config — mutated only through the modifiers below (R2).
    private var aspectRatio: CGFloat = 16.0 / 9.0

    @State private var fraction: CGFloat = 0.5

    public init(@ViewBuilder before: @escaping () -> Before, @ViewBuilder after: @escaping () -> After) {   // R1
        self.before = before
        self.after = after
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // Mirrors the absolute x offsets: the ZStack's `.leading` anchor
            // flips to the physical right under RTL, so the push-out inverts.
            let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
            ZStack(alignment: .leading) {
                after()
                    .frame(width: w, height: geo.size.height)
                    .clipped()
                before()
                    .frame(width: w, height: geo.size.height)
                    .clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: max(0, w * fraction)) }

                Rectangle()
                    .fill(theme.background(.bgWhite))
                    .frame(width: 2)
                    .offset(x: (w * fraction - 1) * direction)

                Circle()
                    .fill(theme.background(.bgWhite))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 14, weight: .bold)).foregroundStyle(theme.text(.textPrimary)))
                    .themeShadow(.soft)
                    .offset(x: (w * fraction - 18) * direction)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { value in
                // Gesture x is physical — measure from the trailing side in RTL
                // so the divider follows the finger.
                let physical = min(max(value.location.x / w, 0), 1)
                fraction = layoutDirection == .rightToLeft ? 1 - physical : physical
            })
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        // The drag handle is invisible to VoiceOver — expose the split as one
        // adjustable element instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKit: "Before and after comparison"))
        .accessibilityValue(Text(Double(fraction), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.1
            switch direction {
            case .increment: fraction = min(1, fraction + step)
            case .decrement: fraction = max(0, fraction - step)
            @unknown default: break
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Diff {
    /// Aspect ratio of the comparison stage (default 16:9). Named `aspect` so it
    /// doesn't shadow SwiftUI's `.aspectRatio(_:contentMode:)`.
    func aspect(_ ratio: CGFloat) -> Self { copy { $0.aspectRatio = ratio } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("Diff") {
                PreviewCase("Default 16:9 (drag divider in live preview)") {
                    Diff {
                        theme.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
                    } after: {
                        theme.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
                    }
                }
                PreviewCase("Custom aspect · 21:9") {
                    Diff {
                        theme.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
                    } after: {
                        theme.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
                    }
                    .aspect(21.0 / 9.0)
                }
            }
        }
    }
    return Demo()
}

#Preview("RTL — divider and drag mirror") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            Diff {
                theme.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
            } after: {
                theme.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
    return Demo()
}
