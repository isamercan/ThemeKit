# Getting Started

Apply the theme once, then build screens from the token-bound component library.

## Overview

`ThemeKit` works in two moves: install the theme at the root of your
app, then compose components that read their colors, spacing, radii, and type
from that theme. Nothing is hard-coded — change the theme and every screen
re-skins.

### 1. Install the theme

Apply `themeKit(reactToRuntimeChanges:)` once, at the top of your scene. It
loads the default theme, bundles the type ramp, and makes the active `Theme`
available to every component below it.

```swift
import SwiftUI
import ThemeKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .themeKit()
        }
    }
}
```

> Note: Without `.themeKit()` at the root, components still render but fall
> back to system defaults instead of the design-system palette and fonts.

### 2. Compose a screen

Use the type ramp via `.textStyle(_:)` and drop in components. They size,
color, and space themselves from the active theme.

```swift
struct SignInView: View {
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in").textStyle(.headingLg)

            TextInput("Email", text: $email)
                .placeholder("you@example.com")
                .icon(leading: "envelope")

            Badge("Beta").badgeStyle(.info)

            PrimaryButton("Continue") {
                // handle sign-in
            }
            .fullWidth()
        }
        .padding()
    }
}
```

### 3. Switch light / dark or re-skin at runtime

The active `Theme` is a singleton you can drive imperatively — flip the color
scheme, or generate a whole palette from one accent color with `ThemeConfig`.

```swift
Theme.shared.setColorScheme(dark: true)                 // light ⇄ dark
Theme.shared.apply(ThemeConfig(primaryHex: "#7C3AED"))  // re-skin from an accent
```

> Tip: Build your component-level previews inside `Group { ... }.themeKit()`
> so they render with the real design-system palette and fonts in the Xcode
> canvas.

## Next steps

- <doc:Theming> — tokens, runtime theme generation, and persistence.
- <doc:FormValidation> — the validation logic + presentation layers.
- <doc:Accessibility> — Dynamic Type, VoiceOver, and Reduce Motion support.

## Topics

### Essentials

- `Theme`
- `TextStyle`
- ``ThemeButton``
- ``TextInput``
