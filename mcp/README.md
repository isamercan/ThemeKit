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
| `get_component(name)` | A component's init signature + chainable modifiers |
| `search_components(query)` | Components matching a keyword (e.g. "date", "progress") |
| `list_themes` | The bundled theme-preset ids |
| `theme_snippet(id?)` | Swift code to apply a theme / show `ThemePicker` |
| `token_reference(kind?)` | Design tokens (colors, radius roles, spacing, semantic colors) |

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
