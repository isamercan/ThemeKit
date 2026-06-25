//
//  Validators.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Pure, UI-independent validation predicates: `(String) -> Bool`. They carry NO
//  message, kind or presentation — just the logic — so they're trivially unit-
//  testable and reusable outside the rule/UI context. `ValidationRule` factories
//  bind these to a message + severity. (Separates "what is valid" from "how it's
//  reported".)
//

import Foundation

public enum Validators {
    public static func required(_ s: String) -> Bool {
        !s.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public static func minLength(_ s: String, _ n: Int) -> Bool { s.count >= n }
    public static func maxLength(_ s: String, _ n: Int) -> Bool { s.count <= n }

    public static func email(_ s: String) -> Bool {
        matches(s, #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#)
    }

    /// 7–15 digits, optional leading +/spaces/()- separators.
    public static func phone(_ s: String) -> Bool {
        let digits = s.filter(\.isNumber)
        return (7...15).contains(digits.count) && matches(s, #"^\+?[\d\s().-]+$"#)
    }

    public static func numeric(_ s: String) -> Bool { matches(s, #"^\d+$"#) }

    /// MM/YY or MMYY.
    public static func creditCardDate(_ s: String) -> Bool {
        matches(s, #"^(0[1-9]|1[0-2])\/?([0-9]{2})$"#)
    }

    /// Parses an integer and checks it's within `bounds`.
    public static func intInRange(_ s: String, _ bounds: ClosedRange<Int>) -> Bool {
        guard let n = Int(s.trimmingCharacters(in: .whitespaces)) else { return false }
        return bounds.contains(n)
    }

    public static func password(
        _ s: String, minLength: Int = 8,
        requireUppercase: Bool = true, requireDigit: Bool = true, requireSpecial: Bool = false
    ) -> Bool {
        guard s.count >= minLength else { return false }
        if requireUppercase, !matches(s, #"[A-ZĞÜŞİÖÇ]"#) { return false }
        if requireDigit, !matches(s, #"\d"#) { return false }
        if requireSpecial, !matches(s, #"[^A-Za-z0-9]"#) { return false }
        return true
    }

    /// Feed any regex pattern (the open extension point).
    public static func matches(_ s: String, _ pattern: String, caseInsensitive: Bool = false) -> Bool {
        var options: NSString.CompareOptions = .regularExpression
        if caseInsensitive { options.insert(.caseInsensitive) }
        return s.range(of: pattern, options: options) != nil
    }
}
