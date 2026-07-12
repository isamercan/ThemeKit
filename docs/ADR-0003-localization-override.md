# ADR-0003 — Consumer localization override & restart-free language switching

- **Status:** **Accepted** (2026-07-12)
- **Date:** 2026-07-12
- **Deciders:** ThemeKit architecture
- **Context source:** HeroUI infra initiative + a compiled OS-behavior spike (recorded in §"What the spike verified") + catalog drift audit (117 missing / 62 stale keys, this ADR)
- **Rollout note:** Additive; the bridge's *body* changes but every one of the 408 call sites compiles unchanged and, with no consumer catalog registered, behavior is byte-identical to today. The one API-shape change — the bridge parameter type — keeps a deprecated `@_disfavoredOverload` for the (theoretical) external caller passing an explicit `String.LocalizationValue`. The interpolation-capture type's overload set must be compile-verified against the 71 interpolated call sites by `sr-ios-dev` before merge (§Open questions).
- **Precedent mirrored:** `FormatDefaults` (`Sources/ThemeKit/FormatDefaults.swift`) — additive, Open/Closed subtree defaults where per-call arguments always win.

## Context

A consumer installs the ThemeKit SPM and wants to author **their own String Catalog** (e.g. add Turkish), drop it into their app target, and have the **entire component library switch language automatically** — with no per-call-site code. Per-component parameter overrides must still exist and still win. **Hard requirement:** restart-free in-app language switching (the standard TR-app pattern: a settings-screen language picker that flips the whole UI live).

**What exists today:**

- Every user-facing default string flows through **one bridge** — `String(themeKit:)` in `Sources/ThemeKitCore/Localization.swift`, whose body is `String(localized: key, bundle: .module)`. **408 call sites** (71 of them with interpolations: `String(themeKit: "\(count) installments")`).
- `Package.swift` declares `defaultLocalization: "en"`; the bundled catalog is `Sources/ThemeKitCore/Resources/Localizable.xcstrings` — **181 keys, en-only, zero plural variations**. Keys ARE the English source strings (`"Phone number"`, `"%lld installments"`, `"%1$@ to %2$@%3$@"`).
- **A meaningful fraction of call sites resolve OUTSIDE the View graph** — enum computed properties and model helpers where `@Environment` is unreachable (`ColorModels.swift:72`, `Steps.swift:218`, `Stat.swift:17`, `CalendarView.swift:152`, `SearchField.swift:269`, …). A pure `@Environment`-based provider is therefore **insufficient**: we need a process-global resolution layer readable from non-View code, *plus* a way to make the View tree re-render on a live locale change.
- Reusable signal: **52 files already read `@Environment(\.locale)`**, and `LanguageSwitcher` (Molecules) already exists as the controlled picker UI (BCP-47 `selection` binding) — it just needs something to drive.

**Drift found while writing this ADR (must be fixed as phase 0):**

- **117 literal keys used in code are missing from the shipped catalog** (e.g. `"Hue"` at `ColorModels.swift:72` resolves only because a missing key echoes back as English) and **62 catalog keys are stale or interpolation-shaped**. A consumer translating the shipped 181-key catalog today would miss over a third of the real string surface.
- `README.md:66` claims the catalog ships "(with Turkish)" — false; the `tr` localization was removed. The header comment in `Localization.swift:14-15` repeats the claim.
- `Sources/ThemeKitTravel/Resources/Localizable.xcstrings` exists but contains **0 keys**, while Travel components call the same bridge.

## What the spike verified (observed, not assumed)

A compiled Foundation spike (hand-built bundle with `en`/`tr`/`ru` `.lproj`s carrying `.strings` + `.stringsdict` — exactly what Xcode compiles an `.xcstrings` into at build time) established:

