//
//  FareFamilyCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``FareFamilyCard`` (ADR-0004, Wave 3 — Class A). The
//  configuration hands styles the tier's *typed data* (name, price, features,
//  selection), not pre-laid content, so a style owns the entire arrangement.
//  Four built-ins:
//
//    .stacked    leading chip, feature list, price footer — today's card. Default.
//    .column     a narrow comparison-matrix column — several sit side by side.
//    .row        horizontal strip: chip+features leading, price+selector trailing.
//    .accordion  a collapsed tier whose feature list expands in place; the
//                price/selector row stays visible whether collapsed or open.
//
//      FareFamilyCard("Super Eco", price: 1_871.99)
//          .accent(.success)
//          .features([FareFeature("Cabin bag", systemImage: "handbag", detail: "55×40×23")])
//          .onSelect { book() }
//          .fareFamilyCardStyle(.row)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints *chrome* (every built-in here is card-shaped and keeps
//  routing its surface, elevation, selection and radius through `\.cardStyle`);
//  the token theme colors everything. The component resolves MicroMotion /
//  Reduce Motion before calling a style — styles read
//  ``FareFamilyCardConfiguration/isMotionEnabled`` and
//  ``FareFamilyCardConfiguration/isExpanded``, never the motion/expansion state
//  themselves.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FareFamilyCardStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no features → no feature list, a custom `footer`
/// slot → the built-in price/selector row never renders).
public struct FareFamilyCardConfiguration {
    /// The fare-family tier name, e.g. "Super Eco" — the built-in chip's label.
    public let name: String
    /// The fare amount; presets format it with ``currencyCode`` (via `PriceTag`
    /// or ``ctaTitle``'s pre-resolved text).
    public let priceAmount: Decimal
    /// Currency code for ``priceAmount`` — already resolved by the component
    /// through the FormatDefaults chain (explicit `.currency(_:)` →
    /// `formatDefaults` → `locale.currency` → `"USD"`).
    public let currencyCode: String
    /// The feature & rule lines (baggage, refund policy, amenities…).
    public let features: [FareFeature]
    /// Selected state — combines the caller's `.selected(_:)` flag with a live
    /// `.selection(_:)` binding's `wrappedValue` (component-resolved). Card-
    /// shaped presets feed it to the `CardStyle` shell and any radio control.
    public let isSelected: Bool
    /// `true` when the card was bound with `.selection(_:)` — presets render a
    /// price + radio row driven by ``isSelected``/``select``. `false` (the
    /// default) renders a price/CTA button titled with ``ctaTitle``.
    public let showsSelector: Bool
    /// Selects the tier — sets the `.selection(_:)` binding (when bound) and
    /// fires `.onSelect(_:)` (when set). Call from a radio control or a CTA.
    public let select: () -> Void
    /// The footer CTA's title — already merged (`.ctaTitle(_:)` override, else
    /// the formatted price) and re-resolved every body pass, so a live locale/
    /// currency switch is never frozen.
    public let ctaTitle: String
    /// Fill treatment of the tier name chip (`.solid`, `.soft`, `.outline`, `.ghost`).
    public let badgeVariant: FillVariant
    /// Replacement for the built-in tier chip (`.header { }`); `nil` = built-in.
    public let header: AnyView?
    /// Replacement for the built-in price/selector footer (`.footer { }`); `nil` = built-in.
    public let footer: AnyView?
    /// Shell elevation, fed to the active `CardStyle` (default `.none` — the
    /// classic flat, hairline-only chrome).
    public let elevation: CardElevation
    /// The tier accent — brands the chip, icons and CTA. Non-optional: a fare
    /// family always carries a brand tint (`.success` unless overridden).
    public let accent: SemanticColor
    /// Explicit surface fill, or `nil` to let the preset choose its own default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Expansion state for `.accordion` — ignored by every other preset.
    /// Uncontrolled by default; `.expanded(_:)` swaps in the caller's binding.
    public let isExpanded: Bool
    /// Flips ``isExpanded`` (MicroMotion-gated by the component). `.accordion`'s
    /// disclosure control calls this.
    public let toggleExpand: () -> Void
    /// Micro-animations resolved by the component (`MicroMotion` ∧ ¬Reduce
    /// Motion) — gate symbol effects/rotations on this; never read the motion
    /// environment directly.
    public let isMotionEnabled: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — pass to any
    /// locale-sensitive formatting so injected locales/RTL demos render right.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the preset's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the card.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

/// A synthesized `Binding` for `RadioButton` — reads the resolved selection,
/// and any tap calls ``FareFamilyCardConfiguration/select()``. Radio selection
/// here is one-way (there's no "deselect" gesture on the control), mirroring
/// `SavedCardsList.isSelectedBinding(_:)`.
private extension FareFamilyCardConfiguration {
    var selectorBinding: Binding<Bool> {
        Binding(get: { isSelected }, set: { _ in select() })
    }
}

// MARK: - Protocol

/// Defines a `FareFamilyCard`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's tier data. Set one with `.fareFamilyCardStyle(_:)`;
/// the default is ``StandardFareFamilyCardStyle``.
public protocol FareFamilyCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FareFamilyCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The tier name chip, rendered per ``FillVariant`` on the accent's ladder —
/// shared by every built-in preset (`.header { }` replaces it).
private struct FareFamilyTierChip: View {
    @Environment(\.theme) private var theme
    let configuration: FareFamilyCardConfiguration

