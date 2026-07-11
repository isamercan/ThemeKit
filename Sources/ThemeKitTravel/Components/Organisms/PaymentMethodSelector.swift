//
//  PaymentMethodSelector.swift
//  ThemeKitTravel
//
//  Edition organism (F1.3 · ADR §9.3). Choose how to pay — card / wallet /
//  transfer rows (`.list`, the default) or tiles (`.grid`), with an optional
//  inline `InstallmentPicker` under the selected `.card` option. Composes
//  ThemeKit's neutral `ListRow` anatomy, `RadioButton`, `Badge` and
//  `InstallmentPicker` — nothing is re-implemented here.
//
//  State follows ADR-F4: controlled-first (`selection: Binding<String?>`) plus
//  an uncontrolled preview convenience (`initiallySelected:`), both funneled
//  through `ControllableState`. Currency for the installment amounts is NOT a
//  parameter — it resolves inside `InstallmentPicker` via the §10 chain
//  (`\.formatDefaults` > locale currency > "USD").
//
//  ```swift
//  PaymentMethodSelector(options, selection: $method)
//      .installments([1, 3, 6, 9], selection: $months, total: fareTotal)
//      .badge("No fee", for: "transfer")
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``PaymentMethodSelector``: radio rows (`.list`),
/// tiles (`.grid`), horizontally-snapping tiles (`.carousel`), or dense
/// single-line rows (`.compactList`).
public enum PaymentMethodVariant: Sendable { case list, grid, carousel, compactList }

/// The per-option selected glyph: a leading `RadioButton` (`.radio`, the list
/// default), a trailing checkmark (`.checkmark`), or nothing (`.none` — the
/// selected chrome alone signals the choice).
public enum SelectionIndicator: Sendable { case radio, checkmark, none }

/// Strength of the selected tile stroke: `.subtle` (default — base step,
/// hairline-and-a-half) or `.strong` (700 "strong" step, 2pt).
public enum TileEmphasis: Sendable { case subtle, strong }

