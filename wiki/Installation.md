# Installation

Swift Package Manager, in Xcode or `Package.swift`.

## Xcode

1. **File ▸ Add Package Dependencies…**
2. URL: `https://github.com/isamercan/GlobalUIComponents`
3. Dependency Rule: **Up to Next Minor Version** — `0.1.0`
4. Add the **GlobalUIComponents** product to your target.

## Package.swift

```swift
.package(url: "https://github.com/isamercan/GlobalUIComponents", .upToNextMinor(from: "0.1.0")),
```

```swift
.product(name: "GlobalUIComponents", package: "GlobalUIComponents"),
// Optional Lottie add-on:
// .product(name: "GlobalUIComponentsLottie", package: "GlobalUIComponents"),
```

## Platforms

| Platform | Minimum |
|----------|---------|
| iOS | 17.0 |
| macOS | 14.0 |

The core is **zero-dependency**; Lottie is pulled in only via the
`GlobalUIComponentsLottie` product.

📖 Detailed version: the **Installation** article in the DocC docs
(`Sources/GlobalUIComponents/Documentation.docc/Installation.md`), viewable with
`swift package --disable-sandbox preview-documentation --target GlobalUIComponents`.
