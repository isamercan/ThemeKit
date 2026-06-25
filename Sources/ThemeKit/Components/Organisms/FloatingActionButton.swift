//
//  FloatingActionButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A floating action button with an optional speed-dial of sub-actions.
//  (daisyUI "FAB / Speed Dial".)
//

import SwiftUI

public struct FABAction: Identifiable {
    public let id = UUID()
    let systemImage: String
    let label: String?
    let action: () -> Void
    public init(systemImage: String, label: String? = nil, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }
}

public enum FABShape { case circle, square }

public struct FloatingActionButton: View {
    private let systemImage: String
    private let actions: [FABAction]
    private let shape: FABShape
    private let color: SemanticColor
    private let badge: Int?
    private let action: () -> Void

    @State private var expanded = false

    public init(
        systemImage: String = "plus",
        actions: [FABAction] = [],
        shape: FABShape = .circle,
        color: SemanticColor = .primary,
        badge: Int? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.systemImage = systemImage
        self.actions = actions
        self.shape = shape
        self.color = color
        self.badge = badge
        self.action = action
    }

    private var mainShape: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        }
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: Theme.SpacingKey.sm.value) {
            if !actions.isEmpty && expanded {
                ForEach(actions) { item in
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        if let label = item.label {
                            Text(label)
                                .textStyle(.labelSm600)
                                .foregroundStyle(Theme.shared.text(.textPrimary))
                                .padding(.horizontal, Theme.SpacingKey.sm.value)
                                .frame(height: 28)
                                .background(Theme.shared.background(.bgWhite), in: Capsule())
                                .themeShadow(.soft)
                        }
                        miniButton(item.systemImage) { item.action(); expanded = false }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Button {
                if actions.isEmpty { action() } else { withAnimation(Motion.fast.spring) { expanded.toggle() } }
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color.onSolid)
                    .frame(width: 56, height: 56)
                    .background(color.solid, in: mainShape)
                    .themeShadow(.elevated)
                    .rotationEffect(.degrees(expanded && !actions.isEmpty ? 45 : 0))
                    .countBadge(badge ?? 0)
            }
            .buttonStyle(.plain)
        }
    }

    private func miniButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.shared.text(.textHero))
                .frame(width: 44, height: 44)
                .background(Theme.shared.background(.bgWhite), in: Circle())
                .themeShadow(.soft)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FloatingActionButton(systemImage: "plus", actions: [
        .init(systemImage: "camera", label: "Photo", action: {}),
        .init(systemImage: "doc", label: "Document", action: {}),
        .init(systemImage: "link", label: "Link", action: {}),
    ])
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding()
}
