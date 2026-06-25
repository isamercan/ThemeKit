//
//  Spinner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. Indeterminate circular loading indicator (token-tinted).
//

import SwiftUI

public struct Spinner: View {
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let color: Color?

    @State private var rotating = false

    public init(size: CGFloat = 24, lineWidth: CGFloat = 3, color: Color? = nil) {
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                (color ?? Theme.shared.foreground(.fgHero)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}

#Preview {
    HStack(spacing: 24) {
        Spinner(size: 16, lineWidth: 2)
        Spinner()
        Spinner(size: 40, lineWidth: 4)
    }
    .padding()
}