    private var resolvedAccent: SemanticColor.Resolved { theme.resolve(configuration.accent) }

    var body: some View {
        Text(configuration.name.uppercased())
            .textStyle(.labelSm700)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(background,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            .overlay {
                if configuration.badgeVariant == .outline {
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .strokeBorder(resolvedAccent.border, lineWidth: 1)
                }
            }
    }

    private var foreground: Color {
        switch configuration.badgeVariant {
        case .solid: return resolvedAccent.onSolid
        case .soft, .outline, .ghost: return resolvedAccent.accent
        }
    }
    private var background: Color {
        switch configuration.badgeVariant {
        case .solid: return resolvedAccent.solid
        case .soft: return resolvedAccent.soft
        case .outline, .ghost: return .clear
        }
    }
}

/// The feature & rule lines, one ``FareFeatureRow`` per line — shared by every
/// built-in preset.
private struct FareFamilyFeatureList: View {
    let features: [FareFeature]
    var spacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(features) { FareFeatureRow($0) }
        }
    }
}

/// The default horizontal price/selector footer — a price + radio row when the
/// card carries a `.selection(_:)` binding (``showsSelector``), else a
/// full-width CTA button titled with ``ctaTitle``. Shared by `.stacked` and
/// `.accordion`.
private struct FareFamilyFooterRow: View {
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        if configuration.showsSelector {
            HStack {
                PriceTag(configuration.priceAmount, currencyCode: configuration.currencyCode).emphasis(.hero)
                Spacer()
                RadioButton(isSelected: configuration.selectorBinding)
            }
            .padding(.top, 2)
        } else {
            ThemeButton(configuration.ctaTitle) { configuration.select() }
                .color(configuration.accent).shape(.rounded).fullWidth()
                .padding(.top, 4)
        }
    }
}

/// The narrow comparison-column footer — price above the control, centered,
/// pinned at the bottom. Used by `.column`.
private struct FareFamilyColumnFooter: View {
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        if configuration.showsSelector {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                PriceTag(configuration.priceAmount, currencyCode: configuration.currencyCode).emphasis(.hero)
                RadioButton(isSelected: configuration.selectorBinding)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        } else {
            ThemeButton(configuration.ctaTitle) { configuration.select() }
                .color(configuration.accent).shape(.rounded).size(.small).fullWidth()
                .padding(.top, 4)
        }
    }
}

// MARK: - .stacked

/// Today's ``FareFamilyCard`` look, extracted verbatim: leading tier chip, the
/// feature list, and a price/CTA footer inside the active `CardStyle` shell.
public struct StandardFareFamilyCardStyle: FareFamilyCardStyle {
    public init() {}
    public func makeBody(configuration: FareFamilyCardConfiguration) -> some View {
        StandardFareFamilyCardChrome(configuration: configuration)
    }
}

