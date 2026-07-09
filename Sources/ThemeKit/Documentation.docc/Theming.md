# Theming

Drive the entire UI from a single accent color, then persist or export the recipe.

> Note: The theme engine and design tokens (`Theme`, `SemanticColor`, `TextStyle`, …)
> live in the standalone **ThemeKitCore** module — adopt it alone with
> `import ThemeKitCore` for a token-only theme layer, no components. Its full API is
> in the [ThemeKitCore reference](/ThemeKit/api-core/documentation/themekitcore/).
> `import ThemeKit` re-exports all of it, so the examples below work unchanged.

## Overview

Every component reads its colors, radii, spacing, type, and shadows from the
active `Theme`. There are two ways to set one.

### Built-in themes

Load a bundled theme by name (light or dark):

```swift
Theme.shared.loadTheme(named: "defaultTheme")
Theme.shared.loadTheme(named: "defaultTheme", dark: true)
```

### Generated themes (recipe → full palette)

A `ThemeConfig` is a small, `Codable` recipe. Applying it regenerates a
complete Ant-style 50–900 palette from your accent color at runtime — primary,
info, the neutral ramp, surfaces, borders, and text all re-tint toward the hue,
while success / warning / error keep their meaning.

```swift
let config = ThemeConfig(
    primaryHex: "7C3AED",   // any accent
    tint: 0.08,             // how strongly neutrals lean toward the hue
    dark: false,
    fontScale: 1.0,
    radiusScale: 1.0,
    spacingScale: 1.0,
    shadowScale: 1.0
)
Theme.shared.apply(config)
```

### Persist and restore

```swift
Theme.shared.persistConfig()          // -> UserDefaults
Theme.shared.applyPersistedConfig()   // on next launch
```

### Export for another project

A configurator can hand a developer three artifacts: the `ThemeConfig` JSON
(`config.jsonData()`), a Swift `apply(_:)` snippet, and the fully-resolved token
JSON (`Theme.shared.generatedTokenJSON(for:)`) that can be dropped into any
project and loaded with `Theme.shared.setTheme(jsonData:)`.

### Reacting to live changes

Apply `.themeKit()` once at the root. It injects the theme into the
environment and (by default) rebuilds the tree on theme changes so even leaf
views that read tokens statically re-render. Pass
`reactToRuntimeChanges: false` if you manage refresh yourself (e.g. to keep an
open sheet alive while previewing a theme).

```swift
WindowGroup { RootView().themeKit() }
```

## Topics

### Core

- `Theme`
- `ThemeConfig`
- `ThemeContext`

### Token namespaces

- `TextStyle`
- `SemanticColor`
- `Theme.SpacingKey`
- `Theme.RadiusKey`
- `ShadowStyle`
