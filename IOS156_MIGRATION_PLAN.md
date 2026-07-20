# iOS 15.6 Deployment-Floor Migration Plan

**Author:** iOS Architect agent · **Date:** 2026-07-20 · **Status:** PROPOSED — awaiting sr-ios-dev pressure-test
**Companion docs:** `docs/ADR-0007-ios-15-6-deployment-floor.md` (the decision + policy — read it first), `docs/ADR-0006-per-subtree-theme-resolution.md` (invariants Phase 1 must preserve), `docs/CI.md` / `.github/workflows/ci.yml` (lane conventions).

## 1. Scope & ground rules

Lower `Package.swift` from `.iOS(.v17)` to `.iOS("15.6")`; macOS stays `.v14`. Policy per ADR-0007 §D2: **single-path** replacements where an iOS 15 construct has the same capability; **graceful-degrade** behind `if #available` for pure polish, with every legacy branch a *named internal unit* that snapshot/unit tests instantiate directly; **reimplement** for structural iOS 16 API (Charts, Layout). Ground rules for every wave:

- `Package.swift` stays at `.v17` until Phase 4 — the existing CI stays green throughout; the new **canary floor lane** (Phase 0) measures progress and flips to blocking at the end of Phase 3.
- PR-per-unit, worktree-isolated (MEMORY: repo-concurrent-agents-worktree). Each PR: run `make l10n` if any localizable string was added/shifted; regen `make skill`/llms only when public surface moved.
- Token-fed-modifier house rule holds inside rewrites — no raw `Color`/`CGFloat` knobs may appear in replacement code.
- **Verification gate per phase** (stated per phase below): the canary lane's error count strictly decreases and reaches zero for the phase's file set; global "builds green at the 15.6 floor" is achieved at the end of Phase 3 and becomes the permanent blocking gate in Phase 4.
- The inventory below is a **floor, not ground truth** (ADR-0007 §Context): every phase ends with a fix→rebuild→fix loop against the canary lane to flush unknown-unknowns (the `ColorContrast.swift` class of finding).

## 2. Verified inventory → treatment (locked at Phase 0)

Counts verified 2026-07-20 by grep + `swiftc -typecheck -target arm64-apple-ios15.6-simulator` probes. ✅ = matches the initiating audit; ⚠️ = corrected or newly found here.

