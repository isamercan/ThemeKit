//
//  SegmentedControl.swift
//  GlobalUIComponents
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

public struct SegmentedControl: View {
    private let items: [SegmentItem]
    @Binding private var selection: Int
    private let accessibilityID: String?

    @Namespace private var pill

    public init(_ items: [SegmentItem], selection: Binding<Int>, accessibilityID: String? = nil) {
        self.items = items
        self._selection = selection
        self.accessibilityID = accessibilityID
    }

    public init(_ items: [String], selection: Binding<Int>, accessibilityID: String? = nil) {
        self.items = items.map { SegmentItem($0) }
        self._selection = selection
        self.accessibilityID = accessibilityID
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isActive = index == selection
                Button {
                    withAnimation(Motion.fast.animation) { selection = index }
                } label: {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        if let icon = item.systemImage {
                            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        }
                        Text(item.title).textStyle(isActive ? .labelBase700 : .labelBase600)
                    }
                    .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
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
                .disabled(!item.isEnabled)
            }
        }
        .padding(4)
        .background(Theme.shared.background(.bgElevatorPrimary),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
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
