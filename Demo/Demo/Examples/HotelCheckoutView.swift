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
                Steps([.init("Detay", state: .done), .init("Ödeme", state: .active), .init("Onay", state: .todo)])

                summaryCard
                Fieldset("İletişim bilgileri") {
                    TextInput("Ad Soyad", text: $name, placeholder: "Adın")
                    TextInput("E-posta", text: $email, placeholder: "ornek@mail.com", leadingSystemImage: "envelope")
                }

                paymentMethod
                if method == "card" {
                    Fieldset("Kart bilgileri") {
                        TextInput("Kart numarası", text: $cardNumber, placeholder: "0000 0000 0000 0000", leadingSystemImage: "creditcard")
                        HStack(spacing: 12) {
                            TextInput("SKT", text: $expiry, placeholder: "AA/YY")
                            TextInput("CVV", text: $cvv, placeholder: "123", isSecure: true)
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
        .navigationTitle("Ödeme")
        .navigationBarTitleDisplayMode(.inline)
        .buttonDock {
            HStack(spacing: Theme.SpacingKey.md.value) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Toplam").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    Text(total.priceText).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                }
                PrimaryButton("Öde", block: true) { showSuccess = true }.disabled(!acceptTerms)
            }
            .padding(.bottom, 4)
        }
        .dialog(isPresented: $showSuccess,
                title: "Rezervasyon onaylandı 🎉",
                message: "\(hotel.name) için ödemen alındı. İyi tatiller!",
                primaryTitle: "Ana sayfaya dön",
                onPrimary: { path.removeAll() })
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(hotel.name).textStyle(.labelMd700).foregroundStyle(Theme.shared.text(.textPrimary))
                HStack(spacing: 6) {
                    Icon(systemName: "calendar", size: .sm, color: Theme.shared.text(.textTertiary))
                    Text("23 Haz – 26 Haz · \(nights) gece").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
                if hotel.freeCancellation { Callout("Ücretsiz iptal", type: .success) }
            }
        }
    }

    private var paymentMethod: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ödeme yöntemi").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            RadioCard("Kredi / banka kartı", description: "Visa, Mastercard, Troy", isSelected: method == "card") { method = "card" }
            RadioCard("Apple Pay", description: "Tek dokunuşla öde", isSelected: method == "applepay") { method = "applepay" }
            RadioCard("Havale / EFT", description: "Banka havalesi", isSelected: method == "transfer") { method = "transfer" }
        }
    }

    private var couponSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextInput("Kupon kodu", text: $coupon, placeholder: "ÖrN: SUMMER")
                SecondaryButton("Uygula") { couponApplied = !coupon.isEmpty }
            }
            if couponApplied { Callout("Kupon uygulandı · %10 indirim", type: .success) }
        }
    }

    private var priceTable: some View {
        KeyValueTable(rows: [
            .init("\(nights) gece × \(hotel.pricePerNight.priceText)", value: subtotal.priceText),
            couponApplied ? .init("İndirim", value: "-" + discount.priceText, style: .success) : .init("İndirim", value: "—", style: .muted),
            .init("Vergi (%10)", value: tax.priceText, style: .muted),
            .init("Toplam", value: total.priceText),
        ])
    }

    private var termsRow: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            Checkbox(isChecked: $acceptTerms)
            InlineText("Devam ederek Koşullar ve Gizlilik Politikası'nı kabul ediyorum.",
                       links: [("Koşullar", {}), ("Gizlilik Politikası", {})])
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
