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
//  The entire layout is a swappable ``PaymentMethodSelectorStyle`` (ADR-0004):
//  this component owns the *data* (options, selection, instalments, badges)
//  and the active style owns the *arrangement*. See
//  `PaymentMethodSelectorStyle.swift` for the five built-ins
//  (`.list` `.grid` `.carousel` `.compactList` `.sectioned`).
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
//      .paymentMethodSelectorStyle(.grid)
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``PaymentMethodSelector``: radio rows (`.list`),
/// tiles (`.grid`), horizontally-snapping tiles (`.carousel`), or dense
/// single-line rows (`.compactList`).
///
/// Superseded by ``PaymentMethodSelectorStyle`` (each case maps 1:1 to a
/// preset, which also adds `.sectioned`); kept for source compatibility until
/// the next major, together with the deprecated
/// ``PaymentMethodSelector/variant(_:)`` modifier.
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
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    @Environment(\.paymentMethodSelectorStyle) private var envStyle

    private let options: [PaymentMethodOption]
    /// Selected option id — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: String?

    // Config — mutated only through the modifiers below (R2).
    private var installmentMonths: [Int]?
    private var installmentSelection: Binding<Int>?
    private var installmentTotal: Decimal?
    private var badges: [String: String] = [:]
    private var disabledIDs: Set<String> = []
    private var accent: SemanticColor?
    private var footerSlot: AnyView?
    private var headerSlot: AnyView?
    private var surfaceKey: Theme.BackgroundColorKey?
    /// Selected glyph — `nil` = the active style's own default (`.radio` for
    /// row-shaped presets, `.checkmark` for tile-shaped ones).
    private var indicatorOverride: SelectionIndicator?
    private var columnsValue = 2
    /// Per-option replacement (`(option, isSelected)`); nil = built-in anatomy.
    private var optionSlot: ((PaymentMethodOption, Bool) -> AnyView)?
    private var badgeStyleValue: BadgeStyle = .info
    private var tileRadiusRole: Theme.RadiusRole = .field
    private var emphasisValue: TileEmphasis = .subtle
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's ``paymentMethodSelectorStyle(_:)``
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyPaymentMethodSelectorStyle?

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

    /// The pre-built, accent-styled inline instalment picker for the current
    /// selection, or `nil` when instalments aren't configured, nothing is
    /// selected, or the selection isn't a `.card` method (composes the
    /// neutral `InstallmentPicker`; currency deliberately unset — it resolves
    /// via the §10 chain inside `InstallmentPicker` itself).
    private var installmentsSlot: AnyView? {
        guard let months = installmentMonths, !months.isEmpty,
              let picked = installmentSelection,
              let total = installmentTotal,
              let selectedOption = options.first(where: { $0.id == selection }),
              selectedOption.kind == .card
        else { return nil }
        return AnyView(
            InstallmentPicker(months.map { count in
                InstallmentOption(
                    count: count,
                    total: total,
                    monthly: count > 1 ? total / Decimal(count) : nil
                )
            }, selection: picked)
                .accent(accent)
                .padding(.leading, density.scale(Theme.SpacingKey.lg.value))
                .transition(.opacity)
        )
    }

    /// The typed configuration handed to the active ``PaymentMethodSelectorStyle``.
    private var configuration: PaymentMethodSelectorConfiguration {
        PaymentMethodSelectorConfiguration(
            options: options,
            selectedID: selection,
            select: { select($0) },
            installmentsSlot: installmentsSlot,
            badges: badges,
            disabledMethods: disabledIDs,
            indicatorOverride: indicatorOverride,
            columns: columnsValue,
            optionContent: optionSlot,
            badgeStyle: badgeStyleValue,
            header: headerSlot,
            footer: footerSlot,
            radiusRole: tileRadiusRole,
            emphasis: emphasisValue,
            accent: accent,
            surfaceKey: surfaceKey,
            isReadOnly: isReadOnly,
            density: density,
            locale: locale
        )
    }

    public var body: some View {
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            .animation(motion, value: selection)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(themeKitTravel: "Payment method, \(options.count) options"))
    }

    // MARK: Selection plumbing

    @MainActor
    private func select(_ id: String) {
        guard !isReadOnly else { return }   // E1 — read-only blocks mutation, not focus
        selection = id
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PaymentMethodSelector {
    /// Layout archetype — superseded by the style axis: prefer
    /// `.paymentMethodSelectorStyle(.list/.grid/.carousel/.compactList)`,
    /// settable once per screen via the environment. This modifier keeps
    /// working and, when called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .paymentMethodSelectorStyle(.grid)")
    func variant(_ v: PaymentMethodVariant) -> Self {
        copy {
            switch v {
            case .list: $0.explicitStyle = AnyPaymentMethodSelectorStyle(ListPaymentMethodSelectorStyle())
            case .grid: $0.explicitStyle = AnyPaymentMethodSelectorStyle(GridPaymentMethodSelectorStyle())
            case .carousel: $0.explicitStyle = AnyPaymentMethodSelectorStyle(CarouselPaymentMethodSelectorStyle())
            case .compactList: $0.explicitStyle = AnyPaymentMethodSelectorStyle(CompactListPaymentMethodSelectorStyle())
            }
        }
    }

    /// Selected glyph: `.radio` (row-shaped presets' default), `.checkmark`
    /// (tile-shaped presets' default), or `.none` — the selected chrome alone
    /// signals the choice. Tile-shaped presets ignore `.radio` (no glyph).
    func indicator(_ i: SelectionIndicator) -> Self { copy { $0.indicatorOverride = i } }

    /// Grid column count, clamped 1…4 (default 2). The accessibility-size
    /// vertical fallback is unaffected.
    func columns(_ n: Int) -> Self { copy { $0.columnsValue = min(4, max(1, n)) } }

    /// Replaces the built-in row/tile anatomy with caller content, built per
    /// `(option, isSelected)` in every style. Selection tap handling,
    /// disabling and VoiceOver traits are preserved around the slot; the
    /// tile-shaped presets keep their selected chrome (fill/stroke/badge)
    /// around it.
    func optionContent(@ViewBuilder _ content: @escaping (PaymentMethodOption, Bool) -> some View) -> Self {
        copy { $0.optionSlot = { AnyView(content($0, $1)) } }
    }

    /// Style of the per-option badges (default `.info`) — applies wherever
    /// the active style draws the `Badge` itself (tiles, carousel, compact
    /// rows); the `.list`/`.sectioned` row's badge is drawn by `ListRow`.
    func badgeStyle(_ s: BadgeStyle) -> Self { copy { $0.badgeStyleValue = s } }

    /// Corner role for tile-shaped presets (default `.field`).
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

    /// Surface token for the *unselected* tile-shaped presets' fill (default
    /// `.bgBase`); the selected tile keeps the accent tint and stroke.
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
                        .emphasis(.strong)
                        .radius(.box)
                        .badge("New", for: "wallet")
                        .badgeStyle(.success)
                        .header {
                            Text("How would you like to pay?").textStyle(.headingSm)
                        }
                        .paymentMethodSelectorStyle(.carousel)

                    ListSectionHeader("Compact list · checkmark indicator")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "wallet", kind: .wallet, title: "Digital wallet"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], selection: $method)
                        .indicator(.checkmark)
                        .paymentMethodSelectorStyle(.compactList)

                    ListSectionHeader("Grid · 3 columns · custom option slot")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Card"),
                        .init(id: "wallet", kind: .wallet, title: "Wallet"),
                        .init(id: "transfer", kind: .transfer, title: "Transfer"),
                    ], selection: $method)
                        .columns(3)
                        .indicator(.none)
                        .optionContent { option, isSelected in
                            VStack(spacing: Theme.SpacingKey.xs.value) {
                                Icon(systemName: option.systemImage).size(.lg)
                                Text(option.title).textStyle(isSelected ? .labelSm700 : .labelSm600)
                            }
                        }
                        .paymentMethodSelectorStyle(.grid)
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Sectioned · grid · dark") {
    struct Demo: View {
        @State private var method: String? = "wallet"
        var body: some View {
            let dark = Theme()
            dark.loadTheme(named: Theme.defaultThemeName, dark: true)
            return VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                ListSectionHeader("Sectioned — cards / wallets / other")
                PaymentMethodSelector([
                    .init(id: "card", kind: .card, title: "Visa •••• 4242"),
                    .init(id: "card2", kind: .card, title: "Corporate card"),
                    .init(id: "wallet", kind: .wallet, title: "Wallet", subtitle: "One tap"),
                    .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                ], selection: $method)
                    .badge("New", for: "wallet")
                    .paymentMethodSelectorStyle(.sectioned)

                ListSectionHeader("Grid · surface(.bgWhite)")
                PaymentMethodSelector([
                    .init(id: "card", kind: .card, title: "Card"),
                    .init(id: "wallet", kind: .wallet, title: "Wallet"),
                ], initiallySelected: "card")
                    .surface(.bgWhite)
                    .paymentMethodSelectorStyle(.grid)
            }
            .padding()
            .background(dark.background(.bgBase))
            .theme(dark)
        }
    }
    return Demo()
}
