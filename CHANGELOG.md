# Changelog

All notable changes to **ThemeKit** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) (pre-1.0: breaking changes
bump the minor).

## [0.2.0] - 2026-06-28

The theming release: per-subtree theming, a full singleton→environment migration, the
`ButtonStyle`-shaped style protocols, a micro-animation system, Ant Design feature
parity across the catalog, and the supporting docs/CI/test layer. Also a rename.

### ⚠️ Breaking
- **Renamed the package `GlobalUIComponents` → `ThemeKit`** and rebranded the
  `Global`-prefixed public API to `ThemeKit`. Update the SPM dependency, the product
  name in your target, and `import GlobalUIComponents` → `import ThemeKit`.

### Added
- **Per-subtree theming** — `EnvironmentValues.theme` (defaulting to `Theme.shared`,
  crash-proof) and a `.theme(_:)` modifier. Inject any `Theme` into a subtree and
  every component inside re-skins to it, with no `Theme.shared` mutation. Bundled
  themes (`ocean`, `sunset`) and on-device generation (`applyGenerated(primaryHex:)`).
- **Style protocols** (the `ButtonStyle` idiom) — `.cardStyle(_:)` (surface),
  `.statStyle(_:)` (layout) and `.selectStyle(_:)` (field chrome), each with stock +
  example styles; appearance is supplied by a style without editing the component.
- **Micro-animation system** — subtle motion on selection/input, overlays, value/data
  and navigation, toggleable **theme-wide and per-component**, and always yielding to
  Reduce Motion.
- **Ant Design feature parity** across the catalog, including: Tooltip placement +
  color variants + self-trigger, Popconfirm 4-way placement + async confirm, async
  AutoComplete with loading/empty states, Upload progress/retry/`maxCount`, Timeline
  modes + reverse, Slider marks + `onChangeEnd` + adjustable VoiceOver, InputNumber
  editable entry/step/unit, TreeSelect loading/disabled/empty, Breadcrumb `maxItems`
  collapse, Avatar presence dot, Statistic animated value, Table pagination, Segmented
  block/size/disabled, Radio/Checkbox group disabled, Alert closable/action/icon,
  Empty secondary action, Tag semantic colors, and more.
- **`PreviewMatrix`** — a preview scaffold laying a component's states out as rows ×
  appearance columns (light/dark, opt-in XL Dynamic Type / RTL).
- **Theme Injection demo** in the gallery (live theme picker) with `-openDemo` /
  `-injectTheme` launch arguments for screenshot automation.
- **Component gallery** in the README — 87 rendered screenshots plus animated GIF
  previews for the overlay components.

### Changed
- **Singleton → environment migration complete** — every component now reads its
  palette from `@Environment(\.theme)` instead of `Theme.shared`: view bodies (580
  reads), private/sub-directory views, enum color resolvers (now `func(_ theme:)`),
  overlay host `ViewModifier`s, and extension-method statics (via wrapper views).
  **Zero `Theme.shared` color reads remain in components.** Non-breaking and
  pixel-identical (the environment defaults to `Theme.shared`).
- `Hero`'s convenience background now defaults to a theme-aware `HeroSurface` view
  instead of a `Theme.shared` color value (source-compatible via type inference).
- Per-symbol DocC `///` documentation added to 86 component view structs.

### Performance
- `LazyVStack` row stacks in `ListView` and `DataTable` (lazy row realization).

### Fixed
- Screenshot generator renders `TextField`-based components correctly (no yellow
  placeholder) via a hosted offscreen window path.
- `record-gif` script no longer misreads a trailing ellipsis as part of `$DEVICE`.

### Internal
- `$0` local CI (`make ci` + pre-push hook) and a cost-resilient GitHub Actions
  pipeline; build-only DocC for the private repo.
- Architecture audit + execution roadmap (`docs/AUDIT.md`) — assessed at Level 4 and
  driven to **Level 5 (reference-grade)**.
- Regression test asserting `.theme(_:)` injection actually re-skins components and
  leaves `Theme.shared` untouched.

## [0.1.1] - 2026-06-25
- Early token + component foundation (pre-rename, as `GlobalUIComponents`).

## [0.1.0] - 2026-06-25
- Initial tagged release.

[0.2.0]: https://github.com/isamercan/ThemeKit/releases/tag/v0.2.0
[0.1.1]: https://github.com/isamercan/ThemeKit/releases/tag/v0.1.1
[0.1.0]: https://github.com/isamercan/ThemeKit/releases/tag/v0.1.0
