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

    private let items: [SegmentItem]
    @Binding private var selection: Int
    private let block: Bool
    private let size: SegmentedSize
    private let isEnabled: Bool
    private var accessibilityID: String? = nil

    @Namespace private var pill
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        _ items: [SegmentItem],
        selection: Binding<Int>,
        block: Bool = true,
        size: SegmentedSize = .medium,
        isEnabled: Bool = true
    ) {
        self.items = items
        self._selection = selection
        self.block = block
        self.size = size
        self.isEnabled = isEnabled
    }

    public init(
        _ items: [String],
        selection: Binding<Int>,
        block: Bool = true,
        size: SegmentedSize = .medium,
        isEnabled: Bool = true
    ) {
        self.init(items.map { SegmentItem($0) }, selection: selection,
                  block: block, size: size, isEnabled: isEnabled)
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
                    .frame(maxWidth: block ? .infinity : nil)
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
        .background(theme.background(.bgElevatorPrimary),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
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

public extension SegmentedControl {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
