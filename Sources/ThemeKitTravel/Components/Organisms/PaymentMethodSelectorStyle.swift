//
//  PaymentMethodSelectorStyle.swift
//  ThemeKitTravel
//
//  The styling hook for ``PaymentMethodSelector`` (ADR-0004, Class A — the
//  component owns the *data*: options, selection, instalments, badges; the
//  style owns the entire arrangement). Five built-ins:
//
//    .list         radio rows via the neutral `ListRow` anatomy — default.
//    .grid         selection tiles (vertical fallback at a11y sizes).
//    .carousel     horizontally-snapping tiles.
//    .compactList  dense single-line rows.
//    .sectioned    grouped rows — cards / wallets / other, with section headers.
//
//      PaymentMethodSelector(options, selection: $method)
//          .installments([1, 3, 6, 9], selection: $months, total: fareTotal)
//          .paymentMethodSelectorStyle(.grid)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything (this component has no shell `CardStyle` chrome to
//  delegate to — its surfaces are drawn directly, gated by ``surface(default:)``).
//  The component resolves MicroMotion / Reduce Motion and read-only state
//  before calling a style — styles read ``PaymentMethodSelectorConfiguration``
//  fields only, never the motion/read-only environment themselves.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``PaymentMethodSelectorStyle`` lays out. Fields a given
/// style doesn't use are simply ignored — every built-in degrades gracefully
/// when optional data is absent (no instalments configured → no inline picker,
/// no badge for an option → no chip).
public struct PaymentMethodSelectorConfiguration {
    /// The payment methods to choose among, in caller order.
    public let options: [PaymentMethodOption]
    /// The selected option id, or `nil` when nothing is chosen yet.
    public let selectedID: String?
    /// Selects an option by id. Already gated on read-only by the component —
    /// styles call this from taps/rows without re-checking `isReadOnly`.
    public let select: (String) -> Void
    /// The pre-built, accent-styled inline instalment picker for the selected
    /// `.card` option (composes the neutral `InstallmentPicker`), or `nil` when
    /// instalments aren't configured, nothing is selected, or the selection
    /// isn't a card. Row-shaped styles place it directly under the matching
    /// row; tile-shaped styles place it once, below the whole tile layout.
    public let installmentsSlot: AnyView?
    /// Per-option badge text (`PaymentMethodSelector.badge(_:for:)`), keyed by
    /// option id.
    public let badges: [String: String]
    /// Option ids rendered disabled and excluded from selection.
    public let disabledMethods: Set<String>
    /// The explicit `.indicator(_:)` override, or `nil` to let the style pick
    /// its own natural default — resolve via ``indicator(default:)``.
    public let indicatorOverride: SelectionIndicator?
    /// Grid column count, clamped 1…4 (default 2); the a11y-size vertical
    /// fallback ignores it.
    public let columns: Int
    /// Replacement for the built-in row/tile anatomy, built per
    /// `(option, isSelected)`; `nil` = built-in. Selection tap handling,
    /// disabling and VoiceOver traits stay owned by the style around this slot.
    public let optionContent: ((PaymentMethodOption, Bool) -> AnyView)?
    /// Style of the per-option badges (default `.info`).
    public let badgeStyle: BadgeStyle
    /// Top-aligned accessory area (`.header { }`); `nil` = none.
    public let header: AnyView?
    /// Bottom-aligned accessory area (`.footer { }`); `nil` = none.
    public let footer: AnyView?
    /// Corner-radius role for tile-shaped styles (default `.field`).
    public let radiusRole: Theme.RadiusRole
    /// Selected-tile stroke strength for tile-shaped styles.
    public let emphasis: TileEmphasis
    /// Semantic tint for the radio / selected chrome / instalment rows;
    /// `nil` uses the primary triad.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its own default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Read-only state, captured by the component (`\.isReadOnly`) — styles
    /// that build their own tap surface (not through ``select``/`ListRow`)
    /// should gate hit-testing on it, mirroring the built-ins.
    public let isReadOnly: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component, for any future
    /// locale-formatted content a custom style may add.
    public let locale: Locale

