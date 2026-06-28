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

    private let aspectRatio: CGFloat
    private let before: () -> Before
    private let after: () -> After

    @State private var fraction: CGFloat = 0.5

    public init(aspectRatio: CGFloat = 16.0 / 9.0, @ViewBuilder before: @escaping () -> Before, @ViewBuilder after: @escaping () -> After) {
        self.aspectRatio = aspectRatio
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

#Preview {
    Diff {
        Theme.shared.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
    } after: {
        Theme.shared.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
    }
    .padding()
}
