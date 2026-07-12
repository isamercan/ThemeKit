//
//  SavedCardsList.swift
//  ThemeKitTravel
//
//  Edition organism (F3.1 · ADR §9.10). Stored payment cards — brand glyph,
//  •••• last4, holder, expiry and an expired flag — with radio-semantic
//  single-select plus delete / add-new affordances. Composes ThemeKit's
//  neutral `ListRow` anatomy, `RadioButton`, `Badge`, `Icon`, `DividerView`
//  and `EmptyState` — nothing is re-implemented here. Presentation is
//  style-driven (``SavedCardsListStyle``, ADR-0004) — set once per screen via
//  `.savedCardsListStyle(_:)`: `.list` (default, radio rows) / `.wallet`
//  (card-face carousel) / `.stack` (Apple-Wallet fan) / `.grid` (tile grid).
//
//  State follows ADR-F4: controlled-first (`selection: Binding<String?>`) plus
//  an uncontrolled preview convenience (`initiallySelected:`), both funneled
//  through `ControllableState`. Expiry renders from `SavedCard`'s month/year
//  ints with the environment locale; expired cards (per `SavedCard.isExpired`)
//  carry an "Expired" badge and auto-disable while `flagsExpired` is on.
//
//  ```swift
//  SavedCardsList(cards, selection: $cardID)
//      .onDelete { wallet.remove($0) }
//      .onAddNew { showAddCardSheet = true }
//      .savedCardsListStyle(.stack)
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``SavedCardsList``: radio rows (`.list`, default) or
/// a horizontal carousel of card-face tiles (`.wallet`).
///
/// Superseded by ``SavedCardsListStyle`` (each case maps 1:1 to a preset,
/// which also adds `.stack` and `.grid`); kept for source compatibility until
/// the next major, together with the deprecated ``SavedCardsList/variant(_:)``
/// modifier.
public enum SavedCardsVariant: Sendable { case list, wallet }

/// How the delete affordance surfaces: a trailing button (`.button`), a
/// destructive context-menu entry (`.contextMenu`), or both (default).
public enum DeleteAffordance: Sendable { case button, contextMenu, both }

