# ADR-0004 — ThemeKitTravel style census & Style-protocol promotions

- **Status:** **Proposed** (2026-07-12)
- **Date:** 2026-07-12
- **Deciders:** ThemeKit architecture (ios-architect); implementation pressure-test by sr-ios-dev
- **Context source:** full read of `Sources/ThemeKitTravel/Components/**` (29 components, branch `main`), `THEMEKITTRAVEL_ARCHITECTURE.md` §6 (ADR-F5), `docs/ADR-0001-core-kind-in-init.md`, `.claude/skills/themekit-authoring/SKILL.md`
- **Question answered:** how many styles do the ThemeKitTravel components have *today*, how many *could* they have, and which components earn a **new full Style protocol**.
- **Governing rule (ADR-F5, `THEMEKITTRAVEL_ARCHITECTURE.md:459`):** *"a component starts at the lowest rung that fits and may only be promoted to a full Style protocol after **three shipped archetypes with distinct anatomy** exist as demand (audit-verified, like FlightListItem's did). Never speculatively."* Reinforced by ADR-0001 (`docs/ADR-0001-core-kind-in-init.md:40–41`): *"3+ archetypes → neither [init enum nor variant switch]; use the style protocol."*

## Context

The edition has exactly **one** full Style protocol: `FlightListItemStyle`
(`Sources/ThemeKitTravel/Components/Organisms/FlightListItemStyle.swift`), with the
complete house anatomy — a data-rich `FlightListItemConfiguration`
(`FlightListItemStyle.swift:38`), 12 preset structs (`:12–23`), `where Self ==`
accessors (`:1264–1309`), `AnyFlightListItemStyle` erasure (`:1316`), an
`EnvironmentValues` key (`:1324–1330`) and a `.flightListItemStyle(_:)` modifier
(`:1338`). Everything else styles itself through **variant/layout enums**, through
**delegation** to the mothership's `CardStyle`/`BarStyle`/`FieldStyle`, or is a
deliberate **single look**.

Meanwhile the HeroUI flexibility sweep grew several variant enums past the sizes
ADR-F5 originally assigned (`THEMEKITTRAVEL_ARCHITECTURE.md:455` assigned
PaymentMethodSelector `.list/.grid`; it now ships four cases). This ADR is the
census that decides, adversarially, whether any of that growth has crossed the
promotion bar — and freezes the answer so the next sweep doesn't promote by drift.

### Counting rules (strict)

- A **style** is a selectable *look*: a Style-protocol preset, or a case of a
  layout-switching `.variant(_:)` / `.layout(_:)` enum.
- An **anatomy** is a layout *skeleton*. Enum cases that share row/tile builders
  count as **one** anatomy family, however many cases arrange them.
- **Knob enums are not styles**: fill emphasis (`FlightStatusEmphasis`,
  `FilterChipStyle`, `TileEmphasis`), silhouettes (`SeatShape`,
  `SeatMapModels.swift:236`), orientation (`SeatLegendOrientation`), presentation
  (`AirportPickerPresentation`), sub-area arrangement (`BoardingPass.DetailsLayout`,
  `DockLayout`, `CheckInProgressStyle`), indicators (`SelectionIndicator`,
  `PassengerAccessory`, `DeleteAffordance`), chrome toggles (`TearStyle`,
  `LayoverLineStyle`). They repaint or rearrange a detail of the *same* skeleton.
- **Delegated shells** (`CardStyle` / `BarStyle` / `FieldStyle` from ThemeKit) are
  inherited axes, not the component's own styles.

## 1. Inventory — the styles that exist today

Census base: **29 components** under `Sources/ThemeKitTravel/Components`
(2 atoms, 8 molecules, 19 organisms; `FlightModels.swift`, `SeatMapModels.swift`
and `FlightListItemStyle.swift` are support files, and
`FlightListItem` + `FlightListItemStyle` count as one component).

**Headline: 50 selectable styles today** — 12 protocol presets + 38 variant-enum
cases across 13 enum axes — on 14 styled components; the other 15 components are
single-look (most with appearance knobs and/or a delegated shell).