| API | Floor | Sites | Files | Treatment | Phase |
|---|---|---|---|---|---|
| `.onChange(of:) { old, new in }` | 17 | 40 (of 53 total `.onChange`) ✅ | ~30 | single-path: internal `onChangeCompat` modifier | 2 |
| `.snappy` / `.smooth` / `.spring(.smooth)` ⚠️ **new** | 17 | 12 | 10 | single-path: `ThemeMotion` spring presets | 2 |
| `.symbolEffect(.bounce)` | 17 | 5 code ✅ | 5 | degrade (`#available(iOS 17)`) via `MicroMotion` | 2 |
| `.scrollTargetBehavior`/`Layout`/`.scrollPosition`/`.scrollClipDisabled` | 17 | 8 ✅ | 3 | degrade — plain scroll below 17 | 2 |
| `.contentTransition` ⚠️ (modifier is **16**, `.numericText(value:)` is 17) | 16/17 | 5 | 5 | degrade at each API's true floor | 2 |
| `.onKeyPress` ⚠️ new | 17 (macOS 14 ok) | 4 | 1 (`CommandPalette`) | degrade — touch-only below 17 | 2 |
| `.scrollContentBackground(.hidden)` | 16 | 1 ✅ | 1 (`MultiLineTextInput`) | degrade + `UITextView.appearance` legacy unit | 2 |
| `Task.sleep(for:)` ⚠️ new | 16 | 1 | 1 (`CodeBlock:120`) | single-path: `sleep(nanoseconds:)` | 2 |
| `Locale.Language` ⚠️ new | 16 | 2 | 1 (`LanguageSwitcher:58`) | single-path: iOS-15 `Locale` parsing | 2 |
| `TextField(axis:)` + `lineLimit(3...6)` ⚠️ new | 16 | 2 | 1 (`Mentions`) | degrade: TextEditor-based legacy unit | 2 |
| `@Observable` | 17 | 8 declarations ⚠️ (2 Core + 5 presenters + `FormValidator`; `ThemeContext`/`ThemeKit` hits are comments) | 8 | single-path: `ObservableObject` (ADR-0007 §D3) | 1 |
| Object-form `.environment(obj)` / `@Environment(Type.self)` ⚠️ new | 17 | ~30 preview + 3 host + 10 read sites | ~35 | keypath env + `.environmentObject` | 1 |
| `Color.resolve(in:)` ⚠️ (only real site; other `…Resolved` grep hits are ThemeKit's own `SemanticColor.Resolved`) | 17 | 1 | 1 (`ColorContrast.swift:49-52`) | single-path: `UIColor`/`NSColor` bridge | 1 |
| `Layout` conformances (`FlowLayout` public, `Masonry`, `Flex`) | 16 | 3 ✅ | 3 | reimplement (measured wrap) | 3a |
| `AnyLayout` | 16 | 4 ✅ | 2 (`AnchorNav`, `Splitter`) | single-path: conditional H/V stacks | 3a |
| `Grid`/`GridRow`(+`gridColumnAlignment`/`gridCellUnsizedAxes`) ⚠️ **1 file, not 10** (audit likely counted iOS-14-safe `LazyVGrid`/`GridItem`) | 16 | 6 | 1 (`BoardingPassStyle`) | reimplement: aligned rows | 3b |
| `ViewThatFits` | 16 | 13 ✅ | 4 | single-path: measured-fit helper | 3c |
| `Charts` framework | 16 | 6 imports, ~31 `Chart` uses ⚠️ (>9) | 6 | reimplement: `Canvas`/`Path` | 3d |
| `.presentationDetents`/`DragIndicator` | 16 | 4 ✅ | 2 (`BottomSheet`, `PhoneField`) | degrade → custom sheet chrome | 3e |
| `.presentationBackground`/`.presentationCornerRadius` ⚠️ new | 16.4 | 5 | 1 (`BottomSheet:177-194` — its comment even cites the 17/14 floor) | degrade with the detents branch | 3e |
| `Gauge` + `.gaugeStyle(.accessoryCircular/Linear)` | 16 | ~14 ✅ | 1 (`GaugeView`) | reimplement: ring/linear drawing | 3e |
| `ShareLink` | 16 | 2 ✅ | 1 (`ShareButton`) | degrade: `UIActivityViewController` legacy unit (macOS keeps `ShareLink`) | 3e |
| `.draggable`/`.dropDestination` ⚠️ new | 16 | 3 | 1 (`KanbanBoard`) | single-path: `onDrag`/`onDrop` (NSItemProvider) | 3e |
| `UnevenRoundedRectangle` ⚠️ new | 16 | 9 | 5 | single-path: Core `Shape` polyfill | 3e |
| `Regex<Output>` public API ⚠️ new | 16 | 1 | 1 (`Validation.swift:97`) | keep, annotate `@available(iOS 16, *)` | 3e |
| `Color…gradient` (`AnyGradient`) ⚠️ new | 16 | 1 (preview-only, `Mask.swift:73`) | 1 | swap in preview | 3e |
| `#Preview` macro itself (388 blocks / 266 files) | — | — | — | typechecks clean at 15.6 — no work ✅ | — |
| `@Previewable` (inline preview `@State`) ⚠️ **new — Phase 1 compile-loop finding; the `swiftc -typecheck` probe missed the macro path, so this was NOT in ADR-0007's "#Preview clean" claim** | 17 | **147** | many | single-path: wrap inline `@Previewable @State` in a `Demo` wrapper `View` (the pattern most previews already use) — must land BEFORE the file-partitioned zones B/C to avoid preview-body merge conflicts | 2 |

Not found (probed for, zero hits): `sensoryFeedback`, `PhaseAnimator`/`KeyframeAnimator`, `NavigationStack`, `ContentUnavailableView`, `fontDesign`, `lineLimit(reservesSpace:)`, toolbar-visibility forms, `PhotosPicker`, `LabeledContent`, native `Table` (`DataTable`/`KeyValueTable` are custom), `ImageRenderer`, parameter packs, `@Bindable`. `AttributedString`/`FormatStyle` uses look 15-safe — the compile loop is the oracle.

---

## Phase 0 — Guardrail + inventory lock (S, ~1–2 days)

**Goal:** the canary floor lane exists and reports a baseline error count; ADR-0007 merged; the §2 table frozen as the work ledger.

Units (one PR):
1. Merge `docs/ADR-0007-ios-15-6-deployment-floor.md` (+ this plan).
2. Add the **`ios-floor`** job to `.github/workflows/ci.yml` (sketch below). Advisory while `Package.swift` is at `.v17` (`continue-on-error: true`); the error count is the migration burndown metric, surfaced in the step summary.
3. **Spike (timeboxed ½ day):** (a) confirm `IPHONEOS_DEPLOYMENT_TARGET` override propagates to SwiftPM targets under the current xcodebuild — else wire the `sed` fallback shown below; (b) confirm the oldest installable simulator runtime on the CI image (`xcodebuild -downloadPlatform iOS -buildVersion 16.4` expected); (c) record both findings in `docs/CI.md`.

```yaml
  # ---------------------------------------------------------------------------
  # iOS 15.6 floor gate (ADR-0007 §D5). Compile-time availability checking is
  # the airtight guardrail — no iOS 15.x simulator runtime can run under the
  # tools-6.2 toolchain, so the FLOOR is proven by the compiler and the legacy
  # #available branches are proven by direct snapshot/unit coverage (D2 rule 3).
  # ADVISORY (continue-on-error) until the Package.swift floor flips in Phase 4;
  # then drop continue-on-error + the override and it becomes the plain build.
  # PR-only, same cost policy as the ios job.
  # ---------------------------------------------------------------------------
  ios-floor:
    name: Build at iOS 15.6 floor (canary)
    if: github.event_name == 'pull_request'
    runs-on: macos-15
    continue-on-error: true            # ← REMOVE in Phase 4
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/swift-setup
        with:
          cache-key: ios-floor
      # While the manifest still says .v17, force the floor for this build only.
      # Spike decides: build-setting override (preferred) or the sed fallback:
      #   sed -i '' 's/\.iOS(\.v17)/.iOS("15.6")/' Package.swift   # CI-local, never committed
      - name: Build for iOS Simulator at the 15.6 floor
        run: |
          set -o pipefail
          xcodebuild build \
            -scheme ThemeKit-Package \
            -destination 'generic/platform=iOS Simulator' \
            IPHONEOS_DEPLOYMENT_TARGET=15.6 \
            2>&1 | tee floor.log | xcbeautify --quiet || true      # advisory phase
          ERRORS=$(grep -c ' error: ' floor.log || true)
          echo "### iOS 15.6 floor canary — $ERRORS availability errors remaining" >> "$GITHUB_STEP_SUMMARY"
      # Phase 4 addition (same job): test on the oldest installable runtime so the
      # #available(iOS 17) false-branches execute for real:
      #   xcodebuild -downloadPlatform iOS -buildVersion 16.4
      #   xcodebuild test -scheme ThemeKit-Package \
      #     -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.4'
```

**Verification gate:** lane runs on a PR and reports the baseline error count (the compiler-measured true size of the job). No source changes yet.

---

## Phase 1 — Core unblocking gate (L, ~3–5 days, single agent, sequential)

**Goal:** `ThemeKitCore` + the observation layer compile clean at the 15.6 floor with ADR-0006 invariants intact. **This phase blocks everything downstream** — the compiler stops in Core before it ever reaches the 226 components, so no Phase 2/3 work can even be error-listed until Core is clean.

Units (in order; ADR-0007 §D3 is the spec):

| # | Unit | Files | Notes |
|---|---|---|---|
| 1.1 | `Theme` → `ObservableObject`; `@Published private(set) var revision`; keypath injection in `.themeKit()` + `ThemedHostingController` | `ThemeKitCore/Theme/Theme.swift`, `ThemeKit.swift` (`ThemeKitModifier` gains `@ObservedObject`), `ThemedHostingController.swift:26` | The regression that must hold: runtime `Theme.shared` swap rebuilds the tree (revision test), `.theme(brandB)` subtree renders brandB accents (ADR-0006 two-brand snapshot), `scripts/check-theme-shared.sh` passes |
| 1.2 | `ThemeKitStrings.Revision` → `ObservableObject`; drop `import Observation` | `ThemeKitCore/ThemeKitStrings.swift:42,91` | Live-language-switch test (ADR-0003 suite) is the gate |
| 1.3 | `ColorContrast.components(of:)` → platform bridge (`UIColor(color).getRed…` / `NSColor.usingColorSpace(.sRGB)`) | `ThemeKitCore/ColorContrast.swift:49-52` | `ContentContrastTests`/`ColorModelsTests` must pass with identical values on macOS `swift test` — the bridge must match `resolve(in:)` output for the token colors |
| 1.4 | **Core compile loop:** canary build until `ThemeKitCore` is error-free — fixes any Core unknown-unknowns on the spot | `Sources/ThemeKitCore/**` | The `ColorContrast` lesson institutionalized |
| 1.5 | Presenters → `ObservableObject`: `SheetPresenter`, `DrawerPresenter`, `FeedbackPresenter`, `TourController`, Upload store; hosts inject `.environmentObject`; internal `@Environment(X.self)` reads → `@EnvironmentObject` | `ThemeKit/Components/Organisms/BottomSheet.swift`, `Drawer.swift`, `Feedback.swift`, `Tour.swift`, `Upload.swift`, `FeedbackDefaults.swift:135` | Doc-comment recipes updated (`@State`→`@StateObject`, `@Environment(X.self)`→`@EnvironmentObject`); `.api-breakage-allowlist.txt` entries for the `Observable` conformance removals; CHANGELOG migration block drafted **in the same PR** |
| 1.6 | `FormValidator` → `ObservableObject` + `@Published` | `ThemeKit/Validation/FormValidator.swift:23` | Generic + `@MainActor` isolation check (ADR-0007 open question); form demo drives it |
| 1.7 | Preview injection sweep: `.environment(Theme.shared)` → `.environment(\.theme, Theme.shared)` | ~30 `#Preview` sites (Affix, Masonry, Flex, Splitter, Transfer, …) | Pure mechanical; can ride 1.1's PR or a follow-up |

**Effort:** L. **Parallelizable:** no (Core is one dependency spine; 1.5–1.7 could split off after 1.4).
**Verification:** builds green on iOS 15.6 — for `ThemeKitCore` entirely and for the 8 observation files; canary error count now measures only component-land. Snapshot suite (`RUN_SNAPSHOTS`) green on the modern sim; theme-swap + two-brand + language-switch tests green; `check-theme-shared.sh` green.

---

## Phase 2 — Bucket A mechanical sweep (M, ~2–3 days wall-clock, 3 parallel agents)

**Goal:** every iOS-17-convenience call site gated or swapped. Disjoint file zones → parallel `sr-ios-dev` agents (worktrees):

- **Zone A — shared helpers first (sequential prerequisite, ~½ day):** add internal `onChangeCompat(of:_:)` (two-param semantics back-deployed: `#available(iOS 17)` native, else one-param + `@State` previous-value capture) in `ThemeKit/Utils/`; add `ThemeMotion` spring presets replacing `.snappy`/`.smooth` (`.spring(response:dampingFraction:)` equivalents, composed with `ifMotionAllowed` — `ThemeMotion.swift` is already the home) — tokens, not inline literals.
- **Zone B — neutral catalog (`Sources/ThemeKit/**`):** ~30 `.onChange` sites → `onChangeCompat`; snappy/smooth sites (`AmenityGrid`, `AnchorNav`, `TreeView`, `InstallmentSelector`, `Cascader`, `PriceHistogram`, `LoyaltyCard`, `ReviewCard`); `.contentTransition` gates (`OTPInput`, `PointsBadge`, `TextRotate`, `PriceTag`, `LoyaltyCard`); `DestinationCard` symbolEffect; `CommandPalette` onKeyPress; `MultiLineTextInput` scrollContentBackground (+ named legacy unit, snapshot-pinned); `CodeBlock` sleep; `LanguageSwitcher` Locale parsing; `Mentions` TextField(axis:) legacy unit.
- **Zone C — Travel edition (`Sources/ThemeKitTravel/**`):** symbolEffect gates (`FlightTicketCardStyle`, `FlightResultRowStyle`, `FlightCardStyle`, `FlightListItemStyle`); scrollTarget cluster (`PaymentMethodSelectorStyle`, `SavedCardsListStyle`, `FilterBarStyle`); `SeatMap` snappy; Travel `.onChange` sites.

**Verification:** builds green on iOS 15.6 for all Phase-2 files (canary burndown ≈ Bucket C only); every degrade branch has a named legacy unit + snapshot; Reduce-Motion behavior unchanged (MicroMotion tests); `-openDemo` spot checks on the modern sim for OTPInput/PriceTag/FilterBar.

---

## Phase 3 — Bucket C reimplementations (parallel sub-waves after Phase 2)

Sub-waves 3a/3b/3c/3e have **disjoint file sets** and can run as 4 parallel agents; 3d (Charts) is self-contained and the long pole — start it first. Cross-wave overlaps to sequence: `Drawer.swift`/`DatePriceStripStyle.swift`/`PriceTrendChart.swift` appear only in 3e's polyfill list (no true conflict); `AnchorNav` is 3a's (its snappy site lands in Phase 2 first).

### 3a — Custom Layout + AnyLayout (M, ~2–3 days)
- **Files:** `ThemeKit/Components/Molecules/FlowLayout.swift` (public `Layout` conformance), `Masonry.swift`, `Flex.swift`, `AnchorNav.swift`, `Splitter.swift`.
- **Replacement:** wrap/masonry/flex become measured layouts (width-preference + manual row packing — the classic pre-16 flow-layout technique); keep type names and init/modifier shapes so `FlowLayout(spacing:) { … }` call sites compile unchanged as a `View`. The dropped public `Layout` conformance is an allowlisted API change (ADR-0007 §D4). `AnyLayout` sites → explicit `if axis == .horizontal { HStack … } else { VStack … }` (note in code: loses the animated cross-fade between orientations — acceptable, Reduce-Motion-safe).
- **Risks:** Dynamic-Type reflow and RTL mirroring in manual packing — snapshot both (`docs/RTL-SUPPORT.md` matrix).
- **Verification:** builds green on iOS 15.6; FlowLayout/Masonry/Flex snapshots ≈ pixel-stable vs. current references; `-openDemo "Flow Layout"` etc.

### 3b — Grid → aligned rows (S, ~½–1 day)
- **Files:** `ThemeKitTravel/Components/Organisms/BoardingPassStyle.swift` (the only Grid file — corrected inventory).
- **Replacement:** two-column label/value rows via fixed-width leading column (`ScaledMetric`-driven) or `LazyVGrid(columns:)` (iOS 14) — pick per visual fidelity in snapshots.
- **Verification:** builds green on iOS 15.6; BoardingPass snapshot (LTR+RTL, XL type).

### 3c — ViewThatFits → measured fit (M, ~1–2 days)
- **Files:** helper in `ThemeKit/Utils/` + `ThemeKit/Components/Organisms/AlertDialog.swift`, `ThemeKitTravel/…/TripSearchCard.swift`, `TripSearchCardStyle.swift`, `PassengerForm.swift` (13 uses).
- **Replacement:** one internal `AdaptiveFit` helper — hidden measurement of the preferred child (background `GeometryReader` + width preference) choosing preferred/compact; re-evaluates on Dynamic Type + width changes. All 13 sites migrate to it (single idiom, single test surface).
- **Risks:** measurement loops / first-frame flicker — pin with a layout test; most sites are two-alternative (wide vs. stacked), keep the helper two-slot, not variadic.
- **Verification:** builds green on iOS 15.6; snapshots at .medium/.accessibility3 type sizes, narrow/wide widths.

### 3d — Charts → Canvas rendering (L–XL, ~4–6 days — the long pole)
- **Files:** `ThemeKit/Components/Molecules/Charts/`: `BarChart.swift`, `LineChart.swift`, `AreaChart.swift`, `DonutChart.swift`, `ChartSupport.swift`, `ChartModels.swift` (~31 `Chart{}`/`Chart(` uses).
- **Replacement:** single-path `Canvas`/`Path` renderers behind the **unchanged public inits/modifiers and `ChartModels` data types** (incl. the ADR-0006 `ChartColorScale(series:theme:)` threading). In-repo precedent to mirror: `PriceTrendChart`/`PriceHistogram` are already custom-drawn. Scope discipline: reproduce the *currently used* mark/axis/legend features only — this is not a Swift-Charts clone; enumerate the used features from `ChartSupport.swift` as the acceptance list before writing code.
- **Risks:** axis-label layout + accessibility (`accessibilityChartDescriptor` is unavailable pre-16 → provide the existing a11y summary path unconditionally); render-visible by definition → **full snapshot re-record for chart components** (LTR/RTL, light/dark), called out in the PR.
- **Verification:** builds green on iOS 15.6; re-recorded snapshots reviewed side-by-side vs. old references; `-openDemo "Bar Chart"` / "Line Chart" / "Donut Chart" screenshots.

### 3e — Detents / Gauge / Share / drag-drop / shape polyfill (M–L, ~2–4 days)
- **Units (each PR-able):**
  1. `ThemeUnevenRoundedRect` polyfill `Shape` in Core (per-corner radii via `Path`) + swap 9 sites: `PriceTrendChart`, `Drawer`, `PageHeaderStyle`, `PhoneFrame`, `DatePriceStripStyle` (single-path).
  2. `BottomSheet.swift:148-194`: `#available(iOS 16.4)` native detents/background/cornerRadius path, else the organism's own overlay chrome as the named legacy unit (the component already owns custom sheet chrome — route, don't rebuild); `PhoneField.swift:376` inherits the same treatment (full-height sheet below 16).
  3. `GaugeView.swift`: replace native `Gauge`+accessory styles with token-fed ring (`Canvas`/`Path`) and linear (ProgressBar-derived) drawings — single-path, keeps `gaugeStyle(_:)` modifier shape.
  4. `ShareButton.swift`: `#if os(iOS)` + `#available(iOS 16)` → `ShareLink`, else `UIActivityViewController` presentation legacy unit; macOS path keeps `ShareLink` (macOS 14 ≥ 13 floor — no gate needed).
  5. `KanbanBoard.swift:96-109`: `.draggable`/`.dropDestination` → `onDrag`/`onDrop` + `NSItemProvider` (single-path; String payload ports 1:1).
  6. `Validation.swift:97`: annotate `matches(_ regex: Regex<Output>…)` `@available(iOS 16.0, *)` (API kept, no break). `Mask.swift:73` preview `.blue.gradient` → plain fill.
