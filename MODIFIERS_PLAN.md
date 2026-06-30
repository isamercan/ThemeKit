# Modifier Migration Plan — bloated inits → idiomatic SwiftUI modifiers

**PHASE 1 (inventory + plan).** Goal: convert bloated `init`s into SwiftUI's chainable modifier
pattern, **without breaking the public API** (deprecate old init + forward). Solid (already
lean) APIs are left untouched.

## Inventory (evidence)

- **103 components**, averaging **5.2** init parameters.
- **26 components ≥ 8 parameters** (anti-pattern targets). **51 components ≤ 4** (clean → untouched).
- **Precedent:** the button family has already been converted (#96–#98): `isContentWidth`→`block`,
  `isEnabled`→`.disabled()`, label `.lineLimit(1)`. This plan spreads the same pattern.

| Bloat | Components (init param count) |
|---|---|
| 23 | TextInput |
| 12 | ThemeButton✅(done), MultiSelect, DateField |
| 11 | Slider, SearchBar, RadioButton, Badge, Accordion |
| 10 | Rating, RangeSlider, ProgressBar, InputNumber, Chip, Checkbox |
| 9 | VideoPlayerView, SelectBox, Pagination, MultiLineTextInput, Carousel |
| 8 | Stat |

## Decision framework (summary)

- **STAYS (init):** required content (`title/value/items/url`), `@Binding` (`selection/text/isOn`),
  required closures (`action/onSubmit`), `@ViewBuilder` slots (`content/label`). Also items considered
  *domain data* — `range/bounds`, `options`, `infoMessages` (validation to display) and
  `placeholder` → **stay** (content/data, not appearance).
- **MODIFIER (mechanism):**
  - **(M-disabled)** `isEnabled: Bool` → SwiftUI native **`.disabled(_:)`** (not custom; read from the environment). *Highest leverage, ~20 components.*
  - **(M-a11y)** `accessibilityID: String?` → self-returning **`.a11yID(_:)`** (forwards to the kit's existing `.a11y()` infrastructure).
  - **(M-style/3)** semantic variant enums (`style/variant/type/selectionStyle`) → **self-returning** `.componentStyle(_:)` (no custom *render* needed; just semantic color/emphasis). Where explicit render extension is required, a Style protocol already exists (Card/Stat/Select).
  - **(M-size/3)** `size`/`customSize`/`height` → self-returning `.size(_:)`, or for those using `ControlSize`, native **`.controlSize()`** + `@Environment(\.controlSize)`.
  - **(M-flag/3)** Bool config flags with defaults (`allowClear/showCount/isSecure/showPercentage/gradient/loop/autoplay/searchable…`) → self-returning flag modifiers.
  - **(M-color/3)** style colors (`textColor/strokeColor/trailColor/backgroundColor/gradient`) → self-returning style modifiers.
  - **(M-env/2)** cross-cutting config that makes sense to cascade into the subtree (density) → EnvironmentKey modifier (e.g. `.controlSize`, and `.fieldDensity` in the future).

> Mechanism choice: multi-variant explicit-render → Style protocol (1); cascade → Environment (2);
> single-instance one-off → self-returning (3). Most cases in this library are **(3)** or native env.

---

## Highest leverage: cross-cutting migrations

These simplify DOZENS of components with a SINGLE modifier — **do these first**:

### X1 — `isEnabled: Bool` → `.disabled(_:)` (native)
Affected components (removed from init and read via `@Environment(\.isEnabled)`; old param deprecated+forwarded):
`Chip, Rating, Checkbox, RadioButton, Pagination, DateField, MultiSelect, RangeSlider, SearchBar, SelectBox, Slider, InputNumber, MultiLineTextInput, TextInput` (+ButtonGroup already ✅).
**~14 components, one pattern.** Mapping: `isEnabled: $x` → `.disabled(!x)`; `isEnabled: false` → `.disabled(true)`.

### X2 — `accessibilityID: String?` → `.a11yID(_:)` (self-returning)
Affected: `Checkbox, RadioButton, DateField, MultiSelect, SearchBar, SelectBox, Slider, RangeSlider, InputNumber, MultiLineTextInput, TextInput, Pagination`. **~12 components.** Old param deprecated+forwarded to `.a11yID(id)`.

### X3 — `size:` → native `.controlSize()` (those using ControlSize)
`Checkbox`, `RadioButton` already take `ControlSize` → `@Environment(\.controlSize)` + native `.controlSize()`. Those with a custom size enum (TextInput/Badge/Chip/…) get a self-returning `.size(_:)`.

---

## Per-component plan (26 bloated)

Legend: **STAYS** | **→.disabled** | **→.a11yID** | **→style(3)** | **→size** | **→flag(3)** | **→color(3)**

### TextInput (23 → target ~6 init)
| Param | Decision | Modifier |
|---|---|---|
| `label`, `text`(Binding), `onSubmit` | **STAYS** | — |
| `placeholder`, `infoMessages` | **STAYS** (content/data) | — |
| `isEnabled` | →.disabled | `.disabled(_:)` |
| `accessibilityID` | →.a11yID | `.a11yID(_:)` |
| `size` | →size | `.size(_:)` (TextInputSize) |
| `isSecure, allowClear, showCount, hardLimit, autocorrectionDisabled` | →flag | `.secure() .clearable() .characterCount(limit:style:) …` |
| `maxLength, countStyle` | →flag (grouped) | `.characterCount(_ max:style:)` |
| `leadingSystemImage, suffixSystemImage, addonBefore, addonAfter` | →style/slot | `.icon(leading:trailing:)` / `.addons(before:after:)` |
| `keyboardType, textContentType, submitLabel, autocapitalization, formatter` | →flag (grouped) | `.keyboard(_:contentType:submit:caps:)` + `.formatter(_:)` |
**Note:** TextInput already carries a `TextInputModel` init variant — the model-based init is preserved; the bloated init is split into `.modifier`s.

### Badge (11 → ~3 init)
| `text`, `action` | **STAYS** |
| `style, variant, size, shape` | →style/size | `.badgeStyle(_:) .badgeVariant(_:) .size(_:) .shape(_:)` (or a single `.badgeStyle(_, variant:, size:, shape:)`) |
| `leadingSystemImage, trailingSystemImage` | →style | `.icon(leading:trailing:)` |
| `textColor, gradient` | →color | `.tint(_:)` / `.gradient(_:)` (⚠ avoid clashing with SwiftUI's `.tint` → `.badgeColor`) |
| `highlighted` | →flag | `.highlighted(_:)` |

### Chip (10 → ~3)
| `title`, `isSelected`(Binding) | **STAYS** |
| `size, selectionStyle` | →style/size | `.size(_:) .chipStyle(_:)` |
| `leadingSystemImage, rating` | →style | `.icon(_:) .rating(_:)` |
| `isExist, isInteractive, expandsHorizontally` | →flag | `.interactive(_:) .strikethrough(_:) .expands(_:)` |
| `isEnabled` | →.disabled | `.disabled(_:)` |

### Rating (10 → ~3)
| `value`, `onRate, onReviewTap` | **STAYS** |
| `maxValue, size, layout, allowHalf, systemImage` | →style/flag | `.scale(max:) .size(_:) .layout(_:) .allowHalf(_:) .symbol(_:)` |
| `isEnabled` | →.disabled |
| `countLabel, sentiment` | →flag | `.caption(count:sentiment:)` |

### Checkbox / RadioButton (10–11 → ~3)
| `label`, `isChecked/isSelected`(Binding), `infoMessages` | **STAYS** |
| `size`(ControlSize), `customSize` | →controlSize | native `.controlSize()` + `.size(custom:)` |
| `type, style, padding, alignment, backgroundColor` | →style | `.checkboxStyle(_:)` / `.radioStyle(_:)` (type+style+padding+align in one protocol/modifier) |
| `isIndeterminate` | →flag | `.indeterminate(_:)` |
| `isEnabled` | →.disabled · `accessibilityID` | →.a11yID |

### ProgressBar (10 → ~2)
| `value` | **STAYS** |
| `height, gradient, strokeColor, trailColor` | →color/size | `.barHeight(_:) .gradient(_:) .colors(stroke:trail:)` |
| `showPercentage, status, steps, successSegment, format, accessibilityLabel` | →flag | `.percentage(_:) .status(_:) .steps(_:) .successAt(_:) .valueFormat(_:)` |

### Pagination (9 → ~3)
| `current`(Binding), `total` | **STAYS** |
| `simple, siblingCount, boundaryCount, showJumper, jumperTitle, showTotal` | →flag | `.simple(_:) .window(sibling:boundary:) .jumper(title:) .total(_:)` |
| `isEnabled` | →.disabled |

### Accordion (11 → ~3)
| `title`, `content`(@ViewBuilder) | **STAYS** |
| `subtitle, number, leadingSystemImage` | →style/content | `.subtitle(_:) .number(_:) .icon(_:)` (or subtitle/number STAYS — content) |
| `indicator, titleSize, paddingSize` | →style/size | `.indicator(_:) .titleSize(_:) .density(_:)` |
| `truncateSubtitle, initiallyExpanded, showDivider` | →flag | `.truncateSubtitle(_:) .expanded(_:) .divider(_:)` |

### Stat (8 → ~3)
| `title, value`, `trend` | **STAYS** (StatStyle layout already exists ✅) |
| `prefix, suffix, description, systemImage` | →content/style | most STAY (content); `systemImage` →`.icon(_:)` |
| `isLoading` | →flag | `.loading(_:)` |

### DateField / SelectBox / MultiSelect / SearchBar / Slider / RangeSlider / InputNumber / MultiLineTextInput
Common pattern (form/input family):
- **STAYS:** binding (`date/selection/text/value/lowerValue/upperValue`), `options`, `range/bounds`, `optionTitle/isOptionEnabled`, `onChange*/onSubmit/onSearch`, `placeholder`, `infoMessages`, `marks`.
- **→.disabled:** `isEnabled` (all). **→.a11yID:** `accessibilityID` (all).
- **→flag(3):** `allowClear, searchable, isLoading, showInputs, showJumper, showValueTooltip, editable, showBackButton, showMuteToggle, loop, autoplay, muted, debounce, maxTagCount, maxResults, step` → each a fluent flag modifier (`.clearable() .searchable() .loading() .step(_:) .debounce(_:) …`).
- **→style/size(3):** `style, size, axis, minHeight, verticalHeight, leadingSystemImage, hint, errorText` → style/size modifiers (hint/errorText can fold into `infoMessages`).

### Carousel / VideoPlayerView (media)
- **STAYS:** `items/url`, `content`(@ViewBuilder), `currentIndex/progress/isMuted`(Binding), `onTap`.
- **→flag(3):** `autoplay, showsArrows, showsDots, loop, fade, dotPosition, muted, showMuteToggle, tapToToggle` → fluent flags (`.autoplay(_:) .arrows(_:) .dots(_:) .loop(_:) .muted(_:)`).

---

## Clean components (≤4 params) — UNTOUCHED
51 components (Avatar, Tag, Kbd, Spinner, Divider, Icon, StatusDot, Skeleton, Toast, Card, Hero, EmptyState, … + the 6 new ones in this plan: Join/Mask/TextRotate/Gauge/ShareButton/ColorField). These are already lean along the content+binding+action axis; **no unnecessary changes** (audit rule: don't touch Solid).

---

## Migration safety

> **Note — the repo is not public yet.** The task says "deprecate+forward" (library rule); but
> the owner previously preferred "not public → drop deprecated, clean break." **Two paths:**
> **(A) deprecate+forward** (rule-compliant, source-compatible) — old init `@available(*, deprecated, message: "Use .x() modifier")` + internally forwards to the new API.
> **(B) clean break** (since it's not public) — remove the old init, update all call sites (as we did for the button family).
> **Recommendation:** use **(B)** until public release (cleaner, less boilerplate); switch to **(A)** at 1.0 once the API freezes. Owner's call.

- Modifier defaults behave **identically** to the old param defaults → no visual change.
- public component → public modifier. After each component: update call sites + #Preview + gallery registry + snapshot + DocC; don't move to the next component until `swift build`+`test`+Demo are green.
- Avoid names that clash with SwiftUI: use the natives `.tint/.font/.controlSize`; use a separate name like `.badgeColor` for semantic color.

## Suggested order (PHASE 2)
1. **X1 `isEnabled`→`.disabled()`** (14 components, one pattern — highest leverage, lowest risk).
2. **X2 `accessibilityID`→`.a11yID()`** (12 components).
3. **X3 `size`→`controlSize`/`.size()`**.
4. Then component-by-component, **bloated first**: TextInput → MultiSelect/DateField → Badge/Chip/RadioButton/Checkbox → ProgressBar/Rating/Pagination/Accordion/Stat → form/media family.
5. Each component: apply plan → call sites+preview+gallery+test+doc → build/test/Demo green → record the "old→new" mapping line in MODIFIERS_PLAN.md.

---

## PHASE 2 — implementation log (old → new mapping)
_(Recorded here as each component is converted.)_

- **Button family** ✅ (#96–#98): `isContentWidth: true` → (remove, default content-width) · `isContentWidth: false` → `block: true` · `isEnabled: $x` → `.disabled(!x)`.
- **X1 `isEnabled`→`.disabled()`** ✅ (13 components): Chip, Rating, Checkbox, RadioButton, Pagination, DateField, MultiSelect, RangeSlider, SearchBar, SelectBox, Slider, InputNumber, MultiLineTextInput → `@Environment(\.isEnabled)`. Mapping: `isEnabled: $x`→`.disabled(!x)` · `isEnabled: false`→`.disabled(true)`. **TextInput** (model-based) deferred to its own refactor; **RadioButtonGroup/CheckboxGroup/SegmentedControl/ThemeToggle** out of X1 scope (round 2).
- **TextInput** ✅ (X1+X2 deferral closed): `isEnabled`→`@Environment(\.isEnabled)` (native `.disabled()`), `accessibilityID`→`.a11yID()` modifier. Both removed from `TextInputModel` + the flat init; the View holds `@Environment(\.isEnabled)` + `private var accessibilityID` (6× `model.isEnabled`→`isEnabled`, 6× `model.accessibilityID`→`accessibilityID`). Call sites: MoleculeDemos (7 models, per-mode `demoA11yID` switch + `.a11yID()`), MoreDemos (2 form fields), TextInput #Preview (2) + Accessibility.swift doc example. **Full 23→6 teardown DATA-DRIVEN REJECTED:** **11 of the 23 call sites use `TextInputModel(...)`** config bundles (solid escape hatch), flat init params are sparse at call sites (at most 3, mostly 1), `isEnabled` 0 usages. Splitting 15 style/flag params into 15 modifiers would break the 11 model call sites + marginal benefit → per "don't break Solid / don't make unnecessary changes" the model was preserved and only cross-cut consistency was applied.
- **VideoPlayerView** ✅ (10→5 init): playback flags (`autoplay/loop/muted/showMuteToggle/tapToToggle`) → modifiers; `url` (content) + bindings (`progress/isMuted/isActive`) + `onTap` stay in init. Modifiers: `.autoplay(_:) .loop(_:) .muted(_:) .muteToggle(_:) .tapToToggle(_:)` (autoplay/loop/muted default `true` preserved — inline auto-play video). Call sites: MoreDemos demo, ComponentRegistry usage.
- **Carousel** ✅ (9→4 init ×2, data-driven): 2 inits (content + activeContent). `items` (content) + `loop`+`currentIndex` (**seeds the @State `selection` → must stay in init**, like Accordion) + content stay in init. `autoplay`(5)/`showsArrows`(3)/`showsDots`(0)/`fade`(1)/`dotPosition`(1) → modifiers: `.autoplay(_:) .arrows(_:) .dots(_:position:) .fade(_:)` (showsDots+dotPosition → grouped into `.dots`). Call sites: OrganismDemos demo, ComponentRegistry usage, #Preview. (PagingCarousel is a separate component, unaffected.)
- **RangeSlider** ✅ (9→4 init, data-driven): 5 call sites → `lowerValue/upperValue/bounds/step` stay in init; `marks`(4)/`onChangeEnd`(3)/`valueLabel`(2)/`showInputs`+`inputTitles`(1) → modifiers: `.marks(_:) .inputs(_:titles:) .onChangeEnd(_:) .valueLabel(_:)` (showInputs+inputTitles → grouped into `.inputs`). Call sites: MoleculeDemos demo (inputs+marks variants), ComponentRegistry usage, ScreenshotGenerator, #Preview.
- **Slider** ✅ (9→4 init, data-driven): 8 call sites → `value/bounds/step/label` (step+label common) stay in init; `marks` 4×, `showValueTooltip` 4×, `onChangeEnd` 2×, `axis`/`verticalHeight` 1× → modifiers: `.marks(_:) .axis(_:height:) .showsValueTooltip(_:) .onChangeEnd(_:)` (axis+verticalHeight → grouped into `.axis(_:height:)`). Call sites: MoleculeDemos demo (vertical+horizontal), ComponentRegistry usage, ScreenshotGenerator (gallery shot), #Preview.
- **Pagination** ✅ (8→2 init, data-driven): 9 call sites → all config params sparse (siblingCount/showJumper 3×, simple/showTotal 2×, jumperTitle 1×, boundaryCount 0×) → all to modifiers; `current`/`total` (content/data) stay in init. Modifiers: `.simple(_:) .window(sibling:boundary:) .jumper(_:title:) .showTotal(_:)` (siblingCount+boundaryCount → `.window`, showJumper+jumperTitle → grouped into `.jumper`). Call sites: MoleculeDemos demo (4 modifiers), ComponentRegistry usage, #Preview.
- **InputNumber** ✅ (11→8 init, data-driven — minimal): 8 call sites → most params are **actually used** (label 9×, range 7×, unit 6×, step 5×, large 4×, hint 3×) → STAY in init ("don't make unnecessary changes"). Only sparse/dead: `editable` 2×, `hasInfo` 0×, `onChange` 0× → modifiers: `.editable(_:) .hasInfo(_:) .onValueChange(_:)` (`.onValueChange` to avoid confusion with SwiftUI `.onChange(of:)`). Call sites: MoleculeDemos demo (2× `.editable`).
- **MultiSelect** ✅ (11→7 init, data-driven): config flags sparse (isLoading 3×, searchable/allowClear/maxTagCount 1×) → modifiers: `.searchable(_:) .clearable(_:) .maxTags(_:) .loading(_:)`. `label/options/selection/placeholder/infoMessages/isOptionEnabled/optionTitle` (content/data) stay in init. Call sites: MoreDemos demo (4 modifiers), ComponentRegistry usage.
- **DateField / SelectBox / Stat** ⏭️ **(skipped — data-driven)**: DateField params are mostly used (style 6×, allowClear 6×, leadingSystemImage 4×) → teardown would be an "unnecessary change." SelectBox ~7 params, most content (label/options/selection/placeholder/hint/errorText/optionTitle). Stat already uses the StatStyle protocol + most of its 8 params are display content. All three left as-is per "don't break Solid / don't make unnecessary changes."
- **Autocomplete** ✅ (10→5 init ×2 + X1): hadn't been in X1 → `isEnabled`→`@Environment(\.isEnabled)`. 2 inits (static + async). `label/text/suggestions/suggest/placeholder/onSelect` (content/data/primary callback) stay in init; `maxResults`(0)/`debounce`(0)/`isSuggestionEnabled`(2)/`onSearch`(0) → modifiers: `.maxResults(_:) .debounce(_:) .suggestionEnabled(_:) .onSearch(_:)`. Async init `debounce=0.3` baseline in the init body (like SearchBar). Call sites: MoreDemos demo (static+async, `.suggestionEnabled`).
- **SearchBar** ✅ (14→8 init ×2, data-driven + cautious): 2 inits (classic + async `suggest`). `text/placeholder/suggestions/recent` (content/data) + **interaction callbacks** (`onSearch/onSelect/onSubmit/onClearRecent`) STAY in init (the component's contract; also `onSubmit` would clash with SwiftUI native `.onSubmit`). **Chrome+tuning** → modifiers: `.backButton(_:action:)` (showBackButton+onBack), `.trailingIcon(_:action:)` (trailingSystemImage+onTrailing), `.debounce(_:)`, `.maxResults(_:)`. Async init sets the `debounce=0.3` baseline in the init body (`.debounce(_:)` can override it) — per-init default preserved. Call sites: MoreDemos demo (`.backButton/.trailingIcon`), 2 #Preview.
- **Accordion** ✅ (11→4 init, data-driven): 7 call sites → `initiallyExpanded` 5× (+ seeds `@State expanded`, must stay in init), `leadingSystemImage` 3× **stays in init** (+ title/content @ViewBuilder); `subtitle`/`truncateSubtitle`/`showDivider` 0×, `number`/`indicator`/`titleSize`/`paddingSize` 1× → modifiers: `.subtitle(_:) .number(_:) .indicator(_:) .titleSize(_:) .density(_:) .truncateSubtitle(_:) .divider(_:)` (`.density` = paddingSize; avoided clashing with SwiftUI `.padding`). The single call site (OrganismDemos demo) converted to modifiers.
- **Rating** ✅ (10→3 init, data-driven): 9 call sites → `layout` 5×, `countLabel` 6× **stay in init** (+ content `value`); `allowHalf` 3×, `size`/`onReviewTap` 2×, `systemImage`/`onRate` 1×, `maxValue`/`sentiment` 0× → modifiers: `.maxValue(_:) .starSize(_:) .allowHalf(_:) .symbol(_:) .sentiment(_:) .onRate(_:) .onReviewTap(_:)`. Optional callbacks (`onRate/onReviewTap`) moved to idiomatic `.onRate{} .onReviewTap{}` modifiers (trailing closure preserved). Call sites: AtomDemos demo, ComponentRegistry usage string, #Preview.
- **Chip** ✅ (10→4 init, data-driven): X1 had added `@Environment(\.isEnabled)` to Chip but left a **dead `isEnabled` param** in the init (it wasn't assigned, silently ignored — bug risk) → removed. 16 call sites: `selectionStyle` 6×, `size` 3× **stay in init** (+ title/isSelected); `leadingSystemImage/rating/isExist/expandsHorizontally` 1×, `isInteractive` 0× → modifiers: `.icon(_:) .rating(_:) .exists(_:) .interactive(_:) .expands(_:)`. The single call site (AtomDemos Chip demo) converted to a modifier showcase + #Preview (`.icon`).
- **ProgressBar** ✅ (11→3 init, data-driven): 17 call sites measured → `showPercentage` 12×, `status` 5× **stay in init** (+ content `value`); `height` 3×, `gradient` 3×, `steps` 2×, `strokeColor`/`trailColor`/`successSegment` 1×, `format`/`accessibilityLabel` 0× → modifiers: `.barHeight(_:) .gradient(_:) .steps(_:) .colors(fill:track:) .successSegment(_:) .valueFormat(_:) .progressLabel(_:)`. (strokeColor+trailColor grouped into `.colors(fill:track:)`; the successSegment clamp moved into the modifier.) Call sites: Upload (`barHeight`), AtomDemos demo (5-modifier showcase), DisplaySnapshotTests (`.gradient()` — visually identical, snapshot valid), #Preview.
- **Badge** ✅ (11→6 init, data-driven): call-site density measured (36 sites) → `style` 33×, `leadingSystemImage` 11×, `size` 10×, `variant` 4× **stay in init** (real usage); `shape` 2×, `textColor` 1×, `trailingSystemImage`/`gradient`/`highlighted` **0×** → moved to self-returning modifiers: `.badgeShape(_:) .trailingIcon(_:) .badgeColor(_:) .gradient(_:) .highlighted(_:)`. (`.badgeColor` is a separate name to avoid clashing with SwiftUI `.tint/.foregroundColor`.) The single call site (AtomDemos Badge demo, exercising the whole long tail via knobs) converted to a modifier showcase + #Preview. Churn ~2 sites.
- **X3 `size`→`.controlSize()`** ✅ (3 components — the ControlSize trio): Checkbox, RadioButton, ThemeToggle. ThemeKit's `public enum ControlSize` (small/medium) custom enum was **shadowing** SwiftUI's `ControlSize` (collision); removed. All three moved to the native `ControlSize` + `@Environment(\.controlSize)` + native `.controlSize(_:)` cascade. The `size` init param was removed. Metric: `extension ControlSize { var checkboxSide }` (`.mini/.small`→20, default `.regular`→24) in Checkbox+RadioButton; ThemeToggle track uses `isCompact` (32×20 / 40×24). Mapping: `size: .small`→`.controlSize(.small)` · `size: .medium`→(remove, native default `.regular`=old `.medium`=24, visually identical) · `size: small ? .small : .medium`→`.controlSize(small ? .small : .regular)`. `customSize: CGFloat?` (Checkbox pixel escape hatch) stayed in init. Call sites: TreeSelect, MultiSelect, MoleculeDemos(Checkbox/RadioButton/ThemeToggle demo). **Remaining size params** (Avatar/Badge/Chip/Divider/ListRow/ProgressIndicator/SegmentedControl/Select/Rating/RadialProgress + button/TextInput) are component-specific enums → to be handled in the component-by-component phase (not a single mechanical cross-cut).
- **X1 round-2 (containers)** ✅ (4 components — X1 FULLY CLOSED): CheckboxGroup, RadioGroup (+ RadioButtonGroup 2nd struct), SegmentedControl, Select → control-level `isEnabled` moved to `@Environment(\.isEnabled)`. Multi-init forwards (convenience→designated) were dropped; in SegmentedControl the **per-item `SegmentItem.isEnabled` was preserved** (a separate concept); in Select the `SelectStyleConfiguration(isEnabled:)` internal forward was preserved (reads from env). `.disabled()` cascades natively to children. Call sites: SegmentedControl ×2, RadioGroup ×1, RadioButtonGroup ×2, CheckboxGroup ×1 → `.disabled(!enabled)`. **No component now carries `isEnabled: Bool` in its init.**
- **X1 round-2 (leaves)** ✅ (5 components): leaves not covered by the original X1 → `isEnabled: Bool` init param moved to `@Environment(\.isEnabled)` (native `.disabled()`): ThemeToggle, OTPInput, QuantityStepper, FileInput, TreeSelect. The OTPInput main struct reads from env and preserves the `isEnabled:` forward to the internal `OTPDigitBox`. Call site: ThemeToggle demo+#Preview (`.disabled()`); the other 4 have no call sites (default true). **Remaining X1 round-2 = containers** (CheckboxGroup/RadioGroup/SegmentedControl/Select) — to be handled separately/carefully due to the `isEnabled` forward to children + the per-item `SegmentItem.isEnabled`.
- **X2 `accessibilityID`→`.a11yID()`** ✅ (21 components): SelectBox, Autocomplete, CheckboxGroup, RadioGroup, SegmentedControl, RangeSlider, SearchBar, Select, RadioButton, ToggleGroup, Slider, ThemeToggle, OTPInput, InputNumber, Checkbox, DateField, MultiSelect, MultiLineTextInput, QuantityStepper, Swap, SegmentedTabBar. Mechanism: stored `accessibilityID` → `private var … = nil` (namespace stays hidden), init param removed, self-returning `func a11yID(_ id: String?) -> Self` modifier added (`var copy = self; copy.accessibilityID = …; return copy`). Mapping: `accessibilityID: "x"` → trailing `.a11yID("x")`. Call sites: DateField/Select/Checkbox demos migrated. **TextInput** (model-based) + **button family** (`ButtonConfiguration` intermediary; accessibilityID init param preserved) are out of X2 scope.

## PHASE 3 — strict R1–R7 modifier refactor (COMPONENT_REFACTOR_RULES)

Stricter ruleset adopted: init = `content + action` (≤2 params, R1); every
appearance/state axis is a chainable, order-free modifier from the R5 vocabulary
(`.variant/.size/.loading/.fullWidth/.icon/.shape`) routed through a single
copy-on-write `copy(_:)` helper (R2); `disabled` is native (R3); colors/metrics
from tokens (R4); **clean break** (owner's call — old inits removed, not
deprecated; recorded in `.api-breakage-allowlist.txt` + CHANGELOG). Scope:
Tier A+B (≥6-param components) first.

- **ThemeButton** ✅ (12→2 init — the canon). Init now `ThemeButton(_ title:action:)`. Moved to modifiers: `color:`→`.color(_:)`, `variant:`→`.variant(_:)`, `size:`→`.size(_:)`, `shape:`→`.shape(_:)`, `block:`→`.fullWidth(_:)`, `isLoading: Binding<Bool>`→`.loading(_ on: Bool = true)` (plain Bool — the button only ever *read* the binding), `systemImage:`+`iconPosition:`→`.icon(leading:trailing:)` (two slots replace the single image + position enum; `ButtonIconPosition` removed), `accessibilityID:`→`.a11yID(_:)`. `isEnabled: Binding<Bool>`→native `@Environment(\.isEnabled)` + `.disabled(_:)` (R3). Single `copy(_:)` mutation point (R2). Icon-only rendering hardened: the old code dropped the glyph for icon-only + `.trailing`; `content` now renders `leadingSystemImage ?? trailingSystemImage` for circle/square. Call sites migrated (≈40): Sources (Feedback, Dialog, Tour, ResultView, Popconfirm), Demo (ThemeButtonDemo knob, MoreDemos ×9, ThemesView ×3, ComponentRegistry usage string), Tests (ButtonSnapshotTests full matrix, ScreenshotGenerator, GifGenerator) + #Preview ×2. Skill docs (SKILL.md, components.md) updated. Snapshots unchanged (modifier defaults == old param defaults → visually identical). **Preset family** (PrimaryButton/…/Buttons.swift, `ButtonConfiguration` intermediary) is a separate ergonomic API — already native-`.disabled()` — and is a later queue item, not part of this change.
- **DateField** ✅ (10→2 init). Init now `DateField(_ label:date:)`. The PHASE 2 "skip" (data-driven) is **superseded** by PHASE 3's strict R1 clean break. Content (`label`) + the `date` Binding stay in init; the 8 appearance/config params → modifiers: `placeholder:`→`.placeholder(_:)`, `range:`→`.range(_:)` (sparse/0×, not required data → modifier per ListRow precedent), `style:`→`.style(_:)`, `locale:`→`.locale(_:)`, `components:`→`.components(_:)`, `infoMessages:`→`.infoMessages(_:)`, `allowClear:`→`.clearable(_ on: Bool = true)` (R5 flag vocabulary, matches MultiSelect), `leadingSystemImage:`→`.icon(_:)` (R5, matches ListRow). `accessibilityID` already `.a11yID()` (X2) — folded into the single `copy(_:)` helper (R2). `isEnabled` already native env (X1/R3). Stored config flipped `private let`→`private var` with defaults. The `var style`/`func style(_:)` and `var range`/`func range(_:)` property-vs-method pairs coexist (legal Swift, intended). Call sites migrated (5): MoreDemos DateFieldDemo knob (6 modifiers + `.a11yID` + `.disabled`), HotelSearchView ×2, ComponentRegistry usage string, ScreenshotGenerator gallery shot + #Preview ×3. Skill `components.md` updated. Snapshots unchanged (modifier defaults == old param defaults → visually identical).
- **ListRow** ✅ (14→2 init). Init now `ListRow(_ title:action:)`. 12 params → modifiers: `subtitle:`→`.subtitle`, `number:`→`.number`, `size:`→`.size`, `leadingSystemImage:`→`.icon`, `leadingImageURL:`→`.leadingImage`, `leadingSelection:`→`.leadingSelection`, `alertCount:`→`.alertCount`, `badge:`→`.badge`, `meta:`→`.meta`, `infos:`→`.infos`, `isSelected:`→`.selected`, `multilineTitle:`→`.multilineTitle`, `infoAction:`→`.onInfo`, `trailing:`→`.trailing`. Single `copy(_:)` (R2). `action` kept optional in init (rows can be display-only). Call sites migrated (23): ListView, Drawer, MenuCard, MoreDemos (ListRowDemo knob + Drawer demos ×4 + List demo), ComponentRegistry usage, GifGenerator ×3, ScreenshotGenerator ×3, #Preview ×6. No dedicated snapshot test.
- **TreeSelect** ✅ (9→4 init). Init now `TreeSelect(_ label:nodes:selection:initiallyExpanded:)`. Content (`label`) + required DATA (`nodes`) + the `selection` Binding stay in init; `initiallyExpanded` **stays in init** (seeds the `@State expanded`, like Accordion/Carousel). 5 config params → modifiers: `placeholder:`→`.placeholder(_:)`, `cascade:`→`.cascade(_ on: Bool = true)`, `searchable:`→`.searchable(_ on: Bool = true)` (R5 flag), `isLoading:`→`.loading(_ on: Bool = true)` (R5 flag), `isNodeEnabled:`→`.nodeEnabled(_:)` (per-node predicate). Single `copy(_:)` (R2). `isEnabled` already native env (X1 round-2/R3). Stored config flipped `private let`→`private var` with defaults. The `var isNodeEnabled` stored property, the `func nodeEnabled(_:)` modifier, and the private `func nodeEnabled(_ node:)` helper coexist (distinct signatures, legal Swift). Call sites migrated (4): MoreDemos TreeSelectDemo knob (4 modifiers), ComponentRegistry usage string, ScreenshotGenerator gallery shot, #Preview. Snapshots unchanged (modifier defaults == old param defaults → visually identical).
