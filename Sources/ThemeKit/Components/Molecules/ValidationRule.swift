//
//  ValidationRule.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Molecule. The declarative validation surface (daisyUI "Validator"): a
//  `ValidationTrigger` telling `TextInput.validate(_:on:)` WHEN to evaluate its
//  `ValidationRule`s, plus the `.custom` escape-hatch rule under the daisyUI
//  name. The rule engine itself lives in `Validation/Validation.swift`
//  (`ValidationRule` + `Validator`) and the message value/rendering in
//  `InfoMessage.swift` / `InfoMessageUI.swift` — this file only adds the
//  trigger vocabulary and sugar so fields restyle themselves valid/invalid
//  automatically, without hand-managed `infoMessages`.
//
//      TextInput("Email", text: $email)
//          .validate([.required(), .email()], on: .editingEnd)
//          .onValidation { isValid in ... }
//

import SwiftUI

/// When `TextInput.validate(_:on:)` evaluates its rules (daisyUI Validator).
public enum ValidationTrigger: Equatable {
    /// Re-validate on every change of the text.
    case live
    /// Validate when the field loses focus (the default). Once a failure is
    /// visible, further edits re-validate live so the error clears as soon as
    /// the user fixes it ("reward early, punish late").
    case editingEnd
    /// Validate only when the user submits (return key). Same live-clear
    /// behavior after the first visible failure.
    case submit
}

public extension ValidationRule {
    /// daisyUI Validator's `custom` escape hatch: an arbitrary predicate with
    /// its own failure message and severity. Sugar over
    /// `ValidationRule.init(_:kind:runsOnEmpty:validate:)` under the daisyUI name.
    ///
    ///     .custom("Must be 6 digits") { $0.count == 6 }
    ///
    /// For a *dynamic* failure message computed from the value, use the closure
    /// overload `TextInput.validate(on:_:)` — `(String) -> String?`, nil = pass.
    static func custom(_ message: String,
                       kind: InfoMessage.Kind = .error,
                       runsOnEmpty: Bool = false,
                       _ isValid: @escaping (String) -> Bool) -> ValidationRule {
        ValidationRule(message, kind: kind, runsOnEmpty: runsOnEmpty, validate: isValid)
    }
}

#Preview {
    struct Demo: View {
        @State private var email = ""
        @State private var username = ""
        @State private var code = ""
        @State private var emailValid = false
        var body: some View {
            VStack(spacing: 16) {
                // Default trigger: validates on blur, clears live once shown.
                TextInput("Email", text: $email)
                    .icon(leading: "envelope").clearable()
                    .keyboard(.emailAddress, contentType: .emailAddress, capitalization: .never)
                    .validate([.required(), .email()])
                    .onValidation { emailValid = $0 }

                // Dynamic-message closure form, evaluated on every keystroke.
                TextInput("Username", text: $username)
                    .validate(on: .live) { value in
                        value.contains(" ") ? "No spaces allowed" : nil
                    }

                // Submit-only, with a `.custom` rule in the same array.
                TextInput("Code", text: $code)
                    .keyboard(.numberPad)
                    .validate([.required(), .numeric(), .custom("Must be 6 digits") { $0.count == 6 }],
                              on: .submit)

                Button("Continue") {}
                    .disabled(!emailValid)
            }
            .padding()
        }
    }
    return Demo()
}
