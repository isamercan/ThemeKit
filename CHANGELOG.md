# Changelog

All notable changes to **ThemeKit** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) (pre-1.0: breaking changes
bump the minor).

## [Unreleased]

The modifier-based component refactor (COMPONENT_REFACTOR_RULES R1–R7): bloated
inits collapse to `content + action`; every appearance/state axis becomes a
chainable, order-free modifier from a shared vocabulary. Rolling out
component-by-component.

### ⚠️ Breaking
- **`DividerView` init reduced to `DividerView(_ title:)`.** The optional inline
  title stays in init; the 4 appearance/state parameters moved to modifiers:
  `size:`→`.size(_:)`, `axis:`→`.axis(_:)`, `dashed:`→`.dashed(_ on:)`,
  `titleAlign:`→`.titleAlign(_:)`. Migration:
  `DividerView(dashed: true, title: "OR", titleAlign: .center)`
  → `DividerView("OR").dashed().titleAlign(.center)`;
  `DividerView(size: .small)` → `DividerView().size(.small)`;
  `DividerView(axis: .vertical)` → `DividerView().axis(.vertical)`.
- **`Timeline` init reduced to `Timeline(_ items:)`.** The 4 layout/state
  parameters moved to modifiers: `axis:`→`.axis(_:)`, `mode:`→`.mode(_:)`,
  `reverse:`→`.reversed(_ on:)`, `pending:`→`.pending(_:)`. Migration:
  `Timeline(items, axis: .horizontal, mode: .alternate, reverse: true, pending: "Awaiting…")`
  → `Timeline(items).axis(.horizontal).mode(.alternate).reversed().pending("Awaiting…")`.
  (`Timeline.Item` is unchanged.)
- **`PromoBanner` init reduced to `PromoBanner(_ title:action:)`.** The 4 other
  parameters moved to modifiers: `subtitle:`→`.subtitle(_:)`,
  `systemImage:`→`.icon(_:)`, `ctaTitle:`→`.ctaTitle(_:)` (renders only when
  paired with the init `action`), `tint:`→`.color(_:)` (renamed to the standard
  color vocabulary). Migration:
  `PromoBanner(title: "Early booking", subtitle: "Save 30%", systemImage: "sun.max.fill", ctaTitle: "Explore", tint: .dark, action: { open() })`
  → `PromoBanner("Early booking", action: { open() }).subtitle("Save 30%").icon("sun.max.fill").ctaTitle("Explore").color(.dark)`.
- **`FloatingActionButton` init reduced to
  `FloatingActionButton(systemImage:actions:action:)`.** The content glyph, the
  speed-dial `actions:` data array and the primary `action:` (no-speed-dial mode)
  stay in init; the 3 appearance params moved to modifiers:
  `shape:`→`.shape(_:)`, `color:`→`.color(_:)`, `badge:`→`.badge(_:)`. Migration:
  `FloatingActionButton(systemImage: "bell.fill", shape: .square, color: .error, badge: 3, action: { open() })`
  → `FloatingActionButton(systemImage: "bell.fill", action: { open() }).shape(.square).color(.error).badge(3)`.
  (`FABAction` is unchanged.)
- **`Callout` init reduced to `Callout(_ text:)`.** The 6 other parameters moved
  to modifiers: `type:`→`.variant(_:)`, `style:`→`.calloutStyle(_:)` (renamed to
  avoid the generic `style` clash + match `CalloutStyle`),
  `showIcon:`→`.showsIcon(_ on:)`, `actionTitle:`/`onAction:`→
  `.action(_ title:onAction:)` (grouped), `onClose:`→`.onClose(_:)`. Migration:
  `Callout("Saved", type: .success, style: .soft, actionTitle: "Undo", onAction: { undo() })`
  → `Callout("Saved").variant(.success).calloutStyle(.soft).action("Undo") { undo() }`.
