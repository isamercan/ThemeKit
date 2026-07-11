//
//  TravelEditionSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel EDITION organisms (F1.x).
//  Opt-in + iOS-only (see SnapshotSupport.swift); records references on the
//  pinned Simulator, skips in CI. Bindings use `.constant` and dates are fixed
//  so references are reproducible.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class TravelEditionSnapshotTests: SnapshotTestCase {

    // MARK: - F1.2 PassengerForm (begin)

    /// Fixed-date traveler so DateField text is reproducible.
    private var filledDraft: PassengerDraft {
        var draft = PassengerDraft()
        draft.givenName = "Alex"
        draft.familyName = "Morgan"
        draft.gender = .female
        draft.dateOfBirth = Date(timeIntervalSinceReferenceDate: -347_000_000)   // ~1990
        draft.nationality = "NO"
        draft.documentNumber = "U1234567"
        draft.documentExpiry = Date(timeIntervalSinceReferenceDate: 900_000_000) // ~2029
        return draft
    }

    func testPassengerForm_states() {
        // Empty + filled, documentRequired asterisks, footer slot.
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 16) {
                PassengerForm("Passenger 1 · Adult", draft: .constant(PassengerDraft()))
                    .fields([.givenName, .familyName, .gender, .dateOfBirth])

                PassengerForm("Passenger 2 · Adult", draft: .constant(filledDraft))
                    .documentRequired()
                    .footer {
                        Text("Enter the name exactly as printed on the travel document.")
                            .textStyle(.bodySm400)
                    }
            }
            .padding()
        )

        // Error state — a failed submit populates the validator's messages,
        // which every wired field renders (§1.4 rev 4: validateAll + canonical
        // formValues; no form.submit until HEROUI 13b).
        let form = FormValidator<PassengerFormField>([
            .givenName: [.required()],
            .familyName: [.required()],
            .documentNumber: [.required(), .documentNumber],
            .documentExpiry: [.required(), .expiryInFuture()],
        ])
        form.validateAll(PassengerDraft().formValues)
        assertComponentSnapshot(
            PassengerForm("Passenger 1 · Adult", draft: .constant(PassengerDraft()))
                .documentRequired()
                .validator(form)
                .padding(),
            named: "errors"
        )

        // Dark — token re-skin of both fieldsets.
        assertComponentSnapshot(
            PassengerForm("Passenger 1 · Adult", draft: .constant(filledDraft))
                .documentRequired()
                .padding(),
            colorScheme: .dark,
            named: "dark"
        )
    }

    // MARK: - F1.2 PassengerForm (end)
}
#endif
