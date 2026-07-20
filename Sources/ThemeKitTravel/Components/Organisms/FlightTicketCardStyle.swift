//
//  FlightTicketCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightTicketCard`` (ADR-0004, Wave 1 · Class A) — the
//  configuration hands styles the *typed ticket data* (route, times, airline,
//  price, favourite state) plus the resolved chrome knobs, so a style owns the
//  entire layout. Three built-ins:
//
//    .classic     route header + dashed timeline + horizontal tear + stub — default
//    .horizontal  stub trailing behind a *vertical* tear (coupon strip)
//    .flat        tearless plain card for dense lists (composes the neutral Card)
//
//  Chrome ownership (ADR-0004 §4): the old component-wide `CardStyle` exemption
//  dissolves into per-preset facts — `.classic` owns the perforated ``TicketStub``
//  chrome inside `makeBody` and `.horizontal` draws the same notched tear locally
//  (rotated 90°), so `.cardStyle(_:)` is a documented **no-op** on those two;
//  `.flat` composes the neutral ``Card``, so `.cardStyle(_:)` applies transitively.
//  Component style arranges content; shell style paints chrome; token theme
//  colors everything.
//
//      FlightTicketCard(from: "NYC", to: "SFO").price(140)
//          .flightTicketCardStyle(.horizontal)   // .classic / .flat / custom
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightTicketCardStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no airline → glyph only, no price → no tag, no
/// favourite requested → no heart and no reserved space).
public struct FlightTicketCardConfiguration {
    /// Origin IATA-style code — the required subject of every style.
    public let from: String
    /// Destination IATA-style code.
    public let to: String
    public let fromCity: String?
    public let toCity: String?
    /// Pre-formatted departure display string (the component takes strings).
    public let departure: String?
    /// Pre-formatted arrival display string.
    public let arrival: String?
    /// Pre-formatted duration ("1h 45m").
    public let duration: String?
    public let stops: Int
    public let airline: String?
    /// SF Symbol fallback when ``airlineLogo`` is `nil`.
    public let airlineIcon: String
    public let airlineLogo: URL?
    public let priceAmount: Decimal?
    /// Pre-discount price for a strikethrough next to ``priceAmount``; `nil`
    /// hides it (the default — today's single-price render).
    public let originalAmount: Decimal?
    /// Already resolved by the component via the §10 chain
    /// (`formatDefaults.currencyCode` → `locale.currency` → `"USD"`).
    public let currencyCode: String
    /// Emphasis of the stub's `PriceTag` (`FlightTicketCard.priceEmphasis(_:)`).
    public let priceEmphasis: PriceEmphasis
    /// Favourite state — `nil` means no heart was requested (the default; styles
    /// render no heart and reserve no space). Set by ``FlightTicketCard/favorite()``
    /// / ``FlightTicketCard/favorite(_:)``.
    public let isFavorite: Bool?
    /// Flips ``isFavorite``. Styles with a heart call this — the bounce is
    /// `MicroMotion`-gated inside the shared heart building block.
    public let toggleFavorite: (() -> Void)?
    /// Accent (`FlightTicketCard.accent(_:)`), or `nil` for the component's
    /// documented `.primary` fallback — resolve via ``accentBase`` and friends.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Surface elevation: none / soft / elevated.
    public let elevation: CardElevation
    /// Corner-radius role override (`FlightTicketCard.cornerRadius(_:)`);
    /// `nil` = the style's standard `.box`. Resolve via ``cornerRadiusRole``.
    public let radiusRole: Theme.RadiusRole?
    /// Draw the dashed perforation across the tear line (tear presets only).
    public let showsPerforation: Bool
    /// Perforation dash colour (border token key).
    public let dashKey: Theme.BorderColorKey
    /// Custom route-header slot (`.header { }`); `nil` = the built-in header.
    public let header: AnyView?
    /// Custom stub slot (`.stub { }`); `nil` = the built-in airline/price/heart stub.
    public let stub: AnyView?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for any
    /// date/number formatting a custom style performs.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// The `cornerRadius(_:)` override, or the standard card `.box` role.
    public var cornerRadiusRole: Theme.RadiusRole { radiusRole ?? .box }

