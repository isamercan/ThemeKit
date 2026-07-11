# ThemeKit Component Compliance Audit — v2

**Scope:** all 242 `.swift` files under `Sources/ThemeKit/Components` (56 Atoms · 100 Molecules · 86 Organisms), of which ~215 ship a component and ~27 are support/infra.
**Rubric:** the 6 house rules from `.claude/skills/themekit-authoring/SKILL.md`, scored on 5 axes.
**Method:** 13 parallel readers scored every file cell-by-cell; two noisy axes (dark-preview, localization) were re-verified by grep; **v2 folds in an architect review** that spot-checked 16 claims against source, caught 2 false positives + 2 false negatives, and re-weighted the priorities. **Audit only — no source was changed.**

> **What changed v1 → v2** (from the architect review)
> - **Removed 2 false positives:** `Diff` Token ❌ and `ScrubGallery :149` were **preview content**, not body — re-triaged under the same "preview-only ≠ violation" standard already applied to KanbanBoard.
> - **Added 2 false negatives:** `SeatCell` ships `currencyCode: String = "TRY"` in a **public init default** (`:39`); **`AnimatedImage` runs its own `URLSession` fetch inside the component** (`:69`) — a **House-Rule-1 (stateless / no network) violation** that the 5 scored axes never measured.
> - **Systemic axes pulled out of per-component scores.** "No dark preview" fails ~206/215 components *identically*; scoring it per-component manufactured a ~95-file noise tier. It is now **one infra workstream**, not 206 demerits.
> - **Glyph-font count de-rated.** The SKILL bans `.font(.system(size:))` **for text**, not for metric-derived symbol sizes (`SKILL.md:125,:127-129`). The 172-site figure overstates the *actionable* surface ~2–3×; the sweep is now split text vs symbol.
> - **Re-prioritized:** brand-neutrality / i18n-in-public-defaults → **P0**; `variant:`-in-init items → **gated on [ADR-0001](docs/ADR-0001-core-kind-in-init.md)**; the 8-site decorative-white cluster → **one coordinated fix per [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md)**.

Cell scoring: `✅` pass · `🟡` partial · `❌` fail · `–` N/A. **Raw violation score = (❌ × 2) + (🟡 × 1)** over 5 axes — retained as mechanical evidence, but **superseded for sequencing by the corrected priority ranking below**, because equal weights let cosmetic partials outrank API-shape and brand defects.

| # | Axis | House rule |
|---|---|---|
| 1 | **Token-fed** | No raw `Color`/hex/magic `CGFloat`; tokens / `SemanticColor` / `RadiusRole` / `SpacingKey` / `textStyle`. Signatures too. |
| 2 | **Copy-on-write** | Appearance in chainable `copy{}` modifiers, not init args. |
| 3 | **Init = content** | `init` takes only content/bindings/actions — *see [ADR-0001](docs/ADR-0001-core-kind-in-init.md) for the "core kind" exception*. |
| 4 | **a11y / RTL / i18n** | `accessibilityLabel` on non-text controls; strings via `String(themeKit:)`; RTL-mirrored geometry; captured-locale formatting. |
| 5 | **#Preview all variants** | A `#Preview` exercising every variant **and** a dark/themed case. |

> **Two unaudited axes** the 5 columns never measured but the SKILL cares about — treat as known gaps, not "clean": **House Rule 1** (stateless, no `Task`/network — one confirmed violation, `AnimatedImage`), **slot vocabulary** conformance, **style-protocol** pattern for multi-archetype organisms, **controlled/uncontrolled** state, **deprecation-hatch** hygiene, Dynamic-Type clipping. A cheap follow-up grep pass is listed in P2.

---

## Verified facts (grep-confirmed)

