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

Already have a web design system as CSS custom properties? ThemeKit ships a
ready-made **HeroUI** theme, and can convert any HeroUI-style CSS token file
(`oklch()` / hex variables) into a native ThemeKit theme.

Use the bundled HeroUI theme in one line:

```swift
Theme.shared.loadTheme(named: "herouiTheme")              // light
Theme.shared.loadTheme(named: "herouiTheme", dark: true)  // dark
```

To bring **your own** CSS, convert it once with the importer — it produces a
light + dark JSON pair you can load like any bundled theme:

```bash
# theme.css → brandTheme.json + brandThemeDark.json
python3 tools/import_css_theme.py theme.css --name brand \
    --out Sources/ThemeKitCore/Resources --font Inter
```

```swift
Theme.shared.loadTheme(named: "brandTheme")
```

The importer maps `--accent` onto the primary/info palette, `--danger` /
`--success` / `--warning` onto the semantic colors, and your `--background` /
`--foreground` / `--border` / `--muted` onto the neutral surfaces and text.
Anything the CSS doesn't define falls back to ThemeKit's defaults.

A host app can also apply a generated theme JSON **at runtime**, with no library
rebuild — the same entry point the localization override uses:

```swift
let data = try Data(contentsOf: url)    // your generated theme JSON
Theme.shared.setTheme(jsonData: data)   // applies instantly, no restart
```

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
