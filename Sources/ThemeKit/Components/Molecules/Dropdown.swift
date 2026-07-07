//
//  Dropdown.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Molecule. A lightweight action menu anchored to any trigger view — tap the
//  trigger and a themed floating panel of actions opens beside it; tap an item
//  (or anywhere outside) to dismiss. The token-bound `Menu` replacement: unlike
//  ``Select`` it binds to no selection, and unlike ``MenuCard`` it floats over
//  content instead of sitting in the layout. (daisyUI Dropdown.)
//

import SwiftUI

// MARK: - Item

/// One entry of a ``Dropdown`` menu — an action row, or a divider line.
public struct DropdownItem: Identifiable {
    /// Visual intent of an action row. (daisyUI Dropdown menu item.)
    public enum Role: Sendable {
        /// Regular action — primary text color.
        case normal
        /// Dangerous action (delete, sign out…) — error-tinted text and icon.
        case destructive
    }

    public let id = UUID()
    let title: String
    let systemImage: String?
    let role: Role
    let isDisabled: Bool
    let action: () -> Void
    let isDivider: Bool

    public init(
        _ title: String,
        systemImage: String? = nil,
        role: Role = .normal,
        disabled: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isDisabled = disabled
        self.action = action
        self.isDivider = false
    }

    private init(divider: Bool) {
        self.title = ""
        self.systemImage = nil
        self.role = .normal
        self.isDisabled = false
        self.action = {}
        self.isDivider = divider
    }

    /// A thin separator line between groups of actions.
    public static var divider: DropdownItem { DropdownItem(divider: true) }
}

// MARK: - Placement

/// Which corner of the trigger the menu panel grows from. (daisyUI Dropdown
/// `dropdown-top/bottom` + `dropdown-end`.)
public enum DropdownEdge: Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// `true` when the panel opens above the trigger.
    var isTop: Bool { self == .topLeading || self == .topTrailing }

    /// The overlay alignment that pins the panel to this corner of the anchor.
    var alignment: Alignment {
        switch self {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    /// Anchor point the open/close scale animates from (the corner touching the trigger).
    var scaleAnchor: UnitPoint {
        switch self {
        case .topLeading: return .bottomLeading
        case .topTrailing: return .bottomTrailing
        case .bottomLeading: return .topLeading
        case .bottomTrailing: return .topTrailing
        }
    }
}

/// Pushes the panel just outside the chosen edge of the anchor (Tooltip's approach).
private struct DropdownPlacement: ViewModifier {
    let edge: DropdownEdge

    func body(content: Content) -> some View {
        let gap = Theme.SpacingKey.xs.value
        if edge.isTop {
            content.offset(y: -gap).alignmentGuide(.top) { $0[.bottom] }
        } else {
            content.offset(y: gap).alignmentGuide(.bottom) { $0[.top] }
        }
    }
}

// MARK: - Dropdown

/// Molecule. A lightweight action menu anchored to any trigger view — tapping
/// the trigger presents a themed floating panel of ``DropdownItem`` actions;
/// tapping an item or anywhere outside dismisses it. (daisyUI Dropdown.)
///
/// ```swift
/// Dropdown(items: [
///     .init("Rename", systemImage: "pencil") { rename() },
///     .divider,
///     .init("Delete", systemImage: "trash", role: .destructive) { delete() },
/// ]) {
///     Icon(systemName: "ellipsis.circle").size(.md)
/// }
/// .edge(.bottomTrailing)
/// ```
public struct Dropdown<Trigger: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let items: [DropdownItem]
    private let trigger: Trigger

    // Appearance/config — mutated only through the modifiers below (R2).
    private var edge: DropdownEdge = .bottomLeading
    private var accentColor: SemanticColor = .neutral
    private var menuWidth: CGFloat? = nil

    @State private var open = false

    public init(items: [DropdownItem], @ViewBuilder trigger: () -> Trigger) {   // R1
        self.items = items
        self.trigger = trigger()
    }

    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        Button {
            open.toggle()
        } label: {
            trigger.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // Outside-tap catcher — an invisible surface centered on the anchor, big
        // enough to cover the screen; drawn under the panel (earlier overlay).
        .overlay {
            if open {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 10_000, height: 10_000)
                    .onTapGesture { open = false }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: edge.alignment) {
            if open {
                panel
                    .modifier(DropdownPlacement(edge: edge))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: edge.scaleAnchor)))
            }
        }
        .zIndex(open ? 1 : 0)   // float over later siblings while open (Tooltip-style)
        .animation(motion, value: open)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(open ? Text(String(themeKit: "Expanded")) : Text(String(themeKit: "Collapsed")))
        .accessibilityAction(.escape) { open = false }
    }

    // MARK: Panel

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                if item.isDivider {
                    DividerView().size(.small)
                        .padding(.vertical, Theme.SpacingKey.xs.value)
                } else {
                    row(item)
                }
            }
        }
        .padding(Theme.SpacingKey.xs.value)
        .frame(width: menuWidth, alignment: .leading)
        .fixedSize(horizontal: menuWidth == nil, vertical: true)
        .background(theme.background(.bgWhite), in: panelShape)
        .overlay(panelShape.stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.soft)
        .zIndex(1)
    }

    private func row(_ item: DropdownItem) -> some View {
        let destructive = item.role == .destructive
        let titleColor = destructive ? SemanticColor.error.accent : theme.text(.textPrimary)
        let iconColor = destructive ? SemanticColor.error.accent : theme.text(.textSecondary)

        return Button {
            open = false
            item.action()
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let systemImage = item.systemImage {
                    Icon(systemName: systemImage).size(.sm).color(iconColor)
                }
                Text(item.title)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: Theme.SpacingKey.md.value)
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(DropdownRowPressStyle(tint: destructive ? SemanticColor.error.soft : accentColor.soft))
        .disabled(item.isDisabled)
        .opacity(item.isDisabled ? 0.4 : 1)
    }
}