| # | Component | Layer | Current style surface | Looks |
|---|---|---|---|---|
| 1 | FlightListItem | Org | **Full protocol** `FlightListItemStyle` — `.compact .timeline .fareBoard .deal .ticket .journey .slices .timetable .tray .tile .hero .receipt` | **12** |
| 2 | TripSearchCard | Org | variant enum `TripSearchVariant {card, hero, compact, inlineBar}` (`TripSearchCard.swift:41`) | 4 |
| 3 | PaymentMethodSelector | Org | variant enum `PaymentMethodVariant {list, grid, carousel, compactList}` (`PaymentMethodSelector.swift:30`) | 4 |
| 4 | CabinClassSelector | Mol | variant enum `CabinClassVariant {segmented, chips, list, cards}` (`CabinClassSelector.swift:21`) | 4 |
| 5 | FlightRoute | Mol | track enum `FlightRouteTrack {path, inline, arc, dots}` (`FlightRoute.swift:19–30`) | 4 |
| 6 | TransportCrossSellCard | Org | variant enum `{ribbon, inline, tile}` (`TransportCrossSellCard.swift:32`) | 3 |
| 7 | LayoverRow | Mol | variant enum `LayoverVariant {line, pill, banner}` (`LayoverRow.swift:19`) | 3 |
| 8 | RecentSearchRow | Mol | variant enum `{plain, bordered, pill}` (`RecentSearchRow.swift:22`) | 3 |
| 9 | PassengerForm | Org | layout enum `PassengerFormLayout {stacked, flat, grouped}` (`PassengerForm.swift:50`) | 3 |
| 10 | FlightTracker | Org | variant enum `{board, compact}` (`FlightTracker.swift:41`) | 2 |
| 11 | SavedCardsList | Org | variant enum `{list, wallet}` (`SavedCardsList.swift:29`) | 2 |
| 12 | FareFamilyCard | Org | layout enum `FareFamilyLayout {stacked, column}` (`FareFamilyCard.swift:22`) | 2 |
| 13 | DatePriceStrip | Mol | layout enum `DatePriceLayout {grid(columns:), strip}` (`DatePriceStrip.swift:36`) | 2 |
| 14 | TripTypeToggle | Mol | variant enum `{pill, underline}` (`TripTypeToggle.swift:48`) | 2 |
| 15 | FlightStatusBadge | Atom | single look — `FlightStatusEmphasis {soft solid outline dot}` + size ramp are knobs | 1 |
| 16 | SeatCell | Atom | single look — `SeatShape` / `SeatSelectionEmphasis` / display are knobs | 1 |
| 17 | PassengerRow | Mol | single look — badge/seat/status/accessory knobs | 1 |
| 18 | SeatLegend | Mol | single look — `SeatLegendOrientation {rows vertical inline}` is orientation | 1 |
| 19 | AirportPicker | Org | single anatomy — `AirportPickerPresentation {inline sheet popover fullScreenCover}` is presentation; source itself pre-commits: *"Rows are fixed anatomy … no Style protocol until real archetypes exist"* (`AirportPicker.swift:21–23`) | 1 |
| 20 | AncillaryCard | Org | single look — shell delegated to `CardStyle` (`AncillaryCard.swift:14–18`) | 1 |
| 21 | BoardingPass | Org | single look — **style-exempt** (TicketStub notch chrome, `BoardingPass.swift:10–16`); `DetailsLayout {row grid}` is a cell-arrangement knob | 1 |
| 22 | CheckInFlow | Org | single look — **exempt scaffold**; `DockLayout` / `CheckInProgressStyle` are knobs | 1 |
| 23 | FareSummary | Org | single look — breakdown table with slots | 1 |
| 24 | FilterBar | Org | single anatomy — `FilterChipStyle {solid outlined ghost}` is chip fill emphasis | 1 |
| 25 | FlightCard | Org | single look — shell delegated to `CardStyle` (`FlightCard.swift:9–14`) | 1 |
| 26 | FlightResultRow | Org | single look — shell delegated to `CardStyle` (`FlightResultRow.swift:10–15`) | 1 |
| 27 | FlightTicketCard | Org | single look — **style-exempt** (TicketStub chrome, `FlightTicketCard.swift:10–16`) | 1 |
| 28 | SeatMap | Org | single anatomy — cabin layout is *data* (column patterns/sections), not style | 1 |
| 29 | StickyBookingBar | Org | single look — chrome delegated to `BarStyle` (`StickyBookingBar.swift:10–17`) | 1 |

