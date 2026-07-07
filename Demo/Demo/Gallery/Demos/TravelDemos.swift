//
//  TravelDemos.swift
//  Demo
//
//  Interactive demo pages for the travel component suite. Each wraps the real
//  component in ComponentStage with live @State knobs — every public prop and
//  modifier is editable from the gallery (parity with the atom/molecule demos).
//

import SwiftUI
import ThemeKit

// MARK: - Atoms

struct PriceTagDemo: View {
    @State private var amount = 1_299.0
    @State private var size: PriceSize = .large
    @State private var emphasis: PriceEmphasis = .hero
    @State private var stateIdx = 0                // 0 priced · 1 free · 2 sold out
    @State private var currency = "TRY"
    @State private var showOriginal = true
    @State private var showUnit = true
    @State private var discountBadge = true
    @State private var fromPrefix = false
    @State private var fractionDigits = 0.0
    @State private var animates = true
    @State private var trailing = false            // .trailing{} slot

    private let states = ["Priced", "Free", "Sold out"]

    private var tag: PriceTag {
        var t = PriceTag(Decimal(amount), currencyCode: currency)
            .size(size).emphasis(emphasis)
            .discountBadge(discountBadge)
            .fractionDigits(Int(fractionDigits))
            .animatesValue(animates)
        if showOriginal { t = t.original(Decimal(amount * 1.4)) }
        if showUnit { t = t.unit("/ night") }
        if fromPrefix { t = t.from() }
        if stateIdx == 1 { t = t.free() }
        if stateIdx == 2 { t = t.soldOut() }
        if trailing { t = t.trailing { Text("incl. tax").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textTertiary)) } }
        return t
    }

    var body: some View {
        ComponentStage("PriceTag", inspector: [
            ("amount", "\(Int(amount))"), ("size", "\(size)"), ("emphasis", "\(emphasis)"), ("state", states[stateIdx]),
        ]) {
            tag
        } knobs: {
            NumberKnob(title: "Amount", value: $amount, range: 0...9_999, step: 10)
            Picker("State", selection: $stateIdx) {
                ForEach(states.indices, id: \.self) { Text(states[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Size", selection: $size) {
                Text("S").tag(PriceSize.small); Text("M").tag(PriceSize.medium); Text("L").tag(PriceSize.large); Text("XL").tag(PriceSize.xlarge)
            }.pickerStyle(.segmented)
            Picker("Emphasis", selection: $emphasis) {
                Text("Std").tag(PriceEmphasis.standard); Text("Hero").tag(PriceEmphasis.hero); Text("Ok").tag(PriceEmphasis.success); Text("Muted").tag(PriceEmphasis.muted)
            }.pickerStyle(.segmented)
            Picker("Currency", selection: $currency) {
                Text("TRY").tag("TRY"); Text("EUR").tag("EUR"); Text("USD").tag("USD"); Text("GBP").tag("GBP")
            }.pickerStyle(.segmented)
            HStack { Text("Decimals"); SwiftUI.Slider(value: $fractionDigits, in: 0...2, step: 1); Text("\(Int(fractionDigits))").font(.caption.monospacedDigit()) }
            Toggle("Original price (strike-through)", isOn: $showOriginal)
            Toggle("Discount badge", isOn: $discountBadge)
            Toggle("Unit (\"/ night\")", isOn: $showUnit)
            Toggle("\"from\" prefix", isOn: $fromPrefix)
            Toggle("Trailing slot (\"incl. tax\")", isOn: $trailing)
            Toggle("Animate value on change", isOn: $animates)
        }
    }
}

struct PointsBadgeDemo: View {
    @State private var points = 1_250.0
    @State private var style: PointsStyle = .earn
    @State private var size: PointsSize = .large
    @State private var showUnit = true
    @State private var showIcon = false
    @State private var icon = "wallet.pass.fill"
    @State private var showsSign = true
    @State private var animates = true
    @State private var trailing = false            // .trailing{} slot

    private var badge: PointsBadge {
        var b = PointsBadge(Int(points)).style(style).size(size).showsSign(showsSign).animatesValue(animates)
        if showUnit { b = b.unit("mil") }
        if showIcon { b = b.icon(icon) }
        if trailing { b = b.trailing { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.shared.text(.textTertiary)) } }
        return b
    }

    var body: some View {
        ComponentStage("PointsBadge", inspector: [
            ("points", "\(Int(points))"), ("style", "\(style)"), ("size", "\(size)"),
        ]) {
            badge
        } knobs: {
            NumberKnob(title: "Points", value: $points, range: 0...50_000, step: 50)
            Picker("Style", selection: $style) {
                Text("Earn").tag(PointsStyle.earn); Text("Redeem").tag(PointsStyle.redeem); Text("Balance").tag(PointsStyle.balance)
            }.pickerStyle(.segmented)
            Picker("Size", selection: $size) {
                Text("S").tag(PointsSize.small); Text("M").tag(PointsSize.medium); Text("L").tag(PointsSize.large)
            }.pickerStyle(.segmented)
            Toggle("Unit (\"mil\")", isOn: $showUnit)
            Toggle("Leading icon", isOn: $showIcon)
            if showIcon { IconKnob(title: "Icon", symbol: $icon, options: ["wallet.pass.fill", "star.circle.fill", "gift.fill", "airplane.circle.fill"]) }
            Toggle("Trailing chevron slot", isOn: $trailing)
            Toggle("Show +/- sign", isOn: $showsSign)
            Toggle("Animate value on change", isOn: $animates)
        }
    }
}

struct CountdownTimerDemo: View {
    @State private var minutes = 10.0                  // minutes until deadline (0 = expired now)
    @State private var style: CountdownStyle = .urgent
    @State private var format: CountdownFormat = .boxed
    @State private var size: CountdownSize = .large
    @State private var showsDays = false
    @State private var autoUrgent = false              // .urgentBelow(...)
    @State private var urgentBelowMin = 15.0
    @State private var expiredSlot = false             // .onExpired { ... }

    private var rebuildKey: String { "\(minutes)-\(autoUrgent)-\(urgentBelowMin)-\(expiredSlot)" }

    private var timer: CountdownTimer {
        var t = CountdownTimer(until: .now.addingTimeInterval(minutes * 60))
            .style(style).format(format).size(size).showsDays(showsDays)
        if autoUrgent { t = t.urgentBelow(urgentBelowMin * 60) }
        if expiredSlot {
            t = t.onExpired {
                Label("Sale ended", systemImage: "checkmark.seal.fill")
                    .textStyle(.labelMd700).foregroundStyle(Theme.shared.text(.textSecondary))
            }
        }
        return t
    }

    var body: some View {
        ComponentStage("CountdownTimer", inspector: [
            ("format", "\(format)"), ("style", "\(style)"), ("deadline", minutes == 0 ? "expired" : "\(Int(minutes))m"),
        ]) {
            timer.id(rebuildKey)   // rebuild the countdown when the deadline/threshold knobs move
        } knobs: {
            HStack { Text("Deadline"); SwiftUI.Slider(value: $minutes, in: 0...4_320, step: 1); Text(minutes == 0 ? "now" : "\(Int(minutes))m").font(.caption.monospacedDigit()) }
            Picker("Format", selection: $format) {
                Text("Boxed").tag(CountdownFormat.boxed); Text("Inline").tag(CountdownFormat.inline); Text("Text").tag(CountdownFormat.text)
            }.pickerStyle(.segmented)
            Picker("Style", selection: $style) {
                Text("Standard").tag(CountdownStyle.standard); Text("Urgent").tag(CountdownStyle.urgent)
            }.pickerStyle(.segmented)
            Picker("Size", selection: $size) {
                Text("S").tag(CountdownSize.small); Text("M").tag(CountdownSize.medium); Text("L").tag(CountdownSize.large)
            }.pickerStyle(.segmented)
            Toggle("Shows days (d h m s)", isOn: $showsDays)
            Toggle("Auto-urgent below threshold", isOn: $autoUrgent)
            if autoUrgent { HStack { Text("Urgent ≤"); SwiftUI.Slider(value: $urgentBelowMin, in: 1...120, step: 1); Text("\(Int(urgentBelowMin))m").font(.caption.monospacedDigit()) } }
            Toggle("Expired slot (drag deadline to 0)", isOn: $expiredSlot)
        }
    }
}

struct QRCodeDemo: View {
    @State private var value = "https://github.com/isamercan/ThemeKit"
    @State private var size = 160.0

    var body: some View {
        ComponentStage("QRCode", inspector: [("size", "\(Int(size))pt")]) {
            QRCode(value).size(size)
        } knobs: {
            TextField("Encoded value", text: $value).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 80...240, step: 4); Text("\(Int(size))").font(.caption.monospacedDigit()) }
        }
    }
}

struct BarcodeDemo: View {
    @State private var value = "9824097217421298"
    @State private var height = 56.0
    @State private var showsValue = true

    var body: some View {
        ComponentStage("Barcode", inspector: [("height", "\(Int(height))pt")]) {
            Barcode(value).height(height).showsValue(showsValue).frame(maxWidth: 320)
        } knobs: {
            TextField("Encoded value", text: $value).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            HStack { Text("Height"); SwiftUI.Slider(value: $height, in: 32...96, step: 2); Text("\(Int(height))").font(.caption.monospacedDigit()) }
            Toggle("Shows value under bars", isOn: $showsValue)
        }
    }
}

// MARK: - Molecules

struct AmenityGridDemo: View {
    @State private var columns = 2.0
    @State private var size: AmenitySize = .medium
    @State private var useLimit = false
    @State private var limit = 4.0
    @State private var tinted = false
    @State private var highlight = false

    private let items: [ThemeKit.Amenity] = [
        .init("Free Wi-Fi", systemImage: "wifi"),
        .init("Pool", systemImage: "figure.pool.swim"),
        .init("Breakfast", systemImage: "fork.knife"),
        .init("Parking", systemImage: "parkingsign"),
        .init("Gym", systemImage: "dumbbell"),
        .init("Pet friendly", systemImage: "pawprint"),
        .init("Spa", systemImage: "sparkles"),
        .init("Airport shuttle", systemImage: "bus"),
    ]