private struct StandardFareFamilyCardChrome: View {
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
            .contentShape(Rectangle())
            .onTapGesture { if configuration.showsSelector { configuration.select() } }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header } else { FareFamilyTierChip(configuration: configuration) }

            if !configuration.features.isEmpty {
                FareFamilyFeatureList(features: configuration.features, spacing: 8)
            }

            if let footer = configuration.footer { footer } else { FareFamilyFooterRow(configuration: configuration) }
        }
        .padding(configuration.spacing(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - .column

/// A narrow comparison-matrix column: centered chip, condensed features, price
/// pinned at the bottom. Place several side by side in an `HStack`.
public struct ColumnFareFamilyCardStyle: FareFamilyCardStyle {
    public init() {}
    public func makeBody(configuration: FareFamilyCardConfiguration) -> some View {
        ColumnFareFamilyCardChrome(configuration: configuration)
    }
}

private struct ColumnFareFamilyCardChrome: View {
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
            .contentShape(Rectangle())
            .onTapGesture { if configuration.showsSelector { configuration.select() } }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            Group {
                if let header = configuration.header { header } else { FareFamilyTierChip(configuration: configuration) }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if !configuration.features.isEmpty {
                FareFamilyFeatureList(features: configuration.features, spacing: 6)
            }

            Spacer(minLength: 0)

            if let footer = configuration.footer { footer } else { FareFamilyColumnFooter(configuration: configuration) }
        }
        .padding(configuration.spacing(.sm))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - .row

/// A horizontal comparison strip: chip + features leading, price + selector
/// trailing. For dense fare-picker lists where each tier is one row instead of
/// a stacked card (Google Flights / Kayak fare-compare rows).
public struct RowFareFamilyCardStyle: FareFamilyCardStyle {
    public init() {}
    public func makeBody(configuration: FareFamilyCardConfiguration) -> some View {
        RowFareFamilyCardChrome(configuration: configuration)
    }
}

private struct RowFareFamilyCardChrome: View {
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(rowContent),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
            .contentShape(Rectangle())
            .onTapGesture { if configuration.showsSelector { configuration.select() } }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: configuration.spacing(.md)) {
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                if let header = configuration.header { header } else { FareFamilyTierChip(configuration: configuration) }
                if !configuration.features.isEmpty {
                    FareFamilyFeatureList(features: configuration.features, spacing: 4)
                }
            }
            Spacer(minLength: configuration.spacing(.sm))
            if let footer = configuration.footer { footer } else { trailingBlock }
        }
        .padding(configuration.spacing(.md))
    }

    private var trailingBlock: some View {
        VStack(alignment: .trailing, spacing: Theme.SpacingKey.xs.value) {
            PriceTag(configuration.priceAmount, currencyCode: configuration.currencyCode).emphasis(.hero).size(.medium)
            if configuration.showsSelector {
                RadioButton(isSelected: configuration.selectorBinding).accent(configuration.accent)
            } else {
                ThemeButton(configuration.ctaTitle) { configuration.select() }
                    .color(configuration.accent).shape(.rounded).size(.small)
            }
        }
    }
}

// MARK: - .accordion

/// A collapsed tier whose feature list expands in place — the price/selector
/// row stays visible whether collapsed or open, so a traveler can compare
/// prices at a glance and only expand the tier they're weighing. The whole
/// card is deliberately NOT a tap target (unlike `.stacked`/`.column`/`.row`):
/// the disclosure chevron and the selector each own one unambiguous gesture.
public struct AccordionFareFamilyCardStyle: FareFamilyCardStyle {
    public init() {}
    public func makeBody(configuration: FareFamilyCardConfiguration) -> some View {
        AccordionFareFamilyCardChrome(configuration: configuration)
    }
}

private struct AccordionFareFamilyCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FareFamilyCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(accordionContent),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    private var accordionContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            disclosureHeader

            if configuration.isExpanded, !configuration.features.isEmpty {
                FareFamilyFeatureList(features: configuration.features, spacing: 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let footer = configuration.footer { footer } else { FareFamilyFooterRow(configuration: configuration) }
        }
        .padding(configuration.spacing(.md))
    }

    private var disclosureHeader: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header } else { FareFamilyTierChip(configuration: configuration) }
            Spacer(minLength: configuration.spacing(.xs))
            Button(action: configuration.toggleExpand) {
                Icon(systemName: "chevron.down")
                    .size(.xs)
                    .color(theme.text(.textTertiary))
                    .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isExpanded
                ? String(themeKit: "Collapse fare details")
                : String(themeKit: "Expand fare details"))
        }
    }
}

// MARK: - Static accessors

