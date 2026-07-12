# ADR-0006 — Per-subtree theme resolution: making `.theme(_:)` actually re-skin

- **Status:** **Accepted** (2026-07-13)
- **Date:** 2026-07-13
- **Deciders:** ThemeKit architecture
- **Context source:** Architecture-remediation review, item **R1 (HIGH) / P0-1** — "`SemanticColor` and the token-value accessors read `Theme.shared` directly, silently defeating the advertised per-subtree `.theme(_:)` override."
- **Rollout note:** Additive and source-compatible. The `Theme.shared`-backed accessors stay working as **`@available(*, deprecated,…)` deprecate-forward** shims with byte-identical behavior, so every existing call site compiles (with a warning) and any app that never calls `.theme(_:)` behaves exactly as today. The one genuinely irreducible case (non-View builders with no theme in scope) is documented as a bounded limit, mirroring ADR-0003's non-View analysis. No public type is removed; two additive surfaces (`SemanticColor.Resolved`, `Theme.resolve(_:)`) are introduced.
- **Precedent mirrored:** `AlertToast` already threads a theme through an enum color helper — `func background(_ theme: Theme) -> Color` / `func foreground(_ theme: Theme) -> Color` (`Sources/ThemeKit/Components/Organisms/AlertToast.swift:16,29`). `SeatPalette.colors(for:theme:)` (`SeatMapModels.swift:114`) does the same for a non-View helper. This ADR generalizes that existing, working pattern to the shared token layer. ADR-0003 supplies the non-View / inherent-limit template.

## Context

`ThemeContext.swift:40-58` advertises per-subtree re-theming in its own doc comment:

> "The active `Theme`. Defaults to `Theme.shared`; override per-subtree with `.theme(_:)`. Components read this instead of touching the singleton directly, so they can be re-themed in isolation (different brand in a subtree, a fixed theme in a preview/snapshot)…"

That promise is **half-true today**, and the half that fails is the half the review flagged.

**What actually works.** A component that reads `@Environment(\.theme) private var theme` and calls the **instance** accessors — `theme.text(.textPrimary)`, `theme.background(.bgBase)`, `theme.border(.borderPrimary)`, `theme.foreground(.fgHero)` — resolves against whatever `Theme` the environment holds. Inside a `.theme(brandB)` subtree, `@Environment(\.theme)` returns `brandB`, so those calls are already per-subtree-correct. **A precise correction to the review wording:** `theme.text(…)`/`theme.background(…)` do *not* read the singleton — they are instance methods on the environment theme. The literal `Theme.shared.text(…)`/`Theme.shared.background(…)` reads the review saw live **inside `SemanticColor.swift`**, not in component bodies.

**What silently fails.** The token accessors that carry **no theme** — they are `enum` computed properties with nowhere to read an environment — hardcode the singleton:

- `SemanticColor` — every role (`.solid .soft .accent .border .onSolid`) and every ladder step (`.bg .hover .base .active .strong .shade(_:)`) resolves from `Theme.shared` (`SemanticColor.swift:23-112`). **758 reads across 146 component files.**
- `Theme.RadiusKey.value` / `RadiusRole.value` / `SpacingKey.value` — `Theme.shared.radius/spacing` (`ThemeModel.swift:78,104,120`). **~1148 call sites.**
- `TextStyle.font` / `.lineSpacing` — `Theme.shared.textStyle(self)` (`Typography.swift:96,103`), reached by the 916 `.textStyle(_:)` modifier sites.

The consequence is a **split-brain inside a single view body**. `SeatPalette.colors(for:theme:)` is the cleanest witness — the same `switch` mixes both worlds (`SeatMapModels.swift:118-123`):

```swift
case .standard:     return (theme.background(.bgBase),  theme.border(.borderPrimary))  // env-correct
case .extraLegroom: return (SemanticColor.info.bg,      SemanticColor.info.base)        // Theme.shared — WRONG in a .theme() subtree
```

Two subtrees with different brands therefore cannot both render correct accent/semantic color: the neutral surfaces re-skin, the *accents* do not. That is exactly the isolation the doc comment sells.

