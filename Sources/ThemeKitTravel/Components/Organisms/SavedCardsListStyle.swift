//
//  SavedCardsListStyle.swift
//  ThemeKitTravel
//
//  The styling hook for ``SavedCardsList`` (ADR-0004, Wave 3, Class A) — the
//  configuration hands styles the *typed* card data (cards, selection, delete /
//  add-new actions, expiry + brand chrome), not pre-laid content, so a style
//  owns the whole arrangement. Four built-ins:
//
//    .list    radio rows over `ListRow` — today's default look.
//    .wallet  a horizontal carousel of bank-card-face tiles (today's `.wallet`
//             variant, verbatim).
//    .stack   an overlapping pass-book fan that spreads into a vertical list on
//             tap — the Apple Wallet card-stack pattern.
//    .grid    a non-scrolling grid of card-face tiles (2 columns, with a
//             vertical fallback at accessibility Dynamic Type sizes).
//
//      SavedCardsList(cards, selection: $cardID)
//          .onDelete { wallet.remove($0) }
//          .savedCardsListStyle(.stack)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything. There is no `CardStyle` shell delegation here —
//  unlike the card-shaped Class A styles, ``SavedCardsList`` never routed
//  through `\.cardStyle`; the tile-shaped presets (`.wallet`/`.stack`/`.grid`)
//  draw their own bank-card silhouette so a caller can theme it without also
//  opting into the neutral `Card` chrome. The component resolves MicroMotion /
//  Reduce Motion before calling a style — styles read
//  ``SavedCardsListConfiguration/isMotionEnabled``, never the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``SavedCardsListStyle`` lays out. Fields a given preset
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no `onDelete` → no delete affordance anywhere, no
/// `onAddNew` → no add-new row/tile).
public struct SavedCardsListConfiguration {
    /// The stored cards to render, in caller order. Never empty — the
    /// component renders its own `EmptyState` before reaching a style.
    public let cards: [SavedCard]
    /// The id of the currently selected card, or `nil` when none is selected.
    public let selectedID: String?
    /// Selects a card by id. Already read-only gated by the component — styles
    /// call it directly, no `@Environment(\.isReadOnly)` check needed.
    public let onSelect: (String) -> Void
    /// Removes a card; `nil` hides every delete affordance. Already read-only
    /// gated by the component.
    public let onDelete: ((SavedCard) -> Void)?
    /// The add-new-card action; `nil` hides the affordance. NOT pre-gated —
    /// presets guard it with `@Environment(\.isReadOnly)` themselves, matching
    /// the component's own empty-state primary action.
    public let onAddNew: (() -> Void)?
    /// Localized label for the add-new affordance — already resolved with the
    /// caller's override or the default "Add new card".
    public let addNewTitle: String
    /// Whether expired cards (`SavedCard.isExpired`) auto-disable and carry the
    /// expired badge. Set by ``SavedCardsList/flagsExpired(_:)``.
    public let flagsExpired: Bool
    /// Replacement for the stock brand symbol, built per ``CardBrand``; `nil`
    /// uses the built-in `Icon`.
    public let brandLogo: ((CardBrand) -> AnyView)?
    /// Whether the expired badge renders at all (`false` when the caller passed
    /// an explicit `nil` text to ``SavedCardsList/expiredBadge(_:style:)``).
    public let showsExpiredBadge: Bool
    /// Custom expired-badge text; `nil` uses the localized "Expired" — resolve
    /// with ``expiredBadgeLabel()``.
    public let expiredBadgeText: String?
    /// The expired badge's semantic style (default `.error`).
    public let expiredBadgeStyle: BadgeStyle
    /// Whether row-shaped presets draw hairline dividers between cards.
    public let showsDividers: Bool
    /// Which delete affordances render once ``onDelete`` is set.
    public let deleteStyle: DeleteAffordance
    /// Replacement for the built-in row/tile anatomy, built per
    /// `(card, isSelected)`; `nil` uses the preset's own anatomy.
    public let rowContent: ((SavedCard, Bool) -> AnyView)?
    /// Semantic tint for the radio / brand glyph / add-new chrome; `nil` uses
    /// the theme's primary triad.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the preset choose its own default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — every date/number
    /// string (expiry, spoken digits) honors it.
    public let locale: Locale
    /// The environment calendar, captured by the component — used for the
    /// expiry math and the formatted expiry string.
    public let calendar: Calendar
    /// Micro-animations resolved by the component (`microAnimations` ∧ ¬Reduce
    /// Motion) — gate fan/expand transitions on this; never read the motion
    /// environment directly.
    public let isMotionEnabled: Bool

