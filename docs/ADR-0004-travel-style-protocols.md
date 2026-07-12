# ADR-0004 — Per-component Style protocols across ThemeKitTravel

- **Status:** **Proposed** (2026-07-12) — supersedes the v1 draft's single-promotion decision
- **Date:** 2026-07-12
- **Deciders:** user directive (explicit override) + ThemeKit architecture (ios-architect); implementation pressure-test by sr-ios-dev
- **Context source:** full read of `Sources/ThemeKitTravel/Components/**` (29 components, branch `main`), `THEMEKITTRAVEL_ARCHITECTURE.md` §6 (ADR-F5), `docs/ADR-0001-core-kind-in-init.md`, `.claude/skills/themekit-authoring/SKILL.md`
- **Question answered:** how many styles the ThemeKitTravel components have today, how many they could have, and the design for giving **every** travel component its own full Style protocol.
- **⚠ Rule override:** ADR-F5's anti-sprawl promotion rule (*"≥3 shipped distinct-anatomy archetypes, never speculatively"*, `THEMEKITTRAVEL_ARCHITECTURE.md:459`) is **intentionally overridden by explicit user request** for this initiative (same authority as the earlier full-flexibility sweep): the goal is *maximum uniform restyleability* — `FlightCard().flightCardStyle(…)`, `SeatMap(…).seatMapStyle(…)` — across the whole suite. §6's ladder remains the default law for components *born after* this initiative.

## Context

The edition has exactly **one** full Style protocol today: `FlightListItemStyle`
(`Sources/ThemeKitTravel/Components/Organisms/FlightListItemStyle.swift`) with the
complete house anatomy — a data-rich `FlightListItemConfiguration`
(`FlightListItemStyle.swift:38`), 12 preset structs (`:12–23`), `where Self ==`
accessors (`:1264–1309`), `AnyFlightListItemStyle` erasure (`:1316`), an
`EnvironmentValues` key (`:1324–1330`) and a `.flightListItemStyle(_:)` modifier
(`:1338`). Everything else styles itself through variant/layout enums, delegation
to the mothership's `CardStyle`/`BarStyle`/`FieldStyle`, or a single fixed look.

This ADR (1) records the census as ground truth, then (2) designs the promotion of
**all 28 remaining components** to the same protocol anatomy, seeding each
protocol's presets from its existing variant/layout enum cases (which
deprecate-forward) plus the ceiling archetypes identified per component.

### Counting rules (unchanged ground truth)

- A **style** is a selectable *look*: a Style-protocol preset, or a case of a
  layout-switching `.variant(_:)` / `.layout(_:)` enum.
- An **anatomy** is a layout *skeleton*; enum cases sharing row/tile builders are
  one anatomy family.
- **Knob enums** (fill emphasis, silhouettes, orientation, presentation,
  sub-area arrangement, indicators, chrome toggles) are not styles *today* —
  though this initiative deliberately promotes a handful of them
  (`FlightStatusEmphasis`, `SeatShape`, `SeatLegendOrientation`,
  `CheckInProgressStyle`, `AirportPickerDensity`) into presets where they are the
  component's only look axis, so atoms/molecules join the uniform surface.
- **Delegated shells** (`CardStyle`/`BarStyle`/`FieldStyle`) are inherited axes;
  they *compose with* (not compete with) the new per-component protocols — see §6.

## 1. Inventory — the styles that exist today

Census base: **29 components** under `Sources/ThemeKitTravel/Components`
(2 atoms, 8 molecules, 19 organisms; `FlightModels.swift`, `SeatMapModels.swift`,
`FlightListItemStyle.swift` are support files; `FlightListItem` +
`FlightListItemStyle` count as one component).

**Headline today: 50 selectable styles** — 12 protocol presets + 38 variant-enum
cases across 13 enum axes — on 14 styled components; 15 components are single-look.

