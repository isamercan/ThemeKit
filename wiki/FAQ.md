# FAQ

### Does it pull in any third-party dependencies?

No. The core `GlobalUIComponents` product is **zero-dependency**. Lottie is only
downloaded if you depend on the separate `GlobalUIComponentsLottie` product.

### Do components work without applying a theme?

They render, but fall back to system defaults. Apply
`.globalUITheme()` once at your app/scene root so components resolve the
design-system palette, spacing, and fonts.

### How do I switch light / dark?

The active theme is a singleton:

```swift
Theme.shared.setColorScheme(dark: true)
```

If you applied `.globalUITheme()` (which reacts to runtime changes by default),
the whole UI re-skins.

### Can I brand it with my own colors?

Yes — generate a full palette from a single accent color at runtime:

```swift
Theme.shared.apply(ThemeConfig(primaryHex: "#7C3AED"))
```

### Does text scale with Dynamic Type?

Yes. The type ramp (`TextStyle`) is built with `relativeTo:`, so every
`.textStyle(_:)` grows and shrinks with the user's preferred text size. Many
controls also scale their height to match.

### Is right-to-left (Arabic / Hebrew) supported?

Yes. SwiftUI mirrors layout automatically, and directional glyphs (chevrons,
back/next arrows) are flipped via the library's RTL helper.

### Which platforms?

iOS 17+ and macOS 14+.

📖 Full API reference — build the DocC docs locally (the repo is private):
`swift package --disable-sandbox preview-documentation --target GlobalUIComponents`