**Two axes, deliberately separated by this ADR.** "Brand isolation" — the thing the promise is about — is a **color** concept: it is driven by `ThemeConfig.primaryHex / secondaryHex / accentHex / tint / dark`. Radius/spacing/typography vary by `radiusScale / spacingScale / fontScale / font` — real theme inputs, but not what anyone means by "a different brand in this subtree." This ADR fixes **color** completely and treats the metric/type scale axis as a bounded, documented limit (see D5), because fixing it costs a ~2000-site migration to isolate an axis no real two-brand screen varies.

**Why the singleton exists (the tension).** `ThemeKit.swift:10-17` states the design intent: *"components resolve tokens from the `Theme.shared` singleton (a deliberate design — no per-call environment lookups)."* The performance claim is real but narrower than it reads: the cost it avoids is the **`@Environment` read**, not the token dictionary lookup. A component reads `@Environment(\.theme)` **once per body** and reuses the local `theme` for all its token access — there is no per-token environment lookup, and there never was one for `SemanticColor` either. Threading the already-in-hand `theme` into `SemanticColor` adds **zero** environment reads to the 121-of-146 files that already hold one, and one cheap read to the remainder. The singleton's simplicity survives as the *default environment value* (`ThemeContext.swift:37`); what changes is that the token layer stops reaching **past** the environment to the global.

## The root cause is resolution *timing*, not just the singleton

The subtle part — and the part `sr-ios-dev` must internalize before migrating — is *when* `SemanticColor → Color` happens. A component can correctly read `@Environment(\.theme)` in its body and **still** leak the singleton, if it resolves the color at a moment when no environment exists. Four timing classes, in increasing difficulty:

| Class | Where resolution happens | Env reachable? | Example | Fix |
|---|---|---|---|---|
| **V — View body** | inside `body` / a Style's `makeBody` Chrome view | **yes** | 121 files; `MeterStyle.swift:90` | swap `color.X` → `theme.resolve(color).X` |
| **P — threaded helper** | an `enum`/`struct` method that already **takes** a `Theme` | **yes (as a param)** | `AlertToast` `variant.background(theme)`; `SeatPalette.colors(for:theme:)` | swap the `SemanticColor.X` reads for `theme.resolve(…).X` |
| **M — eager modifier** | a copy-on-write modifier that resolves to a stored `Color` **before** body runs | **no** | `Icon.accent(_:)` stores `color?.base` (`Icon.swift:58`) | store the `SemanticColor`, resolve in `body` |
| **N — non-View builder** | a model/scale built with no `Theme` and no View ancestor in scope | **inherently no** | `ChartColorScale(series:)` bakes `.solid` (`ChartModels.swift:88,92`) | thread a `theme:` param from the building View, **or** accept process-global (see §Non-View) |

Classes V and P are mechanical. Class M is a small per-component refactor (change an internal stored-property type; public signature unchanged). Class N is the only one with an inherent limit, and it is narrow.

## Decision

Adopt **Approach A (thread the environment theme through color-token resolution)** via an additive, deprecate-forward resolver, scoped to the **color** layer; keep the metric/type scale axis singleton-backed with a **precisely documented limit** (a bounded slice of Approach B) rather than pay a ~2000-site migration for an axis nobody isolates per subtree.

### D1 — Verdict: A for color, documented-limit for metric/type scale

Reject the pure alternatives:

- **Pure B (downgrade the promise, keep the singleton everywhere).** Rejected: it ships a library that reads `@Environment(\.theme)` in 121 files and injects `.theme(_:)` in `ThemeContext`/`ThemeKit`, then quietly ignores it for the *accent* colors those files paint — the worst outcome (the machinery exists and misleads). Honest B would require *deleting* `.theme(_:)` and every "re-themed in isolation / different brand in a subtree" claim, throwing away working per-subtree behavior (surfaces already re-skin) and every preview/snapshot that pins a theme.
- **Full A (thread the theme through color *and* metrics *and* typography).** Rejected as one step: ~2000 additional call sites (`929` SpacingKey + `98` RadiusKey + `121` RadiusRole + `916` textStyle) for an axis — corner radius / spacing / font scale — that no two-brand screen varies. Kept available as the *same idiom* for a later phase if a real need appears (D5), so this is a deferral, not a different pattern.

