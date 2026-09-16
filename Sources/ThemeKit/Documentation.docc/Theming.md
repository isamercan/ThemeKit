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

### Your own tokens

A design system almost always carries tokens ThemeKit has no key for — a campaign
badge fill, a bespoke card corner. They live under the reserved `custom.`
namespace and read back through ``Theme/custom``.

Tokens the **app** owns are registered once and survive every theme change:

```swift
extension Theme.CustomToken { static let fareBadge: Self = "fare-badge" }

Theme.shared.registerCustomTokens(.init(
    colors:     [.fareBadge: Color(hex: "ff5722")],
    darkColors: [.fareBadge: Color(hex: "c63f14")]
))

theme.custom.color(.fareBadge) ?? theme.background(.bgHero)
```

Tokens the **theme** owns are declared in the theme file and change with it —
in JSON:

```json
{ "name": "custom.fare-badge", "hex": "ff5722" }
```

or in CSS, as `--custom-color-*`, `--custom-radius-*`, `--custom-spacing-*`:

```css
:root { --custom-color-fare-badge: #ff5722; --custom-radius-card-hero: 1.25rem; }
.dark { --custom-color-fare-badge: #c63f14; }
```

Where both name the same token the registered value wins — the app is the owner.
An undefined token returns `nil`, so the caller picks its own fallback;
``Theme/CustomTokens`` also enumerates what the active theme declares, so an app
can assert its token set at launch instead of rendering a fallback for a typo.

This is a token-read API, not a component-theming API: components take
``SemanticColor``, so a custom token doesn't reach a component through a
modifier. See ADR-0008.

### Your own component paint

To paint a component with your own tokens, text styles or icon font, set a
chrome style. The component keeps its behaviour, content, slots and
accessibility; the style draws the chrome and resolves its colors from the
environment theme, so `theme.custom` and per-subtree `.theme(_:)` both reach it:

```swift
struct FareBadgeChrome: BadgeChromeStyle {
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        FareBadgeChromeBody(configuration: configuration)
    }
}

private struct FareBadgeChromeBody: View {
    let configuration: BadgeChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            configuration.leading
            Text(configuration.text).textStyle(.labelSm600)
        }
        .foregroundStyle(theme.resolve(configuration.tone.semantic).onSolid)
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .background(theme.custom.color(.fareBadge) ?? theme.resolve(configuration.tone.semantic).solid,
                    in: Capsule())
    }
}

RootView().badgeChromeStyle(FareBadgeChrome())   // every Badge below, ThemeKit's own included
```

With no style set, every component draws its built-in look unchanged. The
protocols: ``ButtonChromeStyle``, ``BadgeChromeStyle``, ``CountBadgeStyle``,
``IconTileStyle``, ``PriceTagStyle``, ``RadioButtonChromeStyle``,
``SkeletonStyle``, ``DividerStyle``, ``CalloutChromeStyle``,
``InlineTextStyle`` and ``ChipStyle``. To use your own type ramp, register a
`Theme.ResolvedTextStyle` under `custom.` and apply it in the style with
`.font(_:)` and `.lineSpacing(_:)`. See ADR-0009.

## Topics

### Core

- `Theme`
- `ThemeConfig`
- `ThemeContext`

### Token namespaces

- `Theme.CustomToken`
- `Theme.CustomTokens`
- `Theme.CustomTokenSet`
- `TextStyle`
- `SemanticColor`
- `Theme.SpacingKey`
- `Theme.RadiusKey`
- `ShadowStyle`