## 2. Ceiling — how many styles each *could* plausibly carry

"Ceiling" = the maximum count of **genuinely distinct layout anatomies** with a
nameable industry archetype behind them. A bigger ceiling is *not* a mandate —
ADR-F5 promotes on shipped demand, not on plausibility.

### 2.1 The styled components

| Component | Today | Ceiling | The archetypes that would fill the gap | Verdict |
|---|---|---|---|---|
| FlightListItem | 12 | **12 (hard cap)** | The containment rule (`THEMEKITTRAVEL_ARCHITECTURE.md:461`) makes 12 a ceiling, not a floor; new needs enter as additive `Configuration` fields | **Stay** — closed |
| TripSearchCard | 4 looks / **3 anatomies** (see §3.1) | **6** | + `.pill` — floating collapsed search pill that expands (Airbnb/Skyscanner home header); + `.split` — two-pane hero for iPad/Mac landing (fields left, promo right) | **PROMOTE** (§4) |
| PaymentMethodSelector | 4 looks / **2 anatomy families** — `.list`/`.compactList` share the row family (`PaymentMethodSelector.swift:141,215`), `.grid`/`.carousel` share one `tile(_:)` builder (`:305`) | 3 | + `.sectioned` — grouped rows (cards / wallets / other) — still the row family | **Stay enum** — the bar counts anatomies, not cases; two families ≠ three anatomies. Brand-custom option looks are already served by the `optionContent` slot (`:426`) |
| CabinClassSelector | 4 | 4 | none — every case *delegates* its anatomy to an existing component (SegmentedControl / Chip / rows / cards); a style protocol here would just re-erase other components' styles | **Stay enum** (ADR-F5 assigned it exactly this, `:455`) |
| FlightRoute | 4 tracks | 5 | + `.progress` — plane-position track for live tracking (feeds FlightTracker) | **Stay enum** — the track is a sub-element swap inside one time-col → track → time-col skeleton; anatomy never changes |
| TransportCrossSellCard | 3 | 4 | + `.banner` — full-bleed promo strip | **Stay enum** — 3 anatomies exist, but the `.ribbon` identity is TicketStub notch chrome cut with `destinationOut` (`TransportCrossSellCard.swift:13–16`), the exemption class ADR-F5 `:457` names: a protocol would force custom styles to reimplement or lose the tear line. Promotion actively harms here |
| LayoverRow | 3 | 3 | — | **Stay** — 161-line molecule; protocol overhead ≫ benefit |
| RecentSearchRow | 3 | 4 | + `.card` — tile for a recents carousel | **Stay** — plain/bordered/pill share one row skeleton (chrome deltas) |
| PassengerForm | 3 | 3 | — | **Stay** — forms are the ADR-F5 exempt class (`:457`); the three layouts arrange the same field set |
| FlightTracker | 2 | **4** | + `.timeline` — phase-first vertical journey (flight-tracker apps' detail view); + `.banner` — status-tone strip for push-style surfaces | **Grow enum** (§5.1) |
| SavedCardsList | 2 | **4** | + `.stack` — overlapping pass-book stack (Apple Wallet); + `.grid` tiles | **Grow enum** (§5.2) |
| FareFamilyCard | 2 | **4** | + `.row` — horizontal comparison strip for narrow screens; + `.accordion` — collapsed expandable tier | **Grow enum** (§5.3) |
| DatePriceStrip | 2 | 3 | + a month price-calendar (Hopper heat-map) — but a month grid with its own selection model is a **sibling component** (`PriceCalendar`), not a third case of a strip | **Stay** |
| TripTypeToggle | 2 | 3 | + `.menu` — dropdown for dense headers | **Stay** — wait for demand |

### 2.2 The single-look components — honest NOs

- **Semantic-fixed atoms** (`FlightStatusBadge`, `SeatCell`): their identity *is*
  the fixed anatomy; emphasis/shape knobs already cover brand variance. Ceiling 1.
- **TicketStub-chrome organisms** (`BoardingPass`, `FlightTicketCard`): style-exempt
  by documented decision in their own headers; the perforated shell is inseparable
  from the layout. A horizontal-pass variant would be a knob-level rearrangement at
  most. Ceiling 1–2, exemption blocks promotion regardless.
- **Structure/scaffold organisms** (`CheckInFlow`, `PassengerForm`, `SeatMap`,
  `AirportPicker`, `FilterBar`): the "layout" is data- or flow-driven;
  `AirportPicker.swift:21–23` already records the no-protocol decision in source.
- **CardStyle/BarStyle delegates** (`FlightCard`, `FlightResultRow`,
  `AncillaryCard`, `FareSummary`, `StickyBookingBar`): re-skinning arrives through
  the mothership's shell protocols. Crucially, *list-item archetype* demand around
  `FlightCard`/`FlightResultRow` is already served by `FlightListItem`'s 12 presets
  (`FlightListItem.swift:17–20` exists precisely to absorb it) — a second flight-row
  style protocol would fork that surface.
- **Row/legend molecules** (`PassengerRow`, `SeatLegend`): one skeleton plus knobs.

**Ceiling headline:** across the library, honest maximum ≈ **62 looks**
(50 today + ~12 nameable new archetypes), of which this ADR proposes shipping
**4** and rejects the rest as speculative.

## 3. Decision

1. **Promote exactly one component to a full Style protocol: `TripSearchCard` →
   `TripSearchStyle`** with four parity presets (`.card .hero .compact .inlineBar`)
   and one demand-gated fifth (`.pill`). Rationale in §3.1, design in §4.
2. **Grow three variant enums by one case each** (staying enums): `FlightTracker`
   `+ .timeline`, `SavedCardsList` `+ .stack`, `FareFamilyCard` `+ .row` (§5).
3. **Everything else stays as-is.** In particular `PaymentMethodSelector`,
   `TransportCrossSellCard` and `CabinClassSelector` — the three other 3-or-4-case
   enums — are ratified **non-promotions** with the reasons recorded in §2.1, so
   future sweeps don't promote them by case-count alone.
4. **Net-new archetypes proposed: 4** (3 variant cases + 1 gated preset). The
   promotion itself is look-for-look (4 presets replacing 4 enum cases, zero new
   looks at parity).

### 3.1 Why TripSearchCard is the one that clears the bar

- **≥3 shipped, distinct anatomies.** The body dispatches three skeletons: the
  collapsed `summaryRow` (`TripSearchCard.swift:167,446`), the single-row
  `inlineRun` with a `ViewThatFits` fallback (`:207–208`), and the stacked
  `editorStack` (`:189`). These are different layout structures, not paint.
  (`.hero` is honestly *not* a fourth anatomy — it is `contentPadding .lg` +
  `.elevated` + a large CTA on the same stack (`:128–131,157`); it rides along as
  a preset only for 1:1 source mapping.)
- **Demand is real, not projected.** All four cases shipped because screens needed
  them (F2.3 capstone + flexibility sweep), and the search card is the single most
  brand-differentiated surface in travel apps — the place consumers will want an
  archetype the built-ins can't express (pill, split-pane). A protocol makes that
  a custom style instead of a fork of a 778-line organism.
- **ADR-0001 mandates it.** *"Never both a `variant` … and a giant `switch` in the
  body: 3+ archetypes use the style-protocol pattern"* (`ADR-0001:30,40–41`). The
  component is at 4 cases and growing; the enum rung no longer "fits", so the
  promotion rule's "lowest rung that fits" moves up.
- Contrast the honest NOs: PaymentMethodSelector's four cases collapse to two
  shared builder families (§2.1) — its rung still fits; TransportCrossSellCard's
  three anatomies are welded to exempt chrome.

## 4. Promotion design — `TripSearchStyle`

Maps onto the `FlightListItemStyle` reference pattern, with one deliberate
difference: FlightListItem's configuration hands styles **typed data** to lay out;
a search card's content is **live, stateful field controls** (pickers, sheets,
debounced queries). Rebuilding those per style would duplicate interaction logic
12 ways — so the configuration hands styles **pre-wired field units** (the slot
idiom, precedented by `logo`/`accessory`/`footer: AnyView?` in
`FlightListItemConfiguration`, `FlightListItemStyle.swift:46,101,103`) plus typed
signals for arrangement decisions. Styles own *arrangement and shell*; the
component keeps *all* interaction (draft bindings, sheets, debounce, submit guard).

