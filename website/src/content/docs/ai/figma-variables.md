---
title: Design Tokens ⇄ Figma Variables
description: Export ThemeKit's design tokens into a themeable Figma Variables library, and import a company's Figma Variables back into a live ThemeConfig — a lossless, two-way bridge for one source of truth.
---

Your design tokens live in code (`data/themekit.json` — colors, radius, spacing,
typography, plus the bundled theme presets). Your designers live in Figma. This
page is the **two-way bridge** between them, so both sides share one vocabulary:

- **`export_figma_variables`** — code → Figma. Turn the token catalog into a
  **Figma Variables** library your designers theme with.
- **`import_figma_variables`** — Figma → code. Turn a company's Figma Variables
  file into a **`ThemeConfig`** that re-skins every ThemeKit component.

Together they form a **round-trip**: a file ThemeKit exported can be imported back
with zero loss, and any brand's file can be adapted with a little mapping.

:::tip[Why this matters]
ThemeKit theming is **seed-driven** — a `ThemeConfig` needs only a few brand
colors (primary / secondary / accent / base) and derives the entire palette. So a
whole app can be re-branded from a handful of values. These tools move those
values between design and code without anyone re-typing hexes.
:::

## A 60-second primer on Figma Variables

Figma **Variables** are typed design tokens (colors, numbers, strings) grouped
into **collections**. A collection can have multiple **modes** — the classic use
is `Light` / `Dark`, but a mode is really just "a column of values." Switch the
mode and every variable resolves to that column.

ThemeKit maps onto this exactly:

| ThemeKit | Figma Variables |
|---|---|
| A color/spacing/radius token | a Variable |
| A token category (`background.*`, `spacing`) | a Collection |
| The 32 theme presets | **modes** of one `Brand` collection |
| The token's name (`background.bg-white`) | the Variable's `codeSyntax` |

That "presets as modes" idea is the key trick — see below.

---

## Export: code → Figma

```text
Use themekit · export_figma_variables
```

It reads the token catalog and returns a **Figma Variables library** in five
collections (277 variables total):

| Collection | What's in it | Type | Modes |
|---|---|---|---|
| **Brand** | `primary` · `secondary` · `accent` · `base` | color | **one per preset** (`Default`, `Dark`, `Dracula`, …) |
| **Color** | every resolved token — `foreground/*`, `background/*`, `text/*`, `palette/primary/50` … | color | `Default` |
| **Radius** | the size scale + the `box` / `field` / `selector` roles | number | `Default` |
| **Spacing** | the spacing scale | number | `Default` |
| **Typography** | `size` · `lineHeight` · `weight` per text style | number / string | `Default` |

### The killer feature: presets become modes

The **Brand** collection carries one Figma **mode per theme preset**. A designer
picks the `Dracula` mode and the four brand seeds switch — exactly like
`ThemePreset.named("dracula").apply()` does in the app. One file, every brand.

### Two output formats

- **`model`** (default) — a clean, tool-agnostic JSON you can feed to a Figma
  plugin or inspect by hand.
- **`format: "figma-rest"`** — the exact body for Figma's bulk-write endpoint.

```text
Use themekit · export_figma_variables with format: "figma-rest", collections: ["Brand","Color"]
```

Then POST it to Figma:

```sh
curl -X POST \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  -H "Content-Type: application/json" \
  --data @variables.json \
  "https://api.figma.com/v1/files/<FILE_KEY>/variables"
```

Filter with `collections: [...]` to export just what you need.

### codeSyntax keeps design bound to code

Every exported variable stores its **originating ThemeKit token** in
`codeSyntax` (the iOS platform slot). That's what makes the round-trip lossless
(the importer reads it back exactly) and lets Figma Dev Mode show the ThemeKit
token beside each value.

:::note[What isn't exported as a variable]
Shadows map to Figma **effect styles**, not variables, and `semanticColor` is
resolved through the palette ladder at runtime — so both are intentionally
skipped, and the tool reports it. Everything else round-trips.
:::

---

## Import: Figma → code

```text
Use themekit · import_figma_variables with variablesJson: "<...>", mode: "Dark"
```

It resolves the brand seeds for the chosen mode and emits a **`ThemeConfig`** plus
a `theme.json`:

```swift
// imported from Figma — mode "Dark" (lossless via codeSyntax)
Theme.shared.apply(ThemeConfig(primaryHex: "605dff", secondaryHex: "f43098",
                               accentHex: "00d3bb", baseHex: "1d232a", dark: true))
```

```json
{ "primaryHex": "605dff", "secondaryHex": "f43098", "accentHex": "00d3bb", "baseHex": "1d232a", "dark": true }
```

### What to feed it

Either shape works:

1. **A real Figma file** — pull its variables with
   `GET /v1/files/:key/variables/local` and hand in that JSON.
2. **A ThemeKit export** — the `model` from `export_figma_variables` (the
   lossless path).

### How a seed is resolved (trusted → last resort)

| # | Source | When it wins | Lossless? |
|---|---|---|---|
| 1 | **`codeSyntax`** | the variable names a `brand.<role>` token | ✅ yes |
| 2 | **`aliases`** | you map the variable name to a role | — |
| 3 | **name heuristic** | the name looks like `primary`/`base`/`surface`… | — |

`codeSyntax` **beats** a conflicting name. Anything unresolved is **reported**,
never guessed — you'll see exactly which seed is missing and can supply an alias.

### Foreign files: a small alias map

A company that named things their own way just needs a hint:

```text
Use themekit · import_figma_variables with
variablesJson: "<...>",
aliases: { "Brand/500": "primary", "Surface/Canvas": "base" }
```

### Details that just work

- **`VARIABLE_ALIAS`** — if a brand variable *points at* a primitive
  (`Brand/primary → blue/500`), the importer dereferences it across collections
  and modes to the real color.
- **Mode picking** — multi-mode files: pass `mode` (`Light` / `Dark` / a preset
  name). Omit it and the collection's default mode is used.
- **Dark inference** — `dark: true` is inferred from the mode name (contains
  "dark") or the base color's luminance, or you can force it.

---

## The round-trip

```text
tokens ──export_figma_variables──▶ Figma Variables (designers theme here)
  ▲                                          │
  └──────import_figma_variables◀─────────────┘
```

Because every exported variable carries its token in `codeSyntax`, a file that
went **out** of ThemeKit comes **back** with identical seeds — a true lossless
loop. A file that started life in someone else's Figma comes back with a one-time
alias map, and from then on it's lossless too.

## What you can build with it

- **Multi-brand / white-label** — a partner hands you their Figma Variables file;
  `import_figma_variables` turns it into a `ThemeConfig` and every ThemeKit
  component re-skins to their brand. No code changes.
- **Design ↔ code stay in sync** — ship the exported library to your design team
  so mockups use the exact tokens the app renders; pull their edits back with the
  importer.
- **Theme authoring in Figma** — designers explore brands as **modes**, then
  export the winning mode straight into a live `ThemeConfig`.

## See also

- [Map Your Figma Kit](../figma-kit/) — the other half: mapping your kit's
  *component* names (not just tokens) to ThemeKit.
- [MCP Server](../mcp/) — the full tool list and install.