    private var grid: AmenityGrid {
        var g = AmenityGrid(items).columns(Int(columns)).size(size)
        if useLimit { g = g.limit(Int(limit)) }
        if tinted { g = g.tint(SemanticColor.purple.base) }
        if highlight { g = g.highlighted(["Free Wi-Fi", "Breakfast"]) }
        return g
    }

    var body: some View {
        ComponentStage("AmenityGrid", inspector: [
            ("count", "\(items.count)"), ("columns", "\(Int(columns))"), ("size", "\(size)"),
        ]) {
            grid.frame(maxWidth: 360)
        } knobs: {
            HStack { Text("Columns"); SwiftUI.Slider(value: $columns, in: 1...4, step: 1); Text("\(Int(columns))").font(.caption.monospacedDigit()) }
            Picker("Size", selection: $size) {
                Text("S").tag(AmenitySize.small); Text("M").tag(AmenitySize.medium); Text("L").tag(AmenitySize.large)
            }.pickerStyle(.segmented)
            Toggle("Collapse with +N", isOn: $useLimit)
            if useLimit { HStack { Text("Limit"); SwiftUI.Slider(value: $limit, in: 1...8, step: 1); Text("\(Int(limit))").font(.caption.monospacedDigit()) } }
            Toggle("Custom tint (purple)", isOn: $tinted)
            Toggle("Highlight Wi-Fi + Breakfast", isOn: $highlight)
        }
    }
}

struct CurrencyPickerDemo: View {
    @State private var code = "TRY"
    @State private var showsName = true
    @State private var searchable = true
    @State private var showRecents = true

    private var picker: CurrencyPicker {
        var p = CurrencyPicker(selection: $code, currencies: ThemeKit.Currency.common)
            .showsName(showsName).searchable(searchable)
        if showRecents { p = p.recents(Array(ThemeKit.Currency.common.prefix(3))) }
        return p
    }

    var body: some View {
        ComponentStage("CurrencyPicker", inspector: [("selection", code)]) {
            picker.frame(maxWidth: 360)
        } knobs: {
            Toggle("Shows currency name", isOn: $showsName)
            Toggle("Searchable list", isOn: $searchable)
            Toggle("Recents section", isOn: $showRecents)
        }
    }
}

struct InstallmentSelectorDemo: View {
    @State private var months = 3
    @State private var total = 12_000.0
    @State private var interestFree = 3.0
    @State private var useRecommended = true
    @State private var recommended = 6.0
    @State private var surcharge = false

    private var selector: InstallmentSelector {
        var s = InstallmentSelector(total: Decimal(total), options: [1, 3, 6, 9, 12], selection: $months)
            .interestFreeUpTo(Int(interestFree))
        if useRecommended { s = s.recommended(Int(recommended)) }
        if surcharge { s = s.surcharge([9: 350, 12: 750]) }
        return s
    }

    var body: some View {
        ComponentStage("InstallmentSelector", inspector: [("selection", "\(months)×"), ("total", "\(Int(total))")]) {
            selector.frame(maxWidth: 360)
        } knobs: {
            NumberKnob(title: "Total", value: $total, range: 1_000...50_000, step: 500)
            HStack { Text("Interest-free ≤"); SwiftUI.Slider(value: $interestFree, in: 0...12, step: 1); Text("\(Int(interestFree))×").font(.caption.monospacedDigit()) }
            Toggle("Recommended badge", isOn: $useRecommended)
            if useRecommended {
                Picker("Recommended", selection: $recommended) {
                    Text("3×").tag(3.0); Text("6×").tag(6.0); Text("9×").tag(9.0); Text("12×").tag(12.0)
                }.pickerStyle(.segmented)
            }
            Toggle("Surcharge on 9× / 12×", isOn: $surcharge)
        }
    }
}

struct PriceHistogramDemo: View {
    @State private var low = 800.0
    @State private var high = 3_200.0
    @State private var barHeight = 56.0
    @State private var accent = false
    @State private var showsBounds = true
    @State private var showsCount = true
    @State private var currency = "TRY"

    private let bins = [2, 5, 9, 14, 18, 22, 19, 12, 8, 5, 3, 2]

    private var histogram: PriceHistogram {
        var h = PriceHistogram(bins: bins, lowerValue: $low, upperValue: $high, in: 0...5_000)
            .barHeight(barHeight).currency(currency).showsBounds(showsBounds)
        if accent { h = h.accent(SemanticColor.purple.base) }
        if showsCount { h = h.resultCount(bins.reduce(0, +)) }
        return h
    }

    var body: some View {
        ComponentStage("PriceHistogram", inspector: [("low", "\(Int(low))"), ("high", "\(Int(high))")]) {
            histogram.frame(maxWidth: 360)
        } knobs: {
            HStack { Text("Bar height"); SwiftUI.Slider(value: $barHeight, in: 32...96, step: 2); Text("\(Int(barHeight))").font(.caption.monospacedDigit()) }
            Picker("Currency", selection: $currency) {
                Text("TRY").tag("TRY"); Text("EUR").tag("EUR"); Text("USD").tag("USD")
            }.pickerStyle(.segmented)
            Toggle("Purple accent", isOn: $accent)
            Toggle("Shows min/max bounds", isOn: $showsBounds)
            Toggle("Result count", isOn: $showsCount)
        }
    }
}

// MARK: - Organisms

struct FareSummaryDemo: View {
    @State private var taxes = true
    @State private var discount = true
    @State private var infoButtons = true
    @State private var footerIdx = 0               // 0 none · 1 terms · 2 CTA
    @State private var currency = "TRY"

    private let footers = ["None", "Terms", "CTA"]

    private var total: Decimal {
        var t: Decimal = 1_100
        if taxes { t += 199 }
        if discount { t -= 100 }
        return t
    }

    private var lines: [FareLine] {
        var l: [FareLine] = [.item("Base fare", 1_100)]
        if taxes { l.append(.item("Taxes & fees", 199, info: infoButtons ? "Airport tax + carrier surcharge" : nil)) }
        if discount { l.append(.discount("Member discount", 100, info: infoButtons ? "Applied automatically for Gold members" : nil)) }
        l.append(.total("Total", total))
        return l
    }

    private var summary: FareSummary {
        var s = FareSummary(lines, currencyCode: currency).onInfo { line in flash("Info: \(line.id)") }
        switch footerIdx {
        case 1: s = s.footer { InlineText("By booking you accept the Fare rules.", links: [("Fare rules", { flash("Fare rules") })]) }
        case 2: s = s.footer { PrimaryButton("Continue to payment") { flash("Continue") }.size(.small) }
        default: break
        }
        return s
    }

    var body: some View {
        ComponentStage("FareSummary", inspector: [("lines", "\(lines.count)"), ("total", "\(total)")]) {
            summary.frame(maxWidth: 360)
        } knobs: {
            Toggle("Taxes & fees line", isOn: $taxes)
            Toggle("Member discount line", isOn: $discount)
            Toggle("Info buttons (tap to flash)", isOn: $infoButtons)
            Picker("Footer slot", selection: $footerIdx) {
                ForEach(footers.indices, id: \.self) { Text(footers[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Currency", selection: $currency) {
                Text("TRY").tag("TRY"); Text("EUR").tag("EUR"); Text("USD").tag("USD")
            }.pickerStyle(.segmented)
        }
    }
}

struct FlightCardDemo: View {
    @State private var multiLeg = false
    @State private var stops = 0.0
    @State private var price = 1_299.0
    @State private var badge = true
    @State private var selectable = true
    @State private var favorite = false
    @State private var isFav = false
    @State private var scarcity = false
    @State private var fareBrand = false
    @State private var airlineIcon = "airplane.circle.fill"
    @State private var customFooter = false

    private let dep = Date()

    private var card: FlightCard {
        var c: FlightCard
        if multiLeg {
            c = FlightCard(legs: [
                FlightLeg(airline: "Anadolu Air", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600)),
                FlightLeg(airline: "Blue Wings", from: "AMS", to: "IST",
                          departure: dep.addingTimeInterval(72 * 3_600), arrival: dep.addingTimeInterval(78 * 3_600),
                          stops: 1, layover: "1 stop · 2h 10m · CDG"),
            ])
        } else {
            c = FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: dep.addingTimeInterval(2 * 3_600 + 20 * 60))
                .stops(Int(stops))
        }
        c = c.price(Decimal(price)).airlineIcon(airlineIcon)
        if badge { c = c.badge("Cheapest") }
        if favorite { c = c.favorite($isFav) }
        if scarcity { c = c.scarcity(3) }
        if fareBrand { c = c.fareBrand("Eco Flex") }
        if customFooter {
            c = c.footer {
                HStack {
                    Label("Free cancellation", systemImage: "checkmark.shield.fill")
                        .textStyle(.labelSm600).foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
                    Spacer()
                    TextLink("Details") { flash("Fare details") }
                }
            }
        } else if selectable {
            c = c.onSelect { flash("Flight selected") }
        }
        return c
    }

    var body: some View {
        ComponentStage("FlightCard", inspector: [
            ("mode", multiLeg ? "multi-leg" : "single"), ("price", "\(Int(price))"), ("favorite", "\(isFav)"),
        ]) {
            card.frame(maxWidth: 380)
        } knobs: {
            Toggle("Multi-leg itinerary", isOn: $multiLeg)
            if !multiLeg {
                Picker("Stops", selection: $stops) {
                    Text("Nonstop").tag(0.0); Text("1 stop").tag(1.0); Text("2 stops").tag(2.0)
                }.pickerStyle(.segmented)
            }
            NumberKnob(title: "Price", value: $price, range: 500...9_999, step: 50)
            IconKnob(title: "Airline icon", symbol: $airlineIcon, options: ["airplane.circle.fill", "airplane", "paperplane.fill"])
            Toggle("\"Cheapest\" badge", isOn: $badge)
            Toggle("Custom footer (overrides Select)", isOn: $customFooter)
            if !customFooter { Toggle("Select button", isOn: $selectable) }
            Toggle("Favorite heart", isOn: $favorite)
            Toggle("Scarcity (3 seats left)", isOn: $scarcity)
            Toggle("Fare-brand chip (Eco Flex)", isOn: $fareBrand)
        }
    }
}

struct LocationCardDemo: View {
    @State private var subtitle = true
    @State private var distance = true
    @State private var directions = true
    @State private var pois = false
    @State private var snapshot = false
    @State private var mapHeight = 140.0
    @State private var spanMeters = 800.0

