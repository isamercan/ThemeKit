//
//  SegmentedControl.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public struct SegmentItem {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    public init(_ title: String, systemImage: String? = nil, isEnabled: Bool = true) {
        self.title = title; self.systemImage = systemImage; self.isEnabled = isEnabled
    }
}

/// Vertical sizing of the segments. (Ant Segmented `size`.)
public enum SegmentedSize {
    case small, medium, large

    var verticalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.xs.value
        case .medium: return Theme.SpacingKey.sm.value
        case .large: return Theme.SpacingKey.md.value
        }
    }
}

/// Molecule. Enclosed single-select control — the selected segment is a raised
/// white pill. Options can carry an icon and a disabled state. (Ant Segmented.)
public struct SegmentedControl: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var isFullWidth = true
    private var size: SegmentedSize = .medium
    private var accessibilityID: String? = nil

    private let items: [SegmentItem]
    @Binding private var selection: Int
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    @Namespace private var pill
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ items: [SegmentItem], selection: Binding<Int>) {   // R1
        self.items = items
        self._selection = selection
    }

    public init(_ items: [String], selection: Binding<Int>) {   // R1
        self.init(items.map { SegmentItem($0) }, selection: selection)
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isActive = index == selection
                Button {
                    withAnimation(motion) { selection = index }
                } label: {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        if let icon = item.systemImage {
                            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        }
                        Text(item.title).textStyle(isActive ? .labelBase700 : .labelBase600)
                    }
                    .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                    .frame(maxWidth: isFullWidth ? .infinity : nil)
                    .padding(.vertical, size.verticalPadding)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .background {
                        if isActive {
                            RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                                .fill(theme.background(.bgWhite))
                                .themeShadow(.soft)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled || !item.isEnabled)
            }
        }
        .padding(4)
        .background(theme.background(.bgBase),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(items.indices.contains(selection) ? items[selection].title : "")
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textHero) : theme.text(.textSecondary)
    }
}

#Preview {
    struct Demo: View {
        @State var sel = 0
        var body: some View {
            VStack(spacing: 16) {
                SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $sel)
                SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                  SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                  SegmentItem("Map", systemImage: "map", isEnabled: false)], selection: $sel)
            }
            .padding()
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SegmentedControl {
    /// Stretch each segment to fill the available width (Ant Segmented `block`).
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isFullWidth = on } }

    /// Vertical sizing of the segments: small / medium / large.
    func size(_ s: SegmentedSize) -> Self { copy { $0.size = s } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
