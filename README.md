# GlobalUIComponents

A theme-driven SwiftUI component library whose colors, typography, spacing,
radii and shadows are **design tokens** sourced from the Figma design system and
loaded from JSON at runtime — so components render under any theme without code
changes.

> Per **ADR-0001**, components never hardcode colors — every color resolves from
> the active `Theme`.

```swift
import GlobalUIComponents
```

## Token system

```
Sources/GlobalUIComponents/
├─ Theme/
│  ├─ Theme.swift                    # ObservableObject singleton (Theme.shared)
│  ├─ ThemeModel.swift               # RadiusKey / SpacingKey
│  ├─ ColorTokens.generated.swift    # Foreground/Background/Border/Text color keys (generated)
│  ├─ Typography.swift               # TextStyle ramp (Montserrat)
│  ├─ Shadows.swift                  # ShadowStyle + .themeShadow()
│  ├─ ThemeContext.swift             # @ThemeContext property wrapper
│  └─ ThemedHostingController.swift  # UIKit bridge
├─ Extensions/Color+Extensions.swift # Color(hex:) — supports RRGGBB + RRGGBBAA
│  ├─ AspectRatio.swift             # AspectRatioToken + .aspectRatioToken()
│  ├─ Motion.swift                  # Motion durations / animations
│  └─ Grid.swift                    # GridLayout column helpers
├─ Views/
│  ├─ CornerRadiusModifier.swift     # .cornerRadius(.rdBase)
│  ├─ DividerView.swift
│  ├─ Icon.swift                     # Icon + IconSize (SF Symbols; FA Pro drop-in)
│  ├─ Badge.swift                    # Badge (semantic + brand styles)
│  ├─ Chip.swift                     # Chip (tonal / solid selection)
│  ├─ Accordion.swift                # Accordion (expandable)
│  ├─ InfoBanner.swift               # light-surface status banner
│  ├─ AlertToast.swift               # solid-fill status banner
│  ├─ Buttons/                       # PrimaryButton / SecondaryButton / OutlineButton
│  └─ Controls/                      # Checkbox / RadioButton / ThemeToggle / TextInput / Select
└─ Resources/
   ├─ *.json                         # defaultTheme / oceanTheme / sunsetTheme
   └─ Fonts/Montserrat.ttf           # bundled, registered at runtime
```

### Token groups

| Group | Source of truth | Keys |
|---|---|---|
| Colors | `Resources/*.json` | `Theme.ForegroundColorKey` · `BackgroundColorKey` · `BorderColorKey` · `TextColorKey` (128 semantic tokens) |
| Radius | `Resources/*.json` | `Theme.RadiusKey` (`rd-xs`…`rd-4xl`) |
| Spacing | `Resources/*.json` | `Theme.SpacingKey` (`sp-xs`…`sp-4xl`) |
| Typography | code (`Typography.swift`) | `TextStyle` — Display / Heading / Label / Body / Overline / Link |
| Shadows | code (`Shadows.swift`) | `ShadowStyle` — elevated / tabBar / soft |

Colors / radius / spacing vary per theme (JSON). Typography & shadows are
structural and constant across themes.

### Usage

```swift
// Inject once
WindowGroup { ContentView().environmentObject(Theme.shared) }

struct Example: View {
    @ThemeContext private var theme
    var body: some View {
        Text("Hi")
            .textStyle(.headingBase)
            .foregroundStyle(theme.text(.textPrimary))
            .padding(theme.spacing(.md))
            .background(theme.background(.bgElevatorPrimary))
            .cornerRadius(.base)
            .themeShadow(.elevated)
    }
}

Theme.shared.loadTheme(named: "oceanTheme")   // runtime switch
```

## Adding / updating tokens

Colors are generated to keep JSON ↔ Swift in sync. Edit the single source and
re-run the generator (the token maps live in the generator script):

1. Update the token maps in `tools/gen_tokens.py`.
2. Re-run: `python3 tools/gen_tokens.py .` (regenerates `Resources/*.json` +
   `ColorTokens.generated.swift`).

Radius / spacing live in `Resources/*.json` + the `RadiusKey` / `SpacingKey`
enums. Typography / shadows are in `Typography.swift` / `Shadows.swift`.

## Themes

