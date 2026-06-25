//
//  SearchBar.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SearchView. Magnifying-glass
//  leading icon, clear button, optional back / trailing actions.
//

import SwiftUI

public struct SearchBar: View {
    @Binding private var text: String
    private let placeholder: String
    private let showBackButton: Bool
    private let trailingSystemImage: String?
    private let onBack: (() -> Void)?
    private let onTrailing: (() -> Void)?
    private let debounce: TimeInterval
    private let onSearch: ((String) -> Void)?
    private let accessibilityID: String?
    private let isEnabled: Bool

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        showBackButton: Bool = false,
        trailingSystemImage: String? = nil,
        debounce: TimeInterval = 0,
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        onBack: (() -> Void)? = nil,
        onTrailing: (() -> Void)? = nil,
        onSearch: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.showBackButton = showBackButton
        self.trailingSystemImage = trailingSystemImage
        self.debounce = debounce
        self.onSearch = onSearch
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.onBack = onBack
        self.onTrailing = onTrailing
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if showBackButton {
                Button { onBack?() } label: {
                    Icon(systemName: "chevron.left", size: .md, color: Theme.shared.text(.textPrimary))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass", size: .sm, color: Theme.shared.text(.textTertiary))

                TextField(placeholder, text: $text)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                    .tint(Theme.shared.foreground(.fgHero))
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(placeholder)

                if !text.isEmpty {
                    Button { text = "" } label: {
                        Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                } else if let trailingSystemImage {
                    Button { onTrailing?() } label: {
                        Icon(systemName: trailingSystemImage, size: .sm, color: Theme.shared.text(.textPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(44)
            .background(Theme.shared.background(.bgElevatorPrimary),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous)
                    .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
            )
        }
        .onDebouncedChange(of: text, for: onSearch == nil ? 0 : debounce) { value in
            onSearch?(value)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var a = ""
        @State var b = "query"
        var body: some View {
            VStack(spacing: 16) {
                SearchBar(text: $a, trailingSystemImage: "barcode.viewfinder")
                SearchBar(text: $b, showBackButton: true)
            }
            .padding()
        }
    }
    return Demo()
}
