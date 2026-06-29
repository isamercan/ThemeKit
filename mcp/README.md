# @isamercan/themekit-mcp

An [MCP](https://modelcontextprotocol.io) server for the **ThemeKit** SwiftUI
design system. It exposes ThemeKit's components, modifiers, tokens and the 32
theme presets as **on-demand tools**, so an MCP-compatible editor (Claude Code,
Cursor, Windsurf, …) can pull accurate, focused context while generating code —
instead of loading everything up front.

**Single source of truth.** `data/themekit.json` is built from the **DocC symbol
graph** (`swift package dump-symbol-graph` → precise init params, types, defaults
and modifiers) + the bundled **theme JSON** (token values). Run `make mcp-data`
to rebuild it; nothing is hand-maintained, so the APIs can't drift.

## Tools

### Read — context (kills hallucinated APIs)
| Tool | What it returns |
|---|---|
| `usage_guide` | The golden rules for writing ThemeKit code |
| `list_components(category?)` | Components by Atom / Molecule / Organism + a one-liner |
| **`get_component_api(name)`** | The **exact** init params (label, type, default, required), extra inits, and modifiers — from the symbol graph |
| `get_design_tokens(category?)` | Tokens with **real values** (colors, radius + box/field/selector roles, spacing, typography, semantic colors) |
| `get_usage_snippet(name, variant?)` | A copy-paste example (basic / full) |
| `search_components(intent)` | Intent search ("a selectable filter list") — keyword + synonym scoring |
| `get_variants_states(name)` | Style variants (enum cases) + supported states |
| `get_migration_guide(from, to?)` | What changed between two versions (breaking first), from the CHANGELOG |

### Act — generation
| Tool | What it does |
|---|---|
| `validate_code(swift)` | Anti-patterns + raw-SwiftUI-with-equivalents + a PASS/FAIL verdict |
| `lint_snippet(swift)` | Flags hardcoded colors / radius / fonts / padding |
| `scaffold_screen(kind)` | A starter form / list / detail / settings screen |
| `migrate_snippet(swift)` | Rewrites plain SwiftUI toward ThemeKit |
| `render_preview(component, dark?)` | The component's **rendered PNG** (the library's gallery render), light or dark |
| **`figma_to_swiftui(fileKey, nodeId, dryRun?)`** | Fetches a Figma node → ThemeKit SwiftUI: snaps colors/spacing/radius to **tokens**, maps nodes to components (config-driven), emits **verified-API** code + a mapping report. Needs `FIGMA_TOKEN` |

### Themes
| Tool | What it returns |
|---|---|
| `list_themes` · `theme_colors(id)` · `theme_snippet(id?)` · `generate_theme(...)` | Preset ids / hexes / apply code / a custom `ThemeConfig` |
| `theme_preview(id)` | A **PNG swatch card** (renders inline) |

Plus resources (`themekit://guide`, `themekit://components`, `themekit://component/{name}`)
and prompts (`themekit-screen`, `migrate-to-themekit`).

## Figma → SwiftUI

`figma_to_swiftui` turns a Figma node into ThemeKit SwiftUI:

1. **Fetch** the node subtree via the Figma REST API (`FIGMA_TOKEN`).
2. **Token match** — fills → nearest color token (CIE76 ΔE), padding/`itemSpacing`
   → spacing scale, corner radius → radius token. No match → reported as *needs review*.
3. **Component match** — `figma-mapping.json` rules first (e.g. `"Button/Primary" → PrimaryButton`),
   then heuristics; unmapped nodes become raw SwiftUI marked `// ⚠️ unmapped`.
4. **Codegen** with parameter names **verified against the symbol-graph API**.
5. A **mapping report** (matched / unmapped / token snaps / needs-review); `dryRun: true`
   returns just the plan.

It's **config-driven** — edit `figma-mapping.json` to add/override rules. Set the
token: `export FIGMA_TOKEN=figd_…`. (Complements an official Figma MCP — this one is
the mapping/codegen layer and fetches node data itself.)

## Install

### Published (recommended, once on npm)

```sh
# Claude Code
claude mcp add themekit -- npx -y @isamercan/themekit-mcp
```

### From this repo (no publish needed)

```sh
cd mcp && npm install && npm run build
claude mcp add themekit -- node "$(pwd)/dist/index.js"
```

### Any MCP editor — `.mcp.json`

```json
{
  "mcpServers": {
    "themekit": {
      "command": "npx",
      "args": ["-y", "@isamercan/themekit-mcp"],
      "env": { "FIGMA_TOKEN": "figd_…" }
    }
  }
}
```

`FIGMA_TOKEN` is optional — only `figma_to_swiftui` needs it; every other tool
works without it. Then ask your agent: *"Use the themekit MCP — build a sign-up screen."*

## Develop

```sh
npm install
npm run build      # tsc -> dist/
npm start          # run the stdio server
```

Re-run `make skill` from the repo root after changing components/themes to
refresh `themekit.json`.
