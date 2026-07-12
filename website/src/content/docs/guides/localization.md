---
title: Localization
description: Translate the entire ThemeKit component library into any language with one String Catalog — no per-call code, with restart-free in-app language switching.
---

Every user-facing default string in ThemeKit (placeholders, VoiceOver labels, step
states, button titles…) flows through a **single localization bridge** and resolves
against a **String Catalog**. That means you can translate the *whole library* into
any language by adding **one file** to your app — no per-call code, and the switch
can happen live, without an app restart.

This is the consumer side of [ADR-0003](https://github.com/isamercan/ThemeKit/blob/main/docs/ADR-0003-localization-override.md).

## 1. Zero-config — follow the device language (3 steps)

1. **Create the catalog.** In your **app** target: *File → New → String Catalog*,
   name it exactly **`ThemeKit.xcstrings`**. The file name is the strings-table
   name; ThemeKit looks up the `"ThemeKit"` table in `Bundle.main` by default, so
   no registration call is needed. Any group/folder works — target membership is
   what matters.
2. **Add your language + translations.** Press **＋** in the catalog editor, add
   Turkish (or any language), and translate the keys you care about. **Keys are
   ThemeKit's English source strings verbatim** — `Card number`, `Select`,
   `Promo code:`, `Available`. Start from the shipped template (below) so you never
   guess the key set. Untranslated keys fall back to English **per key**.
3. **Build & run.** Xcode compiles the catalog into `Bundle.main`
   (`tr.lproj/ThemeKit.strings`). When the device — or the per-app language in
   *Settings → YourApp → Language* — is Turkish, **every ThemeKit component renders
   Turkish.** No API calls.

### The file, exactly

```json
{
  "sourceLanguage" : "en",
  "version" : "1.0",
  "strings" : {
    "Card number" : {
      "extractionState" : "manual",
      "shouldTranslate" : true,
      "localizations" : {
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Kart numarası" } }
      }
    },
    "Promo code:" : {
      "localizations" : {
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Promosyon kodu:" } }
      }
    },
    "%@ out of %@" : {
      "comment" : "Rating VoiceOver value — interpolated keys use %@ for every value; reorder with %1$@/%2$@ if your grammar needs it.",
      "localizations" : {
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "%2$@ üzerinden %1$@" } }
      }
    }
  }
}
```

Two rules that matter:

- **Interpolated keys use `%@` for *every* value** — numbers included (ThemeKit
  canonicalizes all interpolations to `%@`, so the key for `"\(count) installments"`
  is `"%@ installments"`). If your translation reorders the values, use positional
  forms (`%1$@`, `%2$@`).
- **Keep `"generatesSymbol" : false`** on entries if you paste from the shipped
  template. ThemeKit's key set contains case-/punctuation-differing keys
  (`Adults`/`adults`, `Loading`/`Loading…`) that would otherwise collide during
  Xcode's String-Catalog **symbol generation** and fail the build. The template
  already sets this; leave it in place.

> **Start from the template, don't hand-list keys.** The full, always-current key
> set ships at
> [`docs/templates/ThemeKit.xcstrings`](https://github.com/isamercan/ThemeKit/blob/main/docs/templates/ThemeKit.xcstrings)
> (regenerated from source by `make l10n`). Copy it into your app and fill in your
> language column.

## 2. Switch language in code — no restart

`.themeKit()` at your root (the provider you already add for theming) **folds in live
localization** — so there's no extra provider to wire. Flip the language from anywhere:

```swift
import ThemeKit

@main
struct TravelApp: App {
    @AppStorage("appLanguage") private var appLanguage = "en"
    var body: some Scene {
        WindowGroup {
            RootView()
                .themeKit()                                            // root, once — folds in localization
                .onAppear { ThemeKitStrings.setLanguage(appLanguage) }
        }
    }
}

// Anywhere — a settings screen:
ThemeKitStrings.setLanguage("tr")   // whole UI → Turkish (short alias: Theme.setLanguage("tr"))
ThemeKitStrings.setLanguage(nil)    // follow the device language again
ThemeKitStrings.currentLanguage     // "tr"
```

`.themeKit()` observes `ThemeKitStrings`, re-injects the effective `\.locale` and an
RTL-correct `\.layoutDirection`, and re-identifies the subtree so **every** string
re-resolves on a change — including strings produced *outside* the SwiftUI view graph
(enum/model helpers), which a plain environment value can never reach.

Drive it from ThemeKit's own [`LanguageSwitcher`](/components/molecules/), bound to the
ready-made `Binding`:

```swift
LanguageSwitcher([.init(code: "en"), .init(code: "tr")],
                 selection: ThemeKitStrings.languageBinding)   // flips the whole UI live
```

Flip the picker and the entire library — View strings and non-View enum strings alike —
switches language instantly, with no relaunch. (Prefer an explicit, subtree-scoped
provider instead of `.themeKit()`? Use `.themeKitLocalized()`.)

## Loading the file from elsewhere (extensions / frameworks)

Zero-config assumes `Bundle.main` + table `"ThemeKit"`. If your catalog ships in an app
**extension** (whose `.main` is the extension), in a **framework** that embeds ThemeKit,
or under a different table name, point ThemeKit at it once at launch:

```swift
ThemeKitStrings.register(bundle: .myFrameworkBundle, table: "ThemeKit")
```

`register(bundle:table:)` is the public entry point — the `bundle`/`table` are not
settable individually. Call it before the first ThemeKit view renders (e.g. in your
`App.init()` or `application(_:didFinishLaunching…)`).

## Precedence — highest wins

1. **Per-component parameters** you pass in code (`Component(title: "…")`,
   `ValidationRule.required("…")`) — always win, never reach the bridge.
2. Your `ThemeKit.xcstrings`, in the **forced** locale (`ThemeKitStrings.locale`).
3. Your `ThemeKit.xcstrings`, in the **device/app** language.
4. Your `ThemeKit.xcstrings` **English** rewording (if you reword a default).
5. ThemeKit's bundled catalog → the English source key.

With no consumer catalog and no locale override, resolution is **byte-identical to
stock ThemeKit** — this feature is purely additive.

## Scoped locale (formatting only)

`themeKitLocale(_:)` scopes `\.locale` (and layout direction) for a subtree — useful
for the ~50 locale-reading components (dates, numbers, currency). It does **not**
change catalog string language: a `String` initializer can't read the environment,
so two different *string* languages on one screen isn't possible. Use it for
formatting, not for mixed-language copy.

```swift
PriceBreakdown(order).themeKitLocale(Locale(identifier: "de"))   // German number/currency formatting
```

## Try it

The demo app ships a **Live Localization** screen (a `LanguageSwitcher` over
`.themeKitLocalized()`, flipping a View string and non-View enum titles EN↔TR live,
with an Arabic RTL toggle):

```sh
xcrun simctl launch com.globalcomponents.Demo -openDemo "Live Localization"
```

## Caveats

- **The live switch resets view identity** below the provider (scroll position,
  transient `@State`). That's the standard trade-off of restart-free language
  switching; app state in `@Observable` models and navigation state survive.
- **`.xcstrings` only works compiled.** Xcode/`xcodebuild` compile your app target's
  catalog automatically, so real apps are always fine. (A bare `swift build` of an
  SPM *library* copies `.xcstrings` verbatim and won't resolve translations — your
  catalog lives in the *app* target, so this never affects you.)
- **Strings copied out of a component and stored** (e.g. captured into a model at
  init) won't update on switch — resolve at render time.