Approach A for color is correct because color **is** the advertised feature, its blast radius is mechanical (121 files already hold the theme), its per-call cost is nil, and it introduces no new isolation model — only a resolver that takes the theme the component already has.

### D2 — Mechanism: `SemanticColor.Resolved` + `Theme.resolve(_:)`, deprecate-forward the zero-arg accessors

A `Resolved` value binds a `SemanticColor` to a specific `Theme` and exposes the **same role vocabulary** as today, so call sites keep property syntax and only gain a `theme.` prefix. The role logic moves **once** into `Resolved`; the deprecated enum properties become thin forwards to `Theme.shared`.

```swift
public extension SemanticColor {
    /// Roles resolved against a specific Theme — honors per-subtree `.theme(_:)`.
    /// `Sendable` because `Theme` is `@unchecked Sendable` and `SemanticColor` is `Sendable`;
    /// a transient value used within a body, never stored/escaped.
    struct Resolved: Sendable {
        let color: SemanticColor
        let theme: Theme

        public var solid: Color {           // was SemanticColor.solid, now theme-parameterized
            switch color {
            case .primary: return theme.background(.bgHero)
            case .neutral: return theme.background(.bgTertiary)
            case .info:    return theme.background(.systemcolorsBgInfo)
            // … identical to today's switch, s/Theme.shared/theme/
            case .secondary, .accent: return base
            }
        }
        public var soft: Color   { /* … */ }
        public var accent: Color { /* … */ }
        public var border: Color { /* … */ }
        public var onSolid: Color { ColorContrast.content(on: solid) }   // theme-independent, unchanged

        public func shade(_ step: SemanticColor.Shade) -> Color {
            if color == .secondary || color == .accent {
                return theme.brandShade(color.rawValue, step.rawValue)
                    ?? (Theme.PaletteColorKey(rawValue: "palette.primary.\(step.rawValue)").map { theme.palette($0) } ?? .clear)
            }
            guard let key = Theme.PaletteColorKey(rawValue: "palette.\(color.rawValue).\(step.rawValue)") else { return .clear }
            return theme.palette(key)
        }
        public var bg: Color { shade(.s50) }
        public var base: Color { shade(.s500) }
        // … bgHover, borderSubtle, borderHover, hover, active, strong — all shade(_:) forwards
    }

    /// Enum-side binder — for Class-P helpers that already receive a `Theme`
    /// (mirrors `AlertToast.background(_:)` / `SeatPalette.colors(for:theme:)`).
    func resolved(in theme: Theme) -> Resolved { Resolved(color: self, theme: theme) }
}

public extension Theme {
    /// Theme-side binder — the ergonomic call in a View body: `theme.resolve(.primary).solid`.
    /// Mirrors the existing `theme.text(_:)` / `theme.background(_:)` shape.
    func resolve(_ color: SemanticColor) -> SemanticColor.Resolved { color.resolved(in: self) }
}
```

The existing public properties are **kept and deprecated**, forwarding to the singleton so behavior is byte-identical until a site migrates:

```swift
public extension SemanticColor {
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).solid")
    var solid: Color { resolved(in: .shared).solid }
    // …the same one-line deprecate-forward for soft, accent, border, onSolid, shade(_:), bg, base, hover, active, strong, …
}
```

**Naming.** `theme.resolve(_:)` mirrors `theme.text(_:)`/`theme.background(_:)` (identity in front, role behind) and is the primary call. `color.resolved(in:)` exists for Class-P helpers holding a `theme` parameter. Both return the one `Resolved` type; no duplicated logic.

**Before / after — Class P (`SeatMapModels.swift`), the split-brain witness:**

```swift
// before — split brain in one switch
case .standard:     return (theme.background(.bgBase), theme.border(.borderPrimary))
case .extraLegroom: return (SemanticColor.info.bg,     SemanticColor.info.base)      // singleton
// after — both halves read the same env theme (already a param here)
case .standard:     return (theme.background(.bgBase),  theme.border(.borderPrimary))
case .extraLegroom: return (theme.resolve(.info).bg,    theme.resolve(.info).base)
```

**Before / after — Class V (typical Style Chrome):**