| # | Component | Layer | Current style surface | Looks |
|---|---|---|---|---|
| 1 | FlightListItem | Org | **Full protocol** — `.compact .timeline .fareBoard .deal .ticket .journey .slices .timetable .tray .tile .hero .receipt` | **12** |
| 2 | TripSearchCard | Org | `TripSearchVariant {card, hero, compact, inlineBar}` (`TripSearchCard.swift:41`) | 4 |
| 3 | PaymentMethodSelector | Org | `PaymentMethodVariant {list, grid, carousel, compactList}` (`PaymentMethodSelector.swift:30`) | 4 |
| 4 | CabinClassSelector | Mol | `CabinClassVariant {segmented, chips, list, cards}` (`CabinClassSelector.swift:21`) | 4 |
| 5 | FlightRoute | Mol | `FlightRouteTrack {path, inline, arc, dots}` (`FlightRoute.swift:19–30`) | 4 |
| 6 | TransportCrossSellCard | Org | `{ribbon, inline, tile}` (`TransportCrossSellCard.swift:32`) | 3 |
| 7 | LayoverRow | Mol | `LayoverVariant {line, pill, banner}` (`LayoverRow.swift:19`) | 3 |
| 8 | RecentSearchRow | Mol | `{plain, bordered, pill}` (`RecentSearchRow.swift:22`) | 3 |
| 9 | PassengerForm | Org | `PassengerFormLayout {stacked, flat, grouped}` (`PassengerForm.swift:50`) | 3 |
| 10 | FlightTracker | Org | `{board, compact}` (`FlightTracker.swift:41`) | 2 |
| 11 | SavedCardsList | Org | `{list, wallet}` (`SavedCardsList.swift:29`) | 2 |
| 12 | FareFamilyCard | Org | `FareFamilyLayout {stacked, column}` (`FareFamilyCard.swift:22`) | 2 |
| 13 | DatePriceStrip | Mol | `DatePriceLayout {grid(columns:), strip}` (`DatePriceStrip.swift:36`) | 2 |
| 14 | TripTypeToggle | Mol | `{pill, underline}` (`TripTypeToggle.swift:48`) | 2 |
| 15–29 | FlightStatusBadge, SeatCell, PassengerRow, SeatLegend, AirportPicker, AncillaryCard, BoardingPass, CheckInFlow, FareSummary, FilterBar, FlightCard, FlightResultRow, FlightTicketCard, SeatMap, StickyBookingBar | — | single look (knob enums and/or delegated `CardStyle`/`BarStyle` shells; BoardingPass/FlightTicketCard carry the documented TicketStub chrome exemption, `BoardingPass.swift:10–16`, `FlightTicketCard.swift:10–16`) | 1 each |

## 2. Decision

**Every travel component gets its own full Style protocol** following the
`FlightListItemStyle` reference anatomy verbatim — protocol + typed
`Configuration` + `AnyXStyle` erasure + `EnvironmentValues` key + `where Self ==`
accessors + preset structs + `.xStyle(_:)` modifier.

- **29 components → 29 protocols** (28 new + `FlightListItemStyle` unchanged).
- **Presets: 109 total** across the suite — **74 existing-mapped** (the 12
  FlightListItem presets, all 38 variant-enum cases, 14 promoted knob-looks, and
  10 single-look defaults) + **35 net-new archetypes** from the ceiling analysis.
- Every existing `.variant(_:)`/`.layout(_:)`/knob modifier **deprecate-forwards**
  to the new style accessors; each protocol's default preset reproduces today's
  render pixel-for-pixel.

### 2.1 Naming law

**Protocol = component type name + `Style`, verbatim; modifier = lowerCamel of
the protocol name.** No abbreviations (`PaymentMethodSelectorStyle`, not
`PaymentStyle`): mechanical, grep-able, collision-free, and doc-generation
(`tools/gen_skill.py`) can derive it. Matches the existing precedent
(`FlightListItem` → `FlightListItemStyle` → `.flightListItemStyle(_:)`).
Implementation gate: grep ThemeKit core for name collisions before each wave
(none found in this audit; nearest neighbours `FilterChipStyle`,
`CheckInProgressStyle`, `LayoverLineStyle`, `TearStyle` are enums that remain
knobs or deprecate).

### 2.2 Two configuration classes

All 29 protocols share one anatomy but split into two configuration shapes,
depending on what the component owns:

