//
//  TransportCrossSellCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``TransportCrossSellCard`` (ADR-0004): the configuration
//  hands styles the *typed cross-sell data* (mode glyph/label, route, price,
//  meta, CTA…), not pre-laid content, so a style owns the entire arrangement.
//  Four built-ins — the first three map 1:1 to the former
//  ``TransportCrossSellVariant`` cases:
//
//    .ribbon   notched TicketStub-technique coupon strip — today's default.
//    .inline   flat ListRow-anatomy row for embedding between flight results.
//    .tile     compact vertical card for grids/carousels.
//    .banner   full-bleed, mode-tinted promo strip (new).
//
//      TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
//          .price(19).duration("6h 30m").onSelect { showBusOptions() }
//          .transportCrossSellCardStyle(.tile)
//
//  TicketStub-chrome exception (ADR-0004 §4, same as ``TicketStub`` itself):
//  `.ribbon`'s notched, perforated tear-line shell *is* that preset's
//  identity, so `.ribbon` owns the chrome directly inside `makeBody` — it
//  borrows TicketStub's `destinationOut`-notch + dashed-perforation drawing
//  technique, rotated 90° to a *vertical* tear between the glyph and the
//  content, and deliberately does not route through `CardStyle`. `.tile` and
//  `.banner` also draw their own surface (a plain rounded card / an edge-to-
//  edge tinted strip) rather than delegating to `CardStyle`, matching their
//  pre-ADR behaviour. One law (ADR-0004 §6): the component style arranges
//  *content*; token theme colors everything. The component resolves
//  MicroMotion / Reduce Motion *before* calling a style — styles never read
//  the motion environment themselves.
//
//  RTL: every preset composes from `HStack`/`VStack` (they mirror
//  automatically); `.ribbon`'s tear x is measured after layout via an anchor
//  preference (the TicketStub technique), so the notch cut and the dashed
//  perforation land at the mirrored position by construction.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``TransportCrossSellCardStyle`` lays out. Fields a given
/// style doesn't use are simply ignored — every built-in degrades gracefully
/// when optional data is absent (no price → no price block, no CTA → no tap
/// affordance, no badge → no chip).
public struct TransportCrossSellCardConfiguration {
    /// The resolved mode glyph (SF Symbol) — the stock `Mode.systemImage` or
    /// the `customMode` override. Ignored by presets when ``logo`` is set.
    public let modeGlyph: String
    /// The resolved, localized mode label ("Bus", "Train"…), or the
    /// `customMode` override.
    public let modeLabel: String
    /// Departure endpoint (city/airport display string).
    public let from: String
    /// Arrival endpoint.
    public let to: String
    /// Lead-in fare; `nil` hides every preset's price block.
    public let priceAmount: Decimal?
    /// Explicit ISO-4217 code, or `nil` to resolve through the §10
    /// environment chain inside the shared price-tag helper.
    public let priceCurrencyCode: String?
    /// Overrides the default "from" lead-in text.
    public let priceCaption: String?
    /// Journey duration, e.g. "6h 30m".
    public let durationText: String?
    /// Frequency/terminal note, e.g. "Every 30 min from Central Station".
    public let departuresNote: String?
    /// A short accent-tinted flag, e.g. "Cheapest".
    public let badgeText: String?
    /// Fill variant of the badge (`.soft` default).
    public let badgeFillVariant: FillVariant
    /// Custom brand mark replacing the mode glyph; `nil` falls back to
    /// ``modeGlyph``.
    public let logo: AnyView?
    /// The CTA button's title (localized, re-resolved every body pass).
    /// `nil` exactly when ``onSelect`` is `nil`. Only `.ribbon` renders it as
    /// visible text — row/tile/banner presets use the whole surface as the
    /// tap target and show a trailing indicator instead.
    public let ctaTitle: String?
    /// Replaces a preset's built-in CTA affordance with caller content; the
    /// select action, accent gating and read-only behaviour stay wired by
    /// the style, not the slot.
    public let ctaLabel: AnyView?
    /// The select action; `nil` hides every preset's CTA affordance.
    public let onSelect: (() -> Void)?
    /// The read-only environment, captured by the component — presets gate
    /// their tap targets on it through ``select()``.
    public let isReadOnly: Bool
    /// Size ramp — scales the mode glyph, the price tag and the paddings.
    public let size: TransportCrossSellSize
    /// Ribbon tear-line chrome (`.ribbon` only; other presets ignore it).
    public let tearStyle: TearStyle
    /// The resolved brand accent — the mode default, the `customMode`
    /// override, or the explicit `.accent(_:)` override; never `nil`.
    public let accent: SemanticColor
    /// Explicit surface fill, or `nil` to let the style choose its own
    /// default (resolve via ``surface(default:)``). `.banner` ignores this —
    /// its fill is always the mode's soft accent tint.
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Shadow token under a preset's drawn surface (default `.soft`).
    public let shadowStyle: ThemeKitCore.ShadowStyle
    /// The environment's component density, captured by the component —
    /// scale chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — the built-ins
    /// render preformatted strings, but a custom style formatting its own
    /// dates/numbers must use it so injected locales (and RTL demos) render
    /// correctly.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out a preset.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// "duration · departures" — the middle-dot separator is direction-neutral.
    public var metaLine: String? {
        let parts = [durationText, departuresNote].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// ``accent`` mapped to its matching `BadgeStyle` (falls back to
    /// `.neutral` for accents with no 1:1 badge hue).
    public var badgeStyle: BadgeStyle {
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

    /// The spoken summary — route, duration, departures, badge. Every preset
    /// applies this as its container's accessibility label.
    public var accessibilityText: String {
        var parts: [String] = [
            String(themeKitTravel: "\(modeLabel) from \(from) to \(to)")
        ]
        if let durationText { parts.append(durationText) }
        if let departuresNote { parts.append(departuresNote) }
        if let badgeText { parts.append(badgeText) }
        return parts.joined(separator: ", ")
    }

    /// Fires ``onSelect``, no-oping under `.readOnly(true)` — every preset's
    /// tap targets call this instead of ``onSelect`` directly.
    public func select() {
        guard !isReadOnly else { return }
        onSelect?()
    }
}

// MARK: - Protocol

/// Defines a `TransportCrossSellCard`'s entire presentation. Implement
/// `makeBody` to lay out the configuration's cross-sell data. Set one with
/// `.transportCrossSellCardStyle(_:)`; the default is
/// ``RibbonTransportCrossSellCardStyle``.
public protocol TransportCrossSellCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: TransportCrossSellCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The mode glyph in a soft accent-tinted circle, with the mode label below —
/// shared by `.ribbon` and `.tile` (today's identical glyph block).
private struct TransportCrossSellGlyphBadge: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration
    var iconSize: IconSize

    var body: some View {
        VStack(spacing: configuration.spacing(.xs)) {
            Group {
                if let logo = configuration.logo {
                    logo
                } else {
                    Icon(systemName: configuration.modeGlyph)
                        .size(iconSize)
                        .accent(configuration.accent)
                }
            }
            .padding(configuration.spacing(.sm))
            .background(Circle().fill(theme.resolve(configuration.accent).soft))
            Text(configuration.modeLabel)
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textSecondary))
        }
    }
}

