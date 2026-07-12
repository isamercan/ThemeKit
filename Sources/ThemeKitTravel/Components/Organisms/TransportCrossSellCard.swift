//
//  TransportCrossSellCard.swift
//  ThemeKitTravel
//
//  Edition organism (F3.2 · ADR §9.8). "No flights? Take the bus/train" —
//  a cross-sell for an alternative transport mode: mode glyph, route,
//  price-from, optional CTA. Presentation is style-driven
//  (``TransportCrossSellCardStyle``, ADR-0004) — set once per screen via
//  `.transportCrossSellCardStyle(_:)`: `.ribbon` (default, a notched
//  TicketStub-technique coupon strip), `.inline` (a flat ListRow-anatomy
//  row), `.tile` (a compact vertical card for grids) or `.banner` (a
//  full-bleed, mode-tinted promo strip). Token-bound.
//
//  ```swift
//  TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
//      .price(19)                       // currency via the §10 env chain
//      .duration("6h 30m")
//      .departures("Every 30 min from Central Station")
//      .badge("Cheapest")
//      .onSelect { showBusOptions() }
//      .transportCrossSellCardStyle(.tile)
//  ```
//
//  Currency: the plain `price(_:caption:)` overload resolves the code through
//  the §10 chain inside `PriceTag` (`\.formatDefaults` > locale > "USD");
//  the explicit `price(_:currencyCode:caption:)` overload always wins.
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``TransportCrossSellCard``: notched strip (`.ribbon`),
/// flat row (`.inline`), or a compact vertical card for grids (`.tile`).
///
/// Superseded by ``TransportCrossSellCardStyle`` (each case maps 1:1 to a
/// preset — `.ribbon`/`.inline`/`.tile`, joined by the new `.banner` strip);
/// kept for source compatibility until the next major, together with the
/// deprecated ``TransportCrossSellCard/variant(_:)`` modifier.
public enum TransportCrossSellVariant: Sendable { case ribbon, inline, tile }

/// Size ramp of a ``TransportCrossSellCard`` — scales the mode glyph, the
/// `PriceTag` and the paddings together.
public enum TransportCrossSellSize: Sendable { case small, medium }

/// The ribbon's tear-line chrome: the TicketStub-style `.notched` cut with a
/// dashed perforation (default), or a `.plain` rounded strip with no cut.
public enum TearStyle: Sendable { case notched, plain }

/// A cross-sell for an alternative transport mode — "No flights? Take the
/// bus/train" — with a mode glyph, route endpoints, a lead-in price and a CTA.
///
/// ```swift
/// TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
///     .price(19)                       // currency via the §10 env chain
///     .duration("6h 30m")
///     .departures("Every 30 min from Central Station")
///     .badge("Cheapest")
///     .onSelect { showBusOptions() }
/// ```
public struct TransportCrossSellCard: View {
    /// Generic ground/sea transport modes (brand-neutral).
    public enum Mode: String, Sendable, CaseIterable {
        case bus, train, ferry, car

        var systemImage: String {
            switch self {
            case .bus: return "bus.fill"
            case .train: return "tram.fill"
            case .ferry: return "ferry.fill"
            case .car: return "car.fill"
            }
        }

        var displayName: String {
            switch self {
            case .bus: return String(themeKitTravel: "Bus")
            case .train: return String(themeKitTravel: "Train")
            case .ferry: return String(themeKitTravel: "Ferry")
            case .car: return String(themeKitTravel: "Car")
            }
        }

        /// Per-mode default tint (ADR §9.8; ferry maps to the palette's
        /// turquoise — the library has no separate cyan hue).
        var defaultAccent: SemanticColor {
            switch self {
            case .bus: return .warning
            case .train: return .info
            case .ferry: return .turquoise
            case .car: return .neutral
            }
        }
    }

