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
| `validate_code(swift)` | Anti-patterns (string/comment-aware) + raw-SwiftUI-with-equivalents + **unknown/hallucinated component detection** (with a did-you-mean) + **brace/paren/bracket balance** + a PASS/FAIL verdict |
| `lint_snippet(swift)` | Flags hardcoded colors / radius / fonts / padding |
| `a11y_audit(swift)` | Accessibility audit — interactive controls missing `.a11yID`, images/icons without a label, hardcoded colors, + a WCAG contrast hint |
| `scaffold_screen(kind)` | A starter form / list / detail / settings screen |
| `compose_screen(components, …)` | Builds a token-bound screen from an **ordered, catalog-verified** component list (vstack / scroll / card) |
| `migrate_snippet(swift)` | Rewrites plain SwiftUI toward ThemeKit — **config-driven** via `migrate-rules.json` |
| `render_preview(component, dark?)` | The component's **rendered PNG** (the library's gallery render), light or dark |
| **`design_to_code(url \| fileKey+nodeId, dryRun?, a11yOnly?, expandInstances?)`** | Fetches a Figma node → ThemeKit SwiftUI. Snaps colors/spacing/radius/**type** to **tokens** and **emits** them: raw layout stacks carry token-snapped `.padding` / `.background` / `.cornerRadius` / `.themeShadow`, text nodes get `.textStyle(…)`, real **alignment** (`counterAxisAlignItems`, `SPACE_BETWEEN → Spacer()`), **axis-inferred** `VStack`/`HStack`/`ZStack` for absolute layouts, and **icons/images → `Image(…)` + PNG export URLs** from the Figma images API. Maps nodes to components (config-driven, **modifier/state-aware**: disabled / size), emits **verified-API** code + a mapping report **with a WCAG accessibility audit of the design**. Pass a Figma **`url`** directly (it parses `fileKey` + `nodeId`), or give them explicitly. `expandInstances: true` walks into unmapped component instances (forms, headers). `a11yOnly: true` returns just the audit. Needs `FIGMA_TOKEN`. _(Alias: **`figma_to_swiftui`** — same tool, kept for backward compatibility.)_ |

### Themes
| Tool | What it returns |
|---|---|
| `list_themes` · `theme_colors(id)` · `theme_snippet(id?)` · `generate_theme(...)` | Preset ids / hexes / apply code / a custom `ThemeConfig` |
| `diff_theme(a, b)` | Per-channel (primary / secondary / accent / base) **CIE76 ΔE** between two presets |
| `theme_preview(id)` | A **PNG swatch card** (renders inline) |
| `get_design_tokens(category: "contrast")` | A **WCAG** text-on-surface contrast report (AA / AAA grading) |

Plus resources (`themekit://guide`, `themekit://components`, `themekit://component/{name}`)
and prompts (`themekit-screen`, `migrate-to-themekit`).

## Figma → SwiftUI

**`design_to_code`** (alias: `figma_to_swiftui`) turns a Figma node into ThemeKit SwiftUI:

1. **Fetch** the node subtree via the Figma REST API (`FIGMA_TOKEN`).
2. **Token match _and emit_** — fills → nearest color token (CIE76 ΔE),
   padding/`itemSpacing` → spacing scale, corner radius → radius token, and text
   `fontSize`/`fontWeight` → nearest `TextStyle`. These aren't just *reported* —
   raw SwiftUI carries them as `.padding` / `.background` / `.cornerRadius` /
   `.themeShadow` / `.textStyle`. No match → reported as *needs review*.
3. **Layout** — autolayout keeps its axis and `counterAxisAlignItems` alignment,
   `SPACE_BETWEEN` becomes `Spacer()`; a `GROUP` / `layoutMode: NONE` frame
   **infers** its axis from child bounding boxes (→ `VStack`/`HStack`, or `ZStack`
   when children overlap, flagged for review).
4. **Component match** — `figma-mapping.json` rules first (case-insensitive; e.g.
   `"Button/Primary" → PrimaryButton`, plus built-ins for `Checkbox` / `Radio` /
   `Toggle` / `Divider` / inputs / badges / chips / `Tag` / `SearchBar` / `Rating` /
   `Spinner` / `Progress` / `OTP` / `Stepper` / …), then heuristics — but a frame
   only becomes a `Card` when it *looks like a surface* (fill / stroke / shadow);
   a bare frame stays a plain layout stack. Unmapped nodes become raw SwiftUI
   marked `// ⚠️ unmapped`; placeholder text (`scribble`, `Input Label`, …) is dropped.
5. **Assets** — vector / image nodes (and all-vector icon frames) emit
   `Image("slug").accessibilityLabel(…)` and are exported: the tool fetches their
   **PNG URLs** from the Figma images API into an *Asset export URLs* section.
6. **Codegen** with parameter names **verified against the symbol-graph API**.
7. A **mapping report** (matched / unmapped / token snaps / assets / needs-review)
   plus an **auto-validation** pass (`validate_code` is run on the generated code
   and its PASS/FAIL verdict appended); `dryRun: true` returns just the plan.

It's **config-driven** — edit `figma-mapping.json` to add/override rules. Set the
token: `export FIGMA_TOKEN=figd_…`. (Complements an official Figma MCP — this one is
the mapping/codegen layer and fetches node data itself.)

### How to trigger it (from chat)

Easiest: pass the Figma link straight to the tool's **`url`** parameter — it parses
the `fileKey` and `nodeId` for you (including the `node-id` dash→colon fix):

```jsonc
design_to_code({ "url": "https://www.figma.com/design/<FILE_KEY>/App?node-id=25795-9030" })
```

So just paste a Figma link and ask your agent to convert it:

```
Use the themekit MCP. Convert this Figma node to ThemeKit SwiftUI:
https://www.figma.com/design/MX2ACwPhpSO9gyRImA7Dnc/App?node-id=25795-9030
```

You can still pass an explicit **`fileKey`** + **`nodeId`** instead of `url`. The URL
anatomy, if you want to extract them yourself:

```
https://www.figma.com/design/<FILE_KEY>/<title>?node-id=<NODE_ID>
                              ^^^^^^^^^^                  ^^^^^^^
                              fileKey                     nodeId
```

> ⚠️ In the URL the `node-id` uses a **dash** (`25795-9030`); the API expects a
> **colon** (`25795:9030`). Passing `url` handles this automatically; if you pass
> `nodeId` yourself, convert `-` → `:`.

Grab the most reliable link with **right-click ▸ Copy link to selection** in Figma.
Add `dryRun: true` for just the mapping plan, or `a11yOnly: true` for just the
accessibility audit.

#### Telling the agent which MCP to use

With several MCP servers configured, name the one you want so the agent picks the
right tool. The server is registered as **`themekit`** (the name in your
`.mcp.json` / `mcp.json`), and the tool is **`design_to_code`** (alias:
`figma_to_swiftui`) — mention either:

```
# By server name
Use the themekit MCP to convert this Figma screen to ThemeKit SwiftUI:
https://www.figma.com/design/<FILE_KEY>/App?node-id=25795-9030

# By tool name (most explicit)
Call the themekit design_to_code tool with this url:
https://www.figma.com/design/<FILE_KEY>/App?node-id=25795-9030

# Plan first, then generate
Use themekit · design_to_code with dryRun: true on this url, show me the
mapping report, then run it for real if 80%+ of nodes map.
```

> If you renamed the server in your config (say `"design-system"` instead of
> `"themekit"`), use **that** name in the prompt — the agent matches the server key
> you configured, not the npm package name.

Verify what's available before asking: `/mcp` lists configured servers and their
status, and `/tools` lists every tool the agent can call (you'll see
`design_to_code` and its `figma_to_swiftui` alias under the `themekit` server once
it's loaded).

> **Pick a single screen, not a board.** By default the tool walks `FRAME`/`GROUP`
> subtrees but treats a Figma **component `INSTANCE` as an opaque leaf** (its
> internals are reported as `// ⚠️ unmapped`). Point it at one concrete screen/frame;
> a board of nested instances yields empty scaffolding. Pass **`expandInstances: true`**
> to recurse into unmapped instances too (forms/headers/nav bars built from
> instances) — you get much more of the screen, at the cost of more raw SwiftUI to
> review. The accessibility audit always inspects inside instances.

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
