//
//  Join.swift
//  ThemeKit
//

import SwiftUI

/// Atom. Joins adjacent controls into one connected group — a single rounded outer
/// border with the children butted together (no gaps). (daisyUI "Join".)
///
/// ```swift
/// Join { SecondaryButton("Prev") {}; SecondaryButton("Next") {} }
/// ```
public struct Join<Content: View>: View {
    @Environment(\.theme) private var theme

    private let axis: Axis
    private let content: Content

    public init(_ axis: Axis = .horizontal, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }

    public var body: some View {
        layout
            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .stroke(theme.border(.borderPrimary), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var layout: some View {
        if axis == .horizontal {
            HStack(spacing: 0) { content }
        } else {
            VStack(spacing: 0) { content }
        }
    }
}

#Preview {
    Join {
        ForEach(["Day", "Week", "Month"], id: \.self) { label in
            Text(label)
                .textStyle(.labelBase600)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .frame(height: 40)
            DividerView().axis(.vertical)
        }
    }
    .padding()
}
