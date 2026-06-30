//
//  Chips.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The richer chip family ported from the reference (ImageChip / CompactChip /
//  ChoseChip / square FilterChip) plus a multi-select `ChipGroup`. Brand-neutral,
//  token-bound, no asset/Kingfisher dependencies. The simple selectable pill
//  lives in `Chip` (Atoms).
//

import SwiftUI

// MARK: - ImageChip

public enum ImageChipSize {
    case small, medium, large
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 66, height: 93)
        case .medium: return CGSize(width: 86, height: 122)
        case .large: return CGSize(width: 124, height: 175)
        }
    }
}

/// A selectable remote-image tile with a selection border. (Reference ImageChip.)
public struct ImageChip: View {
    @Environment(\.theme) private var theme

    @Binding private var isSelected: Bool
    private let url: URL?
    private let size: ImageChipSize
    private let isEnabled: Bool

    public init(isSelected: Binding<Bool>, url: URL?, size: ImageChipSize = .medium, isEnabled: Bool = true) {
        self._isSelected = isSelected
        self.url = url
        self.size = size
        self.isEnabled = isEnabled
    }

    public var body: some View {
        let s = size.size
        RemoteImage(url).ratio(s.width / s.height).cornerRadius(Theme.RadiusKey.sm.value)
            .frame(width: s.width, height: s.height)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { isSelected.toggle() } }
    }
}

// MARK: - CompactChip

/// A selectable card: an optional rating + label row, then an optional logo +
/// price row. (Reference CompactChip.)
public struct CompactChip: View {
    @Environment(\.theme) private var theme

    @Binding private var isSelected: Bool
    private let text: String
    private let price: String
    private let imageURL: URL?
    private let rating: Double?

    public init(isSelected: Binding<Bool>, text: String, price: String, imageURL: URL? = nil, rating: Double? = nil) {
        self._isSelected = isSelected
        self.text = text
        self.price = price
        self.imageURL = imageURL
        self.rating = rating
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                            .foregroundStyle(theme.text(.textPrimary))
                    }
                }
                Text(text).textStyle(.labelBase600).lineLimit(1)
                    .foregroundStyle(theme.text(.textPrimary))
            }
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let imageURL {
                    RemoteImage(imageURL).contentMode(.fit).frame(height: 16)
                }
                Text(price).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }
}

// MARK: - ChoseChip

/// A selectable card: a leading icon, a title with an optional "free" gradient
/// badge, and a rating + description row. (Reference ChoseChip.)
public struct ChoseChip: View {
    @Environment(\.theme) private var theme

    @Binding private var isSelected: Bool
    private let title: String
    private let description: String?
    private let rating: Double?
    private let showFree: Bool
    private let freeLabel: String
    private let systemImage: String?

    public init(
        isSelected: Binding<Bool>,
        title: String,
        description: String? = nil,
        rating: Double? = nil,
        showFree: Bool = false,
        freeLabel: String = String(themeKit: "Free"),
        systemImage: String? = nil
    ) {
        self._isSelected = isSelected
        self.title = title
        self.description = description
        self.rating = rating
        self.showFree = showFree
        self.freeLabel = freeLabel
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            if let systemImage {
                Icon(systemName: systemImage, size: .md, color: theme.foreground(.fgHero))
            }
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(title).textStyle(.labelMd600).lineLimit(1)
                        .foregroundStyle(theme.text(.textPrimary))
                    if showFree { freeBadge }
                }
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 11))
                                .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                            Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                                .foregroundStyle(theme.text(.textPrimary))
                        }
                    }
                    if let description {
                        Text(description).textStyle(.bodySm400).lineLimit(1)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.SpacingKey.base.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }

    private var freeBadge: some View {
        Text(freeLabel)
            .textStyle(.overline400)
            .foregroundStyle(theme.foreground(.fgSecondary))
            .padding(.vertical, 2).padding(.horizontal, Theme.SpacingKey.xs.value)
            .background(
                LinearGradient(colors: [SemanticColor.primary.base, SemanticColor.purple.base],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
            )
    }
}

// MARK: - FilterChip (square / pill)

public enum FilterChipShape { case pill, square }

/// A dismissible filter chip in a pill (with a soft shadow) or square shape.
/// (Reference FilterChip.)
public struct FilterChip: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let shape: FilterChipShape
    private let showsClose: Bool
    private let onDismiss: (() -> Void)?

    public init(_ title: String, shape: FilterChipShape = .pill, showsClose: Bool = true, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.shape = shape
        self.showsClose = showsClose
        self.onDismiss = onDismiss
    }

    private var clipShape: AnyShape {
        shape == .pill
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }

    public var body: some View {
        if shape == .pill {
            chipBody.themeShadow(.soft)
        } else {
            chipBody
        }
    }

    private var chipBody: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
            if showsClose {
                Button { onDismiss?() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite), in: clipShape)
        .overlay(clipShape.stroke(theme.border(.borderPrimary), lineWidth: 1))
    }
}

// MARK: - ChipGroup (multi-select)

/// A horizontally-scrolling, multi-select chip group backed by a `Set` binding.
public struct ChipGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let selectionStyle: ChipSelectionStyle
    private let label: (Option) -> String

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        selectionStyle: ChipSelectionStyle = .tonal,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.selectionStyle = selectionStyle
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ForEach(options, id: \.self) { option in
                        Chip(label(option),
                             isSelected: Binding(
                                get: { selection.contains(option) },
                                set: { isOn in if isOn { selection.insert(option) } else { selection.remove(option) } }
                             ),
                             selectionStyle: selectionStyle)
                    }
                }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var a = true; @State var b = false; @State var c = true
        @State var multi: Set<String> = ["Wifi"]
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        CompactChip(isSelected: $a, text: "Standard Room", price: "$399.90", rating: 4.6)
                        CompactChip(isSelected: $b, text: "Suite Room", price: "$899.90")
                    }
                    ChoseChip(isSelected: $c, title: "Flexible rate", description: "Free cancellation",
                              rating: 4.8, showFree: true, systemImage: "wind")
                    HStack {
                        FilterChip("Istanbul") {}
                        FilterChip("4+ stars", shape: .square) {}
                    }
                    ChipGroup(title: "Amenities", options: ["Wifi", "Pool", "Spa", "Parking"], selection: $multi) { $0 }
                }
                .padding()
            }
        }
    }
    return Demo()
}
