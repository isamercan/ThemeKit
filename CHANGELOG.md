# Changelog

All notable changes to **ThemeKit** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) — from **1.0.0** on,
breaking changes bump the **major**.

## [Unreleased]

### Added
- **`SemanticColor` now conforms to `Sendable`**, and **`CardBrand` now conforms to `Sendable, CaseIterable, Codable`** — additive conformances (no signature change) so `Sendable` value types (e.g. edition environment defaults) can carry a `SemanticColor`, and `CardBrand`-bearing models can be `Codable`.
- **`ThemeKitTravel`** library product — the opt-in flight/booking **domain edition** (composition over forking: it wraps the neutral `ThemeKit` catalog rather than re-implementing it). This first drop is the packaging foundation — the SPM target/product plus the edition's own String Catalog (`String(themeKitTravel:)`); the booking-flow components land in follow-ups. **No package trait and no re-export** (mirroring `ThemeKitCalendar`): add `ThemeKitTravel` to a target and write `import ThemeKitTravel` alongside `import ThemeKit` to opt in — a consumer who doesn't compiles nothing from it and downloads the same package. Part of the [#229](https://github.com/isamercan/ThemeKit/issues/229) modular direction (ADR: `THEMEKITTRAVEL_ARCHITECTURE.md`).

## [1.1.0] - 2026-07-10

**New `ThemeKitCore` product — the token-only theme layer.** The theme engine,
design tokens, and `@Environment(\.theme)` now ship as a standalone
`ThemeKitCore` library you can adopt on its own, without the 204-component
catalog. The full `ThemeKit` product depends on it and `@_exported import`s it,
so **existing `import ThemeKit` code is unchanged** — `Theme`, `SemanticColor`,
`Theme.SpacingKey` and friends still resolve exactly as before.

First step of the modularization from the architecture review
([#229](https://github.com/isamercan/ThemeKit/issues/229)): a narrow, value-based
core for apps that only want theming, with the opinionated domain organisms to
move into later editions.

### Added
- **`ThemeKitCore`** library product — `Theme`, tokens (`SemanticColor`, `Theme.SpacingKey`, `Theme.RadiusRole`, typography), `@Environment(\.theme)`, `.themeKit()`, presets, and the theme generator, with **zero components and zero third-party dependencies**. Adopt with `import ThemeKitCore`.

### Changed
- **`ThemeKit` now re-exports `ThemeKitCore`** (`@_exported import`), so a plain `import ThemeKit` surfaces every token and theme symbol unchanged — no source changes for existing consumers.
- The theme engine, `Localizable.xcstrings`, and the theme JSON now live in the `ThemeKitCore` target's resource bundle.

### Migration (only if affected)
- Fully-qualified references to engine symbols — e.g. `ThemeKit.Theme`, `ThemeKit.SemanticColor` — must drop the qualifier or use `ThemeKitCore.Theme`. Unqualified use (`Theme(…)`, `SemanticColor.primary`, `.textStyle(…)`) is unaffected.

## [1.0.0] - 2026-07-09

**The 1.0 stability milestone.** ThemeKit reaches **204 components** (50 atoms ·
81 molecules · 73 organisms) with a dependency-free core, a full accessibility
pass, and a stable public API. This is the first release under strict
[Semantic Versioning](https://semver.org/) — from here, breaking changes bump the
**major**. Shipping a real `1.0.0` tag also fixes Xcode's "Up to Next Major"
resolution, which previously could not settle on a pre-1.0 version
([#223](https://github.com/isamercan/ThemeKit/issues/223)).

### Added
- **HeroUI Native parity — four waves of new and upgraded components:**
  - **Wave 1 — form fields** ([#220](https://github.com/isamercan/ThemeKit/pull/220)): TextInput, SearchBar, OTPInput, InputLabel.
  - **Wave 2 — selection & controls** ([#221](https://github.com/isamercan/ThemeKit/pull/221)): Dropdown, Select, Tag, sliders and related controls.
  - **Wave 3 — overlay & feedback** ([#222](https://github.com/isamercan/ThemeKit/pull/222)): Dialog, BottomSheet, popovers, toasts.
  - **Wave 4 — navigation & display** ([#225](https://github.com/isamercan/ThemeKit/pull/225)): Tabs, Accordion, Card, Avatar and more.
  - Plus the initial **HeroUI Native audit** — 6 new components and a gap-analysis document ([#216](https://github.com/isamercan/ThemeKit/pull/216)).
- **Component gallery** now flags freshly shipped components with a **"New"** badge and adds a dedicated Showcase pod ([#226](https://github.com/isamercan/ThemeKit/pull/226)).

### Accessibility
- Two audit rounds added accessibility labels to icon-only controls and corrected sort / disclosure / selected traits across the library ([#218](https://github.com/isamercan/ThemeKit/pull/218), [#219](https://github.com/isamercan/ThemeKit/pull/219)).

### Changed
- **The optional add-ons are now behind opt-in [SwiftPM package traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)**, so the core is dependency-free at *resolution* time, not just link time. A plain `.package(url: "…ThemeKit.git")` now resolves **zero** third-party packages — Lottie, Almanac and HorizonCalendar are no longer fetched unless you ask for them ([#224](https://github.com/isamercan/ThemeKit/issues/224)).
  - Enable an add-on's dependency with the matching trait: `traits: ["Lottie"]` and/or `traits: ["Calendar"]` on the package dependency (or the **Traits** checkboxes in Xcode).
  - Add-on sources are `#if canImport(…)` guarded, so with a trait off the module compiles to an empty module rather than failing to build.

### Breaking
- **Consumers already using `ThemeKitLottie` or `ThemeKitCalendar` must enable the corresponding trait** (`Lottie` / `Calendar`) — otherwise the add-on module resolves empty and its symbols disappear. The core `ThemeKit` product is unaffected. Traits require **Swift 6.1+** tooling on the consuming side.

## [0.19.0] - 2026-07-09

The **Ant Design overview parity** release: swept ant.design/components against the
library and built every genuine gap, plus a wave of Ant-parity upgrades to existing
components. All additive and backward-compatible.

### Added
- **New Ant-parity components:**
  - **Watermark** — a `.watermark(_:)` modifier tiling a faint, rotated label across a view (Canvas-drawn, theme-tinted).
  - **Flex** — a flexbox container with main-axis `justify` (start / center / end / space-between / -around / -evenly) and cross-axis `align`, via a custom `Layout`. **Space** stays the simpler even-gap primitive.
  - **AnchorNav** — a scroll-spy link rail with a moving hero indicator (Ant `Anchor`; renamed to avoid SwiftUI's `Anchor<Value>`).
  - **Splitter** — two panes with a draggable, clamped divider.
  - **Affix** — pins content to the top/bottom of a scroll container once it passes an offset (`.target(_:)` for a named container).
  - **Cascader** — pick a value from a multi-level option tree, one column per level.
  - **Transfer** — move items between a source and a target list via checkboxes + arrows.
  - **Mentions** — a multi-line input where typing `@` opens a filterable suggestion list.
  - **Masonry** — a Pinterest-style grid; items flow into the shortest column (custom `Layout`).
  - **TreeView** — a standalone hierarchical tree with expand/collapse + optional cascade checkboxes (Ant `Tree`; reuses `TreeNode`).
  - **ColumnsGrid** — an equal-column grid with a token gutter, fixed or responsive-adaptive (Ant `Grid`).
  - **Space** — even spacing between inline/stacked children (direction / size / align / wrap).
- **PageHeader** rewritten as a style-driven organism with 13 style variants, plus a reusable **SearchSummary** molecule.
- **CheckableTag** — Ant's checkable tag (toggles a bound `Bool`).

### Changed
- **SegmentedControl** — `.selectionStyle(.tinted)` (soft joined toggle) + `.dividers()` + `.tinted(_ color:)` base color; fuller Ant Segmented parity.
- **Tag** — `.color(_ SemanticColor)` for the broader palette, `.bordered()`, and the new `CheckableTag`.
- **ResultView** — `.icon { }` / `.content { }` / `.extra { }` slots + `.subtitle(_)` (Ant Result parity).
- **BorderBeam** — `outset` + `reverse` (Ant BorderBeam parity).
- **FilterBar** — Ant "Filter Section" chip + leading styles; native icon+label collapse on scroll.
- **DatePriceStrip** — `.strip()` horizontal timeline; **RecentSearchRow** — `.pill()` mini-search-bar variant.
- Docs refreshed to **185 components**; README hero banner + GitHub Pages regenerated, with usage snippets for the new components.

## [0.18.2] - 2026-07-08

### Fixed
- **FlightListItem `.tray`** container now matches the Figma spec: a tinted
  card-surface behind the white card (was a near-white neutral that blended in)
  and the correct concentric radii — 24pt outer tray, 20pt inner card.
  - The tinted surface is **derived, not a new global token**: white blended
    halfway with the theme's tinted page surface (`bgElevatorPrimary`) via the
    new `Color.blended(with:by:)` helper, so it re-skins under ocean/sunset/dark.
    An explicit `.surface(_:)` still overrides it.
- **FlightListItem.surface(_:)** is now optional per style: `surfaceKey` defaults
  to `nil` and each style resolves its own natural surface
  (`configuration.surface(default:)`) — cards use base-100, `.tray` its tint.

### Added
- `Color.blended(with:by:)` — sRGB blend of two colors (0…1), for deriving
  intermediate surfaces from existing theme tokens without adding new ones.

## [0.18.1] - 2026-07-08

### Fixed
- **FlightListItem `.tray`** now matches the Figma spec pixel-for-pixel. Two
  flexibility upgrades on the underlying atoms/molecules made it possible
  without bespoke drawing:
  - `FlightRoute.track(.inline)` — the design-system track: full-width
    hairlines flanking the duration, stops label beneath in tertiary,
    outer-aligned 16pt time columns (stock `.path` look unchanged; time
    strings now honor the environment locale).
  - `PriceTag.originalBelow()` — stacks the struck compare-at price below the
    amount (the spec's vertical price block).

## [0.18.0] - 2026-07-08

### Added
- **FlightListItem `.tray` style** — implemented from the design-system Figma
  spec: a white flight card nested on a soft tray surface, with the actions on
  the tray (details text-link · per-person price with compare-at strikethrough ·
  circular go button). Composed entirely from library atoms/molecules
  (`FlightRoute`, `PriceTag`, `TextLink`, `ThemeButton`, `DividerView`, `Icon`,
  `Badge`). New supporting data on the component: `baggage(_:checked:)` and
  `onDetails(_:perform:)` (available to every style via the configuration).

## [0.17.0] - 2026-07-08

### Added
- **FlightListItem** (organism) — a style-driven flight search-result list item.
  The component owns the typed data (legs, fares, price, deal signals, schedule);
  the entire layout is delegated to a new **`FlightListItemStyle`** protocol —
  the most data-rich style hook in the library. Eight built-in styles cover the
  industry's list-item archetypes (researched across Skyscanner, Google Flights,
  Kayak, Hopper, Delta/THY, Kiwi, Expedia):
  `.compact`, `.timeline` (default), `.fareBoard`, `.deal`, `.ticket`,
  `.journey` (expandable, `expanded(_:)`-drivable), `.slices`, `.timetable`.
  Plus a **FlightFare** model for fare-family shopping and modifiers for
  deal signals (`deal(_:tone:)`, `trend(_:)`), schedules (`departures(_:note:)`)
  and slices (`sliceLabels(_:)`).

## [0.16.0] - 2026-07-07

### Changed — flexibility wave 6: naming sweep, raw-type cleanup, grade-1 floor lift

Closes the flexibility programme (see `docs/flexibility-faz3-report.md`).

- **`accent(_:)` is the one colour verb.** New `accent(SemanticColor?)` on Icon,
  InlineText, RollingNumber, ProgressBar (fill), Avatar/AvatarGroup, CalendarView,
  ScoreBadge, ShareButton, FareFeatureRow, TextRotate, SortTab, Counter,
  Breadcrumbs, ThemeController, ListSectionHeader, FloatingActionButton,
  SmartSuggestion, CalendarView. Raw-`Color` colour modifiers (`color`, `fillColor`,
  `ringColor`, `badgeColor`, `colors`, `tint`, `selectionColor`) are deprecated —
  still functional. Badge deliberately keeps `badgeStyle` as its semantic gate.
- **Geometry tokens:** `cornerRadius(RadiusRole)` / `spacing(SpacingKey)` /
  `peek(SpacingKey)` overloads on AnimatedImage, RemoteImage, ImageCollage,
  FilterBar, PagingCarousel, PriceTrendChart; raw CGFloat knobs stay (documented).
- **Aliases:** `Chip.expands` / `Coupon.block` deprecated-renamed to `fullWidth`.
- **Grade-1 floor lift:** Breadcrumbs, FilterGroup, ScoreBadge, TextRotate,
  FareFeatureRow, ShareButton, CalendarView, ThemeController, ThemePicker, SortTab,
  Counter (new `CounterSize`), ListSectionHeader (+`trailing{}` slot) all gain
  copy-on-write modifier layers. HeroSurface evaluated — Hero's `background{}`
  builder already covers it.
- **Housekeeping:** Carousel/VideoPlayerView modifiers normalised onto the standard
  `copy(_:)` helper.

## [0.15.0] - 2026-07-07

### Added — flexibility wave 5: presenter content slots + container state slots

- **`ToastStyle`** (new protocol; `.default` / `.capsule`): `AlertToast` bridges via
  `isDefault` — `feedbackHost` toasts inherit the hook. `.toast(isPresented:
  autoDismiss:content:)` presents fully custom toasts through the same
  presentation modifier.
- **Presenters:** `Dialog` gains a free-form card overload; `Feedback` gains
  `toast{}` / `notify{}` builder overloads; `Tour` gains `tourHost(stepCard:)`
  with a public `TourStepContext` (step/index/count + next/prev/skip).
  `BottomSheet` / `Drawer` were already ViewBuilder-slotted. CardStyle adoption
  deliberately skipped for floating presenter chrome (documented in-file).
- **Containers:** `ListView` and `DataTable` gain `.empty{}` / `.loadingView{}`
  (DataTable also `.header{}` / `.footer{}` outside the column strip); `Gallery`
  gains `.empty{}`.
- **`CardStack`** gets its modifier layer: `.maxVisible`, token-typed
  `.peekOffset`, `.rotation` (fanned-deck scatter). No swipe axis — the deck has
  no gesture behaviour to bind; empty-deck negative padding clamped.

## [0.14.0] - 2026-07-07

### Changed — flexibility wave 4: chip, bar and meter families bridge into their archetype styles

- **Chips (`ChipStyle`):** `ImageChip` / `CompactChip` / `ChoseChip` / `FilterChip` /
  `MapPriceMarker` keep their non-capsule chroma pixel-identical while the default
  style is ambient (`AnyChipStyle.isDefault` bridge) and hand content to
  `makeBody` when a custom `.chipStyle(_:)` is set. `ChipGroup` unchanged.
- **Bars (`BarStyle`):** `Footer` delegates fully; `PageHeader`, `NavigationBar`
  and `StickyBookingBar` bridge (legacy chrome — chrome-less / capsule + shadow /
  overlay hairline — cannot be expressed by `DefaultBarStyle`, so it stays
  byte-identical until a custom style is set). `NavigationBar` gains a per-item
  `.item{}` builder; `BarChromeOverrides` gains a `showsShadow` channel.
- **Meters (`MeterStyle`):** `RadialProgress` adopts via a new built-in
  `RadialMeterStyle` (`.radial`; ring geometry extracted verbatim, dashboard/size/
  lineWidth as style parameters) and hands over fully to custom `.meterStyle`.
  `Steps` gains a per-step `.marker{}` builder (percent ring + a11y preserved).
  `GaugeView` documented exception (native `Gauge`).
- **Katman-2 exceptions (evaluated, untouched):** `FilterBar`, `SortSummaryBar`
  (no bar chrome — bare rows), `Sidebar` (vertical rail), `SegmentedTabBar`,
  `SegmentedControl`, `TripTypeToggle` (track+selection control chroma);
  `Badge`/`Tag` family stays Katman-2 — their variant system is the style axis,
  they carry no selection state.

## [0.13.0] - 2026-07-07

### Changed — flexibility wave 3: the form family routes its chrome through `FieldStyle`

15 field components now delegate their box chrome (fill, border, corner) to the
environment `FieldStyle`; `.fieldStyle(_:)` re-skins the whole form without forking:

- **Select family:** `Select` folds into FieldStyle when no custom `SelectStyle` is
  injected (legacy path byte-identical otherwise); `SelectStyle`, its built-ins and
  `.selectStyle(_:)` are **deprecated** but functional. `SelectBox`, `MultiSelect`,
  `TreeSelect` delegate their trigger chrome (open → `isFocused`).
- **Date/number:** `DateField`, `TimeField` (open popover → `isFocused`),
  `InputNumber`, `FieldButton` (field-look shell; fill normalises to `bgWhite`).
- **Specialised:** `OTPInput` (per-digit cells; active cell = `isFocused`, warnings
  now tint the border), `PaymentCardField` (real per-row focus — focused rows show
  the hero border), `FileInput`, `ColorField`, `MultiLineTextInput`.
- **Search:** `SearchBar` (fill normalises `bgElevatorPrimary` → `bgWhite`, gains a
  focus border), `Autocomplete`; `SearchField` keeps its five legacy chrome modifiers
  as a byte-identical override path and defers to FieldStyle only when none is set.
- **Exceptions:** `GuestSelector` (no field box), `CurrencyPicker` (inherits via
  `SearchBar`).

**Behaviour notes:** disabled fields now uniformly use the muted `bgSecondaryLight`
fill; error/warning beats the open/focus border and thickens to 1.5pt; corner radii
move to the `.field` role token (same fallback size in bundled themes). Demo
showcase gained a "Form family" section.

## [0.12.0] - 2026-07-07

### Changed — flexibility wave 2: the card family routes its shells through `CardStyle`

16 card components now delegate their outer shell (surface fill, corner clipping,
border, shadow) to the environment `CardStyle` — `surface()/cornerRadius()/elevation()`
feed the `CardStyleConfiguration`, and `.cardStyle(_:)` can swap in a completely
different shell without forking:

- **Flight:** `FlightCard`, `FlightResultRow`.
- **Media:** `RoomCard`, `DestinationCard` (+`.overlay{}`), `LocationCard`
  (+`.media{}` replacing the map region, +`.overlay{}`), `AncillaryCard`.
- **Content:** `ReviewCard`, `NotificationCard` (+`.leading{}`), `PriceAlertCard`,
  `BlogCard` (opt-in shell via `surface/cornerRadius/elevation`, +`.overlay{}`).
- **Selectable:** `FareFamilyCard`, `RadioCard`, `CheckboxCard`, `DatePriceCard`,
  `RoomCard`/`AncillaryCard` — selection now flows through
  `CardStyleConfiguration.isSelected` (selected borders normalise to the style's
  1.5pt `borderHero` `strokeBorder`).
- **Partial/exceptions (documented in-file):** `LoyaltyCard` (gradient front is the
  component's identity; flat back face delegated), `MapCallout` (pointer triangle and
  accent border stay component-drawn), `TicketStub`, `Coupon`, `FlightTicketCard`,
  `BoardingPass` (notched/dashed ticket shells cannot be expressed as a flat surface),
  `RatingSummary` (no shell), `KeyValueTable` (bordered shell delegated, +`surface(_:)`).

**Behaviour notes:** hairline borders follow `Card` semantics (drawn at `.none`
elevation; shadowed shells drop it), `stroke` → `strokeBorder` sub-pixel
normalisation, and selected borders use the `borderHero` token instead of per-card
accent strokes. Demo showcase gained a "Card family" section — one custom style
reskinning several different cards.

## [0.11.0] - 2026-07-07

### Added — flexibility wave 1: archetype style protocols + 6 pilots

First wave of the slot/config/style architecture (see `docs/flexibility-audit-faz1.md`).
Four new archetype style protocols, each mirroring the `CardStyle` idiom
(Configuration + `AnyX` erasure + environment key + `.xStyle(_:)` + `where Self ==`
statics), with the default style extracted pixel-identical from the pilot component:

- **`ListRowStyle`** (`.default` / `.inset`) — pilot `ListRow`, which also gains
  `.leading{}` / `.trailing{}` ViewBuilder slots (the `ListRowTrailing` enum stays).
- **`FieldStyle`** (`.default` / `.underlined`) — pilot `TextInput`, which gains
  `.leading{}` / `.trailing{}` slots; all 21 existing modifiers unchanged.
- **`ChipStyle`** (`.tonal` / `.solid`) — pilot `Chip`; the `ChipSelectionStyle`
  enum shorthand now routes through the same `makeBody` gate as environment styles.
  `Chip.interactive(_:)` deprecated in favour of `.disabled(_:)` (still works).
- **`BarStyle`** (`.default` / `.floating`) — pilot `SheetHeader`, which gains
  `.leading{}`; `surface()`/`showsDivider()` keep working via internal overrides.
- **`MeterStyle`** (`.linear` / `.striped`) — pilot `ProgressBar`; data (fraction,
  fill, track) stays in the component, geometry moves to the style; `steps` is now
  a configuration field handled by the style.
- **`CardStyleConfiguration`** additively gains `isSelected` / `isPressed` /
  `surfaceKey` / `radius`; `DefaultCardStyle` reads surface+radius from it and draws
  a hero border when selected. Pilot `HotelResultCard` routes its shell through
  `.cardStyle` and gains `.media{}` / `.overlay{}` slots.

**Behaviour notes:** defaults are pixel-identical except (1) `HotelResultCard` at
`.soft`/`.elevated` now follows `Card`'s border semantics (shadow only; hairline at
`.none`), and (2) an `exists(false)`+selected `Chip`'s border drops to the disabled
palette (no callers).

**Demo** — new "Flexibility Showcase" gallery page: every pilot shown three ways
(default / slots filled / re-skinned via a custom style defined in the demo target —
the fork-free proof).

## [0.10.0] - 2026-07-07

### Fixed — audit sprint 1: P0 cleanup (all additive, no call-site breaks)

Closes the P0 findings of the non-daisyUI component audit (travel suite, media atoms,
app-shell organisms, form extras).

**Dead API wired**
- `MapCallout.accent(_:)` now tints the border + CTA chevron; `RecentSearchRow.accent(_:)`
  now brand-tints the leading icon tile. (Both stored the value but never read it.)

**Token overloads for raw-`Color` APIs** (originals kept)
- `PriceHistogram.accent(SemanticColor)`, `AmenityGrid.tint(SemanticColor)`,
  `EmptyState.iconForeground(Theme.ForegroundColorKey)` / `.iconBackground(Theme.BackgroundColorKey)` —
  demos no longer unwrap `Theme.shared` by hand.

**Accessibility**
- `NavigationBar` — items take an optional `label`, expose it (or the symbol's base name)
  to VoiceOver, and report `.isSelected`.
- `RollingNumber` — reads the value instead of the 0-9 digit skeleton.
- `ProgressIndicator` — one element: label "Progress", value "N of M" (localized).
- `Steps` — one element per step (title + description, state as value, button trait when
  tappable, `.isSelected` on the active step).
- Chips — `ImageChip`/`CompactChip`/`ChoseChip` now expose button + selected traits
  (they were plain tap gestures); `Chip` reports `.isSelected`; `FilterChip`'s close
  button is labelled "Remove".
- `PriceAlertCard` — the container `.combine` no longer flattens the live Toggle; the
  Toggle is the card's single, fully-labelled VoiceOver element.

**Correctness**
- `GaugeView` — value is clamped into `range`, and the readout is the position within
  the range (no more "7 200%" on non-0…1 ranges).
- `VideoPlayerView` — full macOS parity: the stateful inline player (autoplay, loop,
  mute, progress, overlays, active-gating) now runs on both platforms; only the AVKit
  host view is platform-conditional (`AVPlayerView` on macOS).
- `Steps.small()` — no longer a no-op; compact titles on both axes (and the horizontal
  default title style is now `labelBase600`, matching the vertical axis).

**Localization** — 4 new step-state accessibility keys (en + tr).

### Changed — base-100 component surfaces (daisyUI colour-model alignment)

Card-like components now default to the page's blank surface token **`bgWhite`**
(daisyUI `base-100`) instead of the elevation tint `bgElevatorPrimary`; the tint is
reserved for secondary/nested surfaces (table header strips, zebra rows, selector
fills, device chrome).

- Default flipped on the 11 components that already had `.surface(_:)`:
  `PaymentCardField`, `AgentPriceRow`, `AncillaryCard`, `BoardingPass`,
  `FlightTicketCard`, `HotelResultCard`, `MapCallout`, `PriceAlertCard`, `RoomCard`,
  `StickyBookingBar`, `TicketStub`.
- 11 components with a hardcoded surface gained `.surface(_:)` (default `bgWhite`):
  `ReviewCard`, `FlightCard`, `FlightResultRow`, `LoyaltyCard`, `LocationCard`,
  `DestinationCard`, `FareFamilyCard`, `SheetHeader`, `Footer`, `FilterList`,
  `RecentSearchRow` (bordered variant).
- `Card` (via `DefaultCardStyle`) and `DataTable` rows were already base-100; DataTable's
  header strip + zebra stripes keep the tint deliberately.
- **Migration:** this is a visual default change — `.surface(.bgElevatorPrimary)`
  restores the previous look per component. Snapshots need re-recording.

## [0.9.0] - 2026-07-07

### Added — daisyUI parity sweep (9 new components, 12 upgraded)

Closes the audit against daisyUI's component catalog (61 components, 8 categories).

**New components**
- `Aura` (atom) — breathing glow halo; standalone blob or `.aura(_:radius:intensity:)` modifier.
- `TiltCard` (atom) — touch-adapted hover-3D card; `.tilt3D(maxAngle:shine:radius:)` drag tilt with spring-back and optional specular shine.
- `CodeBlock` (atom) — terminal-style code mockup; `CodeLine` prefixes, per-line semantic highlights, `.copyable()`.
- `ScrubGallery` (molecule) — touch-adapted hover gallery; finger-scrub flips pages, RTL-aware, segment indicator.
- `Dropdown` (molecule) — token-bound anchored action menu; `DropdownItem` roles (incl. `.destructive`), `.divider`, `.edge(_:)` placement, outside-tap dismiss.
- `BrowserFrame` / `WindowFrame` / `PhoneFrame` (organisms) — daisyUI Mockup category: browser chrome, OS window chrome, phone bezel (`.notch(.island/.notch/.none)`) around any content.
- Declarative validation for `TextInput` — `.validate([.required(), .email()], on: .live/.editingEnd/.submit)` + `.onValidation`; rides the existing `ValidationRule` engine and `infoMessages` styling ("reward early, punish late").

**Upgraded (all additive, defaults unchanged)**
- `Spinner` — `SpinnerStyle`: `.ring/.dots/.bars/.ball/.infinity` + `.accent(SemanticColor)` (daisyUI Loading parity).
- `Kbd` — `KbdSize` `.xs/.sm/.md/.lg`.
- `ChatBubble`, `RadialProgress`, `TextLink`, `Checkbox`, `RadioButton`, `ThemeToggle` — `.accent(SemanticColor)` with auto-contrasting foregrounds.
- `Tooltip` — `color: SemanticColor?` tint on both overloads.
- `MultiLineTextInput` — `.size(TextInputSize)` height presets + `.countStyle(_:)` counter parity with TextInput.
- `SegmentedTabBar` — `.pill` style (daisyUI tabs-box): sliding filled pill via `matchedGeometryEffect`.

**Demo** — 9 new gallery entries; 11 usage cards refreshed with the new axes.
**Localization** — 5 new accessibility keys (en + tr).

## [0.8.0] - 2026-07-04

### Changed — travel component flexibility pass (14 components, no breaking changes)

A UX-audited upgrade of the 0.7.0 travel suite (vs. HIG, Dynamic Type & SwiftUI-animation
best practices). Everything is **additive** — existing initialisers and modifiers are
unchanged, so no call site needs migrating.

**Foundation**
- `ComponentDensity` environment (`.componentDensity(.compact/.regular/.spacious)`) — one
  axis tightens/relaxes a whole subtree's spacing.

**Cross-cutting**
- Fixed-height controls now use `scaledControlHeight` / Dynamic-Type clamps (never clip).
- `SeatMap` seats are **44pt** (the HIG minimum touch target), up from 34.
- Reduce-Motion-aware animation throughout (numeric-text prices, spring selections, timer pulse).
- `.redacted(.placeholder)` skeleton loading honoured across the cards.

**Per component**
- `PriceTag` — value semantics (`.free`/`.soldOut`/`.from`), `.animatesValue`, trailing slot.
- `PointsBadge` — scaled height + icon, `.animatesValue`, trailing slot.
- `CountdownTimer` — formats (`.boxed`/`.inline`/`.text`), `.urgentBelow()` escalation + last-10s pulse, `.onExpired` slot.
- `GuestSelector` — `.maxTotal` cabin-capacity cap, `.onChange`.
- `AmenityGrid` — `.limit` progressive disclosure, `.highlighted`.
- `PriceHistogram` — live range readout + `.resultCount`, bound labels, animated bars.
- `InstallmentSelector` — `.recommended` badge, `.surcharge` (interest), spring selection.
- `CurrencyPicker` — `.searchable`, derived country flags, `.recents` section.
- `FlightCard` — custom `.footer` slot, `.favorite($)`, `.scarcity`, `.fareBrand`.
- `FareSummary` — per-line `.info` + `.onInfo`, `.footer` slot, animated total.
- `ReviewCard` — `.stars`, expandable text, tappable photos (`.onPhotoTap`), `.actions` slot.
- `LoyaltyCard` — `.logo` slot, animated points balance.
- `SeatMap` — column/row rulers (`.showsLabels`), new `SeatLegend` (`.legend`).
- `LocationCard` — `.pois` extra pins, `.directions` (opens Apple Maps) / `.onDirections`.

### Added — new atoms & completed deferrals

New CoreImage atoms (still **zero dependencies**):
- `QRCode` — scannable QR (`CIQRCodeGenerator`).
- `Barcode` — Code 128 (`CICode128BarcodeGenerator`) with an optional caption.

Previously-deferred features, now shipped (all additive):
- `LoyaltyCard` — `.flippable()` to a back face with `.membership(.qr / .barcode)`.
- `FlightCard` — `FlightLeg` + `FlightCard(legs:)` multi-leg itineraries (outbound + return,
  per-leg airline & layover); the single-leg path is unchanged.
- `SeatMap` — `.passengers([Passenger], assignment:)` seat-to-traveller assignment (initials +
  active-passenger tabs, `selection` kept in sync) and `.zoomable()` pinch-zoom.
- `LocationCard` — `.snapshot()` renders a static `MKMapSnapshotter` image (cheap in long lists).

Still zero new dependencies; ThemeKit + Demo build clean.

## [0.7.0] - 2026-07-03

### Added — travel component suite (14 components)

Domain components for flight / hotel / car booking, all **token-bound** and
**modifier-based** per the R1–R7 contract (init carries content/bindings; every
appearance axis is a chainable modifier). Registered in the Demo gallery; strings
default to English.

**Atoms**
- `PriceTag` — currency + struck-through original + per-unit suffix + auto discount badge.
- `PointsBadge` — loyalty points/miles pill (earn / redeem / balance).
- `CountdownTimer` — live HH:MM:SS boxes (`TimelineView`), `.urgent` palette, `onFinish`.

**Molecules**
- `GuestSelector` — rooms & guests (adults/children/infants) from `QuantityStepper`, with a `GuestSelection` summary.
- `AmenityGrid` — icon+label amenities, token-tinted, configurable columns.
- `PriceHistogram` — price-distribution bars over a `RangeSlider` (in-range = accent).
- `InstallmentSelector` — instalment plans (per-month + total), interest-free tag (TR taksit).
- `CurrencyPicker` — symbol/code/name rows with a ticked selection; ships `Currency.common`.

**Organisms**
- `FlightCard` — airline · times + airport codes · flight-path line (duration/stops) · price + Select.
- `FareSummary` — itemised fare lines (item/discount/total); total is a hero `PriceTag`.
- `ReviewCard` — single review: `Avatar` + author + date + `ScoreBadge` + text + photo strip.
- `LoyaltyCard` — tier · member · points on a brand gradient + progress to the next tier.
- `SeatMap` — cabin seat grid with aisles, occupied/premium states, multi-select + `maxSelection`.
- `LocationCard` — MapKit map preview + pin + address/distance (lat/lon convenience init).

All reuse existing atoms where natural (PriceTag, Badge, ScoreBadge, Avatar, RangeSlider,
QuantityStepper). MapKit is a system framework, so `LocationCard` stays in the zero-dependency core.

## [0.6.0] - 2026-07-03

### Added — `ThemeKitCalendar`: a token-bound date-range calendar (opt-in add-on)

A new opt-in product wraps [Almanac](https://github.com/isamercan/Almanac) (a SwiftUI
date-range calendar on HorizonCalendar) and drives its colours from ThemeKit tokens —
so the calendar re-skins with the active preset and per-subtree `.theme(_:)` injection,
like every other component.

- **`DateRangePicker`** — a `View` wrapping Almanac's range picker with `.range` /
  `.hotel` / `.rentACar` framing; reads `@Environment(\.theme)` and applies the
  token-derived style automatically. Named to avoid `Foundation.Calendar` and echo
  SwiftUI's `DatePicker`.
- **The bridge** — `CalendarTheme(themeKit:)` / `CalendarStyle.themeKit(_:)` map Almanac's
  ten semantic colour slots to ThemeKit tokens (`ink→text(.textPrimary)`,
  `surface→background(.bgElevatorPrimary)`, `inBetweenFill→palette(.primary100)`, …).
  `.themeKitCalendarStyle(_:)` applies it to any Almanac calendar view.
- **Zero-dep core preserved** — Almanac is a **conditional, iOS-only** dependency of the
  `ThemeKitCalendar` target (`.when(platforms: [.iOS])`); the sources are `#if os(iOS)`
  guarded, so the core stays dependency-free and the package still builds on macOS.
- Adds `Tests/ThemeKitCalendarTests` (iOS lane); `@_exported import Almanac` so one
  `import ThemeKitCalendar` is enough.

## [0.5.0] - 2026-07-02

The modifier refactor (R1–R7) completes: a full-library sweep converts the **58
remaining components** so every public component now follows the same contract —
`init` carries only content, bindings, required data, and primary callbacks;
every appearance/state axis is a chainable, order-free modifier routed through a
single copy-on-write helper. Old inits are removed (clean break, pre-1.0), each
recorded in `.api-breakage-allowlist.txt`.

### ⚠️ Breaking
- **Button family** (`PrimaryButton`/`SecondaryButton`/`OutlineButton`/`GhostButton`,
  9→2 params ×2 inits; `LinkButton` 4→2): `size:`→`.size(_:)`, `block:`→`.fullWidth(_:)`,
  `helperText:`→`.helperText(_:)`, `textStyle:`→`.titleTextStyle(_:)`,
  `confirmsSuccess:`→`.confirmsSuccess(_:)`, `accessibilityID:`→`.a11yID(_:)`,
  `isLoading: Binding<Bool>`→`.loading(_ on: Bool = true)` (the binding was only read).
- **`TextInput` flat init removed** (26 params → `TextInput(_ label:text:)`); the
  `TextInputModel`-based init remains the supported second entry point. New modifiers:
  `.placeholder .icon(leading:trailing:) .addons(before:after:) .secure .clearable
  .maxLength(_:hardLimit:) .showsCount(_:style:) .size .formatter .helperText .errorText
  .warningText .infoMessages .externalFocus .keyboard(_:contentType:submit:capitalization:)
  .autocorrectionDisabled .onCommit` (renamed from `onSubmit:` — avoids native `.onSubmit`).
- **Select family**: `Select` (11→4 ×2), `SelectBox`, `MultiSelect`, `Autocomplete` (×2),
  `SearchBar` (8→1/2 — callbacks moved to `.onSearch/.onSelect/.onCommit`, chrome to
  `.placeholder/.suggestions/.recent(_:onClear:)`).
- **Groups & form controls**: `CheckboxGroup` (`.selectAll/.infoMessages/.optionEnabled`),
  `RadioGroup`, `RadioButtonGroup` (`.groupStyle/.fullWidth/.optionEnabled`), `ToggleGroup`
  (`.optionDescription`), `Checkbox`/`RadioButton` (`.infoMessages`), `ColorField`
  (`.supportsOpacity`), `Fieldset` (`.helper`), `Slider`/`RangeSlider`/`QuantityStepper`
  (`step:`→`.step(_:)`).
- **Chips**: `ChoseChip` (title now positional-first), `CompactChip`, `FilterChip`
  (`.shape/.closable`), `ChipGroup` (`selectionStyle:`→`.chipStyle(_:)`).
- **Organisms**: `Card` (9→3: `.subtitle/.elevation/.contentPadding/.extraAction/.loading`),
  `ListView`, `DataTable`, `NotificationCard` (`type:`→`.variant(_:)`), `ResultView`
  (`.primaryAction/.secondaryAction`), `Hero` (`.subtitle/.cta/.dark`), `BlogCard`,
  `MenuCard`, `PageHeader`, `Gallery`, `PagingCarousel`, `RatingSummary`
  (`.reviews(count:onTap:)`), `RadioCard`/`CheckboxCard` (`.description`), `KeyValueTable`,
  `Diff` (`aspectRatio:`→`.aspect(_:)` — avoids native `.aspectRatio`), `UploadList`,
  `Accordion` (`leadingSystemImage:`→`.icon(_:)`), `AccordionGroup` (`.mode`).
- **Atoms**: `Title`, `InlineText` (`style:`→`.inlineStyle(_:)`), `Icon`
  (`.size/.color` — ~94 call sites migrated), `Spinner`, `Skeleton`
  (`.size(width:height:)`), `ProgressBar` (`.showsPercentage/.status`), `Rating`
  (`.layout/.countLabel`), `Ribbon` (`.color`), `AvatarGroup`
  (`.size/.maxVisible/.fillColor`), `AnimatedImage`, `TextLink` (`.underline`).
- **ThemeKitLottie**: `LottieEmptyState` (inits keyed on the media source, EmptyState-style;
  `.loop/.animationHeight/.message/.primaryAction`), `LottieIllustration` (`.loop`).

All call sites in the library, Demo app, gallery usage snippets, tests, screenshot/GIF
generators, and DocC samples migrated in the same change; defaults are preserved, so
rendering is unchanged.

## [0.4.0] - 2026-06-30

The modifier-based component refactor (COMPONENT_REFACTOR_RULES R1–R7): bloated
inits collapse to `content + action`; every appearance/state axis becomes a
chainable, order-free modifier from a shared vocabulary. Rolling out
component-by-component.

### Added
- **`TimeField`** — a dedicated time-of-day field: 12/24-hour `hourCycle`,
  `minuteInterval` snapping, optional `range`, clearable, leading icon, validation
  messages. The time-first companion to `DateField` (which also does time via
  `.components(.time)`).
- **`Sidebar`** — a token-bound vertical navigation organism: titled sections,
  per-item SF Symbol + badge, accent-tinted selection, and `header`/`footer`
  slots. Complements the bottom `NavigationBar` for macOS / iPad / regular-width
  layouts.

### ⚠️ Breaking
- **`InfoBanner` init reduced to `InfoBanner(_:title:links:)`.** The `message`
  content, the optional `title`, and the inline-`links` data stay in init; the 6
  appearance/state/callback parameters moved to modifiers: `type:`→`.variant(_:)`,
  `showIcon:`→`.showsIcon(_ on: Bool = true)`, `banner:`→`.fullWidth(_ on: Bool = true)`,
  the `actionTitle:`/`onAction:` pair→`.action(_:onAction:)`, `onDismiss:`→`.onDismiss(_:)`.
  Migration:
  `InfoBanner("Saved", type: .success, banner: true, onDismiss: { … })`
  → `InfoBanner("Saved").variant(.success).fullWidth().onDismiss { … }`.
- **`ThemeToggle` init reduced to `ThemeToggle(isOn:)`.** Only the `isOn` binding
  stays in init; the 3 appearance/state parameters moved to modifiers:
  `isLoading:`→`.loading(_ on: Bool = true)`, and the paired
  `onSystemImage:`/`offSystemImage:` knob glyphs→`.symbols(on:off:)`. Migration:
  `ThemeToggle(isOn: $on, isLoading: true, onSystemImage: "checkmark", offSystemImage: "xmark")`
  → `ThemeToggle(isOn: $on).loading().symbols(on: "checkmark", off: "xmark")`.
- **`SegmentedControl` init reduced to `SegmentedControl(_:selection:)`.** Both
  overloads (`[SegmentItem]` and `[String]`) keep only their items data + the
  `selection` binding; the 2 appearance parameters moved to modifiers:
  `block:`→`.fullWidth(_ on: Bool = true)` (default `true`, preserving the old
  default), `size:`→`.size(_:)`. The per-item `SegmentItem.isEnabled` remains
  item data. Migration:
  `SegmentedControl(items, selection: $i, block: false, size: .large)`
  → `SegmentedControl(items, selection: $i).fullWidth(false).size(.large)`.
- **`Coupon` init reduced to `Coupon(code:label:onCopy:)`.** The code, the label
  copy and the `onCopy` callback stay in init; the 1 appearance parameter moved to
  a modifier: `style:`→`.couponStyle(_:)` (renamed to avoid the generic `style`
  clash + match `BadgeStyle`). Migration:
  `Coupon(code: "UXMUQ", style: .filled, onCopy: { … })`
  → `Coupon(code: "UXMUQ", onCopy: { … }).couponStyle(.filled)`.
- **`ImageChip` (the `Chips` family chip) init reduced to
  `ImageChip(isSelected:url:)`.** The `isSelected` binding and the `url` data stay
  in init; `size:`→`.size(_:)`. The component-level `isEnabled:` parameter is
  **removed (R3)** in favor of native `@Environment(\.isEnabled)` + `.disabled(_:)`.
  Migration:
  `ImageChip(isSelected: $on, url: u, size: .large, isEnabled: ok)`
  → `ImageChip(isSelected: $on, url: u).size(.large).disabled(!ok)`.
- **`StatusDot` init reduced to `StatusDot(_ kind:label:)`.** The status kind and
  the (content) label stay in init; the 2 appearance/state parameters moved to
  modifiers: `size:`→`.size(_:)`, `pulse:`→`.pulse(_:)`. Migration:
  `StatusDot(.online, size: 14, label: "Online", pulse: true)`
  → `StatusDot(.online, label: "Online").size(14).pulse()`.
- **`RollingNumber` init reduced to `RollingNumber(_ value:)`.** The value stays
  in init; the 3 appearance parameters moved to modifiers: `size:`→`.size(_:)`,
  `weight:`→`.weight(_:)`, `color:`→`.color(_:)`. Migration:
  `RollingNumber(1284, size: 40, weight: .semibold, color: c)`
  → `RollingNumber(1284).size(40).weight(.semibold).color(c)`.
- **`InputLabel` init reduced to `InputLabel(_ text:)`.** The label text stays in
  init; the 3 appearance/state parameters moved to modifiers: `isRequired:`→
  `.required(_:)` (trailing asterisk), `hasInfo:`→`.hasInfo(_:)` (info glyph),
  `hasError:`→`.hasError(_:)` (error-color treatment). Migration:
  `InputLabel("Email", isRequired: true, hasInfo: true)`
  → `InputLabel("Email").required().hasInfo()`.
- **`Chip` init reduced to `Chip(_ title:isSelected:)`.** The title and the
  `isSelected` binding stay in init; the 2 appearance parameters moved to
  modifiers: `size:`→`.size(_:)`, `selectionStyle:`→`.chipStyle(_:)` (renamed to
  avoid the generic `selectionStyle` clash + match `BadgeStyle`). The existing
  `.icon/.rating/.exists/.interactive/.expands` modifiers now route through the
  shared copy-on-write helper. Migration:
  `Chip("Recommended", isSelected: $on, size: .large, selectionStyle: .solid)`
  → `Chip("Recommended", isSelected: $on).size(.large).chipStyle(.solid)`.
- **`Upload` init reduced to `Upload(prompt:files:onPick:onRemove:onRetry:)`.**
  The prompt copy, the files data array and the pick/remove/retry callbacks stay
  in init; the 2 config parameters moved to modifiers: `buttonTitle:`→
  `.buttonTitle(_:)`, `maxCount:`→`.maxCount(_:)`. (`UploadList` is unchanged.)
  Migration:
  `Upload(prompt: p, buttonTitle: "Add photo", files: f, maxCount: 3, onPick: …, onRemove: …)`
  → `Upload(prompt: p, files: f, onPick: …, onRemove: …).buttonTitle("Add photo").maxCount(3)`.
- **`RadioCard` / `CheckboxCard` drop their `isEnabled:` init parameter (R3).**
  The disabled state is now native: `@Environment(\.isEnabled)` + the standard
  `.disabled(_:)` modifier (which cascades to the card's button). Inits are now
  `RadioCard(_ title:description:isSelected:action:)` and
  `CheckboxCard(_ title:description:isChecked:action:)`. Migration:
  `RadioCard("Express", isSelected: x, isEnabled: y) { … }`
  → `RadioCard("Express", isSelected: x) { … }.disabled(!y)`.
- **`SegmentedTabBar` init reduced to `SegmentedTabBar(_ items:selection:onClose:onAdd:)`.**
  Both overloads (`[TabItem]` and `[String]`) keep the items data, the `selection`
  binding and the optional close/add callbacks in init; the 2 appearance
  parameters moved to modifiers: `scrollable:`→`.scrollable(_ on:)`,
  `style:`→`.tabStyle(_:)` (renamed to avoid the generic `style` clash + match
  `BadgeStyle`). The per-item `TabItem.isEnabled` is unchanged. Migration:
  `SegmentedTabBar(tabs, selection: $i, scrollable: true, style: .card)`
  → `SegmentedTabBar(tabs, selection: $i).scrollable().tabStyle(.card)`.
- **`ImageCollage` init reduced to `ImageCollage(_ urls:onTap:)`.** The image URLs
  and the per-tile tap callback stay in init; the 3 layout/appearance parameters
  moved to modifiers: `height:`→`.height(_:)`, `spacing:`→`.spacing(_:)`,
  `cornerRadius:`→`.cornerRadius(_:)`. Migration:
  `ImageCollage(urls, height: 220, cornerRadius: 8) { open($0) }`
  → `ImageCollage(urls) { open($0) }.height(220).cornerRadius(8)`.
- **`ChatBubble` init reduced to `ChatBubble(_ text:author:time:)`.** The message
  text, author and timestamp (all content) stay in init; the 2 appearance
  parameters moved to modifiers: `side:`→`.side(_:)`,
  `avatarSystemImage:`→`.icon(_:)`. Migration:
  `ChatBubble("Hi!", side: .outgoing, time: "09:24", avatarSystemImage: "person.fill")`
  → `ChatBubble("Hi!", time: "09:24").side(.outgoing).icon("person.fill")`.
- **`Steps` init reduced to `Steps(_ steps:onSelect:)`.** The steps data array and
  the tap-to-navigate callback stay in init; the 3 appearance/layout parameters
  moved to modifiers: `axis:`→`.axis(_:)`, `small:`→`.small(_ on:)`,
  `progressDot:`→`.progressDot(_ on:)`. (`Steps.Step` is unchanged.) Migration:
  `Steps(steps, axis: .vertical, progressDot: true) { active = $0 }`
  → `Steps(steps) { active = $0 }.axis(.vertical).progressDot()`.
- **`Tag` init reduced to `Tag(_ text:onRemove:)`.** The text and the optional
  removal callback stay in init; the 3 appearance parameters moved to modifiers:
  `leadingSystemImage:`→`.icon(_:)`, `style:`→`.tagStyle(_:)` (renamed to avoid the
  generic `style` clash + match `BadgeStyle`), `variant:`→`.variant(_:)`. Migration:
  `Tag("Sold out", leadingSystemImage: "xmark", style: .error, variant: .solid, onRemove: { })`
  → `Tag("Sold out", onRemove: { }).icon("xmark").tagStyle(.error).variant(.solid)`.
- **`Swap` init reduced to `Swap(isOn:)`.** The `isOn` binding stays in init; the
  two glyphs and the appearance/state parameters moved to modifiers:
  `on:`/`off:`→`.symbols(on:off:)` (grouped), `size:`→`.size(_:)`,
  `rotate:`→`.rotate(_ on:)`. (`.a11yID(_:)` is unchanged — now routed through the
  shared copy-on-write helper.) Migration:
  `Swap(isOn: $on, on: "xmark", off: "line.3.horizontal", size: 32)`
  → `Swap(isOn: $on).symbols(on: "xmark", off: "line.3.horizontal").size(32)`.
- **`RemoteImage` init reduced to `RemoteImage(_ url:)`.** The two data overloads
  `RemoteImage(_ url:, ratio: String)` and `RemoteImage(_ url:, ratio:
  RemoteImageRatio)` are preserved (they carry a genuine aspect-ratio source); the
  4 appearance parameters moved to modifiers: `aspectRatio:`→`.ratio(_:)` (renamed
  to avoid clashing with SwiftUI's native `.aspectRatio`), `contentMode:`→
  `.contentMode(_:)`, `cornerRadius:`→`.cornerRadius(_:)`, `circle:`→`.circle(_
  on:)`. Migration:
  `RemoteImage(url, aspectRatio: 1, cornerRadius: 8, circle: true)`
  → `RemoteImage(url).ratio(1).cornerRadius(8).circle()`;
  `RemoteImage(url, ratio: "16:9", cornerRadius: 12)`
  → `RemoteImage(url, ratio: "16:9").cornerRadius(12)`;
  `RemoteImage(url, contentMode: .fit)` → `RemoteImage(url).contentMode(.fit)`.
- **`GaugeView` init reduced to `GaugeView(value:in:label:)`.** The value, its
  range and the optional caption stay in init; the 2 appearance/state parameters
  moved to modifiers: `style:`→`.gaugeStyle(_:)` (renamed to avoid the generic
  `style` clash + match `GaugeView.Style`), `showsValue:`→`.showsValue(_ on:)`.
  Migration:
  `GaugeView(value: 0.4, label: "Disk", style: .linear, showsValue: false)`
  → `GaugeView(value: 0.4, label: "Disk").gaugeStyle(.linear).showsValue(false)`.
- **`DividerView` init reduced to `DividerView(_ title:)`.** The optional inline
  title stays in init; the 4 appearance/state parameters moved to modifiers:
  `size:`→`.size(_:)`, `axis:`→`.axis(_:)`, `dashed:`→`.dashed(_ on:)`,
  `titleAlign:`→`.titleAlign(_:)`. Migration:
  `DividerView(dashed: true, title: "OR", titleAlign: .center)`
  → `DividerView("OR").dashed().titleAlign(.center)`;
  `DividerView(size: .small)` → `DividerView().size(.small)`;
  `DividerView(axis: .vertical)` → `DividerView().axis(.vertical)`.
- **`Timeline` init reduced to `Timeline(_ items:)`.** The 4 layout/state
  parameters moved to modifiers: `axis:`→`.axis(_:)`, `mode:`→`.mode(_:)`,
  `reverse:`→`.reversed(_ on:)`, `pending:`→`.pending(_:)`. Migration:
  `Timeline(items, axis: .horizontal, mode: .alternate, reverse: true, pending: "Awaiting…")`
  → `Timeline(items).axis(.horizontal).mode(.alternate).reversed().pending("Awaiting…")`.
  (`Timeline.Item` is unchanged.)
- **`PromoBanner` init reduced to `PromoBanner(_ title:action:)`.** The 4 other
  parameters moved to modifiers: `subtitle:`→`.subtitle(_:)`,
  `systemImage:`→`.icon(_:)`, `ctaTitle:`→`.ctaTitle(_:)` (renders only when
  paired with the init `action`), `tint:`→`.color(_:)` (renamed to the standard
  color vocabulary). Migration:
  `PromoBanner(title: "Early booking", subtitle: "Save 30%", systemImage: "sun.max.fill", ctaTitle: "Explore", tint: .dark, action: { open() })`
  → `PromoBanner("Early booking", action: { open() }).subtitle("Save 30%").icon("sun.max.fill").ctaTitle("Explore").color(.dark)`.
- **`FloatingActionButton` init reduced to
  `FloatingActionButton(systemImage:actions:action:)`.** The content glyph, the
  speed-dial `actions:` data array and the primary `action:` (no-speed-dial mode)
  stay in init; the 3 appearance params moved to modifiers:
  `shape:`→`.shape(_:)`, `color:`→`.color(_:)`, `badge:`→`.badge(_:)`. Migration:
  `FloatingActionButton(systemImage: "bell.fill", shape: .square, color: .error, badge: 3, action: { open() })`
  → `FloatingActionButton(systemImage: "bell.fill", action: { open() }).shape(.square).color(.error).badge(3)`.
  (`FABAction` is unchanged.)
- **`Callout` init reduced to `Callout(_ text:)`.** The 6 other parameters moved
  to modifiers: `type:`→`.variant(_:)`, `style:`→`.calloutStyle(_:)` (renamed to
  avoid the generic `style` clash + match `CalloutStyle`),
  `showIcon:`→`.showsIcon(_ on:)`, `actionTitle:`/`onAction:`→
  `.action(_ title:onAction:)` (grouped), `onClose:`→`.onClose(_:)`. Migration:
  `Callout("Saved", type: .success, style: .soft, actionTitle: "Undo", onAction: { undo() })`
  → `Callout("Saved").variant(.success).calloutStyle(.soft).action("Undo") { undo() }`.
- **`OTPInput` init reduced to `OTPInput(code:onComplete:)`.** The 6 other
  parameters moved to modifiers: `digitCount:`→`.digitCount(_:)`,
  `isSecure:`→`.secure(_ on:)`, `errorText:`→`.errorText(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, and `resendInterval:`/`onResend:`→
  `.resend(interval:onResend:)` (grouped). Migration:
  `OTPInput(code: $code, digitCount: 6, isSecure: true, onComplete: { verify($0) }, resendInterval: 30, onResend: { resend() })`
  → `OTPInput(code: $code) { verify($0) }.digitCount(6).secure().resend(interval: 30) { resend() }`.
- **`FileInput` init reduced to `FileInput(_ label:onPick:)`.** The 5 other
  parameters moved to modifiers: `fileName:`→`.fileName(_:)` (the bound display
  value), `buttonTitle:`→`.buttonTitle(_:)`, `placeholder:`→`.placeholder(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, `onClear:`→`.onClear(_:)`. Migration:
  `FileInput(label: "Passport", fileName: name, onPick: { pick() }, onClear: { clear() })`
  → `FileInput("Passport") { pick() }.fileName(name).onClear { clear() }`.
- **`AlertToast` init reduced to `AlertToast(_ title:)`.** The 6 other
  parameters moved to modifiers: `message:`→`.message(_:)`,
  `type:`→`.variant(_:)`, `systemImage:`→`.icon(_:)`,
  `isLoading:`→`.loading(_ on:)`, `action:`→`.action(_:)`,
  `onClose:`→`.onClose(_:)`. Migration:
  `AlertToast("Saved", type: .success, onClose: { })`
  → `AlertToast("Saved").variant(.success).onClose { }`.
- **`Badge` init reduced to `Badge(_ text:action:)`.** The 4 remaining
  appearance params moved to modifiers: `style:`→`.badgeStyle(_:)` (renamed to
  avoid the generic `style` clash + match `BadgeStyle`),
  `variant:`→`.variant(_:)`, `size:`→`.size(_:)`,
  `leadingSystemImage:`→`.icon(_:)`. The pre-existing modifiers
  (`.badgeShape/.trailingIcon/.badgeColor/.gradient/.highlighted`) were rerouted
  through the shared `copy(_:)` helper (R2). Migration:
  `Badge("Sold out", style: .error, variant: .solid, leadingSystemImage: "xmark")`
  → `Badge("Sold out").badgeStyle(.error).variant(.solid).icon("xmark")`.
- **`Avatar` init reduced to `Avatar(_ content:)`.** Both inits (size-tier and
  numeric `dimension:`) removed. The config params moved to modifiers:
  `size:`→`.size(_:)`, `dimension:`→`.dimension(_:)`,
  `background:`→`.fillColor(_:)` (renamed to avoid clashing with SwiftUI's
  `.background`), `shape:`→`.shape(_:)`,
  `presence:`/`presencePulse:`→`.presence(_ kind:pulse:)` (grouped). Migration:
  `Avatar(.initials("AB"), size: .lg, background: .dark, shape: .square)`
  → `Avatar(.initials("AB")).size(.lg).fillColor(.dark).shape(.square)`.
  (`AvatarGroup` is unchanged.)
- **`ThemeButton` init reduced to `ThemeButton(_ title:action:)`.** All
  appearance/state parameters moved to modifiers:
  `color:` → `.color(_:)`, `variant:` → `.variant(_:)`, `size:` → `.size(_:)`,
  `shape:` → `.shape(_:)`, `block:` → `.fullWidth(_:)`,
  `isLoading: Binding<Bool>` → `.loading(_ on:)`,
  `systemImage:`/`iconPosition:` → `.icon(leading:trailing:)`,
  `accessibilityID:` → `.a11yID(_:)`, and
  `isEnabled: Binding<Bool>` → native `.disabled(_:)` (R3). The
  `ButtonIconPosition` enum is removed (encode position via `.icon`'s
  `leading:`/`trailing:` slots). Migration:
  `ThemeButton("Save", color: .accent, variant: .soft, block: true) { save() }`
  → `ThemeButton("Save") { save() }.color(.accent).variant(.soft).fullWidth()`.
- **`ListRow` init reduced to `ListRow(_ title:action:)`.** The 12 other
  parameters moved to modifiers: `subtitle:`→`.subtitle(_:)`,
  `number:`→`.number(_:)`, `size:`→`.size(_:)`,
  `leadingSystemImage:`→`.icon(_:)`, `leadingImageURL:`→`.leadingImage(_:)`,
  `leadingSelection:`→`.leadingSelection(_:)`, `alertCount:`→`.alertCount(_:)`,
  `badge:`→`.badge(_:)`, `meta:`→`.meta(_:)`, `infos:`→`.infos(_:)`,
  `isSelected:`→`.selected(_:)`, `multilineTitle:`→`.multilineTitle(_:)`,
  `infoAction:`→`.onInfo(_:)`, `trailing:`→`.trailing(_:)`.
- **`DateField` init reduced to `DateField(_ label:date:)`.** The 8 other
  parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `range:`→`.range(_:)`, `style:`→`.style(_:)`, `locale:`→`.locale(_:)`,
  `components:`→`.components(_:)`, `infoMessages:`→`.infoMessages(_:)`,
  `allowClear:`→`.clearable(_ on:)`, `leadingSystemImage:`→`.icon(_:)`.
  (`accessibilityID:`→`.a11yID(_:)` and native `.disabled(_:)` already applied.)
  Migration:
  `DateField(label: "Check-in", date: $d, style: .long, allowClear: true, leadingSystemImage: "calendar")`
  → `DateField("Check-in", date: $d).style(.long).clearable().icon("calendar")`.
- **`TreeSelect` init reduced to `TreeSelect(_ label:nodes:selection:initiallyExpanded:)`.**
  The 5 config parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `cascade:`→`.cascade(_ on:)`, `searchable:`→`.searchable(_ on:)`,
  `isLoading:`→`.loading(_ on:)`, `isNodeEnabled:`→`.nodeEnabled(_:)`.
  (`nodes`/`selection`/`initiallyExpanded` stay in init — required data, binding,
  and `@State` seed.) Migration:
  `TreeSelect(label: "Cities", nodes: tree, selection: $set, cascade: true, searchable: true)`
  → `TreeSelect("Cities", nodes: tree, selection: $set).cascade().searchable()`.
- **`RadialProgress` init reduced to `RadialProgress(_ value:)`.** The 7
  appearance parameters moved to modifiers: `size:`→`.size(_:)`,
  `lineWidth:`→`.lineWidth(_:)`, `showLabel:`→`.showsLabel(_ on:)`,
  `status:`→`.status(_:)`, `dashboard:`→`.dashboard(_ on:)`,
  `tint:`→`.ringColor(_:)` (renamed to avoid clashing with SwiftUI's `.tint`),
  `accessibilityLabel:`→`.a11yLabel(_:)` (renamed to avoid clashing with
  SwiftUI's `.accessibilityLabel`). Migration:
  `RadialProgress(value: 0.7, size: 80, lineWidth: 8, dashboard: true)`
  → `RadialProgress(0.7).size(80).lineWidth(8).dashboard()`.
- **`InputNumber` init reduced to `InputNumber(_ label:value:range:)`.** The 5
  remaining init parameters moved to modifiers: `step:`→`.step(_:)`,
  `unit:`→`.unit(_:)`, `hint:`→`.hint(_:)`, `errorText:`→`.errorText(_:)`,
  `large:`→`.large(_ on:)`. (`.editable/.hasInfo/.onValueChange/.a11yID` were
  already modifiers; they now route through the shared copy-on-write helper.)
  Migration:
  `InputNumber(label: "Max price", value: $n, range: 0...10000, step: 50, unit: "$")`
  → `InputNumber("Max price", value: $n, range: 0...10000).step(50).unit("$")`.
- **`RadioButton` init reduced to `RadioButton(_ label:isSelected:infoMessages:)`.**
  The 5 appearance parameters moved to modifiers: `type:`→`.type(_:)`,
  `style:`→`.radioStyle(_:)`, `padding:`→`.gap(_:)` (renamed to avoid clashing
  with SwiftUI's `.padding`; it's the radio↔label gap),
  `backgroundColor:`→`.fillColor(_:)` (renamed to avoid clashing with SwiftUI's
  `.background`), `verticalAlignment:`→`.alignment(_:)`. (`label`/`isSelected`/
  `infoMessages` stay in init — content, binding, and required validation data;
  size already native `.controlSize(_:)`, `disabled` already native, and
  `.a11yID(_:)` already a modifier.) The `tag:`-based convenience init dropped its
  `style:`/`padding:`/`backgroundColor:` parameters too. Migration:
  `RadioButton("Remember me", isSelected: $on, type: .check, style: .inner, padding: .medium)`
  → `RadioButton("Remember me", isSelected: $on).type(.check).radioStyle(.inner).gap(.medium)`.
- **`Checkbox` init reduced to `Checkbox(_ label:isChecked:infoMessages:)`.** The
  4 appearance parameters moved to modifiers: `customSize:`→`.customSize(_:)`,
  `type:`→`.type(_:)`, `isIndeterminate:`→`.indeterminate(_ on:)`,
  `alignment:`→`.alignment(_:)`. (`label`/`isChecked`/`infoMessages` stay in init —
  content, binding, and required validation data; size already native
  `.controlSize(_:)`, `disabled` already native, and `.a11yID(_:)` already a
  modifier — now rerouted through the shared `copy(_:)` helper.) Migration:
  `Checkbox("Accept", isChecked: $on, type: .inner, isIndeterminate: mixed)`
  → `Checkbox("Accept", isChecked: $on).type(.inner).indeterminate(mixed)`.
- **`MultiLineTextInput` init reduced to `MultiLineTextInput(_ label:text:)`.** The
  5 config parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `characterLimit:`→`.characterLimit(_:)`, `errorText:`→`.errorText(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, `minHeight:`→`.minHeight(_:)`.
  (`label`/`text` stay in init — content and binding; `disabled` already native,
  and `.a11yID(_:)` already a modifier.) Migration:
  `MultiLineTextInput("Notes", text: $t, placeholder: "…", characterLimit: 200)`
  → `MultiLineTextInput("Notes", text: $t).placeholder("…").characterLimit(200)`.
- **`ProgressIndicator` init reduced to `ProgressIndicator(variant:current:total:)`.**
  The 4 appearance parameters moved to modifiers: `size:`→`.size(_:)`,
  `videoProgress:`→`.videoProgress(_:)`, `stepText:`→`.stepText(_:)`,
  `cornerRadius:`→`.cornerRadius(_ on:)`. (`variant`/`current`/`total` stay in init —
  the core kind plus required data.) Migration:
  `ProgressIndicator(variant: .video, current: 3, total: 5, videoProgress: 0.5, stepText: .slash)`
  → `ProgressIndicator(variant: .video, current: 3, total: 5).videoProgress(0.5).stepText(.slash)`.
- **`Stat` init reduced to `Stat(title:value:)`** (both the `String` and `Int`
  value overloads). The 6 other parameters moved to modifiers:
  `prefix:`→`.prefix(_:)`, `suffix:`→`.suffix(_:)`, `isLoading:`→`.loading(_ on:)`,
  `description:`→`.description(_:)`, `systemImage:`→`.icon(_:)`,
  `trend:`→`.trend(_:)`. (`.statStyle(_:)` layout is unchanged.) Migration:
  `Stat(title: "Bookings", value: "1,284", systemImage: "ticket", trend: .up("+12%"))`
  → `Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))`.
- **`EmptyState` inits reduced to the media + `title`.** The three inits now key
  on the media variant — `EmptyState(_ title:)` (SF Symbol), `EmptyState(image:title:)`,
  `EmptyState(animatedURL:title:)` — and the other parameters moved to modifiers:
  `systemImage:`→`.icon(_:)`, `message:`→`.message(_:)`,
  `imageMaxHeight:`→`.imageMaxHeight(_:)`, `iconForeground:`→`.iconForeground(_:)`,
  `iconBackground:`→`.iconBackground(_:)`, `iconCircleSize:`→`.iconCircleSize(_:)`,
  `buttonTitle:`/`action:`→`.primaryAction(_ title:action:)`,
  `secondaryTitle:`/`onSecondary:`→`.secondaryAction(_ title:action:)`. Migration:
  `EmptyState(systemImage: "tray", title: "Empty", message: "…", buttonTitle: "Retry", action: { })`
  → `EmptyState("Empty").icon("tray").message("…").primaryAction("Retry") { }`.

## [0.2.0] - 2026-06-28

The theming release: per-subtree theming, a full singleton→environment migration, the
`ButtonStyle`-shaped style protocols, a micro-animation system, Ant Design feature
parity across the catalog, and the supporting docs/CI/test layer. Also a rename.

### ⚠️ Breaking
- **Renamed the package `GlobalUIComponents` → `ThemeKit`** and rebranded the
  `Global`-prefixed public API to `ThemeKit`. Update the SPM dependency, the product
  name in your target, and `import GlobalUIComponents` → `import ThemeKit`.

### Added
- **Per-subtree theming** — `EnvironmentValues.theme` (defaulting to `Theme.shared`,
  crash-proof) and a `.theme(_:)` modifier. Inject any `Theme` into a subtree and
  every component inside re-skins to it, with no `Theme.shared` mutation. Bundled
  themes (`ocean`, `sunset`) and on-device generation (`applyGenerated(primaryHex:)`).
- **Style protocols** (the `ButtonStyle` idiom) — `.cardStyle(_:)` (surface),
  `.statStyle(_:)` (layout) and `.selectStyle(_:)` (field chrome), each with stock +
  example styles; appearance is supplied by a style without editing the component.
- **Micro-animation system** — subtle motion on selection/input, overlays, value/data
  and navigation, toggleable **theme-wide and per-component**, and always yielding to
  Reduce Motion.
- **Ant Design feature parity** across the catalog, including: Tooltip placement +
  color variants + self-trigger, Popconfirm 4-way placement + async confirm, async
  AutoComplete with loading/empty states, Upload progress/retry/`maxCount`, Timeline
  modes + reverse, Slider marks + `onChangeEnd` + adjustable VoiceOver, InputNumber
  editable entry/step/unit, TreeSelect loading/disabled/empty, Breadcrumb `maxItems`
  collapse, Avatar presence dot, Statistic animated value, Table pagination, Segmented
  block/size/disabled, Radio/Checkbox group disabled, Alert closable/action/icon,
  Empty secondary action, Tag semantic colors, and more.
- **`PreviewMatrix`** — a preview scaffold laying a component's states out as rows ×
  appearance columns (light/dark, opt-in XL Dynamic Type / RTL).
- **Theme Injection demo** in the gallery (live theme picker) with `-openDemo` /
  `-injectTheme` launch arguments for screenshot automation.
- **Component gallery** in the README — 87 rendered screenshots plus animated GIF
  previews for the overlay components.

### Changed
- **Singleton → environment migration complete** — every component now reads its
  palette from `@Environment(\.theme)` instead of `Theme.shared`: view bodies (580
  reads), private/sub-directory views, enum color resolvers (now `func(_ theme:)`),
  overlay host `ViewModifier`s, and extension-method statics (via wrapper views).
  **Zero `Theme.shared` color reads remain in components.** Non-breaking and
  pixel-identical (the environment defaults to `Theme.shared`).
- `Hero`'s convenience background now defaults to a theme-aware `HeroSurface` view
  instead of a `Theme.shared` color value (source-compatible via type inference).
- Per-symbol DocC `///` documentation added to 86 component view structs.

### Performance
- `LazyVStack` row stacks in `ListView` and `DataTable` (lazy row realization).

### Fixed
- Screenshot generator renders `TextField`-based components correctly (no yellow
  placeholder) via a hosted offscreen window path.
- `record-gif` script no longer misreads a trailing ellipsis as part of `$DEVICE`.

### Internal
- `$0` local CI (`make ci` + pre-push hook) and a cost-resilient GitHub Actions
  pipeline; build-only DocC for the private repo.
- Architecture audit + execution roadmap (`docs/AUDIT.md`) — assessed at Level 4 and
  driven to **Level 5 (reference-grade)**.
- Regression test asserting `.theme(_:)` injection actually re-skins components and
  leaves `Theme.shared` untouched.

## [0.1.1] - 2026-06-25
- Early token + component foundation (pre-rename, as `GlobalUIComponents`).

## [0.1.0] - 2026-06-25
- Initial tagged release.

[0.2.0]: https://github.com/isamercan/ThemeKit/releases/tag/v0.2.0
[0.1.1]: https://github.com/isamercan/ThemeKit/releases/tag/v0.1.1
[0.1.0]: https://github.com/isamercan/ThemeKit/releases/tag/v0.1.0
