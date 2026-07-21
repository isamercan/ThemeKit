# ADR-0007 — Lower the iOS deployment floor to 15.6 (macOS stays 14)

- **Status:** **Proposed** (2026-07-20) — awaiting sr-ios-dev pressure-test; strategy (15.6, not 16, not stay-17) is decided, the mechanics below are what to pressure-test
- **Date:** 2026-07-20
- **Deciders:** ThemeKit architecture
- **Context source:** Consumer-reach requirement — support the iOS 15 device fleet (iPhone 6s/7/SE1 era caps at 15.8.x); today's floor `Package.swift:13` = `.iOS(.v17)` excludes it entirely
- **Companion plan:** `IOS156_MIGRATION_PLAN.md` (repo root) — the wave-by-wave execution plan, file inventory, and CI-lane sketch
- **Rollout note:** The floor change itself is **additive** for every existing consumer (all are on iOS 17+; the support matrix only widens) → next **minor** (1.3.0). One bounded exception rides along: the `@Observable`→`ObservableObject` core downgrade changes the *consumer-side observation pattern* for presenters/`FormValidator` (§D4) — a narrow, one-line-per-site migration, recorded in `.api-breakage-allowlist.txt` with a CHANGELOG migration block, following the repo's established practice of shipping intentional, allowlisted source changes under a documented bump (cf. the 1.2.0 changelog).

## Context

ThemeKit compiles bare against iOS 17 APIs everywhere: the codebase has ~3 `if #available` and ~3 `@available` guards across 355 source files. Lowering the floor is therefore not a `platforms:` one-liner — it is a migration with three cost buckets (verified by grep sweep **and** a compiler probe; exact per-file inventory in `IOS156_MIGRATION_PLAN.md` §2):

- **Bucket A — mechanical gate/swap (iOS 17 conveniences):** two-parameter `.onChange(of:) { old, new in }` (40 sites), `.snappy`/`.smooth`/`.spring(.smooth)` animation presets (12 sites / 10 files — *not in the original grep inventory*), `.symbolEffect(.bounce)` (5 files), `.scrollTargetBehavior`/`.scrollTargetLayout`/`.scrollPosition`/`.scrollClipDisabled` (3 style files), `.onKeyPress` (`CommandPalette.swift`), `.contentTransition` (iOS 16 modifier; the `.numericText(value:)` case is 17 — 5 files).
- **Bucket B — core observation downgrade (iOS 17 Observation framework):** `@Observable` on `Theme` (`ThemeKitCore/Theme/Theme.swift:23`), `ThemeKitStrings.Revision` (`ThemeKitCore/ThemeKitStrings.swift:91`), five organism presenters (`Drawer`, `Tour`, `BottomSheet`, `Upload`, `Feedback`) and `FormValidator` (`ThemeKit/Validation/FormValidator.swift:23`). Observation does **not** back-deploy below 17; `ObservableObject`/`@Published` runs on 15 *and* 17, so this is a single-path downgrade — but it touches the `.themeKit()` rebuild machinery and the documented consumer patterns `@Environment(SheetPresenter.self)` / `@State`-owned presenters (§D3–D4).
- **Bucket C — no back-deploy path, reimplement or reroute (iOS 16 structural API):** `Layout` conformances (`FlowLayout`, `Masonry`, `Flex`) + `AnyLayout` (`AnchorNav`, `Splitter`); `Grid`/`GridRow` (**one** file: `ThemeKitTravel/…/BoardingPassStyle.swift` — see disagreement note in the plan); `ViewThatFits` (13 uses / 4 files); the `Charts` framework (6 files — no Charts on iOS 15); `.presentationDetents`/`.presentationBackground` (16.4)/`.presentationCornerRadius` (16.4) in `BottomSheet`/`PhoneField`; `Gauge` (`GaugeView`); `ShareLink` (`ShareButton`); `.draggable`/`.dropDestination` (`KanbanBoard`); `UnevenRoundedRectangle` (5 files); `.scrollContentBackground` (`MultiLineTextInput`); `TextField(axis:)`+`lineLimit(range)` (`Mentions`); `Locale.Language` (`LanguageSwitcher`); `Task.sleep(for:)` (`CodeBlock`); `Regex<Output>` in a public signature (`Validation.swift:97`); `Color…gradient` (`Mask.swift` preview); `Color.resolve(in:)` (iOS 17, `ThemeKitCore/ColorContrast.swift:49` — inside the WCAG contrast engine that `ContentContrastTests`/`ColorModelsTests` cover).