- **Class A — typed-data configuration** (the `FlightListItemStyle` shape
  verbatim): the component owns *data*; the style lays it out. Fields are typed
  values + resolved axes (`accent`, `surfaceKey`, `density`, `locale`) + optional
  `AnyView` slots + action closures, with the same helper conventions
  (`surface(default:)`, `spacing(_:)`, accent resolvers, shared formatters —
  `FlightListItemStyle.swift:121–150`). Applies to 23 components (all cards,
  rows, badges, cells, legends, selectors over value arrays).
- **Class B — field-unit configuration**: the component owns *live interactive
  controls* (bindings, sheets, debounce, focus). Rebuilding those per style would
  duplicate interaction logic, so the configuration hands styles **pre-wired,
  type-erased field units** plus typed signals; styles arrange, never re-wire.
  (Slot precedent: `logo`/`accessory`/`footer: AnyView?` in
  `FlightListItemConfiguration`, `FlightListItemStyle.swift:46,101,103`.)
  Applies to 6 components: TripSearchCard, PassengerForm, AirportPicker,
  CheckInFlow, SeatMap, StickyBookingBar.

#### Class A exemplar — `FlightCardStyle` (new file `Organisms/FlightCardStyle.swift`)

```swift
public struct FlightCardConfiguration {
    public let airline: String
    public let legs: [FlightLeg]              // single- or multi-leg (FlightCard.swift:27)
    public let logo: AnyView?
    public let priceAmount: Decimal?
    public let currencyCode: String?          // nil → FormatDefaults chain
    public let badge: String?
    public let scarcity: Int?                 // "5 seats left"
    public let stops: Int
    public let isSelected: Bool
    public let onSelect: (() -> Void)?
    public let accent: SemanticColor?
    public let surfaceKey: Theme.BackgroundColorKey?
    public let density: ComponentDensity
    public let locale: Locale
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat
    public func time(_ date: Date) -> String  // shared locale-captured formatters
}

public protocol FlightCardStyle {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: FlightCardConfiguration) -> Body
}

public struct StandardFlightCardStyle: FlightCardStyle { … }   // today's look, verbatim
public extension FlightCardStyle where Self == StandardFlightCardStyle {
    static var standard: Self { .init() }
}
// …CondensedFlightCardStyle (.condensed), TileFlightCardStyle (.tile)

struct AnyFlightCardStyle: FlightCardStyle { … }               // internal erasure, sending init
private struct FlightCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightCardStyle(StandardFlightCardStyle())
}
extension EnvironmentValues { var flightCardStyle: AnyFlightCardStyle { … } }
public extension View {
    func flightCardStyle<S: FlightCardStyle>(_ style: sending S) -> some View {
        environment(\.flightCardStyle, AnyFlightCardStyle(style))
    }
}
```

Default presets that are card-shaped keep composing the neutral `Card`, so
`CardStyle` shell delegation (`FlightCard.swift:9–14`) is preserved
*transitively*; custom/non-card presets may go shell-less.

#### Class B exemplar — `TripSearchCardStyle` (new file `Organisms/TripSearchCardStyle.swift`)

```swift
public struct TripSearchCardConfiguration {
    // Pre-wired field units — fully interactive; styles arrange, never re-wire.
    public let tripType: AnyView?          // TripTypeToggle bound to the draft (TripSearchCard.swift:228)
    public let routeFields: AnyView        // origin + swap + destination, a11y fallback inside (:249)
    public let dateFields: AnyView         // departure (+ animated return) (:319)
    public let passengersField: AnyView    // FieldButton → GuestSelector sheet (:335)
    public let cabinField: AnyView?        // (:396)
    public let cta: AnyView                // completeness-disabled submit (:412–443)
    public let header: AnyView?; public let promo: AnyView?; public let footer: AnyView?
    // Typed signals for arrangement decisions.
    public let draft: TripSearchDraft      // read-only snapshot
    public let isDraftComplete: Bool
    public let isExpanded: Bool            // collapsed styles read…
    public let toggleExpand: () -> Void    // …and flip (MicroMotion-gated)
    public let accent: SemanticColor?
    public let surfaceKey: Theme.BackgroundColorKey?
    public let elevation: CardElevation?
    public let density: ComponentDensity
    public let locale: Locale
    public func routeSummary() -> String   // "IST → LHR" (for collapsed/pill styles)
    public func detailSummary() -> String  // "18 Jul – 25 Jul · 2 adults · Economy"
    public func surface(default: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat
}

public protocol TripSearchCardStyle {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: TripSearchCardConfiguration) -> Body
}
// CardTripSearchCardStyle (.card, default) / .hero / .compact / .inlineBar / .pill
// + AnyTripSearchCardStyle, env key, .tripSearchCardStyle(_:) — same wiring as Class A.
```

