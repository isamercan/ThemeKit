//
//  ThemeKitLocalizationValue.swift
//  ThemeKit
//
//  ADR-0003 §D2 — the bridge's capture type. `String.LocalizationValue` is
//  opaque (its key and arguments are not extractable via public API), so it
//  cannot feed the consumer-catalog resolution chain. This ThemeKit-owned
//  `ExpressibleByStringInterpolation` type captures, in one pass over the
//  literal:
//
//  - `key`        — the canonical catalog key. Every interpolation becomes
//                   `%@`; literal `%` characters are escaped to `%%` if (and
//                   only if) the key has interpolations, because only then is
//                   the resolved value expanded through `String(format:)`.
//                   `tools/gen_l10n.py` implements the IDENTICAL mapping, so
//                   generator key == runtime key == catalog key by
//                   construction (the invariant the generated
//                   `L10nKeyInvariantTests` proves per call-site shape).
//  - `arguments`  — every interpolated value, stringified at capture time
//                   with Swift's default interpolation. Uniform `%@`/String
//                   arguments keep the type `Sendable` (no `CVarArg`
//                   captures) and make the specifier mapping type-inference-
//                   free on both sides. The trade-off — number-driven
//                   `.stringsdict` plural variation cannot apply to
//                   interpolated keys — costs nothing today: ThemeKit ships
//                   separate keys ("room"/"rooms", "1 seat"/"%@ seats")
//                   instead of plural variations.
//  - `defaultText`— the English source with the arguments already inlined;
//                   the resolver's final fallback, byte-equal to what
//                   `String(localized:)`'s default-value path renders today
//                   for these call sites.
//
//  All 455+ call sites pass string literals or literal ternaries, so they
//  compile unchanged (`ExpressibleByStringInterpolation` covers both,
//  including the `CalendarView.swift` ternary-of-literals shape).
//

import Foundation

/// A localization key + captured arguments, built from a string literal at a
/// `String(themeKit:)` / `String(themeKitTravel:)` call site (ADR-0003 §D2).
public struct ThemeKitLocalizationValue: Sendable, ExpressibleByStringInterpolation {
    /// The canonical catalog key (`"%@ out of %@"`), exactly as
    /// `tools/gen_l10n.py` extracts it into the shipped catalogs and the
    /// consumer template.
    public let key: String
    /// The interpolated values, stringified in call-site order.
    public let arguments: [String]
    /// The English source text with arguments inlined — the final fallback.
    let defaultText: String

    public init(stringLiteral value: String) {
        // Plain keys are never expanded through String(format:), so the
        // literal is the key verbatim — no %% escaping (mirrors gen_l10n.py).
        key = value
        arguments = []
        defaultText = value
    }

    public init(stringInterpolation: StringInterpolation) {
        let pieces = stringInterpolation.pieces
        let args = pieces.compactMap { if case .argument(let a) = $0 { a } else { nil } }
        arguments = args
        if args.isEmpty {
            let text = pieces.compactMap { if case .literal(let l) = $0 { l } else { nil } }.joined()
            key = text
            defaultText = text
        } else {
            key = pieces.map {
                switch $0 {
                case .literal(let l): l.replacingOccurrences(of: "%", with: "%%")
                case .argument: "%@"
                }
            }.joined()
            defaultText = pieces.map {
                switch $0 {
                case .literal(let l): l
                case .argument(let a): a
                }
            }.joined()
        }
    }

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        enum Piece: Sendable {
            case literal(String)
            case argument(String)
        }

        var pieces: [Piece] = []

        public init(literalCapacity: Int, interpolationCount: Int) {
            pieces.reserveCapacity(interpolationCount * 2 + 1)
        }

        public mutating func appendLiteral(_ literal: String) {
            pieces.append(.literal(literal))
        }

        /// Every interpolated value — of any type — stringifies to one `%@`
        /// argument, exactly matching the generator's specifier mapping.
        public mutating func appendInterpolation<T>(_ value: T) {
            pieces.append(.argument("\(value)"))
        }
    }
}
