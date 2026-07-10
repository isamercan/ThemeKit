# ThemeKitTravel — Domain-Edition Architecture Decision Record & Build Plan

**Author:** iOS Architect agent · **Date:** 2026-07-10 · **Status:** REVISED — sr-ios-dev pressure-test complete (2026-07-10, probe-proven); call-site revisions folded in (see §1.4). Architecture holds; no structural change; F0.3/F1.1/F1.2/F1.3 all GO with revisions.
**Companion docs:** `HEROUI_INFRA_PLAN.md` (cross-cutting infra ADRs T1–T8 + sr-ios-dev review — this plan *builds on* those primitives), `HEROUI_NATIVE_AUDIT.md` (per-component gaps), issue #229 / memory `themekit-modular-roadmap` (Core split + domain-edition direction), `.claude/skills/themekit-authoring` (the 6 house rules).

---

## Table of contents

1. [Scope, ground truth & relationship to sibling plans](#1-scope-ground-truth--relationship-to-sibling-plans)
2. [ADR-F1 — Module architecture & SPM packaging](#2-adr-f1--module-architecture--spm-packaging)
3. [ADR-F2 — Provider & global defaults (`FormatDefaults` + `FlightDefaults`)](#3-adr-f2--provider--global-defaults)
4. [ADR-F3 — Canonical domain model layer (the `Pick`-slice discipline in Swift)](#4-adr-f3--canonical-domain-model-layer)
5. [ADR-F4 — Controlled/uncontrolled state strategy & adoption matrix](#5-adr-f4--controlleduncontrolled-state-strategy)
6. [ADR-F5 — Style-protocol & variant strategy (and FlightListItem anti-sprawl)](#6-adr-f5--style-protocol--variant-strategy)
7. [ADR-F6 — Validation layer: `FormValidator` is the schema (no zod-analog)](#7-adr-f6--validation-layer)
8. [ADR-F7 — Folder layout: atomic layers, not feature folders](#8-adr-f7--folder-layout)
9. [Full API design — the 12 gap components](#9-full-api-design--the-12-gap-components)
   - 9.1 [PhoneField (P0)](#91-phonefield-p0--molecule)
   - 9.2 [PassengerForm (P0)](#92-passengerform-p0--organism)
   - 9.3 [PaymentMethodSelector (P0)](#93-paymentmethodselector-p0--organism)
   - 9.4 [AirportPicker (P1)](#94-airportpicker-p1--organism)
   - 9.5 [CabinClassSelector (P1)](#95-cabinclassselector-p1--molecule)
   - 9.6 [TripSearchCard (P1)](#96-tripsearchcard-p1--organism)
   - 9.7 [FlightListItem.favorite() (P1)](#97-flightlistitemfavorite-p1--extension)
   - 9.8 [TransportCrossSellCard (P2)](#98-transportcrosssellcard-p2--organism)
   - 9.9 [FlightTracker (P2)](#99-flighttracker-p2--organism)
   - 9.10 [SavedCardsList (P2)](#910-savedcardslist-p2--organism)
   - 9.11 [CheckInFlow (P2)](#911-checkinflow-p2--organism-scaffold)
   - 9.12 [LanguageSwitcher (P2)](#912-languageswitcher-p2--molecule-neutral-not-flight)
10. [Currency / locale defaults — the concrete migration](#10-currency--locale-defaults--the-concrete-migration)
11. [Accessibility, RTL, localization & Dynamic Type architecture](#11-accessibility-rtl-localization--dynamic-type-architecture)
12. [Sequenced build plan (phases, gates, dependency order)](#12-sequenced-build-plan)
13. [Risks & open questions for sr-ios-dev](#13-risks--open-questions)

---

## 1. Scope, ground truth & relationship to sibling plans

### 1.1 What ThemeKitTravel is

A **flight/booking domain edition** of ThemeKit: an opt-in module that packages the airline component family (today ~21 files living directly in `Sources/ThemeKit/Components/{Atoms,Molecules,Organisms}`) plus **12 new components** closing the flight-booking flow (traveler forms, payment, airport search, check-in, tracking). It follows the #229 modular direction: **ThemeKitCore** (token engine, shipped v1.1.0) → **ThemeKit** (neutral catalog) → **domain editions that WRAP neutral primitives into domain organisms**. Composition, not forking; the base never assumes a domain.

This is an architecture deliverable. No implementation ships from this document — every API below is a sketch for `sr-ios-dev` to pressure-test with concrete call sites and a Swift 6 build.

### 1.2 Ground truth (verified in source, 2026-07-10, branch `feat/heroui-infra-sprint-1`)

| Fact | Where verified |
|---|---|
| SPM: products `ThemeKit`, `ThemeKitCore`, `ThemeKitLottie`, `ThemeKitCalendar`; traits `Lottie`/`Calendar` with **empty default set**; zero-dep core | `Package.swift:16–55` |
| `ControllableState` shipped (HeroUI infra unit 1, commit `4116df6`), `@MainActor` accessors, dual-init pattern | `Sources/ThemeKitCore/ControllableState.swift` |
| `ComponentDefaults` env (radius/elevation/accent; explicit-wins merge via `transformEnvironment`) | `Sources/ThemeKit/ComponentDefaults.swift` |
| `FlightLeg` (Codable, content-derived id) is **declared inside `FlightCard.swift:19–41`** and consumed by FlightCard, FlightResultRow, FlightListItem(+Style) | `grep FlightLeg` — 4 files |
| `FlightFare` is declared inside `FlightListItem.swift:28–41`; `FareLine` inside `FareSummary.swift:15`; `QuickFilter` inside `FilterBar.swift:19`; Seat family in `SeatMapModels.swift` (the one existing `<X>Models.swift` precedent) | source |
| `FlightListItem` = data container + 9-preset `FlightListItemStyle` protocol (`.compact/.timeline(default)/.fareBoard/.deal/.ticket/.journey/.slices/.timetable/.tray`), `FlightListItemConfiguration` has **public lets + internal init** (additive fields safe) + shared formatting helpers capturing `locale` | `FlightListItem.swift`, `FlightListItemStyle.swift:33–108, 249–899` |
| Currency drift: `FlightListItem` defaults `"USD"` (`FlightListItem.swift:60,135`); FlightCard/FlightResultRow/FlightTicketCard/StickyBookingBar/AncillaryCard/FareSummary/PriceTag/SeatCell/DatePriceStrip/… default `"TRY"` (~20 sites) | grep `"TRY"\|"USD"` |
| Existing composable primitives for the new components: `TextInput` (model + `addons`, `externalFocus`, `infoMessages`, formatter), `Select`/`SelectBox`, `DateField(_ label:date:Binding<Date?>)`, `Fieldset(_ title:content:)`, `SegmentedControl`, `TripTypeToggle`, `GuestSelector(selection:Binding<GuestSelection>)`, `SwapButton`, `Autocomplete` (debounce/onSearch), `PaymentCardField` (+ public `CardBrand`), `InstallmentPicker/InstallmentSelector`, `CurrencyPicker` (+ public `Currency`), `RecentSearchRow`, `PassengerRow` (display row, not a form), `Steps`, `ButtonDock`, `KeyValueTable`, `Timeline`, `FilterBar` | file listing + API grep |
| Validation layer: `FormValidator<Field: Hashable>` (`@MainActor @Observable`; `messages(for:)`, `validate(_:_:)`, `validateAll`, `focusBinding`) + `ValidationRule`/`InfoMessage`; HEROUI unit 13a/13b adds `externalFocus` across the field family + `.field(_:in:)` wiring | `Sources/ThemeKit/Validation/`, HEROUI plan §T8 + review |
| Settled roadmap (#229): editions have **no SPM traits** ("traits prune dependency resolution; editions have zero external deps → wrong tool; traits union across the graph and leak"); domain move is a 2.0 breaking batch; deprecations toward a module land only in the **last 1.x after the module exists**; earlier note said the 2.0 target is a **single `ThemeKitTravel`** (Flight+Booking merged, because booking renders flight components) — reconciled in ADR-F1 | memory `themekit-modular-roadmap` |
| Reference methodology (HeroUI React, `upskillsdev/flight-booking-ui`): types-first `interface Flight` single source of truth; every component's props = `Pick<Flight, …>`; thin atoms wrap primitives (`AirlineLogo = Avatar + Skeleton fallback`); `ControlledFormFieldProps<T> = {name, control, formState}`; zod schema as form source of truth; feature folders with co-located stories | fetched `types.ts`, `schema.ts`, `flight-card.tsx`, `airline-logo.tsx`, tree |

### 1.3 Non-goals

- No re-audit of the ~21 existing flight components (they are API-complete; `HEROUI_NATIVE_AUDIT.md` owns per-component gaps).
- No literal port of React idioms (`className`, render props, react-hook-form `control` plumbing, zod). Each is mapped to a house idiom below.
- No breaking public-API change in 1.x. The one *behavioral* change (currency resolution, §10) is called out explicitly with a migration note.
- No new external dependencies. The edition is pure SwiftUI on top of ThemeKit.

### 1.4 Pressure-test revisions (sr-ios-dev, 2026-07-10 — probe-proven)

The plan was pressure-tested against source with `swiftc -swift-version 6` executable probes. **The architecture holds — every revision is call-site-level, none structural; the §1.2 ground-truth table was accurate throughout.** Full report: `themekittravel-pressuretest.md`. The following amend the sections named:

1. **§10 currency overload (OQ-7 · NEEDS-REVISION, fix proven):** the omitted-arg overload must replicate *every parameter except `currencyCode`*, not just `price(_:)`. Probe proved `price(214, caption: "from")` — FlightListItem's *documented headline call* — binds the OLD overload and silently keeps hardcoded `"USD"`. Correct shape: `func price(_ amount: Decimal?, caption: String? = nil)` beside the existing 3-param (Swift prefers the fewer-synthesized-defaults candidate; no ambiguity, all 4 call patterns correct). 2-param modifiers keep the plain `price(_:)` overload. `InstallmentSelector`'s currency is an **init** param → it's an init-overload sweep item, not a modifier (flag on the F0.3 checklist). CHANGELOG wording: "callers omitting `currencyCode:`" (not "all arguments").
2. **§3 provider (OQ-6 · CONFIRMED + amendment):** `Date.FormatStyle?` synthesizes `Equatable`/`Hashable` cleanly and does **not** cause spurious env invalidation (enum-preset fallback unneeded) — but under Swift 6 an `EnvironmentKey.defaultValue` struct **must be `Sendable`**. Declare `FormatDefaults`/`FlightDefaults` as `Equatable, Sendable` with a plain `static let defaultValue` (all fields are Sendable); do NOT copy `ComponentDefaults`' `nonisolated(unsafe)` — consider back-porting the fix in the same PR.
3. **§9.1 PhoneField (OQ-2a · NEEDS-REVISION + 1 sim probe):** `TextInput.addons(before:)` takes a **String**, not a view — the sketched composition point doesn't exist. Use the real **`.leading { }`** view slot (or add an additive `addons(@ViewBuilder before:)` overload — a general win, unambiguous with the String version). Interactivity is near-certain (shipped clear/reveal `Button`s live in the same tap-gestured row), but a `Menu` in the slot needs one 5-min simulator probe before F1.1 freezes internals. Fallback is **direct `FieldStyle.makeBody`** (SelectBox precedent), *not* HEROUI unit 12 (that is card chrome). `externalFocus`/`infoMessages`/formatter/`.keyboard`/`.required`/`.a11yID` all confirmed.
4. **§9.2 PassengerForm (OQ-3 · CONFIRMED w/ notes):** `form.submit(…)` **does not exist** (HEROUI unit 13b, unshipped) — the §9.2 call site must use `if form.validateAll(traveler.formValues) == nil { … }` until 13b (or sequence F1.2 after it). Pin serialization to **ISO-8601** in both `PassengerDraft.formValues` and the rule-pack date factories (enums serialize as `rawValue`). `SelectBox` exposes only `errorText(String?)` (no `[InfoMessage]`/focus) and `DateField` has no focus API → "messages + focus flow through the validator" is TextInput-only until HEROUI 13a; focus-first-invalid lands on name/document fields only. Document it; fine for Phase 1.
5. **§9.3 PaymentMethodSelector (F1.3 · revised):** `.installments` **`total:` becomes required** (`total: Decimal`) — both `InstallmentPicker`/`InstallmentSelector` need a total to render per-month amounts; `nil` composes neither. The §9.3 call site already passes `total: fareTotal`.
6. **§9.7 favorite() (OQ-2b · CONFIRMED — ship shape B):** ship the **ControllableState-reassigned-in-copy** shape (not sketch A) — it applies ADR-F4 uniformly and cleanly retrofits `.expanded(_:)` too. **Compiler landmine:** a stored `favorite` property + a nullary `func favorite()` is an *invalid redeclaration* → rename the backing var (`favoriteState`); F2.4's no-arg overloads on `FlightCard`/`FlightResultRow` require renaming their private `favorite`/`bookmark` vars first (private → api-gate green, but must be in the PR plan). Uncontrolled heart survives List *scrolling* (state-per-identity) but not identity churn — document; 5-min sim scroll check in F2.4.
7. **OQ-4 → NEUTRAL:** `PhoneField` + `DialCode` land in **`Sources/ThemeKit/Components/Molecules/`** (PaymentCardField precedent), not the edition — every checkout/contact form needs a phone field. F1.1 sheds its F0.1/F0.4 dependency (only `DialCode` moves off the edition-models list). **OQ-5 → SKIP:** drop the `FareFamilyCard(_: FlightFare)` convenience from F0.2 — `FlightFare.perks` are SF-symbol names, `FareFeature` needs text; the bridge renders garbage, and name+price is a one-line manual call.

**Go/no-go:** F0.3, F1.1, F1.2, F1.3 **all GO** with the revisions above.

---

## 2. ADR-F1 — Module architecture & SPM packaging

### Decision

**Ship a new SPM target + product `ThemeKitTravel`, depending on `ThemeKit` (the full catalog), with NO trait, NO re-export from `ThemeKit`, and a two-phase population strategy:**

- **Phase A (1.x, additive):** the module is created and **all 12 new components land there from day one**. The ~21 existing flight components **stay in `ThemeKit` untouched** (public API preserved — the library is public at v1.x). `ThemeKitTravel` contains `@_exported import ThemeKit`? **No** — a plain `import ThemeKit` inside the module and *no* re-export in either direction (per the settled #229 rule: a domain `@_exported` would re-pollute the neutral namespace; and consumers of the edition should keep writing `import ThemeKit` + `import ThemeKitTravel` explicitly, mirroring `ThemeKitCalendar`).
- **Phase B (2.0, breaking, batched):** the existing flight set — all three tiers, ~25–30 files: atoms `FlightStatusBadge`/`FareFeatureRow`/`SeatCell`, molecules `FlightRoute`/`LayoverRow`/`SeatLegend`/`DatePriceStrip`/`TripTypeToggle`/`RecentSearchRow`/`PassengerRow`, organisms `FlightListItem(+Style)`/`FlightCard`/`FlightResultRow`/`FlightTicketCard`/`FareFamilyCard`/`SeatMap(+Models)`/`BoardingPass`/`FilterBar`/`FareSummary`/`StickyBookingBar`/`AncillaryCard` — moves into `ThemeKitTravel`, with live `@available(*, deprecated, renamed:)` shims landing in the **last 1.x release after the module exists** (the settled deprecation rule). `TicketStub` (a generic decorative shell also used by `Coupon`) and `Steps` (generic wizard) **stay neutral**.

Dependency direction is strictly one-way: `ThemeKitCore ← ThemeKit ← ThemeKitTravel`. The edition never reaches into `Demo`/`Tests` and nothing in `ThemeKit` may name a `ThemeKitTravel` type.

```swift
// Package.swift (additive)
.library(name: "ThemeKitTravel", targets: ["ThemeKitTravel"]),
…
.target(
    name: "ThemeKitTravel",
    dependencies: ["ThemeKit"],          // catalog, which re-exports ThemeKitCore
    swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
),
// ThemeKitTests gains a "ThemeKitTravel" dependency so the snapshot/a11y/RTL
// harness covers the edition; Demo app links the new product.
```

### Why `ThemeKit`, not `ThemeKitCore`, as the dependency

The commission says "wraps the neutral ThemeKitCore" — philosophically true (everything ultimately resolves to Core tokens), but **mechanically the edition composes catalog components** (`TextInput`, `Select`, `DateField`, `Fieldset`, `SegmentedControl`, `Card`/`cardChrome`, `PriceTag`, `Badge`, `Steps`, `ButtonDock`, `FormValidator`…). Depending only on Core would force re-implementing the field family — the exact forking the edition philosophy forbids. "Wraps the neutral core" = *wraps neutral core components*, i.e. the catalog.

### Why no trait

Verbatim settled rule from the #229 execution plan: traits exist to prune *external dependency resolution*; `ThemeKitTravel` has zero external deps, so a trait is the wrong tool — and traits union across the dependency graph and leak. A plain optional **product** already gives perfect opt-in: consumers who don't add `ThemeKitTravel` to their target's dependencies compile nothing from it and download the same package they already download. (The `xcodebuild ignores traits` gotcha from the add-on work also simply doesn't arise.)

### Adopting the settled `ThemeKitTravel` name — OQ-1 RESOLVED (user, 2026-07-10)

The #229 roadmap settled on one `ThemeKitTravel` because splitting Flight and Booking into *sibling* modules cycles (booking renders flight components). **We keep that name.** `ThemeKitTravel` is the module; the **flight-booking vertical** (search → results → fare → seat → ancillaries → passenger/payment → boarding/check-in/tracking) is its **first shipped cluster**. Later clusters — **stay** (`RoomCard`, `HotelResultCard`, `GuestSelector`-rooms mode, `DestinationCard`…) and **transport** — join the **same module**, never sibling modules, so no cross-edition cycle can form. Cluster membership is expressed via **DocC topics + naming** (Flight / Stay / Transport), never folders — folders stay flat atomic-layer per ADR-F7.

**OQ-1 decision:** `ThemeKitTravel` over `ThemeKitFlight`. Rationale confirmed with the user: the repo already ships a large hotel/stay surface (Travel suite PR #179, the `Hotel*` demo screens, `RoomCard`/`DestinationCard`) plus a multi-modal `TransportCrossSellCard` — a flight-scoped name would orphan all of them; and the roadmap's settled name holds. The architect's cycle-dissolution argument ("scope the vertical into one module") applies to `ThemeKitTravel` identically, so nothing about the packaging, provider, state, or build-plan ADRs changes — only the container name and the addition of a cluster convention. **Flight ships first** because it is the most complete cluster today.

### What Phase A puts in the module (beyond the 12 components)

- `FlightDefaults` environment group (§3).
- The **new** domain models that don't yet exist (`Airport`, `CabinClass`, `PassengerDraft`, `PaymentMethodOption`, `SavedCard`, `TransportMode`, `FlightStatusInfo`, `TripSearchDraft`, `DialCode`) — new types have no compatibility constraint, so they are born in the edition (§4).
- Demo/gallery hooks: the Demo app links `ThemeKitTravel` and the catalog gains a "Flight booking" section; every new component registers an `-openDemo` deep-link name.
- Docs plumbing: a third DocC run is **not** needed in Phase A if the module stays small — but `tools/gen_skill.py` (which generates `llms.txt` + `llms-components.txt` and the skill component reference) must learn the second components module, else the published counts (205/34/217/22) silently go stale. Budget this in the first PR.

### Rejected alternatives

- **Land the 12 new components in `ThemeKit` and extract everything at 2.0.** Rejected: grows the exact neutral-base surface #229 complained about, doubles the 2.0 migration blast radius, and wastes the commissioned module. New code has no compatibility debt — don't create it.
- **Move existing flight components now with deprecate-and-forward.** Rejected: the settled rule says deprecations land only in the last 1.x *after* the module exists, and typealias-forwarding across modules can't preserve extension-member call sites cleanly (`FlightListItemStyle where Self ==` accessors, environment keys). 2.0 batch is the honest cut.
- **A `ThemeKitTravel` trait.** Rejected per the settled no-traits-for-editions rule above.
- **`@_exported import ThemeKit` inside the edition** (so consumers write one import). Rejected: hides the dependency, re-creates the umbrella problem in reverse, and diverges from the `ThemeKitCalendar`/`ThemeKitLottie` precedent (both require explicit imports).

---

## 3. ADR-F2 — Provider & global defaults

### Decision

Two environment groups, both modeled *exactly* on `ComponentDefaults` (optional fields, `transformEnvironment` non-nil merge, explicit per-call modifier always wins), at two altitudes:

1. **`FormatDefaults` — lives in neutral `ThemeKit`** (sibling of `ComponentDefaults.swift`). Carries the app-wide **currency code** default. Currency is not a flight concept — `PriceTag`, `RoomCard`, `DestinationCard`, `MapCallout`, `PriceBreakdown` all carry the same `"TRY"` literal — so the fix belongs in the base, and the Flight edition simply benefits.
2. **`FlightDefaults` — lives in `ThemeKitTravel`.** Carries flight-family presentation defaults: accent, the default airline SF Symbol, and time/date format styles for schedule-dense components.

```swift
// Sources/ThemeKit/FormatDefaults.swift  (new, neutral)
public struct FormatDefaults: Equatable {
    /// ISO-4217 code price components use when a call site doesn't pass one.
    public var currencyCode: String?
    public init(currencyCode: String? = nil) { self.currencyCode = currencyCode }
}

public extension EnvironmentValues { var formatDefaults: FormatDefaults { get set } }

public extension View {
    /// House formatting defaults for this subtree. Per-call arguments still win.
    func formatDefaults(currencyCode: String? = nil) -> some View {
        transformEnvironment(\.formatDefaults) { d in
            if let currencyCode { d.currencyCode = currencyCode }
        }
    }
}
```

```swift
// Sources/ThemeKitTravel/FlightDefaults.swift  (new, edition)
public struct FlightDefaults: Equatable {
    /// Accent for flight components (falls back to componentDefaults.accent, then each
    /// component's own default — usually the hero foreground token).
    public var accent: SemanticColor?
    /// SF Symbol used where no airline logo slot is provided (today hardcoded
    /// per-component as "airplane.circle.fill").
    public var airlineSymbol: String?
    /// Time/date formats for schedule-dense flight components (FlightTracker,
    /// TripSearchCard summaries). Date.FormatStyle is Codable & Hashable → Equatable OK.
    public var timeFormat: Date.FormatStyle?
    public var dateFormat: Date.FormatStyle?
    public init(accent: SemanticColor? = nil, airlineSymbol: String? = nil,
                timeFormat: Date.FormatStyle? = nil, dateFormat: Date.FormatStyle? = nil) { … }
}

public extension View {
    func flightDefaults(accent: SemanticColor? = nil,
                        airlineSymbol: String? = nil,
                        timeFormat: Date.FormatStyle? = nil,
                        dateFormat: Date.FormatStyle? = nil) -> some View {
        transformEnvironment(\.flightDefaults) { d in /* merge non-nil */ }
    }
}
```

### Resolution order (documented as the one law, per axis)

```
explicit per-call modifier argument
  > FlightDefaults (flight components only)
    > ComponentDefaults / FormatDefaults (library-wide)
      > environment natives (\.locale for formatting, Locale.currency for money)
        > the component's own constant
```

Concretely for **currency** (the drift fix, details §10):

```
price(_:currencyCode:) explicit  >  \.formatDefaults.currencyCode
  >  locale.currency?.identifier (the env \.locale, so injected locales work)
    >  "USD" (library terminal fallback — one constant, one place)
```

Concretely for **accent** on a flight component: `.accent(_:)` modifier > `flightDefaults.accent` > `componentDefaults.accent` > component default. **Locale is NOT duplicated** into either defaults group — SwiftUI's `\.locale` is already the subtree-scoped locale provider and the flight styles already capture it into their configurations (`FlightListItemConfiguration.locale`); adding a second locale channel would create two sources of truth.

The DocC "provider recipe" (HEROUI plan T1) gains two lines:

```swift
RootView()
    .themeKit()
    .componentDefaults(radius: .field, accent: .turquoise)
    .formatDefaults(currencyCode: "EUR")
    .flightDefaults(airlineSymbol: "airplane.circle", timeFormat: .dateTime.hour().minute())
    .fieldDefaults(size: .large)          // HEROUI unit 5
    .feedbackDefaults(toastPosition: .top) // HEROUI unit 6
```

### Rejected alternatives

- **Growing `ComponentDefaults` with `currencyCode`.** Rejected: HEROUI ADR-1 deliberately keeps `ComponentDefaults` as the *chrome* umbrella (radius/elevation/accent); currency is content formatting, a different axis with a different fallback chain (locale-derived). Two small structs beat one junk drawer.
- **A `FlightProvider { }` wrapper view.** Rejected for the same reasons HeroUI's provider was rejected in ADR-1: un-SwiftUI, fights subtree composition; the environment *is* the provider.
- **Airport/airline data providers in `FlightDefaults`** (e.g. `suggest: (String) -> [Airport]`). Rejected: closures in an `Equatable` env struct break equality and smuggle *data flow* into a *defaults* channel. Data enters through init/modifier parameters per house rule 1 (see AirportPicker, §9.4).
- **Currency on `Theme`.** Rejected: couples the token engine to content concerns; violates the Core/catalog split shipped in #231.

---

## 4. ADR-F3 — Canonical domain model layer

### Decision

**One models file per domain cluster, models never declared inside a component file again**, and the reference repo's `Pick<Flight, …>` discipline mapped to Swift as a documented authoring rule.

#### 4.1 File moves (Phase A, non-breaking — same module, different file)

| Model | Today | Phase A home |
|---|---|---|
| `FlightLeg` | inside `FlightCard.swift:19` | `Sources/ThemeKit/Components/Organisms/FlightModels.swift` (new) |
| `FlightFare` | inside `FlightListItem.swift:28` | `FlightModels.swift` |
| `FareLine` | inside `FareSummary.swift:15` | `FlightModels.swift` |
| `FareFeature`/`FareFeatureStatus` | inside `FareFeatureRow.swift` | `FlightModels.swift` |
| `FlightStatus` | inside `FlightStatusBadge.swift` | `FlightModels.swift` |
| `QuickFilter` | inside `FilterBar.swift:19` | stays (generic, not flight) |
| Seat family | `SeatMapModels.swift` | stays (already the pattern) |

Moving a public type between files **in the same module** is invisible to consumers and to the api-breakage gate — do it now so the 2.0 extraction moves *files*, not declarations. At 2.0, `FlightModels.swift` + `SeatMapModels.swift` move to `Sources/ThemeKitTravel/Models/` wholesale.

#### 4.2 New models (born in `ThemeKitTravel/Models/`)

All value types, `Sendable`, `Equatable`, `Codable` where they represent persistable domain data (matching `FlightLeg`/`Seat`/`GuestSelection` precedent), with content-derived `Identifiable` ids where stable identity exists (matching `FlightLeg.id`/`FlightFare.id` precedent — no per-init `UUID()`):

```swift
/// FlightSearchModels.swift
public struct Airport: Identifiable, Sendable, Hashable, Codable {
    public var id: String { code }
    public let code: String          // IATA, e.g. "IST"
    public let name: String          // "Istanbul Airport"
    public let city: String
    public let countryCode: String?  // ISO 3166-1 alpha-2; display name via Locale
    public init(code: String, name: String, city: String, countryCode: String? = nil)
}

public enum CabinClass: String, CaseIterable, Sendable, Codable {
    case economy, premiumEconomy, business, first
    public var label: String   // String(themeKit:) — localized, English-only source
    public var glyph: String   // SF Symbol: "chair" / "chair.lounge" / "briefcase" / "crown"
}

public enum TripType: String, CaseIterable, Sendable, Codable { case oneWay, roundTrip, multiCity }

public struct PassengerCount: Sendable, Equatable, Codable {
    public var adults: Int; public var children: Int; public var infants: Int
    public init(adults: Int = 1, children: Int = 0, infants: Int = 0)  // clamped ≥ 0, adults ≥ 1
    public var total: Int
}

public struct TripSearchDraft: Sendable, Equatable {
    public var tripType: TripType = .roundTrip
    public var origin: Airport?
    public var destination: Airport?
    public var departureDate: Date?
    public var returnDate: Date?          // meaningful only for .roundTrip
    public var passengers: PassengerCount = .init()
    public var cabin: CabinClass = .economy
    public init()
    public mutating func swapRoute()      // origin ⇄ destination
}

/// PassengerModels.swift
public enum PassengerGender: String, CaseIterable, Sendable, Codable { case female, male, unspecified }

public struct PassengerDraft: Sendable, Equatable, Codable {
    public var givenName = "", familyName = ""
    public var gender: PassengerGender?
    public var dateOfBirth: Date?
    public var nationality: String?       // ISO region code; names via Locale
    public var documentNumber = ""        // passport / national ID
    public var documentExpiry: Date?
    public init()
}

/// PaymentModels.swift
public struct PaymentMethodOption: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable, Codable { case card, wallet, transfer }
    public let id: String
    public let kind: Kind
    public let title: String
    public var subtitle: String?
    public var systemImage: String        // defaulted per kind: creditcard / wallet.pass / building.columns
    public init(id: String, kind: Kind, title: String, subtitle: String? = nil, systemImage: String? = nil)
}

public struct SavedCard: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let brand: CardBrand           // REUSED from PaymentCardField.swift (already public)
    public let last4: String
    public var holder: String?
    public var expiryMonth: Int?          // 1…12; formatted by the component with the env locale
    public var expiryYear: Int?
    public init(…)
    public func isExpired(asOf date: Date = .now, calendar: Calendar = .current) -> Bool
}

/// FlightStatusModels.swift
public struct FlightStatusInfo: Sendable, Equatable {
    public var leg: FlightLeg             // REUSED — the canonical leg
    public var status: FlightStatus       // REUSED 7-case atom enum
    public var gate: String?; public var terminal: String?
    public var checkInDesk: String?; public var baggageBelt: String?
    public var estimatedDeparture: Date?  // vs leg.departure (scheduled)
    public var estimatedArrival: Date?
    public var aircraft: String?
    public init(leg: FlightLeg, status: FlightStatus, …all optional…)
}

/// PhoneModels.swift  (arguably neutral — see OQ-4)
public struct DialCode: Identifiable, Sendable, Hashable, Codable {
    public var id: String { region }
    public let region: String             // ISO 3166-1 alpha-2, "GB"
    public let code: String               // "+44"
    public init(region: String, code: String)
    public var flag: String               // derived regional-indicator emoji
    public static let common: [DialCode]  // curated generic list (mirrors Currency.common precedent)
    public static func localized(for locale: Locale) -> DialCode?  // best-effort from locale.region
}
```

`TransportCrossSellCard`'s mode is a plain nested enum (no shared model needed). `CheckInFlow` reuses `Steps.Step`.

#### 4.3 The `Pick`-slice discipline, translated

The reference repo's law — `interface Flight` is the single source of truth; every component's props are `Pick<Flight, …>` — maps to three Swift rules (added to the authoring skill in Phase A):

1. **The model is the vocabulary, the configuration is the slice.** A component's R1 init takes either the canonical model (`init(legs: [FlightLeg])`, `init(_ info: FlightStatusInfo)`) or a *flat convenience slice* of it (`init(airline:from:to:departure:arrival:)` — which constructs the model internally, as `FlightListItem` already does). **Never a parallel struct that re-declares model fields under new names.**
2. **Style protocols see typed configurations, not models** — `FlightListItemConfiguration` *is* the Swift `Pick`: the component owns which model fields + captured env (locale, flags, callbacks) a style may read. New styled organisms follow suit.
3. **Which component takes which model** is a published table (DocC + skill):

| Model | Consumed by |
|---|---|
| `FlightLeg` | FlightCard, FlightResultRow, FlightListItem(+styles), FlightTracker (`FlightStatusInfo.leg`) |
| `FlightFare` | FlightListItem (`.fares`), FareFamilyCard (convenience init, OQ-5) |
| `FareLine` | FareSummary |
| `FareFeature` | FareFeatureRow, FareFamilyCard |
| `FlightStatus` | FlightStatusBadge, FlightTracker |
| Seat family | SeatCell, SeatLegend, SeatMap |
| `Airport` | AirportPicker, TripSearchCard |
| `CabinClass` | CabinClassSelector, TripSearchCard |
| `PassengerDraft` | PassengerForm |
| `PaymentMethodOption` / `SavedCard` | PaymentMethodSelector / SavedCardsList |
| `TripSearchDraft` | TripSearchCard |
| `FlightStatusInfo` | FlightTracker |
| `DialCode` | PhoneField |

### Rejected alternatives

- **A god-`Flight` struct** (literal port of `interface Flight`). Rejected: ThemeKit components are stateless and data-driven, not screen-driven; the flight family spans list/fare/seat/status concerns that never co-occur in one payload. `FlightLeg` + purpose models compose better and already exist.
- **Protocols as slices** (`FlightLegConvertible`). Rejected: protocol-witness plumbing for zero rendering benefit; value types + convenience inits are the house shape.
- **Backend-DTO alignment** (Amadeus/Duffel field names). Rejected by house rule 1 — no backend schemas; apps map their DTOs to these neutral models.

---

## 5. ADR-F4 — Controlled/uncontrolled state strategy

### Decision

Adopt the shipped `@ControllableState` (ThemeKitCore) as **the only mechanism** for dual-mode state in the edition, with the HeroUI `isX?/defaultX?/onXChange?` triple mapped as:

| HeroUI | ThemeKit convention |
|---|---|
| `isX` (controlled) | an overload / modifier taking `x: Binding<…>` |
| `defaultX` (uncontrolled seed) | `initiallyX:` parameter seeding `@ControllableState` |
| `onXChange` | **does not exist** — the `Binding` is the change channel; observers use `.onChange(of:)` at the call site (ADR-4, upheld by the sr-ios-dev review). Terminal *actions* (`.onSelect`, `.onDelete`) remain — they are commands, not change observation. |

**Two component classes, two defaults:**

- **Ornamental / self-contained state** (favorite, expanded, added, hover): **uncontrolled by default**, controlled on demand. A favorite heart that self-toggles is useful in a demo and harmless in an app.
- **Outcome-bearing selection** (seat set, payment method, passenger draft, trip draft, saved card): **controlled-first** — the app always needs the value, so the `Binding` init is R1. An uncontrolled overload is added *only when the component also carries a terminal action* that hands the value out (e.g. `PaymentMethodSelector` uncontrolled + `.onConfirm { option in … }` would be two channels — rejected; it stays controlled-first with an uncontrolled *preview convenience* only where genuinely useful). Form drafts (`PassengerForm`, `TripSearchCard`) are **controlled-only**: an uncontrolled traveler form is write-only memory.

### Adoption matrix (every stateful flight component)

| Component | State | Today | Target |
|---|---|---|---|
| `FlightListItem` | expanded (`.journey`) | hand-rolled `expandedBinding ?? @State internalExpanded` (`FlightListItem.swift:77–78, 93, 108–112`) | refactor onto `@ControllableState` (behavior-neutral, mirrors the Accordion refactor in commit `4116df6`); keep `.expanded(_ binding:)` modifier API byte-identical |
| `FlightListItem` | **favorite (new)** | — | `.favorite()` uncontrolled / `.favorite(_ binding:)` controlled (§9.7) |
| `FlightCard` / `FlightResultRow` / `FlightTicketCard` | favorite/bookmark | controlled-only `Binding<Bool>` modifiers | additive no-arg uncontrolled overloads: `.favorite()`, `.bookmark()` |
| `FareFamilyCard` | selected | already dual: `.selected(Bool)` display-only + `.selection(Binding<Bool>)` | conform naming; no change (precedent) |
| `SeatMap` | seat set | controlled-only `selection: Binding<Set<String>>` (all 4 inits) | **stays controlled-only** — outcome-bearing; add nothing |
| `AncillaryCard` | quantity / added | controlled-only `quantity(Binding<Int>)` / `added(Binding<Bool>)` | additive uncontrolled overloads `quantity(initially:range:)` / `added(initially:)` — ornamental in browse contexts |
| `PaymentMethodSelector` (new) | method id | — | controlled-first `selection: Binding<String?>` + uncontrolled `initiallySelected:` convenience |
| `SavedCardsList` (new) | card id | — | same shape as PaymentMethodSelector |
| `CabinClassSelector` (new) | cabin | — | dual init: `selection: Binding<CabinClass>` / `initiallySelected:` |
| `AirportPicker` (new) | query + chosen airport | — | selection controlled (`Binding<Airport?>`); the *query text* is internal `@State` (pure UI state), surfaced only via `.onQueryChange` |
| `PhoneField` (new) | number, dial code | — | number controlled (it's a form field); dial code dual via `@ControllableState` (uncontrolled seeds from the env locale's region) |
| `TripSearchCard` (new) | draft | — | controlled-only `draft: Binding<TripSearchDraft>` |
| `PassengerForm` (new) | draft | — | controlled-only `draft: Binding<PassengerDraft>` |
| `CheckInFlow` (new) | step index | — | dual: `selection: Binding<Int>` / uncontrolled with `initiallyAt:` |
| `LanguageSwitcher` (new) | language code | — | controlled-only (an uncontrolled language switcher is a lie — it must drive the app) |

**One mechanical note for `sr-ios-dev`:** for state introduced *by a modifier* rather than an init (`FlightListItem.favorite()`), `@ControllableState`'s uncontrolled seed can't be re-seeded from the copy-on-write modifier (the wrapper is initialized with the struct). The pattern is the one `FlightListItem` uses for expansion today, upgraded: declare `@ControllableState private var favorite = false` at the struct level plus a `favoriteBinding: Binding<Bool>?` var set by the controlled modifier; resolve `favoriteBinding` first. Alternatively store the wrapper with a nil external and have the modifier flip a `showsFavorite` flag + optional seed resolved as `internalValue ?? seed`. Pressure-test both; the plan sketches the first (§9.7).

### Rejected alternatives

- `onFavoriteChange`-style callback pairs — ADR-4's rejection stands; two sources of truth.
- Making `SeatMap`/forms dual-mode for symmetry — uncontrolled outcome state is unusable and would push people toward polling hacks.

---

## 6. ADR-F5 — Style-protocol & variant strategy

### Decision — a published decision ladder

The library has four shell strategies in production. The edition codifies **when each applies** (this table goes into the authoring skill):

| Strategy | Use when | Existing precedent | New components assigned |
|---|---|---|---|
| **Full `…Style` protocol** (Configuration + `Any…` erasure + env key + `where Self ==` accessors) | ≥ 3 shipped archetypes whose **anatomy** (layout skeleton) differs, set once for a whole list/screen | `FlightListItemStyle` (9), CardStyle, BarStyle, FieldStyle… | **none of the 12 at launch** (see rule below) |
| **Enum variant** (`.variant(_:)` copy-on-write modifier, private `switch` on small layout deltas) | 2–3 looks sharing one anatomy; per-instance choice | `FlightRouteTrack` .path/.inline, `SegmentedSelectionStyle`, `FilterChipStyle` | PaymentMethodSelector `.list/.grid`; CabinClassSelector `.segmented/.chips/.list`; TransportCrossSellCard `.ribbon/.inline`; LanguageSwitcher `.menu/.list/.inline`; AirportPicker `.inline/.sheet` presentation |
| **CardStyle delegation** (shell drawn by the active `\.cardStyle` via `CardStyleConfiguration`, or `cardChrome` once HEROUI unit 12 lands) | card-shaped organism whose shell should re-skin with the app's card language | FlightCard (`FlightCard.swift:98–109`) | TripSearchCard, FlightTracker, SavedCardsList rows-in-card |
| **Style-exempt** (bespoke decorative or structural chrome; no protocol, no variant) | perforation/notch chrome or pure structure where re-skinning is meaningless | TicketStub, BoardingPass | PassengerForm, CheckInFlow, PhoneField (inherits **FieldStyle** through TextInput — exempt *itself*, styled *transitively*) |

**Promotion rule (anti-sprawl):** a component starts at the *lowest* rung that fits and may only be promoted to a full Style protocol after **three shipped archetypes with distinct anatomy** exist as demand (audit-verified, like FlightListItem's did). Never speculatively.

**FlightListItem containment rule:** the 9 presets are the ceiling, not a floor. A proposal for a 10th style must show (a) a distinct layout *skeleton* — token/color/spacing deltas are configuration knobs or a custom consumer style, not a preset; (b) an industry archetype not expressible by composing existing presets per-row (the component already supports mixed archetypes in one list by design — `FlightListItem.swift:17–20`). New data needs (like favorite, §9.7) enter through **additive `FlightListItemConfiguration` fields** (safe: public lets, internal init) that every style may *optionally* render — never through new presets.

**Naming uniformity (ADR-3 triad):** every new component uses `.accent(_ c: SemanticColor)` for color (flight components use `accent`, not `color` — matching the 15 existing flight/booking components), `.variant(_:)` for the layout enum, and native `.controlSize`/`.disabled` where applicable; sizes only via ramp enums (`FilterBarSize` precedent), never CGFloat knobs.

### Variant matrix for the new set

| Component | color | variant | size | shell |
|---|---|---|---|---|
| PhoneField | via FieldStyle env | — | `TextInputSize` via FieldDefaults | FieldStyle (transitive) |
| PassengerForm | `.accent` | — | — | exempt (Fieldset structure) |
| PaymentMethodSelector | `.accent` | `.list` (default) / `.grid` | — | rows: ListRow-like; container: none |
| AirportPicker | `.accent` | `.inline` / `.sheet` | — | field row = FieldButton; list = plain |
| CabinClassSelector | `.accent` | `.segmented` (default) / `.chips` / `.list` | via SegmentedControl `.size` passthrough | delegated to SegmentedControl/Chip |
| TripSearchCard | `.accent` | `.card` (default) / `.hero` / `.compact` | — | CardStyle delegation |
| TransportCrossSellCard | `.accent` (mode-tinted default) | `.ribbon` (default) / `.inline` | — | exempt (notched ribbon is decorative, TicketStub-class) |
| FlightTracker | `.accent` | — | — | CardStyle delegation |
| SavedCardsList | `.accent` | — | — | rows in CardStyle container |
| CheckInFlow | `.accent` | — | — | exempt (scaffold) |
| LanguageSwitcher | `.accent` | `.menu` (default) / `.list` / `.inline` | — | delegated (Dropdown / rows / SegmentedControl) |

---

## 7. ADR-F6 — Validation layer

**Question:** introduce a form-schema abstraction (zod-analog) vs modifier-level `.onValidate`?

### Decision: **neither new thing.** `FormValidator` + `ValidationRule` *is* the schema; the edition standardizes on it and ships domain rule-packs.

zod plays two roles in the reference repo: (1) *type inference* — `z.infer<typeof schema>` derives the form's TypeScript type; (2) *rule declaration*. In Swift, role (1) is fulfilled by the typed draft struct itself — `PassengerDraft` **is** the inferred type, checked by the compiler; deriving types from a runtime schema is a dynamic-language workaround Swift doesn't need. Role (2) is exactly `FormValidator<Field>`'s `KeyValuePairs<Field, [ValidationRule]>` init — rules-per-field, dominant-kind messages, first-invalid focus, already `@MainActor @Observable`. Inventing a parallel schema DSL would fork the form brain the HEROUI plan (T8, units 13a/13b) is currently *unifying*, and a `ThemeForm { }` result-builder was already rejected there for dragging app-state shape into the library (house rule 1).

A per-component `.onValidate` closure modifier is also rejected: it decentralizes validation back into per-field plumbing (the disease T8 cures) and duplicates the existing `ValidationRule`/`.onValidation` field-level machinery TextInput already has.

**What the edition ships instead:**

1. **Domain rule-packs** — static `ValidationRule` conveniences in `ThemeKitTravel`: `.documentNumber` (alphanumeric, length window), `.expiryInFuture(after:)`, `.adultDateOfBirth(asOf:)`, `.phoneNumber(minDigits:)`, `.required` reuse. Pure additions to the existing vocabulary.
2. **`PassengerForm.validator(_:)`** — the form composes T8's `.field(_:in:)` wiring internally (§9.2): one modifier hands the whole `FormValidator<PassengerFormField>` in, and every inner field self-wires (messages + focus + live re-validate after failed submit). Submission stays app-side: `form.submit(values) { proceed() }` (T8's convenience).
3. **Non-string fields** (gender select, DOB, expiry) validate through the same validator by convention: the form serializes them to canonical strings (ISO-8601 dates, raw enum values) for `validateAll` — documented so apps' `values` dictionaries match. If sr-ios-dev finds this too stringly in practice, the fallback is a small `FormValidator` overload `validate(_ field:, date: Date?)` — flagged OQ-3, not designed here.

**Dependency note:** `PassengerForm`'s deep wiring wants HEROUI units 13a (externalFocus across the field family) + 13b (`.field(_:in:)`). PassengerForm Phase 1 ships with the *existing* per-field APIs (`infoMessages` + `externalFocus` on TextInput; messages-only on DateField/SelectBox) and upgrades transparently when 13a/13b land — the `.validator(_:)` surface doesn't change. This de-risks sequencing (§12).

---

## 8. ADR-F7 — Folder layout

**Question:** feature-folder module (reference repo style: `flight-card/` with co-located stories) vs the library's atomic-layer folders?

### Decision: **atomic layers, same as the mothership.**

```
Sources/ThemeKitTravel/
├── FlightDefaults.swift
├── Models/
│   ├── FlightSearchModels.swift      // Airport, CabinClass, TripType, PassengerCount, TripSearchDraft
│   ├── PassengerModels.swift         // PassengerDraft, PassengerGender, DialCode
│   ├── PaymentModels.swift           // PaymentMethodOption, SavedCard
│   └── FlightStatusModels.swift      // FlightStatusInfo
├── Components/
│   ├── Atoms/                        // (Phase B: FlightStatusBadge, FareFeatureRow, SeatCell)
│   ├── Molecules/                    // PhoneField, CabinClassSelector, LanguageSwitcher*  (*see 9.12)
│   └── Organisms/                    // PassengerForm, PaymentMethodSelector, AirportPicker,
│                                     //   TripSearchCard, TransportCrossSellCard, FlightTracker,
│                                     //   SavedCardsList, CheckInFlow
└── Documentation.docc/               // "Flight booking flow" articles, model table (§4.3)
```

Rationale, in force order:

1. **Tooling is layer-shaped.** `tools/gen_skill.py` (generates `llms.txt`/`llms-components.txt`/skill references), the snapshot/a11y/RTL harness, the Demo catalog, and the website gallery sync all walk `Components/{Atoms,Molecules,Organisms}`. Feature folders mean forking every tool for one module.
2. **The house decomposition rule is atomic** (skill: atom → molecule → organism, sub-views private in-file, models in `<X>Models.swift`). One repo, one mental model; a contributor moving between `ThemeKit` and `ThemeKitTravel` should not context-switch conventions.
3. **What feature folders actually buy — co-located flows and discoverability — is delivered by other channels ThemeKit already has:** DocC topic groups ("The booking flow: TripSearchCard → FlightListItem → FareFamilyCard → SeatMap → PassengerForm → PaymentMethodSelector → BoardingPass"), the Demo app's Flight section ordered as a flow, and the Showcase hero. Stories co-location maps to the existing `#Preview`-in-file + snapshot-test-per-component convention, which is already co-located.

One concession to the feature view: **`Models/` is a top-level sibling of `Components/`**, not scattered per-component — the model layer is the edition's real spine (ADR-F3) and deserves the visibility.

---

## 9. Full API design — the 12 gap components

Shared contract for everything below (from the authoring skill, restated once): R1 designated init takes **content/data/bindings/actions only**; every appearance knob is a copy-on-write chainable modifier through one private `copy(_:)`; all colors/spacing/radius/type via tokens (`SemanticColor`, `Theme.BackgroundColorKey`, `Theme.RadiusRole`, `Theme.SpacingKey`, `.textStyle`); numeric setters clamp; disabled via native `.disabled` (+ the 0.5-opacity treatment FlightListItem uses); every component ships a `#Preview` covering all variants + a Demo entry verified by `xcrun simctl launch <bundle> -startTab 0 -openDemo "<Name>"`; strings via `String(themeKit:)`, English-only.

### 9.1 PhoneField (P0) — molecule

**What:** an international phone input — leading country dial-code selector + national-number field, presented as *one* field to the FieldStyle system. The HeroUI analog is an input-group prefix; ThemeKit's is `TextInput.addons(before:)`.

**Composes:** `TextInput` (the entire field body — inherits FieldStyle, FieldDefaults size, `infoMessages`, `externalFocus`, keyboard `.numberPad` via `TextInputKeyboard`) + a leading dial-code `FieldButton`-like trigger inside `addons(before:)` + a picker surface (Dropdown on macOS/regular, BottomSheet list on compact — matching the AirportPicker presentation split).

```swift
public struct PhoneField: View {
    /// R1 — label + national-number binding. Dial code self-manages, seeded from
    /// the environment locale's region (uncontrolled).
    public init(_ label: String, number: Binding<String>)
    /// Controlled dial code — the caller owns region/prefix state.
    public init(_ label: String, number: Binding<String>, dialCode: Binding<DialCode>)
}

public extension PhoneField {
    /// The selectable dial codes (default: DialCode.common). Order preserved.
    func dialCodes(_ list: [DialCode]) -> Self
    /// Placeholder for the national-number portion (default localized "Phone number").
    func placeholder(_ text: String) -> Self
    /// Searchable picker list (default true when list.count > 8).
    func searchablePicker(_ on: Bool = true) -> Self
    /// Groups digits as you type using the existing TextInputFormatter machinery.
    func formatsNumber(_ on: Bool = true) -> Self
    /// Pass-throughs to the underlying TextInput (same names, same semantics):
    func infoMessages(_ messages: [InfoMessage]) -> Self
    func externalFocus(_ binding: Binding<Bool>) -> Self
    func required(_ on: Bool = true) -> Self
    func a11yID(_ id: String?) -> Self
}
```

**Call sites:**

```swift
// Simple — dial code inferred from locale, self-managed:
PhoneField("Phone", number: $phone)

// Booking contact form — controlled, validated, wired into the form brain:
PhoneField("Contact phone", number: $draft.phone, dialCode: $draft.dialCode)
    .dialCodes(DialCode.common)
    .infoMessages(form.messages(for: .phone))
    .externalFocus(form.focusBinding(.phone))
```

**State:** number controlled (form field); dial code `@ControllableState<DialCode>` dual-mode. **Style:** FieldStyle transitively; no variant. **RTL:** the dial-code addon is `leading` (RTL-safe by name); digits render LTR inside via `Text` default Unicode behavior — verify with the RTL harness. **A11y:** one combined element "Phone, +44, field"; the code trigger gets `.accessibilityLabel("Country code, +44")`.

**Risk:** `TextInput.addons(before:)` must accept an *interactive* view (button opening a popover/sheet) — verify the addon slot doesn't swallow hit-testing; if it does, PhoneField composes an HStack of trigger + TextInput inside a shared `fieldChrome` (HEROUI unit 12) instead. Flagged OQ-2.

### 9.2 PassengerForm (P0) — organism

**What:** the editable traveler form (name / gender / DOB / nationality / travel document) — the booking flow's biggest missing piece. Distinct from `PassengerRow` (a display row for review screens; unchanged).

**Composes:** `Fieldset` (one per section) + `TextInput` ×2 (names) + `SelectBox<PassengerGender>` + `DateField` (DOB) + `SelectBox<String>` (nationality, ISO codes displayed via `Locale`) + `TextInput` (document no) + `DateField` (document expiry). All fields inherit FieldDefaults/FieldStyle.

```swift
public enum PassengerFormField: Hashable, Sendable, CaseIterable {
    case givenName, familyName, gender, dateOfBirth, nationality, documentNumber, documentExpiry
}

public struct PassengerForm: View {
    /// R1 — title + controlled draft. Controlled-only: a traveler form the app
    /// can't read is useless (ADR-F4).
    public init(_ title: String, draft: Binding<PassengerDraft>)
}

public extension PassengerForm {
    /// Which fields render, in order (default: all). Absent fields aren't validated.
    func fields(_ list: [PassengerFormField]) -> Self
    /// Nationality options as ISO region codes (default: Locale.Region.isoRegions,
    /// sorted by localized name). Display names come from the environment locale.
    func nationalities(_ regions: [String]) -> Self
    /// Renders document number + expiry as required (adds asterisks + the rule pack).
    func documentRequired(_ on: Bool = true) -> Self
    /// Selectable DOB window (default: 120 years back … today). Clamped.
    func birthDateRange(_ range: ClosedRange<Date>) -> Self
    /// Wires every rendered field into the given validator: messages, focus and
    /// live re-validation flow through it (ADR-F6). Field keys are PassengerFormField.
    func validator(_ form: FormValidator<PassengerFormField>) -> Self
    /// Standard vocabulary:
    func accent(_ color: SemanticColor?) -> Self
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self   // replaces the title row
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self
}
```

**Call site (the whole point in one screen):**

```swift
@State private var traveler = PassengerDraft()
@State private var form = FormValidator<PassengerFormField>([
    .givenName: [.required], .familyName: [.required],
    .documentNumber: [.required, .documentNumber],
    .documentExpiry: [.expiryInFuture(after: tripDate)],
])

PassengerForm("Passenger 1 · Adult", draft: $traveler)
    .documentRequired()
    .validator(form)

PrimaryButton("Continue") {
    // REVISED (OQ-3, §1.4): form.submit is HEROUI 13b (unshipped) — use validateAll until then:
    if form.validateAll(traveler.formValues) == nil { proceed(traveler) }
}
```

(`PassengerDraft.formValues: [PassengerFormField: String]` is a small public computed serialization — the canonical-strings convention from ADR-F6.)

**State:** controlled-only. **Style:** exempt — structure, not skinnable chrome; inner fields re-skin via FieldStyle. **Multi-passenger lists** are the app's `ForEach` of `PassengerForm`s — the component stays single-traveler (decompose, don't scale up). **A11y:** the form is a labeled container (`.accessibilityElement(children: .contain)` + heading trait on the title); each field already self-labels.

### 9.3 PaymentMethodSelector (P0) — organism

**What:** choose how to pay — card / wallet / transfer rows (or tiles), with an optional inline installments picker under the card option.

**Composes:** selection rows (RadioButton-semantics rows built on the ListRow anatomy) or `SelectionCards`-like tiles; `InstallmentPicker` (existing) inline; `Badge` for per-option tags.

```swift
public struct PaymentMethodSelector: View {
    /// R1 — options + controlled selection (option id).
    public init(_ options: [PaymentMethodOption], selection: Binding<String?>)
    /// Uncontrolled convenience (browse/preview contexts); reads back only visually.
    public init(_ options: [PaymentMethodOption], initiallySelected: String? = nil)
}

public enum PaymentMethodVariant: Sendable { case list, grid }

public extension PaymentMethodSelector {
    func variant(_ v: PaymentMethodVariant) -> Self                      // default .list
    /// Installment options shown under the selected `.card` option.
    func installments(_ months: [Int], selection: Binding<Int>,
                      total: Decimal) -> Self       // REVISED (§1.4): total REQUIRED — both installment components need it
    /// Per-option badge, e.g. "No fee" on transfer.
    func badge(_ text: String?, for optionID: String) -> Self
    func disabledMethods(_ ids: Set<String>) -> Self
    func accent(_ color: SemanticColor?) -> Self
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self
}
```

**Call site:**

```swift
PaymentMethodSelector([
    .init(id: "card", kind: .card, title: "Credit / debit card"),
    .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
    .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
], selection: $method)
    .installments([1, 3, 6, 9], selection: $months, total: fareTotal)
    .badge("No fee", for: "transfer")
```

**State:** controlled-first + uncontrolled convenience (ADR-F4). Installments selection is a separate binding (separate outcome). **Style:** enum variant; rows accent via triad. **A11y:** rows are `.isButton` with `.isSelected` trait; the group announces "Payment method, 3 options". Currency in the installments math resolves via §10.

### 9.4 AirportPicker (P1) — organism

**What:** airport search & select — code + city rows, *recent / popular / nearby* sections, async-suggest **without owning async** (house rule 1: no `Task`/network in components — the caller owns lookup; the component owns debounce of the *callback*, exactly like `Autocomplete.debounce(_:)` already does).

**Composes:** `SearchBar`/`TextInput` + sectioned list (SuggestionRow-anatomy rows: bold IATA code chip + city/airport text) + `Skeleton` loading rows + `.emptyContent` slot (T2 vocabulary).

```swift
public struct AirportPicker: View {
    /// R1 — controlled selection + the current suggestion list (caller-owned).
    public init(selection: Binding<Airport?>, suggestions: [Airport])
}

public enum AirportPickerPresentation: Sendable { case inline, sheet }

public extension AirportPicker {
    /// Debounced query callback — the caller performs lookup and updates `suggestions`.
    func onQueryChange(_ action: @escaping (String) -> Void) -> Self
    func debounce(_ interval: TimeInterval) -> Self                       // default 0.25s, clamped ≥ 0
    /// Shown before/alongside typing:
    func recent(_ airports: [Airport], onClear: (() -> Void)? = nil) -> Self
    func popular(_ airports: [Airport]) -> Self
    func nearby(_ airports: [Airport]) -> Self
    /// Skeleton rows while the caller's lookup is in flight.
    func loading(_ on: Bool = true) -> Self
    func placeholder(_ text: String) -> Self                              // default "City or airport"
    func presentation(_ p: AirportPickerPresentation) -> Self             // default .inline
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self   // T2 slot
    func accent(_ color: SemanticColor?) -> Self
    func a11yID(_ id: String?) -> Self
}
```

**Call site:**

```swift
@State private var origin: Airport?
@State private var results: [Airport] = []
@State private var searching = false

AirportPicker(selection: $origin, suggestions: results)
    .onQueryChange { query in
        searching = true
        lookupTask = Task { results = await api.airports(matching: query); searching = false }
    }
    .recent(store.recentAirports, onClear: store.clearRecents)
    .popular(curated.popular)
    .loading(searching)
```

**State:** selection controlled; query internal `@State`. **Style:** presentation enum; rows are fixed anatomy (promotion rule: no Style protocol until real archetypes exist). **A11y:** rows read "IST, Istanbul Airport, Istanbul"; section headers are headings; the search field announces result count changes via `.accessibilityValue`.

### 9.5 CabinClassSelector (P1) — molecule

**What:** economy / premium economy / business / first selection, defaulting to a `SegmentedControl` wrap (the reference repo's `cabin-class-selector` is a select; ThemeKit's native answer is segmented).

```swift
public struct CabinClassSelector: View {
    public init(selection: Binding<CabinClass>)                 // controlled
    public init(initiallySelected: CabinClass = .economy)       // uncontrolled (ControllableState)
}

public enum CabinClassVariant: Sendable { case segmented, chips, list }

public extension CabinClassSelector {
    /// Subset + order (default: all four). E.g. domestic: [.economy, .business].
    func classes(_ list: [CabinClass]) -> Self
    func variant(_ v: CabinClassVariant) -> Self                // default .segmented
    func showsGlyphs(_ on: Bool = true) -> Self                 // SF Symbols per class
    func accent(_ color: SemanticColor?) -> Self                // → SegmentedControl.tinted / chip accent
}
```

**Call site:** `CabinClassSelector(selection: $draft.cabin).classes([.economy, .business]).variant(.chips)`

Maps `CabinClass` ⇄ index internally for `SegmentedControl(_ items:selection: Binding<Int>)`; `.list` renders RadioGroup-style rows for sheet contexts. Pure wrapper — zero bespoke chrome.

### 9.6 TripSearchCard (P1) — organism

**What:** the all-in-one search card at the top of every flight app: trip type, origin/destination with swap, dates, passengers, cabin, CTA. **This is the "extend" item:** it extends the *existing molecule set* (TripTypeToggle, SwapButton, DateField, GuestSelector, RecentSearchRow) into one organism rather than duplicating them.

**Composes:** `TripTypeToggle` · two field-shaped triggers (FieldButton anatomy) that open `AirportPicker` in `.sheet` presentation · `SwapButton` · `DateField` ×1–2 · a passengers trigger opening `GuestSelector(...).showsRooms(false)` in a sheet · `CabinClassSelector` · `PrimaryButton` CTA. Shell drawn by the active **CardStyle** (`CardStyleConfiguration`, exactly the `FlightCard.swift:98–109` shape).

```swift
public struct TripSearchCard: View {
    /// R1 — controlled draft + submit action (the one terminal command).
    public init(draft: Binding<TripSearchDraft>, onSearch: @escaping (TripSearchDraft) -> Void)
}

public enum TripSearchVariant: Sendable { case card, hero, compact }

public extension TripSearchCard {
    /// Data for the embedded AirportPicker sheets (same caller-owned model as §9.4).
    func airports(suggestions: [Airport], recent: [Airport] = [], popular: [Airport] = []) -> Self
    func onAirportQuery(_ action: @escaping (String) -> Void) -> Self
    /// Selectable date window (past dates excluded by default). Clamped.
    func dateRange(_ range: ClosedRange<Date>) -> Self
    func showsCabinPicker(_ on: Bool = true) -> Self
    func showsTripType(_ on: Bool = true) -> Self
    func ctaTitle(_ text: String) -> Self                          // default "Search flights"
    func variant(_ v: TripSearchVariant) -> Self                   // .card (default) / .hero / .compact
    func surface(_ key: Theme.BackgroundColorKey) -> Self          // → CardStyleConfiguration
    func elevation(_ e: CardElevation) -> Self
    func accent(_ color: SemanticColor?) -> Self
    func promo<V: View>(@ViewBuilder _ content: () -> V) -> Self   // slot under the CTA (campaign strip)
}
```

**Call site:**

```swift
@State private var draft = TripSearchDraft()

TripSearchCard(draft: $draft) { search($0) }
    .airports(suggestions: results, recent: store.recents, popular: curated.popular)
    .onAirportQuery { lookup($0) }
    .variant(.hero)
    .promo { PromoBanner("Summer sale — up to 30% off") }
```

**Behavior notes:** `.oneWay` hides the return `DateField` (animated via `MicroMotion`-gated motion); the swap button calls `draft.swapRoute()` with a `.symbolEffect` mirror-safe rotation; `.multiCity` renders origin/destination + a "Add flight" affordance in v1 *only if cheap*, else `.multiCity` is accepted in the model but renders the one-slice editor + a documented limitation (decide in PR — flagged in the unit). **Variants:** `.card` standard; `.hero` = larger type + `.bgHero`-friendly styling for landing headers; `.compact` = single collapsed summary row (SearchSummary anatomy) that expands. **Dynamic Type:** the origin/swap/destination row uses `ViewThatFits` to fall vertical at accessibility sizes.

### 9.7 FlightListItem.favorite() (P1) — extension

Additive dual-mode favorite on the flagship, matching FlightCard/FlightResultRow's existing heart semantics (44pt target, `heart/heart.fill`, error-tone fill, bounce `symbolEffect` — `FlightCard.swift:139–149`).

```swift
// FlightListItem.swift — struct gains:
//   private var favoriteBinding: Binding<Bool>?
//   private var showsFavorite = false
//   @State private var internalFavorite = false          // uncontrolled storage
// (or the ControllableState-through-modifier resolution — sr-ios-dev picks, OQ-2)

public extension FlightListItem {
    /// Self-managed favourite heart (uncontrolled).
    func favorite() -> Self { copy { $0.showsFavorite = true } }
    /// Controlled favourite — the caller owns persistence.
    func favorite(_ isFavorite: Binding<Bool>) -> Self {
        copy { $0.showsFavorite = true; $0.favoriteBinding = isFavorite }
    }
}

// FlightListItemConfiguration gains (ADDITIVE — internal init, public lets):
//   public let isFavorite: Bool?                // nil = no heart requested
//   public let toggleFavorite: (() -> Void)?    // animated toggle, mirrors toggleExpand
```

Each built-in style renders the heart in its identity/price corner **when `isFavorite != nil`**; third-party custom styles that predate the field simply don't render it (graceful degradation — no crash, no layout shift). Same additive `favorite()` overloads go on `FlightCard`/`FlightResultRow`/`FlightTicketCard` (they have controlled-only today).

### 9.8 TransportCrossSellCard (P2) — organism

**What:** "No flights? Take the bus/train" cross-sell ribbon — mode glyph, route, price-from, CTA.

```swift
public struct TransportCrossSellCard: View {
    public enum Mode: String, Sendable, CaseIterable { case bus, train, ferry, car }
    /// R1 — mode + route endpoints (display strings; cross-sell has no FlightLeg).
    public init(_ mode: Mode, from: String, to: String)
}

public enum TransportCrossSellVariant: Sendable { case ribbon, inline }

public extension TransportCrossSellCard {
    func price(_ amount: Decimal?, caption: String? = nil) -> Self   // env-resolved currency (§10)
    func price(_ amount: Decimal?, currencyCode: String, caption: String? = nil) -> Self
    func duration(_ text: String?) -> Self
    func departures(_ note: String?) -> Self                          // "Every 30 min from Esenler"
    func badge(_ text: String?) -> Self
    func onSelect(_ title: String = "See options", perform action: @escaping () -> Void) -> Self
    func variant(_ v: TransportCrossSellVariant) -> Self              // .ribbon (default) / .inline
    func accent(_ color: SemanticColor?) -> Self                      // default: mode-tinted (bus .warning, train .info, ferry .cyan, car .neutral)
    func logo<L: View>(@ViewBuilder _ content: () -> L) -> Self
}
```

`.ribbon` = full-width notched strip (TicketStub-class decorative chrome → Style-exempt; reuses the perforation drawing approach, `.flipsForRightToLeftLayoutDirection(true)` on the notch path); `.inline` = flat ListRow-anatomy row for embedding inside result lists between FlightListItems.

### 9.9 FlightTracker (P2) — organism

**What:** the live status/gate screen — status badge, route with progress, schedule vs estimate, gate/terminal/belt facts, phase timeline.

**Composes:** `FlightStatusBadge` · `FlightRoute(.path)` with a new progress treatment · `KeyValueTable` (facts grid) · `Steps` (phases: Check-in → Boarding → Departed → Arrived) — all existing.

```swift
public struct FlightTracker: View {
    public init(_ info: FlightStatusInfo)     // R1 — the canonical model (ADR-F3)
}

public extension FlightTracker {
    /// En-route progress 0…1 drawn along the route path (clamped; nil hides it).
    func progress(_ fraction: Double?) -> Self
    /// "Updated 2 min ago" caption; formatted with the env locale.
    func updated(_ date: Date?) -> Self
    /// Extra fact rows appended to the facts grid, e.g. [("Aircraft", "A321neo")].
    func details(_ pairs: [(String, String)]) -> Self
    func showsTimeline(_ on: Bool = true) -> Self
    func accent(_ color: SemanticColor?) -> Self
    func surface(_ key: Theme.BackgroundColorKey) -> Self   // → CardStyle delegation
    func elevation(_ e: CardElevation) -> Self
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self
}
```

**Call site:** `FlightTracker(info).progress(0.62).updated(lastPoll).details([("Aircraft", "A321neo")])`

Stateless by construction: the app polls/streams and re-renders with new `FlightStatusInfo` — no `Task`, no timers (house rule 1). Delay rendering: when `estimatedDeparture` differs from `leg.departure`, scheduled time renders struck-through `textTertiary`, estimate in the status tone (`FlightStatus.tone` already maps to SemanticColor). **A11y:** the header is a combined element ("SK 1123, Istanbul to London, Delayed, estimated 14:20"); status *changes* announce via `AccessibilityNotification.Announcement` gated to actual value change.

### 9.10 SavedCardsList (P2) — organism

**What:** stored payment cards — brand glyph, •••• last4, holder, expiry, expired flag; single-select; delete + add-new affordances.

```swift
public struct SavedCardsList: View {
    public init(_ cards: [SavedCard], selection: Binding<String?>)   // controlled
    public init(_ cards: [SavedCard], initiallySelected: String? = nil)
}

public extension SavedCardsList {
    func onDelete(_ action: @escaping (SavedCard) -> Void) -> Self       // swipe + context menu
    func onAddNew(_ title: String = "Add new card", perform action: @escaping () -> Void) -> Self
    func flagsExpired(_ on: Bool = true) -> Self                          // "Expired" badge + auto-disabled row
    func accent(_ color: SemanticColor?) -> Self
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self   // T2 slot (default: EmptyState)
}
```

Reuses `CardBrand` (public, from `PaymentCardField.swift:17`) for brand glyph/color; expiry renders from month/year ints with the env locale. Pairs with `PaymentMethodSelector`: apps typically render `SavedCardsList` when the `card` method is chosen. Rows carry `.isSelected` a11y traits; masked number reads "Visa card ending 4 2 4 2".

### 9.11 CheckInFlow (P2) — organism (scaffold)

**What:** a stepper *scaffold* for the check-in journey — `Steps` header + the current page + Back/Continue dock. Deliberately thin: pages are the app's content; the component owns progression chrome only.

```swift
public struct CheckInFlow<Page: View>: View {
    /// R1 — the step definitions + controlled index + per-step page builder.
    public init(steps: [Steps.Step], selection: Binding<Int>,
                @ViewBuilder page: @escaping (Int) -> Page)
    /// Uncontrolled — self-paced (ControllableState).
    public init(steps: [Steps.Step], initiallyAt index: Int = 0,
                @ViewBuilder page: @escaping (Int) -> Page)
}

public extension CheckInFlow {
    func nextTitle(_ text: String) -> Self                       // default "Continue"; last step "Done"
    func backTitle(_ text: String) -> Self                       // default "Back"
    func doneTitle(_ text: String) -> Self
    /// Gate advancing (e.g. seat not yet chosen). Continue disables when false.
    func canAdvance(_ predicate: @escaping (Int) -> Bool) -> Self
    func onComplete(_ action: @escaping () -> Void) -> Self
    func showsStepper(_ on: Bool = true) -> Self                 // hide Steps for compact hosts
    func accent(_ color: SemanticColor?) -> Self
}
```

**Call site:**

```swift
CheckInFlow(steps: [.init("Passengers", state: .active), .init("Seats", state: .todo),
                    .init("Boarding pass", state: .todo)],
            selection: $step) { index in
    switch index {
    case 0: PassengerReviewPage()
    case 1: SeatMap(sections: cabin, selection: $seats)
    default: BoardingPass(passenger: name, from: "IST", to: "LHR").qr(code)
    }
}
.canAdvance { $0 == 1 ? !seats.isEmpty : true }
.onComplete { finishCheckIn() }
```

Page transitions slide directionally (mirrored under RTL automatically by using leading/trailing edges), gated by `MicroMotion`. Step states in the `Steps` header derive from `selection` (before = `.done`, current = `.active`) — callers pass initial states only. The dock reuses `ButtonDock`.

### 9.12 LanguageSwitcher (P2) — molecule, **neutral (not Flight)**

**Placement decision:** language switching is not a flight concept — it belongs in **`Sources/ThemeKit/Components/Molecules/`** next to `CurrencyPicker`/`ThemeToggle`. It rides this initiative's train (same sprint) but lands in the neutral catalog; counting it "in the edition" would set the precedent that generic components live in domain modules — the exact pollution #229 complained about, inverted.

```swift
public struct AppLanguage: Identifiable, Sendable, Hashable {
    public var id: String { code }
    public let code: String            // BCP-47, "en", "de", "ar"
    public var name: String?           // override; default = localized display name via Locale
    public var flag: String?           // optional emoji
    public init(code: String, name: String? = nil, flag: String? = nil)
}

public struct LanguageSwitcher: View {
    public init(_ languages: [AppLanguage], selection: Binding<String>)  // controlled-only (ADR-F4)
}

public enum LanguageSwitcherVariant: Sendable { case menu, list, inline }

public extension LanguageSwitcher {
    func variant(_ v: LanguageSwitcherVariant) -> Self   // .menu (default) / .list / .inline
    func showsFlags(_ on: Bool = true) -> Self
    /// Render each language endonymically ("Deutsch", "العربية") — default true;
    /// off = exonyms in the environment locale.
    func nativeNames(_ on: Bool = true) -> Self
    func accent(_ color: SemanticColor?) -> Self
}
```

`.menu` wraps `Dropdown`; `.list` = check-marked rows for settings screens; `.inline` = `SegmentedControl` for 2–3 languages. Endonym rendering uses `Locale(identifier: code).localizedString(forIdentifier: code)`. A11y: each option reads both endonym and exonym ("Deutsch, German").

---

## 10. Currency / locale defaults — the concrete migration

**Finding (verified):** `FlightListItem.price(_:currencyCode: String = "USD", …)` vs `"TRY"` defaults on ~20 other components (`FlightCard.swift:296`, `FlightResultRow.swift:180`, `PriceTag.swift:92`, `SeatCell.swift:37`, `FareSummary.swift:58`, `StickyBookingBar.swift:127`, `AncillaryCard.swift:162`, DatePriceStrip, InstallmentSelector, PriceBreakdown, DestinationCard, RoomCard, MapCallout, PriceTrendChart, PriceHistogram…). Two different wrong answers; neither is themable or locale-aware.

### Decision — environment resolution via the proven omitted-argument overload pair

The blocker: a defaulted parameter (`currencyCode: String = "TRY"`) cannot detect omission, and changing the parameter type to `String?` changes public signatures (api-gate churn across 20 components). The repo already solved this exact problem: the sr-ios-dev review's **Q3 executable probe** proved that adding a second overload *without* the parameter resolves ambiguity-free for omitting callers, while explicit callers keep hitting the original signature. Apply it mechanically:

```swift
// Per price-bearing component (FlightCard shown; identical shape everywhere):

// 1. Storage becomes optional (private — invisible):
private var currencyCode: String?          // was: = "TRY"

// 2. NEW omitted-argument overload — environment-resolved.
//    ⚠︎ REVISED (OQ-7, §1.4): 3-param modifiers must replicate ALL params except
//    currencyCode — else `price(214, caption:)` silently binds the OLD overload:
func price(_ amount: Decimal?, caption: String? = nil) -> Self { copy { … } }   // 3-param
// (2-param price modifiers use the plain `func price(_ amount: Decimal?)`.)

// 3. EXISTING signature unchanged — explicit still wins:
func price(_ amount: Decimal?, currencyCode: String = "TRY", caption: String? = nil) -> Self { … }
//                              ^ default arg becomes unreachable for new compiles
//                                (omitting callers bind to overload 2), but the
//                                signature — and the api-gate — never changes.

// 4. Body-time resolution (environment IS readable there):
@Environment(\.formatDefaults) private var formatDefaults
@Environment(\.locale) private var locale
private var resolvedCurrency: String {
    currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
}
```

**Sweep list (one PR, mechanical):** PriceTag, SeatCell, FareSummary, FlightCard, FlightResultRow, FlightTicketCard, FlightListItem (drops its `"USD"`), StickyBookingBar, AncillaryCard, DatePriceCard/DatePriceStrip, InstallmentPicker/InstallmentSelector, PriceBreakdown, PriceHistogram, PriceTrendChart, DestinationCard, RoomCard, MapCallout, AgentPriceRow, PriceAlertCard, SeatMap (`.currency(_:)`). Components whose currency knob is a *separate* `.currency(_ code:)` modifier (SeatMap, FareFamilyCard, DatePriceStrip) need no overload — only the optional storage + resolution chain (an unset modifier already means "unspecified").

**Behavior change, called out honestly:** a call site that omitted `currencyCode:` and *relied on* silently getting TRY (or USD on FlightListItem) will, after recompiling, get `formatDefaults` → locale currency instead. This is the intended fix and is **source-compatible but render-visible**. Mitigations: (a) minor-version bump + CHANGELOG "Currency now resolves from the environment; pin with `.formatDefaults(currencyCode:)` at the root or pass explicit codes"; (b) all library `#Preview`s and snapshot fixtures pass explicit codes (most already do); snapshot runs will catch every miss because CI's locale is stable; (c) the api-breakage gate stays green (additive overloads only — same class of change the Q3 probe validated).

**Accent/locale drift** rides the same pattern: flight components' `.accent(_:)` default resolution becomes `explicit > flightDefaults.accent > componentDefaults.accent > component constant` (read-side only, no signature change); locale is already environment-sourced everywhere the flight styles format (`FlightListItemConfiguration.time/shortDate` capture `\.locale`) — the two stragglers that format with the device default (`FlightCard.timeColumn` uses bare `.formatted`, `FlightCard.swift:232`; same in FlightResultRow) get the captured-locale treatment in the same sweep.

---

## 11. Accessibility, RTL, localization & Dynamic Type architecture

House rules 6 + skill sections apply wholesale; this section adds the *edition-specific* architecture so the 12 components don't solve these one-off.

**Localization.** All new user-facing strings via `String(themeKit:)` (Core bundle — the per-target `Bundle.module` gotcha from the Core split means edition strings need **their own** catalog: `ThemeKitTravel` gets a `Localizable.xcstrings` + a `String(themeKitTravel:)` internal helper mirroring the Core one; budget in the first PR). English-only source strings, every one overridable by API parameter (labels/titles already are, per the sketches). **Names from data, never hardcoded:** nationality/country names via `Locale.localizedString(forRegionCode:)`, language endonyms via per-language `Locale` (§9.12), currency symbols via `Decimal.FormatStyle.Currency` — the components carry *codes*, the locale renders *names*.

**Formatting with the captured locale.** Every date/number render uses `.formatted(style.locale(locale))` with the environment locale (FlightListItemConfiguration precedent, `FlightListItemStyle.swift:83–88`). FlightTracker/TripSearchCard route through `FlightDefaults.timeFormat/dateFormat` when set, else `.shortened` defaults — one resolution helper, `FlightFormat.time(_:defaults:locale:)`, internal to the edition so all components speak identically.

**RTL.** By construction: HStack/VStack composition throughout; slots named `leading/trailing` never left/right. Special cases: (a) TransportCrossSellCard's notched ribbon path gets `.flipsForRightToLeftLayoutDirection(true)` (TicketStub precedent); (b) PhoneField: the dial-code addon mirrors with the field, but the *number itself* must render LTR — apply `.environment(\.layoutDirection, .leftToRight)` to the digits text only, and verify "+44" doesn't bidi-flip (RTL harness case required); (c) CheckInFlow page transitions use leading/trailing edges so "forward" mirrors; (d) FlightRoute/SwapButton already mirror — TripSearchCard's swap animation must rotate through the vertical axis (symmetric) to avoid a direction-implying spin.

**Dynamic Type.** All text via `.textStyle(_:)` (free scaling). Structural commitments: TripSearchCard's route row and PaymentMethodSelector's `.grid` fall back to vertical stacks via `ViewThatFits` at accessibility sizes; SavedCardsList/AirportPicker rows have no fixed heights (min-height only); CheckInFlow's dock relies on ButtonDock's existing behavior. No text truncation without an a11y-visible full value.

**Accessibility semantics per component** (beyond per-sketch notes): selection controls (PaymentMethodSelector, SavedCardsList, CabinClassSelector `.list`, LanguageSwitcher `.list`) expose radio-group semantics — container label + per-row `.isSelected`; forms (PassengerForm) group with `.accessibilityElement(children: .contain)` + heading traits per Fieldset title; live surfaces (FlightTracker) announce status transitions once per change; every interactive glyph ≥ 44pt (heart precedent); every new component exposes `.a11yID(_:)` where the convention exists (Autocomplete/SegmentedControl precedent). **Reduce Motion:** all introduced animation (heart bounce, search-card expand, page slides, progress plane) routes through `MicroMotion`/`Motion` gates — no raw `withAnimation` without the gate.

**Verification hooks:** the existing snapshot + a11y-audit + RTL harness (Tests + `DemoUITests/AccessibilityAuditTests.swift`) must enroll every new component — the Tests target gains the `ThemeKitTravel` dependency in the packaging PR so no component can ship un-enrolled.

---

## 12. Sequenced build plan

PR-per-unit (house rule), phases gated. Every unit lands with: `#Preview` covering all variants (light + dark/themed), Demo/Gallery entry + `-openDemo "<Name>"` verification, snapshot + a11y + RTL enrollment, and skill/llms regeneration when public surface changes. Effort tags: **low** ≤ ½ day, **medium** ~1 day, **high** 2+ days.

**Prerequisites from HEROUI_INFRA_PLAN (already sequenced there):** `ControllableState` ✅ shipped (`4116df6`); unit 2 (Backdrop) in flight on this branch — no dependency; unit 5 (FieldDefaults) and units 13a/13b (form wiring) are *soft* dependencies noted per-unit below — nothing here blocks on them.

### Phase F0 — Foundations (unblocks everything)

| # | Unit | Effort | Files | Notes / verification |
|---|---|---|---|---|
| F0.1 | **Packaging:** `ThemeKitTravel` target + product; Tests + Demo wiring; `gen_skill.py` learns the second module; edition string catalog + `String(themeKitTravel:)` | medium | `Package.swift`, `Sources/ThemeKitTravel/` skeleton, `Demo.xcodeproj`, `tools/gen_skill.py` | `swift build` all products; Demo builds; llms counts correct |
| F0.2 | **Model consolidation (neutral):** `FlightModels.swift` — move `FlightLeg`/`FlightFare`/`FareLine`/`FareFeature`(+Status)/`FlightStatus` out of component files; authoring-skill "model = vocabulary, configuration = slice" section | low | `Organisms/FlightModels.swift`, 5 component files, skill | api-gate green (same-module move); snapshots unchanged |
| F0.3 | **`FormatDefaults` env + currency sweep** (§10): overload pairs + optional storage + resolution chain across ~20 components; captured-locale fix in FlightCard/FlightResultRow time columns | high | new `FormatDefaults.swift` + ~20 component files | Q3-style overload-resolution probe repeated once; full snapshot run (catches every silent TRY reliance); CHANGELOG migration note |
| F0.4 | **Edition models + `FlightDefaults` env** (§3, §4.2) | medium | `ThemeKitTravel/Models/*`, `FlightDefaults.swift` | unit tests: PassengerCount/date clamps, `SavedCard.isExpired`, `DialCode.flag`, `TripSearchDraft.swapRoute` |

*F0.3 is the only unit with consumer-visible behavior change — land it early in a minor release so the edition's own components are born onto the final resolution chain.*

### Phase F1 — P0: the booking-completion trio

| # | Unit | Effort | Depends on | Notes |
|---|---|---|---|---|
| F1.1 | **PhoneField** | medium | F0.4 (`DialCode`) | resolve OQ-2 (interactive `addons(before:)`) first — it decides the internal shape; benefits later from HEROUI unit 5 (FieldDefaults) with zero API change |
| F1.2 | **PassengerForm** (+ domain `ValidationRule` pack) | high | F0.4, F1.1 pattern | ships against existing per-field APIs; upgrades transparently when 13a/13b land (§7); demo page exercises validator + first-invalid focus |
| F1.3 | **PaymentMethodSelector** | medium | F0.4 (`PaymentMethodOption`) | installments composes existing InstallmentPicker; currency via F0.3 chain |

*Gate F1: a Demo "Booking checkout" flow page composes PassengerForm → PaymentMethodSelector → StickyBookingBar end-to-end on simulator (`-openDemo "Checkout Flow"`), plus per-component pages.*

### Phase F2 — P1: search & results

| # | Unit | Effort | Depends on | Notes |
|---|---|---|---|---|
| F2.1 | **CabinClassSelector** | low | F0.4 (`CabinClass`) | pure SegmentedControl/Chip wrap; do first — TripSearchCard consumes it |
| F2.2 | **AirportPicker** | high | F0.4 (`Airport`) | debounce mechanics lifted from Autocomplete; `.sheet` presentation reuses BottomSheet |
| F2.3 | **TripSearchCard** | high | F2.1, F2.2 | the capstone composite; multi-city depth decided in-PR (§9.6); CardStyle delegation |
| F2.4 | **FlightListItem.favorite() + heart parity sweep** (uncontrolled overloads on FlightCard/FlightResultRow/FlightTicketCard; FlightListItem expansion refactor onto ControllableState) | medium | none | additive Configuration fields; snapshot-guard all 9 styles ×(heart on/off); behavior-neutral expansion refactor proven by existing previews |

*Gate F2: Demo "Flight search" flow — TripSearchCard → FilterBar → FlightListItem list with favorites → FareFamilyCard. This is the promo-recording surface; screenshot for the README/Pages refresh.*

### Phase F3 — P2: journey & periphery

| # | Unit | Effort | Depends on | Notes |
|---|---|---|---|---|
| F3.1 | **SavedCardsList** | medium | F0.4 (`SavedCard`) | pairs with F1.3 in the checkout demo page |
| F3.2 | **TransportCrossSellCard** | medium | F0.3 | notch chrome borrowed from TicketStub; RTL flip case in harness |
| F3.3 | **FlightTracker** | medium | F0.4 (`FlightStatusInfo`) | status-change announcement pattern documented for reuse |
| F3.4 | **CheckInFlow** | medium | F3.3 (demo composes them) | scaffold only; demo = Passengers → SeatMap → BoardingPass |
| F3.5 | **LanguageSwitcher** (neutral ThemeKit) | low | none | lands in the base catalog; updates neutral counts |

*Gate F3: full "Day of travel" demo flow (CheckInFlow → BoardingPass → FlightTracker); DocC "Flight booking flow" article with the §4.3 model table; edition announcement in CHANGELOG.*

### Phase F4 — 2.0 extraction (separate initiative, pre-scoped here)

Move the ~25–30 existing flight files + `FlightModels.swift`/`SeatMapModels.swift` into `ThemeKitTravel`; land `@available(*, deprecated, renamed:)` shims in the final 1.x; batch with the `Theme.shared @unchecked Sendable` revisit per the settled plan. **Out of scope for this plan's execution; in scope for its architecture** — everything above is shaped so F4 is `git mv` + import fixes, not redesign.

**Dependency graph (what unblocks what):** F0.1 → everything; F0.3 → all price-bearing units (F1.3, F2.3, F3.1, F3.2); F0.4 → all edition components; F2.1 + F2.2 → F2.3; HEROUI 13a/13b → PassengerForm *upgrade* only (not its shipping); HEROUI unit 12 (`cardChrome`) → nice-to-have for TripSearchCard/FlightTracker (they can use the FlightCard-style direct `CardStyleConfiguration` call meanwhile — same environment, same re-skinnability).

---

## 13. Risks & open questions

### Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | **Currency behavior change** (F0.3): omitting callers silently rendered TRY/USD; now locale-resolved | own minor release + CHANGELOG recipe (`.formatDefaults(currencyCode:)` root pin); snapshots catch every internal miss; explicit-code guidance in demo/previews |
| R2 | **Module split friction**: consumers must add a second product + import; SPM consumers on Xcode auto-picker may miss it | README + DocC "Editions" article; mirrors the shipped ThemeKitCalendar/Lottie mental model; no trait avoids the `xcodebuild ignores traits` class of bugs entirely |
| R3 | **`FlightListItemConfiguration` additive fields vs third-party custom styles**: custom styles won't render the heart until updated | acceptable by design (graceful degradation); release-notes call-out; the internal-init check (verified §1.2) guarantees no compile break |
| R4 | **Tooling drift**: gen_skill/llms counts, website gallery, snapshot harness all assume one components module | F0.1 makes tool updates a *gate*, not a follow-up; CI check that llms counts match reality already exists in the gen pipeline |
| R5 | **TripSearchCard scope creep** (multi-city, inline calendars, promo logic) | variant set frozen at `.card/.hero/.compact`; multi-city decision forced in-PR; calendar stays `DateField` (ThemeKitCalendar remains the opt-in range picker) |
| R6 | **Demo/Tests target growth** slowing CI | edition snapshots run in the same opt-in snapshot lane as today; no new lanes |
| R7 | **String catalog forking** (Core vs edition bundles) — the exact `Bundle.module` gotcha from the Core split | `String(themeKitTravel:)` helper from day one (F0.1); never `bundle: .module` raw in components |

### Open questions for sr-ios-dev — ALL RESOLVED 2026-07-10 (verdicts folded into §1.4; full report `themekittravel-pressuretest.md`)

1. **OQ-1 — Edition boundary: RESOLVED (user, 2026-07-10):** the module is **`ThemeKitTravel`** (the roadmap's settled name), not `ThemeKitFlight`. Flight is the first shipped cluster; stay + transport clusters join the same module later (no sibling-cycle), expressed via DocC topics + naming, not folders (§2, ADR-F7). No further ADR changes — container name + cluster convention only. F0.1 may name the target `ThemeKitTravel`.
2. **OQ-2 — PhoneField addon interactivity + modifier-introduced ControllableState:** (a) does `TextInput.addons(before:)` pass hit-testing through to an interactive trigger (probe with a Menu/Button addon); if not, PhoneField becomes trigger+TextInput under shared field chrome — decide before F1.1. (b) For `.favorite()`: validate the `favoriteBinding ?? @State` resolution vs a `ControllableState`-reassigned-in-`copy` approach under identity churn in a `List` (does the uncontrolled heart survive scrolling/reuse?).
3. **OQ-3 — Non-string validation ergonomics:** is the canonical-strings convention (`PassengerDraft.formValues`) acceptable in practice for DOB/expiry rules, or does `FormValidator` want a typed-value overload? Decide with a real PassengerForm demo before F1.2 freezes the rule-pack signatures.
4. **OQ-4 — `DialCode` placement:** phone entry isn't flight-specific (hotel/contact forms want it). If PhoneField itself should be neutral (`ThemeKit/Molecules`, next to PaymentCardField), only its *models* argument moves — decide before F1.1; the API is placement-independent.
5. **OQ-5 — `FareFamilyCard` ⇄ `FlightFare` convenience:** should F0.2 also add `FareFamilyCard(init(_ fare: FlightFare))` mapping perks→features, closing the model-table gap (§4.3), or is the name/price overlap coincidental? Low stakes; decide during F0.2.
6. **OQ-6 — `Date.FormatStyle` in an `Equatable` env struct (`FlightDefaults`):** confirm `Date.FormatStyle`'s `Hashable` conformance behaves under Swift 6 in `EnvironmentValues` diffing (no spurious invalidation); fallback is storing enum presets (`.shortened/.standard`) instead of raw format styles.
7. **OQ-7 — Overload-pair scale:** the Q3 probe validated one overload pair; F0.3 creates ~20. Re-run the executable ambiguity probe on the two worst signatures (`FlightListItem.price(_:currencyCode:caption:)` — 3 params, and `AncillaryCard.price(_:currencyCode:suffix:)`) before committing the sweep shape, since multi-defaulted-parameter overloads are where resolution surprises live.