```swift
struct FooChrome: View {
    @Environment(\.theme) private var theme
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value)
            .fill(SemanticColor.primary.solid)          // before: Theme.shared — mismatches the line below
            .foregroundStyle(theme.text(.textPrimary))  // env-correct
    }
}
// after: .fill(theme.resolve(.primary).solid)          // now consistent with theme.text(...)
```

### D3 — Non-View analysis (mirror ADR-0003)

Following ADR-0003's discipline of stating the inherent limit rather than hiding it:

- **Classes V and P resolve correctly** because a `Theme` is in scope (environment or parameter). This is the overwhelming majority: 121 of 146 files are Class V; Class-P helpers already take `theme` (the pattern predates this ADR).
- **Class M (eager modifiers)** is *not* an inherent limit — it only *looks* like one. `Icon.accent(_:)` resolves `color?.base` to a `Color` at modifier-call time (outside any body). The fix is to store the `SemanticColor` and resolve in `body` via `@Environment(\.theme)`. The public modifier signature (`func accent(_ color: SemanticColor?) -> Self`) is unchanged; only an internal stored-property type flips (`Color?` → `SemanticColor?`). Every COW modifier that today stores a resolved `Color` derived from a `SemanticColor` gets the same treatment.
- **Class N (non-View builders) is the one genuine limit.** `ChartColorScale.init(series:)` bakes `.solid` into a `[Color]` range with no `Theme` and, depending on the caller, possibly no View ancestor. **Recommended fix: thread a `theme:` parameter** — `ChartColorScale(series:theme:)` — populated by the chart's View body, which *does* hold `@Environment(\.theme)`. This converts N→P for every builder invoked from a View (the common case). A builder invoked from pure model code with no View in its call graph is the irreducible residue; for those, per-subtree color is physically impossible for the same reason ADR-0003 gave for strings (no `@Environment` at a value initializer), and they resolve against `Theme.shared` by definition. `sr-ios-dev` audits Class-N sites and confirms each is caller-threadable; the expectation from this inspection is that **all** current N sites (`ChartColorScale` is the only one found) are View-built and therefore fixable.

The rule going forward: **never resolve `SemanticColor → Color` where a `Theme` is not in scope.** Store the enum; resolve at the latest possible moment (a View body or a helper that takes `theme`).

### D4 — `Effects.swift`: convert View-extension helpers to `ViewModifier`s

`edgeBorder(_:width:color:)` and `fadeEdge(_:length:color:)` (`Effects.swift:15-32`) are free functions on `View` that fall back to `Theme.shared` when their `Color?` argument is nil. As plain functions they cannot read `@Environment`. Fix: back each with a small `ViewModifier` struct that reads `@Environment(\.theme)` and uses it for the default. (Separately, the `color: Color?` parameter violates the token-fed-modifier house rule — MEMORY "token-fed-modifiers"; fold that into the same PR by taking a token key / `SemanticColor` instead of a raw `Color?`, deprecate-forwarding the raw overload. Non-blocking for the resolution fix but cheap to do together.)

### D5 — Metrics & typography: documented process-global limit, same idiom available later

`RadiusKey/RadiusRole/SpacingKey.value` and `TextStyle.font/.lineSpacing` **stay singleton-backed** in this ADR. Rationale: they vary by `radiusScale/spacingScale/fontScale/font`, which are not "brand," and threading them is ~2000 sites. Two concrete actions instead of a migration:

1. **Correct the promise wording** in `ThemeContext.swift:40-48` and any docs so it is *true*: per-subtree `.theme(_:)` re-skins **color** (semantic/brand/accent and all instance color accessors); **corner radius, spacing, and type scale remain process-global** (they follow `Theme.shared` / the root `.themeKit()` theme). This is the honest, bounded slice of Approach B — applied only to the axis we are choosing not to isolate, and stated explicitly rather than implied.
2. **Reserve the same resolver idiom** for a future phase if a real per-subtree metric need appears: `theme.metric(.spacing(.md))` / a `Theme.RadiusRole.value(in: theme)` overload, deprecate-forwarding the zero-arg `.value`. No new pattern, no commitment now.

### D6 — Interaction with `.themeKit()`, `.theme(_:)`, and the localization folding

