# ThemeKit

> A token-driven, zero-dependency SwiftUI design system.

A themable palette, 100+ token-bound SwiftUI components, a validation layer, and
accessibility (Dynamic Type, VoiceOver, RTL) — all with no third-party
dependencies in the core.

📖 **Full DocC documentation** is built locally (the repo is private, so it isn't
published to Pages):

```bash
swift package --disable-sandbox preview-documentation --target ThemeKit
```

## Quick install

```swift
.package(url: "https://github.com/isamercan/ThemeKit", .upToNextMinor(from: "0.1.0"))
```

Apply the theme once at your app root, then compose components:

```swift
ContentView().globalUITheme()
```

## Where to go next

- **[[Kurulum|Installation]]** — add the package to your project.
- **[[SSS|FAQ]]** — common questions.
- **[[Sorun Giderme|Troubleshooting]]** — fixes for typical issues.
- **API reference** → build the DocC docs locally (command above)

The detailed, styled DocC docs are built locally / downloaded from the **Docs**
CI artifact. This wiki holds the light, fast-changing helper pages.
