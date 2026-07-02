---
title: Map Your Figma Kit
description: Point the ThemeKit MCP at your own Figma UI kit — map your components (e.g. MyBrandTextField → TextInput) so design_to_code emits real ThemeKit code, and sync design tokens both ways.
---

You already have a Figma UI kit with **your own** names — `MyBrandTextField`,
`MyBrandButton`, `Acme/Chip`. ThemeKit calls those `TextInput`, `PrimaryButton`,
`Chip`. This page shows how to teach the MCP that correspondence **once**, so
`design_to_code` turns your kit into real ThemeKit SwiftUI — and how to sync
design tokens in both directions.

:::tip[The one thing to understand]
The mapping lives in a small JSON file **you own** (not inside `node_modules`).
You point the server at it with the `THEMEKIT_MAPPING` env var, and it's layered
on top of the built-in defaults. Update it anytime; reinstalls never touch it.
:::

## 1. Create your mapping file

Anywhere in your project, e.g. `themekit-mapping.json`:

```json
{
  "componentAliases": {
    "MyBrandTextField": "TextInput",
    "MyBrandButton": "PrimaryButton",
    "Acme/Chip": "Chip"
  }
}
```

That's the **easy path**: one line per component. You don't write init
parameters — the generator fills each ThemeKit component's required args from its
verified API. `MyBrandTextField` → `TextInput("<label>", text: $text)`.

Matching is forgiving: it hits on the exact name, the first `/`-segment, or a
prefix, case-insensitively — so `MyBrandTextField`, `MyBrandTextField/Filled`,
and `mybrandtextfield` all resolve.

## 2. Point the server at it

In your `.mcp.json` (or `claude mcp add … --env`):

```json
{
  "mcpServers": {
    "themekit": {
      "command": "npx",
      "args": ["-y", "@isamercan/themekit-mcp"],
      "env": {
        "THEMEKIT_MAPPING": "/abs/path/to/themekit-mapping.json",
        "FIGMA_TOKEN": "figd_…"
      }
    }
  }
}
```

Now `design_to_code` (Figma → SwiftUI) recognizes your components and emits the
matching ThemeKit code instead of `// ⚠️ unmapped`.

## 3. Don't hand-write it — draft it

Run the **`suggest_figma_mapping`** tool and let it propose the whole block.

Offline, from names:

```
Use themekit · suggest_figma_mapping with
names: ["MyBrandTextField","MyBrandButton","MyBrandChip"], brandPrefix: "MyBrand"
```

Online, from your actual kit (needs `FIGMA_TOKEN`) — it walks every component
instance in the file and drafts an alias for each:

```
Use themekit · suggest_figma_mapping with url:
https://www.figma.com/design/<FILE_KEY>/Design-System?node-id=…
```

It strips the brand prefix, tokenizes the name (`MyBrandTextField` →
`brand · text · field`), scores it against the **real** ThemeKit catalog, and
returns ready-to-paste JSON with a confidence per row. Low-confidence and
no-match names are flagged so you can set them by hand — it never guesses
silently. Paste the result into your mapping file from step 1.

## 4. For components that get renamed: key by componentKey

Layer names drift; a Figma **component key** is stable. For anything important,
use a full rule keyed by the key instead of the name:

```json
{
  "componentRules": [
    {
      "match": { "componentKey": "1:234" },
      "produce": { "component": "TextInput", "argsFrom": { "_": "{text}", "text": "$text" } }
    }
  ]
}
```

`suggest_figma_mapping` prints each instance's `componentKey` (in URL mode) so you
can copy it here. Rules also let you customize arg sources, style segments, and
container wrapping — aliases are the shorthand; rules are the full control.

:::note[Official binding: Code Connect]
For two-way parity with Figma **Dev Mode**, use the Figma MCP's Code Connect to
bind each component to its ThemeKit Swift symbol. Then Dev Mode shows the
ThemeKit snippet, and you can pull the `componentKey`s to fill the rules above.
:::

## Let an LLM read the mapping

The active mapping (defaults + your override) is exposed as the
`themekit://figma-mapping` **resource**, so an assistant can look up "what does
`MyBrandTextField` map to?" directly instead of inferring from the name.

## Sync tokens too, both ways

Component names are half the story; the other half is the design tokens.

- **`export_figma_variables`** — ThemeKit tokens + 32 presets → a Figma Variables
  library (a **Brand** collection with one mode per preset, plus Color / Radius /
  Spacing / Typography). Your designers theme in Figma with the same vocabulary
  the app ships.
- **`import_figma_variables`** — a company's Figma Variables file → a
  `ThemeConfig` + `theme.json`. ThemeKit derives the whole palette from the
  seeds, so any brand re-skins every component. Lossless for files ThemeKit
  exported (each variable carries its token in `codeSyntax`); name/alias-matched
  for foreign files.

Together with the component mapping above, your Figma kit and your ThemeKit code
share **one source of truth in both directions**.