    /// ``cornerRadiusRole``'s resolved value — for styles that draw their own shell.
    public var cornerRadius: CGFloat { cornerRadiusRole.value }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the ticket.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    // deferred: accent-fallback unification — keeps the `.primary` fallback
    // (matching AncillaryCard/StickyBookingBar would be visually breaking here).
    /// Accent for the duration, timeline dots/plane and the active heart fill.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use accentBase(_ theme:)")
    public var accentBase: Color { accentBase(.shared) }
    /// Theme-parameterized twin of ``accentBase`` — resolves against the
    /// environment theme (ADR-0006), honoring per-subtree `.theme(_:)`.
    public func accentBase(_ theme: Theme) -> Color { theme.resolve(accent ?? .primary).base }
    /// Content colour on top of ``accentBase`` (the heart glyph).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use accentOnSolid(_ theme:)")
    public var accentOnSolid: Color { accentOnSolid(.shared) }
    /// Theme-parameterized twin of ``accentOnSolid``.
    public func accentOnSolid(_ theme: Theme) -> Color { theme.resolve(accent ?? .primary).onSolid }
}

// MARK: - Protocol

/// Defines a `FlightTicketCard`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's ticket data. Set one with
/// `.flightTicketCardStyle(_:)`; the default is ``ClassicFlightTicketCardStyle``.
public protocol FlightTicketCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightTicketCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The route header above the tear: codes + cities on the ends, the accented
/// duration centered, and the dashed departure→arrival timeline underneath.
private struct TicketRouteHeader: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTicketCardConfiguration
    /// The preset's *resolved* surface — the timeline plane and the endpoint
    /// dots punch their little windows out of this exact fill.
    let surfaceKey: Theme.BackgroundColorKey

    var body: some View {
        VStack(spacing: configuration.spacing(.md)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(configuration.from).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    if let fromCity = configuration.fromCity {
                        Text(fromCity).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer(minLength: 8)
                if let duration = configuration.duration {
                    Text(duration).textStyle(.labelSm700).foregroundStyle(configuration.accentBase(theme))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(configuration.to).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    if let toCity = configuration.toCity {
                        Text(toCity).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
            }
            TicketTimeline(configuration: configuration, surfaceKey: surfaceKey)
        }
    }
}

/// The dashed departure→arrival track: endpoint dots, a centered plane glyph
/// (mirrored under RTL) and the time labels on the ends.
private struct TicketTimeline: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTicketCardConfiguration
    let surfaceKey: Theme.BackgroundColorKey

    var body: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let departure = configuration.departure {
                Text(departure).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).fixedSize()
            }
            ZStack {
                TicketDashedLine()
                    .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(height: 1)
                HStack {
                    dot; Spacer(); dot
                }
                Image(systemName: configuration.stops == 0 ? "airplane" : "airplane.circle.fill")
                    .font(.system(size: 14)).foregroundStyle(configuration.accentBase(theme))
                    .padding(.horizontal, 4).background(theme.background(surfaceKey))
                    .mirrorsInRTL()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            if let arrival = configuration.arrival {
                Text(arrival).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).fixedSize()
            }
        }
    }

    private var dot: some View {
        Circle().fill(configuration.accentBase(theme)).frame(width: 7, height: 7)
            .overlay(Circle().fill(theme.background(surfaceKey)).frame(width: 3, height: 3))
    }
}

/// The stub row below the tear: airline logo/glyph + name, the price tag and
/// the optional favourite heart — `.classic`'s and `.flat`'s built-in stub.
private struct TicketStubRow: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTicketCardConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let airlineLogo = configuration.airlineLogo {
                RemoteImage(airlineLogo).contentMode(.fit).frame(width: 22, height: 22)
            } else {
                Image(systemName: configuration.airlineIcon)
                    .font(.system(size: 15)).foregroundStyle(theme.text(.textSecondary))
            }
            if let airline = configuration.airline {
                Text(airline).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode)
                    .original(configuration.originalAmount)
                    .size(.medium).emphasis(configuration.priceEmphasis).fractionDigits(0)
            }
            TicketFavoriteHeart(configuration: configuration)
        }
    }
}

