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
///
/// Chroma: while the environment carries the default ``ChipStyle`` the tile
/// draws its own rounded-rectangle selection border (pixel-identical to the
/// pre-ChipStyle look — the built-in styles draw capsules, not tiles). A style
/// set with `.chipStyle(_:)` takes over via `makeBody(configuration:)`; the
/// image tile is passed as the configuration's content.
public struct ImageChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.chipStyle) private var environmentChipStyle

    // Appearance — mutated only through the modifiers below (R2).
    private var size: ImageChipSize = .medium

    @Binding private var isSelected: Bool
    private let url: URL?

    public init(isSelected: Binding<Bool>, url: URL?) {   // R1
        self._isSelected = isSelected
        self.url = url
    }

    public var body: some View {
        chrome
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { isSelected.toggle() } }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Default environment style → today's own chroma; custom style → its
    /// `makeBody`. `ChipSize` mapping: the small tile reads as `.small`,
    /// medium/large tiles as `.large` (ImageChip has no `ChipSize` of its own).
    @ViewBuilder private var chrome: some View {
        if environmentChipStyle.isDefault {
            tile
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                                      lineWidth: isSelected ? 2 : 1)
                )
                .opacity(isEnabled ? 1 : 0.5)
        } else {
            environmentChipStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(tile),
                isSelected: isSelected,
                isEnabled: isEnabled,
                size: size == .small ? .small : .large))
        }
    }

    /// The chroma-free content: the remote image at the tile's aspect and size.
    private var tile: some View {
        let s = size.size
        return RemoteImage(url).ratio(s.width / s.height).cornerRadius(Theme.RadiusKey.sm.value)
            .frame(width: s.width, height: s.height)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ImageChip {
    /// Tile size: small / medium / large.
    func size(_ s: ImageChipSize) -> Self { copy { $0.size = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - CompactChip

/// A selectable card: an optional rating + label row, then an optional logo +
/// price row. (Reference CompactChip.)
///
/// Chroma: while the environment carries the default ``ChipStyle`` the card
/// draws its own rounded-rectangle fill + selection border (pixel-identical to
/// the pre-ChipStyle look — the built-in styles draw capsules, not cards). A
/// style set with `.chipStyle(_:)` takes over via `makeBody(configuration:)`.
public struct CompactChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.chipStyle) private var environmentChipStyle

    @Binding private var isSelected: Bool
    private let text: String
    private let price: String

    // Appearance — mutated only through the modifiers below (R2).
    private var imageURL: URL? = nil
    private var rating: Double? = nil

    public init(_ text: String, price: String, isSelected: Binding<Bool>) {   // R1
        self.text = text
        self.price = price
        self._isSelected = isSelected
    }

    public var body: some View {
        chrome
            .contentShape(Rectangle())
            .onTapGesture { isSelected.toggle() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Default environment style → today's own chroma; custom style → its
    /// `makeBody`. `ChipSize` mapping: the card's `md` padding + heading-sized
    /// price map to `.large` density (CompactChip has no `ChipSize` of its own).
    @ViewBuilder private var chrome: some View {
        if environmentChipStyle.isDefault {
            labelContent
                .foregroundStyle(theme.text(.textPrimary))
                .padding(Theme.SpacingKey.md.value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                                      lineWidth: isSelected ? 2 : 1)
                )
        } else {
            environmentChipStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(labelContent.frame(maxWidth: .infinity, alignment: .leading)),
                isSelected: isSelected,
                isEnabled: isEnabled,
                size: .large))
        }
    }

    /// The card's content (chroma-free): rating + label row, then logo + price
    /// row. Text color comes from the surrounding chroma; the rating star keeps
    /// its warning tint.
    private var labelContent: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                    }
                }
                Text(text).textStyle(.labelBase600).lineLimit(1)
            }
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let imageURL {
                    RemoteImage(imageURL).contentMode(.fit).frame(height: 16)
                }
                Text(price).textStyle(.headingSm)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CompactChip {
    /// Remote logo image shown next to the price.
    func imageURL(_ url: URL?) -> Self { copy { $0.imageURL = url } }

    /// Star rating shown before the label (nil hides it).
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - ChoseChip

/// A selectable card: a leading icon, a title with an optional "free" gradient
/// badge, and a rating + description row. (Reference ChoseChip.)
///
/// Chroma: while the environment carries the default ``ChipStyle`` the card
/// draws its own rounded-rectangle fill + selection border (pixel-identical to
/// the pre-ChipStyle look — the built-in styles draw capsules, not cards). A
/// style set with `.chipStyle(_:)` takes over via `makeBody(configuration:)`.
public struct ChoseChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.chipStyle) private var environmentChipStyle

    @Binding private var isSelected: Bool
    private let title: String

    // Appearance — mutated only through the modifiers below (R2).
    private var description: String? = nil
    private var rating: Double? = nil
    private var showFree: Bool = false
    private var freeLabel: String = String(themeKit: "Free")
    private var systemImage: String? = nil

    public init(_ title: String, isSelected: Binding<Bool>) {   // R1
        self.title = title
        self._isSelected = isSelected
    }

    public var body: some View {
        chrome
            .contentShape(Rectangle())
            .onTapGesture { isSelected.toggle() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Default environment style → today's own chroma; custom style → its
    /// `makeBody`. `ChipSize` mapping: the card's `base` padding + two-line
    /// layout map to `.large` density (ChoseChip has no `ChipSize` of its own).
    @ViewBuilder private var chrome: some View {
        if environmentChipStyle.isDefault {
            labelContent
                .foregroundStyle(theme.text(.textPrimary))
                .padding(Theme.SpacingKey.base.value)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                                      lineWidth: isSelected ? 2 : 1)
                )
        } else {
            environmentChipStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(labelContent),
                isSelected: isSelected,
                isEnabled: isEnabled,
                size: .large))
        }
    }

    /// The card's content (chroma-free): icon, title + optional badge, rating +
    /// description row. Title/rating color comes from the surrounding chroma;
    /// the icon, star, badge, and secondary description keep their own tokens.
    private var labelContent: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            if let systemImage {
                Icon(systemName: systemImage).size(.md).color(theme.foreground(.fgHero))
            }
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(title).textStyle(.labelMd600).lineLimit(1)
                    if showFree { freeBadge }
                }
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 11))
                                .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                            Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ChoseChip {
    /// Secondary line shown under the title.
    func description(_ text: String?) -> Self { copy { $0.description = text } }

    /// Star rating shown before the description (nil hides it).
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }

    /// Show the gradient "free" badge next to the title (optionally with a custom label).
    func free(_ on: Bool = true, label: String = String(themeKit: "Free")) -> Self {
        copy { $0.showFree = on; $0.freeLabel = label }
    }

    /// Leading SF Symbol shown before the texts.
    func icon(_ systemImage: String?) -> Self { copy { $0.systemImage = systemImage } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - FilterChip (square / pill)

public enum FilterChipShape { case pill, square }

/// A dismissible filter chip in a pill (with a soft shadow) or square shape.
/// (Reference FilterChip.)
///
/// Chroma: while the environment carries the default ``ChipStyle`` the chip
/// draws its own pill/square fill + border (pixel-identical to the
/// pre-ChipStyle look). A style set with `.chipStyle(_:)` takes over via
/// `makeBody(configuration:)`. The pill's soft shadow is elevation, not
/// chroma — it stays outside the style in both paths.
public struct FilterChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.chipStyle) private var environmentChipStyle

    private let title: String
    private let onDismiss: (() -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var shape: FilterChipShape = .pill
    private var showsClose: Bool = true

    public init(_ title: String, onDismiss: (() -> Void)? = nil) {   // R1
        self.title = title
        self.onDismiss = onDismiss
    }

    private var clipShape: AnyShape {
        shape == .pill
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }

    public var body: some View {
        if shape == .pill {
            chrome.themeShadow(.soft)
        } else {
            chrome
        }
    }

    /// Default environment style → today's own chroma; custom style → its
    /// `makeBody`. `ChipSize` mapping: the compact label + `sm` vertical
    /// padding map to `.small` density (FilterChip has no `ChipSize` of its
    /// own). FilterChip has no selection state, so the configuration's
    /// `isSelected` is always `false`.
    @ViewBuilder private var chrome: some View {
        if environmentChipStyle.isDefault {
            labelContent
                .foregroundStyle(theme.text(.textPrimary))
                .padding(.vertical, Theme.SpacingKey.sm.value)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .background(theme.background(.bgWhite), in: clipShape)
                .overlay(clipShape.stroke(theme.border(.borderPrimary), lineWidth: 1))
        } else {
            environmentChipStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(labelContent),
                isSelected: false,
                isEnabled: isEnabled,
                size: .small))
        }
    }

    /// The chip's content (chroma-free): title + optional close button. Title
    /// color comes from the surrounding chroma; the close glyph keeps its
    /// tertiary token.
    private var labelContent: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Text(title).textStyle(.labelSm600)
            if showsClose {
                Button { onDismiss?() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Remove"))
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterChip {
    /// Chip shape: pill (with a soft shadow) or square.
    func shape(_ shape: FilterChipShape) -> Self { copy { $0.shape = shape } }

    /// Whether to show the trailing close button (default true).
    func closable(_ on: Bool = true) -> Self { copy { $0.showsClose = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - ChipGroup (multi-select)

/// A horizontally-scrolling, multi-select chip group backed by a `Set` binding.
public struct ChipGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var selectionStyle: ChipSelectionStyle = .tonal
    private var isOptionEnabled: ((Option) -> Bool)?
    private var onRemove: ((Option) -> Void)?
    private var infoMessages: [InfoMessage] = []
    private var emptyContent: AnyView? = nil

    public init(   // R1
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
    }

    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    /// The most severe message tints the group title (RadioGroup convention).
    private var titleColor: Color {
        switch infoMessages.dominantKind {
        case .error: return theme.foreground(.systemcolorsFgError)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        default: return theme.text(.textPrimary)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(titleColor)
            }
            if options.isEmpty, let emptyContent {
                emptyContent
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ForEach(options, id: \.self) { option in
                            let enabled = optionEnabled(option)
                            chip(for: option)
                                .disabled(!enabled)
                                .opacity(enabled ? 1 : 0.4)
                        }
                    }
                }
            }
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages)
            }
        }
        // Animate message rows in/out (their `.transition` lives in
        // `InfoMessageList`); gated by `microAnimations` + Reduce Motion.
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: infoMessages)
    }

    /// One selectable chip; `removable` appends a trailing remove affordance
    /// via `Chip`'s trailing slot (HeroUI TagGroup.ItemRemoveButton parity).
    @ViewBuilder private func chip(for option: Option) -> some View {
        let base = Chip(label(option),
                        isSelected: Binding(
                           get: { selection.contains(option) },
                           set: { isOn in if isOn { selection.insert(option) } else { selection.remove(option) } }
                        ))
            .chipStyle(selectionStyle)
        if let onRemove {
            base.trailing {
                Button { onRemove(option) } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Remove \(label(option))"))
            }
        } else {
            base
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ChipGroup {
    /// Visual style applied to every chip (matches `Chip.chipStyle`).
    func chipStyle(_ style: ChipSelectionStyle) -> Self { copy { $0.selectionStyle = style } }

    /// Per-option enablement predicate (nil enables every option).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Appends a trailing remove button to every chip; the callback receives
    /// the option to remove (HeroUI TagGroup `onRemove`). The caller owns the
    /// options array, so removal mutates it there.
    func removable(_ onRemove: @escaping (Option) -> Void) -> Self { copy { $0.onRemove = onRemove } }

    /// Validation / info messages rendered under the chips (drive the title color).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Custom view shown instead of the chip row while `options` is empty
    /// (HeroUI TagGroup `renderEmptyState`).
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        let view = AnyView(content())
        return copy { $0.emptyContent = view }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var a = true; @State var b = false; @State var c = true
        @State var multi: Set<String> = ["Wifi"]
        @State var removableOptions = ["Wifi", "Pool", "Spa"]
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        CompactChip("Standard Room", price: "$399.90", isSelected: $a).rating(4.6)
                        CompactChip("Suite Room", price: "$899.90", isSelected: $b)
                    }
                    ChoseChip("Flexible rate", isSelected: $c)
                        .description("Free cancellation").rating(4.8).free().icon("wind")
                    HStack {
                        FilterChip("Istanbul") {}
                        FilterChip("4+ stars") {}.shape(.square)
                    }
                    ChipGroup(title: "Amenities", options: ["Wifi", "Pool", "Spa", "Parking"], selection: $multi) { $0 }
                    // Per-option disabled: "Spa" renders dimmed + non-interactive.
                    ChipGroup(title: "Per-option disabled", options: ["Wifi", "Pool", "Spa", "Parking"], selection: $multi) { $0 }
                        .optionEnabled { $0 != "Spa" }
                    // Removable: every chip gets a trailing xmark that mutates the caller's array.
                    ChipGroup(title: "Removable", options: removableOptions, selection: $multi) { $0 }
                        .removable { option in removableOptions.removeAll { $0 == option } }
                    // Invalid state: messages under the chips + error-tinted title.
                    ChipGroup(title: "With error", options: ["Wifi", "Pool"], selection: $multi) { $0 }
                        .infoMessages([InfoMessage("Pick at least one amenity", kind: .error)])
                    // Empty state: custom placeholder while the options collection is empty.
                    ChipGroup(title: "Empty", options: [String](), selection: $multi) { $0 }
                        .emptyContent { Text("No amenities available").textStyle(.bodySm400) }
                    // Custom ChipStyle via the environment: `.chipStyle(.solid)`
                    // on the container is non-default, so these molecules route
                    // through `SolidChipStyle.makeBody` (capsule chroma) instead
                    // of their own default rounded-rectangle chroma.
                    VStack(alignment: .leading, spacing: 12) {
                        CompactChip("Solid style", price: "$120.00", isSelected: $a).rating(4.2)
                        ChoseChip("Solid style", isSelected: $c).description("Custom chroma")
                        HStack {
                            FilterChip("Solid") {}
                            ImageChip(isSelected: $a, url: nil).size(.small)
                        }
                    }
                    .chipStyle(.solid)
                }
                .padding()
            }
        }
    }
    return Demo()
}