`@State` (expansion, sheets, swap spin) stays in the component; styles see
`isExpanded`/`toggleExpand` only. Same split for the other Class B components:
PassengerForm hands wired field units + validator state; AirportPicker hands the
search field + built section lists; CheckInFlow hands the `Steps` header unit,
the current page, and the wired dock; SeatMap hands the built cabin grid, rail,
deck selector, legend and summary units; StickyBookingBar hands the price block
and CTA units (its `BarStyle` chrome delegation stays outside the new protocol).

## 3. Per-component style matrix (the catalog)

Default preset first — always today's render, pixel-for-pixel. *(m)* = mapped
from an existing enum case / knob / single look; *(new)* = net-new archetype from
the ceiling analysis, grounded in a named industry pattern.

### Organisms

| Component | Protocol → modifier | Presets | Count (m+new) |
|---|---|---|---|
| FlightListItem | `FlightListItemStyle` → `.flightListItemStyle(_:)` — **exists, unchanged** | `.timeline`(m, default) `.compact` `.fareBoard` `.deal` `.ticket` `.journey` `.slices` `.timetable` `.tray` `.tile` `.hero` `.receipt` (all m) | **12** (12+0) |
| TripSearchCard | `TripSearchCardStyle` → `.tripSearchCardStyle(_:)` | `.card`(m, default — stacked editor, `TripSearchCard.swift:189`) `.hero`(m — `.lg` padding + elevated + large CTA, `:128–131,157`) `.compact`(m — collapsed summary ⇄ editor, `:167,446`) `.inlineBar`(m — one-row run w/ ViewThatFits fallback, `:207–208`) `.pill`(new — floating capsule that expands; Airbnb/Skyscanner home header) | **5** (4+1) |
| PaymentMethodSelector | `PaymentMethodSelectorStyle` → `.paymentMethodSelectorStyle(_:)` | `.list`(m, default — ListRow radio rows, `:141`) `.grid`(m — tile grid, `:273`) `.carousel`(m — snap tiles, `:246`) `.compactList`(m — dense rows, `:215`) `.sectioned`(new — grouped rows: cards / wallets / other, with section headers) | **5** (4+1) |
| SavedCardsList | `SavedCardsListStyle` → `.savedCardsListStyle(_:)` | `.list`(m, default — radio rows) `.wallet`(m — card-face tile carousel) `.stack`(new — overlapping pass-book stack that fans out; Apple Wallet) `.grid`(new — card-face tile grid) | **4** (2+2) |
| FlightTracker | `FlightTrackerStyle` → `.flightTrackerStyle(_:)` | `.board`(m, default — badge + route/progress + facts + phase timeline) `.compact`(m — one-row strip) `.timeline`(new — phase-first vertical spine w/ per-phase facts; tracker-app detail) `.banner`(new — status-tone strip for push-style surfaces) | **4** (2+2) |
| FareFamilyCard | `FareFamilyCardStyle` → `.fareFamilyCardStyle(_:)` | `.stacked`(m, default — chip, features, price footer) `.column`(m — comparison-matrix column) `.row`(new — horizontal strip: chip+features leading, price+select trailing) `.accordion`(new — collapsed tier that expands its feature list) | **4** (2+2) |
| TransportCrossSellCard | `TransportCrossSellCardStyle` → `.transportCrossSellCardStyle(_:)` | `.ribbon`(m, default — notched TicketStub strip, `TransportCrossSellCard.swift:7–13`) `.inline`(m — flat ListRow) `.tile`(m — vertical grid card) `.banner`(new — full-bleed mode-tinted promo strip) | **4** (3+1) |
| PassengerForm | `PassengerFormStyle` → `.passengerFormStyle(_:)` | `.stacked`(m, default) `.flat`(m) `.grouped`(m) `.carded`(new — each section in its own Card) | **4** (3+1) |
| FlightCard | `FlightCardStyle` → `.flightCardStyle(_:)` | `.standard`(m, default — airline header + route + price/CTA footer) `.condensed`(new — one-line route summary + trailing price, no header row) `.tile`(new — vertical card for destination carousels) | **3** (1+2) |
| FlightResultRow | `FlightResultRowStyle` → `.flightResultRowStyle(_:)` | `.row`(m, default — identity / route / price+CTA columns) `.stacked`(new — identity above route for narrow widths) `.minimal`(new — no CTA, whole-row tap + chevron) | **3** (1+2) |
| FlightTicketCard | `FlightTicketCardStyle` → `.flightTicketCardStyle(_:)` | `.classic`(m, default — route header + dashed timeline + horizontal tear + stub) `.horizontal`(new — stub trailing behind a vertical tear; reuses the CrossSell vertical-tear technique, `TransportCrossSellCard.swift:16–21`) `.flat`(new — tearless plain card for dense lists) | **3** (1+2) |
| BoardingPass | `BoardingPassStyle` → `.boardingPassStyle(_:)` | `.classic`(m, default — header/passenger/route/details + barcode stub) `.wallet`(new — QR-dominant vertical, two-column details; Apple Wallet pass) `.strip`(new — one-row gate strip: name/seat/mini-QR) | **3** (1+2) |
| AncillaryCard | `AncillaryCardStyle` → `.ancillaryCardStyle(_:)` | `.row`(m, default — icon/title/price + stepper or toggle) `.tile`(new — vertical grid tile, stepper bottom) `.banner`(new — thumbnail-led full-width upsell) | **3** (1+2) |
| FareSummary | `FareSummaryStyle` → `.fareSummaryStyle(_:)` | `.list`(m, default — labeled lines + hero total) `.receipt`(new — dotted leaders, overline labels, dashed rules) `.collapsed`(new — total-first row with disclosure to the lines) | **3** (1+2) |
| StickyBookingBar | `StickyBookingBarStyle` → `.stickyBookingBarStyle(_:)` | `.standard`(m, default — price left / CTA right) `.stacked`(new — note+price above a full-width CTA) `.split`(new — secondary + primary action pair) — arranges *content*; `BarStyle` keeps drawing bar chrome (`StickyBookingBar.swift:10–17`) | **3** (1+2) |
| CheckInFlow | `CheckInFlowStyle` → `.checkInFlowStyle(_:)` | `.steps`(m, default — `Steps` header + dock) `.bar`(m — promotes `CheckInProgressStyle.bar`, `CheckInFlow.swift:53`) `.paged`(new — page-dot pager, minimal header) | **3** (2+1) |
| AirportPicker | `AirportPickerStyle` → `.airportPickerStyle(_:)` | `.list`(m, default — sectioned rows: IATA chip + city/airport, `AirportPicker.swift:21–23`) `.compact`(m — promotes `AirportPickerDensity.compact`, `:37`) `.codeGrid`(new — IATA chip grid for nearby/popular sections) — `AirportPickerPresentation` stays orthogonal (presentation ≠ style) | **3** (2+1) |
| FilterBar | `FilterBarStyle` → `.filterBarStyle(_:)` | `.chips`(m, default — pinned actions + scrolling chips) `.segmented`(new — fixed equal segments, no scroll) `.stacked`(new — actions row above a wrapping chip row) — `FilterChipStyle` remains a knob within row-based presets | **3** (1+2) |
| SeatMap | `SeatMapStyle` → `.seatMapStyle(_:)` | `.cabin`(m, default — rail + deck selector + grid + legend + summary) `.grid`(new — bare seat grid, chrome-less; venue-picker style) `.schematic`(new — fuselage-silhouette wrapper with wing/exit markers) | **3** (1+2) |

