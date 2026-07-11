//
//  SavedCardsList.swift
//  ThemeKitTravel
//
//  Edition organism (F3.1 · ADR §9.10). Stored payment cards — brand glyph,
//  •••• last4, holder, expiry and an expired flag — with radio-semantic
//  single-select plus delete / add-new affordances. Composes ThemeKit's
//  neutral `ListRow` anatomy, `RadioButton`, `Badge`, `Icon`, `DividerView`
//  and `EmptyState` — nothing is re-implemented here.
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
//  ```
//

import SwiftUI
import ThemeKit

/// A stored-cards chooser — radio-semantic rows over ``SavedCard`` values with
/// optional delete and add-new affordances. Pairs with `PaymentMethodSelector`:
/// apps typically render it when the `card` method is chosen.
public struct SavedCardsList: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        Group {
            if cards.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .animation(motion, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Saved cards, \(cards.count) cards"))
    }

    // MARK: List — ListRow anatomy with radio semantics

    @MainActor
    private var listBody: some View {
        VStack(spacing: 0) {
            ForEach(cards) { card in
                row(card)
                if card.id != cards.last?.id || showsAddNewRow {
                    DividerView().size(.small)
                }
            }
            if showsAddNewRow { addNewRow }
        }
    }

    @MainActor
    private func row(_ card: SavedCard) -> some View {
        let isOn = selection == card.id
        let isExpiredRow = flagsExpiredValue && card.isExpired(calendar: calendar)
        var listRow = ListRow(maskedTitle(for: card)) { select(card.id) }
            .subtitle(subtitle(for: card))
            .leading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    RadioButton(isSelected: isSelectedBinding(card.id)).accent(accent)
                    Icon(systemName: card.brand.icon)
                        .size(.sm)
                        .color(isOn ? accentBase : theme.text(.textSecondary))
                }
            }
            .selected(isOn)
            .trailing(ListRowTrailing.none)
        if isExpiredRow || onDeleteAction != nil {
            listRow = listRow.trailing { trailingAccessories(for: card, isExpired: isExpiredRow) }
        }
        return listRow
            .disabled(isExpiredRow)
            .contextMenu { deleteMenu(for: card) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: card, isExpired: isExpiredRow))
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// Expired badge and/or the explicit delete affordance, trailing-aligned.
    @MainActor
    @ViewBuilder
    private func trailingAccessories(for card: SavedCard, isExpired: Bool) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if isExpired {
                Badge(String(themeKitTravel: "Expired"))
                    .badgeStyle(.error).variant(.soft).size(.small)
            }
            if onDeleteAction != nil {
                Button { delete(card) } label: {
                    Icon(systemName: "trash")
                        .size(.sm)
                        .color(theme.foreground(.systemcolorsFgError))
                        .frame(width: 44, height: 44)   // a11y hit target (heart precedent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKitTravel: "Remove card ending \(spacedDigits(card.last4))"))
            }
        }
    }

    /// Destructive context-menu entry mirroring the trailing delete button.
    @MainActor
    @ViewBuilder
    private func deleteMenu(for card: SavedCard) -> some View {
        if onDeleteAction != nil, !isReadOnly {
            Button(role: .destructive) { delete(card) } label: {
                Label(String(themeKitTravel: "Remove card"), systemImage: "trash")
            }
        }
    }

    // MARK: Add-new affordance

    private var showsAddNewRow: Bool { onAddNewAction != nil }

    @MainActor
    @ViewBuilder
    private var addNewRow: some View {
        if let onAddNewAction {
            ListRow(addNewTitle ?? String(themeKitTravel: "Add new card")) {
                guard !isReadOnly else { return }
                onAddNewAction()
            }
            .leading {
                Icon(systemName: "plus.circle.fill").size(.sm).color(accentBase)
            }
            .trailing(ListRowTrailing.chevron)
            .accessibilityAddTraits(.isButton)
        }
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

    // MARK: Row text (formatted with the env locale)

    /// "Visa •••• 4242"; brand-less cards render just the masked digits.
    private func maskedTitle(for card: SavedCard) -> String {
        let masked = "•••• \(card.last4)"
        let brand = card.brand.label
        return brand.isEmpty ? masked : "\(brand) \(masked)"
    }

    /// "Alex Morgan · Expires 08/28" — either part optional.
    private func subtitle(for card: SavedCard) -> String? {
        var parts: [String] = []
        if let holder = card.holder, !holder.isEmpty { parts.append(holder) }
        if let expiry = expiryText(for: card) { parts.append(expiry) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func expiryText(for card: SavedCard) -> String? {
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
    private func accessibilityLabel(for card: SavedCard, isExpired: Bool) -> String {
        var parts: [String] = [
            card.brand.label.isEmpty
                ? String(themeKitTravel: "Card ending \(spacedDigits(card.last4))")
                : String(themeKitTravel: "\(card.brand.label) card ending \(spacedDigits(card.last4))"),
        ]
        if let holder = card.holder, !holder.isEmpty { parts.append(holder) }
        if let expiry = expiryText(for: card) { parts.append(expiry) }
        if isExpired { parts.append(String(themeKitTravel: "Expired")) }
        return parts.joined(separator: ", ")
    }

    /// Digits read out one by one: "4242" → "4 2 4 2".
    private func spacedDigits(_ digits: String) -> String {
        digits.map(String.init).joined(separator: " ")
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

    /// Radio-style binding for one card: setting `true` selects it; a card
    /// can't be deselected by tapping its own radio.
    @MainActor
    private func isSelectedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selection == id },
            set: { if $0 { select(id) } }
        )
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
