# ThemeKit Demo

A SwiftUI iOS app that consumes the local `ThemeKit` package and
showcases its theme system and components.

## Run

```bash
open Demo/Demo.xcodeproj
```

Select the **Demo** scheme + an iOS Simulator and hit **Run** (⌘R).

The project references the package via a **local** Swift Package reference
(`relativePath = ..`), so any change in `Sources/ThemeKit` is picked
up immediately.

## Tabs

- **Theme** — gallery of every color token (background / foreground / border /
  accent), updates live when you switch theme.
- **Typography** — `FontKey × FontSizeKey` samples.
- **Components** — `PrimaryButton` / `SecondaryButton` / `OutlineButton` (with
  enabled / loading / size variants), `DividerView`, `cornerRadiusStyle`.

The toolbar paint-palette menu switches between **Default / Ocean / Sunset** at
runtime; the choice is persisted in `UserDefaults`.

## Theme wiring

- `DemoApp` injects `Theme.shared` + `DemoThemeStore` into the environment.
- `DemoTheme` maps each generic theme to its bundled JSON resource name.

## Screenshot automation

Launch arguments map into `UserDefaults` (NSArgumentDomain), so themes/tabs can
be driven headlessly:

```bash
xcrun simctl launch --terminate-running-process <device> com.globalcomponents.Demo \
  -selectedTheme ocean -startTab 2
```
