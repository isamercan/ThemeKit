//
//  ThemeKitStrings.swift
//  ThemeKit
//
//  ADR-0003 §D1/§D3 — the process-global localization layer behind
//  `String(themeKit:)` / `String(themeKitTravel:)`. It lives OUTSIDE the View
//  graph on purpose: many call sites are enum/model computed properties
//  (`ColorChannel.title`, `StepState` labels, …) that `@Environment` can
//  never reach.
//
//  Resolution chain per key — first hit wins (§D1):
//    1. per-call parameter          (never reaches the bridge; always wins)
//    2. consumer catalog, effective language
//    3. consumer catalog, source language (`en` — a consumer's rewording)
//    4. the module's own catalog    (compiled only under Xcode builds)
//    5. the English source text     (`defaultText` — today's exact output)
//
//  Mechanics are the ones the ADR's spike VERIFIED (not assumed):
//  - `String(localized:bundle:locale:)` does NOT select that locale's .lproj,
//    so consumer languages resolve through per-language `.lproj` SUB-BUNDLES
//    (cached, invalidated on `register`).
//  - `.stringsdict` formats survive `localizedString(forKey:value:table:)`,
//    but MUST be expanded with `String(format:locale:arguments:)` — never
//    `String.localizedStringWithFormat`, which silently uses
//    `Locale.current`'s plural rules.
//  - BCP-47 → .lproj matching goes through
//    `Bundle.preferredLocalizations(from:forPreferences:)` ("tr-TR" → tr);
//    never string-munge language codes.
//  - Misses are detected with a `value:` sentinel (with `value: nil` the key
//    echoes back, indistinguishable from a real value).
//
//  Crash safety: a consumer-authored format is validated before
//  `String(format:)` — since every captured argument is a String/NSString,
//  only `%@`-family conversions (plus `%%` and `%#@…@` plural references) are
//  satisfiable; anything else (a stray `%s`, `%lld`) falls through to the
//  next chain step instead of risking undefined varargs behavior. Validation
//  runs in ALL configurations (a bad translation must never crash a shipped
//  app); the diagnostic log is DEBUG-only.
//

import Foundation
import Observation
import os
import SwiftUI

/// Process-global consumer override for ThemeKit's built-in strings
/// (ADR-0003). Zero-config: drop a `ThemeKit.xcstrings` into the app target
/// and every ThemeKit default resolves through it — `register` exists for app
/// extensions, embedding frameworks, and custom table names.
public enum ThemeKitStrings {

    // MARK: - Configuration

    /// Registers the consumer catalog. Defaults probe `Bundle.main` for the
    /// `"ThemeKit"` table (the file name of the consumer's
    /// `ThemeKit.xcstrings`), so most apps never call this.
    public static func register(bundle: Bundle = .main, table: String = "ThemeKit") {
        state.withLockUnchecked {
            $0.bundle = bundle
            $0.table = table
            $0.tableLanguages = nil
            $0.lprojCache = [:]
            $0.matchCache = [:]
        }
        bumpRevision()
    }

    /// Live language override. `nil` (default) follows the system
    /// (`Locale.autoupdatingCurrent`, which also reflects the per-app
    /// language in Settings). Setting it re-resolves every subsequent string
    /// and bumps ``observable`` so a `.themeKitLocalized()` root (phase 2)
    /// re-renders — restart-free.
    public static var locale: Locale? {
        get { state.withLockUnchecked { $0.locale } }
        set {
            state.withLockUnchecked {
                $0.locale = newValue
                $0.matchCache = [:]
            }
            bumpRevision()
        }
    }

    /// The locale strings resolve in: the ``locale`` override, else the system.
    public static var effectiveLocale: Locale { locale ?? .autoupdatingCurrent }

    // MARK: - Observation (the view layer's re-render hook)

    /// Bumped on every ``locale``/``register(bundle:table:)`` change; the
    /// `.themeKitLocalized()` root observes it (ADR-0003 §D4).
    @Observable
    @MainActor
    public final class Revision {
        public internal(set) var value = 0
        nonisolated init() {}
    }

    @MainActor public static let observable = Revision()

    /// Ready-made wiring for ``LanguageSwitcher``-style pickers: a
    /// `Binding<String>` over the effective BCP-47 code whose setter drives
    /// ``locale``.
    @MainActor public static var languageBinding: Binding<String> {
        Binding(
            get: {
                // An explicit override round-trips exactly; the zero-config
                // initial value is the bare device language code ("tr", not
                // "tr_TR") so it matches `AppLanguage(code:)` entries.
                locale?.identifier
                    ?? Locale.autoupdatingCurrent.language.languageCode?.identifier
                    ?? Locale.autoupdatingCurrent.identifier
            },
            set: { locale = Locale(identifier: $0) }
        )
    }

    private static func bumpRevision() {
        if Thread.isMainThread {
            MainActor.assumeIsolated { observable.value &+= 1 }
        } else {
            Task { @MainActor in observable.value &+= 1 }
        }
    }

    // MARK: - Resolution

    /// Resolves a captured localization value through the ADR-0003 chain.
    /// `module` is the calling bridge's own resource bundle (ThemeKitCore's
    /// for `String(themeKit:)`, ThemeKitTravel's for
    /// `String(themeKitTravel:)`).
    public static func resolve(_ value: ThemeKitLocalizationValue, module: Bundle) -> String {
        let effective = effectiveLocale

        // D1 steps 2–3: consumer catalog, effective language then source (en).
        for candidate in consumerBundles(for: effective) {
            let hit = candidate.bundle.localizedString(forKey: value.key, value: sentinel, table: candidate.table)
            if hit != sentinel, let expanded = expand(hit, with: value, locale: effective) {
                return expanded
            }
        }

        // D1 step 4: the module's own catalog (compiled under Xcode builds;
        // a plain `swift build` copies the .xcstrings verbatim → guaranteed
        // miss, which lands on the English defaultText — today's output).
        let hit = module.localizedString(forKey: value.key, value: sentinel, table: nil)
        if hit != sentinel, let expanded = expand(hit, with: value, locale: effective) {
            return expanded
        }

        return value.defaultText
    }

