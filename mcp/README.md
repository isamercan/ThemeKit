# @isamercan/themekit-mcp

An [MCP](https://modelcontextprotocol.io) server for the **ThemeKit** SwiftUI
design system. It exposes ThemeKit's components, modifiers, tokens and the 32
theme presets as **on-demand tools**, so an MCP-compatible editor (Claude Code,
Cursor, Windsurf, …) can pull accurate, focused context while generating code —
instead of loading everything up front.

The data lives in `themekit.json`, generated from the Swift source by
`tools/gen_skill.py` (`make skill`), so it never drifts from the library.

## Tools

| Tool | What it returns |
|---|---|
| `usage_guide` | The golden rules for writing ThemeKit code |
| `list_components(category?)` | Components by Atom / Molecule / Organism |
| `get_component(name)` | A component's summary, init signature + chainable modifiers |
| `search_components(query)` | Components matching a keyword (e.g. "date", "progress") |
| `lint_snippet(swift)` | Flags ThemeKit anti-patterns (hardcoded colors / radius / fonts) with fixes |
| `validate_screen(swift)` | Full screen check: anti-patterns + raw-SwiftUI with ThemeKit equivalents + a pass/fail verdict |
| `scaffold_screen(kind)` | A starter form / list / detail / settings screen |
| `migrate_snippet(swift)` | Rewrites plain SwiftUI toward ThemeKit, with notes |
| `list_themes` | The bundled theme-preset ids |
| `theme_colors(id)` | A preset's primary / secondary / accent / base hexes |
| `theme_preview(id)` | A **PNG swatch card** for a preset (renders inline) |
| `theme_snippet(id?)` | Swift code to apply a preset / show `ThemePicker` |
| `generate_theme(...)` | A `ThemeConfig` apply snippet from accent / base / secondary / accent |
| `token_reference(kind?)` | Design tokens (colors, radius roles, spacing, semantic colors) |

Plus resources (`themekit://guide`, `themekit://components`, `themekit://component/{name}`)
and prompts (`themekit-screen`, `themekit-theme`, `migrate-to-themekit`).

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
      "args": ["-y", "@isamercan/themekit-mcp"]
    }
  }
}
```

Then ask your agent: *"Use the themekit MCP — build a sign-up screen."*

## Develop

```sh
npm install
npm run build      # tsc -> dist/
npm start          # run the stdio server
```

Re-run `make skill` from the repo root after changing components/themes to
refresh `themekit.json`.