### 4.1 Protocol + configuration (new file `Organisms/TripSearchStyle.swift`)

```swift
/// The pre-wired building blocks a ``TripSearchStyle`` arranges. Field units are
/// fully interactive (bindings, sheets, a11y fallbacks included); a style decides
/// where they go, never how they work. Nil units were switched off by modifier
/// (`.tripType(false)`, `.cabinPicker(false)`) or are empty slots.
public struct TripSearchStyleConfiguration {
    // Field units (type-erased, immediately evaluated — the SlotContent idiom).
    public let tripType: AnyView?          // TripTypeToggle, wired to the draft
    public let routeFields: AnyView        // origin + swap + destination (ViewThatFits a11y fallback inside)
    public let dateFields: AnyView         // departure (+ animated return for round trips)
    public let passengersField: AnyView    // FieldButton → GuestSelector bottom sheet
    public let cabinField: AnyView?        // CabinClassSelector section
    public let cta: AnyView                // submit button, completeness-disabled, read-only-guarded
    public let header: AnyView?            // .header { } slot
    public let promo: AnyView?             // .promo { } slot
    public let footer: AnyView?            // .footer { } slot

    // Typed signals for arrangement decisions.
    public let draft: TripSearchDraft      // read-only snapshot (routes, dates, counts)
    public let isDraftComplete: Bool
    public let isExpanded: Bool            // collapsed-summary styles read this…
    public let toggleExpand: () -> Void    // …and flip it (animated, MicroMotion-gated)
    public let accent: SemanticColor?
    public let surfaceKey: Theme.BackgroundColorKey?   // resolve via surface(default:)
    public let elevation: CardElevation?   // explicit .elevation(_:) override, or nil
    public let density: ComponentDensity
    public let locale: Locale

    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat        // density-scaled
    public func routeSummary() -> String   // "IST → LHR" / placeholder — for collapsed styles
    public func detailSummary() -> String  // "18 Jul – 25 Jul · 2 adults · Economy"
}

public protocol TripSearchStyle {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: TripSearchStyleConfiguration) -> Body
}
```

