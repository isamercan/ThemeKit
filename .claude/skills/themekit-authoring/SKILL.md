---
name: themekit-authoring
description: >-
  Use when AUTHORING or EXTENDING a component INSIDE the ThemeKit library
  (Sources/ThemeKit) — building a new atom/molecule/organism, adding chainable
  modifiers, a style-driven API, or upgrading an existing component. This is the
  contributor guide (how the library is BUILT); for consuming ThemeKit in an app
  read the `themekit` skill instead. Trigger on "new component", "add a modifier",
  "extend <Component>", "style-driven", atom/molecule/organism, or editing files
  under Sources/ThemeKit/Components.
license: MIT
---

# Authoring ThemeKit components

ThemeKit is a **brand-neutral, token-driven SwiftUI component library**. Components
are **stateless value-type views** — no ViewModels, no networking, no backend DTOs.
Every color, radius, spacing, and type style resolves at runtime from the active
`Theme`, so one theme change re-skins the whole library. Your job when adding a
component is to make it compose, theme, localize, and mirror (RTL) for free.

> This adapts generic SwiftUI guidance to *this* codebase. Where generic advice
> says "use MVVM / @StateObject / async-await / semantic asset colors," that is
> **app** advice and does **not** apply to leaf components here. The parts that do
> apply — view composition, ViewModifiers, custom styles, `@State`/`@Binding` for
> local interaction, accessibility, Dynamic Type, previews — are baked in below.

Copy-pasteable reference implementations (atom, molecule, style-driven organism)
live in [`references/patterns.md`](references/patterns.md). Read it before writing a
new component — start from a template, don't reinvent the shape.

## The 6 house rules (non-negotiable)

1. **Stateless & data-driven.** A component takes value types / provider closures,
   never a backend schema. Local UI-only state (`@State private var chosen`) is
   fine; app state is not. No `ObservableObject`, no `Task`, no network.
2. **Brand-neutral & generic.** No coupling to any real app (ets/Voyage/etc.), no
   domain data model. Offer generic overrides for anything a brand might tweak.
3. **Init = content; modifiers = appearance.** Required content, bindings and
   actions go in `init`. Every variant, size, flag, color and callback is a
   **chainable modifier** using copy-on-write. No `size:`/`variant:`/`isEnabled:`
   init args.
4. **Token-fed, always.** No raw `Color`, no magic `CGFloat`. Colors → theme token
   keys or `SemanticColor`; radius → `Theme.RadiusRole`; spacing → `Theme.SpacingKey`;
   type → `.textStyle(_:)`. This applies to the body *and* to modifier signatures.
5. **Native modifiers for native concepts.** Size → `.controlSize(.small)`,
   disabled → `.disabled(_:)`. Do not invent `size:`/`isEnabled:` parameters.
6. **Accessible, localized, RTL-safe by construction** (sections below).

## The copy-on-write modifier pattern

House style for every configurable component: content + action in `init`, all
appearance in a `public extension` of chainable modifiers, each mutating a copy
through **one** `copy(_:)` point.

```swift
public init(_ text: String, action: (() -> Void)? = nil) { … }   // content + action only

public extension Badge {
    func badgeStyle(_ s: BadgeStyle) -> Self { copy { $0.style = s } }
    func size(_ s: BadgeSize) -> Self { copy { $0.size = s } }
    private func copy(_ mutate: (inout Self) -> Void) -> Self { var c = self; mutate(&c); return c }
}
```

Reads left-to-right: `Badge("Sale").badgeStyle(.error).variant(.solid).size(.small)`.
If a raw-value escape hatch must exist, **`@available(*, deprecated,…)` it toward
the token path** instead of promoting it. Full annotated struct → `references/patterns.md §1`.

## Slots (optional content areas)

Required content is a generic `@ViewBuilder` **init** parameter (type-preserved).
**Optional** slots are always copy-on-write modifiers — never extra init
overloads — storing the internal `SlotContent` helper
(`Sources/ThemeKit/Extensions/SlotContent.swift`): type-erased, `nil` = "use the
built-in". `SlotContent` is a `View`, so store it and render it directly:

```swift
private var customHeader: SlotContent?              // nil → built-in header

func header<H: View>(@ViewBuilder _ header: () -> H) -> Self {
    copy { $0.customHeader = SlotContent(header) }
}

// body:
if let customHeader { customHeader } else { titleHeader }
```

No `sending` is needed — the slot closure is non-escaping and evaluated
immediately during the parent's body construction (the style-erasure inits need
`sending` only because they store an *escaping* closure in the environment).

**Canonical slot vocabulary** — a component uses these names or none:

| Slot name | Meaning | Precedent |
|---|---|---|
| `.header { }` | replaces the built-in title header | `Card` |
| `.footer { }` | bottom-aligned accessory area | `Card` |
| `.leading { }` / `.trailing { }` | before/after the main content (RTL-safe by name) | `Chip` |
| `.label { }` | replaces a control's built-in text label | planned `ThemeButton` |
| `.indicator { }` | replaces a state glyph (spinner, chevron, thumb) | `Spinner`; planned Accordion |
| `.emptyContent { }` | shown when a collection component has no items | planned ChipGroup |

Slot content must render correctly with **zero configuration** — it inherits
`textStyle` and the surrounding chrome's foreground token from the environment
(as Card's header slot does). `TextInput.addons(before:after:)` keeps its domain
name (an input-group concept, not a generic slot).

**Slot-type stability (the `.id` rule):** `AnyView` diffs by the *wrapped
concrete type*. A slot re-erased on every parent render keeps `@State` and
transitions as long as it wraps the same type — but an `if/else` of two
*different* view types directly in a slot loses branch identity (cross-fade
instead of insert/remove). Wrap alternating slot content in `.id(_:)` to keep
insert/remove semantics.

## Token vocabulary (use these, never literals)

- **Read the theme:** `@Environment(\.theme) private var theme`.
- **Text:** `theme.text(.textPrimary | .textSecondary | .textTertiary | .textDisabled | .textHero)`
- **Surfaces:** `theme.background(.bgBase | .bgWhite | .bgSecondaryLight | .bgHero | …)`
- **Borders / foreground:** `theme.border(.borderPrimary | .borderHero | …)`, `theme.foreground(.fgHero | .systemcolorsFgSuccess | …)`
- **Semantic palette:** `SemanticColor` (`.primary .accent .neutral .info .success .warning .error` + brand hues), each with `.base .hover .active .soft .solid .border .onSolid` and a 50–900 ladder. Pair with `FillVariant` (`.soft .solid .outline .ghost`).
- **Radius by role:** `Theme.RadiusRole.box.value` (cards), `.field.value` (buttons/inputs/chips), `.selector.value` (badges/checkboxes). Size ramp: `Theme.RadiusKey.base.value`.
- **Spacing:** `Theme.SpacingKey.xs|sm|md|base|lg|xl.value`.
- **Type:** `.textStyle(.headingSm | .bodyBase400 | .labelSm600 | .overline400 | …)` — also gives Dynamic Type for free; never hardcode `.font(.system(size:))` for text.

Genuine dimensions with no semantic token (a fixed 22×22 logo frame, an aspect
ratio, a chart height) stay raw `CGFloat` — as **fixed constants inside the view**,
not as arbitrary knobs exposed in a modifier signature.

## Decompose: atom → molecule → organism

When a component grows past one screenful, split it. The public component is the
**organism**, built from smaller pieces:

- **Atom** — smallest reusable unit (`Badge`, `PriceTag`, `Icon`, `SeatCell`).
- **Molecule** — a few atoms with light logic (`FlightRoute`, `SeatLegend`).
- **Organism** — the shipped component (`FlightListItem`, `SeatMap`, `Card`).

Keep sub-views `private` in the same file unless independently useful. Models + any
generic palette (e.g. `SeatPalette`) go in a `<Component>Models.swift`.

## Style-driven API (organisms with multiple archetypes)

When one component needs several fundamentally different layouts (as `FlightListItem`
does with 9 styles), do **not** add a `variant` enum with a giant `switch` in the
body. Use the **style protocol + configuration** pattern: a `Configuration` struct of
typed data + captured `locale`/flags/callbacks, a `…Style` protocol with
`makeBody(configuration:)`, one struct per archetype (thin wrapper over a private
`…Chrome` view), static accessors via `where Self ==`, and type-erasure + an
`EnvironmentKey` + a `func …Style(_:)` view modifier so a list sets it once. Share
cross-style building blocks as private sub-views. Full skeleton → `references/patterns.md §3`.

## Accessibility

- Label every non-text control: `.accessibilityLabel(...)`; give togglers a
  state-aware label (`isExpanded ? "Collapse…" : "Expand…"`).
- Expose a stable test id where the convention exists: `.a11yID("...")`.
- Rely on `.textStyle(_:)` for Dynamic Type; don't cap text with fixed heights that clip.
- Use SF Symbols (`Image(systemName:)` / the `Icon` atom) for iconography.

## Localization & RTL

- **English only, generic strings.** Never Turkish, never "ets"/"etstur" in copy or
  placeholders. Wrap user-facing text: `String(localized: "Nonstop", bundle: .module)`.
- **Format with the captured locale**, not the device default — take a `locale` into
  the configuration and use `.formatted(….locale(locale))` for dates/numbers so
  injected locales and RTL demos render correctly.
- **Build for RTL by construction:** compose from `HStack`/`VStack` (they mirror
  automatically) rather than absolute `Path`/`GeometryReader` geometry. When you must
  draw a `Path` (sparkline, dashed line), add `.flipsForRightToLeftLayoutDirection(true)`.

## Previews & verification

- Ship a `#Preview` that exercises **every** variant — iterate the enums with
  `ForEach(BadgeStyle.allCases, …)`, and show a light + a themed/dark case.
- Add or extend the matching Demo/Gallery entry, then verify it live by deep-link
  instead of tapping through the UI:
  ```
  xcrun simctl launch <bundle> -startTab 0 -openDemo "<Component Name>"
  ```
  then screenshot. Snapshot / a11y / RTL harness exists — keep new components in it.

## Naming & Swift hygiene

- `PascalCase` types, `camelCase` members; boolean props read `is…/has…/should…`.
- `guard` for early return; never force-unwrap — a style must render sensibly when
  optional data is absent.
- `public` only what callers need; keep chrome/sub-views/shapes `private`.

## Anti-patterns (don't → do)

- ❌ `Color(hex:)` / `.foregroundStyle(.blue)` in a component → ✅ `theme.text(.textPrimary)` / `SemanticColor`.
- ❌ `func badge(color: Color)` modifier → ✅ token key / `SemanticColor` / style-enum param.
- ❌ `cornerRadius: 12` → ✅ `Theme.RadiusRole.box.value`. ❌ `padding(16)` → ✅ `Theme.SpacingKey.md.value`.
- ❌ `Badge("x", size: .small, isEnabled: false)` → ✅ `Badge("x").size(.small).disabled(true)`.
- ❌ A `variant` enum + 200-line `switch` in `body` → ✅ the style-protocol pattern.
- ❌ ViewModel / `Task` / network / hardcoded JSON in a component → ✅ value types + provider closures.
- ❌ Re-implementing an existing atom (divider, price, chip) → ✅ compose the library's own.

## Before opening a PR for a component

- [ ] Content/actions in `init`; all appearance via chainable copy-on-write modifiers.
- [ ] Zero raw `Color`/magic numbers in body and modifier signatures.
- [ ] Reads theme from `@Environment(\.theme)`; re-skins under a preset/dark/brand change.
- [ ] Decomposed if large; public surface is the organism.
- [ ] a11y labels + Dynamic Type via `textStyle`; strings localized & English-only.
- [ ] Mirrors under RTL (or `Path`s flipped); dates/numbers use the captured locale.
- [ ] `#Preview` covers every variant; Demo/Gallery entry added and verified by deep-link.