### Molecules

| Component | Protocol → modifier | Presets | Count (m+new) |
|---|---|---|---|
| CabinClassSelector | `CabinClassSelectorStyle` → `.cabinClassSelectorStyle(_:)` | `.segmented`(m, default) `.chips`(m) `.list`(m) `.cards`(m) — each preset keeps delegating to SegmentedControl/Chip/rows/cards | **4** (4+0) |
| FlightRoute | `FlightRouteStyle` → `.flightRouteStyle(_:)` | `.path`(m, default) `.inline`(m) `.arc`(m) `.dots`(m) — promotes `FlightRouteTrack`; `Path`-drawing presets keep `.flipsForRightToLeftLayoutDirection(true)` | **4** (4+0) |
| RecentSearchRow | `RecentSearchRowStyle` → `.recentSearchRowStyle(_:)` | `.plain`(m, default) `.bordered`(m) `.pill`(m) `.card`(new — vertical tile for a recents carousel) | **4** (3+1) |
| LayoverRow | `LayoverRowStyle` → `.layoverRowStyle(_:)` | `.line`(m, default) `.pill`(m) `.banner`(m) | **3** (3+0) |
| DatePriceStrip | `DatePriceStripStyle` → `.datePriceStripStyle(_:)` | `.grid`(m, default — `grid(columns:)` folds column count into the preset: `.grid(columns: 3)`) `.strip`(m — scrollable pills) `.chart`(new — price-bar histogram, bar height ∝ price; Google Flights price graph) | **3** (2+1) |
| PassengerRow | `PassengerRowStyle` → `.passengerRowStyle(_:)` | `.row`(m, default) `.card`(new — bordered card, prominent edit/remove) `.compact`(new — single-line name+seat+chevron) | **3** (1+2) |
| SeatLegend | `SeatLegendStyle` → `.seatLegendStyle(_:)` | `.rows`(m, default) `.vertical`(m) `.inline`(m) — promotes `SeatLegendOrientation` (`SeatLegend.swift:16–23`); `perRow` folds into `.rows(perRow:)` | **3** (3+0) |
| TripTypeToggle | `TripTypeToggleStyle` → `.tripTypeToggleStyle(_:)` | `.pill`(m, default) `.underline`(m) `.menu`(new — Dropdown-composed for dense headers) | **3** (2+1) |