/// The favourite heart toggle shared by the built-ins — 30pt accent-filled
/// circle, bounce gated by `microAnimations` + Reduce Motion. Renders
/// **nothing** when the configuration has no favourite (`isFavorite == nil`),
/// so styles compose it without a layout shift for callers that never asked.
private struct TicketFavoriteHeart: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: FlightTicketCardConfiguration

    var body: some View {
        if let isFavorite = configuration.isFavorite {
            Button { configuration.toggleFavorite?() } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(configuration.accentOnSolid(theme))
                    .symbolBounceCompat(value: (micro && !reduceMotion) ? isFavorite : false)
                    .frame(width: 30, height: 30)
                    .background(isFavorite ? configuration.accentBase(theme) : theme.text(.textTertiary), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .accessibilityLabel(isFavorite
                ? String(themeKit: "Remove from favourites")
                : String(themeKit: "Add to favourites"))
        }
    }
}

/// The timeline's straight dashed track (drawn, but symmetric — no RTL flip needed).
private struct TicketDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        }
    }
}

/// Elevation → shadow-token mapping shared by the shell-drawing presets
/// (``TicketStub``'s treatment, reproduced for the locally drawn `.horizontal` shell).
private struct TicketCardElevation: ViewModifier {
    let elevation: CardElevation
    @ViewBuilder func body(content: Content) -> some View {
        switch elevation {
        case .none: content
        case .soft: content.themeShadow(.soft)
        case .elevated: content.themeShadow(.elevated)
        }
    }
}

// MARK: - .classic — today's look (route header / horizontal tear / stub)

/// The default: the perforated boarding-pass card — route header + dashed
/// timeline above a horizontal tear, airline/price/heart stub below. Owns the
/// ``TicketStub`` chrome (fill, notches, perforation, shadow are one unit), so
/// `.cardStyle(_:)` is a no-op on this preset.
public struct ClassicFlightTicketCardStyle: FlightTicketCardStyle {
    public init() {}
    public func makeBody(configuration: FlightTicketCardConfiguration) -> some View {
        TicketStub {
            if let header = configuration.header {
                header
            } else {
                TicketRouteHeader(configuration: configuration, surfaceKey: configuration.surface(default: .bgBase))
            }
        }
        .stub {
            if let stub = configuration.stub { stub } else { TicketStubRow(configuration: configuration) }
        }
        .cornerRadius(configuration.cornerRadiusRole)
        .perforation(configuration.showsPerforation)
        .dashColor(configuration.dashKey)
        .elevation(configuration.elevation)
        .surface(configuration.surface(default: .bgBase))
    }
}

// MARK: - .horizontal — stub trailing behind a vertical tear

/// A coupon-strip ticket: the route header fills the leading section and the
/// airline/price/heart stub sits trailing, behind a *vertical* tear — the
/// ``TicketStub`` notch technique rotated 90° (the `TransportCrossSellCard`
/// ribbon approach), drawn locally. Owns its tear chrome, so `.cardStyle(_:)`
/// is a no-op on this preset.
public struct HorizontalFlightTicketCardStyle: FlightTicketCardStyle {
    public init() {}
    public func makeBody(configuration: FlightTicketCardConfiguration) -> some View {
        HorizontalTicketChrome(configuration: configuration)
    }
}

