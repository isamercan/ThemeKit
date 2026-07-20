//
//  ThemeContextMenu.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A data-driven wrapper over the native `.contextMenu`, with an optional
//  token-styled preview. (HeroUI Pro "Context Menu".) Honest contract: the menu
//  *chrome* is the system's — not token-stylable — so the kit's value is the
//  shared data model (same shape as DropdownItem), the styled preview, and API
//  consistency. We do not re-implement long-press to fight the system menu.
//

import SwiftUI

/// One entry in a `.themeContextMenu`. Nest `children` for a submenu.
public struct MenuAction: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isDisabled: Bool
    public let children: [MenuAction]
    public let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, role: ButtonRole? = nil,
                isDisabled: Bool = false, children: [MenuAction] = [], id: String? = nil,
                action: @escaping () -> Void = {}) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isDisabled = isDisabled
        self.children = children
        self.action = action
        self.id = id ?? title
    }
}

/// Recursive menu body — a concrete `View` type so submenus can nest without an
/// opaque-return recursion.
private struct MenuActionList: View {
    let actions: [MenuAction]

    var body: some View {
        ForEach(actions) { action in
            if action.children.isEmpty {
                Button(role: action.role, action: action.action) {
                    label(action)
                }
                .disabled(action.isDisabled)
            } else {
                Menu {
                    MenuActionList(actions: action.children)
                } label: {
                    label(action)
                }
            }
        }
    }

    @ViewBuilder private func label(_ action: MenuAction) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }
}

public extension View {
    /// Attach a data-driven context menu (long-press / right-click). Supports
    /// submenus, destructive `role`, disabled items and SF Symbols.
    ///
    ///     row.themeContextMenu([
    ///         MenuAction("Share", systemImage: "square.and.arrow.up") { … },
    ///         MenuAction("Delete", systemImage: "trash", role: .destructive) { … },
    ///     ])
    func themeContextMenu(_ actions: [MenuAction]) -> some View {
        contextMenu { MenuActionList(actions: actions) }
    }

    /// Same, with a token-styled preview card shown while the menu is open.
    /// The preview form is iOS 16+; below, the menu opens without the preview
    /// card (named ``ContextMenuPreviewCompat`` unit, ADR-0007 §D2 rules 2–3).
    func themeContextMenu<P: View>(_ actions: [MenuAction], @ViewBuilder preview: @escaping () -> P) -> some View {
        modifier(ContextMenuPreviewCompat(actions: actions, preview: preview))
    }
}

/// Named degrade unit for `contextMenu(menuItems:preview:)` (iOS 16): the
/// `else` branch is the same data-driven menu without the preview card.
private struct ContextMenuPreviewCompat<P: View>: ViewModifier {
    let actions: [MenuAction]
    let preview: () -> P

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.contextMenu {
                MenuActionList(actions: actions)
            } preview: {
                preview()
            }
        } else {
            content.contextMenu { MenuActionList(actions: actions) }
        }
    }
}

#Preview {
    PreviewMatrix("ThemeContextMenu") {
        PreviewCase("Submenu + destructive (long-press)") {
            Text("Long-press me")
                .textStyle(.labelBase600)
                .padding()
                .themeContextMenu([
                    MenuAction("Share", systemImage: "square.and.arrow.up") {},
                    MenuAction("Move", systemImage: "folder", children: [
                        MenuAction("To Inbox") {},
                        MenuAction("To Archive") {},
                    ]),
                    MenuAction("Delete", systemImage: "trash", role: .destructive) {},
                ])
        }
        PreviewCase("With preview card") {
            Text("With preview")
                .textStyle(.labelBase600)
                .padding()
                .themeContextMenu([MenuAction("Open", systemImage: "arrow.up.forward") {}]) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview").textStyle(.labelBase600)
                        Text("A token-styled preview card.").textStyle(.bodySm400)
                    }
                    .padding()
                }
        }
    }
}
