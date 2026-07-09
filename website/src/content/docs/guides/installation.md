---
title: Installation
description: Add ThemeKit to your app with Swift Package Manager.
---

ThemeKit ships as a Swift Package. It targets **iOS 17+ / macOS 14+** with
**Swift 6.2** tools, and the core product has **zero dependencies** — a plain
install resolves *nothing* third-party. Lottie and the Calendar are opt-in add-ons
gated behind [package traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md),
so their dependencies (Lottie, Almanac/HorizonCalendar) are only fetched if you ask
for them.

## Xcode

*File ▸ Add Package Dependencies…* and enter the repository URL:

```
https://github.com/isamercan/ThemeKit.git
```

You'll get the dependency-free core. To add an optional add-on, enable its trait in
the package's **Traits** section (checkbox) — `Lottie` and/or `Calendar` — then add
the matching library to your target.

## Package.swift

```swift
dependencies: [
    // Core only — zero third-party packages are resolved.
    .package(url: "https://github.com/isamercan/ThemeKit.git", from: "0.3.0"),

    // …or opt into an add-on's dependency at resolution time via traits:
    // .package(url: "https://github.com/isamercan/ThemeKit.git", from: "0.3.0",
    //          traits: ["Lottie"]),            // + lottie-ios
    //          traits: ["Lottie", "Calendar"]) // + lottie-ios, Almanac (iOS)
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "ThemeKit", package: "ThemeKit"),
            // Only with the matching trait enabled above:
            // .product(name: "ThemeKitLottie", package: "ThemeKit"),
            // .product(name: "ThemeKitCalendar", package: "ThemeKit"),
        ]
    ),
]
```

## Products & traits

| Product | Trait to enable | Pulls | Use |
|---|---|---|---|
| `ThemeKit` | — (default) | **nothing** | the full design system (core) |
| `ThemeKitLottie` | `Lottie` | `lottie-ios` 4.4.0+ | Lottie (After Effects / JSON) animation views |
| `ThemeKitCalendar` | `Calendar` | `Almanac` → HorizonCalendar (**iOS-only**) | token-bound date-range calendar & time wheel |

:::note[Why traits?]
Without a trait enabled, SwiftPM never resolves the add-on's package, so `swift
package resolve` (and Xcode's package list) stay empty for a core install — the
"zero dependencies" promise holds at *resolution* time, not just link time. Traits
require Swift 6.1+ tooling on the consuming side.
:::

:::tip[Pin a version]
ThemeKit follows Semantic Versioning. Pin with `from: "0.3.0"` to take patches and
minor updates, or pin an exact version for fully reproducible builds.
:::

Next: [Getting Started](../getting-started/).
