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

/// Layout archetype of a ``SavedCardsList``: radio rows (`.list`, default) or
/// a horizontal carousel of card-face tiles (`.wallet`).
public enum SavedCardsVariant: Sendable { case list, wallet }

/// How the delete affordance surfaces: a trailing button (`.button`), a
/// destructive context-menu entry (`.contextMenu`), or both (default).
public enum DeleteAffordance: Sendable { case button, contextMenu, both }

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
    private var variantValue: SavedCardsVariant = .list
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
    private var accentBase: Color { (accent ?? .primary).base }

    /// The delete affordances that actually render, per `deleteStyle(_:)`.
    private var showsDeleteButton: Bool {
        onDeleteAction != nil && (deleteStyleValue == .button || deleteStyleValue == .both)
    }
    private var showsDeleteMenu: Bool {
        onDeleteAction != nil && (deleteStyleValue == .contextMenu || deleteStyleValue == .both)
    }

    public var body: some View {
        Group {
            if cards.isEmpty {
                emptyBody
            } else {
                switch variantValue {
                case .list: listBody
                case .wallet: walletBody
                }
            }
        }
        .animation(motion, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Saved cards, \(cards.count) cards"))
    }

    // MARK: List — ListRow anatomy with radio semantics

    @MainActor
    @ViewBuilder
    private var listBody: some View {
        let stack = VStack(spacing: 0) {
            ForEach(cards) { card in
                row(card)
                if showsDividersValue, card.id != cards.last?.id || showsAddNewRow {
                    DividerView().size(.small)
                }
            }
            if showsAddNewRow { addNewRow }
        }
        if let surfaceKeyOverride {
            stack.background(theme.background(surfaceKeyOverride))
        } else {
            stack
        }
    }

    @MainActor
    @ViewBuilder
    private func row(_ card: SavedCard) -> some View {
        let isOn = selection == card.id
        let isExpiredRow = flagsExpiredValue && card.isExpired(calendar: calendar)
        Group {
            if let rowContentSlot {
                // `.rowContent` slot: caller anatomy inside the selection
                // button; auto-disable, context menu and VoiceOver preserved.
                Button { select(card.id) } label: {
                    rowContentSlot(card, isOn).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isReadOnly)
            } else {
                builtInRow(card, isOn: isOn, isExpiredRow: isExpiredRow)
            }
        }
        .disabled(isExpiredRow)
        .contextMenu { deleteMenu(for: card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: card, isExpired: isExpiredRow))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @MainActor
    private func builtInRow(_ card: SavedCard, isOn: Bool, isExpiredRow: Bool) -> some View {
        var listRow = ListRow(maskedTitle(for: card)) { select(card.id) }
            .subtitle(subtitle(for: card))
            .leading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    RadioButton(isSelected: isSelectedBinding(card.id)).accent(accent)
                    brandGlyph(card.brand, isOn: isOn)
                }
            }
            .selected(isOn)
            .trailing(ListRowTrailing.none)
        if (isExpiredRow && showsExpiredBadge) || showsDeleteButton {
            listRow = listRow.trailing { trailingAccessories(for: card, isExpired: isExpiredRow) }
        }
        return listRow
    }

    /// The brand mark: the caller's `.brandLogo` slot or the stock symbol.
    @MainActor
    @ViewBuilder
    private func brandGlyph(_ brand: CardBrand, isOn: Bool) -> some View {
        if let brandLogoSlot {
            brandLogoSlot(brand)
        } else {
            Icon(systemName: brand.icon)
                .size(.sm)
                .color(isOn ? accentBase : theme.text(.textSecondary))
        }
    }

    /// Expired badge and/or the explicit delete affordance, trailing-aligned.
    @MainActor
    @ViewBuilder
    private func trailingAccessories(for card: SavedCard, isExpired: Bool) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if isExpired, showsExpiredBadge {
                Badge(expiredBadgeText ?? String(themeKitTravel: "Expired"))
                    .badgeStyle(expiredBadgeStyle).variant(.soft).size(.small)
            }
            if showsDeleteButton {
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
        if showsDeleteMenu, !isReadOnly {
            Button(role: .destructive) { delete(card) } label: {
                Label(String(themeKitTravel: "Remove card"), systemImage: "trash")
            }
        }
    }

    // MARK: Wallet — horizontal carousel of card-face tiles

    /// Genuine dimensions with no semantic token — fixed card-face constants
    /// (the ~1.586 bank-card aspect, sized for a phone-width carousel).
    private enum WalletMetrics {
        static let tileWidth: CGFloat = 200
        static let tileHeight: CGFloat = 126
    }

    @MainActor
    private var walletBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(cards) { walletTile($0) }
                if let onAddNewAction { addNewTile(onAddNewAction) }
            }
            .padding(.vertical, Theme.SpacingKey.xs.value)   // room for the lift shadow
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    @MainActor
    private func walletTile(_ card: SavedCard) -> some View {
        let isOn = selection == card.id
        let isExpiredRow = flagsExpiredValue && card.isExpired(calendar: calendar)
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        return Button { select(card.id) } label: {
            Group {
                if let rowContentSlot {
                    rowContentSlot(card, isOn)
                } else {
                    walletFace(card, isOn: isOn, isExpired: isExpiredRow)
                }
            }
            .frame(width: WalletMetrics.tileWidth, height: WalletMetrics.tileHeight)
            .background(theme.background(surfaceKeyOverride ?? .bgWhite), in: shape)
            // Selection = lift + accent stroke (the checklist's wallet look).
            .overlay(shape.strokeBorder(isOn ? accentBase : theme.border(.borderPrimary),
                                        lineWidth: isOn ? 2 : 1))
            .themeShadow(isOn ? .elevated : .soft)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isExpiredRow)
        .allowsHitTesting(!isReadOnly)
        .contextMenu { deleteMenu(for: card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: card, isExpired: isExpiredRow))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @MainActor
    private func walletFace(_ card: SavedCard, isOn: Bool, isExpired: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack {
                brandGlyph(card.brand, isOn: isOn)
                Spacer(minLength: Theme.SpacingKey.xs.value)
                if isExpired, showsExpiredBadge {
                    Badge(expiredBadgeText ?? String(themeKitTravel: "Expired"))
                        .badgeStyle(expiredBadgeStyle).variant(.soft).size(.small)
                }
            }
            Spacer(minLength: 0)
            Text("•••• \(card.last4)")
                .textStyle(.labelLg600)
                .foregroundStyle(isExpired ? theme.text(.textDisabled) : theme.text(.textPrimary))
            if let line = subtitle(for: card) {
                Text(line)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .lineLimit(1)
            }
        }
        .padding(Theme.SpacingKey.md.value)
    }

    @MainActor
    private func addNewTile(_ action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        return Button {
            guard !isReadOnly else { return }
            action()
        } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: "plus.circle.fill").size(.md).color(accentBase)
                Text(addNewTitle ?? String(themeKitTravel: "Add new card"))
                    .textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            .frame(width: WalletMetrics.tileWidth, height: WalletMetrics.tileHeight)
            .background(theme.background(surfaceKeyOverride ?? .bgWhite), in: shape)
            .overlay(shape.strokeBorder(theme.border(.borderPrimary),
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
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

    /// Layout archetype: `.list` radio rows (default) or `.wallet` — a
    /// horizontal carousel of card-face tiles with lift + stroke selection.
    func variant(_ v: SavedCardsVariant) -> Self { copy { $0.variantValue = v } }

    /// Replaces the stock brand symbol with caller content, built per
    /// ``CardBrand`` — e.g. real brand artwork. Applies to both variants.
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

    /// Show the hairline dividers between list rows (default on).
    func showsDividers(_ on: Bool = true) -> Self { copy { $0.showsDividersValue = on } }

    /// Surface token: the list's backing fill, or the wallet tiles' card-face
    /// fill (wallet default `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKeyOverride = key } }

    /// Which delete affordances render once ``onDelete(_:)`` is wired:
    /// `.button` (trailing trash), `.contextMenu`, or `.both` (default).
    /// The wallet variant is context-menu only — `.button` there shows none.
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
                        .variant(.wallet)
                        .onDelete { _ in }
                        .onAddNew { }

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