    /// The `accent(_:)` override's base color — the value the built-ins use
    /// for the radio, selected icon tint and selected tile stroke.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use accentBase(_ theme:)")
    public var accentBase: Color { accentBase(.shared) }
    /// Theme-parameterized twin of ``accentBase`` — resolves against the
    /// environment theme (ADR-0006), honoring per-subtree `.theme(_:)`.
    public func accentBase(_ theme: Theme) -> Color { theme.resolve(accent ?? .primary).base }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the selector.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The explicit `indicator(_:)` override, or a style's natural default
    /// (`.radio` for row-shaped styles, `.checkmark` for tile-shaped ones).
    public func indicator(default fallback: SelectionIndicator) -> SelectionIndicator {
        indicatorOverride ?? fallback
    }

    /// Radio-style binding for one option: setting `true` selects it via
    /// ``select``; a payment method can't be deselected by tapping its own
    /// radio (mirrors native radio-group semantics).
    public func isSelectedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedID == id },
            set: { if $0 { select(id) } }
        )
    }
}

// MARK: - Protocol

/// Defines a `PaymentMethodSelector`'s entire presentation. Implement
/// `makeBody` to lay out the configuration's options. Set one with
/// `.paymentMethodSelectorStyle(_:)`; the default is ``ListPaymentMethodSelectorStyle``.
public protocol PaymentMethodSelectorStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PaymentMethodSelectorConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The header/content/footer frame every preset shares — matches the
/// pre-style component's outer `VStack` verbatim (header slot above, footer
/// slot below, `.sm`-spaced).
private extension View {
    @ViewBuilder
    func selectorFrame(_ configuration: PaymentMethodSelectorConfiguration) -> some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header }
            self
            if let footer = configuration.footer { footer }
        }
    }
}

/// Wraps a per-option slot in the selection button, preserving tap handling,
/// disabling and VoiceOver traits — shared by every built-in that draws its
/// own row/tile chrome (the `.list`/`.sectioned` `ListRow` anatomy handles its
/// own tap surface and doesn't use this wrapper).
private struct PaymentOptionButton<Content: View>: View {
    let configuration: PaymentMethodSelectorConfiguration
    let option: PaymentMethodOption
    let content: () -> Content

    init(configuration: PaymentMethodSelectorConfiguration, option: PaymentMethodOption,
         @ViewBuilder content: @escaping () -> Content) {
        self.configuration = configuration
        self.option = option
        self.content = content
    }

    private var isOn: Bool { configuration.selectedID == option.id }
    private var isDisabled: Bool { configuration.disabledMethods.contains(option.id) }

