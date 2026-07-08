//
//  HotelCheckoutView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Example flow: checkout / payment step. Steps · booking summary · contact &
//  card fieldsets · payment method cards · coupon · price table · terms, with a
//  sticky pay dock and a success dialog that returns to the start.
//

import SwiftUI
import ThemeKit

struct HotelCheckoutView: View {
    let hotel: Hotel
    @Binding var path: [HotelRoute]

    @State private var name = ""
    @State private var email = ""
    @State private var cardNumber = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var method = "card"
    @State private var coupon = ""
    @State private var couponApplied = false
    @State private var acceptTerms = false
    @State private var showSuccess = false

    private let nights = 3
    private var subtotal: Int { hotel.pricePerNight * nights }
    private var discount: Int { couponApplied ? Int(Double(subtotal) * 0.1) : 0 }
    private var tax: Int { Int(Double(subtotal - discount) * 0.10) }
    private var total: Int { subtotal - discount + tax }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Steps([.init("Details", state: .done), .init("Payment", state: .active), .init("Confirm", state: .todo)])

                summaryCard
                Fieldset("Contact details") {
                    TextInput("Full name", text: $name).placeholder("Your name")
                    TextInput("Email", text: $email).placeholder("you@example.com").icon(leading: "envelope")
                }

                paymentMethod
                if method == "card" {
                    Fieldset("Card details") {
                        TextInput("Card number", text: $cardNumber).placeholder("0000 0000 0000 0000").icon(leading: "creditcard")
                        HStack(spacing: 12) {
                            TextInput("Expiry", text: $expiry).placeholder("MM/YY")
                            TextInput("CVV", text: $cvv).placeholder("123").secure()
                        }
                    }
                }

                couponSection
                priceTable
                termsRow
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .buttonDock {
            HStack(spacing: Theme.SpacingKey.md.value) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    Text(total.priceText).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                }
                PrimaryButton("Pay") { showSuccess = true }.fullWidth().disabled(!acceptTerms)
            }
            .padding(.bottom, 4)
        }
        .dialog(isPresented: $showSuccess,
                title: "Booking confirmed 🎉",
                message: "Your payment for \(hotel.name) has been received. Enjoy your trip!",
                primaryTitle: "Back to home",
                onPrimary: { path.removeAll() })
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(hotel.name).textStyle(.labelMd700).foregroundStyle(Theme.shared.text(.textPrimary))
                HStack(spacing: 6) {
                    Icon(systemName: "calendar").size(.sm).accent(.neutral)
                    Text("23 Jun – 26 Jun · \(nights) nights").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
                if hotel.freeCancellation { Callout("Free cancellation").variant(.success) }
            }
        }
    }

    private var paymentMethod: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment method").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            RadioCard("Credit / debit card", isSelected: method == "card") { method = "card" }.description("Visa, Mastercard, Amex")
            RadioCard("Apple Pay", isSelected: method == "applepay") { method = "applepay" }.description("Pay with one tap")
            RadioCard("Bank transfer", isSelected: method == "transfer") { method = "transfer" }.description("Pay directly from your bank")
        }
    }

    private var couponSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextInput("Coupon code", text: $coupon).placeholder("e.g. SUMMER")
                SecondaryButton("Apply") { couponApplied = !coupon.isEmpty }
            }
            if couponApplied { Callout("Coupon applied · 10% off").variant(.success) }
        }
    }

    private var priceTable: some View {
        KeyValueTable(rows: [
            .init("\(nights) nights × \(hotel.pricePerNight.priceText)", value: subtotal.priceText),
            couponApplied ? .init("Discount", value: "-" + discount.priceText, style: .success) : .init("Discount", value: "—", style: .muted),
            .init("Tax (10%)", value: tax.priceText, style: .muted),
            .init("Total", value: total.priceText),
        ])
    }

    private var termsRow: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            Checkbox(isChecked: $acceptTerms)
            InlineText("By continuing, I accept the Terms and Privacy Policy.",
                       links: [("Terms", {}), ("Privacy Policy", {})])
        }
    }
}

#Preview {
    struct Demo: View {
        @State var path: [HotelRoute] = []
        var body: some View {
            NavigationStack { HotelCheckoutView(hotel: Hotel.samples[0], path: $path) }
        }
    }
    return Demo()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
