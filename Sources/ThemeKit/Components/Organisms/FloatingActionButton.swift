//
//  FloatingActionButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
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

/// Organism. A floating action button with an optional speed-dial of sub-actions.
/// (daisyUI "FAB / Speed Dial".)
public struct FloatingActionButton: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var shape: FABShape = .circle
    private var color: SemanticColor = .primary
    private var badge: Int?

    private let systemImage: String
    private let actions: [FABAction]
    private let action: () -> Void

    @State private var expanded = false

    public init(
        systemImage: String = "plus",
        actions: [FABAction] = [],
        action: @escaping () -> Void = {}
    ) {   // R1 — content + speed-dial data + primary action
        self.systemImage = systemImage
        self.actions = actions
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
                                .foregroundStyle(theme.text(.textPrimary))
                                .padding(.horizontal, Theme.SpacingKey.sm.value)
                                .frame(height: 28)
                                .background(theme.background(.bgWhite), in: Capsule())
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
                .foregroundStyle(theme.text(.textHero))
                .frame(width: 44, height: 44)
                .background(theme.background(.bgWhite), in: Circle())
                .themeShadow(.soft)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FloatingActionButton {
    /// Corner treatment of the main button: circle / square.
    func shape(_ s: FABShape) -> Self { copy { $0.shape = s } }

    /// Semantic color token driving the main button's fill (R4); `nil` restores
    /// the primary default. Standard accent vocabulary (flexibility audit §6).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.color = color ?? .primary } }

    /// Semantic color token driving the main button's fill (R4).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: SemanticColor) -> Self { accent(c) }

    /// Count bubble on the main button (hidden when 0 or nil).
    func badge(_ count: Int?) -> Self { copy { $0.badge = count } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