    var body: some View {
        Button { configuration.select(option.id) } label: {
            content().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .allowsHitTesting(!configuration.isReadOnly)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Genuine dimensions with no semantic token — fixed tile constants, shared
/// by the `.grid` and `.carousel` tile builders.
private enum Metrics {
    static let carouselTileWidth: CGFloat = 148
    static let tileMinHeight: CGFloat = 88
}

/// The shared row anatomy for `.list` and `.sectioned` — a `ListRow`-based
/// radio row with the built-in leading indicator + icon, the per-option
/// badge, an optional selected checkmark, and the inline instalment picker
/// directly beneath the row when this option is the selected `.card` method.
private struct PaymentOptionRow: View {
    @Environment(\.theme) private var theme
    let configuration: PaymentMethodSelectorConfiguration
    let option: PaymentMethodOption

    private var isOn: Bool { configuration.selectedID == option.id }

    var body: some View {
        VStack(spacing: 0) {
            content
            if isOn, let installmentsSlot = configuration.installmentsSlot {
                installmentsSlot.padding(.bottom, configuration.spacing(.sm))
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let optionContent = configuration.optionContent {
            PaymentOptionButton(configuration: configuration, option: option) {
                optionContent(option, isOn)
            }
        } else {
            builtInRow
        }
    }

    private var builtInRow: some View {
        var listRow = ListRow(option.title) { configuration.select(option.id) }
            .subtitle(option.subtitle)
            .leading {
                HStack(spacing: configuration.spacing(.sm)) {
                    if configuration.indicator(default: .radio) == .radio {
                        RadioButton(isSelected: configuration.isSelectedBinding(option.id))
                            .accent(configuration.accent)
                    }
                    Icon(systemName: option.systemImage)
                        .size(.sm)
                        .color(isOn ? configuration.accentBase(theme) : theme.text(.textSecondary))
                }
            }
            .badge(configuration.badges[option.id])
            .selected(isOn)
        if configuration.indicator(default: .radio) == .checkmark, isOn {
            listRow = listRow.trailing {
                Icon(systemName: "checkmark").size(.sm).color(configuration.accentBase(theme))
            }
        } else {
            listRow = listRow.trailing(ListRowTrailing.none)
        }
        return listRow
            .disabled(configuration.disabledMethods.contains(option.id))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// The dense single-line row used by `.compactList` — icon, title, badge and
/// an optional trailing checkmark on one line, plus the inline instalment
/// picker beneath it when this option is the selected `.card` method.
private struct PaymentOptionCompactRow: View {
    @Environment(\.theme) private var theme
    let configuration: PaymentMethodSelectorConfiguration
    let option: PaymentMethodOption

    private var isOn: Bool { configuration.selectedID == option.id }
    private var isDisabled: Bool { configuration.disabledMethods.contains(option.id) }

    var body: some View {
        VStack(spacing: 0) {
            PaymentOptionButton(configuration: configuration, option: option) {
                if let optionContent = configuration.optionContent {
                    optionContent(option, isOn)
                } else {
                    builtInRow
                }
            }
            if isOn, let installmentsSlot = configuration.installmentsSlot {
                installmentsSlot.padding(.bottom, configuration.spacing(.sm))
            }
        }
    }

    private var builtInRow: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if configuration.indicator(default: .radio) == .radio {
                RadioButton(isSelected: configuration.isSelectedBinding(option.id))
                    .accent(configuration.accent)
            }
            Icon(systemName: option.systemImage)
                .size(.sm)
                .color(isDisabled ? theme.text(.textDisabled)
                       : (isOn ? configuration.accentBase(theme) : theme.text(.textSecondary)))
            Text(option.title)
                .textStyle(.labelBase600)
                .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
                .lineLimit(1)
            Spacer(minLength: configuration.spacing(.xs))
            if let badgeText = configuration.badges[option.id] {
                Badge(badgeText).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small)
            }
            if configuration.indicator(default: .radio) == .checkmark, isOn {
                Icon(systemName: "checkmark").size(.sm).color(configuration.accentBase(theme))
            }
        }
        .padding(.vertical, configuration.spacing(.xs))
    }
}

/// The shared tile anatomy for `.grid` and `.carousel` — icon, title,
/// optional subtitle and an optional selected checkmark, on a token-filled,
/// selection-stroked surface with a top-trailing badge overlay.
private struct PaymentOptionTile: View {
    @Environment(\.theme) private var theme
    let configuration: PaymentMethodSelectorConfiguration
    let option: PaymentMethodOption

    private var isOn: Bool { configuration.selectedID == option.id }
    private var isDisabled: Bool { configuration.disabledMethods.contains(option.id) }

    /// Selected-stroke color/width from the emphasis axis — named semantic
    /// steps only (`base` / `strong`).
    private var selectedStroke: (color: Color, width: CGFloat) {
        switch configuration.emphasis {
        case .subtle: return (configuration.accentBase(theme), 1.5)
        case .strong: return (theme.resolve(configuration.accent ?? .primary).strong, 2)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: configuration.radiusRole.value, style: .continuous)
        PaymentOptionButton(configuration: configuration, option: option) {
            Group {
                if let optionContent = configuration.optionContent {
                    optionContent(option, isOn)
                } else {
                    builtInLabel
                }
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.tileMinHeight)
            .padding(configuration.spacing(.md))
            .background(isOn ? theme.resolve(configuration.accent ?? .primary).bg
                        : theme.background(configuration.surface(default: .bgBase)), in: shape)
            .overlay(shape.stroke(isOn ? selectedStroke.color : theme.border(.borderPrimary),
                                  lineWidth: isOn ? selectedStroke.width : 1))
            .overlay(alignment: .topTrailing) {
                if let badgeText = configuration.badges[option.id] {
                    Badge(badgeText).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small)
                        .padding(configuration.spacing(.xs))
                }
            }
            .contentShape(shape)
        }
    }

    private var builtInLabel: some View {
        VStack(spacing: configuration.spacing(.xs)) {
            Icon(systemName: option.systemImage)
                .size(.md)
                .color(isDisabled ? theme.text(.textDisabled)
                       : (isOn ? configuration.accentBase(theme) : theme.text(.textSecondary)))
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
            if configuration.indicator(default: .checkmark) == .checkmark, isOn {
                Icon(systemName: "checkmark.circle.fill").size(.sm).color(configuration.accentBase(theme))
            }
        }
    }
}

// MARK: - .list

/// Today's ``PaymentMethodSelector`` look, extracted verbatim: radio rows via
/// the neutral `ListRow` anatomy, a hairline divider between options, and the
/// inline instalment picker directly under the selected `.card` row.
public struct ListPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    public init() {}
    public func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        ListPaymentMethodSelectorChrome(configuration: configuration)
    }
}

private struct ListPaymentMethodSelectorChrome: View {
    let configuration: PaymentMethodSelectorConfiguration

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(configuration.options.enumerated()), id: \.element.id) { index, option in
                PaymentOptionRow(configuration: configuration, option: option)
                if index < configuration.options.count - 1 {
                    DividerView().size(.small)
                }
            }
        }
        .selectorFrame(configuration)
    }
}