    private var card: LocationCard {
        var c = LocationCard(title: "Marina Bay Hotel", latitude: 38.4237, longitude: 27.1428)
            .mapHeight(mapHeight)
            .spanMeters(spanMeters)
            .onTap { flash("Location tapped") }
        if subtitle { c = c.subtitle("Kordon Cd. No:12, İzmir") }
        if distance { c = c.distance("1.2 km to center") }
        if directions { c = c.directions() }
        if pois {
            c = c.pois([
                LocationPin(title: "Beach", latitude: 38.4265, longitude: 27.1390),
                LocationPin(title: "Marina", latitude: 38.4210, longitude: 27.1450),
            ])
        }
        if snapshot { c = c.snapshot() }
        return c
    }

    var body: some View {
        ComponentStage("LocationCard", inspector: [("mode", snapshot ? "snapshot" : "live map"), ("span", "\(Int(spanMeters))m")]) {
            card.frame(maxWidth: 360)
        } knobs: {
            Toggle("Subtitle (address)", isOn: $subtitle)
            Toggle("Distance line", isOn: $distance)
            Toggle("Directions button", isOn: $directions)
            Toggle("Points of interest", isOn: $pois)
            Toggle("Static snapshot (list-perf)", isOn: $snapshot)
            HStack { Text("Map height"); SwiftUI.Slider(value: $mapHeight, in: 100...240, step: 10); Text("\(Int(mapHeight))").font(.caption.monospacedDigit()) }
            HStack { Text("Zoom (span)"); SwiftUI.Slider(value: $spanMeters, in: 200...5_000, step: 100); Text("\(Int(spanMeters))m").font(.caption.monospacedDigit()) }
        }
    }
}

struct LoyaltyCardDemo: View {
    @State private var points = 8_430.0
    @State private var tier = "Gold"
    @State private var memberName = true
    @State private var progress = true
    @State private var progressValue = 0.62
    @State private var logo = true
    @State private var tierIcon = "seal.fill"
    @State private var unit = "pts"
    @State private var gradientOverride = false
    @State private var membershipIdx = 1              // 0 none · 1 QR · 2 barcode
    @State private var flippable = true
    @State private var animates = true

    private let tiers = ["Silver", "Gold", "Platinum"]
    private let membershipKinds = ["None", "QR", "Barcode"]

    private var card: LoyaltyCard {
        var c = LoyaltyCard(tier: tier, points: Int(points)).unit(unit).animatesValue(animates)
        if memberName { c = c.memberName("Elif Kaya") }
        if progress { c = c.progress(progressValue, toNextTier: "Platinum") }
        if gradientOverride { c = c.gradient([SemanticColor.purple.base, SemanticColor.pink.base]) }
        if logo {
            c = c.logo { Image(systemName: "airplane.circle.fill").font(.title3).foregroundStyle(.white) }
        } else {
            c = c.icon(tierIcon)
        }
        switch membershipIdx {
        case 1: c = c.membership(.qr("MEMBER-8430-ELIF"))
        case 2: c = c.membership(.barcode("8430000000431"))
        default: break
        }
        if flippable { c = c.flippable() }
        return c
    }

