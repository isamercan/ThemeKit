---
title: MCP Server
description: Give your AI editor on-demand tools that generate correct, token-bound ThemeKit code — including Figma → SwiftUI and a two-way Figma Variables bridge.
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

## Keeping it up to date

The server is published to npm and **updated regularly** — browse the
[changelog](https://github.com/isamercan/ThemeKit/blob/main/mcp/CHANGELOG.md) or
the [npm page](https://www.npmjs.com/package/@isamercan/themekit-mcp) for the
release history.

`npx` caches packages, so an install that pins no version keeps running the
release it first cached. Pin `@latest` so it fetches the newest each time the
server starts:

```sh
claude mcp remove themekit
claude mcp add themekit -- npx -y @isamercan/themekit-mcp@latest
```

Already set up without `@latest`? Clear the npx cache once, then it re-fetches on
the next start:

```sh
rm -rf ~/.npm/_npx        # npx package cache
```

Check what you run against the latest published, and see what changed:

```sh
npm view @isamercan/themekit-mcp version   # latest on npm
```

The `get_migration_guide(from, to?)` tool also summarizes the diff (breaking
first) between any two versions. Running from the repo instead? `git pull` in your
clone and rebuild — this always tracks the very latest tools:

```sh
cd mcp && git pull && npm i && npm run build
```

## What you get

22 on-demand tools, in four groups.

### Read — context (kills hallucinated APIs)

| Tool | Returns |
|---|---|
| `usage_guide()` | The golden rules for writing correct ThemeKit code |
| `get_component_api(name)` | The **exact** init params (label, type, default, required) and modifiers — from the symbol graph |
| `get_design_tokens(category?)` | Tokens with **real values** — colors, radius, spacing, typography, semantic colors, or a WCAG **contrast** report |
| `list_components(category?)` | Components by Atom / Molecule / Organism |
| `search_components(intent)` | Intent search — "a selectable filter list" |
| `get_variants_states(name)` | A component's style variants (enum cases) + supported states |
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
| **`design_via_figma_mcp(url)`** | **Figma → ThemeKit through a Figma MCP** — see below |

### Themes

`list_themes` · `theme_colors(id)` · `theme_snippet(id?)` · `generate_theme(...)` ·
`design_md_to_themeconfig(...)` (see [DESIGN.md](../design-md/)).

### Design tokens ⇄ Figma Variables

`export_figma_variables(...)` · `import_figma_variables(...)` — a two-way bridge
between the token catalog and a Figma Variables library. See
[below](#design-tokens--figma-variables-round-trip).

## Figma → ThemeKit (via a Figma MCP)

**`design_via_figma_mcp`** reads a design **through a Figma MCP server** and hands
the LLM that reference plus a **ThemeKit adaptation kit** to map from. The division
of labor:

- **The Figma MCP reads** — real text overrides, resolved variables, Code Connect
  (far richer than a raw REST transpile).
- **The LLM maps** the reference to idiomatic ThemeKit — it does this far better
  than a rule engine (which is why the deterministic `design_to_code` was removed
  in v3.0.0).
- **This server verifies** — `get_component_api` (real init/modifiers, no
  hallucinated API), `validate_code`, `a11y_audit`.

:::note[Setup — Figma Dev Mode MCP server]
Turn it on in **Figma ▸ Preferences ▸ Enable Dev Mode MCP server** (serves at
`http://127.0.0.1:3845/mcp`), then point this server at it with **`FIGMA_MCP_URL`**
(default that address) — or **`FIGMA_MCP_CMD`** for a stdio Figma MCP. **No
`FIGMA_TOKEN` needed.** The hosted `https://mcp.figma.com` is OAuth-gated and can't
be called this way.
:::

Paste a Figma link and ask:

```text
Use the themekit MCP · design_via_figma_mcp on this node, then map it to idiomatic
ThemeKit and verify with validate_code + a11y_audit:
https://www.figma.com/design/<FILE_KEY>/App?node-id=<NODE-ID>
```

## Design tokens ⇄ Figma Variables (round-trip)

Beyond component names, the MCP bridges **design tokens** both ways:
`export_figma_variables` turns the token catalog into a themeable Figma Variables
library (one mode per preset), and `import_figma_variables` turns a company's
Figma Variables file back into a live `ThemeConfig` — lossless for files ThemeKit
exported, alias-matched for any other.

→ **Full guide: [Design Tokens ⇄ Figma Variables](../figma-variables/)**

## Other AI surfaces

One source feeds three surfaces so they can't drift:

- **Agent skill** ([`skills/themekit/`](https://github.com/isamercan/ThemeKit/tree/main/skills/themekit)) — a Claude Code skill with idioms, every component's init & modifiers, and the presets. Install: `/plugin marketplace add isamercan/ThemeKit` → `/plugin install themekit@themekit`, or copy `skills/themekit/` into `.claude/skills/`.
- **`llms.txt`** ([repo root](https://github.com/isamercan/ThemeKit/blob/main/llms.txt)) — structured LLM context following the [llms.txt](https://llmstxt.org) standard; point any `llms.txt`-aware editor at it.

Next: turn a written design brief into a live theme with [DESIGN.md →](../design-md/).
