// REGISTER: PaymentMethodSelector · deep-link "PaymentMethodSelector" · organism · isNew
//
//  PaymentMethodSelectorDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel `PaymentMethodSelector` organism
//  (F1.3) — variant, inline installments, per-option badge, disabled methods,
//  accent and footer are all live knobs.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct PaymentMethodSelectorDemo: View {
    @State private var method: String? = "card"
    @State private var months = 3
    @State private var variant: PaymentMethodVariant = .list
    @State private var showInstallments = true
    @State private var showBadge = true
    @State private var disableWallet = true
    @State private var accented = false
    @State private var showFooter = true
    @State private var readOnly = false

    private let options: [PaymentMethodOption] = [
        .init(id: "card", kind: .card, title: "Credit / debit card"),
        .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
    ]

    private var selector: some View {
        var s = PaymentMethodSelector(options, selection: $method)
            .variant(variant)
            .disabledMethods(disableWallet ? ["wallet"] : [])
            .accent(accented ? .success : nil)
        if showInstallments {
            s = s.installments([1, 3, 6, 9], selection: $months, total: 1_240)
        }
        if showBadge {
            s = s.badge("No fee", for: "transfer")
        }
        if showFooter {
            s = s.footer {
                Text("All payments are encrypted.")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
            }
        }
        return s.readOnly(readOnly)
    }

    var body: some View {
        ComponentStage("PaymentMethodSelector", inspector: [
            ("selection", method ?? "nil"),
            ("variant", variant == .list ? "list" : "grid"),
            ("installments", showInstallments ? "\(months)×" : "off"),
        ]) {
            selector
        } knobs: {
            Picker("Variant", selection: $variant) {
                Text("List").tag(PaymentMethodVariant.list)
                Text("Grid").tag(PaymentMethodVariant.grid)
            }.pickerStyle(.segmented)
            Toggle("Installments (total 1,240 · under card)", isOn: $showInstallments)
            Toggle("Badge (\"No fee\" on transfer)", isOn: $showBadge)
            Toggle("Disable wallet method", isOn: $disableWallet)
            Toggle("Success accent", isOn: $accented)
            Toggle("Footer slot", isOn: $showFooter)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