    var body: some View {
        ComponentStage("LoyaltyCard", inspector: [
            ("tier", tier), ("points", "\(Int(points))"), ("membership", membershipKinds[membershipIdx]),
        ]) {
            VStack(spacing: 8) {
                card.frame(maxWidth: 340)
                if membershipIdx > 0 && flippable {
                    Text("Tap the card to flip →").font(.caption).foregroundStyle(.secondary)
                }
            }
        } knobs: {
            NumberKnob(title: "Points", value: $points, range: 0...50_000, step: 10)
            Picker("Tier", selection: $tier) {
                ForEach(tiers, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Unit", selection: $unit) {
                Text("pts").tag("pts"); Text("miles").tag("miles"); Text("points").tag("points")
            }.pickerStyle(.segmented)
            Toggle("Member name", isOn: $memberName)
            Toggle("Progress to next tier", isOn: $progress)
            if progress { HStack { Text("Progress"); SwiftUI.Slider(value: $progressValue, in: 0...1) } }
            Toggle("Gradient override (purple→pink)", isOn: $gradientOverride)
            Toggle("Brand logo", isOn: $logo)
            if !logo { IconKnob(title: "Tier icon", symbol: $tierIcon, options: ["seal.fill", "crown.fill", "star.fill", "diamond.fill"]) }
            Picker("Membership code", selection: $membershipIdx) {
                ForEach(membershipKinds.indices, id: \.self) { Text(membershipKinds[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Flippable (needs membership)", isOn: $flippable)
            Toggle("Animate value on change", isOn: $animates)
        }
    }
}

struct ReviewCardDemo: View {
    @State private var score = 9.2
    @State private var title = true
    @State private var date = true
    @State private var verified = true
    @State private var stars = false
    @State private var expandable = false
    @State private var photos = false
    @State private var actions = false

    private let longText = "Spotless rooms and a great location right by the marina. Breakfast was excellent and the staff went out of their way to help with an early check-in. The rooftop pool had a stunning sunset view — easily the highlight of the trip."

    private var photoURLs: [URL] {
        ["1027", "1035", "1039"].compactMap { URL(string: "https://picsum.photos/id/\($0)/200/200") }
    }

    private var card: ReviewCard {
        var c = ReviewCard(author: "Elif Kaya", score: score, text: longText)
            .verified(verified).stars(stars).expandable(expandable)
        if title { c = c.title("Would absolutely stay again") }
        if date { c = c.date(.now) }
        if photos { c = c.photos(photoURLs).onPhotoTap { flash("Photo \($0 + 1) tapped") } }
        if actions {
            c = c.actions {
                HStack {
                    TextLink("Helpful") { flash("Marked helpful") }
                    Spacer()
                    TextLink("Report") { flash("Reported") }
                }
            }
        }
        return c
    }

    var body: some View {
        ComponentStage("ReviewCard", inspector: [("score", String(format: "%.1f", score)), ("verified", "\(verified)")]) {
            card.frame(maxWidth: 360)
        } knobs: {
            HStack { Text("Score"); SwiftUI.Slider(value: $score, in: 0...10, step: 0.1); Text(String(format: "%.1f", score)).font(.caption.monospacedDigit()) }
            Toggle("Title", isOn: $title)
            Toggle("Date", isOn: $date)
            Toggle("Verified seal", isOn: $verified)
            Toggle("Stars (instead of score badge)", isOn: $stars)
            Toggle("Expandable (Read more)", isOn: $expandable)
            Toggle("Photo strip", isOn: $photos)
            Toggle("Actions (Helpful / Report)", isOn: $actions)
        }
    }
}

struct SeatMapDemo: View {
    @State private var picked: Set<String> = ["12C"]
    @State private var layoutIdx = 0
    @State private var rowCount = 18.0
    @State private var maxSel = 3.0
    @State private var seatSize = 44.0
    @State private var showsLabels = true
    @State private var legend = true
    @State private var showInfo = true
    @State private var recommended = true
    @State private var decks = false
    @State private var staggered = false
    @State private var blockExit = false
    @State private var fuselage = false
    @State private var zoomable = false
    @State private var displayIdx = 0        // 0 icon · 1 number · 2 custom
    @State private var tightAisle = false

    // Column patterns: letters = seats, spaces = aisle gaps (repeat = wider gap).
    private let layouts: [(String, String)] = [
        ("3 · 3", "ABC DEF"),
        ("3 · 4 · 3", "ABC DEFG HJK"),
        ("2 · 3 · 2", "AB CDE FG"),
        ("3 · 1 · 2", "ABC DE"),
        ("3 · wide · 3", "ABC  DEF"),
    ]
    // Per-row patterns (each row a different shape), cycled to fill the cabin.
    private let staggerCycle = ["ABC DEF", "AB CDE F", "ABC DE", "AB CD EF"]

    private let sold: Set<String> = ["12B", "13E", "16A", "5C"]

    private func seatInfo(_ id: String, _ row: Int, _ col: String) -> SeatInfo {
        let exit = (row == 14)
        let legroom = (row == 11)
        let business = !decks && row <= 2                         // front cabin = Business
        let tier: SeatTier = business ? .business : exit ? .exit : legroom ? .extraLegroom : .standard
        let price: Decimal = business ? 600 : exit ? 220 : legroom ? 150 : 80
        let floor: Int? = decks ? (row <= rowSplit ? 1 : 2) : nil
        return SeatInfo(available: !sold.contains(id), price: price, tier: tier, floor: floor)
    }

    private var rowSplit: Int { Int(rowCount) / 2 }
    private var rows: [Int] { Array(1...Int(rowCount)) }
    private var staggerPatterns: [String] { rows.map { staggerCycle[($0 - 1) % staggerCycle.count] } }
    private var selectedLabel: String { picked.isEmpty ? "—" : picked.sorted().joined(separator: ", ") }

    private var map: SeatMap {
        let base = staggered
            ? SeatMap(rowPatterns: staggerPatterns, selection: $picked, seat: seatInfo)
            : SeatMap(columns: layouts[layoutIdx].1, rows: rows, selection: $picked, seat: seatInfo)
        var m = base
            .maxSelection(Int(maxSel)).seatSize(seatSize)
            .showsLabels(showsLabels).legend(legend).showsSeatInfo(showInfo)
            .fuselage(fuselage).currency("USD").zoomable(zoomable)
        switch displayIdx {
        case 1: m = m.seatDisplay(.number)
        case 2: m = m.seatLabel { ctx in
            if ctx.isSelected { Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(.white) }
            else if ctx.isOccupied { Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary) }
            else { Text(ctx.seat.id).textStyle(.overline500).foregroundStyle(Theme.shared.text(.textSecondary)).minimumScaleFactor(0.5) }
        }
        default: m = m.seatDisplay(.icon)
        }
        if tightAisle { m = m.aisleWidth(seatSize * 0.55) }
        if recommended { m = m.recommended(["11C", "12F"]) }
        if blockExit { m = m.seatEnabled { !$0.isExitRow } }
        return m
    }

    var body: some View {
        ComponentStage("SeatMap", inspector: [("layout", staggered ? "staggered" : layouts[layoutIdx].0), ("rows", "\(Int(rowCount))"), ("selected", selectedLabel)]) {
            map
        } knobs: {
            Toggle("Staggered rows (per-row patterns)", isOn: $staggered)
            Picker("Row layout", selection: $layoutIdx) {
                ForEach(layouts.indices, id: \.self) { Text(layouts[$0].0).tag($0) }
            }.pickerStyle(.segmented).disabled(staggered)
            Text(staggered
                 ? "rowPatterns: cycles \(staggerCycle.map { "\"\($0.replacingOccurrences(of: " ", with: "␣"))\"" }.joined(separator: ", "))"
                 : "columns: \"\(layouts[layoutIdx].1.replacingOccurrences(of: " ", with: "␣"))\"  ·  letters = seats, ␣ = gap")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Text("Rows"); SwiftUI.Slider(value: $rowCount, in: 6...30, step: 1); Text("\(Int(rowCount))").font(.caption.monospacedDigit()) }
            Picker("Seat display", selection: $displayIdx) {
                Text("Icon").tag(0); Text("Number").tag(1); Text("Custom").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Tight aisle (default: full-width gap)", isOn: $tightAisle)
            Toggle("Two decks (floor 1 / 2)", isOn: $decks)
            Toggle("Seat detail + total bar", isOn: $showInfo)
            Toggle("Fare-tier legend", isOn: $legend)
            Toggle("Recommended seats (★)", isOn: $recommended)
            Toggle("Block exit rows (seatEnabled)", isOn: $blockExit)
            Toggle("Seat labels (row/column)", isOn: $showsLabels)
            Toggle("Zoomable (pinch)", isOn: $zoomable)
            Toggle("Fuselage frame (optional, off)", isOn: $fuselage)
            HStack { Text("Max selection"); SwiftUI.Slider(value: $maxSel, in: 1...6, step: 1); Text("\(Int(maxSel))").font(.caption.monospacedDigit()) }
            HStack { Text("Seat size"); SwiftUI.Slider(value: $seatSize, in: 44...64, step: 2); Text("\(Int(seatSize))").font(.caption.monospacedDigit()) }
        }
    }
}

// MARK: - New composites (TicketStub · DestinationCard)

struct TicketStubDemo: View {
    @State private var stub = true
    @State private var codeIdx = 0        // 0 barcode · 1 QR
    @State private var perforation = true
    @State private var notchRadius = 12.0
    @State private var elevated = true

    @ViewBuilder private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("EMIRATES").textStyle(.labelMd700); Spacer(); Badge("Boarding").badgeStyle(.success).size(.small) }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) { Text("09:00").textStyle(.headingSm); Text("JFK").textStyle(.labelSm600).foregroundStyle(.secondary) }
                Spacer()
                Image(systemName: "airplane").foregroundStyle(Theme.shared.foreground(.fgHero))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) { Text("08:00").textStyle(.headingSm); Text("DPS").textStyle(.labelSm600).foregroundStyle(.secondary) }
            }
        }
    }

    private var ticketView: some View {
        let base = TicketStub { mainContent }
            .notchRadius(notchRadius)
            .perforation(perforation)
            .elevation(elevated ? .elevated : .soft)
        return Group {
            if stub {
                base.stub {
                    VStack(spacing: 8) {
                        if codeIdx == 0 { Barcode("BID12025BKG").height(46).showsValue() }
                        else { QRCode("https://travelia.app/pass/BID12025BKG").size(110) }
                        Text("Booking · BID12025BKG").textStyle(.bodySm400).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                base
            }
        }
    }

    var body: some View {
        ComponentStage("TicketStub", inspector: [("stub", "\(stub)"), ("code", codeIdx == 0 ? "barcode" : "QR")]) {
            ticketView.frame(maxWidth: 340)
        } knobs: {
            Toggle("Detachable stub", isOn: $stub)
            if stub {
                Picker("Stub code", selection: $codeIdx) { Text("Barcode").tag(0); Text("QR").tag(1) }.pickerStyle(.segmented)
                Toggle("Perforation line", isOn: $perforation)
                HStack { Text("Notch radius"); SwiftUI.Slider(value: $notchRadius, in: 4...20, step: 1); Text("\(Int(notchRadius))").font(.caption.monospacedDigit()) }
            }
            Toggle("Elevated shadow", isOn: $elevated)
        }
    }
}

struct DestinationCardDemo: View {
    @State private var isFav = true
    @State private var ribbon = true
    @State private var price = true
    @State private var rating = true
    @State private var overlayTitle = false
    @State private var tags = true
    @State private var badge = false
    @State private var aspect = 1.5

    private let url = URL(string: "https://picsum.photos/id/1036/600/400")

    private var card: DestinationCard {
        var c = DestinationCard("Bali & Unforgettable 3-Days", image: url)
            .subtitle("Indonesia")
            .favorite($isFav)
            .aspect(CGFloat(aspect))
            .overlayTitle(overlayTitle)
            .onTap { flash("Destination opened") }
        if ribbon { c = c.ribbon("Top #1") }
        if price { c = c.price(1_450) }
        if rating { c = c.rating(4.8) }
        if tags { c = c.tags(["Beach", "Culture"]) }
        if badge { c = c.badge("New") }
        return c
    }

    var body: some View {
        ComponentStage("DestinationCard", inspector: [("favorite", "\(isFav)"), ("layout", overlayTitle ? "overlay" : "below")]) {
            card.frame(maxWidth: 320)
        } knobs: {
            Toggle("Favorite heart", isOn: $isFav)
            Toggle("Ribbon (Top #1)", isOn: $ribbon)
            Toggle("Overlay title on image", isOn: $overlayTitle)
            Toggle("Price", isOn: $price)
            Toggle("Rating", isOn: $rating)
            Toggle("Tag chips", isOn: $tags)
            Toggle("Badge (New)", isOn: $badge)
            HStack { Text("Aspect"); SwiftUI.Slider(value: $aspect, in: 1...2, step: 0.05); Text(String(format: "%.2f", aspect)).font(.caption.monospacedDigit()) }
        }
    }
}

// A gallery showcase: the same column-pattern model rendered in several real
// cabin layouts, so the variations can be compared at a glance.
struct SeatLayoutsShowcase: View {
    private let uniform: [(title: String, pattern: String)] = [
        ("3 · 1 · 2  — mixed (3 seats, 1 gap, 2 seats)", "ABC DE"),
        ("3 · ⟷ · 3  — 2-column (wide) aisle", "ABC  DEF"),
        ("3 · 3  — narrow-body (A320 / 737)", "ABC DEF"),
        ("2 · 3 · 2  — mid-size (767)", "AB CDE FG"),
        ("3 · 4 · 3  — wide-body (777 / A350)", "ABC DEFG HJK"),
    ]

    private func info(_ id: String, _ row: Int, _ col: String) -> SeatInfo {
        SeatInfo(available: id != "2B", price: 80,
                 tier: row == 1 ? .extraLegroom : row == 3 ? .exit : .standard)
    }

    @ViewBuilder private func block<V: View>(_ title: String, _ code: String, @ViewBuilder _ map: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textPrimary))
            Text(code).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) { map().padding(.vertical, 2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Seat display modes — the different content models, drawn.
            block("Display · Icon (default)", ".seatDisplay(.icon)") { displayMap { $0 } }
            block("Display · Seat number", ".seatDisplay(.number)") { displayMap { $0.seatDisplay(.number) } }
            block("Display · Initials + seat number", ".seatDisplay(.initialsAndNumber) · passenger assignment") {
                SeatMap(columns: "ABC DEF", rows: [1, 2], selection: .constant(["1A", "1C", "2D"])) { id, _, _ in
                    SeatInfo(available: id != "2E")
                }
                .seatDisplay(.initialsAndNumber)
                .passengers([Passenger(id: "p1", initials: "EA"), Passenger(id: "p2", initials: "MK"), Passenger(id: "p3", initials: "JD")],
                            assignment: .constant(["p1": "1A", "p2": "1C", "p3": "2D"]))
                .showsLabels()
            }
            block("Display · Custom UI (name init. + avatar on selected)", ".seatLabel { ctx in … }") {
                displayMap { $0.seatLabel { ctx in customLabel(ctx) } }
            }
            block("Tight aisle (opt-in) vs default full-width gap", ".aisleWidth(26)") {
                displayMap { $0.aisleWidth(26) }
            }
            block("Branded tier colours (generic override)", ".tierColors([.premium: .indigo, .business: .brown])") {
                SeatMap(rowPatterns: ["ABC DEF", "ABC DEF", "ABC DEF"], selection: .constant(["1B"])) { _, row, _ in
                    SeatInfo(tier: row == 1 ? .premium : row == 2 ? .business : .standard)
                }
                .tierColors([.premium: .indigo, .business: .brown])
                .showsLabels().legend()
            }
            // Per-row — each row its own shape (the key point).
            block("Per-row (staggered) — each row differs",
                  #"rowPatterns: ["ABC DE", "AB CDE", "AB CD EF"]"#) {
                SeatMap(rowPatterns: ["ABC DE", "AB CDE", "AB CD EF"], selection: .constant([])) { id, _, _ in
                    SeatInfo(available: id != "2C")
                }.showsLabels()
            }
            // Cabin classes — tiers, incl. business & first.
            block("Cabin classes — First · Business · Premium · Economy",
                  "tier: .first / .business / .premium / .standard") {
                SeatMap(rowPatterns: ["AB CD", "AB CD", "ABC DEF", "ABC DEF"], selection: .constant(["1A"])) { _, row, _ in
                    let tier: SeatTier = row == 1 ? .first : row == 2 ? .business : row == 3 ? .premium : .standard
                    return SeatInfo(available: true, tier: tier)
                }.showsLabels().legend()
            }
            // Uniform variations.
            ForEach(uniform, id: \.pattern) { item in
                block(item.title, "columns: \"\(item.pattern.replacingOccurrences(of: " ", with: "␣"))\"") {
                    SeatMap(columns: item.pattern, rows: Array(1...3), selection: .constant(["1A"]), seat: info).showsLabels()
                }
            }
        }
    }

    private func displayMap(_ transform: (SeatMap) -> SeatMap) -> some View {
        let base = SeatMap(columns: "ABC DEF", rows: [1, 2], selection: .constant(["1B"])) { id, _, _ in
            SeatInfo(available: id != "2E")
        }.showsLabels()
        return transform(base)
    }

    private let names = ["1A": "EA", "1C": "MK", "1D": "JD", "2A": "SL", "2D": "RT", "2F": "BC"]

    @ViewBuilder private func customLabel(_ ctx: SeatContext) -> some View {
        if ctx.isSelected {
            Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(.white)
        } else if ctx.isOccupied {
            Image(systemName: "xmark").font(.caption2).foregroundStyle(Theme.shared.text(.textTertiary))
        } else if let initials = names[ctx.seat.id] {
            Text(initials).textStyle(.overline500).foregroundStyle(Theme.shared.text(.textSecondary))
        } else {
            Image(systemName: "chair").font(.caption).foregroundStyle(Theme.shared.text(.textTertiary))
        }
    }
}