- **`.themeKit()`** (`ThemeKit.swift:44-72`) injects `.environment(theme)` with `Theme.shared` and re-identifies the subtree on `ThemeKitRootIdentity(theme: revision, language: languageRevision)`. Unchanged. After this ADR, a runtime swap of `Theme.shared` still bumps `theme.revision`, still rebuilds the whole tree, and every body re-reads the env theme and **re-resolves** `SemanticColor` through it — same guarantee as today, now including the accents.
- **`.theme(brandB)`** injects `brandB` for a subtree. After this ADR, `theme.resolve(…)` in that subtree reads `brandB` → correct accents on **first paint**. This is the "set-once, second brand in a subtree" case the promise is about, and it now holds. **Trade-off surfaced:** `.theme(brandB)` injects the instance but does *not* add `.id(brandB.revision)`, so a *live mutation* of `brandB` (a second `@Observable` theme reconfigured at runtime) won't repaint that subtree — exactly the gap `.themeKit()` closes for the root. If live-mutating a *secondary* subtree theme is ever required, add either the documented `.theme(brandB).id(brandB.revision)` pattern or a `.theme(_:reactToRuntimeChanges:)` overload that folds `brandB.revision` into an id the way `.themeKit()` does. Recommendation: document the `.id(brandB.revision)` pattern now; add the overload only on demand.
- **Secondary Observation benefit (noted, not promised).** Because `theme.resolve(…)` reads the env theme's `@Observable` dictionaries instead of `Theme.shared`, SwiftUI's Observation can now track color-token reads and invalidate on change without the `.id(revision)` sledgehammer. This *reduces* reliance on the full-subtree rebuild for color, but does not remove it — the deferred metric/type `.value` reads still bypass Observation — so `.themeKit()` keeps its `.id(revision)`.
- **Localization folding.** ADR-0003 folded `ThemeKitStrings` language revision into `.themeKit()`'s identity. This ADR is orthogonal (color, not strings) and touches none of that path; the `ThemeKitRootIdentity` composite is unchanged.

### D7 — Enforcement: an allowlisted `Theme.shared` lint + the deprecation ratchet

Two ratchets keep the fix from regressing:

1. **The deprecation warnings are the migration to-do list.** Every un-migrated `SemanticColor.solid`-style read emits a warning; a PR is "done" for a file when its warnings are gone. (During the migration window the tree carries many warnings — expected and self-clearing per PR.)
2. **A CI grep-lint** bans `Theme.shared` reads outside a small allowlist. The legitimate `Theme.shared` uses are: the singleton's own definition (`Theme.swift`), the environment default (`ThemeContext.swift:37`), the injectors (`ThemeKit.swift`, `ThemedHostingController.swift`), the *mutation* entry points that apply a config to the global (`ThemePicker`, `DesignSpec`, `ThemePresets`, `ThemeConfig` docs), the deprecate-forward shims themselves (`SemanticColor.swift`, and the deferred `ThemeModel.swift`/`Typography.swift` per D5), and `#Preview` bodies (which correctly inject `.environment(Theme.shared)`). Everything else is a finding. This is the same generated-artifact-gate philosophy as `make l10n` / `make skill`.

## Consequences

- **Positive:** the advertised feature becomes true — two subtrees with different brands render correct accents; the split-brain inside single bodies (`SeatPalette`, every Class-V file) is eliminated; the fix reuses an already-shipping pattern (`AlertToast.background(_:)`); per-call cost is nil (no new environment reads for 121/146 files); color-token reads become Observation-trackable; the misleading `ThemeContext` promise is either fulfilled (color) or corrected to be accurate (metric/type scale).
- **Behavioral guarantee (backward-compat):** with no `.theme(_:)` override in play, `@Environment(\.theme)` is `Theme.shared`, so `theme.resolve(…)` resolves against the exact same instance the deprecated `SemanticColor.solid` reads — identical output. An app that never calls `.theme(_:)` is byte-identical before and after. No public type is removed; the deprecated accessors keep compiling.
- **Costs / risks:** 758 SemanticColor call sites migrate (mechanical for V/P; small refactor for M; one audit for N); a transient wall of deprecation warnings during migration; the metric/type scale axis stays process-global (documented, deferred, not silently broken); `.theme(brandB)` live-mutation of a *secondary* theme still needs the `.id(brandB.revision)` pattern (surfaced, low-demand).
- **Enforcement:** the deprecation ratchet + the allowlisted `Theme.shared` lint prevent new offenders and drive the existing ones to zero.