    // MARK: - Internals

    private struct State {
        var bundle: Bundle = .main
        var table: String = "ThemeKit"
        var locale: Locale?
        /// Languages whose `.lproj` actually carries the consumer table
        /// (structural probe, cached; `nil` = not probed yet).
        var tableLanguages: [String]?
        /// Per-language `.lproj` sub-bundles (spike-verified mechanism).
        var lprojCache: [String: Bundle] = [:]
        /// `locale.identifier` → matched `.lproj` name.
        var matchCache: [String: String] = [:]
    }

    private static let state = OSAllocatedUnfairLock<State>(uncheckedState: State())

    /// Sentinel distinguishing a lookup miss from a real value (spike #6).
    private static let sentinel = "\u{7F}ThemeKit.miss\u{7F}"

    #if DEBUG
    private static let logger = Logger(subsystem: "ThemeKit", category: "Localization")
    #endif

    /// The consumer `.lproj` sub-bundles to try, in D1 order: effective
    /// language first, then the source language (`en`). Empty when no
    /// consumer catalog is present (the zero-config no-op path).
    private static func consumerBundles(for locale: Locale) -> [(bundle: Bundle, table: String)] {
        state.withLockUnchecked { s -> [(bundle: Bundle, table: String)] in
            let languages: [String]
            if let cached = s.tableLanguages {
                languages = cached
            } else {
                languages = s.bundle.localizations.filter { loc in
                    s.bundle.url(forResource: s.table, withExtension: "strings",
                                 subdirectory: nil, localization: loc) != nil
                        || s.bundle.url(forResource: s.table, withExtension: "stringsdict",
                                        subdirectory: nil, localization: loc) != nil
                }
                s.tableLanguages = languages
            }
            guard !languages.isEmpty else { return [] }

            let matched: String
            if let cached = s.matchCache[locale.identifier] {
                matched = cached
            } else {
                matched = Bundle.preferredLocalizations(
                    from: languages, forPreferences: [locale.identifier]
                ).first ?? languages.first ?? "en"
                s.matchCache[locale.identifier] = matched
            }

            var order = [matched]
            if matched != "en", languages.contains("en") {
                order.append("en")   // D1 step 3 — the consumer's English rewording
            }
            return order.compactMap { lang in
                if let cached = s.lprojCache[lang] { return (cached, s.table) }
                guard let url = s.bundle.url(forResource: lang, withExtension: "lproj"),
                      let sub = Bundle(url: url) else { return nil }
                s.lprojCache[lang] = sub
                return (sub, s.table)
            }
        }
    }

    /// Expands a resolved format with the captured arguments —
    /// `String(format:locale:arguments:)` so `.stringsdict` plural rules
    /// follow the TARGET locale (spike #4). Returns `nil` (fall through the
    /// chain) when the format cannot be satisfied by String arguments.
    private static func expand(_ format: String, with value: ThemeKitLocalizationValue, locale: Locale) -> String? {
        guard !value.arguments.isEmpty else { return format }
        guard isSatisfiable(format, argumentCount: value.arguments.count) else {
            #if DEBUG
            logger.error("""
                Discarding unsatisfiable translation for key '\(value.key, privacy: .public)': \
                '\(format, privacy: .public)' — ThemeKit passes \(value.arguments.count) string \
                argument(s), so only %@ / %n$@ (and %% / %#@…@) conversions are valid.
                """)
            #endif
            return nil
        }
        let args: [CVarArg] = value.arguments.map { $0 as NSString }
        return String(format: format, locale: locale, arguments: args)
    }

    /// `true` when every `%` conversion in `format` is satisfiable by
    /// `argumentCount` String arguments: `%%`, `%@`, positional `%n$@` with
    /// `n <= argumentCount`, and `%#@name@` plural references (each consuming
    /// one positional slot). Anything else (`%lld`, `%s`, …) would reinterpret
    /// an NSString pointer — rejected. Internal for direct unit testing.
    static func isSatisfiable(_ format: String, argumentCount: Int) -> Bool {
        var consumed = 0
        var maxPositional = 0
        let chars = Array(format)
        var i = 0
        while i < chars.count {
            guard chars[i] == "%" else { i += 1; continue }
            i += 1
            guard i < chars.count else { return false }   // trailing bare %
            if chars[i] == "%" { i += 1; continue }       // literal %%
            // optional positional prefix: digits followed by '$'
            var digits = ""
            var j = i
            while j < chars.count, chars[j].isNumber { digits.append(chars[j]); j += 1 }
            var positional: Int?
            if !digits.isEmpty, j < chars.count, chars[j] == "$" {
                positional = Int(digits)
                i = j + 1
            }
            guard i < chars.count else { return false }
            switch chars[i] {
            case "@":
                i += 1
            case "#":
                // %#@name@ — a .stringsdict variable reference
                guard i + 1 < chars.count, chars[i + 1] == "@",
                      let close = chars[(i + 2)...].firstIndex(of: "@") else { return false }
                i = close + 1
            default:
                return false
            }
            if let positional {
                maxPositional = max(maxPositional, positional)
            } else {
                consumed += 1
            }
        }
        if maxPositional > 0 && consumed > 0 { return false }   // mixed forms — ambiguous
        return maxPositional <= argumentCount && consumed <= argumentCount
    }
}