### Atoms

Honest note: atoms have no layout anatomy to swap — their "styles" are the
emphasis/shape looks they already own as knob enums. We promote those knobs to
presets **for suite uniformity only** (one mental model: everything answers to
`.xStyle(_:)`, settable once per screen via the environment — the knob modifiers
never could be). Remaining knobs (size ramps, palettes, display content) stay
configuration fields, not presets.

| Component | Protocol → modifier | Presets | Count (m+new) |
|---|---|---|---|
| FlightStatusBadge | `FlightStatusBadgeStyle` → `.flightStatusBadgeStyle(_:)` | `.soft`(m, default) `.solid`(m) `.outline`(m) `.dot`(m) — promotes `FlightStatusEmphasis` (`FlightStatusBadge.swift:20–29`); status hue stays semantic per status | **4** (4+0) |
| SeatCell | `SeatCellStyle` → `.seatCellStyle(_:)` | `.rounded`(m, default) `.circle`(m) `.seatback`(m) — promotes `SeatShape` (`SeatMapModels.swift:236`); `SeatSelectionEmphasis`/palette/display stay config fields. Doubles as the pre-COW atom's modernization path (`SeatCell.swift:10–12`): the `shape:` init param deprecates toward the env style, no major needed | **3** (3+0) |

**Totals: 29 protocols · 109 presets = 74 existing-mapped + 35 net-new.**
Per-tier: organisms 19 protocols / 67 presets, molecules 8 / 27, atoms 2 / 7.

## 4. Configuration essentials per cluster

Shared rules for all 28 new configurations (implementation checklist):

- Public `let` fields, internal memberwise init — additive-safe forever
  (the `FlightListItemConfiguration.isFavorite` precedent,
  `FlightListItemStyle.swift:79–83`): new needs enter as optional fields every
  style may ignore, **never** as new presets without a demand note.
- Always carried: `accent: SemanticColor?`, `surfaceKey:
  Theme.BackgroundColorKey?` + `surface(default:)`, `density: ComponentDensity` +
  `spacing(_:)`, `locale: Locale` + shared formatters. Radius via
  `Theme.RadiusRole` where the component exposes it. No raw `Color`/`CGFloat` in
  any configuration or preset signature (token rule).
- Motion: components resolve `MicroMotion`/Reduce Motion *before* calling styles
  (pass resolved `Animation?` or act in the component, as FlightListItem does for
  `toggleExpand`/`toggleFavorite`) — styles never read motion env themselves.