**Shell ownership:** the style draws its own shell — built-ins compose the neutral
`Card` (so `CardStyle` delegation is preserved *transitively*, exactly as today's
body does at `TripSearchCard.swift:156–158`), while custom styles may go shell-less
(a nav-header pill or inline bar must not be forced into a card). This is the same
"style owns the whole layout" stance as `FlightListItemStyle`.

### 4.2 Presets (4 at parity + 1 gated)

| Preset | Maps | Anatomy |
|---|---|---|
| `CardTripSearchStyle` (**default**) | `.card` | `Card { editor stack }`, `.md` padding, `.soft` elevation — pixel-identical to today |
| `HeroTripSearchStyle` | `.hero` | same stack, `.lg` padding, `.elevated`, large CTA |
| `CompactTripSearchStyle` | `.compact` | collapsed summary row ⇄ expanding editor via `isExpanded`/`toggleExpand` |
| `InlineBarTripSearchStyle` | `.inlineBar` | one horizontal run of the units, `ViewThatFits` fallback to the stack |
| `PillTripSearchStyle` — **gated**, ships only on audit-verified demand | — | floating capsule (`routeSummary` + glyph) that expands to the editor in an overlay/sheet; the Airbnb/Skyscanner home-header archetype `.compact` cannot express (capsule chrome, detached expansion) |

Cross-preset building blocks (the summary row, the collapse header at
`TripSearchCard.swift:478`) become shared `private` sub-views in the style file,
per the SKILL's style-driven pattern.

### 4.3 Wiring + accessors (verbatim FlightListItemStyle shape)

```swift
public extension TripSearchStyle where Self == CardTripSearchStyle {
    static var card: Self { .init() }
}
// … .hero / .compact / .inlineBar (…and .pill when gated in)

struct AnyTripSearchStyle: TripSearchStyle {                     // internal erasure
    private let _makeBody: @MainActor (TripSearchStyleConfiguration) -> AnyView
    init<S: TripSearchStyle>(_ style: sending S) { … }
    func makeBody(configuration: TripSearchStyleConfiguration) -> AnyView { … }
}

private struct TripSearchStyleKey: EnvironmentKey {
    static let defaultValue = AnyTripSearchStyle(CardTripSearchStyle())
}
extension EnvironmentValues { var tripSearchStyle: AnyTripSearchStyle { … } }

public extension View {
    /// Sets the search-card archetype for this subtree.
    func tripSearchStyle<S: TripSearchStyle>(_ style: sending S) -> some View {
        environment(\.tripSearchStyle, AnyTripSearchStyle(style))
    }
}
```