// MARK: - .compactList

/// Dense single-line rows — a compact alternative to `.list` for tight
/// checkout summaries.
public struct CompactListPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    public init() {}
    public func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        CompactListPaymentMethodSelectorChrome(configuration: configuration)
    }
}

private struct CompactListPaymentMethodSelectorChrome: View {
    let configuration: PaymentMethodSelectorConfiguration

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(configuration.options.enumerated()), id: \.element.id) { index, option in
                PaymentOptionCompactRow(configuration: configuration, option: option)
                if index < configuration.options.count - 1 {
                    DividerView().size(.small)
                }
            }
        }
        .selectorFrame(configuration)
    }
}

// MARK: - .grid

/// Selection tiles in a fixed-column grid (default 2 columns via
/// `.columns(_:)`), with a vertical fallback at accessibility Dynamic Type
/// sizes. The instalment picker, when applicable, renders once below the grid.
public struct GridPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    public init() {}
    public func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        GridPaymentMethodSelectorChrome(configuration: configuration)
    }
}

private struct GridPaymentMethodSelectorChrome: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let configuration: PaymentMethodSelectorConfiguration

    var body: some View { content.selectorFrame(configuration) }

    @ViewBuilder private var content: some View {
        let gap = configuration.spacing(.sm)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: gap) {
                ForEach(configuration.options) { PaymentOptionTile(configuration: configuration, option: $0) }
            }
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: configuration.columns),
                spacing: gap
            ) {
                ForEach(configuration.options) { PaymentOptionTile(configuration: configuration, option: $0) }
            }
        }
        if let installmentsSlot = configuration.installmentsSlot { installmentsSlot }
    }
}

// MARK: - .carousel

