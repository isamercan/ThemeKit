---
title: Theming
description: Built-in presets, generating a theme from one accent color, and per-subtree theming.
---

A `Theme` is a full set of design tokens — colors, type, spacing, radius, shadow.
Every ThemeKit component reads tokens from the active theme via
`@Environment(\.theme)`, so re-skinning is a single assignment.

## Theme presets

ThemeKit ships **33 ready-made presets**: its **Default** plus **32 color sets
inspired by [daisyUI](https://daisyui.com/docs/themes/)** (cupcake, dracula,
cyberpunk, synthwave, nord, coffee…). Each preset's accent recolors the whole
Ant-style palette while keeping its signature surface tone.

```swift
ThemePreset.named("dracula")?.apply()        // recolors Theme.shared on the fly

@State private var active: String? = "cupcake"
ThemePicker(selection: $active)              // a tappable grid of all 33 themes
```

<img class="tk-shot" src="/ThemeKit/showcase/ThemeShowcase.png" alt="The same ThemeKit components rendered under four presets — Cupcake, Synthwave, Cyberpunk and Nord" loading="lazy" />

## Generate a theme from one color

Don't have a design system? Generate a full palette on-device from a single
accent hex — ThemeKit derives the Ant-style scale for you.

```swift
let theme = Theme()
theme.applyGenerated(primaryHex: "#7C3AED")  // full palette from one accent
```

## Import a CSS theme (HeroUI, Tailwind, shadcn…)

Already have a web design system as CSS custom properties? Hand it to ThemeKit
**directly** — the `oklch()` / hex variables are parsed on-device at runtime and
the whole token set is generated for you. No JSON, no build step. ThemeKit even
ships a ready-made **HeroUI** theme.

Drop a `.css` in your app and apply it in one line:

```swift
Theme.shared.loadTheme(cssNamed: "heroui", font: "Inter")  // bundled HeroUI theme
Theme.shared.loadTheme(cssNamed: "brand")                  // your own brand.css in the app bundle
```

Or apply a CSS string — from a file, a network response, anywhere:

```swift
let css = try String(contentsOf: url)     // your theme.css
Theme.shared.setTheme(css: css)           // parsed + applied instantly, no restart
Theme.shared.setColorScheme(dark: true)   // switches to the CSS's .dark block
```

Both the `:root`/`.light` and `.dark` blocks are read: `--accent` drives the
primary/info palette, `--danger` / `--success` / `--warning` the semantic colors,
and `--background` / `--foreground` / `--border` / `--muted` the neutral surfaces
and text (`--radius` / `--field-radius` → the box/field radius roles). Anything the
CSS doesn't define falls back to ThemeKit's defaults, and the CSS is treated as
untrusted text — only `--var: value;` declarations are read, nothing is executed.

:::tip[Offline alternative]
Prefer to bundle a static JSON (zero runtime parse)? The same conversion runs
offline as a Python tool — `python3 tools/import_css_theme.py theme.css --name
brand --out Sources/ThemeKitCore/Resources`, then `loadTheme(named: "brandTheme")`.
:::

## Per-subtree theming

Theming isn't only a global switch. Inject any `Theme` into a single subtree with
`.theme(_:)`, and every component inside re-skins to it — no `Theme.shared`
mutation, no global state. The rest of the app keeps its theme.

```swift
let ocean = Theme(); ocean.loadTheme(named: "oceanTheme")
let grape = Theme(); grape.applyGenerated(primaryHex: "#7C3AED")

HStack {
    BookingCard(...)                 // app theme
    BookingCard(...).theme(ocean)    // ocean — this subtree only
    BookingCard(...).theme(grape)    // grape — this subtree only
}
```

Brand colors follow the injected theme while semantic colors (info, success…)
stay consistent. Because every component defaults to `Theme.shared`, this is
fully additive and backward-compatible.

<img class="tk-shot" src="/ThemeKit/showcase/ThemeInjection.png" alt="The same components rendered under four injected themes side by side" loading="lazy" />

:::note
For the deep dive on the token model and how a theme is built, see the
[DocC Theming article](/ThemeKit/api/documentation/themekit/theming/).
:::