`TripSearchCard.body` becomes: build the configuration from its existing private
field builders (`editorStack`'s pieces at `:228–443` are already factored as
`tripTypeToggle` / `routeFields` / `dateFields` / `passengersTrigger` /
`cabinSection` / `cta(fullWidth:)`), then
`AnyView(style.makeBody(configuration: config))`. `@State isExpanded` and the
sheet/swap state stay in the component; styles only see `isExpanded` +
`toggleExpand`.

### 4.4 API safety & migration

- **Purely additive.** New protocol + env key + modifier; default =
  `CardTripSearchStyle` reproduces today's default exactly.
- **Deprecate-forward, never break:**
  ```swift
  @available(*, deprecated, message: "Use .tripSearchStyle(.card/.hero/.compact/.inlineBar)")
  func variant(_ v: TripSearchVariant) -> Self   // TripSearchCard.swift:562 today
  ```
  During deprecation the stored variant, when explicitly set, wins over the
  environment style (last-writer-wins at the call site is impossible to detect,
  so: explicit `.variant(_:)` maps to the matching preset internally).
  `TripSearchVariant` itself deprecates with the modifier and is removed at the
  next major.
- **Naming stays on the ADR-F5 triad** (`THEMEKITTRAVEL_ARCHITECTURE.md:463`):
  `.accent(_:)` untouched, sizes native, no CGFloat knobs enter the configuration.

### 4.5 Risks

- **AnyView field units & identity** — the SKILL's `.id` rule: the return
  `DateField` appears/disappears inside `dateFields`; keep the insert/remove
  transition by building that unit with stable identity inside the *component*
  (as today, `:319–333`) so styles inherit correct animation for free.
- **Configuration weight** — 9 erased units per render. Same order as
  FlightListItem's erased slots; fields re-erase per render already (SlotContent
  semantics), and state lives in the component/bindings, so diffing behavior is
  unchanged. sr-ios-dev should still profile the compact expand/collapse.
- **Containment** — adopt a FlightListItem-style rule at birth: **5 presets are
  the cap** (`.pill` included); new needs enter as additive configuration fields.

### 4.6 Verification hooks

- `#Preview("TripSearchStyle matrix")` iterating all presets × light/dark via
  `PreviewMatrix`, plus one custom in-preview style proving the protocol is
  implementable from outside.
- Demo: `xcrun simctl launch <bundle> -startTab 0 -openDemo "Trip Search Card"` —
  gallery gains a style switcher; screenshot at parity before/after the migration
  PR (the `.card` default must be pixel-identical).

## 5. Variant-case additions (staying enums)

Each is one case in an existing enum + one branch on shared sub-views — no new
protocol, no new axis. All are **P2, demand-tagged**: ship when a consumer screen
(Demo counts) actually needs them; delete from the backlog after two quiet quarters.

1. **`FlightTrackerVariant.timeline`** — phase-first vertical layout: the `Steps`
   phase timeline (already composed in `.board`) becomes the spine, with
   schedule/gate facts attached per phase. Distinct skeleton from both `.board`
   (facts-first card) and `.compact` (one-row strip); the flight-tracker-app
   detail archetype. Takes the enum to 3 looks / 3 anatomies — *at* the promotion
   bar; §6 records why it still stays an enum.
2. **`SavedCardsVariant.stack`** — overlapping pass-book stack of the existing
   wallet card-face tiles (Apple Wallet archetype); tap fans out to select.
   Reuses the `.wallet` tile builder; new arrangement only.
3. **`FareFamilyLayout.row`** — horizontal strip: chip + condensed features
   leading, price + select trailing; the narrow-screen fare-tier list where
   `.column` matrices don't fit. Third arrangement of the shared
   chip/features/price sub-views.

## 6. Rejected alternatives

- **Promote every 3+-case enum (PaymentMethodSelector, CabinClassSelector,
  TransportCrossSellCard, LayoverRow, RecentSearchRow, PassengerForm — and
  FlightTracker/SavedCardsList/FareFamilyCard after §5).** Rejected per component
  in §2. The general failure: case-count ≠ anatomy-count. Payment's four cases are
  two builder families; CabinClass delegates its anatomies; CrossSell's chrome is
  exemption-class; the molecules are one-skeleton; and §5's enums reach 3 looks by
  *reusing* builders — their rung still fits. Cost of over-promotion: ~6 protocols
  × (Configuration + erasure + env key + accessors + docs + demo) ≈ hundreds of
  public API points nobody asked for, each a permanent source-compat liability.