/// The "from → to" route line with a direction-aware arrow — shared by
/// `.ribbon` and `.banner`.
private struct TransportCrossSellRouteLine: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration

    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(configuration.from).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            // arrow.forward is direction-aware — it mirrors under RTL.
            Icon(systemName: "arrow.forward")
                .size(.xs)
                .color(theme.text(.textTertiary))
            Text(configuration.to).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
        }
    }
}

/// The lead-in price tag — currency, prefix, size — shared by every preset.
/// No explicit code → `PriceTag`'s omitted-currency init resolves it via the
/// §10 chain (`formatDefaults` → `locale.currency` → `"USD"`).
private struct TransportCrossSellPriceTag: View {
    let configuration: TransportCrossSellCardConfiguration
    let size: PriceSize

    var body: some View {
        let base = configuration.priceCurrencyCode.map { PriceTag(configuration.priceAmount ?? 0, currencyCode: $0) }
            ?? PriceTag(configuration.priceAmount ?? 0)
        let captioned = configuration.priceCaption.map { base.prefix($0) } ?? base.from()
        captioned.size(size).emphasis(.hero)
    }
}

// MARK: - .ribbon

/// Reports the vertical tear-line x up to the surface so the notches align to
/// the boundary between the glyph section and the content, whatever their widths.
private struct TransportCrossSellTearXAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