    /// Whether `card` is the current selection.
    public func isSelected(_ card: SavedCard) -> Bool { selectedID == card.id }
    /// Whether `card` reads as expired for this configuration
    /// (``flagsExpired`` ∧ `SavedCard.isExpired`, using the captured calendar).
    public func isExpired(_ card: SavedCard) -> Bool {
        flagsExpired && card.isExpired(calendar: calendar)
    }
    /// The explicit `surface(_:)` override, or the preset's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }
    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out a preset.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
    /// The `accent(_:)` override's base, else the theme's primary triad — the
    /// value the built-ins hardcoded before the accent axis existed.
    public func accentBase(_ theme: Theme) -> Color { (accent ?? .primary).base }
    /// The expired badge's resolved text.
    public func expiredBadgeLabel() -> String { expiredBadgeText ?? String(themeKitTravel: "Expired") }

    /// Whether a trailing delete button renders. Row-shaped presets only —
    /// tile-shaped presets are a single whole-tile `Button`, so a nested
    /// trailing button would fight the tap gesture; they stay context-menu-only.
    public var showsDeleteButton: Bool {
        onDelete != nil && (deleteStyle == .button || deleteStyle == .both)
    }
    /// Whether the destructive context-menu entry renders.
    public var showsDeleteMenu: Bool {
        onDelete != nil && (deleteStyle == .contextMenu || deleteStyle == .both)
    }

    /// Radio-style binding for one card: setting `true` selects it through
    /// ``onSelect``; a card can't be deselected by tapping its own radio.
    public func selectionBinding(for card: SavedCard) -> Binding<Bool> {
        Binding(get: { isSelected(card) }, set: { if $0 { onSelect(card.id) } })
    }

    // Shared formatting, so every preset speaks one language.

