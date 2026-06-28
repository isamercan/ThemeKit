# Architecture audit & roadmap

A maturity assessment of ThemeKit as a distributable SwiftUI component library, plus
the prioritized plan to take it to reference-grade. Findings are evidence-backed
(counts as of the 2026-06 audit). Execution status is tracked inline.

**Type:** A — distributable SPM library (`ThemeKit` + `ThemeKitLottie`).
**Swift / min target:** 6.2 · iOS 17 / macOS 14. **Deps:** lottie-ios (opt-in product), swift-snapshot-testing (tests), swift-docc-plugin.
**Maturity:** **Level 4 (Production library)** → target **Level 5 (Reference-grade)**.

## Snapshot

A production-grade design system, not a folder of views: 105 components
(26 atoms / 35 molecules / 44 organisms), JSON token generator + light/dark themes,
6 `ButtonStyle`s + 96 `@ViewBuilder` slots, 108 `#Preview`s, 196 tests + 11 snapshot
suites, DocC + CI + SwiftLint/Format + String Catalog (EN+TR) + RTL + API-stability
tooling. The one structural lever toward L5 was theming coupled to the `Theme.shared`
singleton; the rest is polish and discipline.

## Findings by category

| Category | Status | Evidence |
|---|---|---|
| A. Structure | Solid | tokens→atoms→molecules→organisms, 1 file/component, 2 products (Lottie isolated), 781 public (deliberate) |
| B. Tokens | Solid | JSON + generator semantic tokens, light+dark, Dynamic Type, only 6 hardcoded colors |
| C. Theming | **Partial → improving** | runtime theming works but via the `Theme.shared` singleton (690 reads); `\.theme` injection now added (see P0) |
| D. API design | Solid | ButtonStyle/BadgeStyle patterns, slot composition; no VM in leaf components (the 7 ObservableObjects are presenters in organisms) |
| E. State & data flow | Solid | value-driven (`let`+`@Binding`), no business logic in leaves |
| F. Accessibility | Solid | VoiceOver labels/traits, Slider adjustable action, Reduce Motion (micro-motion), RTL, a11y semantics tests |
| G. Previews & gallery | Solid | 108 `#Preview`, Demo gallery + README still/GIF gallery |
| H. Testing | Solid | 196 tests, 11 snapshot suites, render-smoke, a11y |
| I. Documentation | Partial | DocC (6 articles) + README + wiki; per-symbol `///` doc comments incomplete (104 component types use `//` file headers, not DocC `///`) |
| J. Versioning / API stability | Solid | `check-api.sh` + allowlist + `docs/API-STABILITY.md` + CI api-breakage job, `@available` |
| K. Performance | Partial → improving | 11 AnyView (justified, see below), lazy row stacks now in ListView/DataTable (P1) |
| L. Tooling / CI | Solid | SwiftLint+Format+CI+api-breakage; `$0` local CI (`make ci`) covers the Actions-billing outage |
| M. Localization / RTL | Solid | String Catalog (EN+TR), `LocalizedStringKey`, leading/trailing + RTL doc |

## Action plan & execution status

### P0 — structural lever
- [x] **`\.theme` environment injection** (PR #57) — `EnvironmentValues.theme` defaulting to `Theme.shared` (crash-proof, backward compatible) + `.theme(_:)` override; pilot `Card`/`Tag` migrated; +2 tests.
- [ ] **Full singleton → environment rollout** — *staged, deliberate.* The remaining ~690 reads migrate incrementally; the singleton is a documented design (`ThemeKit.swift`), so this is opt-in cleanup, not a forced mass-rewrite. Per-component caveat: only view bodies/instance members can read `\.theme`; `ButtonStyle` inner-views and the `BadgeStyle`/`SemanticColor` enums resolve statically and would need their own theme parameter to be fully re-themeable in a subtree.

### P1 — high leverage
- [x] **Lazy row stacks** (PR #58) — `LazyVStack` for `ListView`/`DataTable` rows.
- [x] **Public surface review** — *assessed, no change.* The utility publics (`Haptics`, impression tracking, `Debounce`, `String(themeKit:)`, color helpers) are deliberate API, not accidental leaks; blind pre-1.0 demotions would be breaking churn and are already guarded by `check-api.sh`. Revisit symbol-by-symbol with intent before 1.0.
- [x] **Style-protocol extraction** (PR #60) — `CardStyle` protocol + `.cardStyle(_:)` environment modifier (the `ButtonStyle` shape): `Card`'s surface is now supplied by a style, so it can be reskinned (`.outlined`, or a custom `CardStyle`) without editing the component. The default style reproduces the original look exactly (no regression). Pattern established; `Stat`/`Select` are the mechanical follow-up.

### P2 — polish
- [x] **AnyView review** — *assessed, no change.* The 11 `AnyView`s sit in heterogeneous-content organisms (`DataTable` columns, `Accordion`/`Drawer` slots) and host/shadow plumbing — justified type-erasure, none in per-row hot paths.
- [ ] **DocC `///` doc comments** — add usage-snippet symbol docs to the 104 component types (file headers exist; DocC needs `///`). Exemplars added this pass; remainder is mechanical.
- [ ] **Preview state-matrix helper** — a shared helper so every component preview covers default/loading/disabled/error/long-text/dark systematically (knob demos already cover states interactively).

## Suggested sequence
1) `\.theme` injection (done) → 2) lazy stacks (done) → 3) style-protocol extraction → 4) DocC `///` sweep → 5) preview-matrix helper.

**Verdict:** Already L4. With the `\.theme` lever opened and the perf/polish items closed, the path to L5 is incremental cleanup, not architectural change.