/// Today's ``TransportCrossSellCard`` look, extracted verbatim: a notched
/// coupon strip — mode glyph leading, route/badge/meta/price/CTA content
/// trailing, split by a vertical tear line (the ``TicketStub`` notch +
/// perforation technique, rotated 90°, drawn locally). Owns the tear chrome
/// (fill, notch cut, perforation, shadow are one unit), so `.cardStyle(_:)`
/// is a no-op on this preset — the default.
public struct RibbonTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    public init() {}
    public func makeBody(configuration: TransportCrossSellCardConfiguration) -> some View {
        RibbonTransportCrossSellChrome(configuration: configuration)
    }
}

private struct RibbonTransportCrossSellChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration

    /// Bespoke coupon geometry (TicketStub-class chrome) — fixed constants,
    /// not knobs: the notch cut radius and the dash inset past the notch.
    private let notchRadius: CGFloat = 8
    private let dashInset: CGFloat = 6

    private var sectionPad: CGFloat {
        configuration.size == .small ? configuration.spacing(.sm) : configuration.spacing(.md)
    }
    private var priceSize: PriceSize { configuration.size == .small ? .small : .medium }

    var body: some View {
        HStack(spacing: 0) {
            TransportCrossSellGlyphBadge(configuration: configuration,
                                          iconSize: configuration.size == .small ? .md : .lg)
                .padding(sectionPad)
                .accessibilityHidden(true)   // announced by the container label
            // A zero-width marker whose center is the tear line, reported up so
            // the background carves its notches at exactly this x (mirrors under
            // RTL by construction — the anchor resolves after layout).
            Color.clear.frame(width: 0)
                .anchorPreference(key: TransportCrossSellTearXAnchorKey.self, value: .center) { $0 }
            contentSection
                .padding(sectionPad)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .backgroundPreferenceValue(TransportCrossSellTearXAnchorKey.self) { anchor in
            GeometryReader { proxy in
                ribbonSurface(tearX: anchor.map { proxy[$0].x }, size: proxy.size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.accessibilityText)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
            HStack(spacing: configuration.spacing(.xs)) {
                TransportCrossSellRouteLine(configuration: configuration)
                if let badgeText = configuration.badgeText {
                    Badge(badgeText).badgeStyle(configuration.badgeStyle)
                        .variant(configuration.badgeFillVariant).size(.small)
                }
            }
            if let metaLine = configuration.metaLine {
                Text(metaLine)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            if configuration.priceAmount != nil || configuration.onSelect != nil {
                HStack(spacing: configuration.spacing(.sm)) {
                    if configuration.priceAmount != nil {
                        TransportCrossSellPriceTag(configuration: configuration, size: priceSize)
                    }
                    Spacer(minLength: 0)
                    if configuration.onSelect != nil { ctaControl }
                }
            }
        }
    }

    /// The ribbon CTA: the caller's `.ctaLabel { }` content wrapped in the
    /// same select action, or the stock `ThemeButton`.
    @ViewBuilder
    private var ctaControl: some View {
        if let ctaLabel = configuration.ctaLabel {
            Button { configuration.select() } label: {
                ctaLabel.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        } else if let ctaTitle = configuration.ctaTitle {
            ThemeButton(ctaTitle) { configuration.select() }
                .color(configuration.accent)
                .size(configuration.size == .small ? .xsmall : .small)
        }
    }

    /// The coupon surface: rounded fill, two `destinationOut` semicircular
    /// notches on the top/bottom edges at the tear x, and a vertical dashed
    /// perforation between them (TicketStub's drawing approach, rotated 90°).
    /// `.tearStyle(.plain)` skips the cut and the perforation entirely.
    private func ribbonSurface(tearX: CGFloat?, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        let notched = configuration.tearStyle == .notched
        return ZStack {
            shape
                .fill(theme.background(configuration.surface(default: .bgBase)))
                .overlay { if notched, let tearX { notches(tearX: tearX, height: size.height) } }
                .compositingGroup()                       // scope the destinationOut cut
                .themeShadow(configuration.shadowStyle)
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
}

// MARK: - .inline

/// A flat `ListRow`-anatomy row for embedding between flight results —
/// today's `.inline` look, extracted verbatim.
public struct InlineTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    public init() {}
    public func makeBody(configuration: TransportCrossSellCardConfiguration) -> some View {
        InlineTransportCrossSellChrome(configuration: configuration)
    }
}

private struct InlineTransportCrossSellChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration

    var body: some View {
        // En dash between endpoints is direction-neutral; the full route is
        // spelled out in the accessibility label.
        ListRow(
            "\(configuration.from) – \(configuration.to)",
            action: configuration.onSelect == nil || configuration.isReadOnly ? nil : { configuration.select() }
        )
        .subtitle(configuration.metaLine)
        .leading {
            Group {
                if let logo = configuration.logo {
                    logo
                } else {
                    Icon(systemName: configuration.modeGlyph)
                        .size(configuration.size == .small ? .sm : .md)
                        .accent(configuration.accent)
                }
            }
        }
        .badge(configuration.badgeText)
        .trailing {
            HStack(spacing: configuration.spacing(.xs)) {
                if configuration.priceAmount != nil {
                    TransportCrossSellPriceTag(configuration: configuration, size: .small)
                }
                if configuration.onSelect != nil {
                    // chevron.forward mirrors under RTL.
                    Icon(systemName: "chevron.forward")
                        .size(.xs)
                        .color(theme.text(.textTertiary))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.accessibilityText)
    }
}

// MARK: - .tile

/// A compact vertical card for grids/carousels — today's `.tile` look,
/// extracted verbatim.
public struct TileTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    public init() {}
    public func makeBody(configuration: TransportCrossSellCardConfiguration) -> some View {
        TileTransportCrossSellChrome(configuration: configuration)
    }
}

private struct TileTransportCrossSellChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration

    private var sectionPad: CGFloat {
        configuration.size == .small ? configuration.spacing(.sm) : configuration.spacing(.md)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
        Group {
            if configuration.onSelect != nil {
                Button { configuration.select() } label: {
                    face(shape).contentShape(shape)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!configuration.isReadOnly)
                .accessibilityAddTraits(.isButton)
            } else {
                face(shape)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityText)
    }

    private func face(_ shape: RoundedRectangle) -> some View {
        VStack(spacing: configuration.spacing(.xs)) {
            TransportCrossSellGlyphBadge(configuration: configuration,
                                          iconSize: configuration.size == .small ? .md : .lg)
            Text("\(configuration.from) – \(configuration.to)")   // en dash — direction-neutral under RTL
                .textStyle(configuration.size == .small ? .labelSm600 : .labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let badgeText = configuration.badgeText {
                Badge(badgeText).badgeStyle(configuration.badgeStyle)
                    .variant(configuration.badgeFillVariant).size(.small)
            }
            if configuration.priceAmount != nil {
                TransportCrossSellPriceTag(configuration: configuration,
                                            size: configuration.size == .small ? .small : .medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(sectionPad)
        .background(theme.background(configuration.surface(default: .bgBase)), in: shape)
        .themeShadow(configuration.shadowStyle)
    }
}

// MARK: - .banner

/// A full-bleed, mode-tinted promo strip: glyph, route + badge, meta line,
/// trailing price + tap indicator — on the mode's soft accent fill, edge-to-
/// edge (no card shell, no border). For a cross-sell slotted flush between
/// search results or atop a results list. The whole strip is the tap target
/// when `onSelect` is set (like `.tile`), so ``ctaLabel`` renders as the
/// trailing indicator and ``ctaTitle`` is a documented no-op here.
public struct BannerTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    public init() {}
    public func makeBody(configuration: TransportCrossSellCardConfiguration) -> some View {
        BannerTransportCrossSellChrome(configuration: configuration)
    }
}

private struct BannerTransportCrossSellChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TransportCrossSellCardConfiguration

    var body: some View {
        Group {
            if configuration.onSelect != nil {
                Button { configuration.select() } label: { content }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!configuration.isReadOnly)
                    .accessibilityAddTraits(.isButton)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityText)
    }

    private var content: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            Group {
                if let logo = configuration.logo {
                    logo
                } else {
                    Icon(systemName: configuration.modeGlyph)
                        .size(configuration.size == .small ? .md : .lg)
                        .accent(configuration.accent)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: configuration.spacing(.xs)) {
                    TransportCrossSellRouteLine(configuration: configuration)
                    if let badgeText = configuration.badgeText {
                        Badge(badgeText).badgeStyle(configuration.badgeStyle)
                            .variant(configuration.badgeFillVariant).size(.small)
                    }
                }
                if let metaLine = configuration.metaLine {
                    Text(metaLine)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: configuration.spacing(.sm))
            trailingBlock
        }
        .padding(configuration.spacing(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.resolve(configuration.accent).soft)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingBlock: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if configuration.priceAmount != nil {
                TransportCrossSellPriceTag(configuration: configuration,
                                            size: configuration.size == .small ? .small : .medium)
            }
            if let ctaLabel = configuration.ctaLabel {
                ctaLabel
            } else if configuration.onSelect != nil {
                Icon(systemName: "chevron.forward").size(.xs).color(theme.resolve(configuration.accent).base)
            }
        }
    }
}

// MARK: - Static accessors

public extension TransportCrossSellCardStyle where Self == RibbonTransportCrossSellCardStyle {
    /// Notched TicketStub-technique coupon strip. The default.
    static var ribbon: RibbonTransportCrossSellCardStyle { RibbonTransportCrossSellCardStyle() }
}
public extension TransportCrossSellCardStyle where Self == InlineTransportCrossSellCardStyle {
    /// Flat `ListRow`-anatomy row for embedding between flight results.
    static var inline: InlineTransportCrossSellCardStyle { InlineTransportCrossSellCardStyle() }
}
public extension TransportCrossSellCardStyle where Self == TileTransportCrossSellCardStyle {
    /// Compact vertical card for grids/carousels.
    static var tile: TileTransportCrossSellCardStyle { TileTransportCrossSellCardStyle() }
}
public extension TransportCrossSellCardStyle where Self == BannerTransportCrossSellCardStyle {
    /// Full-bleed, mode-tinted promo strip.
    static var banner: BannerTransportCrossSellCardStyle { BannerTransportCrossSellCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    private let _makeBody: @MainActor (TransportCrossSellCardConfiguration) -> AnyView
    init<S: TransportCrossSellCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: TransportCrossSellCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct TransportCrossSellCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyTransportCrossSellCardStyle(RibbonTransportCrossSellCardStyle())
}

extension EnvironmentValues {
    var transportCrossSellCardStyle: AnyTransportCrossSellCardStyle {
        get { self[TransportCrossSellCardStyleKey.self] }
        set { self[TransportCrossSellCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``TransportCrossSellCardStyle`` for `TransportCrossSellCard`s
    /// in this view and its descendants — a results list sets it once.
    func transportCrossSellCardStyle<S: TransportCrossSellCardStyle>(_ style: sending S) -> some View {
        environment(\.transportCrossSellCardStyle, AnyTransportCrossSellCardStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a leading accent rail + route + price, no card shell at all.
private struct AccentRailTransportCrossSellCardStyle: TransportCrossSellCardStyle {
    func makeBody(configuration: TransportCrossSellCardConfiguration) -> some View {
        AccentRailChrome(configuration: configuration)
    }

    private struct AccentRailChrome: View {
        @Environment(\.theme) private var theme
        let configuration: TransportCrossSellCardConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value)
                    .fill(theme.resolve(configuration.accent).base)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.modeLabel)
                        .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    Text("\(configuration.from) – \(configuration.to)")
                        .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                }
                Spacer()
                if configuration.priceAmount != nil {
                    TransportCrossSellPriceTag(configuration: configuration, size: .medium)
                }
            }
            .padding(configuration.spacing(.sm))
            .background(
                theme.background(.bgSecondaryLight),
                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
        }
    }
}

#Preview("TransportCrossSellCardStyle — presets × light/dark") {
    let ribbonCard = TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
        .price(19)
        .duration("6h 30m")
        .departures("Every 30 min from Central Station")
        .badge("Cheapest")
        .onSelect {}
    let plainCard = TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
        .price(34, currencyCode: "EUR")
        .duration("4h 15m")
        .onSelect("View timetable") {}
    PreviewMatrix("TransportCrossSellCardStyle") {
        PreviewCase("Ribbon (default)") { ribbonCard }
        PreviewCase("Inline") { plainCard.transportCrossSellCardStyle(.inline) }
        PreviewCase("Tile") {
            plainCard.transportCrossSellCardStyle(.tile).frame(width: 220)
        }
        PreviewCase("Banner") {
            TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
                .price(12).departures("3 sailings daily")
                .onSelect("See sailings") {}
                .transportCrossSellCardStyle(.banner)
        }
        PreviewCase("Custom (in-preview)") {
            plainCard.transportCrossSellCardStyle(AccentRailTransportCrossSellCardStyle())
        }
    }
}
