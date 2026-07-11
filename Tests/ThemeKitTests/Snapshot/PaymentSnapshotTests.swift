//
//  PaymentSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel payment components
//  (F1.3 `PaymentMethodSelector`): list rows with inline installments, a
//  per-option badge and a disabled method, plus the grid tile variant.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class PaymentSnapshotTests: SnapshotTestCase {

    private var options: [PaymentMethodOption] {
        [
            .init(id: "card", kind: .card, title: "Credit / debit card"),
            .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
            .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
        ]
    }

    // MARK: PaymentMethodSelector (F1.3)

    func testPaymentMethodSelector_states() {
        assertComponentSnapshot(
            PaymentMethodSelector(options, selection: .constant("card"))
                .installments([1, 3, 6], selection: .constant(3), total: 1_240)
                .badge("No fee", for: "transfer")
                .disabledMethods(["wallet"])
                .footer { Text("All payments are encrypted.").textStyle(.bodySm400) }
                .environment(\.locale, Locale(identifier: "en_US"))   // deterministic currency (§10 chain)
                .padding()
        )
    }

    func testPaymentMethodSelector_grid() {
        assertComponentSnapshot(
            PaymentMethodSelector(options, selection: .constant("wallet"))
                .variant(.grid)
                .badge("New", for: "wallet")
                .accent(.success)
                .padding()
        )
    }

    func testPaymentMethodSelector_grid_rtl() {
        assertComponentSnapshot(
            PaymentMethodSelector(options, selection: .constant("card"))
                .variant(.grid)
                .padding(),
            layoutDirection: .rightToLeft
        )
    }
}
#endif
