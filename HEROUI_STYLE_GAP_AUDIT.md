# ThemeKit Flexibility Gap Audit — HeroUI + Ant Design parity, implementation-ready

**Scope:** every component under `Sources/ThemeKit/Components` (Atoms 56 · Molecules 104
incl. `Buttons/`+`Charts/` · Organisms 87 — all enumerated, see the Coverage Index).
**References:** HeroUI core (heroui.com/docs/components), HeroUI Pro
(heroui.pro/docs/react/components), **Ant Design** (ant.design/components — Input,
Button, Select, notification API tables fetched and quoted 2026-07-10; the rest from the
prior Ant-parity sweep, PRs #13–#44 / #202–#211).
**Method:** full public-modifier-surface extraction for all 217 files + deep reads of the
field/control/feedback/button/row families. Every gap cites verified `file:line` on
`main` @ `3cf0721`. **Survey-before-adding was applied** — the library is far more
Ant/HeroUI-complete than it looks; components listed "✓" in the Coverage Index were
checked and need nothing.

**This document is the implementation plan.** Each gap has a concrete, house-rules-
compliant API (copy-on-write modifier, token-fed signature, `SlotContent` slot, or
environment default) and is sequenced into waves at the end. It does not re-open
`HEROUI_NATIVE_AUDIT.md`'s shipped per-component plans or `HEROUI_INFRA_PLAN.md`'s
13 shipped infra units.

---

## Executive summary

| Severity | Count | Themes |
|---|---|---|
| **P0** (blocks parity) | 2 | No read-only axis anywhere; per-instance `size` missing/bespoke on 12 of 15 field components |
| **P1** (common usage) | 10 | ControlRow trailing-only control; helper/description text can't carry links (whole form stack); `required()` missing on 8 fields; TextInput fixed height clips under Dynamic Type; InputNumber off the size ramp; FeedbackDefaults missing 7 provider knobs (Ant `notification.config` / HeroUI ToastProvider); ComponentDefaults consumed by only 5/217 components; EmptyState & Callout plain-text bodies |
| **P2** (nice-to-have) | 34 | Leading-only controls; label slots; Tooltip rich content; toast placement/haptics/progress; RTL-unmirrored chevrons; long-tail per-component axes (clearable/searchable/loading/marker slots/decimal InputNumber/…); size-vocabulary booleans; raw-Color/CGFloat deprecation batch |

Two structural stories: **(1)** the field family shipped its axes piecemeal — `size`,
`required`, `helperText`, `validate`, height-scaling each exist on 2–4 components and
are absent or bespoke on the rest; **(2)** the provider layer (`FieldDefaults` /
`FeedbackDefaults` / `ComponentDefaults`) exists but is thin — few knobs, few
consumers — vs `HeroUIProvider` + Ant's `ConfigProvider`/`notification.config`.

---

## A. Placement / mirroring / orientation

| # | Component | Gap | Reference behavior | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| A1 | **ControlRow** | Boolean control renders only **trailing** (label block → `Spacer` → `indicator`); no placement modifier in the surface (`description/control/indicator/required/hasError/errorText/a11yID`). | HeroUI checkbox/radio/switch rows: control on either side; Ant Checkbox/Radio: control leads. | **P1** | `func controlPlacement(_ edge: HorizontalEdge) -> Self` (default `.trailing`); branch the `HStack` order. Keep the row as the single a11y element (`.accessibilityHidden(true)` on the indicator, :80, must survive both orders). | `Molecules/ControlRow.swift:68-81, 138-170` |
| A2 | **Checkbox** | Box hard-wired **leading**. Inconsistent with A1 (same control family, opposite fixed side, no axis on either). | Same. | P2 | Same `controlPlacement(_:)` vocabulary. | `Molecules/Checkbox.swift:91-98` |
| A3 | **RadioButton** | Control hard-wired leading. | Same. | P2 | Same axis. | `Molecules/RadioButton.swift:92-100` |
| A4 | **RadioGroup** | Option rows: radio leading, `Spacer` last; no group-level placement. | Same. | P2 | Group-level `controlPlacement(_:)` forwarded to rows. | `Molecules/RadioGroup.swift:80-93` |
| A5 | **CheckboxGroup** | Rows `HStack { Checkbox…; Spacer() }` — leading-only, incl. select-all row. | Same. | P2 | Same forwarded axis. | `Molecules/CheckboxGroup.swift:66-71, 88-93` |
| A6 | **CheckboxGroup** | No layout-orientation axis — always a `VStack`; `RadioGroup` has `.axis(_:)` (`RadioGroup.swift:234`), CheckboxGroup doesn't (surface: `infoMessages/selectAll/optionEnabled/a11yID`). | Ant `Checkbox.Group` lays out horizontally by default; HeroUI `orientation`. | P2 | `func axis(_ a: Axis) -> Self` — copy RadioGroup's implementation (`RadioGroup.swift:62-68`). | `Molecules/CheckboxGroup.swift:60-71, 126-136` |
| A7 | **ThemeButton** | `loading(_:)` swaps the entire label for a `ProgressView`; no spinner-alongside-label. (Icon placement itself is fine — `icon(leading:trailing:)` ✓ = Ant `iconPlacement`.) | Ant Button `loading: { icon }` keeps label; HeroUI `spinnerPlacement="start"/"end"`. | P2 | `func spinnerPlacement(_ edge: HorizontalEdge) -> Self`; when set, compose the spinner into the label `HStack` at :139 instead of replacing `content`. | `Molecules/Buttons/ThemeButton.swift:123-124, 139-152` |

---

## B. Rich text / link slots

The library owns the link-capable atom — `InlineText`
(`Atoms/InlineText.swift:12-50`) — and **InfoBanner already uses it**
(`Organisms/InfoBanner.swift:126`: `InlineText(message, links: links)`). Every other
description/helper/caption surface is plain `Text`.

**One idiom for all fixes:** a `links:` axis (the InfoBanner pattern) for string
surfaces; `SlotContent` slots only where full composition is warranted (D-section).

| # | Component | Gap | Reference | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| B1 | **HelperText** (atom) | Body is `Text(text)`. This atom is the description line for the whole form stack — `TextInput.helperText(_:)` and `ControlRow.description(_:)` route through it — so "agree to the *Terms*" copy can't link. | HeroUI `description` is a node; Ant `extra`/`help` are ReactNode. | **P1** | `func links(_ links: [(substring: String, action: () -> Void)]) -> Self`; render via `InlineText` when non-empty. Fix once, upgrade every consumer. | `Atoms/HelperText.swift:43`; consumers `Molecules/TextInput.swift:511`, `Molecules/ControlRow.swift:74` |
| B2 | **EmptyState** | `message` renders plain `Text(message)`. | HeroUI Pro empty-state descriptions carry anchors; Ant Empty `description` is a node. | **P1** | `func message(_ text: String, links: [(String, () -> Void)]) -> Self` overload. | `Organisms/EmptyState.swift:92, 121` |
| B3 | **Callout** | Body `Text(text)` — sibling InfoBanner supports links, Callout doesn't. | Ant Alert `description` node; HeroUI Alert. | **P1** | Same `links:` pattern for API symmetry with InfoBanner. | `Organisms/Callout.swift:91` |
| B4 | **InputLabel** (atom) | `Text(text)` only. | HeroUI `label` node; Ant Form label node. | P2 | `links:` on the atom (asterisk/info glyphs unchanged). | `Atoms/InputLabel.swift:28` |
| B5 | **AlertToast** | `message` plain `Text` (one tappable `action(_:)` title exists, :151). | Ant notification `description` node. | P2 | `links:` on `message(_:)`; forward through `FeedbackPresenter.toast(...)`. | `Organisms/AlertToast.swift:144` |
| B6 | **Feedback notification layer** | Notification-card message plain `Text(message)`. | Ant notification `description` node. | P2 | Forward `links:` through `FeedbackPresenter.notify(...)`. | `Organisms/Feedback.swift:453` |
| B7 | **RadioGroup** | Per-option `description` plain `Text`. | Ant Radio description node. | P2 | Render option descriptions through `HelperText` (inherits B1 + disabled/error tokens). | `Molecules/RadioGroup.swift:88-91` |
| B8 | **Checkbox / RadioButton** | Label plain `Text(label)` — no rich text, no slot (see D1). | Checkbox children are nodes. | P2 | Covered by D1. | `Checkbox.swift:94`, `RadioButton.swift:100` |
| B9 | **Tooltip** | Bubble is `Text(text)` only. | HeroUI/Ant Tooltip content node. | P2 | Covered by D2. | `Molecules/Tooltip.swift:134` |

---

## C. Size axes that don't enforce geometry

`TextInputSize` defines the family ramp — xsmall 36 / small 44 / medium 56 / large 64
(`Molecules/TextInput.swift:12-21`) — matching Ant Input's small/medium/large and
HeroUI's sm/md/lg fixed heights. Per-instance adoption is 3 of ~15.

| # | Component | Gap | Reference | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| C1 | **Field family — 12 components** | Per-instance `.size(_:)` exists only on TextInput (:505), Select (:315), MultiLineTextInput (:222). **Subtree-`FieldDefaults`-only** (no per-instance modifier): SearchBar (:137), DateField (:85), OTPInput (:78). **No size axis, fixed height**: TimeField (:114), SelectBox (48pt :109), Autocomplete (48pt :110), FieldButton (56/48pt :63), ColorField (52pt :57), PaymentCardField (52pt :107), Mentions (40pt :72). (SearchField's 64pt is a deliberate design constant, :101 — exempt.) A form mixing TextInput + SelectBox + DateField cannot be uniformly `.small`. | Ant Input/Select/Picker: `size: large/medium/small` with fixed heights (verified API table); HeroUI `size sm/md/lg`. | **P0** | Uniform `func size(_ s: TextInputSize) -> Self` on every field-shaped component → `.scaledControlHeight(s.height)`, precedence `explicit ?? fieldDefaults.size ?? componentDefault` (template: `TextInput.swift:202`). PR per component. | cited inline |
| C2 | **InputNumber** | Bespoke `large()` boolean → 40/48pt — neither on the ramp; never aligns with a `.small` (44) TextInput beside it. | Ant InputNumber `size` = Input sizes. | **P1** | `size(_ s: TextInputSize)`; `@available(*, deprecated)` shim `large()` → `.size(.large)`. | `Molecules/InputNumber.swift:61, 114, 260` |
| C3 | **Chip** | `ChipSize` = `small/large`, padding-only — no enforced min-height/hit target; mixed-content chips misalign. | HeroUI Chip `sm/md/lg` fixed heights. | P2 | Per-case `minHeight` via `scaledControlHeight`; add `.medium`. | `Atoms/Chip.swift:9-22` |
| C4 | **Checkbox / RadioButton glyphs** | `controlSize.checkboxSide`: mini/small → 20, *everything else* → 24 — `.large`/`.extraLarge` silently no-op. | HeroUI Checkbox `sm/md/lg` = 3 box sizes. | P2 | Extend mapping (`.large/.extraLarge → 28`); keep `customSize` escape hatch. | `Molecules/Checkbox.swift:13-18` |
| C5 | **Size-vocabulary booleans** | `ScoreBadge.large()` (`Atoms/ScoreBadge.swift:213` in surface dump), `InputNumber.large()` (C2), `Steps.small()` (`Molecules/Steps.swift:777` surface) — boolean size toggles instead of the kit's size-enum vocabulary. | Ant uses `size` enums everywhere. | P2 | Deprecate-and-forward each to a size enum (`ScoreBadgeSize`, `TextInputSize`, `StepsSize`) for a uniform axis name. | cited inline |

---

## D. Missing slots

| # | Component | Gap | Reference | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| D1 | **Checkbox / RadioButton** | Label is `String?` init arg only — no `.label { }` slot (canonical slot vocabulary already reserves the name). | Checkbox/Radio children are nodes. | P2 | `func label<V: View>(@ViewBuilder _ content: () -> V) -> Self` storing `SlotContent`. | `Molecules/Checkbox.swift:63-69, 93-97` |
| D2 | **Tooltip** | String-only API (`func tooltip(...)` :240/:257); no content slot. | HeroUI/Ant Tooltip content node. | P2 | `func tooltip<C: View>(isPresented:…, @ViewBuilder content:)` overload reusing bubble chrome. | `Molecules/Tooltip.swift:134, 240-257` |
| D3 | **Callout** | No `.leading{}/.trailing{}` — sibling InfoBanner has both (`InfoBanner.swift:200-207`); asymmetric alert APIs. | Ant Alert `icon`/`action` nodes; HeroUI `startContent/endContent`. | P2 | Mirror InfoBanner's slot pair. | `Organisms/Callout.swift:125-143` |
| D4 | **EmptyState** | Actions are string+closure only; no `.actions { }` slot. Also carries raw-token knobs — `iconForeground(_ c: Color?)` :125, `imageMaxHeight(CGFloat)` :124, `iconCircleSize(CGFloat)` :129 (token overloads exist alongside; see G5). | Ant Empty children node; HeroUI Pro action nodes. | P2 | `.actions { }` SlotContent slot (ResultView precedent — it already has `.icon{}/.content{}/.extra{}`, `Organisms/ResultView.swift:1449-1451` surface). | `Organisms/EmptyState.swift:130-131` |
| D5 | **Timeline** | No custom-dot slot — `Steps` has `.marker { }` (`Molecules/Steps.swift:779` surface), Timeline only `axis/mode/reversed/pending`. | Ant Timeline custom `dot` per item. | P2 | `func marker<V: View>(@ViewBuilder _ content: @escaping (Item, Int) -> V) -> Self` — Steps precedent. | `Organisms/Timeline.swift:1551-1554` (surface) |
| D6 | **NotificationCard** | No action-button axis — surface is `message/date/unread/variant/onClose/leading/surface/cornerRadius/elevation`; a notification can't carry "View"/"Undo". | Ant notification `actions` (verified API); HeroUI Pro notification CTA row. | P2 | `func action(_ title: String, onAction: @escaping () -> Void) -> Self` (Callout/InfoBanner pattern) + optional secondary. | `Organisms/NotificationCard.swift:1385-1393` (surface) |
| D7 | **KanbanBoard** (new, #249) | Zero chainable appearance modifiers — card slot lives in `init` ✓ but no `columnWidth`, `spacing`, or accent axes; `KanbanColumn` takes `accent:` as an **init arg** (violates house rule 3: modifiers = appearance). | Ant Pro Board / HeroUI Pro kanban expose column sizing. | P2 | `func columnWidth(_ w: KanbanColumnWidth) -> Self` (enum, not CGFloat), `func spacing(_ key: Theme.SpacingKey) -> Self`; move column accent to a modifier or document the model-arg exception. | `Organisms/KanbanBoard.swift:23, 33-41` |
| D8 | **EmojiReactionButton** (new, #249) | Zero appearance modifiers (controlled/uncontrolled inits only ✓). No size/accent axis. | HeroUI Pro reaction chips have sizes. | P2 | `func size(_ s: ChipSize) -> Self`, `func accent(_ c: SemanticColor?) -> Self`. | `Molecules/EmojiReactionButton.swift:17-35` |

---

## E. Missing states / variants / behavior axes

| # | Component | Gap | Reference | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| E1 | **Entire library — no read-only axis** | `grep -ri readonly Sources/ThemeKit` → 0 hits. `.disabled(_:)` is the only off switch and it dims to `textDisabled` + changes a11y semantics — wrong for review/summary screens. | HeroUI `isReadOnly` on all inputs; Ant `readOnly` on Input/InputNumber. | **P0** | Kit-wide environment axis: `public func readOnly(_ on: Bool = true) -> some View` → `EnvironmentValues.isReadOnly`; fields keep normal chrome, suppress editing/focus/clear, keep VoiceOver value. Infra PR + per-field adoption PRs. | verified absent (repo grep 2026-07-10) |
| E2 | **Required indicator — 8 components** | `.required()` only on TextInput (:485), MultiLineTextInput (:227), ControlRow (:153). Missing: Select, SelectBox, DateField, TimeField, InputNumber, OTPInput, RadioGroup, CheckboxGroup — all already render `InputLabel`-style headers that support `.required(_:)` (`InputLabel.swift:53`). | HeroUI `isRequired`; Ant Form required mark. | **P1** | Same `required(_ on: Bool = true)` modifier per component → forward to `InputLabel`; honor `FieldDefaults.requiredIndicator` (F4) from day one. | verified per component (`grep "func required"`) |
| E3 | **`.validate` rollout — 6 components** | The `ValidationRule` engine exists and is wired only into TextInput (`TextInput.swift:528-541`). OTPInput, InputNumber, DateField, TimeField, Autocomplete, PaymentCardField expose `errorText`/`infoMessages` but no `.validate(_:on:)`. | Ant Form rules per field; HeroUI `validate`. | P2 | `func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger = .editingEnd) -> Self` per component, reusing the TextInput plumbing. (Deliberately deferred earlier as design-intensive — schedule as feature work, wave 3.) | `Molecules/TextInput.swift:528-541`; absence verified in each file's surface |
| E4 | **Checkbox** | No `lineThrough` label treatment when checked. | HeroUI Checkbox `lineThrough`. | P2 | `func lineThrough(_ on: Bool = true) -> Self` → `.strikethrough(isChecked)`. | `Molecules/Checkbox.swift:93-97` |
| E5 | **RadioGroup / CheckboxGroup** | Group-level `title` ✓ (`RadioGroup.swift:48-54`), `infoMessages` ✓, but no group-level `description`. | Ant/HeroUI group `description`. | P2 | `func description(_ text: String?) -> Self` → `HelperText` under the title. | `RadioGroup.swift:51-56`; `CheckboxGroup.swift:60-65` |
| E6 | **Autocomplete** | No `clearable`, no `loading`, no validation axes (surface: `placeholder/maxResults/debounce/suggestionEnabled/onSearch/a11yID`). | Ant AutoComplete `allowClear/status`; HeroUI Autocomplete `isClearable/isLoading/isInvalid`. | P2 | `clearable(_:)` + `loading(_:)` + `infoMessages(_:)` — copy Select's implementations (`Select.swift:309-321`). | `Molecules/Autocomplete.swift:307-313` (surface) |
| E7 | **Cascader** | Only `placeholder/changeOnSelect`. No `searchable`, `clearable`, `optionEnabled`, validation. | Ant Cascader `showSearch/allowClear/disabled options/status` (verified pattern from Select API). | P2 | Port the Select/TreeSelect axes: `searchable(_:)`, `clearable(_:)`, `nodeEnabled(_:)`, `infoMessages(_:)`. | `Molecules/Cascader.swift:327-328` (surface) |
| E8 | **Transfer** | Only `titles(_:_:)`. No per-list search, no item-disable predicate. | Ant Transfer `showSearch`, `disabled`, per-item disable. | P2 | `searchable(_:)` + `itemEnabled(_ predicate:)` (kit-standard `isOptionEnabled` idiom). | `Molecules/Transfer.swift:852` (surface) |
| E9 | **ToggleGroup** | Only `optionDescription/a11yID`. Missing `optionEnabled` (CheckboxGroup has it), `accent`, `axis`. | Ant/HeroUI group axes. | P2 | Port the three standard group modifiers. | `Molecules/ToggleGroup.swift:845-846` (surface) |
| E10 | **MultiLineTextInput** | Missing `helperText(_:)` and `warningText(_:)` — TextInput has both (:511, :517); the two text editors have asymmetric message APIs. | Ant TextArea shares Input's API. | P2 | Add both modifiers routing through the same `HelperText`/`InfoMessageList` path. | `Molecules/MultiLineTextInput.swift:507-516` (surface; absence verified) |
| E11 | **InputNumber** | `Int`-only binding — no decimal values, no `precision`/`formatter`. | Ant InputNumber: decimal + `precision/formatter/parser`. | P2 | `InputNumber<V: BinaryFloatingPoint>` overload or a `Decimal` init + `func precision(_ digits: Int) -> Self`; keep Int init. | `Molecules/InputNumber.swift:470-479` (surface) |
| E12 | **Rating** | No clear-on-re-tap. | Ant Rate `allowClear` (tap current value → 0). | P2 | `func allowClear(_ on: Bool = true) -> Self`. | `Atoms/Rating.swift:190-199` (surface) |
| E13 | **MultiSelect** | `maxTags` caps the *display*; no selection-count limit. | Ant Select `maxCount` (verified API). | P2 | `func maxSelection(_ count: Int?) -> Self` — disable unselected options at the cap. | `Molecules/MultiSelect.swift:525` |
| E14 | **Tag** | No `closable/onClose` — FilterChip has `closable` (`Molecules/Chips.swift:351`), Tag needs the `.trailing{}` slot hand-rolled. | Ant Tag `closable + onClose`. | P2 | `func closable(_ onClose: @escaping () -> Void) -> Self` rendering the kit `CloseButton`. | `Atoms/Tag.swift:262-269` (surface) |
| E15 | **Avatar** | No border ring axis. | HeroUI `isBordered`; Ant Avatar ring via style. | P2 | `func bordered(_ on: Bool = true, accent: SemanticColor? = nil) -> Self` (token stroke). | `Atoms/Avatar.swift:14-25` (surface) |
| E16 | **Splitter** | Horizontal only (`bounds(min:max:)` is the whole surface). | Ant Splitter supports vertical layout + collapsible panels. | P2 | `func vertical(_ on: Bool = true) -> Self` (kit-standard axis name, cf. Space/Flex); optional `collapsible(_:)`. | `Molecules/Splitter.swift:758` (surface) |

---

## F. Provider / defaults incompleteness

| # | Surface | Gap | Reference | Sev | API to add | Source |
|---|---|---|---|---|---|---|
| F1 | **FeedbackDefaults** | 3 knobs only. Hardcoded in the host: **edge offset** (`.padding(.md)` :504 — Ant `top/bottom: 24` config), **inter-toast spacing** (`VStack(spacing: .sm)` :490), **insert/remove animation** (`Motion.base.spring` :414), **swipe-to-dismiss** always-on, fixed 60/120pt (:559-563), **no pause-on-drag** (auto-dismiss `.task` keeps running mid-swipe :567-572 — Ant `pauseOnHover: true` default), **no timeout progress** (Ant `showProgress`), **no haptic on show** (zero `Haptics` calls in Feedback.swift), **notification layer pinned `.top`** (:409). | Ant `notification.config({placement, top/bottom, duration, maxCount, showProgress, pauseOnHover})` — verified; HeroUI ToastProvider (`toastOffset`, `disableAnimation`, `shouldShowTimeoutProgress`). | **P1** | Extend `FeedbackDefaults` (optional fields, existing merge semantics): `toastOffset: Theme.SpacingKey?`, `toastSpacing: Theme.SpacingKey?`, `toastMotion: Motion?`, `swipeToDismiss: Bool?`, `showsTimeoutProgress: Bool?`, `hapticsOnShow: Bool?`, `notificationPosition: ToastPosition?`. Pause-on-drag is a bug-grade fix regardless. | `Organisms/FeedbackDefaults.swift:29-36`; `Organisms/Feedback.swift:414, 490, 504, 559-572, 409` |
| F2 | **ToastPosition** | `case top, bottom` only. | Ant: 6 placements (verified); HeroUI: 6. | P2 | Additive logical cases (`.topLeading/.topTrailing/.bottomLeading/.bottomTrailing`) → overlay alignments; RTL-safe names. | `Organisms/Feedback.swift:74` |
| F3 | **ComponentDefaults adoption** | Consumed by only **5 travel organisms** (RoomCard, StickyBookingBar, PriceAlertCard, AncillaryCard, AgentPriceRow — repo grep). Core ignores it: ThemeButton hardcodes `color = .primary` (:34) and shape radius (:187); Card/Chip/Badge likewise. "Set the app accent once" doesn't re-tint the button family. | Ant `ConfigProvider` / `HeroUIProvider` cascade everywhere. | **P1** | Resolve `explicit ?? componentDefaults.accent ?? .primary` (5-organism precedent) in ThemeButton, Chip, Badge, Card, FloatingActionButton, SegmentedControl. PR per component. | `ComponentDefaults.swift:18-27`; `ThemeButton.swift:34, 187` |
| F4 | **FieldDefaults.requiredIndicator** | Honored only by TextInput + MultiLineTextInput (repo grep); ControlRow renders the asterisk directly and ignores the default. | Provider defaults apply uniformly. | P2 | Read `\.fieldDefaults.requiredIndicator` in ControlRow + all E2 adopters. | `ControlRow.swift:70-71` |
| F5 | **FieldDefaults breadth** | Only `size/messagesAnimated/requiredIndicator`. No subtree default for `clearable` or `ValidationTrigger`. (Field *variant* is already covered by `.fieldStyle(_:)` env ✓ — Ant Input `variant` maps to Default/Muted/Underlined FieldStyles, `FieldStyle.swift:138-151`.) | Ant ConfigProvider input config. | P2 | `clearable: Bool?`, `validationTrigger: ValidationTrigger?` with the existing merge pattern. | `FieldDefaults.swift:24-44` |
| F6 | **Feedback barriers vs Backdrop** | Loading/confirm scrims are raw `bgTertiary.opacity(0.3/0.4)` — not the shared `Backdrop` atom / `bgBackdrop` token from infra unit 2; two backdrop colors in one host, neither themable. | Provider-level overlay consistency. | P2 | Replace both with `Backdrop`. | `Organisms/Feedback.swift:429, 512` |

---

## G. A11y / RTL / Dynamic Type / token hygiene

| # | Component | Gap | Sev | Fix | Source |
|---|---|---|---|---|---|
| G1 | **TextInput** | Field row pinned with raw `.frame(height: effectiveSize.height)` — clips floating label + value at accessibility type sizes. Its own family already uses `scaledControlHeight` (SearchBar :205, Select :143, DateField :143, SelectBox, Autocomplete, TreeSelect, MultiSelect, TimeField). | **P1** | One line: `.scaledControlHeight(effectiveSize.height)`. | `Molecules/TextInput.swift:329` |
| G2 | **ColorField / FieldButton / Mentions** | Fixed unscaled heights (52 / 56–48 / 40pt); no `scaledControlHeight` or documented `dynamicTypeClamp` (OTPInput clamps correctly, `OTPInput.swift:136`). | P2 | `scaledControlHeight` — folds into their C1 size PRs. | `ColorField.swift:57`, `FieldButton.swift:63`, `Mentions.swift:72` |
| G3 | **RTL-unmirrored glyphs** | `chevron.right/left`, `arrow.right` without `.mirrorsInRTL()`: `TreeView.swift:48`, `DatePriceStrip.swift:151,153`, `PriceTrendChart.swift:121,125`, `RecentSearchRow.swift:59` (its :97 chevron *does* mirror). Correct precedents: `Dropdown.swift:433`, `TreeSelect.swift:177`, `Pagination.swift:139`, `SearchBar.swift:148`, `SuggestionRow.swift:107`. | P2 | Add `.mirrorsInRTL()` at the 6 sites. | cited inline |
| G4 | **A1 design note** | Leading-control ControlRow must keep the single-a11y-element contract (`.accessibilityHidden(true)` on the indicator, :80). | — | Folded into A1. | `ControlRow.swift:80` |
| G5 | **Raw-Color/CGFloat modifier batch** (token-hygiene deprecations; each has or needs a token twin) | `Badge.badgeColor(_ Color?)` :207 + `gradient(_ [Color]?)` :209; `RadioButton.fillColor(_ Color?)` :184; `AmenityGrid.tint(_ Color?)` :128 (semantic twin at :129 ✓); `PriceHistogram.accent(_ Color?)` :106 (twin ✓); `EmptyState.iconForeground/Background(_ Color?)` :125,:127 (twins ✓); `Card.contentPadding(_ CGFloat)` :153 (no `SpacingKey` twin — SurfaceView has one, `Atoms/SurfaceView.swift:251`); `Checkbox.customSize(_ CGFloat)` :185 (documented escape hatch — keep); `LoyaltyCard.gradient(_ [Color]?)` (surface :1365). | P2 | Where a token twin exists: `@available(*, deprecated, message: "Use the token overload")`. Where missing (Card.contentPadding): add `contentPadding(_ key: Theme.SpacingKey)` first, then deprecate. One batch PR. | cited inline |

---

## Coverage Index — every component reviewed

Legend: **✓** = surveyed, no gap worth opening (parity adequate for its role) ·
**Gxx/…** = gap IDs above · *(support)* = models/style-protocol/layout file, no
public component surface. Survey basis: full modifier-surface extraction (all files)
+ targeted deep reads.

**Atoms (56):**
AnimatedImage ✓ · Aura ✓ · Avatar E15 · Backdrop ✓ · Badge G5 · Barcode ✓ ·
BorderBeam ✓ · Chip C3 · ChipStyle *(support)* · CloseButton ✓ · CodeBlock ✓ ·
ColorSwatch ✓ · Confetti ✓ · CornerRadiusModifier *(support)* · CountBadge ✓ ·
CountdownTimer ✓ · DividerView ✓ · FareFeatureRow ✓ · FlightStatusBadge ✓ ·
GaugeView ✓ · HelperText B1 · Icon ✓ · IconTile G5-adjacent (CGFloat sizes; token
twins exist) · Indicator ✓ · InlineText ✓ (the fix vehicle) · InputLabel B4 · Join ✓ ·
Kbd ✓ · Mask ✓ · MeterStyle *(support)* · PointsBadge ✓ · PriceTag ✓ · ProgressBar ✓ ·
QRCode ✓ · RadialProgress ✓ · Rating E12 · RemoteImage ✓ · RollingNumber ✓ ·
ScoreBadge C5 · SearchBadge ✓ · SeatCell *(support)* · ShareButton ✓ · Skeleton ✓ ·
SkeletonGroup ✓ · Spinner ✓ · StatusDot ✓ · SurfaceView ✓ · Swap ✓ · SwapButton ✓ ·
Tag E14 · TextLink ✓ · TextRotate ✓ · TiltCard ✓ · Title ✓ · TrendChip ✓ (new #249) ·
Watermark ✓

**Molecules (104):**
Affix ✓ · AmenityGrid G5 · AnchorNav ✓ · Autocomplete C1 E6 · Breadcrumbs ✓ ·
ButtonGroup ✓ · Buttons/Buttons ✓ (presets; `helperText`+`confirmsSuccess` already
rich) · Buttons/ButtonSize *(support)* · Buttons/ThemeButton A7 F3 ·
CalendarView ✓ · CalendarYearPicker ✓ (new) · Cascader E7 · Charts/AreaChart ✓ (new) ·
Charts/BarChart ✓ · Charts/ChartModels *(support)* · Charts/ChartSupport *(support)* ·
Charts/DonutChart ✓ · Charts/LineChart ✓ · Checkbox A2 B8 C4 D1 E4 G5(customSize kept) ·
CheckboxGroup A5 A6 E5 · Chips ✓ (FilterChip closable ✓, emptyContent slot ✓) ·
ColorArea ✓ (new) · ColorField C1 G2 · ColorModels *(support)* · ColorSlider ✓ (new) ·
ColorSwatchPicker ✓ (new) · ColumnsGrid ✓ · ControlRow A1 B1(consumer) E2✓(has) F4 ·
CurrencyPicker ✓ · DateField C1 E2 E3 · DatePriceStrip G3 · Dropdown ✓ ·
EmojiReactionButton D8 (new) · FieldButton C1 G2 · Fieldset ✓ · FieldStyle *(support;
= Ant `variant` ✓)* · FileInput ✓ · FilterGroup ✓ · FilterRow ✓ · Flex ✓ ·
FlightRoute ✓ · FlowLayout *(support)* · GuestSelector ✓ · HoverCard ✓ (new) ·
InputNumber C2 E2 E3 E11 · InstallmentPicker ✓ · InstallmentSelector ✓ · LayoverRow ✓ ·
MapPriceMarker ✓ · Masonry ✓ · Mentions C1 G2 · MultiLineTextInput E10 (size ✓) ·
MultiSelect C1 E13 · OTPInput C1 E2 E3 · Pagination ✓ · PassengerRow ✓ ·
PaymentCardField C1 E3 · PriceBreakdown ✓ · PriceHistogram G5 · PriceTrendChart G3 ·
ProgressIndicator ✓ · QuantityStepper ✓ (thin but role-adequate; 44pt targets shipped) ·
RadioButton A3 B8 D1 G5 · RadioGroup A4 B7 E5 · RangeSlider ✓ · RecentSearchRow G3 ·
ScrollShadow ✓ · ScrubGallery ✓ · SearchBar C1 · SearchField ✓ (64pt exempt) ·
SearchSummary ✓ · SeatLegend ✓ · SegmentedControl ✓ · Select E2 (size ✓ loading ✓) ·
SelectBox C1 E2 · SelectStyle *(support)* · Slider ✓ · SmartSuggestion ✓ ·
SortSummaryBar ✓ · Space ✓ · Splitter E16 · Stat ✓ · StatStyle *(support)* ·
StepperRow ✓ · Steps C5 · SuggestionRow ✓ · TableCells *(support, new)* ·
TextInput E1 G1 B1 (gold standard otherwise) · TextInputFormatter *(support)* ·
ThemeContextMenu ✓ (new) · ThemeController ✓ · ThemeToggle ✓ · TimeField C1 E2 E3 ·
ToggleGroup E9 · Tooltip B9 D2 · Transfer E8 · TreeSelect ✓ · TreeView G3 ·
TripTypeToggle ✓ · ValidationRule *(support)*

**Organisms (87):**
Accordion ✓ · AccordionGroup ✓ · ActionBar ✓ (new) · Agenda ✓ (new) · AgentPriceRow ✓ ·
AlertToast B5 · AnchoredPopover ✓ · AncillaryCard ✓ · BarStyle *(support)* · BlogCard ✓ ·
BoardingPass ✓ · BottomSheet ✓ · BrowserFrame ✓ · ButtonDock ✓ · Callout B3 D3 ·
Card G5 (contentPadding) · CardStack ✓ · CardStyle *(support)* · Carousel ✓ ·
ChatBubble ✓ · ColorPickerPanel ✓ (new) · CommandPalette ✓ (new) · Counter ✓ · Coupon ✓ ·
DataTable ✓ (row-selection/sort deliberately out of scope — tracked in
HEROUI_NATIVE_AUDIT) · DestinationCard ✓ · Dialog ✓ · Diff ✓ · Drawer ✓ ·
EmptyState B2 D4 G5 · FareFamilyCard ✓ · FareSummary ✓ · Feedback F1 F2 F6 B6 ·
FeedbackDefaults F1 · FilterBar ✓ · FilterList ✓ · FlightCard ✓ · FlightListItem ✓ ·
FlightListItemStyle *(support)* · FlightResultRow ✓ · FlightTicketCard ✓ ·
FloatingActionButton F3 · Footer ✓ · Gallery ✓ · Hero ✓ · HotelResultCard ✓ ·
ImageCollage ✓ · InfoBanner ✓ (the exemplar) · KanbanBoard D7 (new) · KeyValueTable ✓ ·
ListRow ✓ · ListRowStyle *(support)* · ListView ✓ · LocationCard ✓ · LoyaltyCard G5 ·
MapCallout ✓ · MenuCard ✓ · NavigationBar ✓ · NotificationCard D6 · PageHeader ✓ ·
PageHeaderStyle *(support)* · PagingCarousel ✓ · PhoneFrame ✓ · Popconfirm ✓ ·
PriceAlertCard ✓ · PromoBanner ✓ · RatingSummary ✓ · ResultView ✓ · ReviewCard ✓ ·
RoomCard ✓ · SeatMap ✓ · SeatMapModels *(support)* · SegmentedTabBar ✓ ·
SelectionCards ✓ · SheetHeader ✓ · Sidebar ✓ · StickyBookingBar ✓ · ThemePicker ✓ ·
TicketStub ✓ · Timeline D5 · Toast ✓ · ToastStyle *(support)* · Tour ✓ · Upload ✓ ·
VideoPlayerView ✓ · WindowFrame ✓

---

## Implementation waves (PR-sized, sequenced)

Every unit: additive, copy-on-write, token-fed; verify via `#Preview` matrix +
`xcrun simctl launch <bundle> -startTab 0 -openDemo "<Component>"`.

### Wave 0 — Quick wins (7 tiny PRs, effort S each)
1. **G1** TextInput `.scaledControlHeight` (1 line).
2. **G3** RTL mirror batch (6 sites, 1 PR).
3. **F1-bug** Toast pause-on-drag (`FeedbackToastRow`: suspend the `.task` timer while `dragProgress > 0`).
4. **F4** ControlRow honors `fieldDefaults.requiredIndicator`.
5. **F6** Feedback barriers → `Backdrop` atom.
6. **A1** `ControlRow.controlPlacement(_: HorizontalEdge)`.
7. **E10** MultiLineTextInput `helperText`/`warningText` parity.

### Wave 1 — Field size unification (12 PRs, S–M each) — the P0
`func size(_ s: TextInputSize) -> Self` + `scaledControlHeight` + `explicit ??
fieldDefaults.size ?? default` on: SearchBar, DateField, TimeField, OTPInput,
SelectBox, Autocomplete, FieldButton, ColorField, PaymentCardField, Mentions,
MultiSelect, and **InputNumber** (C2, with deprecated `large()` shim). G2 folds in.

### Wave 2 — Read-only axis (1 infra PR + ~12 adoption PRs, M) — the other P0
ADR first (interaction with `.disabled`, focus, clear/reveal buttons, a11y traits),
then `\.isReadOnly` + `.readOnly(_:)`, then adopt: TextInput, MultiLineTextInput,
Select, SelectBox, DateField, TimeField, InputNumber, OTPInput, Checkbox,
RadioButton, ThemeToggle, ControlRow.

### Wave 3 — Required + validation completion (8 + 6 PRs, S each)
**E2** `required(_:)` on Select, SelectBox, DateField, TimeField, InputNumber,
OTPInput, RadioGroup, CheckboxGroup (each reading F4's default). **E3** `.validate`
on OTPInput, InputNumber, DateField, TimeField, Autocomplete, PaymentCardField.

### Wave 4 — Rich text links (1 atom PR + 6 adopter PRs, S each)
**B1** `HelperText.links(_:)` first (free upgrade for TextInput/ControlRow), then
B2 EmptyState, B3 Callout, B4 InputLabel, B5 AlertToast + B6 presenter forwarding,
B7 RadioGroup-via-HelperText.

### Wave 5 — Control placement + label slots (5 PRs, S–M)
A2–A5 `controlPlacement(_:)` across Checkbox/RadioButton/RadioGroup/CheckboxGroup
(+ A6 CheckboxGroup `.axis`), D1 `.label { }` slots, E4 `lineThrough`, E5 group
descriptions, C4 glyph-size mapping — grouped per component.

### Wave 6 — Provider expansion (3 PRs, M)
**F1** FeedbackDefaults knobs + host plumbing (token-fed: `SpacingKey` offsets/gaps,
`Motion` animation, Reduce-Motion-gated; haptics off by default). **F2** ToastPosition
corner cases. **F5** FieldDefaults `clearable`/`validationTrigger`. Then **F3**
ComponentDefaults adoption: ThemeButton, Chip, Badge, Card, FloatingActionButton,
SegmentedControl (PR per component).

### Wave 7 — Long-tail flexibility (batched small PRs, S each)
A7 ThemeButton `spinnerPlacement` · D2 Tooltip content slot · D3 Callout slots ·
D4 EmptyState `.actions{}` · D5 Timeline `.marker{}` · D6 NotificationCard `.action` ·
D7 KanbanBoard axes · D8 EmojiReactionButton axes · E6 Autocomplete · E7 Cascader ·
E8 Transfer · E9 ToggleGroup · E11 InputNumber decimals · E12 Rating `allowClear` ·
E13 MultiSelect `maxSelection` · E14 Tag `closable` · E15 Avatar `bordered` ·
E16 Splitter `vertical` · C3 Chip min-heights · C5 size-boolean deprecations.

### Wave 8 — Token-hygiene deprecations (1 batch PR, S)
**G5**: deprecate raw-`Color`/`CGFloat` twins toward token overloads; add the missing
`Card.contentPadding(_ key: Theme.SpacingKey)` first.

---

*Audited 2026-07-10 against `main` @ `3cf0721`. All `file:line` references verified by
direct read or extracted modifier-surface dump. Ant Design API tables for Input,
Button, Select, notification fetched from ant.design 2026-07-10; HeroUI behavior from
heroui.com / heroui.pro component APIs.*
