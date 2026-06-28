# Architecture audit & roadmap

A maturity assessment of ThemeKit as a distributable SwiftUI component library, plus
the prioritized plan to take it to reference-grade. Findings are evidence-backed
(counts as of the 2026-06 audit). Execution status is tracked inline.

**Type:** A — distributable SPM library (`ThemeKit` + `ThemeKitLottie`).
**Swift / min target:** 6.2 · iOS 17 / macOS 14. **Deps:** lottie-ios (opt-in product), swift-snapshot-testing (tests), swift-docc-plugin.
**Maturity:** **Level 5 (Reference-grade)** — reached via #57–#68 (was Level 4 at audit time).

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
| C. Theming | Solid | runtime theming + `\.theme` environment fully rolled out (#57, #66–#73): 719/736 reads honor an injected subtree theme; the 17 left are `#Preview` demo code / a doc comment / structurally-static defaults, by design |
| D. API design | Solid | ButtonStyle/BadgeStyle patterns, slot composition; no VM in leaf components (the 7 ObservableObjects are presenters in organisms) |
| E. State & data flow | Solid | value-driven (`let`+`@Binding`), no business logic in leaves |
| F. Accessibility | Solid | VoiceOver labels/traits, Slider adjustable action, Reduce Motion (micro-motion), RTL, a11y semantics tests |
| G. Previews & gallery | Solid | 108 `#Preview`, Demo gallery + README still/GIF gallery |
| H. Testing | Solid | 196 tests, 11 snapshot suites, render-smoke, a11y |
| I. Documentation | Solid | DocC (6 articles) + README + wiki; per-symbol `///` doc comments now on all component `View` structs (#64) — modifier/enum-fronted components documented at their entry point |
| J. Versioning / API stability | Solid | `check-api.sh` + allowlist + `docs/API-STABILITY.md` + CI api-breakage job, `@available` |
| K. Performance | Partial → improving | 11 AnyView (justified, see below), lazy row stacks now in ListView/DataTable (P1) |
| L. Tooling / CI | Solid | SwiftLint+Format+CI+api-breakage; `$0` local CI (`make ci`) covers the Actions-billing outage |
| M. Localization / RTL | Solid | String Catalog (EN+TR), `LocalizedStringKey`, leading/trailing + RTL doc |

## Action plan & execution status

### P0 — structural lever
- [x] **`\.theme` environment injection** (PR #57) — `EnvironmentValues.theme` defaulting to `Theme.shared` (crash-proof, backward compatible) + `.theme(_:)` override; pilot `Card`/`Tag` migrated; +2 tests.
- [x] **Full singleton → environment rollout** (PRs #66–#73) — done. **719 of 736 reads** now resolve `\.theme` from the environment, so an injected `.theme(_:)` re-skins any subtree.
  - **View bodies** (#66–#68): 580 reads across Atoms (66) · Molecules (333) · Organisms (181).
  - **Private / sub-directory Views the first matcher skipped** (#70): 33 reads (`private struct`s + `Buttons/`).
  - **Enum color resolvers** (#71): 78 reads — `BadgeStyle`/`InfoBannerType`/`StatTrend`/… converted from `var x: Color` to `func x(_ theme:)`, with each owning View passing its `@Environment(\.theme)` (internal members, no public API change).
  - **Overlay host `ViewModifier`s** (#72): 21 reads — Feedback/Tour/Popconfirm/Dialog.
  - **Extension-method statics** (#73): 7 reads — inline content extracted into small `@Environment`-reading wrapper Views (CountBadge/Indicator/ButtonDock/RollingNumber/BorderBeam).
  - Every step is compiler-guarded and pixel-verified (regenerated screenshots byte-identical; default render unchanged because `\.theme` defaults to `Theme.shared`).
  - **Irreducible floor — 17 reads, by design:** `#Preview` demo code (no injected theme; the singleton is correct there), one doc-comment mention, DataTable's nested `Column` (a non-View value type), and Hero's `Background == Color` convenience default (the generic constrains the default to a `Color` *value*, which can't read the environment).

### P1 — high leverage
- [x] **Lazy row stacks** (PR #58) — `LazyVStack` for `ListView`/`DataTable` rows.
- [x] **Public surface review** — *assessed, no change.* The utility publics (`Haptics`, impression tracking, `Debounce`, `String(themeKit:)`, color helpers) are deliberate API, not accidental leaks; blind pre-1.0 demotions would be breaking churn and are already guarded by `check-api.sh`. Revisit symbol-by-symbol with intent before 1.0.
- [x] **Style-protocol extraction** (PRs #60–#62) — the `ButtonStyle`-shaped hook applied to **Card** (`.cardStyle`, surface), **Stat** (`.statStyle`, layout) and **Select** (`.selectStyle`, field chrome): appearance is supplied by a style, so each can be reskinned (e.g. `.outlined` / `.centered` / `.filled`, or a custom style) without editing the component. Every default reproduces the original look exactly (pixel-verified, no regression). Other components extend the same pattern as needed.

### P2 — polish
- [x] **AnyView review** — *assessed, no change.* The 11 `AnyView`s sit in heterogeneous-content organisms (`DataTable` columns, `Accordion`/`Drawer` slots) and host/shadow plumbing — justified type-erasure, none in per-row hot paths.
- [x] **DocC `///` doc comments** (PR #64) — each component's file-header description was relocated to a `///` symbol doc on its primary `View` struct (DocC ignores `//` header prose); **86 structs** now documented, the rest already documented at their modifier/enum entry point. Builds with no symbol warnings; API surface unchanged.
- [x] **Preview state-matrix helper** (PR #65) — `PreviewMatrix` lays a component's labeled states out as rows and renders each across appearance columns (light + dark, opt-in XL Dynamic-Type / RTL), so one `#Preview` covers the state × appearance matrix. Adopted as `#Preview("States")` exemplars in Tag/Stat/Avatar; other components opt in the same way.

## Suggested sequence — all delivered
1) `\.theme` injection (#57) → 2) lazy stacks (#58) → 3) style-protocol extraction (#60–#62) → 4) DocC `///` sweep (#64) → 5) preview-matrix helper (#65) → 6) full view-body `\.theme` rollout (#66–#68). ✅

**Verdict:** **Reference-grade (L5).** Every prioritized item is closed: the theming lever is not just opened but rolled out across all 580 view-body reads, the perf/polish items are done, and docs/previews are systematized. The one remaining thread — parameterizing the ~156 static (enum/init/presenter) theme reads so they too honor an injected subtree theme — is optional hardening, not a gap in the architecture.