## Blast radius (offender inventory, production only — `#Preview` scaffolding excluded)

Every ambiguous component-file `Theme.shared` hit from the audit grep was verified to sit **inside a `#Preview` block** (`.environment(Theme.shared)` / preview `.background(…)`), which is correct and out of scope. The true production offenders:

| # | Site | Class | Scope |
|---|---|---|---|
| 1 | `SemanticColor.swift:23-112` — all role + ladder accessors | engine (non-View) | **In scope — D2** |
| 2 | `Effects.swift:17,23` — `edgeBorder`/`fadeEdge` fallback | View-extension helper | **In scope — D4** |
| 3 | `Icon.swift:58` — `.accent(_:)` stores `color?.base` | M (eager modifier) | **In scope — D3** |
| 4 | `ChartModels.swift:88,92` — `ChartColorScale` bakes `.solid` | N (non-View builder) | **In scope — D3, thread `theme:`** |
| 5 | `SeatMapModels.swift:119,120,122,123` (+ `selectedColors`/`occupied`) | P (helper already takes `theme`) | **In scope — D3, swap reads** |
| 6 | `MeterStyle.swift:90,142` — `SemanticColor.success.solid` in Chrome `body` | V | **In scope — D2** |
| 7 | The remaining SemanticColor reads — **758 total across 146 files**, 121 already holding `@Environment(\.theme)` | V (majority) | **In scope — mechanical D2 swap** |
| 8 | `ThemeModel.swift:78,104,120` — `RadiusKey/RadiusRole/SpacingKey.value` | engine (non-View) | **Deferred — D5 (documented limit)** |
| 9 | `Typography.swift:96,103` — `TextStyle.font/.lineSpacing` | engine (non-View) | **Deferred — D5 (documented limit)** |

Legitimate singleton uses (NOT offenders, allowlisted per D7): `Theme.swift` (definition), `ThemeContext.swift:37` (env default), `ThemeKit.swift` / `ThemedHostingController.swift` (injectors), `ThemePicker` / `DesignSpec` / `ThemePresets` / `ThemeConfig` (apply-to-global mutation), and all `#Preview` bodies.

Reconciling the review's "~27 components": that figure counts the *distinct offender files* outside the engine; the *call-site* surface is 758 reads / 146 files, but 121 of those files already hold the env theme, so the migration is a near-mechanical prefix swap for the bulk, with genuine (small) work only on the ~4 timing-trap files (rows 3–6) plus `Effects.swift`.

## Testing strategy

- **Unit (ThemeKitCore):** build two `Theme` instances with different brand hexes (`applyGenerated(primaryHex:accentHex:)`). Assert `themeA.resolve(.accent).solid != themeB.resolve(.accent).solid`, and that `themeA.resolve(.info).base == themeA.background/palette` for the info key. Assert the deprecated `SemanticColor.info.base == Theme.shared.resolve(.info).base` (forward-equivalence). Assert `Resolved` is `Sendable`-usable across an isolation boundary (compile check under Swift 6 mode).
- **Snapshot (the regression that proves the feature):** one image with **two side-by-side subtrees**, `.theme(brandA)` and `.theme(brandB)`, each rendering a `Badge`/`MeterStyle`/`SeatLegend` that uses `SemanticColor` accents. Pre-fix both render brand A's accent (the bug); post-fix each renders its own. This snapshot is the acceptance gate.
- **Non-View (Class N):** a chart built inside a `.theme(brandB)` subtree must color its series with brandB — verifies `ChartColorScale(series:theme:)` threading.
- **Live-mutation trade-off (D6):** a test that mutates a secondary `brandB` at runtime under bare `.theme(brandB)` (no repaint expected) vs. `.theme(brandB).id(brandB.revision)` (repaint) — documents the gap as tested behavior, not a surprise.
- **On-device:** `-openDemo "Seat Map"` (or any SemanticColor-heavy component) wrapped in a two-brand harness; screenshot before/after.

## Phased rollout (PR-per-unit)

