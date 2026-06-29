# SwiftUI Component Audit — ThemeKit

**Type:** (A) Distributable SPM library — `ThemeKit` (zero-dependency core) + `ThemeKitLottie` (opt-in add-on).
**Swift / tooling:** `swift-tools-version: 6.2`, `swiftLanguageModes: [.v6]` + 2 upcoming flags (migrated `.v5`→`.v6` in P0).
**Min target:** iOS 17 / macOS 14 (Package.swift:12-15).
**Dependencies:** core = **0** (native); lottie-ios (only the `ThemeKitLottie` target), swift-snapshot-testing (only the test target), swift-docc-plugin (docs only). → Consumers get the core with zero dependencies.
**Size:** 154 source files / 19,917 LOC, **117 components** (29 atoms / 45 molecules / 43 organisms), 44 test files.

**Current maturity: Level 5 (2026 frontier-modernized)** — most frontier gaps have been closed.
> Note: The classic architecture roadmap (`docs/AUDIT.md`) was completed on its own track and released as v0.2.0. This report applies the **2026 frontier lens**.

### Executive summary (implemented after this audit)
- ✅ **P0** Swift 6 language mode + upcoming flags (PR #82)
- ✅ **P1** Observation `@Observable` — 8/8 (5 presenters + FormValidator #83, **Theme** in a separate PR)
- ✅ **P1** Liquid Glass chrome `.glassChrome()` (PR #84)
- ✅ **P2** Swift Testing pilot + `DateFieldStyle: Sendable` (PR #85)
- ⏳ **P1 #4-5** (a11y audit + snapshot recording): **environment-dependent** — requires an Xcode UI-test target / test-scheme env configuration; cannot be safely scripted (see below).
- ◻️ **P2 #8-9** (rolling out the preview matrix, padding tokens): low value / re-evaluated (see below).

## Snapshot

**Strongest aspect:** The foundations are genuinely solid — zero-dependency core, JSON token pipeline (**0 hardcoded colors** in components), `EnvironmentKey`-based per-subtree theming (6 files), `ButtonStyle`-shaped style protocols (3 + 6 ButtonStyle), and leaf components are **100% binding-driven** (0 ObservableObject / 0 @StateObject across Atoms+Molecules). Force-unwraps are nearly absent (4 total, 0 `try!`/`as!`).

**Biggest risk (at audit time — ✅ RESOLVED):** The concurrency mode was pseudo-modern — tools 6.2 but `[.v5]`, 0 upcoming flags. **Migrated to Swift 6 language mode in P0 (#82)** (0 errors / 0 warnings); this risk is now closed. The largest remaining gap is the environment-dependent a11y audit (P1 #4).

**Single most critical task:** Migrate to Swift 6 language mode (P0) and fix the resulting isolation errors — this is the foundation the remaining frontier work (Observation, Liquid Glass) builds on.

## Category-based findings

| Category | Status | Evidence |
|---|---|---|
| Structure / modularity | **Solid** | 2 products, 0-dep core, 1 file/component, atoms29/molecules45/organisms43 (Package.swift, Sources/ThemeKit/Components/) |
| API surface | **Solid** | 844 public / 1466 private+fileprivate / 2 explicit-internal; leaves are binding-driven; `check-api.sh` gate on PRs (.github/workflows/ci.yml:57) |
| Token system | **Solid** | JSON generator (Theme/ThemeGenerator.swift); **0** `Color(red:/hex)` in components; all 6 `Color(hex:)` are in the engine (Theme/Shadows.swift:21-23,39 · Theme/Theme.swift:196,220) |
| Theming | **Solid** | `EnvironmentKey` across 6 files, `.theme(_:)` per-subtree (Theme/ThemeContext.swift); 3 style protocols (CardStyle.swift:29, StatStyle.swift:32, SelectStyle.swift:32) + 6 ButtonStyle |
| State / leaf hygiene | **Solid** | **0** ObservableObject/@StateObject across Atoms+Molecules; 5 ObservableObject only in organism *presenters* (Drawer/Tour/BottomSheet/Upload/Feedback.swift) — NO leaf-VM anti-pattern |
| Type erasure / measurement | **Solid** | 31 AnyView / 13 files (style erasure + heterogeneous organisms), 12 GeometryReader / 9 files (slider/progress measurement), **4** force-unwraps, 0 `try!`/`as!` |
| `#Preview` / slots | **Solid** | 102 `@ViewBuilder` slots, 114 `#Preview` |
| Documentation | **Solid** | DocC catalog + 6 articles (Sources/ThemeKit/Documentation.docc), `///` on 86 structs |
| CI / tooling | **Solid** | ci.yml + docs.yml, .swiftlint.yml + .swiftformat, api-breakage gate on PRs (ci.yml:57) |
| Accessibility | **Solid → code ready** | VoiceOver/RTL/Reduce Motion (**118**) + unit a11y tests; `performAccessibilityAudit` XCUITest **written** (Demo/DemoUITests/AccessibilityAuditTests.swift) — wiring up the UI-test target is the single manual Xcode step (docs/ACCESSIBILITY-AUDIT.md) |
| Test framework | **Partial → improving** | Swift Testing **piloted** (SwiftTestingPilot.swift — parameterized `@Test`/`#expect`, runs side by side with XCTest); the remaining 34 `XCTestCase` to be migrated opportunistically. Theming-injection regression test added. Snapshot still thin at 4 suites |
| **Concurrency (frontier)** | **Solid** ✅ | ~~tools 6.2 but v5~~ → **Swift 6 language mode** + 2 upcoming flags (NonisolatedNonsendingByDefault, InferIsolatedConformances); 0 errors / 0 warnings, 163 tests + Demo green (Package.swift) |
| **Observation (frontier)** | **Solid** ✅ | **8/8** `@Observable` — 5 presenters + FormValidator + **Theme** (core engine included). 0 `@Published`/`@ObservedObject`/`@EnvironmentObject`; `.id(theme.revision)` repaint preserved (revision tracked), runtime theme-switch verified in the simulator (Ocean render) |
| **Liquid Glass (frontier)** | **Solid** ✅ | `.glassChrome()` modifier (Extensions/GlassChrome.swift): `.glassEffect` on OS 26+, `Material` fallback 17–25, opaque fill under Reduce Transparency; adopted in Dialog + Drawer chrome. Gated & additive (iOS 17 min preserved) |
| Magic-number spacing | **Partial** | 34 literal `.padding(n)` (instead of tokens); e.g. Molecules/Tooltip.swift:196 `.padding(80)` |
| Preview state-matrix | **Partial** | A `PreviewMatrix` helper exists (Utils/PreviewMatrix.swift) but only 3/117 components adopt it (Tag/Stat/Avatar); most of the 114 previews are single-state |

## Action plan

### P0 — do first ✅ COMPLETED (in a PR)

> Migrated to Swift 6 language mode (`swiftLanguageModes: [.v6]`) + 2 upcoming flags. 46 strict-concurrency errors resolved with idiomatic fixes: `sending` parameter in 3 style erasure inits, `ThemeContext` `@EnvironmentObject`→`@Environment(\.theme)`, `DateField.text` `nonisolated`, `FormValidator` `@MainActor`. 0 errors / 0 warnings, 163 tests + Demo green.

**1. Migrate to Swift 6 language mode**
- **What:** Add `swiftLanguageModes: [.v6]` + `swiftSettings: [.swiftLanguageMode(.v6)]` to the `ThemeKit` target and fix the resulting strict-concurrency errors.
- **Why:** It currently declares tools 6.2 but compiles in v5 mode → concurrency safety isn't enforced; consumers compiling under Swift 6 may hit a wave of data-race warnings. The highest risk for a public library.
- **Effort:** L (1 line in Package.swift + likely dozens of `@MainActor`/`Sendable` fixes).
- **Files:** Package.swift (swiftLanguageModes/swiftSettings) → compiler-guided isolation fixes across Sources/ThemeKit.

**2. Add upcoming feature flags**
- **What:** `swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("InferIsolatedConformances")]`.
- **Why:** Adopt Swift 6.2's new isolation behaviors early; ships in the same PR as #1.
- **Effort:** S. **File:** Package.swift.

### P1 — high leverage

**3. `ObservableObject` → `@Observable` (Observation)** — ✅ COMPLETED (except Theme)
- **Done:** 5 presenters (Drawer/Tour/BottomSheet/Upload/Feedback) + FormValidator migrated to `@Observable`; 0 `@Published`, `@StateObject`→`@State`, presenter injection `.environmentObject`→`.environment` + reads via `@Environment(_.self)`. 163 tests + Demo (a real consumer, updated) green.
- **Theme also completed (separate PR):** `@Observable public final class Theme: @unchecked Sendable`; `objectWillChange.send()` removed (the revision bump triggers @Observable tracking), root `@ObservedObject`→plain `let` + `.environmentObject`→`.environment`, the single `@EnvironmentObject Theme` consumer moved to `@Environment(Theme.self)`. The `.id(theme.revision)` full-rebuild repaint was preserved. Verification: 163 tests + a revision-bump test + Demo rendering with the Ocean global theme (teal accent).

**4. Automated a11y audit (`performAccessibilityAudit`)** — ✅ CODE DELIVERED (target wiring is manual)
- **Done:** `Demo/DemoUITests/AccessibilityAuditTests.swift` — navigates the gallery + Theme Injection + Form/Select/DataTable/Steps pages via the `-openDemo` deep link and runs `performAccessibilityAudit()`. Setup doc: `docs/ACCESSIBILITY-AUDIT.md`.
- **Single remaining step (user):** Add a UI-test target in Xcode (cannot be done safely via a pbxproj script). The doc contains the exact steps; once the target is wired up, `⌘U` / `xcodebuild test`.

**5. Expand snapshot coverage**
- **What:** 4 suites → one reference per component group; `ScreenshotGenerator` already renders all of them, wire them to golden references.
- **Why:** 4 suites against ~117 components; visual protection for theming/regression is thin.
- **Effort:** M. **Files:** Tests/ThemeKitTests/Snapshot/.

**6. Liquid Glass adoption strategy (in chrome, gated)** — ✅ COMPLETED
- **Done:** `.glassChrome(in:)` modifier (Extensions/GlassChrome.swift) — `.glassEffect(.regular, in:)` behind `if #available(iOS 26, macOS 26)`, `Material` for OS 17-25, opaque token fill for Reduce Transparency. Applied to the Dialog card + Drawer panel chrome (neither is in the screenshot baseline → no churn). 163 tests + Demo (the iOS 26 glass branch actually compiles) green.
- **Deliberate scope:** Chrome only (floating panel/modal); the content layer was left untouched. Because FAB/Toast/NavigationBar are in the screenshot baseline, their defaults were not changed — consumers can apply `.glassChrome()` to whatever chrome they want.

### P2 — polish

**7. Swift Testing pilot** — write new tests with `@Test`/`#expect`, migrate the existing 34 XCTests gradually. **Effort:** S-M. **File:** Tests/ThemeKitTests/.

**8. Roll out `PreviewMatrix`** — 3 → more components with `#Preview("States")`. **Effort:** S (mechanical). **File:** across Components/.

**9. Bind magic-number paddings to tokens** — ◻️ RE-EVALUATED (largely invalid). There are 11 single-number `.padding(n)` sites; **7 of them are `#Preview` demo code** (Tooltip:196, BorderBeam:148/158, CountBadge:98 …) or **intentional fine values** (2, 6 — not mappable to a token). That leaves ~3 production sites (4, 8); converting them without verifying the token values risks shifting the layout. Low value / high risk — skipped.

## Quick wins (≤30 min)

- **Add the upcoming feature flags** (Package.swift `swiftSettings`) — P0#2, a single-line block.
- **Tooltip.swift:196 `.padding(80)`** → a `Theme.SpacingKey` token (the most obvious magic number).
- **A Swift version policy note in README/CHANGELOG** (manage consumer expectations until the tools 6.2 / language-mode target is settled).
- **The 3 hex shadows in `Theme/Shadows.swift`** are already tokenizable — consider moving them into the generator.

## Recommended order

1. **Swift 6 language mode + upcoming flags** (P0 #1-2) — the foundation; affects everything else.
2. **Observation (`@Observable`)** (P1 #3) — a natural fit with the concurrency mode; modernizes the presenters.
3. **A11y audit + snapshot expansion** (P1 #4-5) — lock down the modernization against regressions.
4. **Liquid Glass** (P1 #6) — add it to the chrome once the Swift 6 foundation + gated availability are ready.
5. **Swift Testing + preview matrix + padding tokens** (P2 #7-9) — polish, mechanical.

---

**Verdict:** Reference-grade on the classic design-system axis (zero-dep, token pipeline, style protocols, env-theming, DocC, CI, api-gate). On the 2026 frontier lens, the only **anti-pattern** was the concurrency mode (tools 6.2 / language v5); the remaining gaps (Observation, Liquid Glass, Swift Testing, a11y audit) are additive modernization — not architectural. No work was forced into the Solid categories.
