// REGISTER: PassengerForm · deep-link "PassengerForm" · organism · isNew
//
//  PassengerFormDemo.swift
//  Demo
//
//  Interactive demo page for the ThemeKitTravel PassengerForm organism (F1.2).
//  Live knobs for the field list, documentRequired, the validator wiring and
//  the slot/accent modifiers; submission follows the §1.4 rev-4 call site
//  (`form.validateAll(draft.formValues)` — canonical ISO-8601/rawValue strings).
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct PassengerFormDemo: View {
    @State private var draft = PassengerDraft()
    @State private var documentSection = true
    @State private var showNationality = true
    @State private var documentRequired = true
    @State private var useValidator = true
    @State private var accentOn = false
    @State private var footerSlot = false
    @State private var accepted = false

    // FormValidator takes a KeyValuePairs literal, so the two field-list shapes
    // get one validator each and the knob switches between them.
    @State private var fullForm = FormValidator<PassengerFormField>([
        .givenName: [.required()],
        .familyName: [.required()],
        .gender: [.required()],
        .dateOfBirth: [.required()],
        .documentNumber: [.required(), .documentNumber],
        .documentExpiry: [.required(), .expiryInFuture()],
    ])
    @State private var basicForm = FormValidator<PassengerFormField>([
        .givenName: [.required()],
        .familyName: [.required()],
        .dateOfBirth: [.required()],
    ])

    private var form: FormValidator<PassengerFormField> { documentSection ? fullForm : basicForm }

    private var fieldList: [PassengerFormField] {
        var fields: [PassengerFormField] = [.givenName, .familyName, .gender, .dateOfBirth]
        if showNationality { fields.append(.nationality) }
        if documentSection { fields += [.documentNumber, .documentExpiry] }
        return fields
    }

    private var passengerForm: PassengerForm {
        var pf = PassengerForm("Passenger 1 · Adult", draft: $draft)
            .fields(fieldList)
            .documentRequired(documentRequired)
        if useValidator { pf = pf.validator(form) }
        if accentOn { pf = pf.accent(.accent) }
        if footerSlot {
            pf = pf.footer {
                Text("Enter the name exactly as printed on the travel document.")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
            }
        }
        return pf
    }

    var body: some View {
        ComponentStage("PassengerForm", inspector: [
            ("fields", "\(fieldList.count)"),
            ("documentRequired", "\(documentRequired)"),
            ("validator", useValidator ? "wired" : "off"),
            ("accepted", "\(accepted)"),
        ]) {
            VStack(alignment: .leading, spacing: 16) {
                passengerForm

                if useValidator {
                    PrimaryButton("Continue") {
                        // §1.4 rev 4 — submit via validateAll + canonical formValues:
                        accepted = form.validateAll(draft.formValues) == nil
                    }
                    .fullWidth()
                }

                if accepted {
                    Text("Traveler accepted — draft reads back whole.")
                        .textStyle(.labelSm600)
                        .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
                }
            }
        } knobs: {
            Toggle("Travel document section", isOn: $documentSection)
            Toggle("Nationality field", isOn: $showNationality)
            Toggle("Document required (asterisks + rule pack)", isOn: $documentRequired)
            Toggle("Validator wired (messages · focus · live re-validate)", isOn: $useValidator)
            Toggle("Accent tint (pickers, menu checkmarks)", isOn: $accentOn)
            Toggle("Footer slot", isOn: $footerSlot)
            Button("Reset draft + validation") {
                draft = PassengerDraft()
                fullForm.reset()
                basicForm.reset()
                accepted = false
            }
        }
    }
}
