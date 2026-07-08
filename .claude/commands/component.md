---
description: Scaffold a new ThemeKit component (atom/molecule/organism) following the authoring conventions
argument-hint: <Name> [atom|molecule|organism] [one-line description]
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, Skill
---

Scaffold a new ThemeKit component. Request: **$ARGUMENTS**

Follow the library's authoring conventions exactly — do not invent a new shape.

## 1. Load the conventions
Read the `themekit-authoring` skill (`.claude/skills/themekit-authoring/SKILL.md`) and
its `references/patterns.md`. The 6 house rules and the matching template there are
binding: stateless & data-driven, brand-neutral, init=content / modifiers=appearance
(copy-on-write), token-fed (no raw `Color`/magic numbers), native `.controlSize`/
`.disabled`, a11y + RTL + localization by construction.

## 2. Decide the tier & location
- If the request names a tier (atom/molecule/organism), use it; otherwise infer:
  smallest reusable unit → **atom**; a few atoms + light logic → **molecule**; the
  shipped, composed component → **organism**.
- Place the file in `Sources/ThemeKit/Components/{Atoms|Molecules|Organisms}/<Name>.swift`.
- If it will need several fundamentally different layouts, use the **style-driven**
  pattern (`references/patterns.md §3`) and split styles into `<Name>Style.swift`.
- Models / a generic palette go in `<Name>Models.swift`.

## 3. Generate the component
Copy the matching template from `references/patterns.md` (§1 atom, §2 molecule,
§3 style-driven organism), rename, and implement the requested behavior. Before
adding any color/spacing/radius, confirm the token exists — grep a sibling component
in the same folder for the exact token key (`theme.background(.bg…)`,
`Theme.SpacingKey`, `Theme.RadiusRole`, `.textStyle(...)`). Reuse existing atoms
(`Badge`, `PriceTag`, `Icon`, `DividerView`, …) rather than re-drawing them. All
user-facing strings: `String(localized: "…", bundle: .module)`, English only, generic
(no ets/Voyage/domain data).

## 4. Preview + demo
- Add a `#Preview` that iterates **every** variant (e.g. `ForEach(<Enum>.allCases…)`)
  plus a themed/dark case, and injects `.environment(Theme.shared)`.
- Register an interactive demo: open the matching `Demo/Demo/Gallery/Demos/{Atom|Molecule|Organism}Demos.swift`,
  read a neighboring demo to match the style, and add a `struct <Name>Demo: View` using
  `ComponentStage("<Name>", inspector: […]) { <component> } knobs: { … }` with live
  `@State` knobs for each modifier. Wire it into the gallery list the same way the
  siblings are wired.

## 5. Verify (don't skip)
- Build: `swift build` (or the repo's `make` target) — fix all errors/warnings.
- Run SwiftFormat/SwiftLint if configured (`.swiftformat`, `.swiftlint.yml`).
- Launch the demo by deep-link and screenshot instead of tapping through:
  `xcrun simctl launch <bundle> -startTab 0 -openDemo "<Name>"`.
- Walk the **"Before opening a PR"** checklist at the end of the skill; report each
  item as pass/fail.

## 6. Report
Summarize: files created, tier chosen, modifiers exposed, tokens used, and the
checklist result. Flag anything that needed a token that doesn't exist yet (don't
hardcode a literal to work around it — surface it).