`default` (blue) · `ocean` (turquoise accent) · `sunset` (orange accent).
Token **names** are semantic (`fg-hero`, `bg-primary`, `rd-sm`); only the values
differ per theme. Add a theme by dropping a `<name>Theme.json` into `Resources/`.

## Theming your app (Configurator export)

The library ships a **runtime token generator** (`ThemeGenerator`, a Swift port
of `tools/gen_tokens.py`): from a handful of inputs it regenerates the whole
Ant-style palette, neutral ramp, surfaces, borders, text, radius/spacing/font/
shadow ramps — on device, no Python and no baked palette files.

The Demo's **Theme Configurator** (Colors tab) lets you dial in an accent color +
tint + scale knobs + font + dark and exports a `ThemeConfig` recipe. To use it in
your own app:

**1. Install the root modifier — once.** It injects the theme and repaints the UI
on a theme swap (see "How live theming works" below):

```swift
@main struct MyApp: App {
    init() { Theme.shared.applyPersistedConfig() }     // restore last-used theme (if any)
    var body: some Scene {
        WindowGroup { ContentView().globalUITheme() }
    }
}
```

**2. Apply a theme** — pick the level of portability you want:

```swift
// a) one-liner (paste the configurator's "Apply (Swift)" export)
Theme.shared.applyGenerated(primaryHex: "ff0d87", tint: 0.13, radiusScale: 1.0, font: "Montserrat")

// b) ship the Codable recipe as a resource (the configurator's `theme.json`)
let cfg = try ThemeConfig(jsonData: Data(contentsOf: themeJSONURL))
Theme.shared.apply(cfg)
Theme.shared.persistConfig()                            // remember across launches

// c) fully Python-free + generator-free: bundle the pre-baked token JSON
//    (configurator → "Copy full token JSON") and load it directly
Theme.shared.setTheme(jsonData: Data(contentsOf: tokensURL))
```

`ThemeConfig` is `Codable` / `Sendable` / `Equatable` — persist it, sync it, A/B it.

### How live theming works

Components resolve tokens from the `Theme.shared` singleton (no per-call
environment lookups), so SwiftUI can't infer that an arbitrary view depends on
the theme. `.globalUITheme()` closes that gap: it injects `Theme` into the
environment **and** (by default) rebuilds the subtree keyed on `Theme.revision`
when the theme changes, so every view re-reads the regenerated tokens.

- Switching theme from a **settings screen** → keep the default
  (`reactToRuntimeChanges: true`), the whole UI repaints.
- Editing the theme **in-session** (a sheet/inspector that mutates it live) → use
  `.globalUITheme(reactToRuntimeChanges: false)` so the editor isn't torn down,
  and scope a `.id(Theme.shared.revision)` onto just the live-preview subtree.

### Fonts

`Montserrat` is bundled. `System` / `SystemRounded` / `SystemSerif` / `SystemMono`
need nothing. Any other family must be registered by the host app (add the
`.ttf` + `UIAppFonts`), then pass its PostScript family name as `font:`.

## Localization

User-facing default strings (validation messages, placeholders, accessibility
labels, etc.) come from a bundled **String Catalog**
(`Resources/Localizable.xcstrings`). The source language is **English**; a
**Turkish** translation ships too, and consumers can add their own.

Every such string also stays **overridable** via API parameters — e.g.
`ValidationRule.required("Custom message")` — so the catalog only supplies the
default. The bridge `String(globalUIComponents:)` resolves a key from the
package bundle if you need it directly.

> Note: a plain `swift build` copies `.xcstrings` verbatim (CLI doesn't run the
> catalog compiler), so only English resolves there. Xcode / `xcodebuild`
> compile it, so all bundled localizations resolve in real apps.

## Documentation

A DocC catalog ships with the package (`Sources/GlobalUIComponents/Documentation.docc`).
Build it in Xcode via **Product ▸ Build Documentation** (⌃⌘D), or from the
command line:

```sh
xcodebuild docbuild -scheme GlobalUIComponents -destination 'generic/platform=iOS'
```

It curates every component by category and includes guide articles for
**Theming**, **Accessibility** (Dynamic Type + Reduce Motion), and
**Validation**. No extra dependency is required — the catalog builds natively.

## Demo

`Demo/` — a SwiftUI app (local package reference) with three tabs: **Colors**
(token gallery), **Typography**, **Components**, plus a runtime theme switcher.
