//
//  BoardingPass.swift
//  ThemeKit
//
//  Organism. A wallet-style boarding pass — airline + flight header, a passenger
//  name, a from→to route with times, a labelled detail grid (gate / seat / boarding
//  / terminal) and a perforated stub carrying a barcode (or QR) and booking ref.
//  Reuses ``TicketStub`` (perforation) and ``Barcode`` / ``QRCode``. Token-bound.
//
//  CardStyle exemption (deliberate): the shell here is the decorative perforated
//  ticket surface — ``TicketStub`` carves the side notches out of its fill with a
//  `destinationOut` composite, so the fill, notches, perforation and elevation
//  shadow are one inseparable unit. Routing any of it through the environment
//  `CardStyle` would paint the notches shut (a style draws a plain rounded-rect
//  fill/border). The whole shell therefore stays with `TicketStub`;
//  `.cardStyle(_:)` intentionally has no effect on this component.
//
//  ```swift
//  BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
//      .airline("Pegasus").flightNo("PC 1234").times(departure: "13:15", arrival: "16:05")
//      .gate("A12").seat("14C").boarding("12:45").barcode("PC1234SAWBER14C")
//  ```
//

import SwiftUI
import ThemeKit

public struct BoardingPass: View {
    /// Footprint of the stub's QR / barcode, mapped to the component's internal
    /// point constants (medium reproduces the classic 72pt QR / 48pt barcode).
    public enum CodeSize: String, CaseIterable, Sendable { case small, medium, large }

    /// Arrangement of the labelled detail cells.
    public enum DetailsLayout: String, CaseIterable, Sendable {
        /// One horizontal row (the classic layout).
        case row
        /// A two-column grid — prevents clipping when many cells or large type.
        case grid
    }

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
    private var passengerLabel = String(themeKit: "Passenger")
    private var barcodeValue: String?
    private var qrValue: String?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
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

    // deferred: accent-fallback unification — keeps the `.primary` fallback
    // (matching AncillaryCard/StickyBookingBar would be visually breaking here).
    private var accentBase: Color { (accent ?? .primary).base }

    /// Internal point constants behind the `CodeSize` ramp (token rule: ramp
    /// enums map to private CGFloats; no raw sizes in the public signature).
    private var qrSide: CGFloat {
        switch codeSize { case .small: return 56; case .medium: return 72; case .large: return 96 }
    }
    private var barcodeHeight: CGFloat {
        switch codeSize { case .small: return 36; case .medium: return 48; case .large: return 64 }
    }

    public var body: some View {
        // Decorative-shell exception: the perforated `TicketStub` surface (fill +
        // notches + tear line + shadow) is the chrome here and is kept as-is —
        // see the header note. `.surface()`/`.elevation()` feed it directly.
        TicketStub {
            VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.md.value)) {
                if let headerSlot { headerSlot } else { header }
                route
                if !details.isEmpty { detailArea }
            }
        }
        .stub { if let customStub { customStub } else { stub } }
        .cornerRadius(radiusRole)
        .perforation(showsPerforation)
        .dashColor(dashKey)
        .elevation(elevation)
        .surface(surfaceKey)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: airlineIcon).font(.system(size: 14)).foregroundStyle(accentBase)
                    .accessibilityHidden(true)   // decorative airline glyph
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
                    .accessibilityHidden(true)   // decorative route glyph
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

    @ViewBuilder private var detailArea: some View {
        switch detailsLayout {
        case .row: detailRow
        case .grid: detailTwoColumnGrid
        }
    }

    private var detailRow: some View {
        HStack(alignment: .top, spacing: density.scale(Theme.SpacingKey.md.value)) {
            ForEach(Array(details.enumerated()), id: \.offset) { _, item in
                detailCell(item)
            }
            Spacer(minLength: 0)
        }
    }

    /// Two-column layout — pairs of cells per `GridRow`, so five details wrap
    /// to three rows instead of clipping off the trailing edge.
    private var detailTwoColumnGrid: some View {
        Grid(alignment: .leading,
             horizontalSpacing: density.scale(Theme.SpacingKey.md.value),
             verticalSpacing: density.scale(Theme.SpacingKey.sm.value)) {
            ForEach(Array(stride(from: 0, to: details.count, by: 2)), id: \.self) { index in
                GridRow {
                    detailCell(details[index])
                        .gridColumnAlignment(.leading)
                    if index + 1 < details.count {
                        detailCell(details[index + 1])
                            .gridColumnAlignment(.leading)
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailCell(_ item: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.0).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            Text(item.1).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
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
            QRCode(qrValue).size(qrSide)
        } else if let barcodeValue {
            Barcode(barcodeValue).height(barcodeHeight).showsValue()
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
            if let terminal { d.append((String(themeKit: "Terminal"), terminal)) }
            if let gate { d.append((String(themeKit: "Gate"), gate)) }
            if let boarding { d.append((String(themeKit: "Boarding"), boarding)) }
            if let seat { d.append((String(themeKit: "Seat"), seat)) }
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
    /// Replaces the built-in passenger / booking-ref / code stub with custom
    /// content — forwarded to ``TicketStub``'s stub slot below the tear line.
    func stub<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.customStub = AnyView(content()) } }
    /// Replaces the built-in airline / flight-number header row.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// Footprint of the stub's QR / barcode (default `.medium` — the classic sizes).
    func codeSize(_ s: CodeSize) -> Self { copy { $0.codeSize = s } }
    /// Detail-cell arrangement: one `.row` (default) or a two-column `.grid`.
    func detailsLayout(_ l: DetailsLayout) -> Self { copy { $0.detailsLayout = l } }
    /// Outer corner radius (radius role token, default `.box`) — forwarded to ``TicketStub``.
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Draw the dashed perforation across the tear line (default on) — forwarded to ``TicketStub``.
    func perforation(_ on: Bool = true) -> Self { copy { $0.showsPerforation = on } }
    /// Perforation dash colour (border token key, default `.borderPrimary`) — forwarded to ``TicketStub``.
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
            BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
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

// The perforated ticket shell is exempt from `CardStyle` (see header note):
// under `.cardStyle(.outlined)` the pass renders identically to the default.
#Preview("Card-style exempt shell") {
    BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
        .airline("Pegasus").flightNo("PC 1234")
        .times(departure: "13:15", arrival: "16:05")
        .gate("A12", seat: "14C", boarding: "12:45")
        .qr("PC1234SAWBER14C")
        .cardStyle(.outlined)
        .frame(maxWidth: 340).padding()
}
