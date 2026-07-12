//
//  BoardingPass.swift
//  ThemeKit
//
//  Organism. A wallet-style boarding pass — airline + flight header, a passenger
//  name, a from→to route with times, a labelled detail grid (gate / seat / boarding
//  / terminal) and a perforated stub carrying a barcode (or QR) and booking ref.
//  Token-bound. The entire layout is style-driven (ADR-0004): the component
//  gathers the typed configuration and the active ``BoardingPassStyle`` lays it
//  out — `.classic` (default, horizontal ``TicketStub`` tear + trailing code),
//  `.wallet` (QR-dominant vertical Apple-Wallet-style pass, two-column details)
//  or `.strip` (one-row gate strip: passenger name / seat / mini code).
//
//  CardStyle note (per-preset, ADR-0004 §4): on the tear presets
//  (`.classic`/`.wallet`) the perforated ``TicketStub`` shell — fill, notches,
//  perforation and elevation shadow — is one inseparable unit owned by the
//  preset, so `.cardStyle(_:)` is a documented no-op there (a card style would
//  paint the notches shut). `.strip` draws no tear and routes its shell through
//  the active `CardStyle`, so `.cardStyle(_:)` applies to it.
//
//  ```swift
//  BoardingPass(passenger: "Jordan Lee", from: "SAW", to: "BER")
//      .airline("Pegasus").flightNo("PC 1234").times(departure: "13:15", arrival: "16:05")
//      .gate("A12", seat: "14C", boarding: "12:45").barcode("PC1234SAWBER14C")
//      .boardingPassStyle(.wallet)   // .classic / .strip / custom
//  ```
//

import SwiftUI
import ThemeKit

public struct BoardingPass: View {
    /// Footprint of the stub's QR / barcode, mapped to the component's internal
    /// point constants (medium reproduces the classic 72pt QR / 48pt barcode).
    public enum CodeSize: String, CaseIterable, Sendable { case small, medium, large }

    /// Arrangement of the labelled detail cells (honoured by ``ClassicBoardingPassStyle``).
    public enum DetailsLayout: String, CaseIterable, Sendable {
        /// One horizontal row (the classic layout).
        case row
        /// A two-column grid — prevents clipping when many cells or large type.
        case grid
    }

    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    @Environment(\.boardingPassStyle) private var style

    private let passenger: String
    private let from: String
    private let to: String
    // Content/appearance — mutated only through the modifiers below (R2).
    private var airline: String?
    private var airlineIcon = "airplane"
    private var flightNo: String?
    private var cabin: String?
    private var fromCity: String?
    private var toCity: String?
    private var departure: String?
    private var arrival: String?
    private var date: String?
    private var details: [(String, String)] = []   // gate/seat/boarding/terminal…
    /// Typed mirrors of the common detail cells — kept in step with `details`
    /// by the `.gate(...)` convenience so styles (e.g. `.strip`) can read
    /// ``BoardingPassConfiguration/seat`` without parsing labelled tuples.
    private var gateValue: String?
    private var seatValue: String?
    private var boardingValue: String?
    private var terminalValue: String?
    private var bookingRef: String?
    private var passengerLabelOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var passengerLabel: String { passengerLabelOverride ?? String(themeKit: "Passenger") }
    private var barcodeValue: String?
    private var qrValue: String?
    private var accent: SemanticColor?
    /// `nil` = the active style's default surface (`.bgBase` for the built-ins).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var elevation: CardElevation = .elevated
    private var radiusRole: Theme.RadiusRole = .box
    private var showsPerforation = true
    private var dashKey: Theme.BorderColorKey = .borderPrimary
    private var codeSize: CodeSize = .medium
    private var detailsLayout: DetailsLayout = .row
    private var headerSlot: AnyView?
    private var customStub: AnyView?

    public init(passenger: String, from: String, to: String) {   // R1
        self.passenger = passenger
        self.from = from
        self.to = to
    }

