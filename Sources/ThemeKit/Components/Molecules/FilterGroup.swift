//
//  FilterGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A single-select chip filter with a reset control. (daisyUI "Filter".)
public struct FilterGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let label: (Option) -> String

    public init(title: String? = nil, options: [Option], selection: Binding<Option?>, label: @escaping (Option) -> String) {
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if selection != nil {
                        Button { selection = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.text(.textTertiary))
                                .frame(width: 32, height: 32)
                                .background(theme.background(.bgBase), in: Circle())
                                .overlay(Circle().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(options, id: \.self) { option in
                        Chip(label(option),
                             isSelected: Binding(get: { selection == option }, set: { isOn in selection = isOn ? option : nil }))
                            .chipStyle(.solid)
                    }
                }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var sel: String? = "Hotels"
        var body: some View {
            FilterGroup(title: "Category", options: ["Hotels", "Flights", "Cars", "Tours"], selection: $sel) { $0 }
                .padding()
        }
    }
    return Demo()
}
