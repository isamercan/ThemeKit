//
//  BoardingPass.swift
//  ThemeKit
//
//  Organism. A wallet-style boarding pass — airline + flight header, a passenger
//  name, a from→to route with times, a labelled detail grid (gate / seat / boarding
//  / terminal) and a perforated stub carrying a barcode (or QR) and booking ref.
//  Reuses ``TicketStub`` (perforation) and ``Barcode`` / ``QRCode``. Token-bound.
//
//  ```swift
//  BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
//      .airline("Pegasus").flightNo("PC 1234").times(departure: "13:15", arrival: "16:05")
//      .gate("A12").seat("14C").boarding("12:45").barcode("PC1234SAWBER14C")
//  ```
//

import SwiftUI

public struct BoardingPass: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

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
    private var bookingRef: String?
    private var passengerLabel = "Passenger"
    private var barcodeValue: String?
    private var qrValue: String?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var elevation: CardElevation = .elevated

    public init(passenger: String, from: String, to: String) {   // R1
        self.passenger = passenger
        self.from = from
        self.to = to
    }

    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        TicketStub {
            VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.md.value)) {
                header
                route
                if !details.isEmpty { detailGrid }
            }
        }
        .stub { stub }
        .elevation(elevation)
        .surface(surfaceKey)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: airlineIcon).font(.system(size: 14)).foregroundStyle(accentBase)
                if let airline { Text(airline).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let flightNo { Text(flightNo).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary)) }
                if let cabin { Text(cabin).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)) }
            }
        }
    }

    private var route: some View {
        HStack(alignment: .center) {
            routeCol(from, city: fromCity, time: departure, alignment: .leading)
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                if let date { Text(date).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)) }
                Image(systemName: "airplane").font(.system(size: 16)).foregroundStyle(accentBase).mirrorsInRTL()
            }
            Spacer(minLength: 8)
            routeCol(to, city: toCity, time: arrival, alignment: .trailing)
        }
    }

    private func routeCol(_ code: String, city: String?, time: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code).textStyle(.displaySm).foregroundStyle(theme.text(.textPrimary))
            if let city { Text(city).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1) }
            if let time { Text(time).textStyle(.labelBase700).foregroundStyle(accentBase) }
        }
        .fixedSize()
    }

    private var detailGrid: some View {
        HStack(alignment: .top, spacing: density.scale(Theme.SpacingKey.md.value)) {
            ForEach(Array(details.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    Text(item.1).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var stub: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(passengerLabel).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                Text(passenger).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let bookingRef {
                    Text(bookingRef).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 6)
            code
        }
    }

    @ViewBuilder private var code: some View {
        if let qrValue {
            QRCode(qrValue).size(72)
        } else if let barcodeValue {
            Barcode(barcodeValue).height(48).showsValue()
        }
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
    func details(_ items: [(String, String)]) -> Self { copy { $0.details = items } }
    /// Convenience for the common gate / seat / boarding trio.
    func gate(_ gate: String? = nil, seat: String? = nil, boarding: String? = nil, terminal: String? = nil) -> Self {
        copy {
            var d: [(String, String)] = []
            if let terminal { d.append(("Terminal", terminal)) }
            if let gate { d.append(("Gate", gate)) }
            if let boarding { d.append(("Boarding", boarding)) }
            if let seat { d.append(("Seat", seat)) }
            $0.details = d
        }
    }
    func bookingRef(_ text: String?) -> Self { copy { $0.bookingRef = text } }
    /// Localise the "Passenger" caption (English default).
    func passengerLabel(_ text: String) -> Self { copy { $0.passengerLabel = text } }
    /// A Code-128 barcode in the stub.
    func barcode(_ value: String?) -> Self { copy { $0.barcodeValue = value; $0.qrValue = nil } }
    /// A QR code in the stub (instead of a barcode).
    func qr(_ value: String?) -> Self { copy { $0.qrValue = value; $0.barcodeValue = nil } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
        .airline("Pegasus").flightNo("PC 1234").cabin("Economy")
        .cities(from: "Istanbul", to: "Berlin").times(departure: "13:15", arrival: "16:05").date("13 Sep")
        .gate("A12", seat: "14C", boarding: "12:45", terminal: "1")
        .bookingRef("PNR: X7K2QF").barcode("PC1234SAWBER14C")
        .frame(maxWidth: 340).padding()
}
