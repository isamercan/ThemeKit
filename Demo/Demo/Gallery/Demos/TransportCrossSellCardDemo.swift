// REGISTER: TransportCrossSellCard · deep-link "TransportCrossSellCard" · organism · isNew
//
//  TransportCrossSellCardDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel `TransportCrossSellCard` organism
//  (F3.2) — mode, variant, price (env-resolved vs explicit currency), CTA,
//  badge, accent override and read-only are all live knobs.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct TransportCrossSellCardDemo: View {
    @State private var mode: TransportCrossSellCard.Mode = .bus
    @State private var variant: TransportCrossSellVariant = .ribbon
    @State private var showPrice = true
    @State private var explicitEUR = false
    @State private var showDuration = true
    @State private var showDepartures = true
    @State private var showBadge = true
    @State private var showCTA = true
    @State private var accented = false
    @State private var readOnly = false
    @State private var selectCount = 0

    private var card: some View {
        var c = TransportCrossSellCard(mode, from: "Riverton", to: "Lakeside")
            .variant(variant)
            .duration(showDuration ? "6h 30m" : nil)
            .departures(showDepartures ? "Every 30 min from Central Station" : nil)
            .badge(showBadge ? "Cheapest" : nil)
            .accent(accented ? .success : nil)
        if showPrice {
            c = explicitEUR ? c.price(19, currencyCode: "EUR") : c.price(19)
        }
        if showCTA {
            c = c.onSelect { selectCount += 1 }
        }
        return c.readOnly(readOnly)
    }

    var body: some View {
        ComponentStage("TransportCrossSellCard", inspector: [
            ("mode", mode.rawValue),
            ("variant", variant == .ribbon ? "ribbon" : "inline"),
            ("currency", showPrice ? (explicitEUR ? "EUR (explicit)" : "env chain") : "no price"),
            ("selected", "\(selectCount)×"),
        ]) {
            card
        } knobs: {
            Picker("Mode", selection: $mode) {
                Text("Bus").tag(TransportCrossSellCard.Mode.bus)
                Text("Train").tag(TransportCrossSellCard.Mode.train)
                Text("Ferry").tag(TransportCrossSellCard.Mode.ferry)
                Text("Car").tag(TransportCrossSellCard.Mode.car)
            }.pickerStyle(.segmented)
            Picker("Variant", selection: $variant) {
                Text("Ribbon").tag(TransportCrossSellVariant.ribbon)
                Text("Inline").tag(TransportCrossSellVariant.inline)
            }.pickerStyle(.segmented)
            Toggle("Price (19, from)", isOn: $showPrice)
            Toggle("Explicit EUR (else env-resolved)", isOn: $explicitEUR)
            Toggle("Duration (6h 30m)", isOn: $showDuration)
            Toggle("Departures note", isOn: $showDepartures)
            Toggle("Badge (\"Cheapest\")", isOn: $showBadge)
            Toggle("CTA (\"See options\")", isOn: $showCTA)
            Toggle("Success accent override", isOn: $accented)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