    /// "Visa •••• 4242"; brand-less cards render just the masked digits.
    public func title(for card: SavedCard) -> String {
        let masked = "•••• \(card.last4)"
        let brand = card.brand.label
        return brand.isEmpty ? masked : "\(brand) \(masked)"
    }
    /// "Alex Morgan · Expires 08/28" — either part optional.
    public func subtitle(for card: SavedCard) -> String? {
        var parts: [String] = []
        if let holder = card.holder, !holder.isEmpty { parts.append(holder) }
        if let expiry = expiryText(for: card) { parts.append(expiry) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    /// "Expires 08/28", formatted with the captured locale + calendar.
    public func expiryText(for card: SavedCard) -> String? {
        guard let month = card.expiryMonth, let year = card.expiryYear else { return nil }
        var components = DateComponents()
        components.year = year < 100 ? year + 2000 : year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else { return nil }
        let formatted = date.formatted(
            Date.FormatStyle(calendar: calendar).month(.twoDigits).year(.twoDigits).locale(locale)
        )
        return String(themeKitTravel: "Expires \(formatted)")
    }
    /// "Visa card ending 4 2 4 2, Alex Morgan, Expires 08/28[, Expired]".
    public func accessibilityLabel(for card: SavedCard) -> String {
        var parts: [String] = [
            card.brand.label.isEmpty
                ? String(themeKitTravel: "Card ending \(spacedDigits(card.last4))")
                : String(themeKitTravel: "\(card.brand.label) card ending \(spacedDigits(card.last4))"),
        ]
        if let holder = card.holder, !holder.isEmpty { parts.append(holder) }
        if let expiry = expiryText(for: card) { parts.append(expiry) }
        if isExpired(card) { parts.append(String(themeKitTravel: "Expired")) }
        return parts.joined(separator: ", ")
    }
    /// Digits read out one by one: "4242" → "4 2 4 2".
    public func spacedDigits(_ digits: String) -> String {
        digits.map(String.init).joined(separator: " ")
    }
}

// MARK: - Protocol

/// Defines a `SavedCardsList`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's card data. Set one with `.savedCardsListStyle(_:)`;
/// the default is ``ListSavedCardsListStyle``.
public protocol SavedCardsListStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SavedCardsListConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The brand mark: the caller's `.brandLogo` slot or the stock symbol. Shared
/// by every preset.
private struct SavedCardBrandGlyph: View {
    @Environment(\.theme) private var theme
    let configuration: SavedCardsListConfiguration
    let card: SavedCard
    let isOn: Bool

    var body: some View {
        if let brandLogo = configuration.brandLogo {
            brandLogo(card.brand)
        } else {
            Icon(systemName: card.brand.icon)
                .size(.sm)
                .color(isOn ? configuration.accentBase(theme) : theme.text(.textSecondary))
        }
    }
}

/// The "Expired" badge, shared by every preset.
private struct SavedCardExpiredBadge: View {
    let configuration: SavedCardsListConfiguration
    let card: SavedCard

    var body: some View {
        if configuration.isExpired(card), configuration.showsExpiredBadge {
            Badge(configuration.expiredBadgeLabel())
                .badgeStyle(configuration.expiredBadgeStyle).variant(.soft).size(.small)
        }
    }
}

/// The trailing trash button — row-shaped presets only. See
/// ``SavedCardsListConfiguration/showsDeleteButton``.
private struct SavedCardDeleteButton: View {
    @Environment(\.theme) private var theme
    let configuration: SavedCardsListConfiguration
    let card: SavedCard

    var body: some View {
        Button {
            configuration.onDelete?(card)
        } label: {
            Icon(systemName: "trash")
                .size(.sm)
                .color(theme.foreground(.systemcolorsFgError))
                .frame(width: 44, height: 44)   // a11y hit target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKitTravel: "Remove card ending \(configuration.spacedDigits(card.last4))"))
    }
}

/// Destructive context-menu entry, shared by every preset. Hidden (not merely
/// disabled) while read-only, matching the component's pre-style behavior.
private struct SavedCardDeleteMenu: View {
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: SavedCardsListConfiguration
    let card: SavedCard

    var body: some View {
        if configuration.showsDeleteMenu, !isReadOnly {
            Button(role: .destructive) { configuration.onDelete?(card) } label: {
                Label(String(themeKitTravel: "Remove card"), systemImage: "trash")
            }
        }
    }
}

/// The "card face" tile anatomy shared by every tile-shaped preset — a bank
/// card silhouette: brand glyph + expired badge up top, masked digits mid,
/// holder/expiry line at the bottom.
private struct SavedCardFaceTile: View {
    @Environment(\.theme) private var theme
    let configuration: SavedCardsListConfiguration
    let card: SavedCard
    let isOn: Bool

    var body: some View {
        let isExpiredCard = configuration.isExpired(card)
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack {
                SavedCardBrandGlyph(configuration: configuration, card: card, isOn: isOn)
                Spacer(minLength: Theme.SpacingKey.xs.value)
                SavedCardExpiredBadge(configuration: configuration, card: card)
            }
            Spacer(minLength: 0)
            Text("•••• \(card.last4)")
                .textStyle(.labelLg600)
                .foregroundStyle(isExpiredCard ? theme.text(.textDisabled) : theme.text(.textPrimary))
            if let line = configuration.subtitle(for: card) {
                Text(line)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .lineLimit(1)
            }
        }
        .padding(Theme.SpacingKey.md.value)
    }
}

/// Fixed frame when `width` is given (the wallet carousel); otherwise fills the
/// parent's width at a fixed height (grid cells / the expanded stack).
private extension View {
    @ViewBuilder
    func tileFrame(width: CGFloat?, height: CGFloat) -> some View {
        if let width {
            frame(width: width, height: height)
        } else {
            frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }

    /// Shared tile chrome: surface fill, selection stroke, lift shadow — every
    /// tile-shaped preset draws the same bank-card shell.
    func savedCardTileChrome(_ configuration: SavedCardsListConfiguration, isOn: Bool) -> some View {
        modifier(SavedCardTileChromeModifier(configuration: configuration, isOn: isOn))
    }
}

private struct SavedCardTileChromeModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let configuration: SavedCardsListConfiguration
    let isOn: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        content
            .background(theme.background(configuration.surface(default: .bgWhite)), in: shape)
            .overlay(shape.strokeBorder(isOn ? configuration.accentBase(theme) : theme.border(.borderPrimary),
                                        lineWidth: isOn ? 2 : 1))
            .themeShadow(isOn ? .elevated : .soft)
            .contentShape(shape)
    }
}

/// One selectable card-face tile — the whole tile is a `Button`, so its delete
/// affordance is context-menu-only (see
/// ``SavedCardsListConfiguration/showsDeleteButton``'s doc). Shared by
/// `.wallet`, `.grid` and `.stack`'s expanded spread.
private struct SavedCardTile: View {
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: SavedCardsListConfiguration
    let card: SavedCard
    var width: CGFloat?
    var height: CGFloat