    public var body: some View {
        let configuration = BoardingPassConfiguration(
            passenger: passenger, from: from, to: to,
            fromCity: fromCity, toCity: toCity,
            departure: departure, arrival: arrival, date: date,
            airline: airline, airlineIcon: airlineIcon,
            flightNo: flightNo, cabin: cabin,
            details: details,
            gate: gateValue, seat: seatValue, boarding: boardingValue, terminal: terminalValue,
            bookingRef: bookingRef, passengerLabel: passengerLabel,
            barcodeValue: barcodeValue, qrValue: qrValue,
            codeSize: codeSize, detailsLayout: detailsLayout,
            accent: accent, surfaceKey: surfaceKey, elevation: elevation,
            radiusRole: radiusRole, showsPerforation: showsPerforation, dashKey: dashKey,
            header: headerSlot, stub: customStub,
            density: density, locale: locale
        )
        style.makeBody(configuration: configuration)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension BoardingPass {
    func airline(_ name: String?, icon: String = "airplane") -> Self { copy { $0.airline = name; $0.airlineIcon = icon } }
    func flightNo(_ text: String?) -> Self { copy { $0.flightNo = text } }
    func cabin(_ text: String?) -> Self { copy { $0.cabin = text } }
    func cities(from: String?, to: String?) -> Self { copy { $0.fromCity = from; $0.toCity = to } }
    func times(departure: String?, arrival: String?) -> Self { copy { $0.departure = departure; $0.arrival = arrival } }
    func date(_ text: String?) -> Self { copy { $0.date = text } }
    /// The labelled detail cells (gate / seat / boarding / terminal…), in order.
    /// Clears the typed ``BoardingPassConfiguration/gate``/``BoardingPassConfiguration/seat``
    /// mirrors — call `.gate(...)` instead when a style needs the typed fields.
    func details(_ items: [(String, String)]) -> Self {
        copy {
            $0.details = items
            $0.gateValue = nil; $0.seatValue = nil; $0.boardingValue = nil; $0.terminalValue = nil
        }
    }
    /// Convenience for the common gate / seat / boarding trio.
    func gate(_ gate: String? = nil, seat: String? = nil, boarding: String? = nil, terminal: String? = nil) -> Self {
        copy {
            $0.gateValue = gate; $0.seatValue = seat; $0.boardingValue = boarding; $0.terminalValue = terminal
            var d: [(String, String)] = []
            if let terminal { d.append((String(themeKit: "Terminal"), terminal)) }
            if let gate { d.append((String(themeKit: "Gate"), gate)) }
            if let boarding { d.append((String(themeKit: "Boarding"), boarding)) }
            if let seat { d.append((String(themeKit: "Seat"), seat)) }
            $0.details = d
        }
    }
    func bookingRef(_ text: String?) -> Self { copy { $0.bookingRef = text } }
    /// Localise the "Passenger" caption (English default).
    func passengerLabel(_ text: String) -> Self { copy { $0.passengerLabelOverride = text } }
    /// A Code-128 barcode in the stub.
    func barcode(_ value: String?) -> Self { copy { $0.barcodeValue = value; $0.qrValue = nil } }
    /// A QR code in the stub (instead of a barcode).
    func qr(_ value: String?) -> Self { copy { $0.qrValue = value; $0.barcodeValue = nil } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Replaces the built-in stub with custom content — forwarded to the active
    /// style's tear-off / trailing area (ignored by presets with no stub, e.g. `.strip`).
    func stub<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.customStub = AnyView(content()) } }
    /// Replaces the built-in airline / flight-number header row.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// Footprint of the stub's QR / barcode (default `.medium` — the classic sizes).
    func codeSize(_ s: CodeSize) -> Self { copy { $0.codeSize = s } }
    /// Detail-cell arrangement: one `.row` (default) or a two-column `.grid` — honoured by `.classic`.
    func detailsLayout(_ l: DetailsLayout) -> Self { copy { $0.detailsLayout = l } }
    /// Outer corner radius (radius role token, default `.box`) — forwarded to the active style.
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Draw the dashed perforation across the tear line (default on) — tear presets only.
    func perforation(_ on: Bool = true) -> Self { copy { $0.showsPerforation = on } }
    /// Perforation dash colour (border token key, default `.borderPrimary`) — tear presets only.
    func dashColor(_ key: Theme.BorderColorKey) -> Self { copy { $0.dashKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            BoardingPass(passenger: "Jordan Lee", from: "SAW", to: "BER")
                .airline("Pegasus").flightNo("PC 1234").cabin("Economy")
                .cities(from: "Istanbul", to: "Berlin").times(departure: "13:15", arrival: "16:05").date("13 Sep")
                .gate("A12", seat: "14C", boarding: "12:45", terminal: "1")
                .bookingRef("PNR: X7K2QF").barcode("PC1234SAWBER14C")
            // Two-column detail grid + large QR + tinted dashes + field corner.
            BoardingPass(passenger: "Alex Morgan", from: "IST", to: "LHR")
                .airline("Sunrise Air").flightNo("SA 101")
                .times(departure: "09:20", arrival: "12:15")
                .details([("Terminal", "2"), ("Gate", "B7"), ("Boarding", "08:40"),
                          ("Seat", "3A"), ("Zone", "1")])
                .detailsLayout(.grid)
                .qr("SA101ISTLHR3A").codeSize(.large)
                .cornerRadius(.field).dashColor(.borderHero)
            // Small barcode, no perforation, custom header + stub slots.
            BoardingPass(passenger: "Sam Carter", from: "AMS", to: "CDG")
                .times(departure: "18:05", arrival: "19:20")
                .header {
                    HStack {
                        Badge("Priority").badgeStyle(.warning).size(.small)
                        Spacer()
                        Text("BW 810").textStyle(.labelSm600)
                    }
                }
                .stub {
                    HStack {
                        Text("Group 1").textStyle(.labelBase700)
                        Spacer()
                        Barcode("BW810AMSCDG").height(36)
                    }
                }
                .barcode("BW810AMSCDG").codeSize(.small)
                .perforation(false)
        }
        .frame(maxWidth: 340).padding()
    }
}

// The tear shell is per-preset chrome (see header note): on the `.classic`
// default, `.cardStyle(.outlined)` renders identically to the default — the
// no-op is deliberate. Swap to `.strip` (`.boardingPassStyle(.strip)`) and it applies.
#Preview("Card-style no-op on the default tear preset") {
    BoardingPass(passenger: "Jordan Lee", from: "SAW", to: "BER")
        .airline("Pegasus").flightNo("PC 1234")
        .times(departure: "13:15", arrival: "16:05")
        .gate("A12", seat: "14C", boarding: "12:45")
        .qr("PC1234SAWBER14C")
        .cardStyle(.outlined)
        .frame(maxWidth: 340).padding()
}
