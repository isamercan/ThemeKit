# Installation

Add `GlobalUIComponents` with Swift Package Manager — in Xcode or in a
`Package.swift`.

## Overview

The package ships two products. Depend on the core for the component library;
add the Lottie add-on only if you need vector animations.

| Product | Contents | Dependencies |
|---------|----------|--------------|
| `GlobalUIComponents` | The full design system (theme, components, validation, accessibility). | **None** |
| `GlobalUIComponentsLottie` | Lottie-backed animation views (`LottieIllustration`, `LottieEmptyState`). | Lottie |

### In Xcode

1. **File ▸ Add Package Dependencies…**
2. Enter the URL: `https://github.com/isamercan/GlobalUIComponents`
3. Dependency Rule: **Up to Next Minor Version** — `0.1.0`.
   (The API is still stabilising in `0.x`; minor releases may break. See
   <doc:GettingStarted> and the project's API-stability policy.)
4. Add the **GlobalUIComponents** library product to your app target.

### In a Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/isamercan/GlobalUIComponents", .upToNextMinor(from: "0.1.0")),
],
targets: [
    .target(
        name: "MyFeature",
        dependencies: [
            .product(name: "GlobalUIComponents", package: "GlobalUIComponents"),
            // Optional — only if you use Lottie views:
            // .product(name: "GlobalUIComponentsLottie", package: "GlobalUIComponents"),
        ]
    ),
]
```

### Supported platforms

| Platform | Minimum |
|----------|---------|
| iOS | 17.0 |
| macOS | 14.0 |

> Note: The core library has **zero** third-party dependencies. Lottie is pulled
> in only when you depend on the `GlobalUIComponentsLottie` product, so apps that
> don't need it never download it.

Then apply the theme and start composing — see <doc:GettingStarted>.