    var body: some View {
        let isOn = configuration.isSelected(card)
        let isExpiredRow = configuration.isExpired(card)
        Button { configuration.onSelect(card.id) } label: {
            Group {
                if let rowContent = configuration.rowContent {
                    rowContent(card, isOn)
                } else {
                    SavedCardFaceTile(configuration: configuration, card: card, isOn: isOn)
                }
            }
            .tileFrame(width: width, height: height)
            .savedCardTileChrome(configuration, isOn: isOn)
        }
        .buttonStyle(.plain)
        .disabled(isExpiredRow)
        .allowsHitTesting(!isReadOnly)
        .contextMenu { SavedCardDeleteMenu(configuration: configuration, card: card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityLabel(for: card))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// The dashed "Add new card" tile — shared by `.wallet`, `.grid` and `.stack`.
private struct SavedCardAddNewTile: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: SavedCardsListConfiguration
    var width: CGFloat?
    var height: CGFloat
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        Button {
            guard !isReadOnly else { return }
            action()
        } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: "plus.circle.fill").size(.md).color(configuration.accentBase(theme))
                Text(configuration.addNewTitle)
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            .tileFrame(width: width, height: height)
            .background(theme.background(configuration.surface(default: .bgWhite)), in: shape)
            .overlay(shape.strokeBorder(theme.border(.borderPrimary),
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

/// The trailing "Add new card" `ListRow` — row-shaped presets.
private struct SavedCardAddNewRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: SavedCardsListConfiguration

    var body: some View {
        ListRow(configuration.addNewTitle) {
            guard !isReadOnly else { return }
            configuration.onAddNew?()
        }
        .leading {
            Icon(systemName: "plus.circle.fill").size(.sm).color(configuration.accentBase(theme))
        }
        .trailing(ListRowTrailing.chevron)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - .list

/// Today's ``SavedCardsList`` look, extracted verbatim: `ListRow` radio rows —
/// leading `RadioButton` + brand glyph, masked title + holder/expiry subtitle,
/// trailing expired badge and/or delete button, hairline dividers, an optional
/// "Add new card" row. Default.
public struct ListSavedCardsListStyle: SavedCardsListStyle {
    public init() {}
    public func makeBody(configuration: SavedCardsListConfiguration) -> some View {
        ListSavedCardsListChrome(configuration: configuration)
    }
}

private struct ListSavedCardsListChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: SavedCardsListConfiguration

    private var showsAddNewRow: Bool { configuration.onAddNew != nil }

    var body: some View {
        let stack = VStack(spacing: 0) {
            ForEach(configuration.cards) { card in
                row(card)
                if configuration.showsDividers, card.id != configuration.cards.last?.id || showsAddNewRow {
                    DividerView().size(.small)
                }
            }
            if showsAddNewRow {
                SavedCardAddNewRow(configuration: configuration)
            }
        }
        if let surfaceKey = configuration.surfaceKey {
            stack.background(theme.background(surfaceKey))
        } else {
            stack
        }
    }

    @MainActor
    @ViewBuilder
    private func row(_ card: SavedCard) -> some View {
        let isOn = configuration.isSelected(card)
        let isExpiredRow = configuration.isExpired(card)
        Group {
            if let rowContent = configuration.rowContent {
                // `.rowContent` slot: caller anatomy inside the selection
                // button; auto-disable, context menu and VoiceOver preserved.
                Button { configuration.onSelect(card.id) } label: {
                    rowContent(card, isOn).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isReadOnly)
            } else {
                builtInRow(card, isOn: isOn, isExpiredRow: isExpiredRow)
            }
        }
        .disabled(isExpiredRow)
        .contextMenu { SavedCardDeleteMenu(configuration: configuration, card: card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityLabel(for: card))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @MainActor
    private func builtInRow(_ card: SavedCard, isOn: Bool, isExpiredRow: Bool) -> some View {
        var listRow = ListRow(configuration.title(for: card)) { configuration.onSelect(card.id) }
            .subtitle(configuration.subtitle(for: card))
            .leading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    RadioButton(isSelected: configuration.selectionBinding(for: card)).accent(configuration.accent)
                    SavedCardBrandGlyph(configuration: configuration, card: card, isOn: isOn)
                }
            }
            .selected(isOn)
            .trailing(ListRowTrailing.none)
        if (isExpiredRow && configuration.showsExpiredBadge) || configuration.showsDeleteButton {
            listRow = listRow.trailing { trailingAccessories(for: card) }
        }
        return listRow
    }

    /// Expired badge and/or the explicit delete affordance, trailing-aligned.
    @MainActor
    @ViewBuilder
    private func trailingAccessories(for card: SavedCard) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            SavedCardExpiredBadge(configuration: configuration, card: card)
            if configuration.showsDeleteButton {
                SavedCardDeleteButton(configuration: configuration, card: card)
            }
        }
    }
}

// MARK: - .wallet

/// Today's `.wallet` variant, extracted verbatim: a horizontal
/// `ScrollView` of bank-card-face tiles — lift shadow + accent stroke on
/// selection, an optional dashed "Add new card" tile trailing the carousel.
/// Delete is context-menu-only (the whole tile is one `Button`).
public struct WalletSavedCardsListStyle: SavedCardsListStyle {
    public init() {}
    public func makeBody(configuration: SavedCardsListConfiguration) -> some View {
        WalletSavedCardsListChrome(configuration: configuration)
    }
}

private enum TileMetrics {
    // Genuine dimensions with no semantic token — the ~1.586 bank-card aspect,
    // sized for a phone-width carousel / grid cell.
    static let width: CGFloat = 200
    static let height: CGFloat = 126
}

private struct WalletSavedCardsListChrome: View {
    let configuration: SavedCardsListConfiguration

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(configuration.cards) { card in
                    SavedCardTile(configuration: configuration, card: card,
                                  width: TileMetrics.width, height: TileMetrics.height)
                }
                if let onAddNew = configuration.onAddNew {
                    SavedCardAddNewTile(configuration: configuration,
                                        width: TileMetrics.width, height: TileMetrics.height, action: onAddNew)
                }
            }
            .padding(.vertical, Theme.SpacingKey.xs.value)   // room for the lift shadow
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - .stack (new)

/// An overlapping pass-book fan — the Apple Wallet card-stack pattern. Tap the
/// collapsed fan to spread every card into a vertical list; tap a card there to
/// select it, or collapse back with the chevron. A single card behaves like a
/// plain tile (tap selects it directly — nothing to spread into).
public struct StackSavedCardsListStyle: SavedCardsListStyle {
    public init() {}
    public func makeBody(configuration: SavedCardsListConfiguration) -> some View {
        StackSavedCardsListChrome(configuration: configuration)
    }
}

private enum StackMetrics {
    // Genuine dimensions with no semantic token — the pass-book fan geometry.
    static let width: CGFloat = 280
    static let height: CGFloat = 168
    static let peekOffset: CGFloat = 30
    static let maxPeek = 3           // cards drawn behind the front card while collapsed
    static let depthScaleStep: CGFloat = 0.04
}

private struct StackSavedCardsListChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SavedCardsListConfiguration
    @State private var isExpanded = false

    private var motionAnimation: Animation? {
        configuration.isMotionEnabled ? Motion.base.spring : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if isExpanded {
                expandedStack
            } else {
                collapsedStack
            }
        }
        .animation(motionAnimation, value: isExpanded)
    }

