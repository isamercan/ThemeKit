//
//  Validation.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  The validation RULE layer: a `ValidationRule` binds a `Validators` predicate
//  to a message + severity, and `Validator` turns rules into `InfoMessage`s.
//  Pure logic — no SwiftUI, no theme. (The message value lives in
//  `InfoMessage.swift`; its rendering in `InfoMessageUI.swift`.)
//
//  Open for extension: feed any predicate via `init(_:validate:)`, any regex via
//  `.regex(_:_:)` / `.regex(_:caseInsensitive:_:)`, or a typed Swift `Regex` via
//  `.matches(_:_:)`. Built-in factories delegate to `Validators`.
//

import Foundation

/// A single validation rule: a predicate + the message shown when it fails.
public struct ValidationRule {
    let validate: (String) -> Bool
    let message: String
    let kind: InfoMessage.Kind
    /// Whether this rule should also run on an empty value (only `required` does).
    let runsOnEmpty: Bool

    public init(_ message: String, kind: InfoMessage.Kind = .error, runsOnEmpty: Bool = false, validate: @escaping (String) -> Bool) {
        self.message = message
        self.kind = kind
        self.runsOnEmpty = runsOnEmpty
        self.validate = validate
    }

    // MARK: Built-in rules (delegate to `Validators` predicates)

    public static func required(_ message: String = String(globalUIComponents: "This field is required")) -> ValidationRule {
        ValidationRule(message, runsOnEmpty: true) { Validators.required($0) }
    }

    public static func minLength(_ n: Int, _ message: String? = nil) -> ValidationRule {
        ValidationRule(message ?? String(globalUIComponents: "At least \(n) characters")) { Validators.minLength($0, n) }
    }

    public static func maxLength(_ n: Int, _ message: String? = nil) -> ValidationRule {
        ValidationRule(message ?? String(globalUIComponents: "At most \(n) characters")) { Validators.maxLength($0, n) }
    }

    public static func email(_ message: String = String(globalUIComponents: "Enter a valid email")) -> ValidationRule {
        ValidationRule(message) { Validators.email($0) }
    }

    public static func phone(_ message: String = String(globalUIComponents: "Enter a valid phone number")) -> ValidationRule {
        ValidationRule(message) { Validators.phone($0) }
    }

    public static func password(minLength: Int = 8, requireUppercase: Bool = true, requireDigit: Bool = true,
                                requireSpecial: Bool = false, _ message: String? = nil) -> ValidationRule {
        let msg = message ?? String(globalUIComponents: "At least \(minLength) characters")
            + (requireUppercase ? String(globalUIComponents: ", uppercase") : "")
            + (requireDigit ? String(globalUIComponents: ", a digit") : "")
            + (requireSpecial ? String(globalUIComponents: ", a special character") : "")
        return ValidationRule(msg) {
            Validators.password($0, minLength: minLength, requireUppercase: requireUppercase, requireDigit: requireDigit, requireSpecial: requireSpecial)
        }
    }

    public static func creditCardDate(_ message: String = String(globalUIComponents: "Use MM/YY format")) -> ValidationRule {
        ValidationRule(message) { Validators.creditCardDate($0) }
    }

    public static func numeric(_ message: String = String(globalUIComponents: "Digits only")) -> ValidationRule {
        ValidationRule(message) { Validators.numeric($0) }
    }

    public static func range(_ bounds: ClosedRange<Int>, _ message: String? = nil) -> ValidationRule {
        ValidationRule(message ?? String(globalUIComponents: "Between \(bounds.lowerBound) and \(bounds.upperBound)")) { Validators.intInRange($0, bounds) }
    }

    /// Must equal another field's current value (e.g. confirm-password).
    public static func match(_ other: @escaping @autoclosure () -> String, _ message: String = String(globalUIComponents: "Doesn't match")) -> ValidationRule {
        ValidationRule(message) { $0 == other() }
    }

    // MARK: Regex injection (open extension point)

    /// Feed any regex pattern. `kind` lets you surface it as a warning/info too.
    public static func regex(_ pattern: String, _ message: String, kind: InfoMessage.Kind = .error) -> ValidationRule {
        ValidationRule(message, kind: kind) { Validators.matches($0, pattern) }
    }

    /// Regex with options (e.g. case-insensitive).
    public static func regex(_ pattern: String, caseInsensitive: Bool, _ message: String, kind: InfoMessage.Kind = .error) -> ValidationRule {
        ValidationRule(message, kind: kind) { Validators.matches($0, pattern, caseInsensitive: caseInsensitive) }
    }

    /// A typed Swift `Regex` (iOS 16+) — compile-time-checked, supports the regex DSL.
    @available(iOS 16.0, macOS 13.0, *)
    public static func matches<Output>(_ regex: Regex<Output>, _ message: String, kind: InfoMessage.Kind = .error) -> ValidationRule {
        ValidationRule(message, kind: kind) { $0.contains(regex) }
    }
}

public enum Validator {
    /// Evaluate `rules` against `value`. Empty values skip non-`required` rules.
    /// Returns the failing messages (first failure by default, or all).
    public static func validate(_ value: String, _ rules: [ValidationRule], all: Bool = false) -> [InfoMessage] {
        var messages: [InfoMessage] = []
        let isEmpty = value.trimmingCharacters(in: .whitespaces).isEmpty
        for rule in rules {
            if isEmpty && !rule.runsOnEmpty { continue }
            if !rule.validate(value) {
                messages.append(InfoMessage(rule.message, kind: rule.kind))
                if !all { break }
            }
        }
        return messages
    }
}

// MARK: - Async rules (e.g. server-side uniqueness check)

/// An asynchronous validation rule — for remote checks (username taken, etc.).
/// Kept separate from the synchronous path so the common case stays simple.
public struct AsyncValidationRule {
    let validate: (String) async -> Bool
    let message: String
    let kind: InfoMessage.Kind

    public init(_ message: String, kind: InfoMessage.Kind = .error, validate: @escaping (String) async -> Bool) {
        self.message = message
        self.kind = kind
        self.validate = validate
    }
}

public extension Validator {
    /// Evaluate async rules in order; returns failing messages (all, or first).
    static func validate(_ value: String, async rules: [AsyncValidationRule], all: Bool = false) async -> [InfoMessage] {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var messages: [InfoMessage] = []
        for rule in rules where !(await rule.validate(value)) {
            messages.append(InfoMessage(rule.message, kind: rule.kind))
            if !all { break }
        }
        return messages
    }
}