- **Dark-preview coverage = 9 / 215 components** (4 use the `PreviewMatrix` helper: Avatar, Tag, TrendChip, Stat; 5 set dark manually incl. CloseButton). The gap is real and systemic → **infra fix, not per-component**.
- **Localization wrapper = `String(themeKit:)`** (bundle `.module`): **267** call sites, **0** `String(localized:)`. Flagged strings are genuinely unwrapped.
- **Captured-locale pattern already exists** and is idiomatic: `@Environment(\.locale)` + `explicitLocale ?? environmentLocale` + a `.locale(_:)` COW modifier — see `DateField.swift:89,:345`, `TimeField.swift:81`, the Charts. 12 components adopt it; the 16 price/number components below do **not** (they use device locale). *(**Correction (v2.1):** a `FormatDefaults` env + `.formatDefaults(currencyCode:)` DID land in #260 — the architect was right; my earlier "it doesn't exist" was read off a stale tree. Chain: explicit arg › `formatDefaults.currencyCode` › `\.locale.currency` › `"USD"`.)*
- **Body-level raw-color `❌` (grep-confirmed, preview content excluded):** `BorderBeam:143`, `ImageCollage:61`, `ScrubGallery:92`, `VideoPlayerView:172`, `TiltCard:130`, `ThemePicker:104,:135` (`Color(hex:)`) + support `MeterStyle:170`, `PageHeaderStyle:457`. **Excluded (preview-only):** `Diff:78-80`, `ScrubGallery:149`, `KanbanBoard:202,210`.
- **`.font(.system(size:))` = 172 sites / 87 files** — but includes metric-derived symbol sizes in the score-0 exemplars themselves (`CloseButton:77` `diameter*0.44`, `TrendChip:48` `size.iconPointSize`). Actionable subset = **text** sites only.
- **`COMPONENT_REFACTOR_RULES R1–R7`** — the "core kind in init" convention cited in code — **is not a written doc**; it lives only in ~58 files' comments and conflicts with SKILL rule 3. → [ADR-0001](docs/ADR-0001-core-kind-in-init.md).

## Scorecard — hard fails (`❌`, high confidence)

| Axis | ❌ count | Components |
|---|---|---|
| Token-fed | **5** | BorderBeam · ImageCollage · ScrubGallery · VideoPlayerView · ThemePicker *(Diff removed — preview content)* |
| Copy-on-write | 2 | **SeatCell** · SeatLegend |
| Init = content | 2* | **SeatCell** · ProgressIndicator  *(\*both are the "core kind" pattern — validity pending [ADR-0001](docs/ADR-0001-core-kind-in-init.md); + 🟡 ScoreBadge, ResultView)* |
| a11y / RTL / i18n | 2 | Diff · PagingCarousel |
| **House Rule 1 (network)** | **1** | **AnimatedImage** — `URLSession` fetch in body (unscored axis; grep-confirmed `:69`) |
| #Preview | 0 | every component has a `#Preview` |

---

# Corrected priority ranking (drives the work — post-review)

Raw score is kept in the appendix as evidence; **this ordering supersedes it.** Rationale: equal-weight scoring put a decorative specular-white (`BorderBeam` #2) and a preview false-positive (`Diff`) above `ListRow`'s Turkish default in a **public init signature** — the more serious defect for a public, MIT, English-only, brand-neutral library.

## 🔴 P0 — do first

### P0.1 — Brand-neutrality & i18n in public API (cheapest fix, highest exposure)
> **✅ SHIPPED** on branch `fix/audit-p0-brand-neutrality-clean` (worktree off `origin/main`). All items below done; **API-safe** (`diagnose-api-breaking-changes` clean). Currency de-branded to `"USD"` as the default *value* (signatures unchanged) — the env chain (`.formatDefaults` › `\.locale` › `"USD"`) already resolves omitted call sites. **Deferred:** flipping the modifier defaults to `String? = nil` for full env-adoption is a 17-signature API break → gated behind a **major version bump** per `.api-breakage-allowlist.txt` policy; tracked as a follow-up, not done here.
- [x] **`SeatCell.swift:39`** — `currencyCode: String = "TRY"` → `"USD"` (de-branded; kept default + type, API-safe).
- [ ] **`ListRow.swift:14`** — Turkish `"/ ay"` default in public init → `String(themeKit:)`; `:333` `"Total:"` → wrap.
- [ ] **`AgentPriceRow`, `AncillaryCard`** — hardcoded `"TRY"` → caller-provided / locale currency.
- [ ] **Previews:** `PageHeader.swift:235` `"etstur"`, `Watermark:80` `"İstanbul"` → generic placeholders. *(Apply the preview-content standard **symmetrically**: these are not "clean" just because they're in a preview — the SKILL bans the brand name outright.)*
- [ ] **Sweep:** grep the library for other currency-code / brand / Turkish defaults in public signatures.

### P0.2 — Structural API violations (House Rules 2 & 3)
- [ ] **SeatCell** — the only full-legacy API: no `copy{}` extension; `size:`/`isSelected:`/`display:`/`palette:` in init → chainable modifiers (`.controlSize`, `.selected`, `.display`, token-fed palette). *(score 7 — worst in library.)*
- [ ] **SeatLegend** — `palette`/`perRow` in init with no COW path → `.palette(_:)`/`.perRow(_:)` (it already has `.showsPremium`, so additive not a rewrite); swatch `cornerRadius:4` → `RadiusRole.selector`.
- [ ] **Raw `Color` in modifier signatures** → accept `SemanticColor`/token keys, `@available(*, deprecated…)` the raw overload: `Checkbox.customInner(color:)` (`:29`), `SeatMap.tierColors([SeatTier:Color])` (`:289`), `BorderBeam(colors:[Color]?, cornerRadius:CGFloat)` (`:27-42`).
- [ ] **AnimatedImage `:69`** — decide: remove the in-component `URLSession` fetch (delegate to the caller / a provider closure like RemoteImage's `AsyncImage`), **or** ratify a documented House-Rule-1 exception. This is the audit's most serious blind spot.

### P0.3 — Body-level raw colors → resolve via **[ADR-0002](docs/ADR-0002-on-media-and-specular-color.md)** (one coordinated fix, not 8)
- [ ] Introduce on-media contrast token(s) + a documented specular-constant convention, then sweep: `ImageCollage:61`, `VideoPlayerView:172`, `ScrubGallery:92`, `LoyaltyCard` (QR bg), `PageHeaderStyle:457` (on-image), `BorderBeam:143`, `TiltCard:130`, `MeterStyle:170`. `ThemePicker` (`Color(hex: theme.base)`) is a separate *intentional cross-theme render* — comment it, don't tokenize.

### P0.4 — Write two ADRs **before** re-bucketing the affected items
- [ ] **[ADR-0001 — Core kind in init vs modifiers-only appearance](docs/ADR-0001-core-kind-in-init.md).** Unblocks: `ProgressIndicator` (`variant:`), `ButtonGroup`/`Join` (`axis:`), `ScoreBadge`/`ResultView`. **Do not rewrite these until the ADR lands** — 58 files cite the conflicting convention; changing one in isolation creates incoherence.
- [ ] **[ADR-0002 — On-media & specular color](docs/ADR-0002-on-media-and-specular-color.md).** Unblocks P0.3.

## 🟠 P1 — after P0

- [ ] **Adopt the `@Environment(\.locale)` + `.locale(_:)` capture pattern** (DateField/TimeField/Charts) in the 16 device-locale price/number components: PriceTag, PointsBadge, RollingNumber, GaugeView, Rating (`%.1f`), RatingSummary (`%.1f`), PriceBreakdown, PriceHistogram, PriceTrendChart, InstallmentPicker, InstallmentSelector, FlightResultRow, FlightCard (dates), RoomCard, SeatMap, LoyaltyCard.
- [ ] **Wrap remaining UI/a11y strings** in `String(themeKit:)`: BoardingPass, Coupon, FilterBar, FlightResultRow, FlightTicketCard, FlightStatusBadge, CountdownTimer, FareFeatureRow, ShareButton, SwapButton, QRCode, StepperRow, DatePriceStrip, AmenityGrid, CurrencyPicker, FileInput, SearchBar, Select, RecentSearchRow, SearchField, Barcode, ReviewCard, SheetHeader, FareSummary, SortSummaryBar, PassengerRow, GuestSelector, FlightRoute, Mentions.
- [ ] **Icon-only buttons missing `accessibilityLabel`:** AlertToast (close), FilterGroup (reset), QuantityStepper (±), SearchBar (back/clear), DatePriceStrip/PriceTrendChart (chevrons), SegmentedTabBar (add/close), Upload (trash), ReviewCard (photos), CountBadge/Indicator (dots), Barcode, RemoteImage (alt-text).
- [ ] **Interactive rows without a11y action/selected trait:** DataTable (`onTapGesture`), AgentPriceRow, PriceBreakdown.
- [ ] **Adjustable/paging VoiceOver:** Diff (drag → `accessibilityAdjustableAction`), PagingCarousel (paging), Splitter (divider label).
- [ ] **RTL geometry** (mirror offsets / flip `Path`s / honor `layoutDirection` in custom `Layout`s): Slider, RangeSlider, Timeline, Steps, PagingCarousel, Diff, Masonry, Flex, RollingNumber (lock LTR), Indicator, Transfer, Tooltip (arrow), LoyaltyCard (Canvas).

## 🟡 P2 — systemic sweeps & enforcement

- [ ] **Dark/themed preview coverage — ~206 components, ONE infra decision.** Standardize on `PreviewMatrix` (or make the snapshot harness render dark automatically) so every `#Preview` gets dark for free. Do **not** file 206 per-component tickets.
- [ ] **Glyph-font sweep — split the 172:** migrate **text** sites off `.font(.system(size:))` to `textStyle` (real Dynamic-Type debt; e.g. `ThemePicker:98,:127`, `ResultView` 72pt numeral); leave **metric-derived symbol** sites (scaled off fixed container metrics) or move them to the `Icon` atom opportunistically. Do not treat all 172 as violations.
- [ ] **Magic spacing/radius literals** → `SpacingKey`/`RadiusRole`: Accordion, ActionBar, Agenda, Card (`padding=16`), FareFamilyCard, NotificationCard, ListView, Title, InputLabel, SearchBadge, AnchorNav, Buttons, Chip (tier paddings).
- [ ] **Native-modifier hygiene:** `StickyBookingBar.enabled()` → native `.disabled(_:)`; deprecate raw-`CGFloat` knobs (`TicketStub.notchRadius`, `RemoteImage.cornerRadius`, `ColumnsGrid` gutter) toward `RadiusRole`/`SpacingKey`.
- [ ] **Run the unaudited-axis pass** (cheap): grep for House-Rule-1 violations (`Task`/`URLSession`/`ObservableObject` in components), slot-vocabulary conformance, and whether raw escape hatches are already `@available(*, deprecated…)`.
- [ ] **CI grep gates (prevent regression):** fail the build on — Turkish characters or `"ets"`/`"etstur"` in `Sources`; `Color.white`/`.black`/`Color(hex:` in non-`#Preview` body code; raw `Color`/`CGFloat` in a `public func …() -> Self` modifier signature; `URLSession`/`Task` inside `Components`. Each sweep above should land with its gate so it's done once.

---

# Appendix — full scored matrix (raw, worst-first)

> Mechanical evidence. For sequencing use the **Corrected priority ranking** above.

## 🔴 Raw score ≥ 3

| # | Component | Layer | Tok | COW | Init | a11y/RTL/i18n | Prev | Score | Key issues (v2 notes in *italics*) |
|---|---|---|:-:|:-:|:-:|:-:|:-:|:-:|---|
| 1 | SeatCell | atom | 🟡 | ❌ | ❌ | 🟡 | 🟡 | **7** | No COW; init appearance args; a11y unwrapped; *+ public `currencyCode:"TRY"` default (missed in v1)* |
| 2 | CountBadge | atom | 🟡 | 🟡 | ✅ | 🟡 | 🟡 | **4** | `font(size:11)`, Ribbon `cornerRadius:4`; dot unlabeled; RTL offset |
| 3 | SeatLegend | mol | 🟡 | ❌ | ✅ | ✅ | 🟡 | **4** | palette/perRow in init (no COW); `cornerRadius:4` |
| 4 | PagingCarousel | org | 🟡 | ✅ | ✅ | ❌ | 🟡 | **4** | Absolute `.offset` breaks RTL; no VoiceOver paging; `spacing=12` |
| 5 | Diff | org | 🟡 | ✅ | ✅ | ❌ | 🟡 | **4** | *Token → 🟡 (`.white` was preview-only, corrected);* drag no adjustable/label; RTL offset; `font(size:14)` |
| 6 | BorderBeam | atom | ❌ | 🟡 | – | ✅ | 🟡 | **3** | *`Color.white` = specular head → [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md); COW cell is really a raw-`Color` signature issue.* `[Color]`+`CGFloat` init |
| 7 | Rating | atom | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `%.1f` not localized; padding 6/2; score `font(size:)` |
| 8 | RemoteImage | atom | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | No alt-text; raw `cornerRadius(CGFloat)`; deprecated `Icon.color` |
| 9 | Barcode | atom | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `.secondary` not token; `"Barcode"` unwrapped |
| 10 | AgentPriceRow | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `"TRY"`; `font.system(10/11)`; `"Select"`; no row a11y group |
| 11 | AlertToast | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | Close unlabeled; `padding(.vertical,12)` |
| 12 | AncillaryCard | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `"TRY"`; `"Add/Added"`; `font.system(12/13)`; magic spacing |
| 13 | BoardingPass | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | Hardcoded Gate/Seat/Boarding/Terminal; `font.system(14/16)` |
| 14 | ImageCollage | org | ❌ | ✅ | ✅ | ✅ | 🟡 | **3** | `+N` `.white` → [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md); `cornerRadius=12` + raw-CGFloat modifier |
| 15 | FilterBar | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | magic chipHPad/spacing=8; `"Filter"/"Sort"` unwrapped |
| 16 | FlightCard | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | icon `font(12)`, pad 6/2; scarcity + dates not locale |
| 17 | FlightResultRow | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | icon `font(11/14)`; `"Save"/"Details"`; currency not locale |
| 18 | FlightTicketCard | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | icon `font(14/15)`; `"Favourite"` unwrapped |
| 19 | ListRow | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | **Turkish `"/ ay"` in public init** + `"Total:"`; icon `font(5/11/13)` — *P0.1* |
| 20 | DatePriceStrip | mol | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `spacing:8`; chevrons unlabeled; `", lowest fare"` unwrapped |
| 21 | ProgressIndicator | mol | ✅ | ✅ | ❌ | ✅ | 🟡 | **3** | *init `variant:` = "core kind" (R1) — validity pending [ADR-0001](docs/ADR-0001-core-kind-in-init.md)* |
| 22 | ScrubGallery | mol | ❌ | ✅ | ✅ | ✅ | 🟡 | **3** | *`:92` dot real (❌); `:149` was preview (corrected)* → [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md) |
| 23 | Coupon | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | `font.system(13)`×3; a11y strings hardcoded |
| 24 | DestinationCard | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | Heart `font(15)`+`padding(4)`; favourite a11y hardcoded |
| 25 | ThemePicker | org | ❌ | ✅ | ✅ | ✅ | 🟡 | **3** | `Color(hex)` *= intentional cross-theme render, comment not tokenize;* text `font` sites real |
| 26 | VideoPlayerView | org | ❌ | ✅ | ✅ | ✅ | 🟡 | **3** | `.white` overlay glyphs → [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md); font 56/padding 8/shadow 6 |
| 27 | LoyaltyCard | org | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | Canvas progress not RTL; `.white` QR bg; points not locale |
| 28 | ResultView | org | 🟡 | ✅ | 🟡 | ✅ | 🟡 | **3** | 404 numeral `font(size:72)` (text → real); *init `status:` pending [ADR-0001](docs/ADR-0001-core-kind-in-init.md)* |
| 29 | StepperRow | mol | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | glyph font 16/14; `"Decrease/Increase"` unwrapped |
| 30 | Steps | mol | 🟡 | ✅ | ✅ | 🟡 | 🟡 | **3** | glyph font 10/12; horizontal connector RTL |

*(Unscored-axis flag: **AnimatedImage** — raw score 2, but a confirmed House-Rule-1 network violation; treat as P0.2.)*

## 🟠 Raw score 2 (55) — mostly i18n-🟡 + preview-🟡 (the preview-🟡 is the systemic axis; discount it when triaging)

**Atoms:** GaugeView, Icon (`Color.primary` tint), Indicator, InputLabel, Join (`axis` init → [ADR-0001](docs/ADR-0001-core-kind-in-init.md)), Kbd, PointsBadge, PriceTag, QRCode, RollingNumber, AnimatedImage *(→ P0.2 network)*, Chip, CountdownTimer, FareFeatureRow, FlightStatusBadge, ScoreBadge (`large:` → [ADR-0001](docs/ADR-0001-core-kind-in-init.md)), SearchBadge, ShareButton, SwapButton, TiltCard (`Color.white` → [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md)), Title, Watermark (preview "İstanbul" → P0.1).

**Molecules:** InstallmentPicker, PriceHistogram, PriceTrendChart, PriceBreakdown, PaymentCardField, LayoverRow, PassengerRow, Masonry (RTL), InstallmentSelector, MultiSelect, FlightRoute, GuestSelector, Mentions, Chips, CurrencyPicker, FieldButton, FileInput, FilterGroup, Flex (RTL), QuantityStepper, RangeSlider (RTL), Slider (RTL), RecentSearchRow, SearchBar, SearchField, Select, SmartSuggestion, SortSummaryBar, Checkbox (`customInner(color:)` → P0.2), AmenityGrid, AnchorNav, Buttons, Splitter, SuggestionRow, Transfer, TreeView, TripTypeToggle.

**Organisms:** Accordion, ActionBar, Agenda, BlogCard, BrowserFrame, Callout, Card (`padding=16`), CardStack, FareFamilyCard, DataTable (a11y trait), FareSummary, FlightListItem, FloatingActionButton, HotelResultCard, InfoBanner, SeatMap (`tierColors` → P0.2), ReviewCard, SegmentedTabBar, SheetHeader, Timeline (RTL), Upload, ListView, NotificationCard, RatingSummary.

## 🟡 Raw score 1 (~95) — **almost entirely the systemic dark-preview axis** (→ P2 infra, not per-component)

Atoms: IconTile, InlineText, ProgressBar, RadialProgress, Aura, Avatar, Badge, CodeBlock, ColorSwatch, Confetti, DividerView, Skeleton, Spinner, StatusDot, Swap, TextLink, TextRotate · *(support 🟡: Mask, MeterStyle→[ADR-0002](docs/ADR-0002-on-media-and-specular-color.md))*.
Molecules: InputNumber, MapPriceMarker, MultiLineTextInput, OTPInput, Pagination, ColorArea, ColorField, ColorSlider, ColorSwatchPicker, ColumnsGrid, DateField, Dropdown, EmojiReactionButton, Fieldset, FilterRow, RadioButton, RadioGroup, SearchSummary, SegmentedControl, SelectBox, BarChart, DonutChart, Cascader, ThemeButton, Breadcrumbs, CalendarView, CheckboxGroup, ButtonGroup (`axis:`→[ADR-0001](docs/ADR-0001-core-kind-in-init.md)), Affix, Stat, Tooltip (arrow RTL), TreeSelect · *(support 🟡: FlowLayout, ChartSupport, ButtonSize)*.
Organisms: AccordionGroup, BottomSheet, ButtonDock, Carousel, ChatBubble, ColorPickerPanel, CommandPalette, Counter, Dialog, Drawer, EmptyState, Feedback, FilterList, Footer, Gallery, KanbanBoard *(preview `.white` demo only — not a violation)*, KeyValueTable, Popconfirm, LocationCard, MapCallout, MenuCard, NavigationBar, PhoneFrame, PriceAlertCard, PromoBanner, RoomCard, SelectionCards, Sidebar, StickyBookingBar (`.enabled()`), TicketStub (`notchRadius`), Toast, Tour, WindowFrame · *(support 🟡: PageHeaderStyle→[ADR-0002](docs/ADR-0002-on-media-and-specular-color.md), ToastStyle)*.

## ✅ Raw score 0 — reference-clean

**Atoms:** Backdrop, **CloseButton** (exemplary), HelperText, SkeletonGroup, SurfaceView, **Tag**, **TrendChip** · *(support: ChipStyle, CornerRadiusModifier)*.
**Molecules:** ControlRow, **ScrollShadow**, Autocomplete, CalendarYearPicker, **AreaChart**, **LineChart**, TableCells, **TextInput**, ThemeContextMenu, ThemeController, ThemeToggle, **TimeField**, ToggleGroup · *(support: ColorModels, FieldStyle, SelectStyle, Space, ChartModels, StatStyle, TextInputFormatter, ValidationRule)*.
**Organisms:** **Hero**, ListRowStyle, ~~PageHeader~~ **→ moved to P0.1** (preview logo `"etstur"` is a real brand slip, not clean) · *(support: AnchoredPopover, BarStyle, CardStyle, FeedbackDefaults, SeatMapModels, FlightListItemStyle)*.

---

*v2 generated 2026-07-11 (v1 + architect review). Rubric: `.claude/skills/themekit-authoring/SKILL.md`. ADRs: [ADR-0001](docs/ADR-0001-core-kind-in-init.md), [ADR-0002](docs/ADR-0002-on-media-and-specular-color.md). Line numbers reflect the tree at audit time — re-grep before editing.*