/// A stored-cards chooser — radio-semantic rows over ``SavedCard`` values with
/// optional delete and add-new affordances. Pairs with `PaymentMethodSelector`:
/// apps typically render it when the `card` method is chosen.
public struct SavedCardsList: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.componentDensity) private var density
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.savedCardsListStyle) private var envStyle

    private let cards: [SavedCard]
    /// Selected card id — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: String?

    // Config — mutated only through the modifiers below (R2).
    private var onDeleteAction: ((SavedCard) -> Void)?
    private var addNewTitle: String?
    private var onAddNewAction: (() -> Void)?
    private var flagsExpiredValue = true
    private var accent: SemanticColor?
    private var emptyContentSlot: AnyView?
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's ``savedCardsListStyle(_:)``
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnySavedCardsListStyle?
    /// Per-brand glyph replacement; nil = the stock `CardBrand.icon` symbol.
    private var brandLogoSlot: ((CardBrand) -> AnyView)?
    /// `false` once the caller passed an explicit `nil` text — badge hidden,
    /// auto-disable retained.
    private var showsExpiredBadge = true
    private var expiredBadgeText: String?
    private var expiredBadgeStyle: BadgeStyle = .error
    private var showsDividersValue = true
    private var surfaceKeyOverride: Theme.BackgroundColorKey?
    private var deleteStyleValue: DeleteAffordance = .both
    /// Per-card row replacement (`(card, isSelected)`); nil = built-in anatomy.
    private var rowContentSlot: ((SavedCard, Bool) -> AnyView)?

    /// R1 — cards + controlled selection (card id). The binding is the change
    /// channel; observe with `.onChange(of:)` at the call site.
    public init(_ cards: [SavedCard], selection: Binding<String?>) {
        self.cards = cards
        self._selection = ControllableState(wrappedValue: nil, external: selection)
    }

    /// Uncontrolled convenience (browse/preview contexts); the component owns
    /// the selection and it reads back only visually.
    public init(_ cards: [SavedCard], initiallySelected: String? = nil) {
        self.cards = cards
        self._selection = ControllableState(wrappedValue: initiallySelected)
    }

    private var motion: Animation? {
        MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
    }

    /// The typed configuration handed to the active ``SavedCardsListStyle``.
    @MainActor
    private var configuration: SavedCardsListConfiguration {
        SavedCardsListConfiguration(
            cards: cards,
            selectedID: selection,
            onSelect: { select($0) },
            onDelete: onDeleteAction == nil ? nil : { delete($0) },
            onAddNew: onAddNewAction,
            addNewTitle: addNewTitle ?? String(themeKitTravel: "Add new card"),
            flagsExpired: flagsExpiredValue,
            brandLogo: brandLogoSlot,
            showsExpiredBadge: showsExpiredBadge,
            expiredBadgeText: expiredBadgeText,
            expiredBadgeStyle: expiredBadgeStyle,
            showsDividers: showsDividersValue,
            deleteStyle: deleteStyleValue,
            rowContent: rowContentSlot,
            accent: accent,
            surfaceKey: surfaceKeyOverride,
            density: density,
            locale: locale,
            calendar: calendar,
            isMotionEnabled: micro && !reduceMotion
        )
    }

    public var body: some View {
        Group {
            if cards.isEmpty {
                emptyBody
            } else {
                (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            }
        }
        .animation(motion, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Saved cards, \(cards.count) cards"))
    }

    // MARK: Empty (T2 slot; default EmptyState)

    @MainActor
    @ViewBuilder
    private var emptyBody: some View {
        if let emptyContentSlot {
            emptyContentSlot
        } else {
            defaultEmptyState
        }
    }

    @MainActor
    private var defaultEmptyState: some View {
        var empty = EmptyState(String(themeKitTravel: "No saved cards"))
            .icon("creditcard")
            .message(String(themeKitTravel: "Cards you save at checkout will appear here."))
        if let onAddNewAction {
            let isReadOnly = self.isReadOnly
            empty = empty.primaryAction(addNewTitle ?? String(themeKitTravel: "Add new card"),
                                        action: {
                guard !isReadOnly else { return }
                onAddNewAction()
            })
        }
        return empty
    }

    // MARK: Selection plumbing

    @MainActor
    private func select(_ id: String) {
        guard !isReadOnly else { return }   // E1 — read-only blocks mutation, not focus
        selection = id
    }

    @MainActor
    private func delete(_ card: SavedCard) {
        guard !isReadOnly else { return }
        onDeleteAction?(card)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SavedCardsList {
    /// Enables the delete affordances — a trailing remove button on every row
    /// plus a destructive context-menu entry. The component never mutates the
    /// `cards` array; the app removes the card and re-renders (house rule 1).
    func onDelete(_ action: @escaping (SavedCard) -> Void) -> Self {
        copy { $0.onDeleteAction = action }
    }

    /// Appends an "Add new card" row (and wires the empty state's primary
    /// action) that invokes `action`. `title` overrides the default label.
    func onAddNew(_ title: String = String(themeKitTravel: "Add new card"),
                  perform action: @escaping () -> Void) -> Self {
        copy {
            $0.addNewTitle = title
            $0.onAddNewAction = action
        }
    }

    /// Expired cards (per `SavedCard.isExpired`) carry an "Expired" badge and
    /// auto-disable (default on); pass `false` to keep them selectable.
    func flagsExpired(_ on: Bool = true) -> Self { copy { $0.flagsExpiredValue = on } }

    /// Semantic tint for the radio / brand glyph / add-new chrome;
    /// `nil` (default) uses the primary triad.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Replaces the default `EmptyState` shown when `cards` is empty
    /// (canonical `.emptyContent { }` T2 slot).
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.emptyContentSlot = AnyView(content()) }
    }

    /// Layout archetype — superseded by the style axis: prefer
    /// `.savedCardsListStyle(.list/.wallet/.stack/.grid)`, settable once per
    /// screen via the environment. This modifier keeps working and, when
    /// called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .savedCardsListStyle(.list) or .savedCardsListStyle(.wallet) instead")
    func variant(_ v: SavedCardsVariant) -> Self {
        copy {
            switch v {
            case .list: $0.explicitStyle = AnySavedCardsListStyle(ListSavedCardsListStyle())
            case .wallet: $0.explicitStyle = AnySavedCardsListStyle(WalletSavedCardsListStyle())
            }
        }
    }

    /// Replaces the stock brand symbol with caller content, built per
    /// ``CardBrand`` — e.g. real brand artwork. Applies to every style.
    func brandLogo(@ViewBuilder _ content: @escaping (CardBrand) -> some View) -> Self {
        copy { $0.brandLogoSlot = { AnyView(content($0)) } }
    }

    /// Overrides the expired flag's badge. Pass a custom `text` and/or a
    /// `style` (default `.error`); pass `nil` text to hide the badge entirely
    /// — expired cards still auto-disable while ``flagsExpired(_:)`` is on.
    func expiredBadge(_ text: String?, style: BadgeStyle = .error) -> Self {
        copy {
            $0.showsExpiredBadge = text != nil
            $0.expiredBadgeText = text
            $0.expiredBadgeStyle = style
        }
    }

    /// Show the hairline dividers between list rows (default on). Applies to
    /// the `.list` style only.
    func showsDividers(_ on: Bool = true) -> Self { copy { $0.showsDividersValue = on } }

    /// Surface token: the `.list` style's backing fill, or the tile-shaped
    /// styles' card-face fill (default `.bgWhite` there).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKeyOverride = key } }

    /// Which delete affordances render once ``onDelete(_:)`` is wired:
    /// `.button` (trailing trash), `.contextMenu`, or `.both` (default). The
    /// tile-shaped styles (`.wallet`/`.stack`/`.grid`) are context-menu only —
    /// `.button` there shows none (their whole tile is already one `Button`).
    func deleteStyle(_ s: DeleteAffordance) -> Self { copy { $0.deleteStyleValue = s } }

    /// Replaces the built-in row/tile anatomy with caller content, built per
    /// `(card, isSelected)`. Selection tap handling, expired auto-disable,
    /// the delete context menu and VoiceOver labels are preserved around it.
    func rowContent(@ViewBuilder _ content: @escaping (SavedCard, Bool) -> some View) -> Self {
        copy { $0.rowContentSlot = { AnyView(content($0, $1)) } }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Mixed valid/expired · delete · add-new") {
    struct Demo: View {
        @State private var cardID: String? = "visa"
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    SavedCardsList([
                        SavedCard(id: "visa", brand: .visa, last4: "4242",
                                  holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
                        SavedCard(id: "mc", brand: .mastercard, last4: "4444",
                                  holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
                        SavedCard(id: "old", brand: .amex, last4: "0005",
                                  holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
                    ], selection: $cardID)
                        .onDelete { _ in }
                        .onAddNew { }

                    ListSectionHeader("Uncontrolled · accent · read-only")
                    SavedCardsList([
                        SavedCard(id: "visa", brand: .visa, last4: "4242",
                                  expiryMonth: 8, expiryYear: 2032),
                        SavedCard(id: "troy", brand: .troy, last4: "0001"),
                    ], initiallySelected: "troy")
                        .accent(.success)
                        .readOnly()

                    ListSectionHeader("Expired selectable (flagsExpired off)")
                    SavedCardsList([
                        SavedCard(id: "old", brand: .mastercard, last4: "9999",
                                  holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
                    ], initiallySelected: "old")
                        .flagsExpired(false)
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Wallet · slots · delete styles · dividers off") {
    struct Demo: View {
        @State private var cardID: String? = "visa"
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    ListSectionHeader("Wallet carousel (lift + stroke selection)")
                    SavedCardsList([
                        SavedCard(id: "visa", brand: .visa, last4: "4242",
                                  holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
                        SavedCard(id: "mc", brand: .mastercard, last4: "4444",
                                  holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
                        SavedCard(id: "old", brand: .amex, last4: "0005",
                                  expiryMonth: 3, expiryYear: 2020),
                    ], selection: $cardID)
                        .onDelete { _ in }
                        .onAddNew { }
                        .savedCardsListStyle(.wallet)

                    ListSectionHeader("Brand-logo slot · custom expired badge · no dividers")
                    SavedCardsList([
                        SavedCard(id: "visa", brand: .visa, last4: "4242",
                                  expiryMonth: 8, expiryYear: 2032),
                        SavedCard(id: "old", brand: .mastercard, last4: "9999",
                                  expiryMonth: 3, expiryYear: 2020),
                    ], selection: $cardID)
                        .brandLogo { brand in
                            Badge(brand.label.isEmpty ? "Card" : brand.label)
                                .badgeStyle(.info).size(.small)
                        }
                        .expiredBadge("Out of date", style: .warning)
                        .showsDividers(false)
                        .surface(.bgSecondaryLight)
                        .onDelete { _ in }
                        .deleteStyle(.contextMenu)

                    ListSectionHeader("Row-content slot · hidden expired badge")
                    SavedCardsList([
                        SavedCard(id: "visa", brand: .visa, last4: "4242",
                                  holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
                        SavedCard(id: "old", brand: .amex, last4: "0005",
                                  expiryMonth: 3, expiryYear: 2020),
                    ], selection: $cardID)
                        .expiredBadge(nil)
                        .rowContent { card, isSelected in
                            HStack(spacing: Theme.SpacingKey.sm.value) {
                                Icon(systemName: isSelected ? "checkmark.circle.fill" : "creditcard")
                                    .size(.sm)
                                Text("\(card.brand.label) \u{2022}\u{2022}\u{2022}\u{2022} \(card.last4)")
                                    .textStyle(.labelBase600)
                                Spacer()
                            }
                            .padding(.vertical, Theme.SpacingKey.sm.value)
                        }
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Empty · default + custom slot") {
    VStack(spacing: Theme.SpacingKey.lg.value) {
        SavedCardsList([], initiallySelected: nil)
            .onAddNew { }
        DividerView()
        SavedCardsList([], initiallySelected: nil)
            .emptyContent {
                Text("Your wallet is empty.")
                    .textStyle(.bodyBase400)
            }
    }
    .padding()
}

#Preview("Dark") {
    struct Demo: View {
        @State private var cardID: String? = "visa"
        var body: some View {
            let dark = Theme()
            dark.loadTheme(named: Theme.defaultThemeName, dark: true)
            return SavedCardsList([
                SavedCard(id: "visa", brand: .visa, last4: "4242",
                          holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
                SavedCard(id: "old", brand: .amex, last4: "0005",
                          expiryMonth: 3, expiryYear: 2020),
            ], selection: $cardID)
                .onDelete { _ in }
                .onAddNew { }
                .padding()
                .background(dark.background(.bgBase))
                .theme(dark)
        }
    }
    return Demo()
}
