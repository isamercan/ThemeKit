# Localization

Translate the whole component library into any language with one String Catalog —
no per-call code, with restart-free in-app language switching.

## Overview

Every user-facing default string in ThemeKit (placeholders, VoiceOver labels, step
states, button titles…) flows through a single bridge — `String(themeKit:)` — and
resolves through the localization chain introduced in ADR-0003. A consumer translates
the entire library by dropping one **`ThemeKit.xcstrings`** into their app target;
per-component parameter overrides still win over everything.

### Zero-config — follow the device language

Add a String Catalog named exactly `ThemeKit.xcstrings` to your **app** target and
translate the keys. ThemeKit looks up the `"ThemeKit"` table in `Bundle.main` by
default, so there is nothing to call. When the device or per-app language matches a
language you translated, every component renders it; untranslated keys fall back to
English per key.

- **Keys are ThemeKit's English source strings** (`Card number`, `Select`,
  `Promo code:`). Start from the generated template at
  `Templates/ThemeKit.xcstrings` — it is the always-current key set (`make l10n`).
- **Interpolated keys use `%@` for every value** (numbers included): the key for
  `"\(count) installments"` is `"%@ installments"`. Reorder with `%1$@`/`%2$@`.
- **Keep `"generatesSymbol": false`** on template entries — ThemeKit's key set has
  case-/punctuation-differing keys that would otherwise collide in Xcode's
  String-Catalog symbol generation.

### Restart-free in-app switching

`.themeKit()` at the app root (the provider you already add for theming) folds in live
localization — so there's nothing extra to wire. Switch the language from anywhere:

```swift
RootView().themeKit()               // root, once — folds in localization

// later, from a settings screen — flips the whole UI live, no relaunch:
Theme.setLanguage("tr")   // short alias: Theme.setLanguage("tr")
Theme.setLanguage(nil)    // follow the device
```

An explicit, subtree-scoped provider is available as `themeKitLocalized()`; a picker
can bind to `ThemeKitStrings.languageBinding`.

`themeKitLocalized()` observes `ThemeKitStrings`, re-injects `\.locale` +
RTL-correct `\.layoutDirection`, and re-identifies the subtree so **every** string
re-resolves — including strings produced outside the view graph (enum/model
helpers), which a plain environment value cannot reach.

Use `themeKitLocale(_:)` to scope `\.locale` (formatting and the
locale-reading components) for a subtree; it does not change catalog string language.

### Precedence (highest wins)

1. Per-component parameter (`Component(title:)`) — never reaches the bridge.
2. Consumer catalog, forced locale (`ThemeKitStrings.locale`).
3. Consumer catalog, device/app language.
4. Consumer catalog, English rewording.
5. ThemeKit's bundled catalog → English source key.

With no consumer catalog and no override, output is byte-identical to stock ThemeKit.

## API

The localization primitives live in the token-only **ThemeKitCore** layer, so their
symbol reference is in the [ThemeKitCore API](https://isamercan.github.io/ThemeKit/api-core/documentation/themekitcore/):
`View/themeKitLocalized()`, `View/themeKitLocale(_:)`, `ThemeKitStrings`, and
`ThemeKitLocalizationValue`.
