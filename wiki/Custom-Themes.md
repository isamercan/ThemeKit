# Custom Themes — import a CSS design system

Already have a web design system as CSS custom properties (HeroUI, Tailwind,
shadcn…)? Hand it to ThemeKit **directly** — the `oklch()` / hex variables are
parsed on-device at runtime and the whole token set is generated for you. No JSON,
no build step. ThemeKit even ships a ready-made **HeroUI** theme.

## Drop a `.css` and apply it

```swift
Theme.shared.loadTheme(cssNamed: "heroui", font: "Inter")  // bundled HeroUI theme
Theme.shared.loadTheme(cssNamed: "brand")                  // your own brand.css in the app bundle
```

`loadTheme(cssNamed:)` searches the ThemeKit bundle first, then your app's main
bundle — so a consumer just drops `brand.css` into their app.

## Apply a CSS string

From a file, a network response, anywhere:

```swift
let css = try String(contentsOf: url)     // your theme.css
Theme.shared.setTheme(css: css)           // parsed + applied instantly, no restart
Theme.shared.setColorScheme(dark: true)   // switches to the CSS's .dark block
```

## What maps to what

Both the `:root`/`.light` and `.dark` blocks are read:

| CSS variable | ThemeKit |
| --- | --- |
| `--accent` | primary + info palette, `bg-hero`, focus |
| `--danger` / `--success` / `--warning` | the semantic colors |
| `--background` / `--foreground` | page surface / primary text |
| `--border` / `--muted` | borders / secondary text |
| `--surface*` / `--default` | elevated surfaces |
| `--radius` / `--field-radius` | box / field radius roles |

Anything the CSS doesn't define falls back to ThemeKit's defaults. The CSS is
treated as untrusted text — only `--var: value;` declarations are read, nothing is
executed. Custom fonts (e.g. Inter) must be bundled and registered in your app to
render; otherwise the type ramp uses the system font.

## Offline alternative

Prefer to bundle a static JSON (zero runtime parse)? The same conversion runs
offline as a Python tool:

```bash
# theme.css → brandTheme.json + brandThemeDark.json
python3 tools/import_css_theme.py theme.css --name brand \
    --out Sources/ThemeKitCore/Resources --font Inter
```

```swift
Theme.shared.loadTheme(named: "brandTheme")
```

See also the [Theming guide](https://isamercan.github.io/ThemeKit/guides/theming/)
on the docs site.
