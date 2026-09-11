# ADR-0008 — Consumer-defined tokens (`custom.` namespace) & host-owned registration

- **Status:** **Accepted** (2026-09-11)
- **Date:** 2026-09-11
- **Deciders:** ThemeKit architecture
- **Context source:** A consumer integration (a UIKit travel app adopting `ThemeKitCore` behind an atomic-component package) whose Figma export carried tokens ThemeKit has no key for, plus a three-lens review of the first implementation (#344) that found it reachable from one of five entry points.
- **Rollout:** Additive. Every existing token, accessor and theme file behaves identically; a theme that declares nothing under the namespace is byte-identical to before.
- **Precedent mirrored:** ADR-0003 (consumer localization override) — the same shape of problem: a reserved seam that lets a host extend the library without the library learning anything about that host.
- **Shipped in:** #344, #345, #346, #347, #348.

## Context

A host app's design system almost always carries tokens ThemeKit has no key for — a campaign badge fill, a bespoke card corner, a price type style. Three properties are in tension:

1. **ThemeKit must stay brand-agnostic.** The color keys are generated from one design system by `tools/gen_tokens.py` and the names are deliberately semantic. Teaching them one consumer's token is how a shared library becomes a fork.
2. **Silently dropping unknown tokens is the worst outcome.** `apply(_ decoded:)`'s key-matching chain ended in nothing: a name matching no generated key was discarded with no signal, so a consumer's theme file "worked" while a third of it vanished.
3. **Stringly-typed token names are a documented non-goal.** `package func spacing(token:)` carries the rationale: *"stringly token names stay inside the library — consumers go through component modifiers or theme/CSS files."* Any escape hatch must not casually reverse that.

What already existed: `radiusList`, `spacingList`, `typographyList` and `shadowList` are `[String: …]` and `apply(_ decoded:)` writes **every** name from the theme file into them unconditionally. The data was already in memory; only a read path was missing. Colors were the exception — the `else if` chain dropped them.

## Decision

### D1 — A reserved namespace, not an open string API

ThemeKit owns the unprefixed token namespace. A consumer's tokens are declared under `Theme.customTokenPrefix` (`"custom."`) in the theme JSON or CSS.

The namespace is what makes a stringly read API compatible with the `spacing(token:)` rationale. The accessors take the **bare** name and prepend the prefix themselves, so a lookup can only ever land in the consumer's namespace — the generated keys and the `package`-level demand-minted component tokens (`card-padding`, …) are unreachable through it.

**This seals reads, not writes.** A theme file has always been an open write surface and may still name `card-padding` or any generated key directly; the CSS path does so deliberately via `spacingVarMap`. The namespace is a read contract, not a sandbox. #344's commit message overstated this and #345 corrected it.

### D2 — A typed name, not a raw `String`

`Theme.CustomToken` is `RawRepresentable` + `ExpressibleByStringLiteral` over the bare name:

```swift
extension Theme.CustomToken { static let fareBadge: Self = "fare-badge" }

theme.custom.color(.fareBadge) ?? theme.background(.bgHero)
```

The seal argument justifies a string reaching the dictionary; it does not justify a string at the call site. #344 shipped `customColor(_ name: String)` and its own documentation example had to write `.rawValue` at every use — the tell that the parameter type was wrong. One declaration site per token, dot-syntax and autocomplete at every use, and a place to assert on input.

`init(rawValue:)` asserts the name doesn't already carry the prefix: pasting the qualified name out of the theme file is the likeliest real mistake and would otherwise resolve `custom.custom.…` → `nil`, indistinguishable from "not defined". `qualifiedName` is the supported way back.

### D3 — One namespace object, five kinds

`theme.custom.color / .radius / .spacing / .textStyle / .shadow`, rather than five `customX(_:)` methods on `Theme`. A future token kind adds a member instead of a sixth and seventh top-level method.

Each kind has its own bare-keyed store, mirroring `brandPalette`. #344 separated only colors and left custom metrics in the dictionaries ThemeKit's own tokens resolve from; the stores are now symmetric, so a consumer token cannot sit next to — or be mistaken for — an internal one.

### D4 — Ownership: theme-declared vs host-registered

This is the decision that makes the feature usable, and the one #344 missed.

A theme file's `custom.` tokens belong to the **theme**: they arrive with it and leave with it. That is correct for a token a theme is meant to re-skin, and useless for an app's own brand token — because `apply(ThemeConfig)`, `ThemePreset.apply()` and `setTheme(css:)` all regenerate the token set from scalars, and `resetThemeState()` clears the namespace. #344 was therefore reachable from `setTheme(jsonData:)` and nowhere else — not from the entry point `ThemeConfig`'s own header calls *"the entry point a host app uses."*

`registerCustomTokens(_:)` declares a set that belongs to the **app**. It is re-seeded after every theme application, so it survives all five entry points. Where a theme and the app name the same token, **the registered value wins** — the app is the owner, and a theme switch must not silently repaint or drop its brand.

| | Theme-declared | Registered |
|---|---|---|
| `setTheme(jsonData:dark:)` | ✅ | ✅ |
| `setTheme(css:)` / `loadTheme(cssNamed:)` | ✅ | ✅ |
| `apply(ThemeConfig)` / `applyGenerated(…)` | ❌ | ✅ |
| `ThemePreset.apply()` | ❌ | ✅ |
| `loadTheme(named:dark:)` | ❌ | ✅ |

The rejected alternative was a `customTokens` field on `ThemeConfig`. It keeps tokens theme-owned and portable through `generatedTokenJSON(for:)`, but it bloats a type whose whole point is being a handful of scalars, still loses tokens on `ThemePreset.apply()`, and answers "what happens when the user picks a theme?" with "your badge changes color" — which is not what a host app wants from its own brand token.

### D5 — Dark variants

`CustomTokenSet.darkColors` overrides `colors` while the dark scheme is active, re-picked on every `setColorScheme(dark:)`. A theme file carries its dark variant the way it always has — in the `…Dark` JSON, or the `.dark` CSS block, which inherits from `:root` for anything it doesn't restate.

### D6 — CSS carries the namespace too

`--custom-color-*`, `--custom-radius-*`, `--custom-spacing-*` → `custom.<name>`. The kind sits in the var name rather than being inferred from the value: `1.25rem` is not a color, and a radius is indistinguishable from a spacing. `tools/import_css_theme.py` mirrors this, per the `// MARK: - Token mapping (mirrors import_css_theme.py)` contract, and the golden parity tests cover it.

ThemeKit's CSS surface has no typography or shadow vars, so the consumer namespace has none either. That is the existing CSS feature boundary, not a gap introduced here.

This required one symmetry fix in `ThemeGenerator`: `semanticOverrides` and `radiusOverrides` were override-only, so a name the generated set doesn't contain was dropped — while `spacingOverrides` already appended unknown keys, which is how demand-minted `card-padding` works. Colors and radius now append too.

### D7 — Diagnostics

A theme token matching no generated key and outside the namespace is logged in DEBUG rather than dropped in silence. That silent drop is the bug this ADR exists to fix, and a typo (`Custom.fare-badge`, `custom-fare-badge`) still lands in it. A warning, not `assertionFailure` — an older theme may legitimately carry a retired name.

`theme.custom.colors` / `.radii` / `.spacings` / `.textStyles` / `.shadows` enumerate what the active theme declares, so an app can assert its token set at launch or in CI instead of discovering a typo as a silently rendered fallback.

## Consequences

- ThemeKit gains a consumer extension seam and learns nothing about any consumer. The `Brand neutrality (i18n)` CI gate passes unchanged.
- A consumer token is a flat value: it has no `SemanticColor` role ladder (`.solid` / `.soft` / `.onSolid`), and no component takes one — components take `SemanticColor`, a closed enum. This is a **token-read API, not a component-theming API**. A custom color reaches a component only where that component accepts a raw `Color`.
- Custom colors bypass the WCAG contrast checking `docs/design-principles.md` describes for generated tokens. Deliberate: the host owns the value.
- `custom.` is now reserved in the JSON theme schema, which `docs/API-STABILITY.md` counts as public API. `tools/gen_tokens.py` must never emit a name under it.
- Promotion path: if a consumer token later becomes a real ThemeKit token, both exist and there is no aliasing mechanism — a JSON string cannot carry an `@available` deprecation. Policy: promotion is opt-in, the `custom.` token keeps working, the consumer migrates at their convenience. No alias map, because it would require the library to know a consumer's name.

## Testing strategy

- `CustomTokenTests` — round trip across all five kinds, built-ins unaffected, the read seal, custom metrics never entering the built-in stores, qualified-name round trip, the empty name, enumeration, and the Dynamic Type band.
- `CustomTokenRegistrationTests` — survival across all five entry points, registered-outranks-theme, theme tokens alongside registered ones, the dark variant, a token with no dark override, the `setColorScheme` regression, and clearing.
- `CSSThemeTests` — passthrough, dark-block inheritance, no disturbance to built-ins, unparseable vars ignored, and parity with `tools/import_css_theme.py`.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Add the consumer's tokens to `gen_tokens.py` / the generated enums | Makes a shared library brand-specific. The requirement that started this ADR. |
| Blanket `rawColor(_:)` / `rawSpacing(_:)` over the existing stores | Reverses the `spacing(token:)` rationale and exposes the `package`-level component tokens as a side effect. |
| `customTokens` on `ThemeConfig` | See D4 — theme-owned, bloats a scalar recipe, still lost on `ThemePreset.apply()`. |
| A consumer-supplied `RawRepresentable` enum conformance instead of `CustomToken` | Generic over `RawValue == String` works, but gives the library no place to normalize or assert, and no type to key enumeration on. |
| A typed sub-theme (a second `Theme` instance for consumer tokens) | Two theme objects to inject and keep in sync; breaks the single `\.theme` environment contract of ADR-0006. |
