---
title: DESIGN.md — Design Mode
description: Write your design intent in plain Markdown and ThemeKit re-skins every component to match.
---

**Design Mode** lets you describe your product's look in plain words — a
`DESIGN.md` — and ThemeKit turns it into a live theme. Point an agent (with the
[ThemeKit MCP](../mcp/)) at the file and **every** component re-skins to match: one
written brief, a fully tokenized UI.

It's the same idea as a design-system doc an AI reads — except the output is a
real, validated `ThemeConfig`, not a guess.

## How it works

1. **You write `DESIGN.md`** — a free-form brief: brand colors, personality,
   typography, shape, spacing, light/dark.
2. **The agent reads it** and infers each value, then calls the MCP tool
   `design_md_to_themeconfig`.
3. **The tool validates & normalizes** — clamps the tint, lowercases hex,
   whitelists the font — and emits a ready-to-paste `ThemeConfig` snippet **and** a
   matching `theme.json`.
4. **You apply it** — `Theme.shared.apply(ThemeConfig(...))` and the whole UI
   re-skins.

## The knobs

`DESIGN.md` is free-form prose; the agent maps it onto these `ThemeConfig` fields:

| Field | From your brief | Range |
|---|---|---|
| `primaryHex` | Brand / primary color | 6-digit `RRGGBB` (required) |
| `baseHex` | Surface / background tone | `RRGGBB` |
| `secondaryHex` / `accentHex` | Secondary & highlight colors | `RRGGBB` |
| `tint` | How strongly the accent bleeds into neutrals | `0`–`0.25` |
| `dark` | Light vs dark base | `true` / `false` |
| `font` | Typeface personality | `Montserrat` · `System` · `SystemRounded` · `SystemSerif` · `SystemMono` |
| `fontScale` | Overall text size | `≈1.0` |
| `radiusScale` | Corner roundness | `≈1.0` — `<1` sharper, `>1` rounder |
| `spacingScale` | Density | `≈1.0` — `<1` compact, `>1` airy |
| `shadowScale` | Elevation | `0` flat … `>1` elevated |

## Example `DESIGN.md`

```markdown
# DESIGN.md — Northwind Travel

## Brand
- Primary: deep ocean blue `#0B5FFF`
- Accent: warm coral `#FF6B5E` for highlights and primary CTAs
- Surfaces: near-white, calm and airy

## Personality
Trustworthy, modern, friendly — not playful, not corporate-stiff.

## Typography
Rounded sans: friendly but legible. Slightly larger body text for readability.

## Shape & spacing
- Soft, rounded corners on cards and buttons
- Generous, airy spacing — lots of breathing room
- Subtle shadows; nothing heavy

## Mode
Light by default.
```

## What the agent generates

The agent reads the brief above and calls `design_md_to_themeconfig`, which returns:

```swift
// ocean-blue primary + coral accent, rounded friendly font, airy & soft, light
Theme.shared.apply(ThemeConfig(
    primaryHex: "0b5fff",
    accentHex: "ff6b5e",
    font: .systemRounded,
    fontScale: 1.05,
    radiusScale: 1.2,
    spacingScale: 1.15,
    shadowScale: 0.6
))
```

…plus a matching `theme.json` you can ship and apply with `ThemeConfig(jsonData:)`:

```json
{
  "primaryHex": "0b5fff",
  "accentHex": "ff6b5e",
  "font": "SystemRounded",
  "fontScale": 1.05,
  "radiusScale": 1.2,
  "spacingScale": 1.15,
  "shadowScale": 0.6
}
```

```swift
// Ship theme.json in your bundle and load it at runtime:
Theme.shared.apply(ThemeConfig(jsonData: themeJSONData))
```

Every ThemeKit component reads its colors, type, radius, spacing, and shadow from
that config — so the single brief re-skins the entire UI, with no per-component
work. See [Theming](../../guides/theming/) for the runtime model.

## Bundled styles

No brief yet? Start from a bundled style and tweak — **Linear**, **Notion**,
**iOS**, **Brutalist**, or **Pastel** — each re-skins every component via the same
offline heuristic parser (with an optional LLM path for richer briefs).

:::tip
Keep `DESIGN.md` at your repo root next to `llms.txt`. It doubles as living
design documentation **and** the source your agent re-themes from — change the
brief, regenerate, and the whole app follows.
:::
