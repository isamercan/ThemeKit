// REGISTER: SavedCardsList · deep-link "SavedCardsList" · organism · isNew
//
//  SavedCardsListDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel `SavedCardsList` organism (F3.1) —
//  selection, delete/add-new affordances, expired flagging, accent, empty
//  state and read-only are all live knobs.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct SavedCardsListDemo: View {
    @State private var cardID: String? = "visa"
    @State private var showEmpty = false
    @State private var enableDelete = true
    @State private var enableAddNew = true
    @State private var flagExpired = true
    @State private var accented = false
    @State private var readOnly = false
    @State private var lastEvent = "—"

    private let cards: [SavedCard] = [
        SavedCard(id: "visa", brand: .visa, last4: "4242",
                  holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
        SavedCard(id: "mc", brand: .mastercard, last4: "4444",
                  holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
        SavedCard(id: "amex", brand: .amex, last4: "0005",
                  holder: "Alex Morgan", expiryMonth: 3, expiryYear: 2020),
    ]

    private var list: some View {
        var l = SavedCardsList(showEmpty ? [] : cards, selection: $cardID)
            .flagsExpired(flagExpired)
            .accent(accented ? .success : nil)
        if enableDelete {
            l = l.onDelete { card in lastEvent = "delete •••• \(card.last4)" }
        }
        if enableAddNew {
            l = l.onAddNew { lastEvent = "add new" }
        }
        return l.readOnly(readOnly)
    }

    var body: some View {
        ComponentStage("SavedCardsList", inspector: [
            ("selection", cardID ?? "nil"),
            ("cards", showEmpty ? "0" : "\(cards.count)"),
            ("last event", lastEvent),
        ]) {
            list
        } knobs: {
            Toggle("Empty state (no cards)", isOn: $showEmpty)
            Toggle("Delete affordance (trash + context menu)", isOn: $enableDelete)
            Toggle("Add-new row", isOn: $enableAddNew)
            Toggle("Flag expired (Amex ···0005 · 03/20)", isOn: $flagExpired)
            Toggle("Success accent", isOn: $accented)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
