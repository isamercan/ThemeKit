# ADR-0001 — "Core kind" in `init` vs. modifiers-only appearance

- **Status:** Proposed (needs design-system owner sign-off)
- **Date:** 2026-07-11
- **Deciders:** ThemeKit architecture
- **Context source:** `THEMEKIT_COMPONENT_AUDIT.md` (v2) + architect review
- **Supersedes / clarifies:** the informal `COMPONENT_REFACTOR_RULES R1–R7` convention and `.claude/skills/themekit-authoring/SKILL.md` rule 3

## Context

Two rules in the codebase disagree about whether a **`variant:` (or `kind:`) argument may appear in a component's `init`.**

1. **The authoring SKILL, rule 3** (written, authoritative for contributors): *"Every variant, size, flag, color and callback is a chainable modifier … **No `size:`/`variant:`/`isEnabled:` init args.**"*

2. **`COMPONENT_REFACTOR_RULES R1`** (referenced in code as "R1 — core kind + required data"): *the `init` takes only the **`variant` (core kind)** plus required data; every other axis is a chainable, order-free modifier.* Example in `ProgressIndicator.swift:31-56`:
   ```swift
   ProgressIndicator(variant: .video, current: 3, total: 5)   // R1 — core kind + required data
       .videoProgress(0.5).stepText(.slash).size(.large)
   ```

This is not a one-off. **~58 component files cite the R1 convention in their doc comments** (Badge, Icon, TextInput, RadioButton, FlightListItem, Timeline, …). Yet **`COMPONENT_REFACTOR_RULES` does not exist as a written document** — it lives only in comments — so contributors reading the SKILL and contributors following the code reach opposite conclusions. The audit flagged `ProgressIndicator` (init `variant:`) as a P0 hard-fail on this basis; `ButtonGroup`/`Join` (`axis:`), `ScoreBadge` (`large:`), and `ResultView` (`status:`) sit in the same tension.

The real question is not "modifier or init?" in the abstract, but **what class of argument `variant` is.** SwiftUI's own idiom keeps *identity* in the initializer (`ProgressView(value:)`, `Label(_:systemImage:)`) and *appearance* in modifiers/styles (`.progressViewStyle`). ThemeKit should pick the same seam deliberately.

## Decision

**Ratify a reconciled rule and write `COMPONENT_REFACTOR_RULES` down as a real doc; update SKILL rule 3 to cross-reference it.** The reconciled rule:

> **`init` carries content, required data, bindings, actions, and — at most — ONE "core-kind" enum that selects a fundamentally different *archetype* (different content model or layout structure), when that enum has a sensible default. Everything that merely *reskins the same archetype* — size, emphasis, color, state flags, on/off options — is a chainable copy-on-write modifier. Never both a `variant` init arg *and* a giant `switch` in the body: 3+ archetypes use the style-protocol pattern (SKILL §"Style-driven API"), not an init enum.**

**The archetype test** (decides every case): *Does the enum change the component's content model / layout structure, or does it only change how the same content is painted?*

- **Changes the archetype → allowed in `init` as the core kind.**
  `ProgressIndicator(variant:)` — `.video`/`.carousel`/`.progress` are structurally different bars with different data semantics. ✅ Stays.
- **Only reskins → must be a modifier.**
  `ScoreBadge(large:)` (a size flag), a color/emphasis `variant`. → `.controlSize(.large)` / `.variant(_:)` modifier.
- **Marginal (layout-orientation) → modifier**, because orientation reskins the same content rather than changing the content model.
  `ButtonGroup(axis:)`, `Join(axis:)`, `SeatLegend(perRow:)` → `.axis(_:)` / `.perRow(_:)`.
- **3+ archetypes → neither; use the style protocol.**
  `FlightListItem` (9 styles) already does this; new multi-archetype organisms follow it rather than growing an init enum.

**Escape-hatch rule:** where an init arg is being demoted to a modifier but call sites exist, add the modifier and `@available(*, deprecated, message: "Use .xxx()")` the init parameter — never a hard break.

## Consequences

**Immediately re-bucketed in the audit:**

| Component | Init arg | Test result | Action |
|---|---|---|---|
| `ProgressIndicator` | `variant:` | different archetypes | **Compliant — remove from P0**, keep init |
| `ResultView` | `status:` | drives content+color archetype (404 vs empty vs error) | Compliant — keep init; still fix the 72pt raw font separately |
| `ScoreBadge` | `large:` | size flag, reskin | → `.controlSize(.large)`, deprecate arg |
| `ButtonGroup`, `Join` | `axis:` | orientation, reskin | → `.axis(_:)` modifier, deprecate arg |
| `SeatCell` | `size:`/`isSelected:`/`display:`/`palette:` | all reskins/state | → modifiers (unchanged: still P0, still the worst offender) |
| `SeatLegend` | `palette:`/`perRow:` | reskins | → modifiers |

- **Positive:** the written SKILL and the 58 R1 call sites stop contradicting each other; contributors get one testable rule; SwiftUI-idiomatic identity-in-init is preserved; the audit's `variant:` findings resolve without 58 speculative rewrites.
- **Negative / cost:** one doc to write (`docs/COMPONENT_REFACTOR_RULES.md`), a one-line edit to SKILL rule 3, and re-verification that no cited "R1" component smuggles a *reskin* enum into init under the "core kind" banner (spot-audit the 58).
- **Enforcement:** a CI lint can flag any `public init` whose enum parameter is also settable by a modifier (the reskin smell), but the archetype test needs human judgment — keep it a review checklist item, not a hard gate.

## Alternatives considered

1. **SKILL wins literally — no enum ever in init; everything is a modifier (even `variant`).** Rejected: forces `ProgressIndicator().variant(.video)` with an invalid/empty default state before the modifier runs, is un-SwiftUI-like, and would churn 58 files for negative ergonomic value.
2. **R1 wins literally — any `variant`/`kind` in init is fine.** Rejected: re-opens the door to `size:`/`isEnabled:`/color `variant:` in init, which is exactly the anti-pattern the SKILL exists to prevent; loses the copy-on-write ergonomics the library sells.
3. **Leave it ambiguous.** Rejected: it is already producing false-positive audit findings and contributor confusion; the cost is paid continuously.

## Open questions

- Precise wording of the CI "reskin smell" lint (parameter also has a same-named modifier).
- Whether `perNRow`-style layout counts (`SeatLegend.perRow`, `ColumnsGrid` columns) are "structure" or "reskin" — the ADR classes them as reskin (→ modifier); confirm with a second reviewer.