    // MARK: Collapsed — overlapping peek fan, tap to spread

    private var collapsedStack: some View {
        let peekCount = min(configuration.cards.count - 1, StackMetrics.maxPeek)
        let height = StackMetrics.height + CGFloat(peekCount) * StackMetrics.peekOffset
        return Button {
            if configuration.cards.count > 1 {
                isExpanded = true
            } else if let only = configuration.cards.first {
                configuration.onSelect(only.id)
            }
        } label: {
            ZStack(alignment: .top) {
                ForEach(Array(configuration.cards.prefix(peekCount + 1).enumerated()).reversed(),
                        id: \.element.id) { depth, card in
                    peekFace(card, depth: depth)
                        .offset(y: CGFloat(depth) * StackMetrics.peekOffset)
                }
            }
            .frame(width: StackMetrics.width, height: height, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(collapsedAccessibilityLabel)
        .accessibilityHint(configuration.cards.count > 1
            ? String(themeKitTravel: "Shows every card in the stack") : "")
        .accessibilityAddTraits(.isButton)
    }

    private var collapsedAccessibilityLabel: String {
        if configuration.cards.count == 1, let only = configuration.cards.first {
            return configuration.accessibilityLabel(for: only)
        }
        return String(themeKitTravel: "Saved cards, \(configuration.cards.count) cards, collapsed")
    }

    private func peekFace(_ card: SavedCard, depth: Int) -> some View {
        let scale = 1 - CGFloat(depth) * StackMetrics.depthScaleStep
        let isOn = configuration.isSelected(card)
        return Group {
            if let rowContent = configuration.rowContent {
                rowContent(card, isOn)
            } else {
                SavedCardFaceTile(configuration: configuration, card: card, isOn: isOn)
            }
        }
        .frame(width: StackMetrics.width, height: StackMetrics.height)
        .savedCardTileChrome(configuration, isOn: isOn)
        .scaleEffect(scale, anchor: .top)
        .accessibilityHidden(true)   // the collapsed button carries one summary label
    }

    // MARK: Expanded — vertical spread; tap a card to select it

    private var expandedStack: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            collapseButton
            ForEach(configuration.cards) { card in
                SavedCardTile(configuration: configuration, card: card, width: nil, height: StackMetrics.height)
            }
            if let onAddNew = configuration.onAddNew {
                SavedCardAddNewTile(configuration: configuration, width: nil, height: StackMetrics.height,
                                    action: onAddNew)
            }
        }
    }

