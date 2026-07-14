# ThemeKit

> A token-driven, zero-dependency SwiftUI design system.

A themable palette, 117 token-bound SwiftUI components, a validation layer, and
accessibility (Dynamic Type, VoiceOver, RTL) — all with no third-party
dependencies in the core.

📖 **Full DocC documentation** is published at
**[isamercan.github.io/ThemeKit](https://isamercan.github.io/ThemeKit/api/documentation/themekit)**,
or build it locally:

```bash
swift package --disable-sandbox preview-documentation --target ThemeKit
```

## Quick install

```swift
.package(url: "https://github.com/isamercan/ThemeKit", .upToNextMinor(from: "0.1.0"))
```

Apply the theme once at your app root, then compose components:

```swift
ContentView().themeKit()
```

## Where to go next

- **[[Installation]]** — add the package to your project.
- **[[Custom Themes|Custom-Themes]]** — import a HeroUI / CSS design system.
- **[[FAQ]]** — common questions.
- **[[Troubleshooting]]** — fixes for typical issues.
- **API reference** → the [live DocC docs](https://isamercan.github.io/ThemeKit/api/documentation/themekit)

The detailed, styled DocC docs live at
[isamercan.github.io/ThemeKit](https://isamercan.github.io/ThemeKit/api/documentation/themekit).
This wiki holds the light, fast-changing helper pages.
