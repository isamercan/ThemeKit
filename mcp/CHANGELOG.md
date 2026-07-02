# Changelog — @isamercan/themekit-mcp

All notable changes to the **ThemeKit MCP server** are documented here. This is the
npm package under [`mcp/`](.); the ThemeKit Swift library has its own
[CHANGELOG](../CHANGELOG.md). The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.8.0] - 2026-07-02

### Added — `design_to_code` fidelity pass

The Figma → SwiftUI pipeline now *emits* the visual data it previously only
reported, so the generated screen looks like the design:

- **Container styling is emitted** — a raw layout stack now carries its
  token-snapped `.padding(Theme.SpacingKey…)` (uniform and horizontal/vertical),
  `.background(theme.background(…))`, `.cornerRadius(Theme.RadiusKey…)` and
  `.themeShadow(.soft/.elevated)` (from the node's `DROP_SHADOW`, by blur radius).
  ThemeKit components stay theme-driven — only raw SwiftUI gets explicit styling.
- **Typography snaps to `TextStyle`** — a text node's `fontSize`/`fontWeight`
  resolves to the nearest token (same weight, ≤ 2 pt) and emits
  `.textStyle(.bodyBase400 …)`; no match is an honest *needs review*.
- **Real alignment** — `counterAxisAlignItems` (and Figma's MIN default) maps to
  `VStack(alignment: .leading)` / `HStack(alignment: .top)` etc.;
  `primaryAxisAlignItems: SPACE_BETWEEN` inserts `Spacer()` between children.
- **Absolute layouts stop collapsing into VStacks** — a `GROUP` /
  `layoutMode: NONE` frame infers its axis from the child bounding boxes
  (non-overlapping top-to-bottom → `VStack`, left-to-right → `HStack`, children
  re-ordered visually) and genuinely overlapping children become a
  `ZStack(alignment: .topLeading)` flagged for review.
- **Icons and images become assets** — vector nodes (and icon frames drawn
  entirely from vectors) emit `Image("slug").accessibilityLabel(…)`, are listed
  in the report, and the tool fetches their **PNG export URLs** from the Figma
  images API (valid ~14 days) into a new *Asset export URLs* section.
- **Decorative shapes render** — a `RECTANGLE`/`ELLIPSE` with a token-matched
  fill becomes `RoundedRectangle(cornerRadius: …).fill(theme…)` / `Circle()`
  instead of an unmapped comment.
- **Gradient fills are flagged** — `GRADIENT_*` fills land in *needs review*
  instead of silently vanishing.
- **13 new mapping rules** — Tag, SearchBar, Rating, Spinner, ProgressBar,
  Skeleton, EmptyState, InfoBanner, AlertToast, OTPInput, QuantityStepper,
  Pagination, Accordion (every arg label verified against the catalog by a test).

### Changed

- **Frames only become `Card` when they look like a surface** (fill, stroke or
  shadow). A bare autolayout frame is now a plain layout stack — wrapping every
  frame in a Card was the single biggest source of "doesn't match the design"
  output.
- Mapping rule `namePattern`s now match **case-insensitively**
  (`button/primary` ≡ `Button/Primary`).
- `usage` snippets keep labels on labelled `Binding` params
  (`SearchBar(text: $text)`, not `SearchBar($text)`).

### Fixed

- **`search_components` crashed** on intents hitting a stale synonym (`toast`,
  `tooltip`, `badge`) — ghost names removed, and synonym candidates are now
  validated against the generated catalog so drift can never crash the tool.
- **`get_migration_guide` silently dropped the oldest CHANGELOG section** — the
  section regex used `\Z`, which does not exist in JavaScript; replaced with a
  true end-of-string anchor (migrating *from* 0.1.0 works now).
- **npm installs**: `get_migration_guide` reads the ThemeKit CHANGELOG bundled
  into `data/THEMEKIT-CHANGELOG.md` by `build:data`, and `render_preview`
  falls back to fetching the gallery render from GitHub when `Screenshots/`
  isn't on disk — both tools previously only worked in-repo.

## [2.7.0] - 2026-06-30

### Changed
- **Catalog refreshed to 119 components** — regenerated `data/themekit.json` from the
  symbol graph to include the new **`TimeField`** (Molecule) and **`Sidebar`**
  (Organism) with their full init params + modifiers, so `get_component_api`,
  `list_components`, `search_components` and `design_to_code` know about them.

## [2.6.0] - 2026-06-30

### Added
- **`design_to_code` tool** — a more readable, design-tool-agnostic name for the
  Figma→SwiftUI generator. **`figma_to_swiftui` is kept as a backward-compatible
  alias** (identical behavior), so existing prompts and automations keep working.
- **`figma_to_swiftui` `expandInstances` option.** When `true`, an unmapped Figma
  component `INSTANCE` that has children is walked into (like a FRAME/GROUP) instead
  of being emitted as an opaque `// ⚠️ unmapped` leaf — so a screen built from nested
  instances (forms, headers, nav bars) actually converts. Default `false` preserves
  the previous opaque-leaf behavior. Recursion is capped by `instanceMaxDepth`
  (default 8) to guard against runaway output.
- **Auto-validation.** `design_to_code` now runs `validate_code` on its own generated
  output and appends the PASS/FAIL verdict under an `## Auto-validation` section.
- **More `figma-mapping.json` rules** — common control instances now map out of the
  box: `Checkbox` → `Checkbox`, `Radio`/`RadioButton` → `RadioButton`,
  `Toggle`/`Switch` → `ThemeToggle`, and `Divider`/`Divider Container` → `DividerView`.
- **Direct Figma `url` input** — pass the design link as `url` and the tool parses the
  `fileKey` + `nodeId` itself (handles both `/design/` and legacy `/file/` links and
  normalises the URL's dash `node-id` → colon). `fileKey` + `nodeId` stay accepted.

### Fixed
- **Placeholder noise** — design-system scaffolding text (`scribble`, `Action Button`,
  `Input Label`, …) is no longer emitted as real SwiftUI `Text`.
- **Spacing token → `SpacingKey` case emission.** `sp-4xl` now emits
  `Theme.SpacingKey.xl4.value` (was the non-compiling `.4xl`) and `spacing-none`
  emits `.none` (was `.spacing-none`); other keys unchanged.

## [2.5.0] - 2026-06-30

### Added
- **`figma_to_swiftui` now accepts a Figma `url` directly.** Pass the design link as
  `url` and the tool parses the `fileKey` + `nodeId` itself (handles both `/design/`
  and legacy `/file/` links and normalises the URL's dash `node-id` → colon, e.g.
  `25795-9030` → `25795:9030`). `fileKey` + `nodeId` are still accepted explicitly
  and are now optional when `url` is given.

## [2.4.1] - 2026-06-30

Fixes stale catalog data after the library's modifier-based refactor.

### Fixed
- **Regenerated `data/themekit.json`** from the post-refactor symbol graph (117
  components, 164 modifiers). The previous data still described the old
  initializer-heavy APIs (e.g. `ThemeButton(color:variant:size:…)`,
  `Badge(style:…)`) that the refactor removed — the MCP would have generated code
  against deleted initializers.
- **Figma codegen no longer emits a removed `style:` init arg.** A new mapping
  option `styleModifier` (e.g. `"badgeStyle"`) routes the style axis to the
  chainable modifier (`Badge("Sale").badgeStyle(.error)`), matching the refactored
  API; the old `style:` init path is kept only when the component still declares it.

## [2.4.0] - 2026-06-30

Accessibility moves to the design source: `figma_to_swiftui` now runs a WCAG 2.1
audit on the Figma node tree itself — using the design's real colors, font sizes and
dimensions, before any code is generated.

### Added
- **Figma-layer accessibility audit** (`src/figma/a11yAudit.ts`) — walks the node
  tree carrying the nearest opaque surface as background context and grades:
  - **1.4.3 Contrast (Minimum)** — text fill vs. the resolved surface, with the
    large-text threshold (≥18pt, or ≥14pt bold → 3:1; else 4.5:1).
  - **1.4.4 / legibility** — font sizes below an 11pt floor.
  - **2.5.5 Target Size** — interactive nodes smaller than 44×44pt (via
    `absoluteBoundingBox`).
  - **4.1.2 Name, Role, Value** — interactive elements with no visible text.
  - **1.1.1 Non-text Content** — icons/images with no text alternative.
- **`figma_to_swiftui(…, a11yOnly: true)`** — returns just the accessibility audit
  (no code, no mapping). The audit is also appended to the normal mapping report.

### Changed
- `FigmaNode` gained `absoluteBoundingBox`, `opacity` and `visible`; the mapping
  `Report` gained an `a11y: A11yFinding[]` field, surfaced by `formatReport`.

### Internal
- New fixture `test/fixtures/figma-a11y.json` and 6 audit tests (25 total).

## [2.3.0] - 2026-06-30

A correctness + accessibility release: three new tools, a modifier/state-aware
Figma codegen path, and a config-driven migration layer. The catalog/token data is
still built from the single source of truth (DocC symbol graph + theme JSON), so APIs
can't drift.

### Added
- **`diff_theme(a, b)`** — compares two theme presets channel by channel (primary /
  secondary / accent / base) with the per-channel **CIE76 ΔE** and a same/close/different
  verdict.
- **`compose_screen(components, title?, layout?, spacing?)`** — builds a token-bound
  SwiftUI screen from an **ordered, catalog-verified** component list (unknown names are
  flagged, never silently dropped); `vstack` / `scroll` / `card` layouts.
- **`a11y_audit(swift)`** — accessibility audit: interactive controls missing
  `.a11yID(_:)`, images/icons without an accessibility label, hardcoded colors, plus a
  WCAG contrast hint between detected hex pairs.
- **`get_design_tokens(category: "contrast")`** — a WCAG 2.1 text-on-surface contrast
  report (AA / AA-Large / AAA grading) across the key surfaces.

### Changed
- **`figma_to_swiftui` is now modifier/state-aware** — variant properties and node
  names map to chainable modifiers: `State=Disabled` → `.disabled(true)`,
  `Size=Large` → `.controlSize(.large)`; selected/active states are flagged for a
  `Binding` rather than invented. Mapping rules (`figma-mapping.json`) gained an
  optional `modifiers` array (`emit` + `whenName` / `whenProp`).
- **Unmapped/raw `Text` now snaps its fill to a theme token color** via the token
  accessor instead of being emitted bare.
- **`validate_code` is stronger** — anti-pattern checks are now string/comment-aware
  (no false positives from literals or comments), it detects **unknown / hallucinated
  components** against the real catalog (with a "did you mean" suggestion), and it
  checks multi-line **brace / paren / bracket balance**.
- **`migrate_snippet` is config-driven** — rewrite rules now live in
  [`migrate-rules.json`](./migrate-rules.json) (regex `find` / `replace` / `note`)
  instead of being hardcoded; edit/extend without touching the server.
- The server **version is read from `package.json`** (single source of truth) instead
  of a hardcoded string.

### Fixed
- Removed dead code in `tokenAccessor` (an unused variable and two no-op `replace`s).

### Internal
- New `node:test` suites for WCAG contrast helpers, the modifier-aware Figma codegen
  (new `figma-states.json` fixture), and the config-driven migrate / mapping rules
  (19 tests total).
- **CI now builds & tests the MCP** on every push/PR — a dedicated Linux Node/TS job
  in `.github/workflows/ci.yml` runs `npm ci && npm test`.

## [2.2.0]

- Prior published baseline: 20 tools (read context, generation, themes), Figma →
  SwiftUI codegen with token snapping, and the DocC-symbol-graph data pipeline.