// MARK: - Flight-booking suite (FareFeatureRow · FareFamilyCard · FlightResultRow · PriceTrendChart · DatePriceStrip · SortSummaryBar · FlightSearchBar)

struct FareFeatureRowDemo: View {
    @State private var statusIdx = 0
    @State private var detail = true

    private let statuses: [(String, FareFeatureStatus)] = [("Info", .info), ("Included", .included), ("Excluded", .excluded)]

    var body: some View {
        ComponentStage("FareFeatureRow", inspector: [("status", statuses[statusIdx].0)]) {
            VStack(alignment: .leading, spacing: 8) {
                FareFeatureRow("Checked baggage", systemImage: "suitcase.fill", detail: detail ? "1 × 20 kg" : nil, status: statuses[statusIdx].1)
                FareFeatureRow("Cabin bag", systemImage: "handbag", detail: detail ? "55×40×23 cm" : nil)
                FareFeatureRow("Non-refundable", systemImage: "nosign", status: .excluded)
            }.frame(maxWidth: 320)
        } knobs: {
            Picker("Status", selection: $statusIdx) {
                ForEach(statuses.indices, id: \.self) { Text(statuses[$0].0).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Detail text", isOn: $detail)
        }
    }
}

struct FareFamilyCardDemo: View {
    @State private var accentIdx = 0
    @State private var selectable = true
    @State private var selected = true
    @State private var rules = true

    private let accents: [(String, SemanticColor)] = [("Green", .success), ("Orange", .orange), ("Purple", .purple)]

    private var features: [FareFeature] {
        var f: [FareFeature] = [
            FareFeature("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm"),
            FareFeature("Carry-on", systemImage: "suitcase.rolling", detail: "55×40×23 cm"),
            FareFeature("Checked", systemImage: "suitcase.fill", detail: "1 × 15 kg"),
        ]
        if rules {
            f.append(FareFeature("Non-refundable", systemImage: "nosign", status: .excluded))
            f.append(FareFeature("Non-changeable", systemImage: "nosign", status: .excluded))
        }
        return f
    }

    private var card: FareFamilyCard {
        var c = FareFamilyCard("Super Eco", price: 1_871.99).accent(accents[accentIdx].1).features(features).currency("TRY")
        if selectable { c = c.selection($selected) } else { c = c.onSelect { flash("Fare selected") } }
        return c
    }

    var body: some View {
        ComponentStage("FareFamilyCard", inspector: [("accent", accents[accentIdx].0), ("mode", selectable ? "radio" : "CTA")]) {
            card.frame(maxWidth: 300)
        } knobs: {
            Picker("Accent", selection: $accentIdx) {
                ForEach(accents.indices, id: \.self) { Text(accents[$0].0).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Selectable (radio)", isOn: $selectable)
            if selectable { Toggle("Selected", isOn: $selected) }
            Toggle("Rules (excluded rows)", isOn: $rules)
        }
    }
}

struct FlightResultRowDemo: View {
    @State private var stops = 0.0
    @State private var roundTrip = false
    @State private var badge = true
    @State private var baggage = true
    @State private var fav = false
    @State private var favorite = false
    @State private var bookmark = false
    @State private var savedFlag = false
    @State private var total = true
    @State private var urgency = true
    @State private var select = true
    @State private var details = true

    private let dep = Date()

    private var row: FlightResultRow {
        var r = FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
            .flightNo("TK 2434").cabin("Economy").price(3_538.99).stops(Int(stops))
        if roundTrip {                                   // stacked return leg via FlightRoute
            r = r.returnLeg(from: "AYT", to: "IST", departure: dep.addingTimeInterval(5 * 86400),
                            arrival: dep.addingTimeInterval(5 * 86400 + 105 * 60), stops: Int(stops))
        }
        if badge { r = r.badge("Cheapest") }
        if baggage { r = r.baggage("15 kg") }
        if fav { r = r.favorite($favorite) }
        if bookmark { r = r.bookmark($savedFlag) }
        if total { r = r.totalPrice(43_068, label: "3 travellers") }
        if urgency { r = r.urgency("5 seats left!") }
        if select { r = r.onSelect("Select") { flash("Flight selected") } }
        if details { r = r.onDetails { flash("Details") } }
        return r
    }

    var body: some View {
        ComponentStage("FlightResultRow", inspector: [("stops", "\(Int(stops))"), ("trip", roundTrip ? "round" : "one-way")]) {
            row.frame(maxWidth: 380)
        } knobs: {
            Picker("Stops", selection: $stops) { Text("Direct").tag(0.0); Text("1 stop").tag(1.0); Text("2 stops").tag(2.0) }.pickerStyle(.segmented)
            Toggle("Round trip (.returnLeg — stacked FlightRoute)", isOn: $roundTrip)
            Toggle("Badge (\"Cheapest\")", isOn: $badge)
            Toggle("Baggage chip", isOn: $baggage)
            Toggle("Total price line (3 travellers)", isOn: $total)
            Toggle("Urgency (\"5 seats left!\")", isOn: $urgency)
            Toggle("Favorite heart", isOn: $fav)
            Toggle("Bookmark (save)", isOn: $bookmark)
            Toggle("Select button", isOn: $select)
            Toggle("Details link", isOn: $details)
        }
    }
}

struct PriceTrendChartDemo: View {
    @State private var sel = 6
    @State private var showTitle = true
    @State private var axis = true
    @State private var scroll = true
    @State private var values = true
    @State private var accent = false

    private let points: [PriceTrendPoint] = (12...40).map {
        PriceTrendPoint("\($0)", sublabel: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][$0 % 7], price: Decimal(1400 + ($0 * 37) % 700))
    }

    private var chart: PriceTrendChart {
        var c = PriceTrendChart(points, selection: $sel).currency("TRY").onPage(prev: {}, next: {})
            .showsAxis(axis).scrollable(scroll).showsValues(values)
        if showTitle { c = c.title("July") }
        if accent { c = c.accent(.purple) }
        return c
    }

    var body: some View {
        ComponentStage("PriceTrendChart", inspector: [("selected", points[sel].label), ("days", "\(points.count)")]) {
            chart.frame(maxWidth: 360)
        } knobs: {
            Toggle("Title (month)", isOn: $showTitle)
            Toggle("Min/max axis lines", isOn: $axis)
            Toggle("Horizontal scroll (fixed bar width)", isOn: $scroll)
            Toggle("Selected price on top", isOn: $values)
            Toggle("Purple accent", isOn: $accent)
            Text("\(points.count) days, bars on a shared baseline. Also: .maxDays(_) · .barWidth · .spacing · .cornerRadius · .gradient · .selectionColor.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DatePriceStripDemo: View {
    @State private var sel = 1
    @State private var columns = 3.0
    @State private var cheapest = true
    @State private var paging = true

    private let items = [
        DatePriceItem("17 Jul", price: 1_697.99), DatePriceItem("18 Jul", price: 1_767.99),
        DatePriceItem("19 Jul", price: 1_960.99), DatePriceItem("20 Jul", price: 1_914.99),
        DatePriceItem("21 Jul", price: 1_474.99), DatePriceItem("22 Jul", price: 1_483.99),
    ]

    private var strip: DatePriceStrip {
        var s = DatePriceStrip(items, selection: $sel).columns(Int(columns)).currency("TRY").highlightCheapest(cheapest)
        if paging { s = s.onPage(prev: { flash("Previous dates") }, next: { flash("Next dates") }) }
        return s
    }

    var body: some View {
        ComponentStage("DatePriceStrip", inspector: [("selected", items[sel].date)]) {
            strip.frame(maxWidth: 380)
        } knobs: {
            HStack { Text("Columns"); SwiftUI.Slider(value: $columns, in: 2...4, step: 1); Text("\(Int(columns))").font(.caption.monospacedDigit()) }
            Toggle("Paging chevrons (‹ ›)", isOn: $paging)
            Toggle("Auto-highlight cheapest (green)", isOn: $cheapest)
            Text("Cards are the reusable DatePriceCard component.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FlightRouteDemo: View {
    @State private var stops = 0.0
    @State private var nextDay = false

    private let dep = Date()

    var body: some View {
        ComponentStage("FlightRoute", inspector: [("stops", "\(Int(stops))"), ("nextDay", "\(nextDay)")]) {
            FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(95 * 60))
                .stops(Int(stops)).nextDay(nextDay)
                .frame(maxWidth: 300)
        } knobs: {
            Picker("Stops", selection: $stops) { Text("Direct").tag(0.0); Text("1").tag(1.0); Text("2").tag(2.0) }.pickerStyle(.segmented)
            Toggle("Arrives next day (+1)", isOn: $nextDay)
            Text("One flight leg — reused inside FlightResultRow (round-trip stacks two).").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SortSummaryBarDemo: View {
    @State private var sel = 0
    @State private var icons = true
    @State private var more = true

    private var bar: SortSummaryBar {
        var b = SortSummaryBar([
            SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: icons ? "star.fill" : nil),
            SortOption("Cheapest", value: "₺2.178", subtitle: "6h 45m", icon: icons ? "tag.fill" : nil),
            SortOption("Fastest", value: "₺2.852", subtitle: "1h 05m", icon: icons ? "bolt.fill" : nil),
            SortOption("Direct only", value: "₺2.852", subtitle: "1h 05m", icon: icons ? "arrow.right" : nil),
        ], selection: $sel)
        if more { b = b.onMore { flash("More sort") } }
        return b
    }

    var body: some View {
        ComponentStage("SortSummaryBar", inspector: [("selected", "\(sel)")]) {
            bar
        } knobs: {
            Toggle("Per-option icons", isOn: $icons)
            Toggle("Trailing \"more sort\" button", isOn: $more)
            Text("Tap an option — each previews its result. Built from the SortTab component.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SwapButtonDemo: View {
    @State private var a = "IST"
    @State private var b = "AYT"
    @State private var size = 34.0
    @State private var bordered = true

    var body: some View {
        ComponentStage("SwapButton", inspector: [("from", a), ("to", b)]) {
            HStack(spacing: 16) {
                Text(a).textStyle(.headingSm)
                SwapButton { let t = a; a = b; b = t }.size(size).bordered(bordered)
                Text(b).textStyle(.headingSm)
            }
        } knobs: {
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 28...56, step: 2); Text("\(Int(size))").font(.caption.monospacedDigit()) }
            Toggle("Bordered", isOn: $bordered)
        }
    }
}

struct FieldButtonDemo: View {
    @State private var taps = 0
    @State private var showLabel = true
    @State private var icon = true
    @State private var placeholder = false

    private var field: FieldButton {
        var f = FieldButton(placeholder ? "Select passengers" : "2 Passengers · Economy") { taps += 1; flash("Field tapped") }
        if showLabel { f = f.label("Passengers") }
        if icon { f = f.icon("person.2.fill") }
        if placeholder { f = f.placeholder() }
        return f
    }

    var body: some View {
        ComponentStage("FieldButton", inspector: [("taps", "\(taps)")]) {
            field.frame(maxWidth: 320)
        } knobs: {
            Toggle("Label above value", isOn: $showLabel)
            Toggle("Leading icon", isOn: $icon)
            Toggle("Placeholder (nothing chosen)", isOn: $placeholder)
        }
    }
}

struct SearchFieldDemo: View {
    @State private var modeIdx = 0        // 0 location · 1 dates · 2 passengers · 3 empty
    @State private var focused = false
    @State private var trailingIdx = 0    // 0 none · 1 chevron · 2 clear
    @State private var shadow = false
    @State private var brand = false      // per-element restyle (chip + border)

    private let modes = ["Location", "Dates", "Passengers", "Empty"]

    private var placeholder: String { modeIdx == 3 ? "Where do you want to go?" : "From" }

    private var field: SearchField {
        var f = SearchField(placeholder) { flash("Field tapped") }
        switch modeIdx {
        case 0: f = f.value(code: "SAW", title: "Istanbul", subtitle: "Sabiha Gökçen Havalimanı")
        case 1: f = f.dateRange(SearchDate(badge: "23 Jul '24", label: "Monday"),
                                SearchDate(badge: "27 Jul '24", label: "Friday"))
        case 2: f = f.passengers(badge: "4 Guests", [
            PassengerCount("person.fill", "2"), PassengerCount("figure.child", "1"),
            PassengerCount("figure.child.circle", "1"), PassengerCount("graduationcap.fill", "1"),
        ])
        default: break   // empty → placeholder
        }
        if focused { f = f.focused() }
        if shadow { f = f.showsShadow() }
        if brand {                                   // every element restyled via TOKEN keys (re-themes)
            f = f.chipColors(background: .bgHero, foreground: .textSecondaryInverse)
                .borderColor(.borderHero)
                .titleStyle(color: .textHero)
        }
        switch trailingIdx {
        case 1: f = f.trailing(.chevron)
        case 2: f = f.onClear { flash("Cleared") }
        default: f = f.trailing(.none)
        }
        return f
    }

    var body: some View {
        ComponentStage("SearchField", inspector: [("content", modes[modeIdx]), ("focused", "\(focused)")]) {
            field.frame(maxWidth: 340)
        } knobs: {
            Picker("Content", selection: $modeIdx) {
                ForEach(modes.indices, id: \.self) { Text(modes[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Text(".value(code:title:subtitle:) · .dateRange(_,_) · .passengers(badge:_) · or .content { … } for anything")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Trailing", selection: $trailingIdx) {
                Text("None").tag(0); Text("Chevron").tag(1); Text("Clear ✕").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Focused (active border)", isOn: $focused)
            Toggle("Soft shadow", isOn: $shadow)
            Toggle("Brand restyle (chip · border · title via modifiers)", isOn: $brand)
        }
    }
}

struct FilterRowDemo: View {
    @State private var on = true
    @State private var count = 128.0
    @State private var sep = true
    @State private var icon = false

    var body: some View {
        ComponentStage("FilterRow", inspector: [("selected", "\(on)")]) {
            FilterRow("Direct", isOn: $on)
                .count(count > 0 ? Int(count) : nil)
                .showsSeparator(sep)
                .icon(icon ? "airplane" : nil)
                .frame(maxWidth: 300)
        } knobs: {
            NumberKnob(title: "Count", value: $count, range: 0...500, step: 1)
            Toggle("Bottom separator", isOn: $sep)
            Toggle("Leading icon", isOn: $icon)
        }
    }
}

struct FilterListDemo: View {
    @State private var sel: Set<String> = ["direct"]
    @State private var bordered = true
    @State private var selectAll = false
    @State private var counts = true

    private var options: [FilterOption] {
        [FilterOption("Direct", count: counts ? 128 : nil, id: "direct"),
         FilterOption("1 stop", count: counts ? 64 : nil, id: "1stop"),
         FilterOption("2+ stops", count: counts ? 12 : nil, id: "2stop")]
    }

    private var list: FilterList {
        var f = FilterList(options, selection: $sel).title("Stops").bordered(bordered)
        if selectAll { f = f.selectAll("All connections") }
        return f
    }

    var body: some View {
        ComponentStage("FilterList", inspector: [("selected", "\(sel.count)")]) {
            list.frame(maxWidth: 320)
        } knobs: {
            Toggle("Bordered card", isOn: $bordered)
            Toggle("Select-all master row", isOn: $selectAll)
            Toggle("Result counts (N)", isOn: $counts)
            Text("Rows are the reusable FilterRow (Checkbox atom + title + count) — the etstur PopularFilters pattern, generic.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FilterBarDemo: View {
    @State private var sel: Set<String> = ["8"]
    @State private var showFilter = true
    @State private var showSort = true
    @State private var collapse = true
    @State private var sizeIdx = 1
    @State private var accent = false

    private let sizes: [FilterBarSize] = [.small, .medium, .large]
    private let chips: [QuickFilter] = [
        QuickFilter("8+ rating", id: "8"), QuickFilter("Ultra all-inclusive"), QuickFilter("All-inclusive"),
        QuickFilter("Seafront"), QuickFilter("Aquapark"), QuickFilter("Free cancellation"), QuickFilter("Kids club"),
    ]

    private var bar: FilterBar {
        var b = FilterBar(chips, selection: $sel).collapsible(collapse).size(sizes[sizeIdx])
        if accent { b = b.accent(.turquoise) }
        if showFilter { b = b.onFilter { flash("Filters") } }
        if showSort { b = b.onSort { flash("Sort") } }
        return b
    }

    var body: some View {
        ComponentStage("FilterBar", inspector: [("selected", "\(sel.count)")]) {
            bar
        } knobs: {
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
            Toggle("Filter button", isOn: $showFilter)
            Toggle("Sort button", isOn: $showSort)
            Toggle("Collapse leading on scroll", isOn: $collapse)
            Toggle("Turquoise accent (token)", isOn: $accent)
            Text("Scroll the chips → the leading Filter/Sort buttons minimize to icons (masking the chips underneath). Tap a chip to toggle.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct HotelResultCardDemo: View {
    @State private var fav = true
    @State private var badge = true
    @State private var promos = true
    @State private var extra = true

    private var card: HotelResultCard {
        var c = HotelResultCard(name: "Mirage Park Resort")
            .location("Kemer, Antalya")
            .score(8.9, label: "Very good", reviews: 949)
            .features(["Premium All-inclusive", "Seafront"])
            .stay("2 Rooms · 4 Nights")
            .original(248_000).discountBadge("-23%").price(190_960)
            .favorite($fav).onSelect { flash("Hotel selected") }
        if badge { c = c.badge("Deal") }
        if promos { c = c.promos(["Special 7.500 TL MaxiPoint!", "50% deposit"]) }
        if extra { c = c.extraDiscount("Extra 8%", 175_683) }
        return c
    }

    var body: some View {
        ComponentStage("HotelResultCard", inspector: [("favorite", "\(fav)")]) {
            card.frame(maxWidth: 360)
        } knobs: {
            Toggle("Corner badge", isOn: $badge)
            Toggle("Promo chips", isOn: $promos)
            Toggle("Extra-discount line", isOn: $extra)
            Text("Composed from RemoteImage · ScoreBadge · PriceTag · Badge. Every part is a modifier.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct RoomCardDemo: View {
    @State private var selectable = false
    @State private var selected = false
    @State private var badge = true

    private var card: RoomCard {
        var c = RoomCard(name: "Deluxe Room, Sea View")
            .board("All-inclusive").occupancy("2 adults, 1 child")
            .features([
                FareFeature("Free cancellation", systemImage: "checkmark.circle", status: .included),
                FareFeature("Breakfast included", systemImage: "cup.and.saucer", status: .included),
            ])
            .original(12_000).discountBadge("-20%").price(9_600).unit("/ night")
        if badge { c = c.badge("Last 2") }
        if selectable { c = c.selection($selected) } else { c = c.onSelect { flash("Room selected") } }
        return c
    }

    var body: some View {
        ComponentStage("RoomCard", inspector: [("selected", "\(selected)")]) {
            card.frame(maxWidth: 360)
        } knobs: {
            Toggle("Radio selection (vs Select button)", isOn: $selectable)
            Toggle("\"Last 2\" badge", isOn: $badge)
            Text("Reuses FareFeatureRow · PriceTag · Badge.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StickyBookingBarDemo: View {
    @State private var discount = true
    @State private var note = true
    @State private var enabled = true

    private var bar: StickyBookingBar {
        var b = StickyBookingBar("Book now") { flash("Book") }.price(9_600).ctaIcon("arrow.right").enabled(enabled)
        if discount { b = b.original(12_000).discountBadge("-20%") }
        if note { b = b.note("2 rooms · 4 nights") }
        return b
    }

    var body: some View {
        ComponentStage("StickyBookingBar", inspector: [("enabled", "\(enabled)")]) {
            bar.frame(maxWidth: 380)
        } knobs: {
            Toggle("Discount (original + badge)", isOn: $discount)
            Toggle("Note line", isOn: $note)
            Toggle("Enabled", isOn: $enabled)
            Text("Pin with .safeAreaInset(edge: .bottom) { … }.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PaymentCardFieldDemo: View {
    @State private var num = ""
    @State private var exp = ""
    @State private var cvv = ""
    @State private var name = ""
    @State private var holder = true

    private var field: PaymentCardField {
        var f = PaymentCardField(number: $num, expiry: $exp, cvv: $cvv)
        if holder { f = f.holder($name) }
        return f
    }

    var body: some View {
        ComponentStage("PaymentCardField", inspector: [("brand", CardBrand.detect(num).label.isEmpty ? "—" : CardBrand.detect(num).label)]) {
            field.frame(maxWidth: 360)
        } knobs: {
            Toggle("Cardholder field", isOn: $holder)
            Text("Type a number → brand auto-detects (4=Visa, 5=Mastercard, 9792=Troy). Groups 4-4-4-4, MM/YY.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct InstallmentPickerDemo: View {
    @State private var sel = 1

    var body: some View {
        ComponentStage("InstallmentPicker", inspector: [("selected", "\(sel)")]) {
            InstallmentPicker([
                InstallmentOption(count: 1, total: 9_600),
                InstallmentOption(count: 3, total: 9_900, monthly: 3_300),
                InstallmentOption(count: 6, total: 10_200, monthly: 1_700),
                InstallmentOption(count: 9, total: 10_800, monthly: 1_200),
            ], selection: $sel).currency("TRY").frame(maxWidth: 360)
        } knobs: {
            Text("Radio list of taksit plans — per-month × count and total.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MapPriceMarkerDemo: View {
    @State private var selected = true
    @State private var pointer = true
    @State private var fav = false

    private var marker: MapPriceMarker {
        var m = MapPriceMarker("₺1.250").selected(selected).pointer(pointer)
        if fav { m = m.icon("heart.fill") }
        return m
    }

    var body: some View {
        ComponentStage("MapPriceMarker", inspector: [("selected", "\(selected)")]) {
            marker.padding(24)
        } knobs: {
            Toggle("Selected (accent fill)", isOn: $selected)
            Toggle("Pointer", isOn: $pointer)
            Toggle("Leading icon", isOn: $fav)
            Text("Drop into any Map annotation — no MapKit dependency.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MapCalloutDemo: View {
    @State private var withScore = true
    @State private var withCTA = true

    private var callout: MapCallout {
        var c = MapCallout(title: "Mirage Park Resort").subtitle("Kemer, Antalya").price(9_600)
        if withScore { c = c.score(8.9) }
        if withCTA { c = c.onSelect { flash("Open hotel") } }
        return c
    }

    var body: some View {
        ComponentStage("MapCallout", inspector: [("cta", "\(withCTA)")]) {
            callout
        } knobs: {
            Toggle("Score badge", isOn: $withScore)
            Toggle("Tappable (chevron)", isOn: $withCTA)
            Text("The bubble over a tapped marker — thumbnail + name + score + price.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SuggestionRowDemo: View {
    @State private var nested = false
    @State private var selected = true
    @State private var code = true
    @State private var highlight = true
    @State private var accessoryIdx = 0   // 0 none · 1 chevron · 2 add

    private var row: SuggestionRow {
        var r = SuggestionRow("Ankara, Türkiye") { flash("Picked") }
            .icon("airplane").subtitle(nested ? "Ankara, Türkiye" : "Any")
            .nested(nested).selected(selected)
        if code { r = r.code(nested ? "ESB" : "ANK") }
        if highlight { r = r.highlight("Ank") }
        switch accessoryIdx { case 1: r = r.accessory(.chevron); case 2: r = r.accessory(.add); default: break }
        return r
    }

    var body: some View {
        ComponentStage("SuggestionRow", inspector: [("nested", "\(nested)"), ("selected", "\(selected)")]) {
            VStack(spacing: 2) {
                row
                if !nested { SuggestionRow("Esenboğa") { }.icon("airplane").code("ESB").subtitle("Ankara, Türkiye").nested().accessory(.chevron) }
            }
            .frame(maxWidth: 360)
        } knobs: {
            Toggle("Nested (child ↳ indent)", isOn: $nested)
            Toggle("Selected (tinted bg)", isOn: $selected)
            Toggle("Code (ANK)", isOn: $code)
            Toggle("Highlight match (\"Ank\")", isOn: $highlight)
            Picker("Accessory", selection: $accessoryIdx) { Text("None").tag(0); Text("Chevron").tag(1); Text("Add").tag(2) }.pickerStyle(.segmented)
            Text("Autocomplete result row — icon tile + title + code + subtitle, nesting for sub-airports.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AgentPriceRowDemo: View {
    @State private var rating = true
    @State private var badge = true
    @State private var warning = false
    @State private var recommended = true
    @State private var original = true

    private var row: AgentPriceRow {
        var r = AgentPriceRow("Trip.com") { flash("Go to Trip.com") }.icon("globe").price(3_538).cta("Go to site").recommended(recommended)
        if rating { r = r.rating(4.2) }
        if badge { r = r.badge("Cheapest") }
        if warning { r = r.warning("Self-transfer — you handle the connection") }
        if original { r = r.original(4_100) }
        return r
    }

    var body: some View {
        ComponentStage("AgentPriceRow", inspector: [("recommended", "\(recommended)")]) {
            row.frame(maxWidth: 380)
        } knobs: {
            Toggle("Rating", isOn: $rating)
            Toggle("Badge (Cheapest)", isOn: $badge)
            Toggle("Self-transfer warning", isOn: $warning)
            Toggle("Recommended (accent border)", isOn: $recommended)
            Toggle("Original price (strike)", isOn: $original)
            Text("The meta-search booking option — provider + price + CTA.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PriceAlertCardDemo: View {
    @State private var on = true
    @State private var showPrice = true
    @State private var trendIdx = 1   // 0 up · 1 down · 2 flat

    private var card: PriceAlertCard {
        var c = PriceAlertCard("Get price alerts", isOn: $on).subtitle("We'll notify you when this route's price changes")
        if showPrice {
            let t: PriceTrend = trendIdx == 0 ? .up : (trendIdx == 1 ? .down : .flat)
            c = c.price(3_538).trend(t, trendIdx == 0 ? "+5%" : (trendIdx == 1 ? "-8%" : "0%"))
        }
        return c
    }

    var body: some View {
        ComponentStage("PriceAlertCard", inspector: [("on", "\(on)")]) {
            card.frame(maxWidth: 380)
        } knobs: {
            Toggle("Current price + trend", isOn: $showPrice)
            Picker("Trend", selection: $trendIdx) { Text("Up").tag(0); Text("Down").tag(1); Text("Flat").tag(2) }.pickerStyle(.segmented)
            Text("Bell + copy + toggle. Trend down = green, up = red.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct RecentSearchRowDemo: View {
    @State private var round = true
    @State private var remove = false
    @State private var bordered = true

    private var row: RecentSearchRow {
        var r = RecentSearchRow(from: "IST", to: "AYT") { flash("Re-run search") }
            .roundTrip(round).dates("18 – 27 Jul").passengers("2 adults · Economy").bordered(bordered)
        if remove { r = r.onRemove { flash("Removed") } }
        return r
    }

    var body: some View {
        ComponentStage("RecentSearchRow", inspector: [("trip", round ? "round" : "one-way")]) {
            row.frame(maxWidth: 360)
        } knobs: {
            Toggle("Round trip (⇄ vs →)", isOn: $round)
            Toggle("Remove (✕) instead of chevron", isOn: $remove)
            Toggle("Bordered card", isOn: $bordered)
            Text("Recent/saved search — tap to re-run.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TripTypeToggleDemo: View {
    @State private var sel = 1
    @State private var icons = true
    @State private var accent = false

    private var toggle: TripTypeToggle {
        var t = TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
        if icons { t = t.icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"]) }
        if accent { t = t.accent(.turquoise) }
        return t
    }

    var body: some View {
        ComponentStage("TripTypeToggle", inspector: [("selected", "\(sel)")]) {
            toggle.frame(maxWidth: 360)
        } knobs: {
            Toggle("Per-option icons", isOn: $icons)
            Toggle("Turquoise accent (token)", isOn: $accent)
            Text("Compact pill segmented — selected pill is accent-filled.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SmartSuggestionDemo: View {
    @State private var tintIdx = 0
    @State private var hasLabel = true
    @State private var action = false

    private let tints: [SemanticColor] = [.success, .warning, .info]
    private let tintNames = ["Success", "Warning", "Info"]

    private var banner: SmartSuggestion {
        var b = SmartSuggestion("The Berlin outbound is 12% cheaper on Sat 13 Sep.").tint(tints[tintIdx])
        if hasLabel { b = b.label("Smart tip") }
        if action { b = b.action("Apply") { flash("Applied") } } else { b = b.onTap { flash("Tapped") } }
        return b
    }

    var body: some View {
        ComponentStage("SmartSuggestion", inspector: [("tint", tintNames[tintIdx])]) {
            banner.frame(maxWidth: 400)
        } knobs: {
            Picker("Tint (token)", selection: $tintIdx) { ForEach(tintNames.indices, id: \.self) { Text(tintNames[$0]).tag($0) } }.pickerStyle(.segmented)
            Toggle("Accent label prefix", isOn: $hasLabel)
            Toggle("Trailing action (vs tap chevron)", isOn: $action)
            Text("Sparkle + accent label + message. Green tint by default.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FlightTicketCardDemo: View {
    @State private var fav = true
    @State private var stops = 0.0

    var body: some View {
        ComponentStage("FlightTicketCard", inspector: [("stops", "\(Int(stops))")]) {
            FlightTicketCard(from: "NYC", to: "SFO")
                .cities(from: "New York City", to: "San Francisco").duration(stops == 0 ? "1h 45m" : "5h 20m")
                .times(departure: "10:00 AM", arrival: stops == 0 ? "11:30 AM" : "3:20 PM")
                .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite($fav).stops(Int(stops)).accent(.info)
                .frame(maxWidth: 320)
        } knobs: {
            Picker("Stops", selection: $stops) { Text("Direct").tag(0.0); Text("1 stop").tag(1.0) }.pickerStyle(.segmented)
            Toggle("Favorite", isOn: $fav)
            Text("Perforated ticket (reuses TicketStub) + route timeline + airline/price stub.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct BoardingPassDemo: View {
    @State private var useQR = false
    @State private var withTerminal = true

    private var pass: BoardingPass {
        var p = BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
            .airline("Pegasus").flightNo("PC 1234").cabin("Economy")
            .cities(from: "Istanbul", to: "Berlin").times(departure: "13:15", arrival: "16:05").date("13 Sep")
            .gate("A12", seat: "14C", boarding: "12:45", terminal: withTerminal ? "1" : nil)
            .bookingRef("PNR: X7K2QF")
        p = useQR ? p.qr("PC1234SAWBER14C") : p.barcode("PC1234SAWBER14C")
        return p
    }

    var body: some View {
        ComponentStage("BoardingPass", inspector: [("code", useQR ? "QR" : "barcode")]) {
            pass.frame(maxWidth: 360)
        } knobs: {
            Toggle("QR code (vs barcode)", isOn: $useQR)
            Toggle("Terminal cell", isOn: $withTerminal)
            Text("Perforated pass (TicketStub) + route + detail grid + barcode/QR stub.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AncillaryCardDemo: View {
    @State private var modeIdx = 0   // 0 stepper · 1 add-toggle
    @State private var bags = 1
    @State private var added = false
    @State private var badge = false

    private var card: AncillaryCard {
        var c = AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg").price(450, suffix: "/ bag")
        if badge { c = c.badge("Popular") }
        c = modeIdx == 0 ? c.quantity($bags, range: 0...4) : c.added($added)
        return c
    }

    var body: some View {
        ComponentStage("AncillaryCard", inspector: [("mode", modeIdx == 0 ? "stepper" : "add")]) {
            card.frame(maxWidth: 380)
        } knobs: {
            Picker("Control", selection: $modeIdx) { Text("Stepper").tag(0); Text("Add toggle").tag(1) }.pickerStyle(.segmented)
            Toggle("Badge (Popular)", isOn: $badge)
            Text("Booking add-on: baggage / meal / insurance. Active state = accent border.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PassengerRowDemo: View {
    @State private var seat = true
    @State private var status = false
    @State private var edit = true
    @State private var avatar = false

    private var row: PassengerRow {
        var r = PassengerRow("İsa Mercan") { flash("Passenger tapped") }.type("Adult").subtitle("Passport · TR12345678")
        if seat { r = r.seat("14C") }
        if status { r = r.status("Checked in") }
        if avatar { r = r.avatar(.initials("İM")) }
        if edit { r = r.onEdit { flash("Edit") } } else { r = r.accessory(.chevron) }
        return r
    }

    var body: some View {
        ComponentStage("PassengerRow", inspector: [("seat", "\(seat)")]) {
            row.frame(maxWidth: 380)
        } knobs: {
            Toggle("Seat chip", isOn: $seat)
            Toggle("Status badge (Checked in)", isOn: $status)
            Toggle("Avatar (initials) vs icon", isOn: $avatar)
            Toggle("Edit (pencil) vs chevron", isOn: $edit)
            Text("Traveller list row — name + type + seat + status + edit.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FlightStatusBadgeDemo: View {
    @State private var idx = 2
    @State private var solid = false
    @State private var time = true

    private let statuses = FlightStatus.allCases

    var body: some View {
        ComponentStage("FlightStatusBadge", inspector: [("status", "\(statuses[idx])")]) {
            FlightStatusBadge(statuses[idx]).solid(solid).time(time ? (statuses[idx] == .delayed ? "+35m" : "13:15") : nil)
        } knobs: {
            Picker("Status", selection: $idx) { ForEach(statuses.indices, id: \.self) { Text("\(statuses[$0])").tag($0) } }
            Toggle("Solid fill (vs soft)", isOn: $solid)
            Toggle("Trailing time", isOn: $time)
            Text("Semantic colour per status: on-time green · delayed amber · cancelled red.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LayoverRowDemo: View {
    @State private var warn = false

    var body: some View {
        ComponentStage("LayoverRow", inspector: [("warning", "\(warn)")]) {
            Group {
                if warn { LayoverRow(duration: "0h 45m", airport: "Ankara (ESB)").warning("Short connection — 45 min") }
                else { LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)") }
            }.frame(maxWidth: 360)
        } knobs: {
            Toggle("Short-connection warning", isOn: $warn)
            Text("Between two flight segments — dashed lines + centered layover pill.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StepperRowDemo: View {
    @State private var adults = 2
    @State private var children = 1
    @State private var babies = 0

    var body: some View {
        ComponentStage("StepperRow", inspector: [("total", "\(adults + children + babies)")]) {
            VStack(spacing: 12) {
                StepperRow("Adult", value: $adults).subtitle("+12 yrs").range(1...9)
                StepperRow("Child", value: $children).subtitle("2–11 yrs").range(0...8)
                StepperRow("Infant", value: $babies).subtitle("0–2 yrs").range(0...4)
            }
            .frame(maxWidth: 360)
        } knobs: {
            Text("The building block of a passenger / room / quantity selector — circular − / + bounded by a range.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SheetHeaderDemo: View {
    @State private var back = true
    @State private var close = true
    @State private var prog = true
    @State private var progress = 0.4

    private var header: SheetHeader {
        var h = SheetHeader("Passengers")
        if back { h = h.onBack { flash("Back") } }
        if close { h = h.onClose { flash("Close") } }
        if prog { h = h.subtitle("Step 2 of 4").progress(progress) }
        return h
    }

    var body: some View {
        ComponentStage("SheetHeader", inspector: [("progress", prog ? "\(Int(progress * 100))%" : "—")]) {
            header.frame(maxWidth: 380).clipShape(RoundedRectangle(cornerRadius: 16))
        } knobs: {
            Toggle("Back (‹)", isOn: $back)
            Toggle("Close (✕)", isOn: $close)
            Toggle("Progress line + step subtitle", isOn: $prog)
            if prog { HStack { Text("Progress"); SwiftUI.Slider(value: $progress, in: 0...1); Text("\(Int(progress * 100))%").font(.caption.monospacedDigit()) } }
            Text("Modal/sheet header — centered title + back/close + multi-step progress.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PriceBreakdownDemo: View {
    @State private var note = true
    @State private var original = true
    @State private var extra = true
    @State private var sizeIdx = 2

    private let sizes: [PriceSize] = [.small, .medium, .large, .xlarge]

    private var block: PriceBreakdown {
        var b = PriceBreakdown(190_960).size(sizes[sizeIdx]).emphasis(.standard).discountBadge("-23%")
        if note { b = b.note("2 rooms · 4 nights") }
        if original { b = b.original(248_000) }
        if extra { b = b.extra("Extra 8%", 175_683) }
        return b
    }

    var body: some View {
        ComponentStage("PriceBreakdown", inspector: [("size", "\(sizes[sizeIdx])")]) {
            block.frame(maxWidth: 320)
        } knobs: {
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2); Text("XL").tag(3) }.pickerStyle(.segmented)
            Toggle("Note line", isOn: $note)
            Toggle("Original (strike) + badge", isOn: $original)
            Toggle("Extra-discount line", isOn: $extra)
            Text("The reusable discount-price block — shared by HotelResultCard / RoomCard / StickyBookingBar / AgentPriceRow.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct IconTileDemo: View {
    @State private var accentOn = true
    @State private var size = 46.0

    var body: some View {
        ComponentStage("IconTile", inspector: [("size", "\(Int(size))")]) {
            HStack(spacing: 12) {
                IconTile("airplane").size(size)
                IconTile("suitcase.fill").size(size).accent(accentOn ? .turquoise : nil)
                IconTile("bell.fill").size(size).accent(.warning)
                IconTile("mappin.circle.fill").size(size).iconColor(.textPrimary)
            }
        } knobs: {
            Toggle("Brand-tint the 2nd tile", isOn: $accentOn)
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 32...64, step: 2); Text("\(Int(size))").font(.caption.monospacedDigit()) }
            Text("The shared leading tile behind suggestion / add-on / alert / recent-search rows.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
