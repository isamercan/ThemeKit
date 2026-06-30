---
title: Getting Started
description: Apply a theme at the root, then build screens from token-bound ThemeKit components.
---

ThemeKit is a **brand-neutral SwiftUI design system**. Every color, type style,
spacing, radius, and shadow is a **design token** resolved at runtime from the
active `Theme`. Inject a theme once and the whole UI re-skins — without touching
component code.

## 1. Add the package

See [Installation](../installation/) for the SwiftPM details. In short:

```swift
.package(url: "https://github.com/isamercan/ThemeKit.git", from: "0.3.0"),
```

## 2. Inject the theme at the root

Call `.themeKit()` on your root view. This injects the active theme into the
environment and repaints when it changes.

```swift
@main
struct MyApp: App {
    init() { Theme.shared.applyPersistedConfig() }   // restore last theme (optional)
    var body: some Scene {
        WindowGroup {
            ContentView().themeKit()                 // inject + repaint on change
        }
    }
}
```

## 3. Build with token-bound views

Read the theme from the environment and compose components. Spacing, color,
radius and shadow all come from tokens — never hard-coded values.

```swift
struct ContentView: View {
    @ThemeContext private var theme
    var body: some View {
        VStack(spacing: theme.spacing(.md)) {
            Text("Welcome").textStyle(.headingBase)
            PrimaryButton("Get started") { await signIn() }
        }
        .padding(theme.spacing(.base))
        .background(theme.background(.bgElevatorPrimary))
        .cornerRadius(.base)
        .themeShadow(.elevated)
    }
}
```

## 4. Switch themes at runtime

```swift
Theme.shared.loadTheme(named: "oceanTheme")   // re-skins everything instantly
```

## Next steps

- [Theming](../theming/) — built-in presets and generating a theme from one accent color
- [Form Validation](../form-validation/) — the validation layer
- [Accessibility](../accessibility/) — Dynamic Type, VoiceOver, Reduce Motion
- [Component Gallery](../../components/) — browse all components
- [DocC API Reference](/ThemeKit/api/documentation/themekit/) — full symbol-level docs
