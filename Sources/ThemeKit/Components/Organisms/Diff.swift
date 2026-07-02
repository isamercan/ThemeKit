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
                    .offset(x: w * fraction - 1)

                Circle()
                    .fill(theme.background(.bgWhite))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 14, weight: .bold)).foregroundStyle(theme.text(.textPrimary)))
                    .themeShadow(.soft)
                    .offset(x: w * fraction - 18)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { value in
                fraction = min(max(value.location.x / w, 0), 1)
            })
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
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
    @Previewable @Environment(\.theme) var theme
    Diff {
        theme.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
    } after: {
        theme.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
    }
    .padding()
}
