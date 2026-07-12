# ADR-0005 — Component data intake: taxonomy, not a uniform per-component data object

- **Status:** **Accepted** (2026-07-13)
- **Date:** 2026-07-13
- **Deciders:** ThemeKit architecture (ios-architect); implementation pressure-test by sr-ios-dev
- **Context source:** full read of the four data-intake surfaces in the tree — init-scalars (`Badge.swift:125`, `HotelResultCard.swift:65`, `Coupon.swift:57`, `LineChart.swift:39/45`), copy-on-write modifiers (`HotelResultCard.swift:242–283`), Style protocol + `Configuration` (`CardStyle.swift:20–50`, ADR-0004's `FlightListItemConfiguration`), value-type Models (`SeatMapModels.swift`, `ChartModels.swift`, 9 `*Models.swift` files), catalog strings (ADR-0003), environment Defaults (`FormatDefaults.swift`); `.claude/skills/themekit-authoring/SKILL.md` rules 1–3; the "no backend DTOs / data-driven via value types & closures" standing directive
- **Question answered:** should **every** component carry one dedicated "here is all my data" object (strings + config) fed at `init`? Is such a thing necessary uniformly, and if not, what is the rule for when a component gets a dedicated data value type?
- **Relationship to prior ADRs:** builds on ADR-0001 (content-in-`init` vs. modifiers-only) and its archetype-test style; complements ADR-0003 (catalog strings) and ADR-0004 (Style `Configuration`s). No supersession.

## Context

The maintainer is weighing a uniformity mandate: give **every** one of the ~217
components a single `<Component>Data` value type — a bag of strings and config —
passed to `init`, so data intake is identical catalog-wide. The motivating
intuition is real: "I have a record; I want to splat it into the component."

ThemeKit today has **no** such uniform object. It uses a **graduated, four-mode**
intake, each mode load-bearing and already reconciled by prior ADRs:

| Mode | What it carries | Mechanism | Precedent |
|---|---|---|---|
| **M1 — `init` scalars** | required content, bindings, actions, ≤1 core-kind enum | `HotelResultCard(name:)`, `Coupon(code:label:onCopy:)`, `Badge(_:action:)`, `LineChart(_:selection:)` | ADR-0001, SKILL R1/R3 |
| **M2 — COW modifiers** | every optional config + appearance axis | `.location(_:)`, `.score(_:label:reviews:)`, `.price(_:)`, `.accent(_:)` | SKILL R2/R3 |
| **M3 — Style + `Configuration`** | appearance archetype (layout skeleton) | `.cardStyle(_:)` → `CardStyleConfiguration` | ADR-0004 |
| **M4 — value-type Models (+ provider closures)** | collection / graph / family data | `Seat`, `SeatSection`, `SeatInfo` provider; `ChartSeries`/`ChartPoint` | 9 `*Models.swift` |
| **M5 — catalog + env Defaults (cross-cutting)** | default user-facing strings; subtree format defaults | `String(themeKit:)`; `.formatDefaults(...)` | ADR-0003, `FormatDefaults` |

Crucially, **an aggregate "everything the component knows" object already exists
in the codebase — twice — but on deliberate seams:**

- **M3's `Configuration`** (`CardStyleConfiguration`, `FlightListItemConfiguration`)
  is a per-component aggregate that flows **component → style**. The component
  builds it; a `Style` consumes it. One typed snapshot is genuinely useful there
  because a `Style` has exactly one entry point (`makeBody(configuration:)`).
- **M4's Models** are per-*family* aggregates that flow **consumer → component**,
  but only for data that is a **collection or graph of records** the consumer must
  construct anyway (`SeatMapModels.swift` header: *"Value types shared by the
  seat-map family"*; `ChartModels.swift`: *"Shared value model"*).

The proposed mandate is a **third** aggregate shape — a consumer→component
`<Component>Data` bag for *every* component, including simple atoms and flat-scalar
organisms — occupying the one seam the current taxonomy deliberately leaves empty.

## Decision

**Reject the uniform mandate. Ratify the graduated four-mode taxonomy as the
canonical data-intake law, and add one testable rule for when a component earns a
dedicated value-type Model (M4).** A component gets a dedicated data object **only
when its data is a collection/graph/shared record** — never merely because it is
"data-rich," and never for strings or appearance.

### D1 — No uniform consumer→component data object

The `init` surface stays **content + bindings + actions + ≤1 core-kind enum**
(ADR-0001); every optional axis stays a **COW modifier** (SKILL R2/R3). A
mandated `<Component>Data` bag is rejected because it breaks all of the following
that the tree relies on:

- **Progressive disclosure & fluency.** `Badge("Sale").variant(.solid).size(.small)`
  and `HotelResultCard(name:).score(…).price(…)` are IDE-completable, order-free,
  and read as a sentence. A single memberwise-init bag collapses that into one
  nested-struct literal with dozens of `nil`s.
- **Additive evolution.** A new axis today is a *new modifier* — purely additive,
  source-stable forever (the reason `price(_:)` and `price(_:currencyCode:)`
  coexist, `HotelResultCard.swift:251–254`). A new field on a memberwise-init
  struct reorders/breaks the initializer — a source break on every call site.
- **Native-concept interop.** Size/disabled route through `.controlSize`/`.disabled`
  (SKILL R5). A data bag re-invents `size:`/`isEnabled:` fields, the exact
  anti-pattern ADR-0001 closed.
- **The appearance seam.** Appearance is M2/M3 (`.accent(_:)`, `.cardStyle(_:)`).
  A data bag must either (a) swallow appearance too — merging data and paint,
  violating R3 and colliding with the Style `Configuration` — or (b) exclude it,
  leaving **three** intake surfaces (bag + modifiers + style), *more* sprawl than
  today's two.
- **The directive.** A ThemeKit-owned `<Component>Data` schema **is** a fixed data
  schema — precisely the "backend DTO" the standing directive forbids. The
  graduated model *expresses* the directive: value types for collections, provider
  closures for lazy data, fluent scalars for the rest.

### D2 — The "dedicated Model" test (when M4 is warranted)

A component earns a dedicated value-type Model (an `*Models.swift` type) when **any
one** of these holds — otherwise it stays on M1 + M2:

1. **Collection/graph shape.** The component consumes a *list/grid/graph of
   repeating structured records* that cannot be flattened into modifier args —
   seat rows (`SeatSection`/`SeatSlot`/`Seat`), chart series
   (`ChartSeries`/`ChartPoint`). You cannot express "10 seats × 3 tiers × prices"
   as scalars.
2. **Shared across a component family.** The same record is consumed by an atom +
   molecule + organism, so one canonical type must exist — `Seat` is read by
   `SeatCell`, `SeatLegend`, and `SeatMap`; `ChartPoint` by every chart. The Model
   prevents three divergent shapes.
3. **The return type of a provider closure.** The data-driven directive's closure
   form needs a typed return — `seat: (id,row,col) -> SeatInfo`
   (`SeatMapModels.swift:179`). `SeatInfo` exists to *be* that return, not to
   aggregate the whole component's inputs.

**Anti-trigger — richness is not aggregation.** `HotelResultCard` has ~20 fields
and still takes none as a Model, because they are **independent optional scalars**,
each meaningful alone, each its own modifier, several re-resolving strings lazily
(`reviewsSuffix`, `HotelResultCard.swift:39`) or deprecate-forwarding
(`price` overloads). Field *count* is never the trigger; field *shape*
(collection/graph/shared record) is. Data-rich ≠ data-object.

The test is **data-shape, not component tier.** A collection-driven atom
(a chart point list) gets a Model; a 20-field organism (HotelResultCard) does not.

### D3 — Strings never live in a data object

Per ADR-0003, **default** user-facing strings are *catalog-resolved lazily at
render*, re-resolving on every body pass so a live language switch is never frozen
(`reviewsSuffix { reviewsSuffixOverride ?? String(themeKit: "reviews") }`). Therefore:

- **A data object holds only raw *content* strings that are genuinely the
  consumer's data** — a hotel name, a coupon code, a passenger's initials, a chart
  series label. These are already localized (or brand copy) by the caller.
- **It never holds labels, affordance text, or default copy** ("reviews", "Select",
  "Nonstop") — those stay M5 catalog keys with per-call overrides. Putting them in
  a hoisted-and-stored data object would **freeze** them against a live
  `.themeKitLocalized()` switch, or force the object to carry localization keys —
  reinventing the catalog ADR-0003 just built.
- **A data object never holds localization keys.** Keys are the catalog's job.

This is why a uniform data bag is actively *harmful* to strings: it invites default
copy into the stored data path, defeating restart-free switching for any consumer
who constructs the bag once outside `body`.

### D4 — The three legitimate aggregate seams (and the one that stays empty)

Name the seams so the recurring "why not one data object?" question is settled:

| Aggregate | Direction | Purpose | Status |
|---|---|---|---|
| **Model** (M4) | consumer → component | collection/graph/shared-record data | Keep; governed by D2 |
| **`Configuration`** (M3) | component → style | one typed snapshot for `makeBody` | Keep (ADR-0004) |
| **Defaults provider** (M5) | ancestor → subtree | `FormatDefaults`; per-call still wins | Keep (ADR-0003) |
| **`<Component>Data` bag** | consumer → component | "all my inputs in one struct" | **Rejected (D1)** — the one seam left deliberately empty |

The aggregate the maintainer is imagining already exists — as `Configuration` and
as Models — just on the correct sides of the seam. Adding a fourth, consumer-side
bag duplicates both and fights the fluent API.

### D5 — The real underlying need: consumer-authored adapters, not a shipped schema

The legitimate demand behind the question — *"splat my backend record into the
card"* — is met **in the consumer's app**, not by a ThemeKit schema:

```swift
// In the CONSUMER's app — maps their DTO to the fluent API. ThemeKit ships no DTO.
extension HotelResultCard {
    init(_ listing: MyHotelDTO) {           // consumer owns MyHotelDTO
        self = HotelResultCard(name: listing.name)
            .location(listing.city)
            .score(listing.rating, reviews: listing.reviewCount)
            .price(listing.priceMinor.asDecimal, currencyCode: listing.currency)
    }
}
```

This keeps ThemeKit free of any fixed schema (directive-compliant), lets the
consumer evolve their DTO independently, and still lands every value through the
same additive fluent surface. ThemeKit adds a `.content(_:)`-style adapter *only*
where a genuine collection Model already exists (M4) and demand is proven — never
as a blanket, never carrying appearance or default strings.

## Before / after — showing the line

**Data-rich organism (HotelResultCard) — stays fluent (M1 + M2):**

```swift
// Current (ratified). Progressive, additive, strings resolve lazily.
HotelResultCard(name: "Mirage Park Resort")
    .location("Kemer, Antalya")
    .score(8.9, label: "Very good", reviews: 949)
    .price(190_960, currencyCode: "TRY")
    .accent(.error)

// Rejected mandate. ~20 nested optionals; adding a field breaks the init;
// "reviews"/"Select" default copy freezes or the bag must carry catalog keys;
// where does .accent / .cardStyle go? (into the bag = merges paint with data.)
HotelResultCard(data: HotelResultCardData(
    name: "Mirage Park Resort",
    location: .init(text: "Kemer, Antalya", icon: "mappin.and.ellipse"),
    score: .init(8.9, label: "Very good", reviews: 949, reviewsSuffix: /* ?? */),
    price: .init(190_960, currency: "TRY"),
    /* …15 more optionals + appearance? */ ))
```

**Simple atom (Badge) — never a data object (M1 + M2):**

```swift
Badge("Sale").variant(.solid).size(.small)                 // current — ideal
Badge(BadgeData(text: "Sale", variant: .solid, size: .small))  // rejected — strictly worse
```

**Collection organism (SeatMap) — *keeps* its Model (M4, by D2):**

```swift
// A Model IS warranted here: a graph of records, shared across the seat family,
// fed via a provider closure returning SeatInfo. This is the directive expressed.
SeatMap(sections: [SeatSection("Business", columns: "AB CD", rows: 1...4) { id, _, _ in
    SeatInfo(available: !sold.contains(id), tier: .business, price: 1_200)
}])
```

## Consequences

- **Positive:** the graduated model is ratified with a *testable* rule (D2), so the
  recurring "why not one data object?" question is answered once, the way ADR-0001's
  archetype test answered "init or modifier?"; the fluent API, additive evolution,
  ADR-0003 live localization, and the no-DTO directive are all preserved; the three
  real aggregate seams get names.
- **No migration, zero churn:** this is a **codification, not a change** — nothing
  under `Sources/**` moves. Any refinement (D5 adapters) is purely additive and
  demand-gated. The rejected mandate, by contrast, would be a **catalog-wide
  breaking change** (every `init` rewritten, every call site churned) contradicting
  ADR-0001/0003/0004 and SKILL rules 1–3 for **negative** ergonomic value — it fails
  the additive-first bar outright.
- **Enforcement:** add D2 to the authoring SKILL as a review checklist item ("does
  this data object pass the collection/family/closure test, or is it richness
  masquerading as aggregation?"), mirroring ADR-0001's reskin-smell check. No hard
  CI gate — the test needs human judgment on data shape.

## Alternatives considered

1. **Uniform `<Component>Data` for all ~217 components.** Rejected per D1: breaks
   fluency, additivity, native interop, the appearance seam, and the no-DTO
   directive; freezes default strings; adds a redundant third intake surface.
2. **Data object for "data-rich" components only (by field count / by organism
   tier).** Rejected per D2's anti-trigger: HotelResultCard proves richness and
   tier are the wrong axis — its 20 fields are independent scalars, not a record.
   The correct axis is data *shape*, which already selects exactly the 9 Models
   that exist.
3. **Strings in a per-component data object** (raw strings or localization keys).
   Rejected per D3: freezes restart-free switching or reinvents the ADR-0003
   catalog; raw *content* strings a consumer already owns are the only strings a
   Model may carry.
4. **A universal cross-component `Data` protocol** (one shape all components read).
   Rejected for the same reason ADR-0004 rejected a universal `.travelStyle(_:)`:
   a useful data type must be *typed to the component*; a universal one degenerates
   into `[AnyView]` + stringly keys.
5. **ThemeKit ships convenience inits from common shapes** (e.g. a built-in
   `HotelResultCard(_: SomeListing)`). Rejected as a default: that `SomeListing` is
   the forbidden DTO. Allowed only as the *consumer-authored* adapter of D5, or a
   demand-gated `.content(_:)` over an existing Model.

## Open questions (for sr-ios-dev pressure-testing)

1. **D2 boundary cases** — audit any organism that takes a small fixed struct today
   that is *not* a collection (if any exist): does it pass D2 (shared/family/closure)
   or should it decompose into modifiers? Confirm the 9 `*Models.swift` types all
   pass, and that no scalar-bag has crept in under the "Models" filename.
2. **D5 adapter demand** — is there a real consumer asking to splat a record, or is
   this purely hypothetical? Gate any shipped `.content(_:)` on a concrete call-site
   request; default remains "consumer writes the extension."
3. **SKILL wording** — draft the one-paragraph D2 checklist item and the "richness ≠
   aggregation" note for `.claude/skills/themekit-authoring/SKILL.md` §"Decompose".
