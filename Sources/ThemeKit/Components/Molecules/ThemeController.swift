//
//  ThemeController.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A packaged theme switcher: selecting an option loads that theme via
//  `Theme.shared.loadTheme(named:)`. (daisyUI "Theme Controller".)
//

import SwiftUI

public struct ThemeController: View {
    public struct Option: Identifiable {
        public let id = UUID()
        let name: String
        let label: String
        public init(name: String, label: String) { self.name = name; self.label = label }
    }

    private let options: [Option]
    @Binding private var selectedName: String

    public init(options: [Option], selectedName: Binding<String>) {
        self.options = options
        self._selectedName = selectedName
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isActive = option.name == selectedName
                Button {
                    Theme.shared.loadTheme(named: option.name)
                    withAnimation(Motion.fast.animation) { selectedName = option.name }
                } label: {
                    Text(option.label)
                        .textStyle(isActive ? .labelBase700 : .labelBase600)
                        .foregroundStyle(isActive ? Theme.shared.text(.textHero) : Theme.shared.text(.textSecondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                                    .fill(Theme.shared.background(.bgWhite))
                                    .themeShadow(.soft)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.shared.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

#Preview {
    struct Demo: View {
        @State var theme = "defaultTheme"
        var body: some View {
            ThemeController(options: [
                .init(name: "defaultTheme", label: "Default"),
                .init(name: "oceanTheme", label: "Ocean"),
                .init(name: "sunsetTheme", label: "Sunset"),
            ], selectedName: $theme)
            .padding()
        }
    }
    return Demo()
}
