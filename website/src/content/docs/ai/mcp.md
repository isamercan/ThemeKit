---
title: MCP Server
description: Give your AI editor on-demand tools that generate correct, token-bound ThemeKit code — including Figma → SwiftUI.
---

ThemeKit is built for the AI-assisted workflow. Its **MCP server** exposes the
components, modifiers, tokens, and 32 theme presets as **on-demand tools**, so an
MCP-compatible editor (Claude Code, Cursor, Windsurf…) pulls accurate, focused
context while it codes — instead of guessing APIs or hardcoding colors.

:::tip[Single source of truth]
The server's data (`data/themekit.json`) is built from the **DocC symbol graph**
(precise init params, types, defaults, modifiers) plus the bundled **theme JSON**.
Nothing is hand-maintained, so the tools can't drift from the library.
:::

## Install

```sh
claude mcp add themekit -- npx -y @isamercan/themekit-mcp
```

Or from the repo:

```sh
cd mcp && npm i && npm run build
```

Then just ask your agent:

> Build a sign-up screen. Use the ThemeKit MCP.

Works with **Claude Code, Cursor, Windsurf, GitHub Copilot**, and any tool that
supports MCP.

## What you get

24 on-demand tools, in three groups.

### Read — context (kills hallucinated APIs)

| Tool | Returns |
|---|---|
| `get_component_api(name)` | The **exact** init params (label, type, default, required) and modifiers — from the symbol graph |
| `get_design_tokens(category?)` | Tokens with **real values** — colors, radius, spacing, typography, semantic colors |
| `list_components(category?)` | Components by Atom / Molecule / Organism |
| `search_components(intent)` | Intent search — "a selectable filter list" |
| `get_usage_snippet(name, variant?)` | A copy-paste example (basic / full) |
| `get_migration_guide(from, to?)` | What changed between two versions, from the CHANGELOG |

### Act — generation

| Tool | Does |
|---|---|
| `compose_screen(components, …)` | Builds a token-bound screen from an **ordered, catalog-verified** component list |
| `scaffold_screen(kind)` | A starter form / list / detail / settings screen |
| `validate_code(swift)` | Anti-patterns + **hallucinated-component detection** + brace balance + PASS/FAIL |
| `lint_snippet(swift)` | Flags hardcoded colors / radius / fonts / padding |
| `a11y_audit(swift)` | Missing `.a11yID`, unlabeled icons, hardcoded colors, + a WCAG contrast hint |
| `migrate_snippet(swift)` | Rewrites plain SwiftUI toward ThemeKit (config-driven) |
| `render_preview(component, dark?)` | The component's **rendered PNG**, light or dark |
| **`design_to_code(url …)`** | **Figma node → ThemeKit SwiftUI** — see below |

### Themes

`list_themes` · `theme_colors(id)` · `generate_theme(...)` · `diff_theme(a, b)`
(per-channel CIE76 ΔE) · `theme_preview(id)` (PNG swatch) ·
`design_md_to_themeconfig(...)` (see [DESIGN.md](../design-md/)).

## Figma → SwiftUI

The star tool, **`design_to_code`** (alias `figma_to_swiftui`), turns a Figma node
into ThemeKit SwiftUI with **verified** APIs instead of guesses. It snaps
fills / spacing / radius to design tokens, maps nodes to components
(config-driven via `figma-mapping.json`, then heuristics), and returns the code
plus a mapping report. Unmapped nodes are flagged — never silently dropped.

Just paste a Figma link and ask:

```text
Use the themekit MCP. Convert this Figma node to ThemeKit SwiftUI:
https://www.figma.com/design/<FILE_KEY>/App?node-id=<NODE-ID>
```

It returns token-matched, verified-API code with a report:

```swift
Card {
    VStack(spacing: Theme.SpacingKey.md.value) {
        Badge("Sale").badgeStyle(.error)
        PrimaryButton("Continue") { }
        // ⚠️ unmapped: Mystery Widget (INSTANCE)
    }
}
// 3/4 nodes mapped · fill #f04438 → fg-error (ΔE 0.0) · itemSpacing 16 → sp-md
```

:::note
`design_to_code` needs `FIGMA_TOKEN` set in the server's env (`export
FIGMA_TOKEN=figd_…`) — it's **optional**, only this tool needs it. Add `dryRun:
true` for just the mapping plan, or `a11yOnly: true` for just the accessibility
audit. See [`mcp/README.md`](https://github.com/isamercan/ThemeKit/blob/main/mcp/README.md) for the full tool list and the `figma-mapping.json` schema.
:::

## Other AI surfaces

One source feeds three surfaces so they can't drift:

- **Agent skill** ([`skills/themekit/`](https://github.com/isamercan/ThemeKit/tree/main/skills/themekit)) — a Claude Code skill with idioms, every component's init & modifiers, and the presets. Install: `/plugin marketplace add isamercan/ThemeKit` → `/plugin install themekit@themekit`, or copy `skills/themekit/` into `.claude/skills/`.
- **`llms.txt`** ([repo root](https://github.com/isamercan/ThemeKit/blob/main/llms.txt)) — structured LLM context following the [llms.txt](https://llmstxt.org) standard; point any `llms.txt`-aware editor at it.

Next: turn a written design brief into a live theme with [DESIGN.md →](../design-md/).