- Selection/expansion follow ADR-F4: configurations expose read state + toggle
  closures; `ControllableState` stays in the component.
- TicketStub-chrome components (`BoardingPass`, `FlightTicketCard`,
  `TransportCrossSellCard.ribbon`): the former blanket exemption dissolves —
  default presets *own* the TicketStub chrome inside `makeBody`, and the tear
  helpers stay available to custom styles (TicketStub is already a public
  ThemeKit component). `.cardStyle(_:)` remains a no-op on these presets, now
  documented per-preset instead of per-component.
- Cross-preset building blocks (summary rows, tear lines, tile builders like
  `PaymentMethodSelector.tile(_:)` (`:305`)) become shared `private` sub-views in
  the `<Component>Style.swift` file, per the SKILL's style-driven pattern.

## 5. API safety & versioning

- **Additive, minor-eligible:** 28 new protocols + configurations + erasures +
  env keys + accessors + ~97 new preset structs; zero removals. Every default
  preset is extracted verbatim from today's body → pixel parity, verified per
  wave by demo screenshot.
- **Deprecate-forward, never break:**
  ```swift
  @available(*, deprecated, message: "Use .paymentMethodSelectorStyle(.grid)")
  func variant(_ v: PaymentMethodVariant) -> Self   // maps to the matching preset
  ```
  Applies to all 13 variant/layout enums, plus the promoted knobs
  (`FlightStatusBadge` emphasis, `SeatCell` `shape:` init param, `SeatLegend`
  orientation, `CheckInFlow` progress style, `AirportPicker` density). An
  explicitly-set deprecated modifier **wins over the environment style**
  (source-behavior stability); the enums themselves deprecate and are removed at
  the next major together with the already-deferred SeatCell COW migration.
- **The one real cost, flagged:** this is a *large* public-surface expansion —
  roughly **+400 public symbols** (~28 × [protocol + config (~8–25 fields) +
  modifier + 3–5 presets + accessors]). Each is a permanent API-stability
  liability under `docs/API-STABILITY.md`. It fits a **minor** release
  mechanically, but the recommendation is to ship all waves inside **one minor
  train** (single changelog story, one docs/llms regeneration, one deprecation
  epoch) rather than dribbling across releases — and to accept that the *next
  major* is when the 13 enums and knob params actually disappear.

## 6. Interaction with the shell protocols

`CardStyle`/`BarStyle`/`FieldStyle` remain the *chrome* axes; the new protocols
are the *arrangement* axes. Card-shaped presets compose the neutral `Card`
(chrome keeps routing through `\.cardStyle` — today's behavior at
`FlightCard.swift:9–14`, `AncillaryCard.swift:14–18`, `TripSearchCard.swift:156–158`);
`StickyBookingBar` presets hand their arranged row to the active `BarStyle`;
form/field components keep `FieldStyle` transitively. One law, documented in each
style file's header: **component style arranges content; shell style paints
chrome; token theme colors everything.**

## 7. Rejected alternatives

- **One universal cross-cutting `.travelStyle(_:)` design-language axis** (a
  single `TravelStyle` protocol every component reads, presets like
  `.classic`/`.modern`/`.dense`). Rejected: a style is only implementable because
  its `Configuration` is *typed to the component* — a universal configuration
  degenerates into `[AnyView]` + stringly keys (render-props by another name,
  explicitly off-idiom), and a "design language" that must describe both a
  `SeatCell` and a `CheckInFlow` can only carry paint, which is what the *theme*
  already does. Cross-component cohesion is instead achieved the ThemeKit way:
  set many `.xStyle(_:)` modifiers once at the screen root (they are all
  environment keys — one `ThemeProvider`-style wrapper in the app can bundle
  them), plus the existing `CardStyle`/`BarStyle` shells for shared chrome.
- **Protocols only where anatomy exists (the v1 draft / ADR-F5 ladder):** one
  promotion (TripSearchCard), three enum growths, everything else as-is.
  Superseded by explicit user override; recorded here so the reasoning isn't
  lost — the ladder still governs *future* components, and §3's (m)/(new) tags
  preserve which presets are demand-proven vs. initiative-driven.