private struct HorizontalTicketChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTicketCardConfiguration

    /// ``TicketStub``'s stock notch geometry, reproduced for the local tear.
    private let notchRadius: CGFloat = 10
    private let dashInset: CGFloat = 6

    private var surfaceKey: Theme.BackgroundColorKey { configuration.surface(default: .bgBase) }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let header = configuration.header {
                    header
                } else {
                    TicketRouteHeader(configuration: configuration, surfaceKey: surfaceKey)
                }
            }
            .padding(configuration.spacing(.md))
            .frame(maxWidth: .infinity, alignment: .leading)
            // A zero-width marker whose center is the tear line, reported up so
            // the background carves its notches at exactly this x — mirrors
            // under RTL by construction (the anchor resolves after layout).
            Color.clear.frame(width: 0)
                .anchorPreference(key: TicketTearXAnchorKey.self, value: .center) { $0 }
            Group {
                if let stub = configuration.stub { stub } else { VerticalStubColumn(configuration: configuration) }
            }
            .padding(configuration.spacing(.md))
        }
        .backgroundPreferenceValue(TicketTearXAnchorKey.self) { anchor in
            GeometryReader { proxy in
                shell(tearX: anchor.map { proxy[$0].x }, size: proxy.size)
            }
        }
    }

    /// The coupon surface: rounded fill, two `destinationOut` semicircular
    /// notches on the top/bottom edges at the tear x, and a vertical dashed
    /// perforation between them (``TicketStub``'s drawing approach, rotated 90°).
    private func shell(tearX: CGFloat?, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
        return ZStack {
            shape
                .fill(theme.background(surfaceKey))
                .overlay { if let tearX { notches(tearX: tearX, height: size.height) } }
                .compositingGroup()                       // scope the destinationOut cut
                .modifier(TicketCardElevation(elevation: configuration.elevation))
            if configuration.showsPerforation, let tearX {
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
        .stroke(theme.border(configuration.dashKey), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}

/// `.horizontal`'s built-in trailing stub — the airline/price/heart stacked
/// into a narrow tear-off column.
private struct VerticalStubColumn: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTicketCardConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            if let airlineLogo = configuration.airlineLogo {
                RemoteImage(airlineLogo).contentMode(.fit).frame(width: 22, height: 22)
            } else {
                Image(systemName: configuration.airlineIcon)
                    .font(.system(size: 15)).foregroundStyle(theme.text(.textSecondary))
            }
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode)
                    .original(configuration.originalAmount)
                    .size(.medium).emphasis(configuration.priceEmphasis).fractionDigits(0)
            }
            TicketFavoriteHeart(configuration: configuration)
        }
    }
}

private struct TicketTearXAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

// MARK: - .flat — tearless plain card for dense lists

/// A tearless ticket for dense result lists: the route header and the stub row
/// in a plain rounded ``Card``, divided instead of torn — no notches, no
/// perforation. Composes the neutral `Card`, so `.cardStyle(_:)` applies to
/// this preset transitively (unlike the tear presets).
public struct FlatFlightTicketCardStyle: FlightTicketCardStyle {
    public init() {}
    public func makeBody(configuration: FlightTicketCardConfiguration) -> some View {
        Card {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                if let header = configuration.header {
                    header
                } else {
                    TicketRouteHeader(configuration: configuration, surfaceKey: configuration.surface(default: .bgBase))
                }
                DividerView().size(.small)
                if let stub = configuration.stub { stub } else { TicketStubRow(configuration: configuration) }
            }
        }
        .elevation(configuration.elevation)
        .surface(configuration.surface(default: .bgBase))
    }
}

// MARK: - Static accessors

public extension FlightTicketCardStyle where Self == ClassicFlightTicketCardStyle {
    /// Route header + dashed timeline + horizontal tear + stub. The default.
    static var classic: ClassicFlightTicketCardStyle { ClassicFlightTicketCardStyle() }
}
public extension FlightTicketCardStyle where Self == HorizontalFlightTicketCardStyle {
    /// Coupon strip: stub trailing behind a vertical tear.
    static var horizontal: HorizontalFlightTicketCardStyle { HorizontalFlightTicketCardStyle() }
}
public extension FlightTicketCardStyle where Self == FlatFlightTicketCardStyle {
    /// Tearless plain card for dense lists — `.cardStyle(_:)` applies here.
    static var flat: FlatFlightTicketCardStyle { FlatFlightTicketCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightTicketCardStyle: FlightTicketCardStyle {
    private let _makeBody: @MainActor (FlightTicketCardConfiguration) -> AnyView
    init<S: FlightTicketCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightTicketCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightTicketCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightTicketCardStyle(ClassicFlightTicketCardStyle())
}

extension EnvironmentValues {
    var flightTicketCardStyle: AnyFlightTicketCardStyle {
        get { self[FlightTicketCardStyleKey.self] }
        set { self[FlightTicketCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightTicketCardStyle`` for `FlightTicketCard`s in this view
    /// and its descendants — one screen can mix archetypes per section.
    func flightTicketCardStyle<S: FlightTicketCardStyle>(_ style: sending S) -> some View {
        environment(\.flightTicketCardStyle, AnyFlightTicketCardStyle(style))
    }
}
