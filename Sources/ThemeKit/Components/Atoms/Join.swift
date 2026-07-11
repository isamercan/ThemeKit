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

    // Appearance — mutated only through the modifiers below.
    private var axis: Axis
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

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Join {
    /// Layout axis of the joined controls. Preferred over the `axis:` init
    /// argument (orientation is a reskin, so it chains):
    /// `Join { … }.axis(.vertical)`.
    func axis(_ axis: Axis) -> Self { copy { $0.axis = axis } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Join") {
        PreviewCase("Horizontal") {
            Join {
                ForEach(["Day", "Week", "Month"], id: \.self) { label in
                    Text(label)
                        .textStyle(.labelBase600)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: 40)
                    DividerView().axis(.vertical)
                }
            }
        }
        PreviewCase("Vertical") {
            Join(.vertical) {
                ForEach(["Copy", "Paste", "Delete"], id: \.self) { label in
                    Text(label)
                        .textStyle(.labelBase600)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: 40)
                    DividerView()
                }
            }
        }
    }
}