/// A payment-method chooser — radio-semantic rows (or tiles) over
/// ``PaymentMethodOption`` values, with an optional inline instalment picker
/// under the selected card option.
public struct PaymentMethodSelector: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [PaymentMethodOption]
    /// Selected option id — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: String?

    // Config — mutated only through the modifiers below (R2).
    private var variantValue: PaymentMethodVariant = .list
    private var installmentMonths: [Int]?
    private var installmentSelection: Binding<Int>?
    private var installmentTotal: Decimal?
    private var badges: [String: String] = [:]
    private var disabledIDs: Set<String> = []
    private var accent: SemanticColor?
    private var footerSlot: AnyView?
    private var headerSlot: AnyView?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    /// Selected glyph — `nil` = the variant's default (`.radio` for the row
    /// variants, `.checkmark` for the tile variants).
    private var indicatorOverride: SelectionIndicator?
    private var columnsValue = 2
    /// Per-option replacement (`(option, isSelected)`); nil = built-in anatomy.
    private var optionSlot: ((PaymentMethodOption, Bool) -> AnyView)?
    private var badgeStyleValue: BadgeStyle = .info
    private var tileRadiusRole: Theme.RadiusRole = .field
    private var emphasisValue: TileEmphasis = .subtle

    /// R1 — options + controlled selection (option id). The binding is the
    /// change channel; observe with `.onChange(of:)` at the call site.
    public init(_ options: [PaymentMethodOption], selection: Binding<String?>) {
        self.options = options
        self._selection = ControllableState(wrappedValue: nil, external: selection)
    }

    /// Uncontrolled convenience (browse/preview contexts); the component owns
    /// the selection and it reads back only visually.
    public init(_ options: [PaymentMethodOption], initiallySelected: String? = nil) {
        self.options = options
        self._selection = ControllableState(wrappedValue: initiallySelected)
    }

    private var motion: Animation? {
        MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
    }
    private var accentBase: Color { (accent ?? .primary).base }

    /// The variant's effective indicator: the explicit override, or `.radio`
    /// for row variants / `.checkmark` for tile variants.
    private var effectiveIndicator: SelectionIndicator {
        if let indicatorOverride { return indicatorOverride }
        switch variantValue {
        case .list, .compactList: return .radio
        case .grid, .carousel: return .checkmark
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let headerSlot { headerSlot }
            switch variantValue {
            case .list: listBody
            case .grid: gridBody
            case .carousel: carouselBody
            case .compactList: compactListBody
            }
            if let footerSlot { footerSlot }
        }
        .animation(motion, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Payment method, \(options.count) options"))
    }

    // MARK: List variant — ListRow anatomy with radio semantics

    @MainActor
    private var listBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                row(option)
                if showsInstallments(under: option) {
                    inlineInstallments
                        .padding(.bottom, Theme.SpacingKey.sm.value)
                }
                if index < options.count - 1 {
                    DividerView().size(.small)
                }
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func row(_ option: PaymentMethodOption) -> some View {
        let isOn = selection == option.id
        if let optionSlot {
            slotButton(option, isOn: isOn) { optionSlot(option, isOn) }
        } else {
            builtInRow(option, isOn: isOn)
        }
    }

    @MainActor
    private func builtInRow(_ option: PaymentMethodOption, isOn: Bool) -> some View {
        var listRow = ListRow(option.title) { select(option.id) }
            .subtitle(option.subtitle)
            .leading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if effectiveIndicator == .radio {
                        RadioButton(isSelected: isSelectedBinding(option.id)).accent(accent)
                    }
                    Icon(systemName: option.systemImage)
                        .size(.sm)
                        .color(isOn ? accentBase : theme.text(.textSecondary))
                }
            }
            .badge(badges[option.id])
            .selected(isOn)
        if effectiveIndicator == .checkmark, isOn {
            listRow = listRow.trailing {
                Icon(systemName: "checkmark").size(.sm).color(accentBase)
            }
        } else {
            listRow = listRow.trailing(ListRowTrailing.none)
        }
        return listRow
            .disabled(disabledIDs.contains(option.id))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    /// Wraps `.optionContent` slot output in the selection button, preserving
    /// tap handling, disabling and VoiceOver traits around caller content.
    @MainActor
    private func slotButton<Content: View>(
        _ option: PaymentMethodOption, isOn: Bool, @ViewBuilder content: () -> Content
    ) -> some View {
        Button { select(option.id) } label: {
            content().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabledIDs.contains(option.id))
        .allowsHitTesting(!isReadOnly)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Compact-list variant — dense single-line rows

    @MainActor
    private var compactListBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                compactRow(option)
                if showsInstallments(under: option) {
                    inlineInstallments
                        .padding(.bottom, Theme.SpacingKey.sm.value)
                }
                if index < options.count - 1 {
                    DividerView().size(.small)
                }
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func compactRow(_ option: PaymentMethodOption) -> some View {
        let isOn = selection == option.id
        let isDisabled = disabledIDs.contains(option.id)
        slotButton(option, isOn: isOn) {
            if let optionSlot {
                optionSlot(option, isOn)
            } else {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if effectiveIndicator == .radio {
                        RadioButton(isSelected: isSelectedBinding(option.id)).accent(accent)
                    }
                    Icon(systemName: option.systemImage)
                        .size(.sm)
                        .color(isDisabled ? theme.text(.textDisabled) : (isOn ? accentBase : theme.text(.textSecondary)))
                    Text(option.title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
                        .lineLimit(1)
                    Spacer(minLength: Theme.SpacingKey.xs.value)
                    if let badgeText = badges[option.id] {
                        Badge(badgeText).badgeStyle(badgeStyleValue).variant(.soft).size(.small)
                    }
                    if effectiveIndicator == .checkmark, isOn {
                        Icon(systemName: "checkmark").size(.sm).color(accentBase)
                    }
                }
                .padding(.vertical, Theme.SpacingKey.xs.value)
            }
        }
    }

    // MARK: Carousel variant — horizontal snap tiles

    @MainActor
    @ViewBuilder
    private var carouselBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(options) { option in
                    tile(option)
                        .frame(width: Metrics.carouselTileWidth)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        if options.contains(where: { showsInstallments(under: $0) }) {
            inlineInstallments
        }
    }

    /// Genuine dimensions with no semantic token — fixed tile constants.
    private enum Metrics {
        static let carouselTileWidth: CGFloat = 148
        static let tileMinHeight: CGFloat = 88
    }

    // MARK: Grid variant — selection tiles (vertical fallback at a11y sizes)

    @MainActor
    @ViewBuilder
    private var gridBody: some View {
        let gap = Theme.SpacingKey.sm.value
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: gap) { ForEach(options) { tile($0) } }
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columnsValue),
                spacing: gap
            ) {
                ForEach(options) { tile($0) }
            }
        }
        if options.contains(where: { showsInstallments(under: $0) }) {
            inlineInstallments
        }
    }

    /// Selected-stroke color/width from the emphasis axis — named semantic
    /// steps only (`base` / `strong`).
    private var selectedStroke: (color: Color, width: CGFloat) {
        switch emphasisValue {
        case .subtle: return (accentBase, 1.5)
        case .strong: return ((accent ?? .primary).strong, 2)
        }
    }

    @MainActor
    @ViewBuilder
    private func tile(_ option: PaymentMethodOption) -> some View {
        let isOn = selection == option.id
        let isDisabled = disabledIDs.contains(option.id)
        let shape = RoundedRectangle(cornerRadius: tileRadiusRole.value, style: .continuous)
        slotButton(option, isOn: isOn) {
            Group {
                if let optionSlot {
                    optionSlot(option, isOn)
                } else {
                    builtInTileLabel(option, isOn: isOn, isDisabled: isDisabled)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.tileMinHeight)
            .padding(Theme.SpacingKey.md.value)
            .background(isOn ? (accent ?? .primary).bg : theme.background(surfaceKey), in: shape)
            .overlay(shape.stroke(isOn ? selectedStroke.color : theme.border(.borderPrimary),
                                  lineWidth: isOn ? selectedStroke.width : 1))
            .overlay(alignment: .topTrailing) {
                if let badgeText = badges[option.id] {
                    Badge(badgeText).badgeStyle(badgeStyleValue).variant(.soft).size(.small)
                        .padding(Theme.SpacingKey.xs.value)
                }
            }
            .contentShape(shape)
        }
    }

    @MainActor
    private func builtInTileLabel(_ option: PaymentMethodOption, isOn: Bool, isDisabled: Bool) -> some View {
        VStack(spacing: Theme.SpacingKey.xs.value) {
            Icon(systemName: option.systemImage)
                .size(.md)
                .color(isDisabled ? theme.text(.textDisabled) : (isOn ? accentBase : theme.text(.textSecondary)))
            Text(option.title)
                .textStyle(.labelSm600)
                .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
                .multilineTextAlignment(.center)
            if let subtitle = option.subtitle {
                Text(subtitle)
                    .textStyle(.bodySm400)
                    .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textSecondary))
                    .multilineTextAlignment(.center)
            }
            if effectiveIndicator == .checkmark, isOn {
                Icon(systemName: "checkmark.circle.fill").size(.sm).color(accentBase)
            }
        }
    }

    // MARK: Installments (composes the existing InstallmentPicker)

    /// Whether the inline instalment picker belongs under this option: the
    /// modifier is configured, the option is the current selection, and it is
    /// a `.card` method.
    @MainActor
    private func showsInstallments(under option: PaymentMethodOption) -> Bool {
        installmentMonths?.isEmpty == false
            && installmentSelection != nil
            && installmentTotal != nil
            && option.kind == .card
            && option.id == selection
    }

    @MainActor
    @ViewBuilder
    private var inlineInstallments: some View {
        if let months = installmentMonths, let picked = installmentSelection, let total = installmentTotal {
            // Currency deliberately not set: InstallmentPicker resolves it via
            // the §10 chain (`\.formatDefaults` > locale currency > "USD").
            InstallmentPicker(months.map { count in
                InstallmentOption(
                    count: count,
                    total: total,
                    monthly: count > 1 ? total / Decimal(count) : nil
                )
            }, selection: picked)
            .accent(accent)
            .padding(.leading, Theme.SpacingKey.lg.value)
            .transition(.opacity)
        }
    }

    // MARK: Selection plumbing

    @MainActor
    private func select(_ id: String) {
        guard !isReadOnly else { return }   // E1 — read-only blocks mutation, not focus
        selection = id
    }

    /// Radio-style binding for one option: setting `true` selects it; a
    /// payment method can't be deselected by tapping its own radio.
    @MainActor
    private func isSelectedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selection == id },
            set: { if $0 { select(id) } }
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PaymentMethodSelector {
    /// Layout archetype: `.list` radio rows (default), `.grid` tiles,
    /// `.carousel` horizontal snap tiles, or `.compactList` single-line rows.
    func variant(_ v: PaymentMethodVariant) -> Self { copy { $0.variantValue = v } }

    /// Selected glyph: `.radio` (row variants' default), `.checkmark`
    /// (tile variants' default), or `.none` — the selected chrome alone
    /// signals the choice. Tile variants ignore `.radio` (no glyph).
    func indicator(_ i: SelectionIndicator) -> Self { copy { $0.indicatorOverride = i } }

    /// Grid column count, clamped 1…4 (default 2). The accessibility-size
    /// vertical fallback is unaffected.
    func columns(_ n: Int) -> Self { copy { $0.columnsValue = min(4, max(1, n)) } }

    /// Replaces the built-in row/tile anatomy with caller content, built per
    /// `(option, isSelected)` in every variant. Selection tap handling,
    /// disabling and VoiceOver traits are preserved around the slot; the tile
    /// variants keep their selected chrome (fill/stroke/badge) around it.
    func optionContent(@ViewBuilder _ content: @escaping (PaymentMethodOption, Bool) -> some View) -> Self {
        copy { $0.optionSlot = { AnyView(content($0, $1)) } }
    }

    /// Style of the per-option badges (default `.info`) — applies wherever
    /// this component draws the `Badge` itself (tiles, carousel, compact
    /// rows); the `.list` variant's badge is drawn by `ListRow`.
    func badgeStyle(_ s: BadgeStyle) -> Self { copy { $0.badgeStyleValue = s } }

    /// Corner role for the tile variants (default `.field`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.tileRadiusRole = role } }

    /// Selected-tile stroke strength: `.subtle` (default, base step) or
    /// `.strong` (the 700 "strong" step at 2pt).
    func emphasis(_ e: TileEmphasis) -> Self { copy { $0.emphasisValue = e } }

    /// Top-aligned accessory area (canonical `.header { }` slot), mirroring
    /// the existing `.footer` — e.g. a section title or a promo note.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.headerSlot = AnyView(content()) }
    }

    /// Instalment plans shown inline under the selected `.card` option.
    /// `total` is required (§1.4 rev. 5) — per-month amounts derive from it
    /// (`total / months`); `selection` is the chosen instalment count, a
    /// separate outcome owned by the caller. Currency resolves via the
    /// environment chain (`\.formatDefaults` > locale > "USD").
    func installments(_ months: [Int], selection: Binding<Int>, total: Decimal) -> Self {
        copy {
            $0.installmentMonths = months
            $0.installmentSelection = selection
            $0.installmentTotal = total
        }
    }

    /// Per-option badge, e.g. "No fee" on a transfer method. Pass `nil` to clear.
    func badge(_ text: String?, for optionID: String) -> Self {
        copy { $0.badges[optionID] = text }
    }

    /// Options rendered disabled and excluded from selection.
    func disabledMethods(_ ids: Set<String>) -> Self { copy { $0.disabledIDs = ids } }

    /// Semantic tint for the radio / selected chrome / instalment rows;
    /// `nil` (default) uses the primary triad.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Surface token for the *unselected* `.grid` tile fill (default `.bgBase`);
    /// the selected tile keeps the accent tint and stroke.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Bottom-aligned accessory area (canonical `.footer { }` slot), e.g. a
    /// security note or fee disclaimer.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.footerSlot = AnyView(content()) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("List · installments · badge · disabled") {
    struct Demo: View {
        @State private var method: String? = "card"
        @State private var months = 3
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], selection: $method)
                        .installments([1, 3, 6, 9], selection: $months, total: 1_240)
                        .badge("No fee", for: "transfer")
                        .disabledMethods(["wallet"])
                        .footer {
                            Text("All payments are encrypted.")
                                .textStyle(.bodySm400)
                        }

                    ListSectionHeader("Uncontrolled · accent · read-only")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], initiallySelected: "transfer")
                        .accent(.success)
                        .readOnly()
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Carousel · compact list · slots · emphasis") {
    struct Demo: View {
        @State private var method: String? = "card"
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    ListSectionHeader("Carousel · strong emphasis · box radius")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Card"),
                        .init(id: "wallet", kind: .wallet, title: "Wallet"),
                        .init(id: "transfer", kind: .transfer, title: "Transfer"),
                        .init(id: "card2", kind: .card, title: "Corporate"),
                    ], selection: $method)
                        .variant(.carousel)
                        .emphasis(.strong)
                        .radius(.box)
                        .badge("New", for: "wallet")
                        .badgeStyle(.success)
                        .header {
                            Text("How would you like to pay?").textStyle(.headingSm)
                        }

                    ListSectionHeader("Compact list · checkmark indicator")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "wallet", kind: .wallet, title: "Digital wallet"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], selection: $method)
                        .variant(.compactList)
                        .indicator(.checkmark)

                    ListSectionHeader("Grid · 3 columns · custom option slot")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Card"),
                        .init(id: "wallet", kind: .wallet, title: "Wallet"),
                        .init(id: "transfer", kind: .transfer, title: "Transfer"),
                    ], selection: $method)
                        .variant(.grid)
                        .columns(3)
                        .indicator(.none)
                        .optionContent { option, isSelected in
                            VStack(spacing: Theme.SpacingKey.xs.value) {
                                Icon(systemName: option.systemImage).size(.lg)
                                Text(option.title).textStyle(isSelected ? .labelSm700 : .labelSm600)
                            }
                        }
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Grid · dark") {
    struct Demo: View {
        @State private var method: String? = "wallet"
        var body: some View {
            let dark = Theme()
            dark.loadTheme(named: Theme.defaultThemeName, dark: true)
            return VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                PaymentMethodSelector([
                    .init(id: "card", kind: .card, title: "Card"),
                    .init(id: "wallet", kind: .wallet, title: "Wallet", subtitle: "One tap"),
                    .init(id: "transfer", kind: .transfer, title: "Transfer"),
                    .init(id: "card2", kind: .card, title: "Corporate card"),
                ], selection: $method)
                    .variant(.grid)
                    .badge("New", for: "wallet")

                ListSectionHeader("Grid · surface(.bgWhite)")
                PaymentMethodSelector([
                    .init(id: "card", kind: .card, title: "Card"),
                    .init(id: "wallet", kind: .wallet, title: "Wallet"),
                ], initiallySelected: "card")
                    .variant(.grid)
                    .surface(.bgWhite)
            }
            .padding()
            .background(dark.background(.bgBase))
            .theme(dark)
        }
    }
    return Demo()
}
