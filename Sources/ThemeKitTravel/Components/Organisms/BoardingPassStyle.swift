//
//  BoardingPassStyle.swift
//  ThemeKit
//
//  The styling hook for ``BoardingPass`` (ADR-0004, Wave 4 · Class A) — the
//  configuration hands styles the *typed pass data* (passenger, route, flight,
//  the labelled detail cells, booking ref, barcode/QR), not pre-laid content, so
//  a style owns the entire layout. Three built-ins:
//
//    .classic   header/passenger/route/details + horizontal TicketStub tear and
//               a trailing barcode/QR stub — today's pass. Default.
//    .wallet    QR-dominant vertical pass — the code and passenger name fill the
//               tear-off stub, two-column details above (Apple Wallet pass).
//    .strip     one-row gate strip: passenger name / seat / a mini QR or barcode.
//
//  Chrome ownership (ADR-0004 §4): the old component-wide `TicketStub`/`CardStyle`
//  exemption dissolves into per-preset facts — `.classic` and `.wallet` own the
//  perforated ``TicketStub`` chrome inside `makeBody` (fill, notches, perforation
//  and elevation shadow are one inseparable unit), so `.cardStyle(_:)` is a
//  documented no-op on those two; `.strip` draws no tear and routes its shell
//  through the active `CardStyle`, so `.cardStyle(_:)` applies to it. The tear
//  helpers (``BoardingPassCode``, the header/route/detail building blocks below)
//  stay available to any custom style that wants the pass look.
//
//      BoardingPass(passenger: "Jordan Lee", from: "IST", to: "LHR")
//          .airline("Anadolu Air").times(departure: "09:20", arrival: "12:15")
//          .gate("A12", seat: "14C").qr("TK2434ISTLHR14C")
//          .boardingPassStyle(.wallet)   // .classic / .strip / custom
//
//  Component style arranges content; shell style paints chrome; token theme
//  colors everything.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``BoardingPassStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no airline → glyph only, no details → no detail
/// area, no barcode/QR → no code).
public struct BoardingPassConfiguration {
    /// The passenger's display name — every style's required subject.
    public let passenger: String
    /// Origin IATA-style code.
    public let from: String
    /// Destination IATA-style code.
    public let to: String
    public let fromCity: String?
    public let toCity: String?
    /// Pre-formatted departure display string (the component takes strings).
    public let departure: String?
    /// Pre-formatted arrival display string.
    public let arrival: String?
    /// Pre-formatted flight date ("13 Sep").
    public let date: String?
    public let airline: String?
    /// SF Symbol used when the header renders no custom slot.
    public let airlineIcon: String
    public let flightNo: String?
    public let cabin: String?
    /// The labelled detail cells (gate / seat / boarding / terminal…), in the
    /// order supplied via `.details(_:)` or the `.gate(...)` convenience.
    public let details: [(String, String)]
    /// Typed convenience mirrors of the common cells — set via `.gate(...)`;
    /// `nil` when the caller populated `.details(_:)` directly, or never set
    /// that particular cell. ``BoardingPassStyle/strip`` reads ``seat``.
    public let gate: String?
    public let seat: String?
    public let boarding: String?
    public let terminal: String?
    public let bookingRef: String?
    /// Render-time resolved "Passenger" caption — re-resolves through the
    /// localization chain on every body pass, so a live language switch is
    /// never frozen at init.
    public let passengerLabel: String
    /// A Code-128 barcode value; `nil` when ``qrValue`` (or neither) is set.
    public let barcodeValue: String?
    /// A QR value; takes precedence over ``barcodeValue`` when both are set.
    public let qrValue: String?
    /// Footprint of the dominant-code presets' QR/barcode (`.strip` uses its
    /// own fixed mini footprint instead — see ``BoardingPassConfiguration``'s
    /// header note on genuine, non-token dimensions).
    public let codeSize: BoardingPass.CodeSize
    /// Detail-cell arrangement honoured by ``ClassicBoardingPassStyle``; other
    /// presets pick their own fixed arrangement (`.wallet` always grids).
    public let detailsLayout: BoardingPass.DetailsLayout
    /// Accent (`BoardingPass.accent(_:)`), or `nil` for the component's
    /// documented `.primary` fallback — resolve via ``accentBase``/``accentOnSolid``.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Surface elevation: none / soft / elevated.
    public let elevation: CardElevation
    /// Corner-radius role (`BoardingPass.cornerRadius(_:)`, default `.box`) —
    /// forwarded to the tear presets' ``TicketStub`` and to `.strip`'s `CardStyle` shell.
    public let radiusRole: Theme.RadiusRole
    /// Draw the dashed perforation across the tear line (tear presets only).
    public let showsPerforation: Bool
    /// Perforation dash colour (border token key).
    public let dashKey: Theme.BorderColorKey
    /// Custom header slot (`.header { }`); `nil` = the built-in airline/flight row.
    public let header: AnyView?
    /// Custom stub slot (`.stub { }`); `nil` = the built-in stub for that preset.
    public let stub: AnyView?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component. `BoardingPass` takes
    /// pre-formatted display strings (no raw `Date`s), so today's built-ins
    /// don't format with it — carried for parity with the suite's shared
    /// configuration essentials, and available to any custom style that does.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the pass.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    // deferred: accent-fallback unification — keeps the `.primary` fallback
    // (matching AncillaryCard/StickyBookingBar would be visually breaking here).
    /// Accent for the airline glyph, route plane and duration.
    public var accentBase: Color { (accent ?? .primary).base }
    /// Content colour on top of a solid accent fill.
    public var accentOnSolid: Color { (accent ?? .primary).onSolid }

