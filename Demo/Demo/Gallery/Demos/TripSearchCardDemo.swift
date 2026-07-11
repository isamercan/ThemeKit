// REGISTER: TripSearchCard · deep-link "TripSearchCard" · organism · isNew
//
//  TripSearchCardDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel TripSearchCard organism — the
//  capstone flight-search card composing TripTypeToggle, AirportPicker ×2 +
//  SwapButton, DateField ×1–2, GuestSelector, CabinClassSelector and the CTA.
//  The demo plays the CALLER's role: it owns the airport lookup (a local
//  filter over a static dataset — real apps call their API) and receives the
//  terminal `onSearch` command.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct TripSearchCardDemo: View {
    @State private var draft: TripSearchDraft = initialDraft()
    @State private var results: [Airport] = []

    // Knobs
    @State private var variantIdx = 0            // 0 card · 1 hero · 2 compact
    @State private var showsTripType = true
    @State private var showsCabin = true
    @State private var accented = false
    @State private var showPromo = false
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
        Airport(code: "AMS", name: "Schiphol Airport", city: "Amsterdam", countryCode: "NL"),
        Airport(code: "FRA", name: "Frankfurt Airport", city: "Frankfurt", countryCode: "DE"),
        Airport(code: "BCN", name: "El Prat Airport", city: "Barcelona", countryCode: "ES"),
        Airport(code: "DXB", name: "Dubai International Airport", city: "Dubai", countryCode: "AE"),
        Airport(code: "SIN", name: "Changi Airport", city: "Singapore", countryCode: "SG"),
        Airport(code: "HND", name: "Haneda Airport", city: "Tokyo", countryCode: "JP"),
    ]

    private static func initialDraft() -> TripSearchDraft {
        var draft = TripSearchDraft()
        draft.origin = airports[0]
        draft.destination = airports[2]
        draft.departureDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)
        draft.returnDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)
        return draft
    }

    private var variant: TripSearchVariant {
        switch variantIdx {
        case 1: .hero
        case 2: .compact
        default: .card
        }
    }

    private var card: TripSearchCard {
        var card = TripSearchCard(draft: $draft) { submitted in
            let route = "\(submitted.origin?.code ?? "?") – \(submitted.destination?.code ?? "?")"
            flash("Search \(route) · \(submitted.passengers.total) pax · \(submitted.cabin.label)")
        }
        .airports(suggestions: results,
                  recent: [Self.airports[4], Self.airports[6]],
                  popular: [Self.airports[0], Self.airports[2], Self.airports[10]])
        .onAirportQuery { query in
            results = query.isEmpty ? [] : Self.airports.filter {
                $0.city.localizedCaseInsensitiveContains(query)
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.code.localizedCaseInsensitiveContains(query)
            }
        }
        .variant(variant)
        .showsTripType(showsTripType)
        .showsCabinPicker(showsCabin)
        if accented { card = card.accent(.success) }
        if showPromo {
            card = card.promo {
                HStack(spacing: 8) {
                    Icon(systemName: "tag").size(.sm).color(SemanticColor.success.accent)
                    Text("Members save up to 20% on selected routes").textStyle(.bodySm400)
                }
            }
        }
        return card
    }

    var body: some View {
        ComponentStage("TripSearchCard", inspector: [
            ("variant", ["card", "hero", "compact"][variantIdx]),
            ("trip", draft.tripType.label),
            ("route", "\(draft.origin?.code ?? "—") – \(draft.destination?.code ?? "—")"),
            ("passengers", "\(draft.passengers.total)"),
            ("cabin", draft.cabin.label),
        ]) {
            card
                .readOnly(readOnly)
                .id(variantIdx)   // reset compact expansion on variant flips
        } knobs: {
            Picker("Variant", selection: $variantIdx) {
                Text("Card").tag(0); Text("Hero").tag(1); Text("Compact").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Trip-type toggle", isOn: $showsTripType)
            Toggle("Cabin picker", isOn: $showsCabin)
            Toggle("Accent (.success)", isOn: $accented)
            Toggle("Promo slot", isOn: $showPromo)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
