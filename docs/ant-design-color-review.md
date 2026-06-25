# Ant Design color system — review & mapping to GlobalUIComponents

Review of [Ant Design colors](https://ant.design/docs/spec/colors) vs the GlobalUIComponents
(Etstur) token system. Date: 23.06.2026.

## How Ant Design v5 colors work

Ant uses a **3-layer** token model:

1. **Seed token** — one base hex per color (e.g. `colorPrimary = #1677ff`).
2. **Map tokens (the 10-shade palette)** — each seed is algorithmically expanded into **10 steps**
   (HSV curve). Conventional roles per step:
   | step | role |
   |---|---|
   | 1 | container background |
   | 2 | background-hover |
   | 3 | border |
   | 4 | border-hover |
   | 5 | hover (lighter than base) |
   | **6** | **base** (the color itself) |
   | 7 | active / pressed (darker) |
   | 8–10 | text / darkest |
3. **Alias (semantic) tokens** — named roles components consume:
   `colorPrimary`, `colorPrimaryBg` (1), `colorPrimaryBgHover` (2), `colorPrimaryBorder` (3),
   `colorPrimaryBorderHover` (4), `colorPrimaryHover` (5), `colorPrimaryActive` (7),
   `colorPrimaryText*`… and the same `*Success / *Warning / *Error / *Info` families.
   Neutrals: `colorText` (#000 88%), `colorTextSecondary` (65%), `colorTextTertiary` (45%),
   `colorTextQuaternary` (25%), `colorBorder` #d9d9d9, `colorBorderSecondary` #f0f0f0,
   `colorFill*` (4 levels), `colorBgContainer` #fff, `colorBgLayout` #f5f5f5, `colorBgElevated`.

Base hexes: primary/info `#1677ff`, success `#52c41a`, warning `#faad14`, error `#ff4d4f`.
Neutrals use **alpha on black/white** so they adapt to any surface. Light & dark are two
algorithm outputs; contrast targets WCAG 2.

## How OURS already matches it

Our Etstur system is **the same 3-layer model**:

| Ant layer | Ours |
|---|---|
| Seed | `Base` colors (white/dark/red/turquoise/…) |
| Map (10 shades) | primitive ladders `primary 50–900`, `gray 50–900`, `Secondary Shades …/50–900`, `System Colors …/50–900` (10 steps each, in the Figma source) |
| Alias (semantic) | `foreground.* / background.* / border.* / text.*` tokens (128 tokens) |
| Interaction states | `bg-hero` / `bg-hero-hover` (#3789fd) / `bg-hero-pressing` (#0561e6) = Ant's primary base/hover/active |

`SemanticColor` (our daisyUI-style layer) exposes `solid / onSolid / soft / accent / border` per color
— the most-used Ant alias roles.

## Gaps vs Ant + what we did

| Ant capability | Status |
|---|---|
| Full **10-shade ladder** per color, exposed in code | **Done** — every semantic color now ships a `50…900` ladder, generated with Ant's exact `generate()` HSV algorithm (`tools/gen_tokens.py → ant_generate`). 100 `palette.*` tokens in each theme JSON, surfaced via `Theme.palette(_:)` and the generated `PaletteColorKey`. Step `500` == the base color. |
| Per-color **hover/active** states (not just primary) | **Done** — `SemanticColor` exposes Ant role accessors for **all 10 colors**: `bg(50) · bgHover(100) · borderSubtle(200) · borderHover(300) · hover(400) · base(500) · active(600) · strong(700)`. |
| Interaction states wired into components | **Done** — `GlobalButton` now uses a fill-aware `FillButtonStyle`: solid darkens to `active` on press, soft strengthens to `bgHover`, bordered/ghost wash in `bg`. The iOS analog of Ant's hover/active. (Preset buttons keep `PressFeedbackStyle`.) |
| Theme-aware accent ladder | **Done** — the `primary` ladder is regenerated from each theme's accent (Ocean→teal, Sunset→orange), so the new roles stay theme-reactive. |
| `colorFill` 4-level neutral fills | Not adopted (we use elevator/secondary surfaces instead). |
| Alpha-based neutrals | We use solid hexes (fine for our single-surface app; Ant's alpha adapts across surfaces). |

## Usage

```swift
// Raw ladder step
SemanticColor.primary.shade(.s700)

// Ant-style roles (work for every color: success / warning / error / …)
SemanticColor.success.bg          // step 50  — faint container
SemanticColor.success.base        // step 500 — the color
SemanticColor.success.active      // step 600 — pressed/active
```

The **Color Palette** page in the demo gallery (Atoms) renders the full ladder + roles live,
and re-tints with the theme switcher.