/// Horizontally-snapping selection tiles — a browsable strip for a wide
/// method list. The instalment picker, when applicable, renders once below
/// the strip.
public struct CarouselPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    public init() {}
    public func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        CarouselPaymentMethodSelectorChrome(configuration: configuration)
    }
}

private struct CarouselPaymentMethodSelectorChrome: View {
    let configuration: PaymentMethodSelectorConfiguration

    var body: some View { content.selectorFrame(configuration) }

    @ViewBuilder private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: configuration.spacing(.sm)) {
                ForEach(configuration.options) { option in
                    PaymentOptionTile(configuration: configuration, option: option)
                        .frame(width: Metrics.carouselTileWidth)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        if let installmentsSlot = configuration.installmentsSlot { installmentsSlot }
    }
}

// MARK: - .sectioned

/// Grouped rows under section headers — cards, wallets, then everything else
/// (Apple Pay/wallet sheets, checkout flows with a large method catalogue).
/// Reuses the `.list` row anatomy inside each section; empty sections collapse.
public struct SectionedPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    public init() {}
    public func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        SectionedPaymentMethodSelectorChrome(configuration: configuration)
    }
}

private struct SectionedPaymentMethodSelectorChrome: View {
    let configuration: PaymentMethodSelectorConfiguration

    /// Cards, then wallets, then everything else — empty groups are dropped.
    private var sections: [(title: String, options: [PaymentMethodOption])] {
        let cards = configuration.options.filter { $0.kind == .card }
        let wallets = configuration.options.filter { $0.kind == .wallet }
        let other = configuration.options.filter { $0.kind != .card && $0.kind != .wallet }
        return [
            (String(themeKitTravel: "Cards"), cards),
            (String(themeKitTravel: "Wallets"), wallets),
            (String(themeKitTravel: "Other"), other),
        ].filter { !$0.options.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 0) {
                    ListSectionHeader(section.title)
                    ForEach(Array(section.options.enumerated()), id: \.element.id) { index, option in
                        PaymentOptionRow(configuration: configuration, option: option)
                        if index < section.options.count - 1 {
                            DividerView().size(.small)
                        }
                    }
                }
            }
        }
        .selectorFrame(configuration)
    }
}

// MARK: - Static accessors