    /// Internal point constants behind the `CodeSize` ramp (token rule: ramp
    /// enums map to private CGFloats; no raw sizes in the public signature).
    public var qrSide: CGFloat {
        switch codeSize { case .small: return 56; case .medium: return 72; case .large: return 96 }
    }
    public var barcodeHeight: CGFloat {
        switch codeSize { case .small: return 36; case .medium: return 48; case .large: return 64 }
    }
}

// MARK: - Protocol

/// Defines a `BoardingPass`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's pass data. Set one with `.boardingPassStyle(_:)`;
/// the default is ``ClassicBoardingPassStyle``.
public protocol BoardingPassStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: BoardingPassConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The airline/flight header row shared by `.classic` and `.wallet`: glyph +
/// airline name leading, flight number + cabin trailing.
private struct BoardingPassHeaderRow: View {
    @Environment(\.theme) private var theme
    let configuration: BoardingPassConfiguration

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: configuration.airlineIcon).font(.system(size: 14))
                    .foregroundStyle(configuration.accentBase)
                    .accessibilityHidden(true)   // decorative airline glyph
                if let airline = configuration.airline {
                    Text(airline).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let flightNo = configuration.flightNo {
                    Text(flightNo).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                }
                if let cabin = configuration.cabin {
                    Text(cabin).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
    }
}

/// The from→to route track shared by `.classic` and `.wallet`: codes + cities
/// on the ends, the accented plane (mirrored under RTL) and date centered.
private struct BoardingPassRouteRow: View {
    @Environment(\.theme) private var theme
    let configuration: BoardingPassConfiguration

    var body: some View {
        HStack(alignment: .center) {
            column(configuration.from, city: configuration.fromCity, time: configuration.departure, alignment: .leading)
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                if let date = configuration.date {
                    Text(date).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
                Image(systemName: "airplane").font(.system(size: 16))
                    .foregroundStyle(configuration.accentBase).mirrorsInRTL()
                    .accessibilityHidden(true)   // decorative route glyph
            }
            Spacer(minLength: 8)
            column(configuration.to, city: configuration.toCity, time: configuration.arrival, alignment: .trailing)
        }
    }

    private func column(_ code: String, city: String?, time: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code).textStyle(.displaySm).foregroundStyle(theme.text(.textPrimary))
            if let city { Text(city).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1) }
            if let time { Text(time).textStyle(.labelBase700).foregroundStyle(configuration.accentBase) }
        }
        .fixedSize()
    }
}

