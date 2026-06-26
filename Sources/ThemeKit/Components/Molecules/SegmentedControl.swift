//
//  SegmentedControl.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Enclosed single-select control — the selected segment is a raised
//  white pill. Options can carry an icon and a disabled state. (Ant Segmented.)
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

public struct SegmentedControl: View {
    private let items: [SegmentItem]
    @Binding private var selection: Int
    private let block: Bool
    private let size: SegmentedSize
    private let isEnabled: Bool
    private let accessibilityID: String?

    @Namespace private var pill
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        _ items: [SegmentItem],
        selection: Binding<Int>,
        block: Bool = true,
        size: SegmentedSize = .medium,
        isEnabled: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.items = items
        self._selection = selection
        self.block = block
        self.size = size
        self.isEnabled = isEnabled
        self.accessibilityID = accessibilityID
    }

    public init(
        _ items: [String],
        selection: Binding<Int>,
        block: Bool = true,
        size: SegmentedSize = .medium,
        isEnabled: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.init(items.map { SegmentItem($0) }, selection: selection,
                  block: block, size: size, isEnabled: isEnabled, accessibilityID: accessibilityID)
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
                                .fill(Theme.shared.background(.bgWhite))
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
        .background(Theme.shared.background(.bgElevatorPrimary),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(items.indices.contains(selection) ? items[selection].title : "")
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return Theme.shared.text(.textDisabled) }
        return isActive ? Theme.shared.text(.textHero) : Theme.shared.text(.textSecondary)
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
