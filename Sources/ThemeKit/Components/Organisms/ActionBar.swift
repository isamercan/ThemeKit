//
//  ActionBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A contextual multi-select action bar: a floating capsule showing the
//  selection count and the actions that apply to it. (HeroUI Pro "Action Bar".)
//  Use `ActionBar` directly, or `.actionBar(selection:actions:)` to auto-show it
//  above the content while a selection set is non-empty.
//

import SwiftUI

/// One action in an `ActionBar`. A `.destructive` role renders in the error hue.
public struct ActionBarAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, role: ButtonRole? = nil,
                id: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
        self.id = id ?? title
    }
}

/// Organism. The floating bar itself. `onClear` (when set) adds a trailing close
/// affordance that deselects.
public struct ActionBar: View {
    @Environment(\.theme) private var theme

    private let count: Int
    private let actions: [ActionBarAction]
    private let onClear: (() -> Void)?

    public init(count: Int, actions: [ActionBarAction], onClear: (() -> Void)? = nil) {   // R1
        self.count = count
        self.actions = actions
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Text("\(count)")
                .textStyle(.labelSm700)
                .foregroundStyle(theme.foreground(.fgSecondary))
                .frame(minWidth: 22, minHeight: 22)
                .background(theme.background(.bgHero), in: Circle())
            Text(String(themeKit: "selected"))
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textSecondary))

            Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1, height: 20)

            ForEach(actions) { action in
                actionButton(action)
            }

            if let onClear {
                CloseButton { onClear() }.controlSize(.small)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(theme.background(.bgWhite), in: Capsule())
        .overlay(Capsule().stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.elevated)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(String(themeKit: "\(count) selected")))
        .onAppear { AccessibilityNotification.Announcement(String(themeKit: "\(count) selected")).post() }
    }

    private func actionButton(_ action: ActionBarAction) -> some View {
        let isDestructive = action.role == .destructive
        return Button(role: action.role, action: action.action) {
            VStack(spacing: 2) {
                if let systemImage = action.systemImage {
                    Icon(systemName: systemImage).size(.sm)
                }
                Text(action.title).textStyle(.labelSm600)
            }
            .foregroundStyle(isDestructive ? theme.foreground(.systemcolorsFgError) : theme.text(.textPrimary))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

private struct ActionBarModifier<ID: Hashable>: ViewModifier {
    @Binding var selection: Set<ID>
    let actions: [ActionBarAction]

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if !selection.isEmpty {
                ActionBar(count: selection.count, actions: actions, onClear: { selection.removeAll() })
                    .padding(.bottom, Theme.SpacingKey.lg.value)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion), value: selection.isEmpty)
    }
}

public extension View {
    /// Show an `ActionBar` above this view whenever `selection` is non-empty,
    /// sliding in from the bottom (fade-only under Reduce Motion). The bar's
    /// close affordance clears the selection.
    ///
    ///     List(selection: $selected) { … }
    ///         .actionBar(selection: $selected, actions: [
    ///             ActionBarAction("Archive", systemImage: "archivebox") { … },
    ///             ActionBarAction("Delete", systemImage: "trash", role: .destructive) { … },
    ///         ])
    func actionBar<ID: Hashable>(selection: Binding<Set<ID>>, actions: [ActionBarAction]) -> some View {
        modifier(ActionBarModifier(selection: selection, actions: actions))
    }
}

#Preview {
    struct Demo: View {
        @State var selected: Set<Int> = [1, 2, 3]
        var body: some View {
            VStack {
                Text("Tap an action or clear").padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .actionBar(selection: $selected, actions: [
                ActionBarAction("Archive", systemImage: "archivebox") {},
                ActionBarAction("Share", systemImage: "square.and.arrow.up") {},
                ActionBarAction("Delete", systemImage: "trash", role: .destructive) { selected.removeAll() },
            ])
        }
    }
    return Demo()
}
