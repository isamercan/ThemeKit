//
//  FormValidator.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Form-level aggregate validation: declare rules per field (in order), validate
//  the whole form on submit, surface per-field `[InfoMessage]`, and focus the
//  first invalid field. Pairs with `TextInput(externalFocus:)`.
//
//      enum Field { case email, password }
//      @State var form = FormValidator<Field>([
//          .email: [.required(), .email()],
//          .password: [.required(), .minLength(8)],
//      ])
//      TextInput(.init(label: "Email", infoMessages: form.messages(for: .email)),
//                text: $email, externalFocus: form.focusBinding(.email))
//      Button("Submit") { _ = form.validateAll([.email: email, .password: password]) }
//

import SwiftUI

@MainActor
@Observable
public final class FormValidator<Field: Hashable> {
    public private(set) var messages: [Field: [InfoMessage]] = [:]
    /// The field that should currently hold focus (set to the first invalid on submit).
    public var focusedField: Field?

    private let order: [Field]
    private let rulesByField: [Field: [ValidationRule]]

    /// Rules per field; declaration order drives "first invalid" + focus order.
    public init(_ rules: KeyValuePairs<Field, [ValidationRule]>) {
        self.order = rules.map(\.key)
        self.rulesByField = rules.reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    public func messages(for field: Field) -> [InfoMessage] { messages[field] ?? [] }
    public func hasError(_ field: Field) -> Bool { messages[field]?.dominantKind == .error }

    /// Validate a single field live (e.g. as the user edits after a failed submit).
    @discardableResult
    public func validate(_ field: Field, _ value: String) -> [InfoMessage] {
        let result = Validator.validate(value, rulesByField[field] ?? [], all: true)
        messages[field] = result
        return result
    }

    /// Validate every field; sets all messages and focuses + returns the first
    /// invalid field in declaration order (nil when the form is valid).
    @discardableResult
    public func validateAll(_ values: [Field: String]) -> Field? {
        var first: Field?
        for field in order {
            let result = Validator.validate(values[field] ?? "", rulesByField[field] ?? [], all: true)
            messages[field] = result
            if first == nil, result.dominantKind == .error { first = field }
        }
        focusedField = first
        return first
    }

    /// Whether every validated field is currently error-free.
    public var isValid: Bool {
        order.allSatisfy { (messages[$0]?.dominantKind ?? .info) != .error }
    }

    public func reset() {
        messages = [:]
        focusedField = nil
    }

    /// A bool focus binding for a field — true while it's the focused field.
    /// Hand this to `TextInput(externalFocus:)`. The validator is `@MainActor`, so
    /// the binding's get/set are main-actor isolated — clean under Swift 6.
    public func focusBinding(_ field: Field) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.focusedField == field },
            set: { [weak self] isFocused in
                guard let self else { return }
                if isFocused { self.focusedField = field }
                else if self.focusedField == field { self.focusedField = nil }
            }
        )
    }
}