**The inventory is iterative, not final.** A trial build at a lowered target failed *first* inside `ThemeKitCore` (the module everything depends on) on `ColorContrast.swift` — an API no grep list contained. The compiler's availability checker is the only complete oracle; the plan therefore budgets an explicit fix→rebuild→fix loop per wave, and treats the grep inventory as a floor, not ground truth.

**Compiler-verified good news:** `#Preview` (388 blocks / 266 files) **typechecks clean at a 15.6 target** with the current toolchain — probed directly with `swiftc -typecheck -target arm64-apple-ios15.6-simulator`. The preview surface is not a migration cost.

**Toolchain reality that shapes verification (§D5):** `swift-tools-version: 6.2` binds the package to the Xcode 26 / Swift 6.2 toolchain. There is **no iOS 15.6 simulator runtime** (the last iOS 15 sim runtime is 15.5, in the legacy pre-cryptex format that modern Xcode cannot install). "Build + test on an iOS 15.6 simulator" is therefore not literally achievable; §D5 defines the equivalent guardrail.

## Decision

### D1 — Floor: `.iOS("15.6")`, macOS stays `.v14`, Swift 6 mode stays

`Package.swift` platforms become `.iOS("15.6"), .macOS(.v14)` (string form — there is no `.v15_6` enum case). Nothing else in the manifest moves: tools 6.2, Swift 6 language mode, and both upcoming features (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`) are compile-time behaviors with no OS floor. Because macOS stays at 14 (the iOS-17-era SDK), **availability guards are an iOS-only concern**: `if #available(iOS 16.0, *)` is statically always-true on macOS, so the macOS build gains no branches and no risk. The add-on targets follow the package floor except `ThemeKitCalendar`, whose Almanac dependency sets its own floor — the add-on keeps whatever floor Almanac requires (traits keep it out of default resolution; verify in Phase 4).

### D2 — Replacement policy: single-path first, graceful-degrade for polish, reimplement for structure

One decision rule, applied per API (full API→treatment table in the plan §2):

1. **Single-path iOS-15-compatible replacement** — when an iOS 15 construct expresses the *same capability*, replace once and run the same code on every OS. No branches, no doubled snapshot matrix, CI exercises it on every run. Applies to: `@Observable`→`ObservableObject` (Bucket B), `Grid`→manual rows/`LazyVGrid`, `ViewThatFits`→measured-choice helper, `Charts`→`Canvas`/`Path` rendering (precedent in-repo: `PriceTrendChart`, `PriceHistogram` are already custom-drawn), `.snappy`/`.smooth`→equivalent `.spring(response:dampingFraction:)` routed through `ThemeMotion`/`Motion` tokens, `UnevenRoundedRectangle`→a Core `Shape` polyfill, `Task.sleep(for:)`→`Task.sleep(nanoseconds:)`, `Locale.Language`→iOS-15-safe `Locale` parsing, `Color.resolve(in:)`→`UIColor`/`NSColor` component bridge, two-param `.onChange`→one internal back-deployed compat modifier.
2. **Graceful-degrade behind `if #available(iOS 16/17, *)`** — when the modern API is *pure enhancement* and its absence is acceptable UX on an old device: `.symbolEffect` (icon bounce), `.scrollTargetBehavior`/`.scrollClipDisabled` (paging snap polish), `.contentTransition` (numeric roll), `.onKeyPress` (hardware-keyboard nav), sheet `presentationDetents`/corner/background chrome, `ShareLink` (UIKit share-sheet fallback), `TextField(axis:)` (TextEditor-based fallback). Motion-flavored enhancements must keep flowing through the existing `MicroMotion`/Reduce-Motion gate so `#available` and `.ifMotionAllowed` compose rather than nest ad hoc.
3. **Hard testability rule for every degrade branch:** the legacy (`else`) branch must be an **internally instantiable unit** (a named internal view/function), never an inline closure — so the snapshot/unit suite can pin the <16/<17 rendering directly **on any simulator runtime**. This rule is what makes D5's verification story sound despite no iOS 15 runtime existing.

Never acceptable: raw-`Color`/`CGFloat` knobs sneaking in during rewrites (token-fed-modifier house rule holds), or per-OS dual *public* API.

### D3 — Core observation downgrade, and why per-subtree theming survives

The precise inventory (corrects the working notes' "4 critical Core files"): Core has **two** `@Observable` declarations — `Theme` and `ThemeKitStrings.Revision`; the hits in `ThemeContext.swift` and `ThemeKit.swift` are doc comments. The mechanism today (`ThemeKitCore/Theme/ThemeKit.swift:44-71`):

- `\.theme` is a **plain keypath `EnvironmentKey`** (`ThemeContext.swift`, default `Theme.shared`) — *not* the iOS-17 object-based environment. Components read `@Environment(\.theme)`. **This entire path is iOS-15-safe and unchanged.**
- Reactivity is the **`.id(revision)` rebuild**, not Observation granularity: `ThemeKitModifier.body` reads `theme.revision` + `ThemeKitStrings.observable.value` and re-identifies the subtree via `ThemeKitRootIdentity`. Observation's only job is re-running that one `body` when a revision bumps.

The downgrade, mapped 1:1:

| Today (iOS 17) | After (iOS 15.6+) |
|---|---|
| `@Observable final class Theme` | `final class Theme: ObservableObject`, `@Published private(set) var revision` (other stored tokens need no `@Published` — nothing observes them per-property; the revision rebuild is the contract) |
| `ThemeKitModifier` reads `theme.revision` in `body` (Observation-tracked) | `ThemeKitModifier` holds `@ObservedObject private var theme = Theme.shared` — `objectWillChange` re-runs `body`, same `.id` bump |
| `ThemeKitStrings.Revision` `@Observable` | `ObservableObject` + `@Published var value`; `ThemeKitModifier`/`.themeKitLocalized()` observe it the same way |
| `.environment(theme)` object-form injection (`ThemeKit.swift:68`, `ThemedHostingController.swift:26`, ~30 `#Preview` sites) | `.environment(\.theme, theme)` keypath injection (byte-identical semantics for every `@Environment(\.theme)` reader) |
| Presenters (`SheetPresenter`, `DrawerPresenter`, `FeedbackPresenter`, `TourController`, Upload store) + `FormValidator` `@Observable` | `ObservableObject` + `@Published` state; hosts inject `.environmentObject(presenter)`; internal reads become `@EnvironmentObject`/`@ObservedObject` |

**ADR-0006 invariants, checked one by one:**
- *Per-subtree `.theme(brandB)` first-paint correctness* — carried by the keypath environment value + `theme.resolve(_:)` (`SemanticColorResolved.swift`); no Observation involved. **Preserved.**
- *Runtime root theme swap repaints everything* — carried by `revision` + `.id`; `@ObservedObject` supplies the re-run trigger. **Preserved** (this is the Phase-1 regression test).
- *Live mutation of a secondary subtree theme* — was already documented as **not** covered without `.id(brandB.revision)` (`ThemeContext.swift:76-79`). Unchanged.
- *ADR-0006 §D6's "secondary Observation benefit"* (color-token reads becoming Observation-trackable) — explicitly "noted, not promised" there; it is **forfeited** by this ADR. The `.id(revision)` sledgehammer, which was never removed, remains the sole rebuild mechanism. No promised behavior regresses.
- *`Theme.shared` allowlist gate* (`scripts/check-theme-shared.sh`, ADR-0006 §D7) — the downgrade adds **no** new `Theme.shared` reads outside already-allowlisted files (`Theme.swift`, `ThemeContext.swift`, `ThemeKit.swift`, `ThemedHostingController.swift`, `#Preview` bodies). Gate keeps passing; if injector lines move, the allowlist entries are file-scoped and follow them.

`Theme` keeps its `@unchecked Sendable` + main-thread-confinement rationale unchanged (`Theme.swift:16-22`); `ObservableObject` conformance doesn't alter it. `import Combine` is not required (`ObservableObject` surfaces via SwiftUI); zero-dependency claim intact — Combine/SwiftUI are system frameworks.

### D4 — Public API and SemVer: minor (1.3.0), with two recorded pattern exceptions

**The floor change is additive.** Every existing consumer resolves 1.3.0 on iOS 17+ and recompiles; new consumers gain 15.6–16.x. Widening `platforms:` is not a source or ABI break, and `swift-api-digester` sees no removal from the declaration surface for it. **Verdict: minor bump, 1.3.0.**

**Exception 1 — consumer observation of presenters/`FormValidator` (source-visible, one line per site):** `@Environment(SheetPresenter.self)` / `@Environment(DrawerPresenter.self)` / `@Environment(FeedbackPresenter.self)` is the *documented* consumer read pattern (`BottomSheet.swift:73`, `Drawer.swift:353`, `Feedback.swift:12`). That syntax requires `Observable` conformance and cannot survive the downgrade → migrates to `@EnvironmentObject var sheet: SheetPresenter`. Compile error + one-line fix; recorded in `.api-breakage-allowlist.txt` (conformance removals: `Observable` off the six classes) with a CHANGELOG migration table.

**Exception 2 — the sharpest edge, because it is silent:** a consumer holding `@State private var feedback = FeedbackPresenter()` (correct for `@Observable`) **still compiles** after the downgrade but stops observing — views won't update. Migration is `@State` → `@StateObject`. Because this fails at runtime, not compile time, it gets: (a) top-of-CHANGELOG prominence, (b) updated doc-comment recipes on all five presenters + `FormValidator`, (c) a migration snippet in the release notes, and (d) where feasible an `@available(*, deprecated)` annotation on any convenience API whose doc shows the `@State` pattern, pointing at the new recipe.

**Non-breaking availability gating:** public API that *names* an iOS-16+ type stays, annotated — `ValidationRule.matches(_ regex: Regex<Output>, …)` becomes `@available(iOS 16.0, *)` (additive restriction only relative to the *new* floor; no existing consumer loses it). Same treatment for any similar find in the compile loop. `FlowLayout`'s public `Layout` conformance is the one Bucket-C item that must change shape publicly; its call-syntax-preserving replacement and allowlist entry are specified in the plan (§3a).

**Rejected:** *major bump / fold into the 2.0 removal epoch* — it would chain floor support to an unrelated epoch and delay it indefinitely; the two exceptions are narrow, mechanical, and exactly what the api-breakage allowlist + CHANGELOG machinery exist to record. If the maintainer wants strict SemVer orthodoxy, Exception 1+2 are the *only* items forcing major — nothing else in the migration is even arguably breaking.

### D5 — Verification guardrail: compile-floor gate + oldest-runtime lane + directly-tested legacy branches

Three layers replace the impossible "iOS 15.6 simulator" lane (no 15.6 runtime exists; ≤15.5 runtimes are legacy-format and uninstallable on the Xcode 26 toolchain that tools-6.2 requires):

1. **Compile-floor gate (airtight, blocking).** An `ios-floor` CI job builds the package for the iOS simulator with the deployment target forced to 15.6. The Swift availability checker is exact — *every* use of a 16/17-only API without a guard is a hard error. This is the primary guardrail and it needs no old runtime. During migration (while `Package.swift` still says `.v17`) it runs with an explicit target override as a **canary** (advisory, error-count ratcheting down); when Phase 3 completes and the manifest flips to 15.6, the same job becomes the plain blocking build. YAML sketch in the plan §Phase 0.
2. **Oldest-installable-runtime test lane.** Tests run on the oldest simulator runtime the CI toolchain can install (expected iOS 16.4 — sr-ios-dev verifies in Phase 0) — this executes the `#available(iOS 17)` *false* branches for real.
3. **Legacy branches as first-class test units (D2 rule 3).** The `#available(iOS 16)` false branches can never run on an installable runtime, so they are verified by construction: each is a named internal unit, snapshot- and unit-tested directly on the modern runtime. Optional belt-and-braces: a manual smoke pass on a physical iOS 15.7 device before release.

### D6 — Permanent authoring tax, made cheap

From merge on, contributors cannot use bare iOS 16/17 API. Enforcement is automatic (the compiler at the 15.6 floor rejects it — layer 1 above), so the tax is awareness, not policing: `themekit-authoring` SKILL gains a house rule ("iOS 15.6 floor: prefer the single-path idiom; degrade-with-named-legacy-unit for polish; the compat helpers to reach for are `onChangeCompat` / `ThemeUnevenRoundedRect` / the measured-fit helper / `ThemeMotion` presets"), and the plan's compat-helper inventory becomes the documented toolbox. When the floor eventually rises again (a future major), the compat helpers are the deletion checklist.

## Consequences

- **Positive:** the iOS 15 fleet becomes addressable; the library sheds its hidden Observation dependency (one less framework coupling); Charts/layout reimplementations render identically across OS versions (single snapshot reference, no per-OS pixel drift); the degrade-branch testability rule leaves the codebase *more* testable than before.
- **Costs / risks:**
  - **Permanent tax** (D6): no bare 16/17 APIs; modern-API polish always costs a guard + named legacy unit.
  - **Silent consumer behavior change** (D4 Exception 2) — mitigated by prominence, not eliminated. The single biggest external risk of the release.
  - **Chart reimplementation** is the largest engineering item (6 files, axes/legends/interaction) and is render-visible → full snapshot re-record for chart components.
  - **Lost Observation granularity** — future per-property theme observation would need re-introduction behind availability (explicitly out of scope; `.id(revision)` remains the contract).
  - **iOS 15.x runtime untestable in CI** — bounded by D5's three layers; residual risk is OS-behavioral differences (not API availability) in 15.x UIKit/SwiftUI internals, addressed by the optional physical-device smoke.
  - **`MultiLineTextInput`/`TextEditor`**: `.scrollContentBackground(.hidden)` has no clean iOS 15 equivalent; the legacy branch needs the `UITextView.appearance().backgroundColor = .clear` technique or accepts the system background — decided at implementation with a snapshot pin (plan §Phase 2).
- **Not a consequence:** `#Preview` (verified), Swift 6 mode/concurrency runtime (back-deploys), the zero-dependency claim, the macOS build (no new branches), `make l10n`/`gen_skill` layers (unchanged mechanics; regen runs ride each wave per house rules).

## Alternatives considered

1. **Stay at iOS 17.** Rejected by the driving requirement: the iOS 15 fleet is the point. (It remains the zero-cost option if the reach requirement ever lapses — this ADR's work is then simply not done.)
2. **Lower to iOS 16.0 (or 16.4) instead.** Genuinely attractive on cost: it deletes **all of Bucket C** (Charts, Layout, Grid, ViewThatFits, detents, ShareLink, Gauge, drag-drop — the expensive half) while Buckets A and B are required either way (Observation and the 17-only conveniences don't run on 16). Rejected because it strands the actual target fleet: iPhone 6s/7/SE1 stop at 15.8, so a 16.0 floor buys almost no additional reach over 17 in practice. Recorded so the cost asymmetry is visible: **~60% of this migration's engineering cost is purchasing the 15.x segment specifically.**
3. **Dual-path public API** (keep `@Observable`/Charts on 17+, parallel 15-compatible types below). Rejected: doubles the public surface and the snapshot matrix, splits consumer documentation, and the 17-path would rot — single-path is the only maintainable shape for a 226-component library.
4. **Third-party Observation back-port (Perception-style) to keep `@Observable` semantics on 15.** Rejected outright: violates the zero-dependency contract the package sells (`Package.swift:17`).
5. **Availability-gate whole components** (`@available(iOS 16, *)` on Charts, KanbanBoard, etc., shipping them as 16+-only). Rejected as the general policy — a consumer on 15.6 should get the full catalog, and a partially-available catalog breaks the "every component works at the floor" story. Retained as a *documented escape hatch* only if a specific reimplementation proves pathological (sr-ios-dev flags it; the candidate would be Charts, and the plan's Canvas approach makes it unnecessary).

## Open questions (for sr-ios-dev pressure-testing)

- **Deployment-target override mechanics for the canary lane:** confirm `xcodebuild … IPHONEOS_DEPLOYMENT_TARGET=15.6` propagates into SwiftPM package targets on the current toolchain; fallback is a CI-local `sed` of `Package.swift` (never committed). Also confirm the oldest runtime installable on the `macos-15`/Xcode-26 CI image (expected iOS 16.4 via `xcodebuild -downloadPlatform iOS -buildVersion`).
- **`@ObservedObject` inside a `ViewModifier`:** confirm `ThemeKitModifier` re-runs correctly with `@ObservedObject` (it should — `ViewModifier` participates in `DynamicProperty`); fallback shape is an inner `ThemeKitRoot: View` wrapper that owns the `@ObservedObject`.
- **Presenter `@Published` granularity:** whether coarse `objectWillChange`-per-mutation causes visible over-invalidation in `Feedback` toast stacks / `Upload` progress (vs. today's per-property tracking) — measure with the demo's toast stress case; if needed, split hot counters into a child `ObservableObject`.
- **`FormValidator<Field: Hashable>` generic + `ObservableObject`:** confirm no Swift 6 isolation friction (`@MainActor` class, `@Published` in generic context — expected fine) and that `InfoMessageUI` bindings survive unchanged.
- **`ThemeKitCalendar`/Almanac floor:** what floor does Almanac 0.2.x declare? If >15.6, the add-on keeps its higher floor (trait-gated, acceptable) — document it in the installation guide either way.
- **iOS 15 SwiftUI behavioral potholes** to spot-check on the physical-device smoke: sheet/`fullScreenCover` state-loss quirks, `ScrollViewReader` timing differences, `@FocusState` reliability in `OTPInput`/`CommandPalette`.
