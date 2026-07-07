//
//  SortSummaryBar.swift
//  ThemeKit
//
//  Molecule. A sort selector where each option previews its result — "Best"
//  ₺2.777 · 1h 07m / "Cheapest" / "Fastest". Composed from the standalone
//  ``SortTab`` atom so a developer can lay out their own sort UI. Token-bound;
//  scrolls horizontally, with an optional trailing "more sort" action.
//

import SwiftUI

/// One sort option in a ``SortSummaryBar`` — a title plus a previewed value/subtitle and optional icon.
public struct SortOption: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let value: String?
    public let subtitle: String?
    public let icon: String?
    public init(_ title: String, value: String? = nil, subtitle: String? = nil, icon: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
    }
}

/// One tab of a sort bar — an icon+title, a previewed value/subtitle and a selected underline.
/// Public so it can be reused outside ``SortSummaryBar`` in a custom layout.
public struct SortTab: View {
    @Environment(\.theme) private var theme
    private let option: SortOption
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ option: SortOption, isSelected: Bool, action: @escaping () -> Void) {   // R1
        self.option = option
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if let icon = option.icon {
                        Image(systemName: icon).font(.system(size: 12))
                            .foregroundStyle(isSelected ? theme.foreground(.fgHero) : theme.text(.textSecondary))
                    }
                    Text(option.title).textStyle(.labelBase600)
                        .foregroundStyle(isSelected ? theme.text(.textPrimary) : theme.text(.textSecondary))
                }
                if let value = option.value {
                    Text(value).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
                if let subtitle = option.subtitle {
                    Text(subtitle).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
                Rectangle().fill(isSelected ? theme.foreground(.fgHero) : .clear).frame(height: 2).padding(.top, 2)
            }
            .frame(minWidth: 84, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title)\(option.value.map { ", " + $0 } ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public struct SortSummaryBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let options: [SortOption]
    @Binding private var selection: Int
    // Appearance/state — mutated only through the modifiers below (R2).
    private var onMore: (() -> Void)?
    private var moreIcon = "slider.horizontal.3"

    public init(_ options: [SortOption], selection: Binding<Int>) {   // R1
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: density.scale(Theme.SpacingKey.lg.value)) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        SortTab(option, isSelected: i == selection) { selection = i }
                    }
                }
            }
            if let onMore { moreButton(onMore) }
        }
    }

    private func moreButton(_ action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1, height: 28).padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
            Button(action: action) {
                Image(systemName: moreIcon).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.foreground(.fgHero))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More sort options")
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SortSummaryBar {
    /// Adds a trailing "more sort" button (default a sliders icon).
    func onMore(icon: String = "slider.horizontal.3", action: @escaping () -> Void) -> Self {
        copy { $0.onMore = action; $0.moreIcon = icon }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel = 0
        var body: some View {
            SortSummaryBar([
                SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"),
                SortOption("Cheapest", value: "₺2.178", subtitle: "6h 45m", icon: "tag.fill"),
                SortOption("Fastest", value: "₺2.852", subtitle: "1h 05m", icon: "bolt.fill"),
            ], selection: $sel).onMore { }.padding()
        }
    }
    return Demo()
}
