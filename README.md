# ThemeKit

A theme-driven, **brand-neutral** SwiftUI component library. Every color,
typography, spacing, radius and shadow is a **design token** resolved at runtime
from the active `Theme`, so the whole UI re-skins from a single accent color —
without touching component code.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014-blue.svg)
![Dependencies](https://img.shields.io/badge/Core%20dependencies-0-success.svg)

> **Principle:** components never hardcode a color — every value resolves from the
> active `Theme`. Swap the theme and everything follows.

```swift
import ThemeKit
```

## Features

- **Token system** — colors / radius / spacing from JSON, typography / shadows in
  code; one semantic name (`fg-hero`, `rd-sm`), different values per theme.
- **Runtime theming** — a Swift token generator + a live configurator turn any
  accent color into a full Ant-style palette on device (no Python, no baked files).
- **130+ components** — Atoms / Molecules / Organisms, all token-bound.
- **Validation** — pure, testable predicates + a SwiftUI presentation layer.
- **Accessibility** — Dynamic Type and Reduce Motion honored throughout.
- **Localization** — English-default strings via a bundled String Catalog (with
  Turkish), every default still overridable.
- **Zero-dependency core** — Lottie is an opt-in, separate product.
- **DocC catalog**, a demo app, and a test suite.

## Requirements

| | |
|---|---|
| Platforms | iOS 17+ · macOS 14+ |
| Swift tools | 6.2 |
| Dependencies | none (core) · `lottie-ios` 4.4.0+ (only the Lottie add-on) |

## Installation

Swift Package Manager. In **Xcode**: *File ▸ Add Package Dependencies…* and enter
the repository URL, or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/isamercan/ThemeKit.git", from: "0.1.0"),
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

> This is a **private** repository — resolving it requires GitHub access
> (an authenticated SSH key or token).

### Products

| Product | Dependencies | Use |
|---|---|---|
| `ThemeKit` | none | the full design system (core) |
| `ThemeKitLottie` | `lottie-ios` | adds Lottie (After Effects / JSON) animation views; pulls Lottie **only** if imported |

## Quick start

Install the theme once at the root, then build with token-bound views:

```swift
@main
struct MyApp: App {
    init() { Theme.shared.applyPersistedConfig() }   // restore last-used theme (optional)
    var body: some Scene {
        WindowGroup {
            ContentView().themeKit()            // inject + repaint on theme change
        }
    }
}

struct ContentView: View {
    @ThemeContext private var theme
    var body: some View {
        VStack(spacing: theme.spacing(.md)) {
            Text("Welcome").textStyle(.headingBase)
            PrimaryButton(title: "Get started") { await signIn() }
        }
        .padding(theme.spacing(.base))
        .background(theme.background(.bgElevatorPrimary))
        .cornerRadius(.base)
        .themeShadow(.elevated)
    }
}

Theme.shared.loadTheme(named: "oceanTheme")          // runtime switch
```

## Components

~130 token-bound components, grouped by complexity:

- **Atoms** (26) — `Badge`, `Chip`, `Avatar`, `Icon`, `Rating`, `Spinner`,
  `StatusDot`, `Skeleton`, `ProgressBar`, `BorderBeam`, `RollingNumber`…
- **Molecules** (35) — `TextInput`, `OTPInput`, `Select`, `Checkbox`,
  `RadioGroup`, `Slider`, `RangeSlider`, `SearchBar`, `Tooltip`, buttons…
- **Organisms** (44) — `Card`, `Carousel`, `DataTable`, `Accordion`, `Steps`,
  `Timeline`, `ResultView`, `Upload`, `Tour`, `NavigationBar`…

Every component is curated by category in the [DocC catalog](#documentation).

## Component gallery

Rendered straight from the library via `ImageRenderer` (default theme, light) —
regenerate with `make screenshots`. Interactive overlays (Dialog, Drawer, Tour,
BottomSheet…) and media components are best seen live in the [Demo app](#demo).

<!-- GALLERY:START -->

### Atoms

<table>
<tr>
<td align="center" width="33%"><img src="Screenshots/Avatar.png" width="240" alt="Avatar"><br><sub><b>Avatar</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Badge.png" width="240" alt="Badge"><br><sub><b>Badge</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Chip.png" width="240" alt="Chip"><br><sub><b>Chip</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/CountBadge.png" width="240" alt="CountBadge"><br><sub><b>CountBadge</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Divider.png" width="240" alt="Divider"><br><sub><b>Divider</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Icon.png" width="240" alt="Icon"><br><sub><b>Icon</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Indicator.png" width="240" alt="Indicator"><br><sub><b>Indicator</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/InputLabel.png" width="240" alt="InputLabel"><br><sub><b>InputLabel</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Kbd.png" width="240" alt="Kbd"><br><sub><b>Kbd</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/ProgressBar.png" width="240" alt="ProgressBar"><br><sub><b>ProgressBar</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/RadialProgress.png" width="240" alt="RadialProgress"><br><sub><b>RadialProgress</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Rating.png" width="240" alt="Rating"><br><sub><b>Rating</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/RollingNumber.png" width="240" alt="RollingNumber"><br><sub><b>RollingNumber</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ScoreBadge.png" width="240" alt="ScoreBadge"><br><sub><b>ScoreBadge</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Skeleton.png" width="240" alt="Skeleton"><br><sub><b>Skeleton</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Spinner.png" width="240" alt="Spinner"><br><sub><b>Spinner</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/StatusDot.png" width="240" alt="StatusDot"><br><sub><b>StatusDot</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Swap.png" width="240" alt="Swap"><br><sub><b>Swap</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Tag.png" width="240" alt="Tag"><br><sub><b>Tag</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/TextLink.png" width="240" alt="TextLink"><br><sub><b>TextLink</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Title.png" width="240" alt="Title"><br><sub><b>Title</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/InlineText.png" width="240" alt="InlineText"><br><sub><b>InlineText</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/BorderBeam.png" width="240" alt="BorderBeam"><br><sub><b>BorderBeam</b></sub></td>
</tr>
</table>

### Molecules

<table>
<tr>
<td align="center" width="33%"><img src="Screenshots/Button.png" width="240" alt="Button"><br><sub><b>Button</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ThemeButton.png" width="240" alt="ThemeButton"><br><sub><b>ThemeButton</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Checkbox.png" width="240" alt="Checkbox"><br><sub><b>Checkbox</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/CheckboxGroup.png" width="240" alt="CheckboxGroup"><br><sub><b>CheckboxGroup</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/RadioButton.png" width="240" alt="RadioButton"><br><sub><b>RadioButton</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/RadioGroup.png" width="240" alt="RadioGroup"><br><sub><b>RadioGroup</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/ToggleGroup.png" width="240" alt="ToggleGroup"><br><sub><b>ToggleGroup</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ThemeToggle.png" width="240" alt="ThemeToggle"><br><sub><b>ThemeToggle</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/SegmentedControl.png" width="240" alt="SegmentedControl"><br><sub><b>SegmentedControl</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/QuantityStepper.png" width="240" alt="QuantityStepper"><br><sub><b>QuantityStepper</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Stat.png" width="240" alt="Stat"><br><sub><b>Stat</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Steps.png" width="240" alt="Steps"><br><sub><b>Steps</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Slider.png" width="240" alt="Slider"><br><sub><b>Slider</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Breadcrumbs.png" width="240" alt="Breadcrumbs"><br><sub><b>Breadcrumbs</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/TextInput.png" width="240" alt="TextInput"><br><sub><b>TextInput</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/FileInput.png" width="240" alt="FileInput"><br><sub><b>FileInput</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Pagination.png" width="240" alt="Pagination"><br><sub><b>Pagination</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Fieldset.png" width="240" alt="Fieldset"><br><sub><b>Fieldset</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/DateField.png" width="240" alt="DateField"><br><sub><b>DateField</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Select.png" width="240" alt="Select"><br><sub><b>Select</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/MultiSelect.png" width="240" alt="MultiSelect"><br><sub><b>MultiSelect</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/TreeSelect.png" width="240" alt="TreeSelect"><br><sub><b>TreeSelect</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Autocomplete.png" width="240" alt="Autocomplete"><br><sub><b>Autocomplete</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/SearchBar.png" width="240" alt="SearchBar"><br><sub><b>SearchBar</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/OTPInput.png" width="240" alt="OTPInput"><br><sub><b>OTPInput</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/InputNumber.png" width="240" alt="InputNumber"><br><sub><b>InputNumber</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/RangeSlider.png" width="240" alt="RangeSlider"><br><sub><b>RangeSlider</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/MultiLineTextInput.png" width="240" alt="MultiLineTextInput"><br><sub><b>MultiLineTextInput</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Tooltip.png" width="240" alt="Tooltip"><br><sub><b>Tooltip</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Chips.png" width="240" alt="Chips"><br><sub><b>Chips</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/FilterGroup.png" width="240" alt="FilterGroup"><br><sub><b>FilterGroup</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ProgressIndicator.png" width="240" alt="ProgressIndicator"><br><sub><b>ProgressIndicator</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ThemeController.png" width="240" alt="ThemeController"><br><sub><b>ThemeController</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Calendar.png" width="240" alt="Calendar"><br><sub><b>Calendar</b></sub></td>
</tr>
</table>

### Organisms

<table>
<tr>
<td align="center" width="33%"><img src="Screenshots/Accordion.png" width="240" alt="Accordion"><br><sub><b>Accordion</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/AlertToast.png" width="240" alt="AlertToast"><br><sub><b>AlertToast</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Callout.png" width="240" alt="Callout"><br><sub><b>Callout</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Card.png" width="240" alt="Card"><br><sub><b>Card</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ChatBubble.png" width="240" alt="ChatBubble"><br><sub><b>ChatBubble</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Counter.png" width="240" alt="Counter"><br><sub><b>Counter</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Coupon.png" width="240" alt="Coupon"><br><sub><b>Coupon</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/EmptyState.png" width="240" alt="EmptyState"><br><sub><b>EmptyState</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/InfoBanner.png" width="240" alt="InfoBanner"><br><sub><b>InfoBanner</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/KeyValueTable.png" width="240" alt="KeyValueTable"><br><sub><b>KeyValueTable</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ListRow.png" width="240" alt="ListRow"><br><sub><b>ListRow</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/NotificationCard.png" width="240" alt="NotificationCard"><br><sub><b>NotificationCard</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/PageHeader.png" width="240" alt="PageHeader"><br><sub><b>PageHeader</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/RatingSummary.png" width="240" alt="RatingSummary"><br><sub><b>RatingSummary</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ResultView.png" width="240" alt="ResultView"><br><sub><b>ResultView</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/SegmentedTabBar.png" width="240" alt="SegmentedTabBar"><br><sub><b>SegmentedTabBar</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Timeline.png" width="240" alt="Timeline"><br><sub><b>Timeline</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Upload.png" width="240" alt="Upload"><br><sub><b>Upload</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/PromoBanner.png" width="240" alt="PromoBanner"><br><sub><b>PromoBanner</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/ListView.png" width="240" alt="ListView"><br><sub><b>ListView</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/MenuCard.png" width="240" alt="MenuCard"><br><sub><b>MenuCard</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/NavigationBar.png" width="240" alt="NavigationBar"><br><sub><b>NavigationBar</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/FAB.png" width="240" alt="FAB"><br><sub><b>FAB</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Hero.png" width="240" alt="Hero"><br><sub><b>Hero</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/SelectionCards.png" width="240" alt="SelectionCards"><br><sub><b>SelectionCards</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/CardStack.png" width="240" alt="CardStack"><br><sub><b>CardStack</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Gallery.png" width="240" alt="Gallery"><br><sub><b>Gallery</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/Footer.png" width="240" alt="Footer"><br><sub><b>Footer</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Diff.png" width="240" alt="Diff"><br><sub><b>Diff</b></sub></td>
</tr>
</table>

### Overlays (animated)

_Entrance previews rendered from the live components. SelectBox, BottomSheet, Tour and Feedback use OS-owned presentations (native `Menu` / `.sheet`) that no offscreen renderer can capture — record them from the running app with `make record-gif NAME=SelectBox` (boots the simulator, you tap to open the dropdown; see [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md))._

<table>
<tr>
<td align="center" width="33%"><img src="Screenshots/Dialog.gif" width="260" alt="Dialog"><br><sub><b>Dialog</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Drawer.gif" width="260" alt="Drawer"><br><sub><b>Drawer</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Popconfirm.gif" width="260" alt="Popconfirm"><br><sub><b>Popconfirm</b></sub></td>
</tr>
<tr>
<td align="center" width="33%"><img src="Screenshots/AlertToast.gif" width="260" alt="AlertToast"><br><sub><b>AlertToast</b></sub></td>
<td align="center" width="33%"><img src="Screenshots/Tooltip.gif" width="260" alt="Tooltip"><br><sub><b>Tooltip</b></sub></td>
</tr>
</table>
<!-- GALLERY:END -->

## Token system

```
Sources/ThemeKit/
├─ Theme/              # Theme.shared, tokens, generator, configurator API
│  ├─ Theme.swift                 # ObservableObject singleton (Theme.shared)
│  ├─ ColorTokens.generated.swift # Foreground/Background/Border/Text color keys
│  ├─ ThemeModel.swift            # RadiusKey / SpacingKey
│  ├─ Typography.swift            # TextStyle ramp (Montserrat, Dynamic Type)
│  ├─ Shadows.swift               # ShadowStyle + .themeShadow()
│  ├─ SemanticColor.swift         # named palette colors
│  ├─ ThemeGenerator.swift        # runtime palette generator (Swift port)
│  ├─ ThemeConfig.swift           # Codable theme recipe
│  ├─ ThemeKit.swift         # .themeKit() root modifier
│  ├─ ThemeContext.swift          # @ThemeContext property wrapper
│  └─ ThemedHostingController.swift
├─ Components/         # Atoms / Molecules / Organisms (all token-bound)
├─ Validation/         # Validators / ValidationRule / Validator / InfoMessage
├─ Accessibility/      # Reduce Motion + Dynamic Type helpers
├─ Extensions/         # Color(hex:), AspectRatio, Motion, Grid
├─ Utils/              # Haptics, Impression, Localization bridge
├─ Documentation.docc/ # DocC catalog
└─ Resources/
   ├─ *.json                  # defaultTheme / oceanTheme / sunsetTheme (+ Dark)
   ├─ Localizable.xcstrings    # String Catalog (en source + tr)
   └─ Fonts/Montserrat.ttf     # bundled, registered at runtime
```

### Token groups

| Group | Source of truth | Keys |
|---|---|---|
| Colors | `Resources/*.json` | `Theme.ForegroundColorKey` · `BackgroundColorKey` · `BorderColorKey` · `TextColorKey` |
| Radius | `Resources/*.json` | `Theme.RadiusKey` (`rd-xs`…`rd-4xl`) |
| Spacing | `Resources/*.json` | `Theme.SpacingKey` (`sp-xs`…`sp-4xl`) |
| Typography | code (`Typography.swift`) | `TextStyle` — Display / Heading / Label / Body / Overline / Link |
| Shadows | code (`Shadows.swift`) | `ShadowStyle` — elevated / tabBar / soft |

Colors / radius / spacing vary per theme (JSON). Typography & shadows are
structural and constant across themes.

## Themes

`default` (blue) · `ocean` (turquoise) · `sunset` (orange) — each with a Dark
variant. Token **names** are semantic; only the values differ per theme. Add a
theme by dropping a `<name>Theme.json` into `Resources/`.

## Theming your app (Configurator export)

The library ships a **runtime token generator** (`ThemeGenerator`, a Swift port of
`tools/gen_tokens.py`): from a handful of inputs it regenerates the whole palette,
neutral ramp, surfaces, borders, text, and radius / spacing / font / shadow ramps
— on device, no Python and no baked palette files.

The Demo's **Theme Configurator** (Colors tab) lets you dial in an accent color +
tint + scale knobs + font + dark and exports a `ThemeConfig` recipe. To apply one:

```swift
// a) one-liner (paste the configurator's "Apply (Swift)" export)
Theme.shared.applyGenerated(primaryHex: "ff0d87", tint: 0.13, radiusScale: 1.0, font: "Montserrat")

// b) ship the Codable recipe as a resource (the configurator's `theme.json`)
let cfg = try ThemeConfig(jsonData: Data(contentsOf: themeJSONURL))
Theme.shared.apply(cfg)
Theme.shared.persistConfig()                            // remember across launches

// c) generator-free: bundle the pre-baked token JSON ("Copy full token JSON")
Theme.shared.setTheme(jsonData: Data(contentsOf: tokensURL))
```

`ThemeConfig` is `Codable` / `Sendable` / `Equatable` — persist it, sync it, A/B it.

### How live theming works

Components resolve tokens from the `Theme.shared` singleton (no per-call
environment lookups), so SwiftUI can't infer that an arbitrary view depends on the
theme. `.themeKit()` closes that gap: it injects `Theme` into the environment
**and** (by default) rebuilds the subtree keyed on `Theme.revision` when the theme
changes, so every view re-reads the regenerated tokens.

- Switching theme from a **settings screen** → keep the default
  (`reactToRuntimeChanges: true`); the whole UI repaints.
- Editing the theme **in-session** (a live editor/inspector) → use
  `.themeKit(reactToRuntimeChanges: false)` so the editor isn't torn down,
  and scope `.id(Theme.shared.revision)` onto just the live-preview subtree.

### Per-subtree theming (`\.theme`)

Components also read the theme from the `\.theme` environment value, which
**defaults to `Theme.shared`** (so unthemed components never crash). Inject a
different `Theme` instance to re-theme a branch — a second brand in one screen, or
a pinned theme in a preview/snapshot — without mutating global state:

```swift
SomeComponent()
    .theme(brandBTheme)        // this subtree only
```

This is migrating in: pilot components (`Card`, `Tag`) read `\.theme` today; the
rest still read `Theme.shared` directly and are moving over incrementally.

### Fonts

`Montserrat` is bundled. `System` / `SystemRounded` / `SystemSerif` / `SystemMono`
need nothing. Any other family must be registered by the host app (add the `.ttf` +
`UIAppFonts`), then pass its PostScript family name as `font:`.

## Accessibility

- **Dynamic Type** — the type ramp scales with the user's preferred text size:
  each `TextStyle` anchors to a semantic `Font.TextStyle` via `relativeTo:`. At the
  default size nothing changes; it only grows/shrinks when the user opts in. Clamp
  per-screen if needed: `MyScreen().dynamicTypeSize(...DynamicTypeSize.accessibility2)`.
- **Reduce Motion** — decorative/continuous animation is suppressed while
  functional motion is kept: `BorderBeam`, `Skeleton`, `RollingNumber`, `StatusDot`,
  `Carousel` autoplay, the OTP caret all calm down; `Spinner` keeps spinning.

No caller configuration is required — components read the environment directly.

## Validation

A pure logic layer (no SwiftUI, no theme) plus a separate presentation layer:

```swift
let messages = Validator.validate(email, [.required(), .email()])   // [InfoMessage]
InfoMessageList(messages)                                            // SwiftUI rendering
```

Feed your own logic — a custom predicate, a regex, a typed `Regex`, or an async
(server-side) check:

```swift
.regex("^[a-z]+$", caseInsensitive: true, "letters only")
ValidationRule("only AAA") { $0 == "AAA" }
let unique = AsyncValidationRule("Username taken") { await api.isAvailable($0) }
```

`FormValidator` ties fields, rules, focus and messages together for a whole form.

## Localization

User-facing default strings (validation messages, placeholders, accessibility
labels…) come from a bundled **String Catalog** (`Resources/Localizable.xcstrings`).
The source language is **English**; a **Turkish** translation ships too, and
consumers can add their own.

Every such string is also **overridable** via API parameters — e.g.
`ValidationRule.required("Custom message")` — so the catalog only supplies the
default.

> Note: a plain `swift build` copies `.xcstrings` verbatim (the SwiftPM CLI
> doesn't run the catalog compiler), so only English resolves there. Xcode /
> `xcodebuild` compile it, so all bundled localizations resolve in real apps.

## Documentation

A DocC catalog ships with the package
(`Sources/ThemeKit/Documentation.docc`). Build it in Xcode via
**Product ▸ Build Documentation** (⌃⌘D), or from the command line:

```sh
xcodebuild docbuild -scheme ThemeKit -destination 'generic/platform=iOS'
```

It curates every component by category and includes guide articles for
**Theming**, **Accessibility**, and **Validation**. No extra dependency required.

## Demo

`Demo/` — a SwiftUI app (local package reference) with five tabs: **Components**
(gallery), **Colors** (token gallery + live Theme Configurator), **Type**,
**Layout** (spacing / radius / shadow tokens), and **Example** (a full flow built
from the real components), plus a light/dark switcher.

## Adding / updating tokens

Colors are generated to keep JSON ↔ Swift in sync:

1. Update the token maps in `tools/gen_tokens.py`.
2. Re-run: `python3 tools/gen_tokens.py .` (regenerates `Resources/*.json` +
   `ColorTokens.generated.swift`).

Radius / spacing live in `Resources/*.json` (+ the `RadiusKey` / `SpacingKey`
enums); typography / shadows in `Typography.swift` / `Shadows.swift`.

## Testing

```sh
swift test
```

The suite covers the token generator, theme integrity across every bundled theme,
validation, localization, accessibility mapping, and component render smoke tests.

## License

Proprietary — all rights reserved. (Replace with your chosen license before any
public distribution.)