    private var collapseButton: some View {
        Button {
            isExpanded = false
        } label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: "chevron.up").size(.xs).color(theme.text(.textSecondary))
                Text(String(themeKitTravel: "Collapse"))
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textSecondary))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKitTravel: "Collapse saved cards stack"))
    }
}

// MARK: - .grid (new)

/// A non-scrolling grid of bank-card-face tiles (2 columns), with a vertical
/// single-column fallback at accessibility Dynamic Type sizes — mirrors
/// `PaymentMethodSelector`'s `.grid` a11y behavior. Delete is context-menu-only
/// (the whole tile is one `Button`).
public struct GridSavedCardsListStyle: SavedCardsListStyle {
    public init() {}
    public func makeBody(configuration: SavedCardsListConfiguration) -> some View {
        GridSavedCardsListChrome(configuration: configuration)
    }
}

private struct GridSavedCardsListChrome: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let configuration: SavedCardsListConfiguration

    private static let columnCount = 2

    var body: some View {
        let gap = configuration.spacing(.sm)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: gap) { tiles }
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: Self.columnCount),
                spacing: gap
            ) { tiles }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        ForEach(configuration.cards) { card in
            SavedCardTile(configuration: configuration, card: card, width: nil, height: TileMetrics.height)
        }
        if let onAddNew = configuration.onAddNew {
            SavedCardAddNewTile(configuration: configuration, width: nil, height: TileMetrics.height,
                                action: onAddNew)
        }
    }
}

// MARK: - Static accessors

