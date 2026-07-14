//
//  FormWiring.swift
//  ThemeKit
//
//  One-liner form wiring for the field family. `.field(_:in:)` wires a field
//  into a `FormValidator`: renders its `[InfoMessage]`s, adopts its focus
//  binding (so `validateAll` / `submit` focuses the first invalid field), and
//  re-validates the field live on editing end once the form has validated it
//  (i.e. after a failed submit) — replacing the three-line
//  `infoMessages + externalFocus + validate` dance:
//
//      enum Field { case email, password }
//      @State var form = FormValidator<Field>([
//          .email: [.required(), .email()],
//          .password: [.required(), .minLength(8)],
//      ])
//      TextInput("Email", text: $email).field(.email, in: form)
//      TextInput("Password", text: $password).secure().field(.password, in: form)
//      PrimaryButton("Submit") {
//          form.submit([.email: email, .password: password]) { logIn() }
//      }
//

import SwiftUI

// MARK: - Submission handling

public extension FormValidator {
    /// Submission handling: validates every field, focuses the first invalid
    /// one, runs `action` when the form is clean (Ant `onFinish`), and otherwise
    /// calls `onInvalid` with the first invalid field (Ant `onFinishFailed`).
    ///
    ///     Button("Pay") { form.submit(values) { pay() } }
    ///     Button("Pay") {
    ///         form.submit(values) { pay() } onInvalid: { _ in flash("Check the form") }
    ///     }
    ///
    /// - Returns: `true` when the form was valid and `action` ran.
    @discardableResult
    func submit(_ values: [Field: String],
                onValid action: () -> Void,
                onInvalid: (Field) -> Void = { _ in }) -> Bool {
        if let invalid = validateAll(values) {
            onInvalid(invalid)
            return false
        }
        action()
        return true
    }

    /// Whether editing-end should re-validate `field` live: only once the form
    /// has validated it (a failed `submit` / `validateAll`, or a prior live
    /// pass) — so fields don't nag before the first submission attempt.
    fileprivate func shouldRevalidate(_ field: Field) -> Bool {
        messages.index(forKey: field) != nil
    }
}

// MARK: - .field(_:in:) on the field family

public extension TextInput {
    /// Wires this field into a `FormValidator`: renders its `[InfoMessage]`s,
    /// adopts its focus binding, and re-validates live on editing end after a
    /// failed submit. Replaces the `infoMessages + externalFocus + validate` dance.
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onEditingEnd { value in
                if form.shouldRevalidate(field) { form.validate(field, value) }
            }
    }
}

public extension MultiLineTextInput {
    /// Wires this editor into a `FormValidator`: renders its `[InfoMessage]`s,
    /// adopts its focus binding, and re-validates live on editing end after a
    /// failed submit.
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onEditingEnd { value in
                if form.shouldRevalidate(field) { form.validate(field, value) }
            }
    }
}

public extension SearchBar {
    /// Wires this search field into a `FormValidator`: renders its
    /// `[InfoMessage]`s, adopts its focus binding, and re-validates live on
    /// editing end after a failed submit.
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onEditingEnd { value in
                if form.shouldRevalidate(field) { form.validate(field, value) }
            }
    }
}

public extension DateField {
    /// Wires this date field into a `FormValidator`: renders its
    /// `[InfoMessage]`s, adopts its focus binding (focusing opens the picker),
    /// and re-validates on picker dismissal after a failed submit. The validated
    /// value is the displayed text (empty when no date is set), so
    /// `.required()`-style rules apply naturally.
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onEditingEnd { value in
                if form.shouldRevalidate(field) { form.validate(field, value) }
            }
    }
}

public extension SelectBox {
    /// Wires this select into a `FormValidator`: renders its `[InfoMessage]`s,
    /// adopts its focus binding (the native `Menu` can't be opened
    /// programmatically, so focusing renders the field's focus border instead),
    /// and re-validates on selection change after a failed submit. The validated
    /// value is the selected option's title (empty when nothing is selected).
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onEditingEnd { value in
                if form.shouldRevalidate(field) { form.validate(field, value) }
            }
    }
}

// MARK: - Preview

#Preview("Form wiring") {
    struct Demo: View {
        enum Field { case email, password, country, notes }

        @Environment(\.theme) private var theme
        @State private var form = FormValidator<Field>([
            .email: [.required(), .email()],
            .password: [.required(), .minLength(8)],
            .country: [.required("Pick a country")],
            .notes: [.maxLength(80)],
        ])
        @State private var email = ""
        @State private var password = ""
        @State private var country: String?
        @State private var notes = ""
        @State private var submitted = false

        private var values: [Field: String] {
            [.email: email,
             .password: password,
             .country: country ?? "",
             .notes: notes]
        }

        var body: some View {
            ScrollView {
                VStack(spacing: Theme.SpacingKey.md.value) {
                    TextInput("Email", text: $email)
                        .icon(leading: "envelope")
                        .keyboard(.emailAddress, contentType: .emailAddress, submit: .next, capitalization: .never)
                        .field(.email, in: form)

                    TextInput("Password", text: $password)
                        .secure()
                        .field(.password, in: form)

                    SelectBox("Country", options: ["Norway", "Japan", "Brazil"], selection: $country) { $0 }
                        .field(.country, in: form)

                    MultiLineTextInput("Notes", text: $notes)
                        .placeholder("Optional, up to 80 characters")
                        .size(.xsmall)
                        .field(.notes, in: form)

                    PrimaryButton("Create account") {
                        submitted = form.submit(values) { /* run the real action */ }
                    }
                    .fullWidth()

                    if submitted {
                        Text("Form is valid — action ran.")
                            .textStyle(.labelSm600)
                            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
                    }
                }
                .padding()
            }
            .background(theme.background(.bgBase))
        }
    }
    return Demo()
}