public extension FareFamilyCardStyle where Self == StandardFareFamilyCardStyle {
    /// Leading tier chip + feature list + price/CTA footer — today's card. The default.
    static var stacked: StandardFareFamilyCardStyle { StandardFareFamilyCardStyle() }
}
public extension FareFamilyCardStyle where Self == ColumnFareFamilyCardStyle {
    /// A narrow comparison-matrix column — several sit side by side in an `HStack`.
    static var column: ColumnFareFamilyCardStyle { ColumnFareFamilyCardStyle() }
}
public extension FareFamilyCardStyle where Self == RowFareFamilyCardStyle {
    /// A horizontal strip: chip + features leading, price + selector trailing.
    static var row: RowFareFamilyCardStyle { RowFareFamilyCardStyle() }
}
public extension FareFamilyCardStyle where Self == AccordionFareFamilyCardStyle {
    /// A collapsed tier that expands its feature list; the price/selector row
    /// stays visible whether collapsed or open.
    static var accordion: AccordionFareFamilyCardStyle { AccordionFareFamilyCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFareFamilyCardStyle: FareFamilyCardStyle {
    private let _makeBody: @MainActor (FareFamilyCardConfiguration) -> AnyView
    init<S: FareFamilyCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FareFamilyCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FareFamilyCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyFareFamilyCardStyle(StandardFareFamilyCardStyle())
}

extension EnvironmentValues {
    var fareFamilyCardStyle: AnyFareFamilyCardStyle {
        get { self[FareFamilyCardStyleKey.self] }
        set { self[FareFamilyCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FareFamilyCardStyle`` for `FareFamilyCard`s in this view and
    /// its descendants — a fare-compare screen can mix archetypes per section.
    func fareFamilyCardStyle<S: FareFamilyCardStyle>(_ style: sending S) -> some View {
        environment(\.fareFamilyCardStyle, AnyFareFamilyCardStyle(style))
    }
}

// MARK: - Previews

/// Proves external implementability: a borderless pill — no `CardStyle` shell
/// at all, just the name, price and a selector, built purely from the public
/// configuration + theme tokens.
private struct PillFareFamilyCardStyle: FareFamilyCardStyle {
    func makeBody(configuration: FareFamilyCardConfiguration) -> some View {
        PillChrome(configuration: configuration)
    }

    private struct PillChrome: View {
        @Environment(\.theme) private var theme
        let configuration: FareFamilyCardConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                Circle().fill(theme.resolve(configuration.accent).base).frame(width: 8, height: 8)
                Text(configuration.name).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                PriceTag(configuration.priceAmount, currencyCode: configuration.currencyCode).size(.small)
                if configuration.showsSelector {
                    RadioButton(isSelected: configuration.selectorBinding).accent(configuration.accent)
                } else {
                    ThemeButton(configuration.ctaTitle) { configuration.select() }
                        .color(configuration.accent).shape(.pill).size(.small)
                }
            }
            .padding(configuration.spacing(.sm))
            .background(theme.background(.bgSecondaryLight), in: Capsule())
        }
    }
}

#Preview("FareFamilyCardStyle — presets × light/dark") {
    @Previewable @State var picked = true
    let features: [FareFeature] = [
        FareFeature("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm"),
        FareFeature("Carry-on", systemImage: "suitcase.rolling", detail: "55×40×23 cm"),
        FareFeature("Non-refundable", systemImage: "nosign", status: .excluded),
    ]
    let radioCard = FareFamilyCard("Super Eco", price: 1_871.99)
        .accent(.success).features(features).selection($picked)
    let ctaCard = FareFamilyCard("Comfort Flex", price: 3_116.99)
        .accent(.purple).features(features).onSelect { }
    PreviewMatrix("FareFamilyCardStyle") {
        PreviewCase("Stacked (default) · radio") { radioCard }
        PreviewCase("Stacked · CTA") { ctaCard }
        PreviewCase("Column · radio") { radioCard.fareFamilyCardStyle(.column).frame(width: 170) }
        PreviewCase("Column · CTA") { ctaCard.fareFamilyCardStyle(.column).frame(width: 170) }
        PreviewCase("Row · radio") { radioCard.fareFamilyCardStyle(.row) }
        PreviewCase("Row · CTA") { ctaCard.fareFamilyCardStyle(.row) }
        PreviewCase("Accordion · collapsed") { radioCard.fareFamilyCardStyle(.accordion) }
        PreviewCase("Accordion · expanded") {
            ctaCard.expanded(.constant(true)).fareFamilyCardStyle(.accordion)
        }
        PreviewCase("Custom (in-preview)") { ctaCard.fareFamilyCardStyle(PillFareFamilyCardStyle()) }
    }
}
