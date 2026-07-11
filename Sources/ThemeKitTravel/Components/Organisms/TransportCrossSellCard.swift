//
//  TransportCrossSellCard.swift
//  ThemeKitTravel
//
//  Edition organism (F3.2 · ADR §9.8). "No flights? Take the bus/train" —
//  a cross-sell for an alternative transport mode: mode glyph, route,
//  price-from, optional CTA. Two archetypes: `.ribbon` (default) is a
//  full-width notched strip that borrows TicketStub's coupon chrome — a
//  `destinationOut` notch cut plus a dashed perforation — rotated to a
//  *vertical* tear line between the glyph and the content; `.inline` is a
//  flat ListRow-anatomy row for embedding between flight results.
//
//  CardStyle exception (same as TicketStub): the notched tear-line shell *is*
//  the ribbon's identity, so it deliberately does not route through CardStyle.
//
//  RTL: the strip is an `HStack`, so the sections mirror automatically. The
//  tear line's x is *measured after layout* via an anchor preference (the
//  TicketStub technique), so the notches and the dashed perforation are cut
//  at the mirrored position by construction — no manual flip of the drawn
//  geometry is needed (flipping the anchor-resolved path would double-mirror).
//
//  Currency: the plain `price(_:caption:)` overload resolves the code through
//  the §10 chain inside `PriceTag` (`\.formatDefaults` > locale > "USD");
//  the explicit `price(_:currencyCode:caption:)` overload always wins.
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``TransportCrossSellCard``: notched strip (`.ribbon`),
/// flat row (`.inline`), or a compact vertical card for grids (`.tile`).
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

    @Environment(\.theme) private var theme
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
    private var variantValue: TransportCrossSellVariant = .ribbon
    private var accentOverride: SemanticColor?
    private var logoSlot: AnyView?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var sizeValue: TransportCrossSellSize = .medium
    private var tearStyleValue: TearStyle = .notched
    private var badgeFillValue: FillVariant = .soft
    /// Replaces the ribbon CTA button's built-in label (action preserved).
    private var ctaLabelSlot: AnyView?
    private var shadowStyleValue: ThemeKitCore.ShadowStyle = .soft

    /// Bespoke coupon geometry (TicketStub-class chrome) — fixed constants,
    /// not knobs: the notch cut radius and the dash inset past the notch.
    private let notchRadius: CGFloat = 8
    private let dashInset: CGFloat = 6

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

    /// The size ramp, resolved once (token-fed paddings; Icon/PriceTag enums).
    private var glyphIconSize: IconSize { sizeValue == .small ? .md : .lg }
    private var sectionPad: CGFloat {
        sizeValue == .small ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value
    }
    private var ribbonPriceSize: PriceSize { sizeValue == .small ? .small : .medium }

    public var body: some View {
        Group {
            switch variantValue {
            case .ribbon: ribbon
            case .inline: inline
            case .tile: tile
            }
        }
        .animation(motion, value: priceAmount)
        .animation(motion, value: badgeText)
    }

    // MARK: - Ribbon variant — notched coupon strip (TicketStub chrome, vertical tear)

    private var ribbon: some View {
        HStack(spacing: 0) {
            glyphSection
                .padding(sectionPad)
            // A zero-width marker whose center is the tear line, reported up so
            // the background carves its notches at exactly this x (mirrors under
            // RTL by construction — the anchor resolves after layout).
            Color.clear.frame(width: 0)
                .anchorPreference(key: TearXAnchorKey.self, value: .center) { $0 }
            contentSection
                .padding(sectionPad)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .backgroundPreferenceValue(TearXAnchorKey.self) { anchor in
            GeometryReader { proxy in
                ribbonSurface(tearX: anchor.map { proxy[$0].x }, size: proxy.size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    private var glyphSection: some View {
        VStack(spacing: Theme.SpacingKey.xs.value) {
            Group {
                if let logoSlot {
                    logoSlot
                } else {
                    Icon(systemName: modeGlyph)
                        .size(glyphIconSize)
                        .accent(accent)
                }
            }
            .padding(Theme.SpacingKey.sm.value)
            .background(Circle().fill(accent.soft))
            Text(modeLabel)
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textSecondary))
        }
        .accessibilityHidden(true)   // announced by the container label
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                routeLine
                if let badgeText {
                    Badge(badgeText).badgeStyle(badgeStyle).variant(badgeFillValue).size(.small)
                }
            }
            if let metaLine {
                Text(metaLine)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            if priceAmount != nil || ctaAction != nil {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if priceAmount != nil { priceTag(size: ribbonPriceSize) }
                    Spacer(minLength: 0)
                    if ctaAction != nil {
                        ctaControl
                    }
                }
            }
        }
    }

    /// The ribbon CTA: the caller's `.ctaLabel { }` content wrapped in the
    /// same select action, or the stock `ThemeButton`.
    @ViewBuilder
    private var ctaControl: some View {
        if let ctaLabelSlot {
            Button { select() } label: {
                ctaLabelSlot.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        } else if let ctaTitle {
            ThemeButton(ctaTitle) { select() }
                .color(accent)
                .size(sizeValue == .small ? .xsmall : .small)
        }
    }

    private var routeLine: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(from).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            // arrow.forward is direction-aware — it mirrors under RTL.
            Icon(systemName: "arrow.forward")
                .size(.xs)
                .color(theme.text(.textTertiary))
            Text(to).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
        }
    }

    /// The coupon surface: rounded fill, two `destinationOut` semicircular
    /// notches on the top/bottom edges at the tear x, and a vertical dashed
    /// perforation between them (TicketStub's drawing approach, rotated 90°).
    /// `.tearStyle(.plain)` skips the cut and the perforation entirely.
    private func ribbonSurface(tearX: CGFloat?, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        let notched = tearStyleValue == .notched
        return ZStack {
            shape
                .fill(theme.background(surfaceKey))
                .overlay { if notched, let tearX { notches(tearX: tearX, height: size.height) } }
                .compositingGroup()                       // scope the destinationOut cut
                .themeShadow(shadowStyleValue)
            if notched, let tearX {
                dashedLine(x: tearX, height: size.height)
            }
        }
    }

    /// Two circles centered on the top/bottom edges — half of each sits outside
    /// the card, so `destinationOut` erases a clean semicircular notch.
    private func notches(tearX: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle().frame(width: notchRadius * 2, height: notchRadius * 2).position(x: tearX, y: 0)
            Circle().frame(width: notchRadius * 2, height: notchRadius * 2).position(x: tearX, y: height)
        }
        .blendMode(.destinationOut)
    }

    private func dashedLine(x: CGFloat, height: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: x, y: notchRadius + dashInset))
            p.addLine(to: CGPoint(x: x, y: height - notchRadius - dashInset))
        }
        .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    // MARK: - Inline variant — flat ListRow anatomy

    private var inline: some View {
        // En dash between endpoints is direction-neutral; the full route is
        // spelled out in the accessibility label.
        ListRow("\(from) – \(to)", action: ctaAction == nil || isReadOnly ? nil : { select() })
            .subtitle(metaLine)
            .leading {
                Group {
                    if let logoSlot {
                        logoSlot
                    } else {
                        Icon(systemName: modeGlyph)
                            .size(sizeValue == .small ? .sm : .md)
                            .accent(accent)
                    }
                }
            }
            .badge(badgeText)
            .trailing {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if priceAmount != nil { priceTag(size: .small) }
                    if ctaAction != nil {
                        // chevron.forward mirrors under RTL.
                        Icon(systemName: "chevron.forward")
                            .size(.xs)
                            .color(theme.text(.textTertiary))
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityText)
    }

    // MARK: - Tile variant — compact vertical card for grids

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        let face = VStack(spacing: Theme.SpacingKey.xs.value) {
            Group {
                if let logoSlot {
                    logoSlot
                } else {
                    Icon(systemName: modeGlyph)
                        .size(glyphIconSize)
                        .accent(accent)
                }
            }
            .padding(Theme.SpacingKey.sm.value)
            .background(Circle().fill(accent.soft))
            Text(modeLabel)
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textSecondary))
            Text("\(from) – \(to)")   // en dash — direction-neutral under RTL
                .textStyle(sizeValue == .small ? .labelSm600 : .labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let badgeText {
                Badge(badgeText).badgeStyle(badgeStyle).variant(badgeFillValue).size(.small)
            }
            if priceAmount != nil {
                priceTag(size: sizeValue == .small ? .small : .medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(sectionPad)
        .background(theme.background(surfaceKey), in: shape)
        .themeShadow(shadowStyleValue)

        return Group {
            if ctaAction != nil {
                Button { select() } label: {
                    face.contentShape(shape)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isReadOnly)
                .accessibilityAddTraits(.isButton)
            } else {
                face
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Shared pieces

    @ViewBuilder
    private func priceTag(size: PriceSize) -> some View {
        // No explicit code → PriceTag's omitted-currency init resolves it via
        // the §10 chain (formatDefaults > locale currency > "USD").
        let base = priceCurrencyCode.map { PriceTag(priceAmount ?? 0, currencyCode: $0) }
            ?? PriceTag(priceAmount ?? 0)
        let captioned = priceCaption.map { base.prefix($0) } ?? base.from()
        captioned.size(size).emphasis(.hero)
    }

    /// "duration · departures" — the middle-dot separator is direction-neutral.
    private var metaLine: String? {
        let parts = [durationText, departuresNote].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var badgeStyle: BadgeStyle {
        switch accent {
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .turquoise: return .turquoise
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        default: return .neutral
        }
    }

    private var accessibilityText: String {
        var parts: [String] = [
            String(themeKitTravel: "\(modeLabel) from \(from) to \(to)")
        ]
        if let durationText { parts.append(durationText) }
        if let departuresNote { parts.append(departuresNote) }
        if let badgeText { parts.append(badgeText) }
        return parts.joined(separator: ", ")
    }

    private func select() {
        guard !isReadOnly else { return }
        ctaAction?()
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
    /// The call to action. In `.ribbon` it renders a button; in `.inline` the
    /// whole row becomes tappable (with a mirrored chevron). No-op when the
    /// subtree is `.readOnly(true)`.
    func onSelect(
        _ title: String = String(themeKitTravel: "See options"),
        perform action: @escaping () -> Void
    ) -> Self {
        copy { $0.ctaTitle = title; $0.ctaAction = action }
    }
    /// Layout archetype: `.ribbon` (default, notched strip), `.inline` (flat
    /// row), or `.tile` (compact vertical card for grids).
    func variant(_ v: TransportCrossSellVariant) -> Self { copy { $0.variantValue = v } }
    /// Size ramp: `.medium` (default) or `.small` — scales the mode glyph,
    /// the `PriceTag` and the paddings together.
    func size(_ s: TransportCrossSellSize) -> Self { copy { $0.sizeValue = s } }
    /// Ribbon tear-line chrome: `.notched` (default — the TicketStub cut +
    /// dashed perforation) or `.plain` (an uncut rounded strip).
    func tearStyle(_ t: TearStyle) -> Self { copy { $0.tearStyleValue = t } }
    /// Fill variant of the badge (`.soft` default, `.solid`, `.outline`,
    /// `.ghost`); its color keeps following the accent→style mapping.
    func badgeVariant(_ v: FillVariant) -> Self { copy { $0.badgeFillValue = v } }
    /// Replaces the ribbon CTA button's label with caller content — the
    /// select action, accent gating and read-only behavior are preserved.
    /// `.inline` and `.tile` draw no CTA button, so they ignore this slot
    /// (documented no-op).
    func ctaLabel<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.ctaLabelSlot = AnyView(content()) }
    }
    /// Shadow token under the ribbon/tile surface (default `.soft`).
    func shadow(_ style: ThemeKitCore.ShadowStyle) -> Self { copy { $0.shadowStyleValue = style } }
    /// Overrides the mode-tinted accent (bus `.warning`, train `.info`,
    /// ferry `.turquoise`, car `.neutral`); `nil` restores the default.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentOverride = color } }
    /// Replaces the built-in mode glyph with a custom brand mark.
    func logo<L: View>(@ViewBuilder _ content: () -> L) -> Self {
        copy { $0.logoSlot = AnyView(content()) }
    }
    /// Surface token for the ribbon's coupon fill (default `.bgBase`); the
    /// notch cut and dashed perforation are unaffected. `.inline` draws no
    /// surface of its own, so the key applies to the `.ribbon` variant.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Reports the vertical tear-line x up to the surface so the notches align to
/// the boundary between the glyph section and the content, whatever their widths.
private struct TearXAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
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
            .variant(.inline)
            .onSelect {}
        TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .price(19)
            .duration("6h 30m")
            .variant(.inline)
            .onSelect {}
            .readOnly()
        TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .price(19)
            .logo { Icon(systemName: "leaf.fill").size(.lg).accent(.success) }
            .onSelect {}
    }
    .padding()
}

#Preview("Tiles · custom mode · sizes · tear/badge/shadow/ctaLabel") {
    ScrollView {
        VStack(spacing: Theme.SpacingKey.md.value) {
            // Tile grid — including a custom mode beyond the 4-case enum.
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                    .variant(.tile)
                    .price(34)
                    .badge("Fastest")
                    .onSelect {}
                TransportCrossSellCard(customMode: "figure.wave", label: "Shuttle",
                                       accent: .purple, from: "Airport", to: "Center")
                    .variant(.tile)
                    .price(9)
                    .onSelect {}
                TransportCrossSellCard(.ferry, from: "Harbor", to: "North Isle")
                    .variant(.tile)
                    .size(.small)
                    .price(12)
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
            .variant(.inline)
            .onSelect {}
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return VStack(spacing: Theme.SpacingKey.md.value) {
        TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
            .price(12)
            .departures("3 sailings daily")
            .onSelect {}
    }
    .padding()
    .background(dark.background(.bgBase))
    .theme(dark)
}
