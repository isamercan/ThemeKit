# Troubleshooting

### Components show system colors / fonts instead of the design system

You haven't applied the theme. Add `.globalUITheme()` at the root of your scene:

```swift
WindowGroup { ContentView().globalUITheme() }
```

### Dark mode looks wrong in tests or previews

Components read their palette from the `Theme.shared` singleton, **not** the
SwiftUI `\.colorScheme` environment. Drive it explicitly:

```swift
Theme.shared.setColorScheme(dark: true)
```

In previews, wrap content in `.globalUITheme()` so the palette is installed.

### `swift build` fails with "package requires tools version 6.2"

The package targets Swift 6.2. Install/select Xcode 26 (or newer):

```bash
sudo xcode-select -s /Applications/Xcode_26.app
```

### Published DocC on Pages loads with no CSS (everything 404s)

The `--hosting-base-path` is wrong. For a **project site**
(`user.github.io/<repo>/`) it must equal the repo name:

```
--hosting-base-path GlobalUIComponents
```

For a user/custom-domain site, drop the flag entirely.

### Montserrat font isn't rendering

The bundled font is loaded via `.globalUITheme()`. If you render components
without it, type falls back to the system font (by design). Make sure the theme
is applied above the views that use `.textStyle(_:)`.

### Visual-regression (snapshot) tests are all skipped

They're opt-in. Set `RUN_SNAPSHOTS=1` on the test scheme's **Test action**
(shell env vars don't cross into the Simulator). See the project's
`docs/SNAPSHOT-TESTING.md`.

Still stuck? Open an issue — see **[[Katkı|Contributing]]**.