- **Verification:** builds green on iOS 15.6 — **canary error count reaches 0 here; flip `ios-floor` to blocking (remove `continue-on-error`)**; BottomSheet legacy chrome snapshot; KanbanBoard drag demo on sim.

---

## Phase 4 — Floor flip, full regression, release (M–L, ~2–4 days)

1. **Flip `Package.swift`** → `.iOS("15.6")`; `ios-floor` job drops the override + `continue-on-error` and gains the oldest-runtime test step (Phase 0 sketch); existing `ios` lane unchanged (modern-runtime coverage).
2. **Full regression:** `swift test` (macOS), iOS-sim tests on modern + oldest-installable runtimes, `RUN_SNAPSHOTS` full suite (incl. all new legacy-branch snapshots), RTL + Dynamic Type spot matrix on 3a/3b/3c/3d output, a11y audit spot-pass (`docs/ACCESSIBILITY-AUDIT.md` method), `check-theme-shared` / `variant-naming` / `neutrality` / `api-breakage` all green.
3. **Demo app:** bump `IPHONEOS_DEPLOYMENT_TARGET` 17.0 → 15.6 (`Demo/Demo.xcodeproj`, 2 build configs) and sweep demo-only modern API with plain `#available` gates (Demo is not under the library's compat rules; the Showcase hero may stay 17-gated). This makes the Demo double as the consumer-on-15.6 proof and keeps `-openDemo` deep-link verification meaningful on old devices. If the sweep balloons, it may split into its own follow-up PR without blocking the release.
4. **Docs & release:** README platform badge + installation guide (website) → "iOS 15.6+ / macOS 14+"; `make skill` regen (llms/docs carry the floor); CHANGELOG 1.3.0 with the §D4 migration block (`@State`→`@StateObject` / `@Environment(X.self)`→`@EnvironmentObject` front and center); `.api-breakage-allowlist.txt` finalized; optional physical iOS 15.7 device smoke (ADR-0007 §D5); tag **v1.3.0**.

**Verification:** the permanent gate set — blocking `ios-floor` build + oldest-runtime tests + full snapshot suite — green on the release commit.

---

## Effort & sequencing summary

| Phase | What | Effort | Parallel? |
|---|---|---|---|
| 0 | CI canary lane + ADR + inventory lock + runtime spike | S (1–2 d) | — |
| 1 | Core observation + ColorContrast + presenters (**the gate**) | L (3–5 d) | No (spine) |
| 2 | Bucket A mechanical sweep | M (2–3 d wall) | 3 agents (zones A→B∥C) |
| 3a | Layout/AnyLayout | M (2–3 d) | ┐ |
| 3b | Grid (1 file) | S (½–1 d) | │ 4 agents, |
| 3c | ViewThatFits helper | M (1–2 d) | │ disjoint files |
| 3d | Charts → Canvas (**long pole**) | L–XL (4–6 d) | │ (start 3d first) |
| 3e | Detents/Gauge/Share/drag/polyfill | M–L (2–4 d) | ┘ |
| 4 | Floor flip + regression + Demo + release 1.3.0 | M–L (2–4 d) | Partially |

**Total: ~17–29 agent-days (~3.5–6 weeks single-agent; ~2.5–3.5 weeks wall-clock with the Phase 2/3 parallelization).** Biggest schedule risk: Phase 3d scope creep (hold the "currently used features only" acceptance list). Biggest correctness risk: Phase 1 (everything depends on it, and it carries the consumer-visible observation-pattern change — ADR-0007 §D4 Exception 2).

## Open items for sr-ios-dev (beyond ADR-0007's list)

- Confirm the deployment-target override propagates to package targets (else wire the `sed` fallback) and pin the oldest installable runtime on the CI image — Phase 0 spike, first PR.
- Pressure-test `onChangeCompat` with a concrete call site that needs `oldValue` under rapid updates (`@State` previous-value capture ordering).
- Enumerate `ChartSupport.swift`'s actually-used Chart features into the 3d acceptance list before estimating 3d further — if it exceeds L–XL, escalate with the ADR's documented escape hatch (16+-gating Charts) as the fallback decision to bring back to the architect.
- Verify `xcbeautify` availability on the runner for the canary log parsing (or use plain grep on the raw log, matching existing `ci.yml` style).
