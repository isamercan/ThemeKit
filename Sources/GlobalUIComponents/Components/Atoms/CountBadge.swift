//
//  CountBadge.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Ant "Badge": a small count / dot overlaid on the corner of any view, plus a
//  corner Ribbon. (Our `Badge` atom is Ant's "Tag"; this fills the real Ant
//  Badge role.)
//

import SwiftUI

public extension View {
    /// Overlays a count bubble in the top-trailing corner (Ant `Badge count`).
    func countBadge(_ count: Int, overflowCount: Int = 99, showZero: Bool = false, color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) {
            if count > 0 || showZero {
                Text(count > overflowCount ? "\(overflowCount)+" : "\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color.onSolid)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(color.solid, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.shared.background(.bgWhite), lineWidth: 1.5))
                    .offset(x: 9, y: -9)
            }
        }
    }

    /// Overlays a status dot in the top-trailing corner (Ant `Badge dot`).
    func dotBadge(color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) {
            Circle().fill(color.solid).frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Theme.shared.background(.bgWhite), lineWidth: 1.5))
                .offset(x: 4, y: -4)
        }
    }
}

/// A corner ribbon wrapping any content (Ant `Badge.Ribbon`).
public struct Ribbon<Content: View>: View {
    private let text: String
    private let color: SemanticColor
    private let content: Content

    public init(_ text: String, color: SemanticColor = .primary, @ViewBuilder content: () -> Content) {
        self.text = text
        self.color = color
        self.content = content()
    }

    public var body: some View {
        content.overlay(alignment: .topTrailing) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.onSolid)
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, 3)
                .background(color.solid)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: 6, y: 8)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }
}

#Preview {
    HStack(spacing: 32) {
        Image(systemName: "bell.fill").font(.title).countBadge(5)
        Image(systemName: "envelope.fill").font(.title).countBadge(128)
        Image(systemName: "cart.fill").font(.title).dotBadge(color: .success)
        Ribbon("New", color: .error) {
            RoundedRectangle(cornerRadius: 12).fill(Theme.shared.background(.bgElevatorTertiary)).frame(width: 100, height: 70)
        }
    }
    .padding(40)
}
