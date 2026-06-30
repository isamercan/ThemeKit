---
title: Installation
description: Add ThemeKit to your app with Swift Package Manager.
---

ThemeKit ships as a Swift Package. It targets **iOS 17+ / macOS 14+** with
**Swift 6.2** tools, and the core product has **zero dependencies**.

## Xcode

*File ▸ Add Package Dependencies…* and enter the repository URL:

```
https://github.com/isamercan/ThemeKit.git
```

## Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/isamercan/ThemeKit.git", from: "0.3.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "ThemeKit", package: "ThemeKit"),
            // Optional — only if you need Lottie-backed animations:
            // .product(name: "ThemeKitLottie", package: "ThemeKit"),
        ]
    ),
]
```

## Products

| Product | Dependencies | Use |
|---|---|---|
| `ThemeKit` | none | the full design system (core) |
| `ThemeKitLottie` | `lottie-ios` 4.4.0+ | adds Lottie (After Effects / JSON) animation views — pulls Lottie **only** if imported |

:::tip[Pin a version]
ThemeKit follows Semantic Versioning. Pin with `from: "0.3.0"` to take patches and
minor updates, or pin an exact version for fully reproducible builds.
:::

Next: [Getting Started](../getting-started/).