- **Skipping the atoms** (leave `FlightStatusBadge`/`SeatCell` on knob enums).
  Rejected for this initiative: the user's goal is a *uniformly* restyleable
  suite; the honest handling is §3's — promote only the knob that *is* the look
  (emphasis, shape), keep every other knob a configuration field, and say plainly
  that these two protocols buy env-level set-once and custom-look extensibility
  (e.g. a brand's own seat silhouette as a custom `SeatCellStyle`), not new
  anatomy.
- **A macro/codegen shortcut** (`@Styleable` generating the boilerplate).
  Tempting at 28 protocols, but a macro dependency violates the zero-dependency
  contract and hides the one thing that must stay reviewable per component: the
  configuration's typed field list. The erasure/env-key/accessor boilerplate is
  mechanical enough for a shared reference file + review checklist.

## 8. Sequenced build plan — 6 waves, PR-per-wave, disjoint files

Parallelizable by the proven 4-agent pattern (each wave touches only its own
component files + one new `<Component>Style.swift` per component; no file is in
two waves). Every wave carries the same gates: pixel-parity screenshot of each
default preset, `#Preview` matrix iterating all presets × light/dark
(`PreviewMatrix`), one custom in-preview style proving external implementability,
RTL + a11y-size spot-checks on layout-switching presets, demo style-switcher +
`-openDemo "<Component>"` verification, llms/docs regen (`tools/gen_skill.py`).

| Wave | Cluster (disjoint files) | Protocols | Presets | Effort |
|---|---|---|---|---|
| 0 | **Infrastructure**: reference doc (`docs/style-protocol-checklist.md`), demo style-switcher harness, name-collision grep, API-STABILITY note | 0 | 0 | S |
| 1 | **Flight results**: FlightCard, FlightResultRow, FlightTicketCard, FlightRoute, FlightStatusBadge | 5 | 17 | M |
| 2 | **Search**: TripSearchCard, AirportPicker, RecentSearchRow, TripTypeToggle, CabinClassSelector, DatePriceStrip | 6 | 22 | L (TripSearchCard is the hardest single item — Class B, 778 lines) |
| 3 | **Booking & payment**: PaymentMethodSelector, SavedCardsList, FareFamilyCard, FareSummary, AncillaryCard, StickyBookingBar | 6 | 22 | L |
| 4 | **Passenger & day-of-travel**: PassengerForm, PassengerRow, CheckInFlow, BoardingPass, FlightTracker, LayoverRow | 6 | 20 | L |
| 5 | **Seats & filters**: SeatMap, SeatCell, SeatLegend, FilterBar, TransportCrossSellCard | 5 | 16 | M/L (SeatMap Class B; CrossSell tear chrome) |

Wave order rationale: Wave 1 establishes the Class A template on the simplest
cluster; Wave 2 lands the Class B exemplar early (highest-risk shape gets the
longest soak); Waves 3–5 are parallel-safe after Wave 1 merges the template.
FlightListItem ships nothing (already conformant) but its style file is the
review baseline for every wave.

## 9. Open questions for sr-ios-dev (pressure-test with call sites)

1. **Deprecation precedence mechanics** — explicit `.variant(_:)` beating an
   ancestor `.xStyle(_:)`: confirm the internal mapping (stored optional variant
   overrides env style when non-nil) reads sanely at mixed call sites during
   migration, especially Demo screens setting both.
2. **Class B unit granularity** — is `routeFields` (welded
   origin+swap+destination) enough for `.pill`/custom search styles, or do styles
   need the three units separately? Start welded; splitting later is additive.
3. **`DatePriceStripStyle.grid(columns:)` / `SeatLegendStyle.rows(perRow:)`** —
   parameterized presets (struct with a stored property) vs. keeping
   `columns`/`perRow` as configuration fields. Prefer parameterized preset
   structs (matches `where Self ==` accessors taking arguments); verify ergonomics.
4. **AnyView diffing at scale** — the SKILL's `.id` rule for slot-type stability:
   audit the Class B units that alternate view types (return date field,
   compact expansion) for branch-identity loss; profile SeatMap `.grid` with
   large cabins (erased grid unit).
5. **Symbol-count check** — after Wave 1, measure the real public-symbol and
   binary-size delta; if the ~400-symbol projection is materially exceeded,
   surface it before Waves 3–5 rather than after.