    @Environment(\.transportCrossSellCardStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mode: Mode
    private let from: String
    private let to: String
    /// Custom-mode overrides — set only by the `customMode` init; when set
    /// they win over every `Mode`-derived value.
    private var customGlyph: String?
    private var customLabel: String?
    private var customAccent: SemanticColor?

    // Config — mutated only through the modifiers below (R2).
    private var priceAmount: Decimal?
    private var priceCurrencyCode: String?
    private var priceCaption: String?
    private var durationText: String?
    private var departuresNote: String?
    private var badgeText: String?
    private var ctaTitle: String?
    private var ctaAction: (() -> Void)?
    private var accentOverride: SemanticColor?
    private var logoSlot: AnyView?
    /// `nil` lets the active style pick its own default surface (`.bgBase`
    /// for `.ribbon`/`.tile`; `.banner` always uses the mode's soft tint).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var sizeValue: TransportCrossSellSize = .medium
    private var tearStyleValue: TearStyle = .notched
    private var badgeFillValue: FillVariant = .soft
    /// Replaces a preset's built-in CTA label/indicator (action preserved).
    private var ctaLabelSlot: AnyView?
    private var shadowStyleValue: ThemeKitCore.ShadowStyle = .soft
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's
    /// `.transportCrossSellCardStyle(_:)` (source-behavior stability during
    /// the enum's deprecation window, ADR-0004 §5).
    private var explicitStyle: AnyTransportCrossSellCardStyle?

    /// R1 — mode + route endpoints (display strings; cross-sell has no FlightLeg).
    public init(_ mode: Mode, from: String, to: String) {
        self.mode = mode
        self.from = from
        self.to = to
    }

    /// R1 overload — a transport mode beyond the built-in four (shuttle,
    /// funicular, ride-share…): its glyph, display label and default accent
    /// come from the caller; everything else behaves like a stock mode.
    public init(customMode systemImage: String, label: String, accent: SemanticColor,
                from: String, to: String) {
        self.mode = .bus   // inert — every mode-derived value is overridden
        self.from = from
        self.to = to
        self.customGlyph = systemImage
        self.customLabel = label
        self.customAccent = accent
    }

    private var accent: SemanticColor { accentOverride ?? customAccent ?? mode.defaultAccent }
    private var modeGlyph: String { customGlyph ?? mode.systemImage }
    private var modeLabel: String { customLabel ?? mode.displayName }
    private var motion: Animation? {
        MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
    }

    public var body: some View {
        // The active `TransportCrossSellCardStyle` owns the entire
        // presentation — built-ins and custom styles go through the same
        // gate. The default `.ribbon` reproduces the classic notched-coupon
        // look verbatim. Motion is resolved *here* (ADR-0004 §4): styles
        // never read the motion environment themselves.
        let configuration = TransportCrossSellCardConfiguration(
            modeGlyph: modeGlyph,
            modeLabel: modeLabel,
            from: from,
            to: to,
            priceAmount: priceAmount,
            priceCurrencyCode: priceCurrencyCode,
            priceCaption: priceCaption,
            durationText: durationText,
            departuresNote: departuresNote,
            badgeText: badgeText,
            badgeFillVariant: badgeFillValue,
            logo: logoSlot,
            ctaTitle: ctaTitle,
            ctaLabel: ctaLabelSlot,
            onSelect: ctaAction,
            isReadOnly: isReadOnly,
            size: sizeValue,
            tearStyle: tearStyleValue,
            accent: accent,
            surfaceKey: surfaceKey,
            shadowStyle: shadowStyleValue,
            density: density,
            locale: locale)
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            .animation(motion, value: priceAmount)
            .animation(motion, value: badgeText)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TransportCrossSellCard {
    /// Lead-in price; the currency code resolves via the §10 environment chain
    /// (`formatDefaults.currencyCode` → locale currency → "USD").
    /// `caption` replaces the default "from" lead-in; `nil` amount hides it.
    func price(_ amount: Decimal?, caption: String? = nil) -> Self {
        copy { $0.priceAmount = amount; $0.priceCaption = caption }
    }
    /// Lead-in price with an explicit ISO-4217 code (always wins over the env).
    func price(_ amount: Decimal?, currencyCode: String, caption: String? = nil) -> Self {
        copy { $0.priceAmount = amount; $0.priceCurrencyCode = currencyCode; $0.priceCaption = caption }
    }
    /// Journey duration, e.g. `"6h 30m"`.
    func duration(_ text: String?) -> Self { copy { $0.durationText = text } }
    /// Frequency/terminal note, e.g. `"Every 30 min from Central Station"`.
    func departures(_ note: String?) -> Self { copy { $0.departuresNote = note } }
    /// A short accent-tinted flag, e.g. `"Cheapest"`.
    func badge(_ text: String?) -> Self { copy { $0.badgeText = text } }
    /// The call to action. `.ribbon` renders a button; `.inline`/`.tile`/
    /// `.banner` make the whole surface tappable (with a mirrored trailing
    /// indicator). No-op when the subtree is `.readOnly(true)`.
    func onSelect(
        _ title: String = String(themeKitTravel: "See options"),
        perform action: @escaping () -> Void
    ) -> Self {
        copy { $0.ctaTitle = title; $0.ctaAction = action }
    }
    /// Layout archetype — superseded by the style axis: prefer
    /// `.transportCrossSellCardStyle(.ribbon/.inline/.tile)`, settable once
    /// per list via the environment (and joined by the new `.banner`
    /// full-bleed strip). This modifier keeps working and, when called,
    /// wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .transportCrossSellCardStyle(.ribbon/.inline/.tile) instead")
    func variant(_ v: TransportCrossSellVariant) -> Self {
        copy {
            switch v {
            case .ribbon: $0.explicitStyle = AnyTransportCrossSellCardStyle(RibbonTransportCrossSellCardStyle())
            case .inline: $0.explicitStyle = AnyTransportCrossSellCardStyle(InlineTransportCrossSellCardStyle())
            case .tile: $0.explicitStyle = AnyTransportCrossSellCardStyle(TileTransportCrossSellCardStyle())
            }
        }
    }
    /// Size ramp: `.medium` (default) or `.small` — scales the mode glyph,
    /// the `PriceTag` and the paddings together.
    func size(_ s: TransportCrossSellSize) -> Self { copy { $0.sizeValue = s } }
    /// Ribbon tear-line chrome: `.notched` (default — the TicketStub cut +
    /// dashed perforation) or `.plain` (an uncut rounded strip). Ignored by
    /// every preset except `.ribbon`.
    func tearStyle(_ t: TearStyle) -> Self { copy { $0.tearStyleValue = t } }
    /// Fill variant of the badge (`.soft` default, `.solid`, `.outline`,
    /// `.ghost`); its color keeps following the accent→style mapping.
    func badgeVariant(_ v: FillVariant) -> Self { copy { $0.badgeFillValue = v } }
    /// Replaces a preset's built-in CTA button/indicator with caller
    /// content — the select action, accent gating and read-only behavior
    /// are preserved. `.inline` and `.tile` draw no CTA button, so they
    /// ignore this slot (documented no-op); `.banner` renders it as the
    /// trailing tap indicator (replacing the default chevron) since its
    /// whole strip is the tap target.
    func ctaLabel<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.ctaLabelSlot = AnyView(content()) }
    }
    /// Shadow token under a preset's drawn surface (default `.soft`).
    func shadow(_ style: ThemeKitCore.ShadowStyle) -> Self { copy { $0.shadowStyleValue = style } }
    /// Overrides the mode-tinted accent (bus `.warning`, train `.info`,
    /// ferry `.turquoise`, car `.neutral`); `nil` restores the default.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentOverride = color } }
    /// Replaces the built-in mode glyph with a custom brand mark.
    func logo<L: View>(@ViewBuilder _ content: () -> L) -> Self {
        copy { $0.logoSlot = AnyView(content()) }
    }
    /// Surface token for `.ribbon`/`.tile`'s drawn fill (default `.bgBase`);
    /// the ribbon's notch cut and dashed perforation are unaffected.
    /// `.inline` draws no surface of its own, and `.banner` always uses the
    /// mode's soft accent tint — both ignore this key.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Modes · ribbon") {
    ScrollView {
        VStack(spacing: Theme.SpacingKey.md.value) {
            TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                .price(19)
                .duration("6h 30m")
                .departures("Every 30 min from Central Station")
                .badge("Cheapest")
                .onSelect {}
            TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                .price(34, currencyCode: "EUR")
                .duration("4h 15m")
                .onSelect("View timetable") {}
            TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
                .price(12)
                .departures("3 sailings daily")
            TransportCrossSellCard(.car, from: "Riverton", to: "Lakeside")
                .price(55, caption: "per day")
                .duration("5h drive")
                .accent(.success)
                .onSelect("Rent a car") {}
            TransportCrossSellCard(.train, from: "Harbor City", to: "Riverton")
                .price(28)
                .duration("3h 40m")
                .surface(.bgWhite)
                .onSelect {}
        }
        .padding()
    }
    .background(Theme.shared.background(.bgSecondaryLight))
}

#Preview("Inline · logo slot · read-only") {
    VStack(spacing: Theme.SpacingKey.md.value) {
        TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
            .price(34)
            .duration("4h 15m")
            .badge("Fastest")
            .onSelect {}
            .transportCrossSellCardStyle(.inline)
        TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .price(19)
            .duration("6h 30m")
            .onSelect {}
            .transportCrossSellCardStyle(.inline)
            .readOnly()
        TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .price(19)
            .logo { Icon(systemName: "leaf.fill").size(.lg).accent(.success) }
            .onSelect {}
    }
    .padding()
}

