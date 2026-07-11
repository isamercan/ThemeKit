// REGISTER: AirportPicker · deep-link "AirportPicker" · organism · isNew
//
//  AirportPickerDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel AirportPicker organism. The demo
//  plays the CALLER's role in the §9.4 contract: it owns the lookup (a local
//  filter over a static dataset here — real apps call their API) and feeds
//  `suggestions` back in; the component owns the debounce of `onQueryChange`.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct AirportPickerDemo: View {
    @State private var selection: Airport?
    @State private var results: [Airport] = []

    // Knobs
    @State private var presentationIdx = 0            // 0 inline · 1 sheet
    @State private var loading = false
    @State private var showNearby = true
    @State private var showRecent = true
    @State private var showPopular = true
    @State private var debounce = 0.25
    @State private var accented = false
    @State private var readOnly = false

    /// Generic in-demo dataset — real IATA codes are facts, not brands.
    private static let airports: [Airport] = [
        Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR"),
        Airport(code: "SAW", name: "Sabiha Gokcen Airport", city: "Istanbul", countryCode: "TR"),
        Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB"),
        Airport(code: "LGW", name: "Gatwick Airport", city: "London", countryCode: "GB"),
        Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US"),
        Airport(code: "EWR", name: "Newark Liberty Airport", city: "New York", countryCode: "US"),
        Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR"),
        Airport(code: "ORY", name: "Orly Airport", city: "Paris", countryCode: "FR"),
        Airport(code: "AMS", name: "Schiphol Airport", city: "Amsterdam", countryCode: "NL"),
        Airport(code: "FRA", name: "Frankfurt Airport", city: "Frankfurt", countryCode: "DE"),
        Airport(code: "BCN", name: "El Prat Airport", city: "Barcelona", countryCode: "ES"),
        Airport(code: "FCO", name: "Fiumicino Airport", city: "Rome", countryCode: "IT"),
        Airport(code: "DXB", name: "Dubai International Airport", city: "Dubai", countryCode: "AE"),
        Airport(code: "SIN", name: "Changi Airport", city: "Singapore", countryCode: "SG"),
        Airport(code: "HND", name: "Haneda Airport", city: "Tokyo", countryCode: "JP"),
    ]

    private var picker: AirportPicker {
        var p = AirportPicker(selection: $selection, suggestions: results)
            .onQueryChange { query in
                results = query.isEmpty ? [] : Self.airports.filter {
                    $0.city.localizedCaseInsensitiveContains(query)
                        || $0.name.localizedCaseInsensitiveContains(query)
                        || $0.code.localizedCaseInsensitiveContains(query)
                }
            }
            .debounce(debounce)
            .presentation(presentationIdx == 1 ? .sheet : .inline)
            .loading(loading)
        if showNearby { p = p.nearby([Self.airports[1]]) }
        if showRecent { p = p.recent([Self.airports[2], Self.airports[4]], onClear: { flash("Clear recents") }) }
        if showPopular { p = p.popular([Self.airports[0], Self.airports[6], Self.airports[13]]) }
        if accented { p = p.accent(.info) }
        return p.a11yID("demo.airportPicker")
    }

    var body: some View {
        ComponentStage("AirportPicker", inspector: [
            ("presentation", presentationIdx == 1 ? "sheet" : "inline"),
            ("selected", selection.map { $0.code } ?? "—"),
            ("debounce", String(format: "%.2fs", debounce)),
            ("loading", "\(loading)"),
        ]) {
            picker
                .readOnly(readOnly)
                .id("\(presentationIdx)\(readOnly)")   // reset internal query on mode flips
        } knobs: {
            Picker("Presentation", selection: $presentationIdx) {
                Text("Inline").tag(0); Text("Sheet").tag(1)
            }.pickerStyle(.segmented)
            HStack {
                Text("Debounce")
                SwiftUI.Slider(value: $debounce, in: 0...1, step: 0.05)
                Text(String(format: "%.2fs", debounce)).font(.caption.monospacedDigit())
            }
            Toggle("Loading (skeleton rows)", isOn: $loading)
            Toggle("Nearby section", isOn: $showNearby)
            Toggle("Recent section (+ Clear)", isOn: $showRecent)
            Toggle("Popular section", isOn: $showPopular)
            Toggle("Accent (.info) chips", isOn: $accented)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
