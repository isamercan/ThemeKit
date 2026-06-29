---
name: themekit
description: >-
  Use when writing SwiftUI UI with the ThemeKit design system — its tokenized
  components (Badge, Card, TextInput, Select, Carousel…), runtime theming,
  theme presets, and chainable modifiers. Trigger on "ThemeKit", design tokens,
  theme switching, or a request to build a screen with ThemeKit.
license: MIT
---

# ThemeKit

A token-driven, brand-neutral **SwiftUI** component library. Every color,
radius, spacing, type style and shadow is a **design token** resolved at runtime
from the active `Theme`. Write UI with its components + modifiers; the theme
re-skins everything.

For the full component list + each one's init params + modifiers, read
[`references/components.md`](references/components.md). For the theme-preset
catalog, read [`references/themes.md`](references/themes.md).

## Golden rules

1. **Never hardcode a color.** No `.foregroundStyle(.blue)`, no `Color(hex:)` in
   app code. Pull from the theme: `theme.text(.textPrimary)`,
   `theme.background(.bgWhite)`, or a `SemanticColor` (`SemanticColor.primary.base`).
2. **Read the theme from the environment:** `@Environment(\.theme) private var theme`.
   It defaults to `Theme.shared`.
3. **Inject it once at the root:** `.environment(Theme.shared)`.
4. **Set styling with chainable modifiers, not extra init args.** Required
   content/bindings/actions go in `init`; variants, sizes, flags, colors and
   callbacks are modifiers — e.g. `Badge("New", style: .info).badgeShape(.rounded)`.
5. **Sizes use the native modifier:** `.controlSize(.small)` (not a `size:` arg).
   **Disabled state is native:** `.disabled(_:)` (not an `isEnabled:` arg).

## Setup

```swift
import ThemeKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environment(Theme.shared)   // inject the theme once
        }
    }
}

struct ContentView: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            Text("Hello").foregroundStyle(theme.text(.textPrimary))
            PrimaryButton("Continue", block: true) { /* … */ }
        }
        .padding(Theme.SpacingKey.lg.value)
        .background(theme.background(.bgElevatorPrimary))
    }
}
```

## Tokens

- **Text:** `theme.text(.textPrimary | .textSecondary | .textTertiary | .textDisabled | .textHero)`
- **Surfaces:** `theme.background(.bgWhite | .bgElevatorPrimary | .bgSecondary | .bgHero | …)`
- **Borders:** `theme.border(.borderPrimary | .borderHero | …)`
- **Foreground:** `theme.foreground(.fgHero | .fgSecondary | …)`
- **Semantic colors** (`SemanticColor`): `.primary .secondary .accent .neutral .info
  .success .warning .error` + hues. Each gives `.solid .soft .accent .border`
  variants and a 50..900 ladder (`.base .hover .active .strong .bg …`). Use with
  `FillVariant` (`.solid .soft .outline .ghost`) on the configurable components.
- **Radius — by role** (re-rounds a whole category from one token):
  `Theme.RadiusRole.box.value` (cards/modals), `.field.value` (buttons/inputs),
  `.selector.value` (checkboxes/badges). Size ramp also exists:
  `Theme.RadiusKey.sm.value` etc.
- **Spacing:** `Theme.SpacingKey.xs|sm|md|base|lg|xl.value`
- **Type:** `.textStyle(.headingSm | .bodyBase400 | .labelMd600 | …)` (a view modifier).

## Components

Browse [`references/components.md`](references/components.md) for all of them.
The configurable ones take a `SemanticColor` + `FillVariant`, so brand/accent
recolor for free:

```swift
Badge("Sale", style: .error, variant: .solid)
Chip("Pool", isSelected: $on).icon("drop.fill")
ThemeButton("Save", color: .accent, variant: .solid) { save() }
TextInput("Email", text: $email, leadingSystemImage: "envelope")
    .a11yID("login.email")
Select("Country", options: countries, selection: $country) { $0.name }
Checkbox("I agree", isChecked: $agree).controlSize(.small)
Card(title: "Booking") { /* content */ }
Rating(value: 4.5).allowHalf().onRate { rating = $0 }
ProgressBar(value: 0.6, showPercentage: true).gradient()
```

## Theming

```swift
// Recolor the whole app from one accent (generates the full palette on-device):
Theme.shared.applyGenerated(primaryHex: "7C3AED")

// Or a full config (accent + base surface + secondary/accent brand colors):
Theme.shared.apply(ThemeConfig(primaryHex: "ff79c6", baseHex: "282a36",
                               secondaryHex: "bd93f9", accentHex: "ffb86c", dark: true))

// Inject a theme into ONE subtree only:
let ocean = Theme(); ocean.applyGenerated(primaryHex: "0fb4ab")
BookingCard().theme(ocean)
```

### Theme presets

ThemeKit bundles 32 theme presets (inspired by daisyUI). Apply one, or drop the `ThemePicker`
grid into a screen:

```swift
ThemePreset.named("dracula")?.apply()        // recolor Theme.shared live

@State private var active: String? = "cupcake"
ThemePicker(selection: $active)             // tappable grid of all 32 themes
```

## Patterns

**Themed form**
```swift
@Environment(\.theme) private var theme
Card(title: "Sign up") {
    VStack(spacing: Theme.SpacingKey.md.value) {
        TextInput("Email", text: $email, leadingSystemImage: "envelope").a11yID("email")
        TextInput("Password", text: $pw, isSecure: true).a11yID("pw")
        Checkbox("Accept terms", isChecked: $terms)
        PrimaryButton("Create account", block: true) { submit() }.disabled(!terms)
    }
}
```

**Theme switcher screen** — see `ThemePicker` + the theme-presets section above.

## Anti-patterns (don't)

- ❌ `.foregroundStyle(.blue)` / `Color(hex:)` in app UI → ✅ a theme token.
- ❌ `Badge("x", size: .small)` → ✅ `Badge("x").controlSize(.small)` (or the
  component's own size init where it has one — check `references/components.md`).
- ❌ `SomeControl(isEnabled: false)` → ✅ `SomeControl().disabled(true)`.
- ❌ Re-implementing a Card/Sheet/Toast → ✅ use the existing component.
- ❌ Hardcoded corner radius `cornerRadius: 12` → ✅ `Theme.RadiusRole.box.value`.