public extension SavedCardsListStyle where Self == ListSavedCardsListStyle {
    /// `ListRow` radio rows — today's card list. The default.
    static var list: ListSavedCardsListStyle { ListSavedCardsListStyle() }
}
public extension SavedCardsListStyle where Self == WalletSavedCardsListStyle {
    /// A horizontal carousel of bank-card-face tiles.
    static var wallet: WalletSavedCardsListStyle { WalletSavedCardsListStyle() }
}
public extension SavedCardsListStyle where Self == StackSavedCardsListStyle {
    /// An overlapping pass-book fan that spreads into a vertical list on tap.
    static var stack: StackSavedCardsListStyle { StackSavedCardsListStyle() }
}
public extension SavedCardsListStyle where Self == GridSavedCardsListStyle {
    /// A non-scrolling 2-column grid of bank-card-face tiles.
    static var grid: GridSavedCardsListStyle { GridSavedCardsListStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySavedCardsListStyle: SavedCardsListStyle {
    private let _makeBody: @MainActor (SavedCardsListConfiguration) -> AnyView
    init<S: SavedCardsListStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SavedCardsListConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SavedCardsListStyleKey: EnvironmentKey {
    static let defaultValue = AnySavedCardsListStyle(ListSavedCardsListStyle())
}

extension EnvironmentValues {
    var savedCardsListStyle: AnySavedCardsListStyle {
        get { self[SavedCardsListStyleKey.self] }
        set { self[SavedCardsListStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SavedCardsListStyle`` for `SavedCardsList`s in this view and
    /// its descendants — one screen can mix archetypes per section.
    func savedCardsListStyle<S: SavedCardsListStyle>(_ style: sending S) -> some View {
        environment(\.savedCardsListStyle, AnySavedCardsListStyle(style))
    }
}

// MARK: - Previews

/// Proves external implementability: a plain badge-row list built purely from
/// the public configuration + theme tokens — no ThemeKit-internal APIs beyond
/// what any app target could reach.
private struct BadgeRowSavedCardsListStyle: SavedCardsListStyle {
    func makeBody(configuration: SavedCardsListConfiguration) -> some View {
        BadgeRowChrome(configuration: configuration)
    }

    private struct BadgeRowChrome: View {
        @Environment(\.theme) private var theme
        let configuration: SavedCardsListConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                ForEach(configuration.cards) { card in
                    Button { configuration.onSelect(card.id) } label: {
                        HStack(spacing: configuration.spacing(.sm)) {
                            Badge(card.brand.label.isEmpty ? "Card" : card.brand.label)
                                .badgeStyle(configuration.isSelected(card) ? .success : .info)
                                .size(.small)
                            Text(configuration.title(for: card))
                                .textStyle(.labelBase600)
                                .foregroundStyle(theme.text(.textPrimary))
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("SavedCardsListStyle — presets × light/dark") {
    struct Demo: View {
        @State private var cardID: String? = "visa"
        let cards = [
            SavedCard(id: "visa", brand: .visa, last4: "4242",
                      holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
            SavedCard(id: "mc", brand: .mastercard, last4: "4444",
                      holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
            SavedCard(id: "old", brand: .amex, last4: "0005",
                      holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
        ]

        var body: some View {
            PreviewMatrix("SavedCardsListStyle") {
                PreviewCase("List (default)") {
                    SavedCardsList(cards, selection: $cardID).onDelete { _ in }.onAddNew { }
                }
                PreviewCase("Wallet") {
                    SavedCardsList(cards, selection: $cardID)
                        .onDelete { _ in }.onAddNew { }
                        .savedCardsListStyle(.wallet)
                }
                PreviewCase("Stack") {
                    SavedCardsList(cards, selection: $cardID)
                        .onDelete { _ in }.onAddNew { }
                        .savedCardsListStyle(.stack)
                }
                PreviewCase("Grid") {
                    SavedCardsList(cards, selection: $cardID)
                        .onDelete { _ in }.onAddNew { }
                        .savedCardsListStyle(.grid)
                        .frame(width: 320)
                }
                PreviewCase("Custom (in-preview)") {
                    SavedCardsList(cards, selection: $cardID)
                        .savedCardsListStyle(BadgeRowSavedCardsListStyle())
                }
            }
        }
    }
    return Demo()
}