#Preview("Tiles · banner · custom mode · sizes · tear/badge/shadow/ctaLabel") {
    ScrollView {
        VStack(spacing: Theme.SpacingKey.md.value) {
            // Tile grid — including a custom mode beyond the 4-case enum.
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                    .price(34)
                    .badge("Fastest")
                    .onSelect {}
                    .transportCrossSellCardStyle(.tile)
                TransportCrossSellCard(customMode: "figure.wave", label: "Shuttle",
                                       accent: .purple, from: "Airport", to: "Center")
                    .price(9)
                    .onSelect {}
                    .transportCrossSellCardStyle(.tile)
                TransportCrossSellCard(.ferry, from: "Harbor", to: "North Isle")
                    .size(.small)
                    .price(12)
                    .transportCrossSellCardStyle(.tile)
            }
            // Plain tear + solid badge + elevated shadow + custom CTA label.
            TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                .price(19)
                .duration("6h 30m")
                .badge("Cheapest")
                .badgeVariant(.solid)
                .tearStyle(.plain)
                .shadow(.elevated)
                .onSelect {}
                .ctaLabel {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Text("Book now").textStyle(.labelSm700)
                        Icon(systemName: "arrow.forward").size(.xs)
                    }
                }
            // Small ribbon ramp.
            TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                .size(.small)
                .price(28)
                .duration("3h 40m")
                .onSelect {}
            // Full-bleed promo strip, mode-tinted.
            TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
                .price(12)
                .departures("3 sailings daily")
                .onSelect("See sailings") {}
                .transportCrossSellCardStyle(.banner)
        }
        .padding()
    }
    .background(Theme.shared.background(.bgSecondaryLight))
}

#Preview("RTL") {
    VStack(spacing: Theme.SpacingKey.md.value) {
        TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .price(19)
            .duration("6h 30m")
            .badge("Cheapest")
            .onSelect {}
        TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
            .price(34)
            .onSelect {}
            .transportCrossSellCardStyle(.inline)
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark") {
    let dark: Theme = {
        let t = Theme()
        t.loadTheme(named: Theme.defaultThemeName, dark: true)
        return t
    }()
    VStack(spacing: Theme.SpacingKey.md.value) {
        TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
            .price(12)
            .departures("3 sailings daily")
            .onSelect {}
    }
    .padding()
    .background(dark.background(.bgBase))
    .theme(dark)
}