/// Row press feedback tinted by the dropdown's accent — the menu analog of
/// ``RowPressStyle``, with a configurable highlight color.
private struct DropdownRowPressStyle: ButtonStyle {
    let tint: Color
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? tint : .clear,
                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
            )
            .animation(MicroMotion.animation(.instant, enabled: micro, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Dropdown {
    /// Which corner of the trigger the panel opens from (default `.bottomLeading`).
    func edge(_ edge: DropdownEdge) -> Self { copy { $0.edge = edge } }

    /// Semantic tint of the pressed-row highlight (default `.neutral`).
    func accent(_ color: SemanticColor) -> Self { copy { $0.accentColor = color } }

    /// Fixed panel width in points; `nil` (default) fits the widest item.
    func menuWidth(_ points: CGFloat?) -> Self { copy { $0.menuWidth = points } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) private var theme

        var items: [DropdownItem] {
            [
                .init("Rename", systemImage: "pencil"),
                .init("Duplicate", systemImage: "plus.square.on.square"),
                .init("Share", systemImage: "square.and.arrow.up", disabled: true),
                .divider,
                .init("Delete", systemImage: "trash", role: .destructive),
            ]
        }

        var body: some View {
            VStack(spacing: 160) {
                HStack(spacing: 120) {
                    Dropdown(items: items) {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            Text("Options").textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                            Icon(systemName: "chevron.down").size(.xs).color(theme.text(.textTertiary))
                        }
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .background(theme.background(.bgSecondaryLight),
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
                    }

                    Dropdown(items: items) {
                        Icon(systemName: "ellipsis.circle").size(.md).color(theme.foreground(.fgHero))
                    }
                    .edge(.bottomTrailing)
                    .accent(.primary)
                }

                Dropdown(items: items) {
                    Icon(systemName: "square.grid.2x2").size(.md).color(theme.foreground(.fgHero))
                }
                .edge(.topLeading)
                .menuWidth(220)
            }
            .padding(80)
        }
    }
    return Demo()
}