- **A generic `TravelComponentStyle` / one mega-protocol.** A style is only useful
  because its `Configuration` is *typed to the component*; a shared configuration
  degenerates into `[AnyView]` + stringly keys — render-props by another name,
  explicitly off-idiom.
- **Growing `TripSearchVariant` instead (add `.pill`, `.split` as cases).** Keeps
  the 778-line organism accreting a switch that ADR-0001 names an anti-pattern,
  and still gives consumers no custom-archetype escape short of forking. The enum
  rung demonstrably no longer fits.
- **`FlightListItemStyle`-style typed-data configuration for TripSearchStyle**
  (hand styles the raw `Binding<TripSearchDraft>` + airport datasets + callbacks).
  Every style would rebuild pickers, sheets, debounce and submit guards —
  duplicated interaction logic, divergent a11y. Field-unit slots keep behavior in
  one place; this is the deliberate delta from the reference pattern, precedented
  by the reference's own `AnyView` slots.
- **Promote `DatePriceStrip` via a `.calendar` case/preset.** A month heat-map
  calendar has its own data model (month windows, per-day availability) and
  selection semantics — that's a sibling `PriceCalendar` component (and overlaps
  the ThemeKitCalendar add-on), not a third look of a strip.

## 7. Sequenced build plan (PR-per-unit, sr-ios-dev)

| # | PR | Contents | Effort | Gate |
|---|---|---|---|---|
| 1 | `feat(travel): TripSearchStyle protocol + .card default` | New `TripSearchStyle.swift` (protocol, configuration, erasure, env key, modifier, `CardTripSearchStyle`); `TripSearchCard` renders through the env style; `.variant(_:)` maps internally; previews + parity screenshot via `-openDemo "Trip Search Card"` | **M** | `.card` pixel-parity |
| 2 | `feat(travel): hero/compact/inlineBar presets + variant deprecation` | Three presets extracted from today's branches; `@available(deprecated)` on `.variant(_:)` + `TripSearchVariant`; demo style switcher; llms/docs regen (`tools/gen_skill.py`) | **M** | all four presets verified by deep-link, RTL + a11y-size pass on `.inlineBar` fallback |
| 3 | `docs: ratify ADR-0004` | Merge this ADR; add the §2.1 non-promotion verdicts to `THEMEKITTRAVEL_ARCHITECTURE.md` §6 so the ladder table stays the single source | **S** | — |
| 4* | `feat(travel): PillTripSearchStyle` | Gated on demand evidence | **M** | demand note in PR body |
| 5* | `feat(travel): FlightTracker .timeline` | §5.1 | **S/M** | demand-tagged |
| 6* | `feat(travel): SavedCardsList .stack` | §5.2 | **S** | demand-tagged |
| 7* | `feat(travel): FareFamilyCard .row` | §5.3 | **S** | demand-tagged |

\* = demand-gated backlog, not sprint-committed.

## 8. Open questions for sr-ios-dev (pressure-test with call sites)

1. **Deprecation precedence** — when a call site has both `.variant(.hero)` and an
   ancestor `.tripSearchStyle(.compact)`, the explicit modifier should win for
   source-behavior stability. Confirm with a call-site matrix that the internal
   mapping doesn't surprise (esp. Demo screens that set both during migration).
2. **`isExpanded` semantics for non-collapsing styles** — `CompactTripSearchStyle`
   is the only consumer today; decide whether the configuration documents
   "always true unless the style collapses" or exposes a
   `supportsCollapse` hint. Prefer documentation over API.
3. **Field-unit granularity** — is `routeFields` one unit (origin+swap+destination
   welded) enough for `.split`/`.pill`, or do custom styles need
   `originField`/`swapControl`/`destinationField` separately? Start welded
   (additive to split later; splitting first can never be unsplit).
4. **§5 demand ledger** — where do "audit-verified demand" notes live so gates are
   checkable? Proposal: a `Demand:` line in the component header doc, cited in the
   PR body.