/// One labelled detail cell ("GATE" / "A12") — shared by the row and grid arrangements.
private struct BoardingPassDetailCell: View {
    @Environment(\.theme) private var theme
    let item: (String, String)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.0).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            Text(item.1).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
        }
    }
}

/// One horizontal row of detail cells — `.classic`'s `.row` layout.
private struct BoardingPassDetailRow: View {
    let configuration: BoardingPassConfiguration

    var body: some View {
        HStack(alignment: .top, spacing: configuration.spacing(.md)) {
            ForEach(Array(configuration.details.enumerated()), id: \.offset) { _, item in
                BoardingPassDetailCell(item: item)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A two-column grid of detail cells — pairs of cells per `GridRow`, so five
/// details wrap to three rows instead of clipping off the trailing edge.
/// `.classic`'s `.grid` layout; `.wallet` always uses this arrangement.
private struct BoardingPassDetailGrid: View {
    let configuration: BoardingPassConfiguration

    var body: some View {
        Grid(alignment: .leading,
             horizontalSpacing: configuration.spacing(.md),
             verticalSpacing: configuration.spacing(.sm)) {
            ForEach(Array(stride(from: 0, to: configuration.details.count, by: 2)), id: \.self) { index in
                GridRow {
                    BoardingPassDetailCell(item: configuration.details[index])
                        .gridColumnAlignment(.leading)
                    if index + 1 < configuration.details.count {
                        BoardingPassDetailCell(item: configuration.details[index + 1])
                            .gridColumnAlignment(.leading)
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `.classic`'s detail area — honours ``BoardingPassConfiguration/detailsLayout``.
private struct BoardingPassDetailArea: View {
    let configuration: BoardingPassConfiguration

    var body: some View {
        switch configuration.detailsLayout {
        case .row: BoardingPassDetailRow(configuration: configuration)
        case .grid: BoardingPassDetailGrid(configuration: configuration)
        }
    }
}

/// The stub's barcode/QR — QR wins when both are set. Shared by `.classic`'s
/// trailing code and `.wallet`'s dominant centered code.
private struct BoardingPassCode: View {
    let configuration: BoardingPassConfiguration

    var body: some View {
        if let qr = configuration.qrValue {
            QRCode(qr).size(configuration.qrSide)
        } else if let barcode = configuration.barcodeValue {
            Barcode(barcode).height(configuration.barcodeHeight).showsValue()
        }
    }
}

// MARK: - .classic — today's look (header / route / details / tear / stub)

/// The default: header row, route, an optional detail area above a horizontal
/// ``TicketStub`` tear, and a passenger/booking-ref/code stub below it. Owns
/// the `TicketStub` chrome, so `.cardStyle(_:)` is a no-op on this preset.
public struct ClassicBoardingPassStyle: BoardingPassStyle {
    public init() {}
    public func makeBody(configuration: BoardingPassConfiguration) -> some View {
        TicketStub {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                if let header = configuration.header { header } else { BoardingPassHeaderRow(configuration: configuration) }
                BoardingPassRouteRow(configuration: configuration)
                if !configuration.details.isEmpty { BoardingPassDetailArea(configuration: configuration) }
            }
        }
        .stub {
            if let stub = configuration.stub { stub } else { ClassicBoardingPassStub(configuration: configuration) }
        }
        .cornerRadius(configuration.radiusRole)
        .perforation(configuration.showsPerforation)
        .dashColor(configuration.dashKey)
        .elevation(configuration.elevation)
        .surface(configuration.surface(default: .bgBase))
    }
}

/// `.classic`'s built-in stub: passenger label/name/booking-ref leading, the
/// code trailing.
private struct ClassicBoardingPassStub: View {
    @Environment(\.theme) private var theme
    let configuration: BoardingPassConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.md)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.passengerLabel).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                Text(configuration.passenger).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let bookingRef = configuration.bookingRef {
                    Text(bookingRef).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 6)
            BoardingPassCode(configuration: configuration)
        }
    }
}

// MARK: - .wallet — QR-dominant vertical (Apple Wallet pass)

/// A vertical pass with the code and passenger name filling the tear-off stub —
/// the header, route and a two-column detail grid sit above the tear; the code
/// dominates below it. Owns the `TicketStub` chrome, so `.cardStyle(_:)` is a
/// no-op on this preset.
public struct WalletBoardingPassStyle: BoardingPassStyle {
    public init() {}
    public func makeBody(configuration: BoardingPassConfiguration) -> some View {
        TicketStub {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                if let header = configuration.header { header } else { BoardingPassHeaderRow(configuration: configuration) }
                BoardingPassRouteRow(configuration: configuration)
                if !configuration.details.isEmpty { BoardingPassDetailGrid(configuration: configuration) }
            }
        }
        .stub {
            if let stub = configuration.stub { stub } else { WalletBoardingPassStub(configuration: configuration) }
        }
        .cornerRadius(configuration.radiusRole)
        .perforation(configuration.showsPerforation)
        .dashColor(configuration.dashKey)
        .elevation(configuration.elevation)
        .surface(configuration.surface(default: .bgBase))
    }
}

/// `.wallet`'s built-in stub: the dominant, centered code above the centered
/// passenger name/booking-ref — the Apple Wallet "big barcode, name below" read.
private struct WalletBoardingPassStub: View {
    @Environment(\.theme) private var theme
    let configuration: BoardingPassConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            BoardingPassCode(configuration: configuration)
            VStack(spacing: 2) {
                Text(configuration.passengerLabel).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                Text(configuration.passenger).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let bookingRef = configuration.bookingRef {
                    Text(bookingRef).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

// MARK: - .strip — one-row gate strip

/// A dense, tearless row for gate-side lists: passenger name, the seat (when
/// set) and a mini code. Draws no tear and routes its shell through the active
/// `CardStyle`, so `.cardStyle(_:)` applies to this preset.
public struct StripBoardingPassStyle: BoardingPassStyle {
    public init() {}
    public func makeBody(configuration: BoardingPassConfiguration) -> some View {
        StripBoardingPassChrome(configuration: configuration)
    }
}

private struct StripBoardingPassChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: BoardingPassConfiguration

    /// A dense strip's code is deliberately mini — a fixed constant, not the
    /// dominant-code presets' `codeSize` ramp (token rule: a genuine dimension
    /// with no semantic token stays a fixed constant, never an arbitrary knob).
    private let miniQRSide: CGFloat = 32
    private let miniBarcodeHeight: CGFloat = 24

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(row),
            elevation: configuration.elevation,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: configuration.radiusRole))
    }

    private var row: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            VStack(alignment: .leading, spacing: 1) {
                Text(configuration.passengerLabel).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                Text(configuration.passenger).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
            }
            if let seat = configuration.seat {
                DividerView().axis(.vertical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(themeKit: "Seat")).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    Text(seat).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                }
            }
            Spacer(minLength: configuration.spacing(.sm))
            miniCode
        }
        .padding(configuration.spacing(.sm))
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var miniCode: some View {
        if let qr = configuration.qrValue {
            QRCode(qr).size(miniQRSide)
        } else if let barcode = configuration.barcodeValue {
            Barcode(barcode).height(miniBarcodeHeight)
        }
    }
}

// MARK: - Static accessors

public extension BoardingPassStyle where Self == ClassicBoardingPassStyle {
    /// Header/passenger/route/details + horizontal tear + barcode stub. The default.
    static var classic: ClassicBoardingPassStyle { ClassicBoardingPassStyle() }
}
public extension BoardingPassStyle where Self == WalletBoardingPassStyle {
    /// QR-dominant vertical pass, two-column details — Apple Wallet style.
    static var wallet: WalletBoardingPassStyle { WalletBoardingPassStyle() }
}
public extension BoardingPassStyle where Self == StripBoardingPassStyle {
    /// One-row gate strip: passenger name / seat / mini code.
    static var strip: StripBoardingPassStyle { StripBoardingPassStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyBoardingPassStyle: BoardingPassStyle {
    private let _makeBody: @MainActor (BoardingPassConfiguration) -> AnyView
    init<S: BoardingPassStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: BoardingPassConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct BoardingPassStyleKey: EnvironmentKey {
    static let defaultValue = AnyBoardingPassStyle(ClassicBoardingPassStyle())
}

extension EnvironmentValues {
    var boardingPassStyle: AnyBoardingPassStyle {
        get { self[BoardingPassStyleKey.self] }
        set { self[BoardingPassStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``BoardingPassStyle`` for `BoardingPass`es in this view and its
    /// descendants — one screen can mix archetypes per section.
    func boardingPassStyle<S: BoardingPassStyle>(_ style: sending S) -> some View {
        environment(\.boardingPassStyle, AnyBoardingPassStyle(style))
    }
}

// MARK: - Previews

private func sampleBoardingPass() -> BoardingPass {
    BoardingPass(passenger: "Jordan Lee", from: "IST", to: "LHR")
        .airline("Anadolu Air").flightNo("TK 2434").cabin("Economy")
        .cities(from: "Istanbul", to: "London").times(departure: "09:20", arrival: "12:15").date("18 Jul")
        .gate("A12", seat: "14C", boarding: "08:40", terminal: "1")
        .bookingRef("PNR: X7K2QF").barcode("TK2434ISTLHR14C")
}

private func denseBoardingPass() -> BoardingPass {
    BoardingPass(passenger: "Priya Nair", from: "AMS", to: "CDG")
        .airline("Blue Wings").flightNo("BW 810")
        .times(departure: "18:05", arrival: "19:20")
        .details([("Terminal", "2"), ("Gate", "B4"), ("Boarding", "17:35"), ("Seat", "22A"), ("Zone", "1")])
        .qr("BW810AMSCDG22A").codeSize(.large)
}

/// A custom style built purely on the public API — what an app target would
/// write: a solid-accent "now boarding" banner with no `TicketStub` at all,
/// proving the protocol is externally implementable.
private struct GateAnnouncementBoardingPassStyle: BoardingPassStyle {
    func makeBody(configuration: BoardingPassConfiguration) -> some View {
        GateAnnouncementChrome(configuration: configuration)
    }

    private struct GateAnnouncementChrome: View {
        let configuration: BoardingPassConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                Text(String(themeKit: "Now boarding")).textStyle(.overline500)
                    .foregroundStyle(configuration.accentOnSolid)
                HStack {
                    Text("\(configuration.from) → \(configuration.to)")
                        .textStyle(.headingSm).foregroundStyle(configuration.accentOnSolid)
                    Spacer()
                    if let gate = configuration.gate {
                        Text(gate).textStyle(.labelLg700).foregroundStyle(configuration.accentOnSolid)
                    }
                }
                Text(configuration.passenger).textStyle(.bodySm400).foregroundStyle(configuration.accentOnSolid)
            }
            .padding(configuration.spacing(.md))
            .background((configuration.accent ?? .primary).solid,
                        in: RoundedRectangle(cornerRadius: configuration.radiusRole.value, style: .continuous))
        }
    }
}

#Preview("BoardingPassStyle — presets × light/dark") {
    PreviewMatrix("BoardingPassStyle", rtl: true) {
        PreviewCase("Classic (default)") { sampleBoardingPass().frame(maxWidth: 320) }
        PreviewCase("Classic · accent") {
            sampleBoardingPass().accent(.info).boardingPassStyle(.classic).frame(maxWidth: 320)
        }
        PreviewCase("Wallet") { sampleBoardingPass().boardingPassStyle(.wallet).frame(maxWidth: 280) }
        PreviewCase("Wallet · large QR") {
            denseBoardingPass().accent(.success).boardingPassStyle(.wallet).frame(maxWidth: 280)
        }
        PreviewCase("Strip") { sampleBoardingPass().boardingPassStyle(.strip).frame(maxWidth: 320) }
        PreviewCase("Strip · no seat") {
            BoardingPass(passenger: "Chris Bailey", from: "ESB", to: "SAW")
                .times(departure: "07:00", arrival: "08:10")
                .barcode("PC9021ESBSAW")
                .boardingPassStyle(.strip)
                .frame(maxWidth: 320)
        }
        PreviewCase("Custom (in-preview)") {
            sampleBoardingPass().accent(.warning).boardingPassStyle(GateAnnouncementBoardingPassStyle()).frame(maxWidth: 320)
        }
    }
}