public extension PaymentMethodSelectorStyle where Self == ListPaymentMethodSelectorStyle {
    /// Radio rows via the neutral `ListRow` anatomy. The default.
    static var list: ListPaymentMethodSelectorStyle { ListPaymentMethodSelectorStyle() }
}
public extension PaymentMethodSelectorStyle where Self == GridPaymentMethodSelectorStyle {
    /// Selection tiles (vertical fallback at accessibility Dynamic Type sizes).
    static var grid: GridPaymentMethodSelectorStyle { GridPaymentMethodSelectorStyle() }
}
public extension PaymentMethodSelectorStyle where Self == CarouselPaymentMethodSelectorStyle {
    /// Horizontally-snapping selection tiles.
    static var carousel: CarouselPaymentMethodSelectorStyle { CarouselPaymentMethodSelectorStyle() }
}
public extension PaymentMethodSelectorStyle where Self == CompactListPaymentMethodSelectorStyle {
    /// Dense single-line rows.
    static var compactList: CompactListPaymentMethodSelectorStyle { CompactListPaymentMethodSelectorStyle() }
}
public extension PaymentMethodSelectorStyle where Self == SectionedPaymentMethodSelectorStyle {
    /// Grouped rows — cards / wallets / other — each under a section header.
    static var sectioned: SectionedPaymentMethodSelectorStyle { SectionedPaymentMethodSelectorStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    private let _makeBody: @MainActor (PaymentMethodSelectorConfiguration) -> AnyView
    init<S: PaymentMethodSelectorStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PaymentMethodSelectorConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PaymentMethodSelectorStyleKey: EnvironmentKey {
    static let defaultValue = AnyPaymentMethodSelectorStyle(ListPaymentMethodSelectorStyle())
}

extension EnvironmentValues {
    var paymentMethodSelectorStyle: AnyPaymentMethodSelectorStyle {
        get { self[PaymentMethodSelectorStyleKey.self] }
        set { self[PaymentMethodSelectorStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PaymentMethodSelectorStyle`` for `PaymentMethodSelector`s in
    /// this view and its descendants — one checkout screen can mix archetypes
    /// per section.
    func paymentMethodSelectorStyle<S: PaymentMethodSelectorStyle>(_ style: sending S) -> some View {
        environment(\.paymentMethodSelectorStyle, AnyPaymentMethodSelectorStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a single accent-tinted card wrapping plain option rows, no radio at
/// all (the card fill alone signals the choice).
private struct AccentCardPaymentMethodSelectorStyle: PaymentMethodSelectorStyle {
    func makeBody(configuration: PaymentMethodSelectorConfiguration) -> some View {
        AccentCardChrome(configuration: configuration)
    }

    private struct AccentCardChrome: View {
        @Environment(\.theme) private var theme
        let configuration: PaymentMethodSelectorConfiguration

        var body: some View {
            VStack(spacing: configuration.spacing(.sm)) {
                ForEach(configuration.options) { option in
                    let isOn = configuration.selectedID == option.id
                    Button { configuration.select(option.id) } label: {
                        HStack(spacing: configuration.spacing(.sm)) {
                            Icon(systemName: option.systemImage).size(.sm).color(configuration.accentBase(theme))
                            Text(option.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                            Spacer()
                            if isOn {
                                Icon(systemName: "checkmark.circle.fill").size(.sm).color(configuration.accentBase(theme))
                            }
                        }
                        .padding(configuration.spacing(.md))
                        .background(isOn ? theme.resolve(configuration.accent ?? .primary).bg : theme.background(.bgBase),
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                    }
                    .buttonStyle(.plain)
                }
            }
            .selectorFrame(configuration)
        }
    }
}

#Preview("PaymentMethodSelectorStyle — presets × light/dark") {
    let options: [PaymentMethodOption] = [
        .init(id: "card", kind: .card, title: "Credit / debit card"),
        .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
    ]
    PreviewMatrix("PaymentMethodSelectorStyle") {
        PreviewCase("List (default)") {
            PaymentMethodSelector(options, initiallySelected: "card").badge("No fee", for: "transfer")
        }
        PreviewCase("List · instalments") {
            PaymentMethodSelector(options, initiallySelected: "card")
                .installments([1, 3, 6], selection: .constant(3), total: 1_240)
        }
        PreviewCase("Grid") {
            PaymentMethodSelector(options, initiallySelected: "wallet").paymentMethodSelectorStyle(.grid)
        }
        PreviewCase("Carousel") {
            PaymentMethodSelector(options, initiallySelected: "card")
                .paymentMethodSelectorStyle(.carousel).frame(width: 320)
        }
        PreviewCase("Compact list") {
            PaymentMethodSelector(options, initiallySelected: "transfer").paymentMethodSelectorStyle(.compactList)
        }
        PreviewCase("Sectioned") {
            PaymentMethodSelector([
                .init(id: "card", kind: .card, title: "Visa •••• 4242"),
                .init(id: "card2", kind: .card, title: "Corporate card"),
                .init(id: "wallet", kind: .wallet, title: "Digital wallet"),
                .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
            ], initiallySelected: "card")
                .header { Text("How would you like to pay?").textStyle(.headingSm) }
                .paymentMethodSelectorStyle(.sectioned)
        }
        PreviewCase("Custom (in-preview)") {
            PaymentMethodSelector([
                .init(id: "card", kind: .card, title: "Card"),
                .init(id: "wallet", kind: .wallet, title: "Wallet"),
            ], initiallySelected: "card")
                .accent(.success)
                .paymentMethodSelectorStyle(AccentCardPaymentMethodSelectorStyle())
        }
    }
}
