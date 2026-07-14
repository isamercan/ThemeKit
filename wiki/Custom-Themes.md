# Custom Themes — import a CSS design system

Already have a web design system as CSS custom properties (HeroUI, Tailwind,
shadcn…)? ThemeKit ships a ready-made **HeroUI** theme, and can convert any
HeroUI-style CSS token file (`oklch()` / hex variables) into a native theme.

## 1. Use the bundled HeroUI theme

```swift
Theme.shared.loadTheme(named: "herouiTheme")              // light
Theme.shared.loadTheme(named: "herouiTheme", dark: true)  // dark
```

## 2. Bring your own CSS

Convert a CSS token file once — it writes a light + dark JSON pair:

```bash
# theme.css → brandTheme.json + brandThemeDark.json
python3 tools/import_css_theme.py theme.css --name brand \
    --out Sources/ThemeKitCore/Resources --font Inter
```

Then load it like any bundled theme:

```swift
Theme.shared.loadTheme(named: "brandTheme")
```

The importer maps `--accent` → the primary/info palette, `--danger` /
`--success` / `--warning` → the semantic colors, and `--background` /
`--foreground` / `--border` / `--muted` → the neutral surfaces and text.
`--radius` / `--field-radius` become the box/field radius roles. Anything the CSS
doesn't define falls back to ThemeKit's defaults.

## 3. Apply a CSS theme at runtime

A host app can hand ThemeKit a generated JSON directly — no library rebuild,
applied instantly (the same entry point the localization override uses):

```swift
let data = try Data(contentsOf: url)    // your generated theme JSON
Theme.shared.setTheme(jsonData: data)   // applies instantly, no restart
```

> Custom fonts (e.g. Inter) must be bundled and registered in your app to render;
> otherwise the type ramp falls back to the system font.

See also the [Theming guide](https://isamercan.github.io/ThemeKit/guides/theming/)
on the docs site.
