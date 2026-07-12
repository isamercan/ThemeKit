# ADR-0002 — On-media contrast & specular color (non-thematic white/black)

- **Status:** **Accepted** (2026-07-11)
- **Date:** 2026-07-11
- **Deciders:** ThemeKit architecture
- **Context source:** `THEMEKIT_COMPONENT_AUDIT.md` (v2) + architect review
- **Realization:** Rather than a new `SemanticColor` slot, category-A on-media contrast is realized by **extending the existing `MediaScrim` enum** (`Sources/ThemeKit/Utils/Effects.swift`) — which already carries the sanctioned no-raw-`Color` exemption — with `MediaScrim.onContent` / `.onContentSecondary`. Category-B specular highlights use the documented in-view `private static let` constant convention. Applied API-safely (body-only) in the P0.3 change set.

## Context

House rule 4 (token-fed) bans raw `Color` in component bodies. The audit found **~8 body-level `Color.white`/`.black` sites** that are flagged as violations but are **not straightforward token misses** — resolving them the naive way (swap for `theme.text(...)`) would be *wrong*, because these colors are intentionally **not derived from the active theme.** They fall into two distinct categories:

**A. On-media contrast (functional).** Content rendered over pixels the theme does not control — photos, video, or a darkening scrim. The correct color depends on the *media*, not the light/dark theme.
- `ImageCollage:61` — `+N` count over an image scrim
- `VideoPlayerView:172` — play/scrub glyphs over video
- `ScrubGallery:92` — page dots over imagery
- `LoyaltyCard` — QR quiet-zone background
- `PageHeaderStyle:457` — title in the `onImage` variant

**B. Specular / decorative highlight (physical metaphor).** A glare/glow that is white by optical metaphor, independent of theme.
- `TiltCard:130` — specular sheen gradient
- `BorderBeam:143` — comet-head hot spark
- `MeterStyle:170` — diagonal hatch overlay

The SKILL already anticipates non-thematic constants: *"Genuine dimensions with no semantic token … stay raw as fixed constants inside the view."* (`SKILL.md:127-129`). It just never extended the allowance to non-thematic **colors**, so the audit had no sanctioned way to score these and defaulted to ❌/🟡 — even while the report itself hedged (TiltCard "arguably decorative"). We need one rule so the fix is a coordinated sweep, not 8 independent judgment calls, and so CI can tell a real violation from a sanctioned one.

**Out of scope (separate handling):**
- `ThemePicker:104,:135` `Color(hex: theme.base)` — deliberately renders a *different* theme than the active one (preset previews). Not on-media, not specular → keep, add an explanatory comment; the CI gate must allow it.
- `Diff:78-80`, `ScrubGallery:149`, `KanbanBoard:202,210` — `.white` in `#Preview`/demo content, not shipped body. Not in scope.

## Decision

**Introduce a small on-media token set for category A, and sanction a named-constant convention for category B. Update the rubric + CI gate to allow both and ban only raw *inline* literals in body code.**

**A. On-media contrast token(s).** Add to the semantic palette:
```swift
// Resolves against media/scrim, not the light/dark theme.
theme.foreground(.onMedia)          // ≈ near-white, for content over dark media/scrim
theme.foreground(.onMediaSecondary) // dimmed on-media
// (or SemanticColor.onMedia / .onScrim — final naming per token owner)
```
Migrate the category-A sites to it. This keeps them theme-*coordinated* (one place to tune the scrim/contrast strategy, e.g. if a future high-contrast mode changes it) without pretending they follow `textPrimary`.

**B. Specular / decorative constant convention.** A non-thematic decorative color lives as a **named `private static let` inside the view, with a one-line comment**, never as an inline literal and never as a public modifier knob:
```swift
private static let specularHighlight = Color.white.opacity(0.35) // optical sheen — intentionally non-thematic
```
This mirrors the existing fixed-constant allowance for dimensions. Category B is done when the inline literal becomes a named constant.

**Rubric + CI update.** The token-fed axis and its CI grep gate:
- **PASS:** theme tokens, `SemanticColor`, the new `.onMedia*` tokens, and a named `private static let … = Color.…` decorative constant.
- **FAIL:** a raw `Color.white`/`.black`/`Color(hex:` **inline** in non-`#Preview` body code, or a raw `Color` in a public modifier signature (see the P0.2 signature fixes — separate from this ADR).
- **ALLOW-LISTED exception:** `Color(hex: theme.<preset>)` when rendering a non-active theme, if commented (ThemePicker).

## Consequences

- **8 checkboxes → 2 coordinated changes** (add token set; apply the naming convention), plus one rubric/CI edit. The sweep becomes mechanical.
- **Correctness:** on-media content stops masquerading as themed text; specular highlights stop masquerading as token violations. A future high-contrast / accessibility pass has one lever (`.onMedia*`) instead of 5 scattered whites.
- **Cost:** defining/naming the token(s) is a design-token-owner decision (the palette is generated — confirm where `.onMedia` slots into the token pipeline vs. a hand-added semantic). Until the token lands, category-A sites stay flagged.
- **Enforcement:** the CI grep gate distinguishes sanctioned (named constant / `.onMedia` / commented preset) from raw inline — so this class of finding can't silently regress.

## Alternatives considered

1. **Tokenize everything to `theme.text(.textPrimary)` etc.** Rejected: produces wrong results over media (a play icon over a bright photo would follow the theme and vanish) and couples decorative sheen to text color.
2. **Leave all 8 as raw literals, exempt them case-by-case in the audit.** Rejected: no shared rule → every future on-media component re-litigates it, and CI can't tell sanctioned from sloppy.
3. **Only a naming convention, no token (treat category A as decorative constants too).** Rejected for category A: on-media contrast is *functional* and benefits from one tunable source (high-contrast mode, scrim strength); a scattered constant per component loses that. Kept the convention for category B where there is genuinely nothing to centralize.

## Open questions

- ~~Final token name/namespace and where it enters the **generated** token pipeline~~ —
  **RESOLVED (2026-07-13).** On-media contrast is intentionally **non-thematic** (near-
  white/near-black *over media*, brand-independent — the same core reasoning that made
  specular highlights non-thematic), so it must **NOT** enter the *generated*,
  theme-derived palette (`ThemeGenerator`/`gen_tokens.py`) — that would make a
  brand-independent constant vary with the brand. The category-A token therefore lands
  as the already-shipping **centralized non-thematic constant `MediaScrim.onContent` /
  `.onContentSecondary`** (`Sources/ThemeKit/Utils/Effects.swift`), NOT a `SemanticColor`
  slot. This still satisfies alternative-3's requirement — *one tunable source* for a
  future high-contrast / scrim-strength lever — without misfiling it in the generated
  pipeline. No pipeline change; the realization is final.
- Whether `.onContent` needs a paired scrim/gradient recipe (many on-media designs need a
  darkening scrim behind the content to guarantee contrast) — kept as a deliberate
  **future** follow-up (a scrim-strategy ADR), not blocking; `MediaScrim` already owns
  the scrim gradients, so it is the natural home if/when that lands.