- **`OTPInput` init reduced to `OTPInput(code:onComplete:)`.** The 6 other
  parameters moved to modifiers: `digitCount:`→`.digitCount(_:)`,
  `isSecure:`→`.secure(_ on:)`, `errorText:`→`.errorText(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, and `resendInterval:`/`onResend:`→
  `.resend(interval:onResend:)` (grouped). Migration:
  `OTPInput(code: $code, digitCount: 6, isSecure: true, onComplete: { verify($0) }, resendInterval: 30, onResend: { resend() })`
  → `OTPInput(code: $code) { verify($0) }.digitCount(6).secure().resend(interval: 30) { resend() }`.
- **`FileInput` init reduced to `FileInput(_ label:onPick:)`.** The 5 other
  parameters moved to modifiers: `fileName:`→`.fileName(_:)` (the bound display
  value), `buttonTitle:`→`.buttonTitle(_:)`, `placeholder:`→`.placeholder(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, `onClear:`→`.onClear(_:)`. Migration:
  `FileInput(label: "Passport", fileName: name, onPick: { pick() }, onClear: { clear() })`
  → `FileInput("Passport") { pick() }.fileName(name).onClear { clear() }`.
- **`AlertToast` init reduced to `AlertToast(_ title:)`.** The 6 other
  parameters moved to modifiers: `message:`→`.message(_:)`,
  `type:`→`.variant(_:)`, `systemImage:`→`.icon(_:)`,
  `isLoading:`→`.loading(_ on:)`, `action:`→`.action(_:)`,
  `onClose:`→`.onClose(_:)`. Migration:
  `AlertToast("Saved", type: .success, onClose: { })`
  → `AlertToast("Saved").variant(.success).onClose { }`.
- **`Badge` init reduced to `Badge(_ text:action:)`.** The 4 remaining
  appearance params moved to modifiers: `style:`→`.badgeStyle(_:)` (renamed to
  avoid the generic `style` clash + match `BadgeStyle`),
  `variant:`→`.variant(_:)`, `size:`→`.size(_:)`,
  `leadingSystemImage:`→`.icon(_:)`. The pre-existing modifiers
  (`.badgeShape/.trailingIcon/.badgeColor/.gradient/.highlighted`) were rerouted
  through the shared `copy(_:)` helper (R2). Migration:
  `Badge("Sold out", style: .error, variant: .solid, leadingSystemImage: "xmark")`
  → `Badge("Sold out").badgeStyle(.error).variant(.solid).icon("xmark")`.
- **`Avatar` init reduced to `Avatar(_ content:)`.** Both inits (size-tier and
  numeric `dimension:`) removed. The config params moved to modifiers:
  `size:`→`.size(_:)`, `dimension:`→`.dimension(_:)`,
  `background:`→`.fillColor(_:)` (renamed to avoid clashing with SwiftUI's
  `.background`), `shape:`→`.shape(_:)`,
  `presence:`/`presencePulse:`→`.presence(_ kind:pulse:)` (grouped). Migration:
  `Avatar(.initials("AB"), size: .lg, background: .dark, shape: .square)`
  → `Avatar(.initials("AB")).size(.lg).fillColor(.dark).shape(.square)`.
  (`AvatarGroup` is unchanged.)
- **`ThemeButton` init reduced to `ThemeButton(_ title:action:)`.** All
  appearance/state parameters moved to modifiers:
  `color:` → `.color(_:)`, `variant:` → `.variant(_:)`, `size:` → `.size(_:)`,
  `shape:` → `.shape(_:)`, `block:` → `.fullWidth(_:)`,
  `isLoading: Binding<Bool>` → `.loading(_ on:)`,
  `systemImage:`/`iconPosition:` → `.icon(leading:trailing:)`,
  `accessibilityID:` → `.a11yID(_:)`, and
  `isEnabled: Binding<Bool>` → native `.disabled(_:)` (R3). The
  `ButtonIconPosition` enum is removed (encode position via `.icon`'s
  `leading:`/`trailing:` slots). Migration:
  `ThemeButton("Save", color: .accent, variant: .soft, block: true) { save() }`
  → `ThemeButton("Save") { save() }.color(.accent).variant(.soft).fullWidth()`.
- **`ListRow` init reduced to `ListRow(_ title:action:)`.** The 12 other
  parameters moved to modifiers: `subtitle:`→`.subtitle(_:)`,
  `number:`→`.number(_:)`, `size:`→`.size(_:)`,
  `leadingSystemImage:`→`.icon(_:)`, `leadingImageURL:`→`.leadingImage(_:)`,
  `leadingSelection:`→`.leadingSelection(_:)`, `alertCount:`→`.alertCount(_:)`,
  `badge:`→`.badge(_:)`, `meta:`→`.meta(_:)`, `infos:`→`.infos(_:)`,
  `isSelected:`→`.selected(_:)`, `multilineTitle:`→`.multilineTitle(_:)`,
  `infoAction:`→`.onInfo(_:)`, `trailing:`→`.trailing(_:)`.
- **`DateField` init reduced to `DateField(_ label:date:)`.** The 8 other
  parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `range:`→`.range(_:)`, `style:`→`.style(_:)`, `locale:`→`.locale(_:)`,
  `components:`→`.components(_:)`, `infoMessages:`→`.infoMessages(_:)`,
  `allowClear:`→`.clearable(_ on:)`, `leadingSystemImage:`→`.icon(_:)`.
  (`accessibilityID:`→`.a11yID(_:)` and native `.disabled(_:)` already applied.)
  Migration:
  `DateField(label: "Check-in", date: $d, style: .long, allowClear: true, leadingSystemImage: "calendar")`
  → `DateField("Check-in", date: $d).style(.long).clearable().icon("calendar")`.
- **`TreeSelect` init reduced to `TreeSelect(_ label:nodes:selection:initiallyExpanded:)`.**
  The 5 config parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `cascade:`→`.cascade(_ on:)`, `searchable:`→`.searchable(_ on:)`,
  `isLoading:`→`.loading(_ on:)`, `isNodeEnabled:`→`.nodeEnabled(_:)`.
  (`nodes`/`selection`/`initiallyExpanded` stay in init — required data, binding,
  and `@State` seed.) Migration:
  `TreeSelect(label: "Cities", nodes: tree, selection: $set, cascade: true, searchable: true)`
  → `TreeSelect("Cities", nodes: tree, selection: $set).cascade().searchable()`.
- **`RadialProgress` init reduced to `RadialProgress(_ value:)`.** The 7
  appearance parameters moved to modifiers: `size:`→`.size(_:)`,
  `lineWidth:`→`.lineWidth(_:)`, `showLabel:`→`.showsLabel(_ on:)`,
  `status:`→`.status(_:)`, `dashboard:`→`.dashboard(_ on:)`,
  `tint:`→`.ringColor(_:)` (renamed to avoid clashing with SwiftUI's `.tint`),
  `accessibilityLabel:`→`.a11yLabel(_:)` (renamed to avoid clashing with
  SwiftUI's `.accessibilityLabel`). Migration:
  `RadialProgress(value: 0.7, size: 80, lineWidth: 8, dashboard: true)`
  → `RadialProgress(0.7).size(80).lineWidth(8).dashboard()`.
- **`InputNumber` init reduced to `InputNumber(_ label:value:range:)`.** The 5
  remaining init parameters moved to modifiers: `step:`→`.step(_:)`,
  `unit:`→`.unit(_:)`, `hint:`→`.hint(_:)`, `errorText:`→`.errorText(_:)`,
  `large:`→`.large(_ on:)`. (`.editable/.hasInfo/.onValueChange/.a11yID` were
  already modifiers; they now route through the shared copy-on-write helper.)
  Migration:
  `InputNumber(label: "Max price", value: $n, range: 0...10000, step: 50, unit: "$")`
  → `InputNumber("Max price", value: $n, range: 0...10000).step(50).unit("$")`.
- **`RadioButton` init reduced to `RadioButton(_ label:isSelected:infoMessages:)`.**
  The 5 appearance parameters moved to modifiers: `type:`→`.type(_:)`,
  `style:`→`.radioStyle(_:)`, `padding:`→`.gap(_:)` (renamed to avoid clashing
  with SwiftUI's `.padding`; it's the radio↔label gap),
  `backgroundColor:`→`.fillColor(_:)` (renamed to avoid clashing with SwiftUI's
  `.background`), `verticalAlignment:`→`.alignment(_:)`. (`label`/`isSelected`/
  `infoMessages` stay in init — content, binding, and required validation data;
  size already native `.controlSize(_:)`, `disabled` already native, and
  `.a11yID(_:)` already a modifier.) The `tag:`-based convenience init dropped its
  `style:`/`padding:`/`backgroundColor:` parameters too. Migration:
  `RadioButton("Remember me", isSelected: $on, type: .check, style: .inner, padding: .medium)`
  → `RadioButton("Remember me", isSelected: $on).type(.check).radioStyle(.inner).gap(.medium)`.
- **`Checkbox` init reduced to `Checkbox(_ label:isChecked:infoMessages:)`.** The
  4 appearance parameters moved to modifiers: `customSize:`→`.customSize(_:)`,
  `type:`→`.type(_:)`, `isIndeterminate:`→`.indeterminate(_ on:)`,
  `alignment:`→`.alignment(_:)`. (`label`/`isChecked`/`infoMessages` stay in init —
  content, binding, and required validation data; size already native
  `.controlSize(_:)`, `disabled` already native, and `.a11yID(_:)` already a
  modifier — now rerouted through the shared `copy(_:)` helper.) Migration:
  `Checkbox("Accept", isChecked: $on, type: .inner, isIndeterminate: mixed)`
  → `Checkbox("Accept", isChecked: $on).type(.inner).indeterminate(mixed)`.
- **`MultiLineTextInput` init reduced to `MultiLineTextInput(_ label:text:)`.** The
  5 config parameters moved to modifiers: `placeholder:`→`.placeholder(_:)`,
  `characterLimit:`→`.characterLimit(_:)`, `errorText:`→`.errorText(_:)`,
  `infoMessages:`→`.infoMessages(_:)`, `minHeight:`→`.minHeight(_:)`.
  (`label`/`text` stay in init — content and binding; `disabled` already native,
  and `.a11yID(_:)` already a modifier.) Migration:
  `MultiLineTextInput("Notes", text: $t, placeholder: "…", characterLimit: 200)`
  → `MultiLineTextInput("Notes", text: $t).placeholder("…").characterLimit(200)`.
- **`ProgressIndicator` init reduced to `ProgressIndicator(variant:current:total:)`.**
  The 4 appearance parameters moved to modifiers: `size:`→`.size(_:)`,
  `videoProgress:`→`.videoProgress(_:)`, `stepText:`→`.stepText(_:)`,
  `cornerRadius:`→`.cornerRadius(_ on:)`. (`variant`/`current`/`total` stay in init —
  the core kind plus required data.) Migration:
  `ProgressIndicator(variant: .video, current: 3, total: 5, videoProgress: 0.5, stepText: .slash)`
  → `ProgressIndicator(variant: .video, current: 3, total: 5).videoProgress(0.5).stepText(.slash)`.
- **`Stat` init reduced to `Stat(title:value:)`** (both the `String` and `Int`
  value overloads). The 6 other parameters moved to modifiers:
  `prefix:`→`.prefix(_:)`, `suffix:`→`.suffix(_:)`, `isLoading:`→`.loading(_ on:)`,
  `description:`→`.description(_:)`, `systemImage:`→`.icon(_:)`,
  `trend:`→`.trend(_:)`. (`.statStyle(_:)` layout is unchanged.) Migration:
  `Stat(title: "Bookings", value: "1,284", systemImage: "ticket", trend: .up("+12%"))`
  → `Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))`.
- **`EmptyState` inits reduced to the media + `title`.** The three inits now key
  on the media variant — `EmptyState(_ title:)` (SF Symbol), `EmptyState(image:title:)`,
  `EmptyState(animatedURL:title:)` — and the other parameters moved to modifiers:
  `systemImage:`→`.icon(_:)`, `message:`→`.message(_:)`,
  `imageMaxHeight:`→`.imageMaxHeight(_:)`, `iconForeground:`→`.iconForeground(_:)`,
  `iconBackground:`→`.iconBackground(_:)`, `iconCircleSize:`→`.iconCircleSize(_:)`,
  `buttonTitle:`/`action:`→`.primaryAction(_ title:action:)`,
  `secondaryTitle:`/`onSecondary:`→`.secondaryAction(_ title:action:)`. Migration:
  `EmptyState(systemImage: "tray", title: "Empty", message: "…", buttonTitle: "Retry", action: { })`
  → `EmptyState("Empty").icon("tray").message("…").primaryAction("Retry") { }`.

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