| # | Question | Observed | Consequence |
|---|---|---|---|
| 1 | Does `String(localized:bundle:locale:)` select that locale's `.lproj` from the bundle? | **No.** `"Hue"` with `locale: tr` returned `"Hue"`, not `"Ton"`; resource selection stays pinned to the bundle's `preferredLocalizations` (fixed at process start). The `locale:` parameter only formats interpolations. | The "obvious" one-liner is a dead end. Consumer-catalog resolution **must** go through explicit per-language sub-bundles. |
| 2 | Runtime switch via that API, same process? | **No.** Two calls with different `locale:` values returned identical strings. | Same consequence. |
| 3 | Sub-bundle path: `Bundle(path: bundle.path(forResource: "tr", ofType: "lproj")!)` → `localizedString(forKey:value:table:)`? | **Works.** Returned `"Ton"` immediately, no restart, no pinning — each `.lproj` wrapped as its own `Bundle` is language-exact. | This is the reliable mechanism. Design to it. |
| 4 | Do plurals survive the sub-bundle path? | **Yes, with one rule.** `localizedString(forKey:)` on a `.stringsdict` key returns a format carrying the plural table; expansion must use **`String(format:locale:arguments:)` with the target locale** — verified with Russian (2 → `few`, 5 → `many`), whereas `String.localizedStringWithFormat` silently uses `Locale.current`'s plural rules (returned `other` for both under a tr_TR host). | The resolver expands with `String(format:locale:effective, arguments:)`, never `localizedStringWithFormat`. |
| 5 | BCP-47 → `.lproj` matching ("tr-TR" → `tr`, unknown → source language)? | **Works** via `Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [code])` — returned `["tr"]` for `tr-TR`, `["en"]` for an unknown code. | Use it; never string-munge language codes. |
| 6 | Detecting a missing key in the consumer catalog? | **Works** via the `value:` sentinel — `localizedString(forKey:value:"\u{7F}")` returns the sentinel on a miss (with `value: nil` it echoes the key, indistinguishable from a real value). | Sentinel probe gates the fallback to `.module`. |

**Remaining assumption (low risk, verify once on device):** Xcode compiles a consumer's `.xcstrings` into `.strings`/`.stringsdict` files inside `.lproj` directories (Apple-documented build behavior); the spike exercised that compiled form directly, not an Xcode-built app bundle. If a future toolchain moves app catalogs to single-file `.loctable`, the sub-bundle path needs re-verification — `sr-ios-dev` confirms once with a real device/simulator build in the test plan below.

## Decision

Adopt a **three-layer, additive localization-override architecture** anchored at the existing single bridge. Per-call parameter overrides remain the top of the chain untouched.

### D1 — Resolution chain (the bridge's new body)

Ordered, first hit wins:

1. **Per-call argument** — a component parameter (`.label("Telefon")`) never reaches the bridge. Unchanged, always wins.
2. **Consumer catalog, effective language** — table `"ThemeKit"` in the registered bundle (default `Bundle.main`); language chosen by `Bundle.preferredLocalizations(from:forPreferences: [effectiveLocale.identifier])`, loaded as a cached `.lproj` sub-bundle, miss detected by sentinel.
3. **Consumer catalog, source language (`en`)** — so a consumer who *rewords* an English default (without translating) sees it in every language.
4. **ThemeKit's `.module` catalog** — `String(localized: key, bundle: .module, locale: effective)`, i.e. exactly today's call (the added `locale:` only formats interpolations per spike #1, which is precisely what we want).

Where `effectiveLocale = ThemeKitStrings.locale ?? Locale.autoupdatingCurrent`.

```swift
// Localization.swift — the only file whose *body* changes; all 408 call sites unchanged.
public extension String {
    init(themeKit value: ThemeKitLocalizationValue) {
        self = ThemeKitStrings.resolve(value)
    }

    @available(*, deprecated, message: "Pass a string literal; explicit String.LocalizationValue bypasses consumer catalogs.")
    @_disfavoredOverload
    init(themeKit key: String.LocalizationValue) {           // source-compat for explicit-value callers
        self = String(localized: key, bundle: .module)
    }
}

// Resolver core (ThemeKitCore, internal mechanics):
static func resolve(_ v: ThemeKitLocalizationValue) -> String {
    let locale = state.withLock { $0.locale } ?? .autoupdatingCurrent
    if let format = consumerFormat(forKey: v.key, locale: locale) {              // D1 steps 2–3
        return v.arguments.isEmpty
            ? format
            : String(format: format, locale: locale, arguments: v.arguments)     // spike #4: plural-correct
    }
    return String(localized: v.fallback, bundle: .module, locale: locale)        // D1 step 4 — today's path
}
```

`consumerFormat(forKey:locale:)` = language match (spike #5) → cached sub-bundle (spike #3) → `localizedString(forKey: key, value: sentinel, table: state.table)` (spike #6) → on miss, one retry against the source-language sub-bundle → `nil`. Sub-bundles are cached per language in the lock-protected state and invalidated on `register`/`locale` change.

**Defensive rule:** in DEBUG, validate that the consumer format's `%` specifier count/positions are satisfiable by `v.arguments`; on mismatch, log and fall through to step 4 rather than risk a `String(format:)` crash from a bad translation.

### D2 — The capture type: `ThemeKitLocalizationValue`

`String.LocalizationValue` is opaque — its key and arguments are not extractable via public API, so it cannot feed steps 2–3. The bridge parameter becomes a ThemeKit-owned `ExpressibleByStringInterpolation` type that captures **three things in one pass**:

```swift
public struct ThemeKitLocalizationValue: ExpressibleByStringInterpolation {
    let key: String                        // "%lld installments" — specifier per segment, matching Xcode's extractor
    let arguments: [CVarArg]               // [count]
    let fallback: String.LocalizationValue // mirror-built, for the .module path (D1 step 4)
    // StringInterpolation: literals append verbatim to all three;
    // appendInterpolation(String) → "%@", Int → "%lld", UInt → "%llu",
    // Double → "%lf", Float → "%f" … — the exact specifier mapping
    // String.LocalizationValue uses, so captured keys match the catalog keys
    // Xcode already extracted from these same call sites.
}
```

All 408 sites pass literals or literal interpolations, so they compile unchanged (`ExpressibleByStringInterpolation` handles both, including the `CalendarView.swift:152` ternary-of-literals shape). The 71 interpolated sites define the required overload set — `sr-ios-dev` compile-verifies it (§Open questions).

### D3 — Process-global config: `ThemeKitStrings` (ThemeKitCore)

The layer non-View call sites read, and the single mutation point for live switching:

```swift
public enum ThemeKitStrings {
    /// Register a consumer catalog. Zero-config default: Bundle.main + table "ThemeKit".
    public static func register(bundle: Bundle = .main, table: String = "ThemeKit")

    /// Live language override. nil → follow the system (Locale.autoupdatingCurrent).
    /// Setting it re-resolves every subsequent string AND re-renders any tree
    /// under `.themeKitLocalized()`. Restart-free.
    public static var locale: Locale? { get set }

    /// Convenience for LanguageSwitcher: a Binding<String> over the BCP-47 code.
    @MainActor public static var languageBinding: Binding<String>
}
```

- State (`bundle`, `table`, `locale`, sub-bundle cache) lives behind an `OSAllocatedUnfairLock` (iOS 16/macOS 13 floor — within our iOS 17/macOS 14 targets), so enum computed properties and model helpers resolve safely from any isolation. No `@MainActor` requirement on the read path.
- The `locale` setter also bumps an internal `@Observable` revision box on the main actor — the hook `.themeKitLocalized()` observes (D4).
- **Zero-config is the default** (§D5): even without `register`, `resolve` probes `Bundle.main` table `"ThemeKit"`. `register` exists for app extensions, ThemeKit-embedding frameworks, and custom table names.

### D4 — View layer: root provider + subtree convenience

```swift
public extension View {
    /// Root provider — makes the subtree live-localizable. Place once at the app root.
    /// Observes ThemeKitStrings' revision; on change re-injects the effective
    /// \.locale (+ matching \.layoutDirection for RTL languages) and re-identifies
    /// the subtree so every body re-runs in the new language.
    func themeKitLocalized() -> some View

    /// Subtree/preview convenience: sets \.locale for formatting and the 52
    /// locale-reading components. Does NOT change string-catalog language —
    /// see "known limitation" below.
    func themeKitLocale(_ locale: Locale) -> some View
}

// Implementation shape:
struct ThemeKitLocalizedRoot: ViewModifier {
    @State private var revision = ThemeKitStrings.observable   // @Observable box
    func body(content: Content) -> some View {
        let locale = ThemeKitStrings.effectiveLocale
        content
            .environment(\.locale, locale)
            .environment(\.layoutDirection,
                         Locale.Language(identifier: locale.identifier)
                             .characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
            .id(revision.value)                                  // full re-render on switch
    }
}
```

**Why `.id(revision)`:** strings resolve during body construction into plain `String`s; SwiftUI only re-runs bodies whose *dependencies* changed, and 408 baked strings are not dependencies. Re-injecting `\.locale` alone re-renders only the 52 locale-readers. Re-identifying the root subtree is the one mechanism that guarantees every body re-runs — it is also the standard SwiftUI pattern for in-app language switching. **Documented cost:** view-local `@State` below the root resets on switch; app state held in `@Observable` models and navigation state stored outside the view tree survive. That trade-off is inherent to restart-free switching, acceptable for a settings-screen action, and infinitely better than a relaunch.

**Known limitation (stated, not hidden):** per-*subtree* string language (two languages on one screen) is physically impossible at a `String` initializer — it can never read `@Environment`. `.themeKitLocale(_:)` therefore only scopes formatting/locale-reading behavior; mixed-language string subtrees are out of scope. Previews share a process, so a `#Preview` that sets `ThemeKitStrings.locale` should reset it — provide a `ThemeKitStrings.withLocale(_:){}` test/preview helper.

**LanguageSwitcher wiring (restart-free, end to end):** the existing controlled component drives the global —

```swift
LanguageSwitcher([.init(code: "en"), .init(code: "tr"), .init(code: "ar")],
                 selection: ThemeKitStrings.languageBinding)
```

setter → `ThemeKitStrings.locale = Locale(identifier: code)` → revision bump → `.themeKitLocalized()` re-renders → every `String(themeKit:)` in every re-run body resolves through D1 with the new effective locale — including the non-View enum/model helpers, because they read the same process-global. No restart.

### D5 — Zero-config discovery over explicit registration (recommended default: zero-config ON)

Convention: the consumer drops a **`ThemeKit.xcstrings`** file into their app target. Xcode compiles it to table `"ThemeKit"` in `Bundle.main`; the resolver's default state already probes exactly there. **Nothing to call.**

Justification: drop-a-file-and-the-library-speaks-Turkish is the entire feature; the probe cost on the no-catalog path is one cached `preferredLocalizations` match plus a dictionary miss per resolution — negligible against body construction. A dedicated table (not `Localizable`) means zero collision with the consumer's own strings, and the file name doubles as documentation. Explicit `register(bundle:table:)` covers the real exceptions: app extensions (whose `.main` is the extension), frameworks embedding ThemeKit, and teams with catalog-naming conventions.

### D6 — Key stability: keep English-source keys

Keep the source-English string as the key (`"Phone number"`, not `themekit.phone.placeholder`). Symbolic keys would be more rename-proof but cost a 181-key catalog migration, churn on all 408 call sites' greppability, and make the consumer template unreadable without a second column. The known weakness — an English copy edit silently orphans consumer translations — is mitigated structurally by D7: the template is **generated from code**, so any key change shows up as a diff in a checked-in artifact and a CI failure, not a silent orphan. Rejected: symbolic keys (cost ≫ benefit at 181 keys); hybrid (worst of both).

### D7 — Generated template + CI drift gate (`tools/gen_l10n.py`, phase 0)

The 117-missing/62-stale drift proves hand-maintenance has already failed. Following the `tools/gen_skill.py` / `make skill` precedent:

- `tools/gen_l10n.py` extracts every `String(themeKit:)` key from both source roots (`Sources/ThemeKit*`), converting interpolations to their specifier form (`\(count)` → `%lld`) with the same mapping as D2.
- It **regenerates** `Sources/ThemeKitCore/Resources/Localizable.xcstrings` + the Travel catalog (fixing the current drift), and **emits the consumer template** `Templates/ThemeKit.xcstrings` — all current keys, English values, existing comments preserved — so consumers never guess the key set.
- `make l10n` target; CI check that regeneration is a no-op (same pattern as the skill/llms gate). English copy edits now surface as visible template diffs (D6's mitigation).

## Consumer authoring guide (normative)

**The file:** `ThemeKit.xcstrings` — start from the generated template at `Templates/ThemeKit.xcstrings`, add it to the app target (any group; target membership is what matters). Keep only the keys you translate if you prefer — untranslated keys fall back per D1 (your `en` rewording if present, else ThemeKit's English).

**Adding a language:** open the file in Xcode's String Catalog editor → “+” under the language list → pick Turkish → fill the `tr` column. For keys with `%` specifiers, keep every specifier; if your translation reorders them, use positional forms (`%1$@`, `%2$lld`). To pluralize a format key, right-click → *Vary by Plural*.

Minimal example (2 keys, one plural — both are real ThemeKit keys):

```json
{
  "sourceLanguage" : "en",
  "version" : "1.0",
  "strings" : {
    "Phone number" : {
      "localizations" : {
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Telefon numarası" } }
      }
    },
    "%lld installments" : {
      "localizations" : {
        "tr" : { "variations" : { "plural" : {
          "one"   : { "stringUnit" : { "state" : "translated", "value" : "Tek taksit" } },
          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld taksit" } }
        } } }
      }
    }
  }
}
```

**Wiring — zero-config (follow the system language):** none. Drop the file; when the device/app language is Turkish, every ThemeKit default is Turkish. (App-level per-app language via Settings works automatically too, since `Locale.autoupdatingCurrent` reflects it.)

**Wiring — restart-free in-app switcher:**

```swift
@main struct TravelApp: App {
    @AppStorage("appLanguage") private var appLanguage = "en"
    var body: some Scene {
        WindowGroup {
            RootView()
                .themeKitLocalized()                                       // root provider, once
                .onAppear { ThemeKitStrings.locale = Locale(identifier: appLanguage) }
        }
    }
}

// Settings screen — flips the whole UI live, no relaunch:
LanguageSwitcher([.init(code: "en"), .init(code: "tr")],
                 selection: Binding(
                     get: { appLanguage },
                     set: { appLanguage = $0
                            ThemeKitStrings.locale = Locale(identifier: $0) }))
    .variant(.list)
```

## Consequences

- **Positive:** one file's body change lights up 408 call sites for any consumer language, View and non-View alike; restart-free switching lands as a first-class, documented pattern with `LanguageSwitcher` as the ready-made UI; the FormatDefaults philosophy (additive, per-call wins) extends to strings; the drift-generating hand-edited catalog becomes a generated artifact; the false README/doc-comment `tr` claims get corrected.
- **Behavioral guarantee:** with no consumer catalog and no `locale` override, every resolution ends at D1 step 4 with `locale = .autoupdatingCurrent` — the exact code path and output of today.
- **Costs / risks:** the D2 overload set must cover all 71 interpolated sites (compile gate); `.id(revision)` resets view-local `@State` on switch (documented, inherent); `String(format:)` with consumer-authored formats needs the DEBUG specifier validation to be crash-safe; the `.xcstrings → .lproj` compilation assumption needs one on-device confirmation; previews share the process-global (helper provided).
- **Enforcement:** `make l10n` CI gate keeps code and catalogs in lockstep forever; the deprecated disfavored overload keeps any explicit-`LocalizationValue` caller compiling with a nudge.

## Testing strategy

- **Unit (ThemeKitCore):** fixture bundle built like the spike (en/tr/ru, `.strings` + `.stringsdict`), registered via `register(bundle:table:)`. Assert: chain order (per-call → tr → consumer-en rewording → module), sentinel miss-through, plural categories under ru (2 → few, 5 → many) proving `String(format:locale:)` usage, BCP-47 matching (`tr-TR` → tr), live `locale` flip mid-test, revision bump on set, specifier-mismatch fall-through, and the no-config path returning today's output verbatim.
- **Snapshot:** one forced-`tr` lane — fixture registered + `.themeKitLocalized()` around existing harness subjects; plus an RTL (`ar`) case asserting the `layoutDirection` injection.
- **On-device confirmation (once):** demo app with a real `ThemeKit.xcstrings`, deep-link `-openDemo "Language Switcher"`, flip language, screenshot before/after.

## Phased rollout (PR-per-unit)

| Phase | Unit | Effort |
|---|---|---|
| 0 | `tools/gen_l10n.py` + `make l10n` + CI gate; regenerate both catalogs (fixes 117 missing / 62 stale); emit `Templates/ThemeKit.xcstrings` | M |
| 1 | `ThemeKitLocalizationValue` + `ThemeKitStrings` + resolver (bridge body swap) + unit fixtures | M |
| 2 | `.themeKitLocalized()` / `.themeKitLocale(_:)` + `languageBinding` + LanguageSwitcher live demo + snapshot lane + on-device confirmation | M |
| 3 | Docs: consumer guide page (website), README fix (remove "(with Turkish)"), `Localization.swift` header fix, DocC article | S |

## Alternatives considered

1. **`String(localized:bundle:locale:)` directly at the bridge.** Rejected by spike #1–#2: the `locale:` parameter does not select resources and cannot switch at runtime — it would ship a feature that silently never works.
2. **Pure `@Environment` provider (no process-global).** Rejected: the confirmed non-View call sites (`ColorModels.swift:72` et al.) can never read an environment; strings there would permanently stay English, fracturing the "entire library switches" requirement.
3. **Reflection (`Mirror`) to extract key/args from `String.LocalizationValue`** instead of D2's capture type. Rejected: depends on Foundation's private layout; one OS update away from silent English-only regression. The capture type is boring and ours.
4. **`Bundle.setLanguage` swizzling / `AppleLanguages` UserDefaults rewrite** (the classic TR-app hack). Rejected: process-global side effects on the *consumer's* app, App-Review-fragile, still needs a relaunch for `AppleLanguages`, and a zero-dependency design-system library must not swizzle Foundation.
5. **Symbolic keys** (`themekit.phone.placeholder`). Rejected per D6.
6. **Requiring explicit registration (no zero-config).** Rejected per D5: one avoidable setup call for the 95% case; extensions/frameworks keep the explicit path.
7. **Re-render via NotificationCenter + per-component subscriptions.** Rejected: 217-file churn, misses future components, and `.id(revision)` at one root achieves the guarantee for free.

## Open questions (for sr-ios-dev pressure-testing)

- **D2 overload set:** enumerate the interpolated types across the 71 sites (String, Int, Double, formatted Decimals-as-String, …) and compile-verify; decide whether a `CustomStringConvertible` catch-all (→ `%@`) is safe or too permissive vs. `String.LocalizationValue`'s specifier behavior.
- **`[CVarArg]` sendability** under Swift 6 language mode for the transient capture type (`@unchecked Sendable` vs. structuring resolution to stay isolation-local).
- **`.xcstrings` compiled form on device** (spike's stated assumption) — confirm `path(forResource:ofType:"lproj")` finds compiled catalogs in a real Xcode-built app, including per-app-language installs.
- Whether `ThemeKitTravel`'s (currently empty) catalog merges into the single consumer template or ships as a second `ThemeKitTravel.xcstrings` table — recommendation: **one merged template**, since the consumer experience is one file.
- Whether `.themeKitLocalized()` should also refresh `\.calendar`/`\.timeZone`-adjacent formatting environment, or leave those to the consumer.
