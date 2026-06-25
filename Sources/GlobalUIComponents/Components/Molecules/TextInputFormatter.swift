//
//  TextInputFormatter.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Format-as-you-type masks for `TextInput` (the reference declared `Currency`
//  but never applied it). Pass one as `TextInput(formatter:)`.
//

import Foundation

public struct TextInputFormatter {
    let transform: (String) -> String
    public init(_ transform: @escaping (String) -> String) { self.transform = transform }

    public func callAsFunction(_ value: String) -> String { transform(value) }

    /// Digits grouped in 4s (e.g. "1234 5678 9012 3456"), capped at `maxDigits`.
    public static func creditCard(maxDigits: Int = 16) -> TextInputFormatter {
        TextInputFormatter { raw in
            let digits = String(raw.filter(\.isNumber).prefix(maxDigits))
            return stride(from: 0, to: digits.count, by: 4).map {
                let start = digits.index(digits.startIndex, offsetBy: $0)
                let end = digits.index(start, offsetBy: min(4, digits.count - $0))
                return String(digits[start..<end])
            }.joined(separator: " ")
        }
    }

    /// Turkish phone "0### ### ## ##".
    public static var phoneTR: TextInputFormatter {
        TextInputFormatter { raw in
            var d = Array(raw.filter(\.isNumber).prefix(11))
            if d.first != "0" { d.insert("0", at: 0); d = Array(d.prefix(11)) }
            var out = ""
            for (i, c) in d.enumerated() {
                if i == 4 || i == 7 || i == 9 { out += " " }
                out.append(c)
            }
            return out
        }
    }

    /// Thousands-grouped amount with an optional currency symbol (e.g. "₺1.234.567").
    public static func currency(symbol: String = "₺", grouping: String = ".") -> TextInputFormatter {
        TextInputFormatter { raw in
            let digits = raw.filter(\.isNumber)
            guard !digits.isEmpty else { return "" }
            var result = ""
            for (i, c) in digits.reversed().enumerated() {
                if i > 0 && i % 3 == 0 { result = grouping + result }
                result = String(c) + result
            }
            return symbol + result
        }
    }

    /// Digits only.
    public static var digits: TextInputFormatter {
        TextInputFormatter { $0.filter(\.isNumber) }
    }
}
