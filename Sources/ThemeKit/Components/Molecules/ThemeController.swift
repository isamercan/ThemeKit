//
//  ThemeController.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A packaged theme switcher: selecting an option loads that theme via
/// ``Theme/loadTheme(named:dark:)``. (daisyUI "Theme Controller".)
public struct ThemeController: View {
    @Environment(\.theme) private var theme

    public struct Option: Identifiable {
        public let id = UUID()
        let name: String
        let label: String
        public init(name: String, label: String) { self.name = name; self.label = label }
    }

    private let options: [Option]
    @Binding private var selectedName: String
    // Appearance — mutated only through the modifiers below (R2).
    private var accent: SemanticColor?
    private var fullWidth = true

    public init(options: [Option], selectedName: Binding<String>) {
        self.options = options
        self._selectedName = selectedName
    }

    /// Active-label tint — semantic accent when set, else the hero token (R4).
    private var activeText: Color { accent.map { theme.resolve($0).accent } ?? theme.text(.textHero) }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isActive = option.name == selectedName
                Button {
                    theme.loadTheme(named: option.name)
                    withAnimation(Motion.fast.animation) { selectedName = option.name }
                } label: {
                    Text(option.label)
                        .textStyle(isActive ? .labelBase700 : .labelBase600)
                        .foregroundStyle(isActive ? activeText : theme.text(.textSecondary))
                        .frame(maxWidth: fullWidth ? .infinity : nil)
                        .padding(.horizontal, fullWidth ? 0 : Theme.SpacingKey.sm.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                                .fill(theme.background(.bgWhite))
                                .themeShadow(.soft)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.SpacingKey.xs.value)   // 4pt == SpacingKey.xs
        .background(theme.background(.bgBase), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ThemeController {
    /// Token-fed tint for the active option's label; `nil` (default) keeps the hero token.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Stretch options to share the available width (default on); off = intrinsic widths.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.fullWidth = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var themeName = "defaultTheme"
        var body: some View {
            let options: [ThemeController.Option] = [
                .init(name: "defaultTheme", label: "Default"),
                .init(name: "oceanTheme", label: "Ocean"),
                .init(name: "sunsetTheme", label: "Sunset"),
            ]
            PreviewMatrix("ThemeController") {
                PreviewCase("Full width (default)") { ThemeController(options: options, selectedName: $themeName) }
                PreviewCase("Accent + intrinsic width") {
                    ThemeController(options: options, selectedName: $themeName)
                        .accent(.success)
                        .fullWidth(false)
                }
            }
        }
    }
    return Demo()
}