| Phase | Unit | Effort |
|---|---|---|
| 0 | `SemanticColor.Resolved` + `Theme.resolve(_:)` + `color.resolved(in:)`; deprecate-forward the zero-arg `SemanticColor` accessors; unit + two-brand snapshot harness. **No call sites migrated yet** — purely additive, tree still green. | M |
| 1 | Migrate the **timing-trap** files (the ones that would otherwise stay wrong even after a mechanical swap): `Icon` (Class M), `ChartModels` (Class N, `theme:` param), `SeatMapModels` + any other Class-P helpers, `MeterStyle`, `Effects.swift` (D4). | M |
| 2 | Mechanical Class-V migration of the remaining SemanticColor reads, batched by area (Atoms → Molecules → Organisms → Travel), one PR per batch — driven to zero deprecation warnings. Can run as parallel disjoint-file PRs (worktree pattern, MEMORY "repo-concurrent-agents-worktree"). | L |
| 3 | Correct the `ThemeContext` promise wording (D5.1); add the allowlisted `Theme.shared` CI lint (D7); DocC/README note on what per-subtree `.theme(_:)` does and does not isolate. | S |
| 4 (optional / on-demand) | Metric & typography threaded overloads (D5.2) and/or `.theme(_:reactToRuntimeChanges:)` (D6) — only if a concrete per-subtree metric or live secondary-theme need appears. | M |

## Alternatives considered

1. **Pure B — keep the singleton, delete the per-subtree promise.** Rejected (D1): throws away working surface re-skinning and every theme-pinned preview; the honest version requires removing `.theme(_:)` entirely.
2. **Full A now — thread color + metrics + typography together.** Rejected (D1): ~2000 extra sites to isolate an axis no two-brand screen varies; kept as a same-idiom deferral (D5.2).
3. **`in: Theme` on every accessor (`color.solid(in: theme)`) instead of a `Resolved` binder.** Rejected: turns 8 role *properties* into methods and threads `theme` at every one of the 758 reads with no shared binding; `Resolved` threads once and keeps property syntax (`theme.resolve(.primary).solid`).
4. **A task-local / thread-local "current theme" the enum reads (`Theme.current`)** so `SemanticColor.solid` keeps its zero-arg shape. Rejected: SwiftUI body evaluation is not guaranteed to run inside a controlled task-local scope; it re-introduces hidden global state (the exact class of bug this ADR removes) and is unverifiable across the 217-component surface. The env theme is already in hand — no magic needed.
5. **Make `SemanticColor` an `@Observable`/`EnvironmentKey` of its own.** Rejected: duplicates `\.theme` (a `SemanticColor` is a *selector*, not a *theme*); the theme already carries all the data.
6. **Do nothing / mark `.theme(_:)` "preview-only" in docs.** Rejected: it works for surfaces today and the fix for accents is cheap and mechanical; scoping it to previews would be a strictly worse, still-inconsistent story.

## Open questions (for sr-ios-dev pressure-testing)

- **Class-N completeness:** confirm `ChartColorScale` is the *only* non-View builder that bakes `SemanticColor → Color`, and that every instantiation is reachable from a View that can supply `theme:`. If any is built in pure model code, decide explicitly: thread a `theme:` down, or accept `Theme.shared` for that residue and document it (ADR-0003 §"known limitation" wording).
- **`Resolved` cost in hot lists:** `theme.resolve(.primary)` constructs a 2-field struct per read. In a large `SeatMap`/`Chart`, prove this is free (it is a stack value, but confirm no `Color` bridging surprises) — or bind once per body (`let p = theme.resolve(.primary)`) as the recommended call-site idiom for repeated roles.
- **Deprecation noise policy:** whether to gate the `@available(deprecated)` behind a phase flag so Phase 0 lands warning-free and warnings switch on for Phase 2, vs. accepting the warning wall immediately as the visible to-do list.
- **Icon (Class M) raw-color path:** confirm `Icon` has no *raw* `Color` accent path that also needs storing-vs-eager treatment, and that flipping the stored type to `SemanticColor?` doesn't collide with an existing raw override modifier.
- **Metric-axis honesty check (D5.1):** verify no shipped demo/snapshot currently *relies* on per-subtree radius/spacing differing (it should not, given the singleton) before publishing the "metrics are process-global" statement.
