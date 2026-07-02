---
title: Map Your Figma Kit
description: Teach the ThemeKit MCP your Figma UI kit's component names (e.g. MyBrandTextField → TextInput) so design_to_code emits real ThemeKit SwiftUI — with componentAliases, a user-owned override file, and a suggest tool that drafts the whole map.
---

`design_to_code` turns a Figma node into ThemeKit SwiftUI. But your kit names its
components in **your** vocabulary — `MyBrandTextField`, `MyBrandButton`,
`Acme/Chip` — while ThemeKit calls them `TextInput`, `PrimaryButton`, `Chip`.
Without a mapping, those instances come out as `// ⚠️ unmapped`.

This page shows how to teach the MCP that correspondence **once**, so your whole
kit converts to real ThemeKit code — and how to keep that mapping in a file **you
own**, draft it automatically, and make it robust to Figma renames.

:::tip[The mental model]
There are two "vocabularies" to bridge: **component names** (this page) and
**design tokens** ([the other page](../figma-variables/)). This page is about
components — turning `MyBrandTextField` into `TextInput(...)`.
:::

## The problem, concretely

Point `design_to_code` at a screen built from your kit and, with no mapping, you
get scaffolding full of unmapped instances:

```swift
VStack {
    // ⚠️ unmapped: MyBrandTextField (INSTANCE)
    // ⚠️ unmapped: MyBrandButton (INSTANCE)
}
```

The generator has never heard of `MyBrandTextField`. One line of mapping fixes
that for every instance of it, forever.

## 1. `componentAliases` — the one-line path

Create a small JSON file anywhere in **your** project — say `themekit-mapping.json`:

```json
{
  "componentAliases": {
    "MyBrandTextField": "TextInput",
    "MyBrandButton": "PrimaryButton",
    "Acme/Chip": "Chip"
  }
}
```

That's it. One line per component: **your Figma name → a ThemeKit component**. You
do **not** write init parameters — the generator fills them in for you (next
section explains how). Now:

```swift
TextInput("E-mail", text: $text)
PrimaryButton("Continue") { }
```

### How matching works

An alias key matches a Figma node's name in three forgiving ways, all
**case-insensitive**:

| Your alias key | Matches node named |
|---|---|
| exact | `MyBrandTextField` |
| first `/`-segment | `MyBrandTextField/Filled`, `MyBrandTextField/Focused` |
| prefix | `MyBrandTextFieldLarge` |

So a single `"MyBrandTextField": "TextInput"` covers every variant of that
component. `mybrandtextfield` (lowercased) matches too.

### How the arguments get filled

This is the part that saves you from writing params. When an alias matches, the
generator looks up the ThemeKit component's **real, verified API** (from the DocC
symbol graph) and synthesizes each **required** init argument by type:

| Required param type | Becomes | Example |
|---|---|---|
| `String` (first one) | the node's text | `TextInput("E-mail", …)` |
| `Binding<…>` | a `$name` stub | `text: $text` |
| closure (`() -> Void`) | an empty closure | `action: { }` |
| `Int` / `Double` | `0` | `value: 0` |
| anything richer (a model, enum, array) | a placeholder **+ a needs-review note** | `options: <[Option]>` |

So `MyBrandTextField → TextInput` produces `TextInput("<label>", text: $text)` —
correct against `init(_ label: String, text: Binding<String>)`, with the label
pulled from the node's own text. Optional args are left to the theme/defaults.

:::caution[Honest about what it can't guess]
If a component needs a structured argument it can't synthesize — say `Select`
needs `options: [Option]` — the alias still emits the call but leaves a
`<[Option]>` placeholder **and** flags it in the report. It never invents data.
For those, a full rule (below) or a manual edit is the way.
:::

## 2. Keep the mapping in a file **you own**

`figma-mapping.json` ships **inside** the npm package (`node_modules/…`). Editing
it there is a trap: an `npm update` or a fresh `npx` cache wipes your changes.

Instead, keep your file in your project and point the server at it with the
**`THEMEKIT_MAPPING`** environment variable. The server layers it **on top of**
the bundled defaults.

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

How the layering works:

- **Your file wins.** Your `componentRules` are tried *before* the bundled ones,
  and your `componentAliases` override same-named defaults.
- **Partial is fine.** Your file only needs the keys it sets — everything else
  falls back to the bundled defaults.
- **Reinstalls are safe.** Your file lives in your repo; updating the package
  never touches it.

## 3. Don't hand-write it — draft it

Run **`suggest_figma_mapping`** and let it propose the whole `componentAliases`
block, scored against the real ThemeKit catalog.

**Offline, from a list of names:**

```text
Use themekit · suggest_figma_mapping with
names: ["MyBrandTextField","MyBrandButton","MyBrandChip"], brandPrefix: "MyBrand"
```

**Online, from your actual kit** (needs `FIGMA_TOKEN`) — it walks every component
instance in the file and drafts an alias for each:

```text
Use themekit · suggest_figma_mapping with url:
https://www.figma.com/design/<FILE_KEY>/Design-System?node-id=…
```

Under the hood it strips the brand prefix, tokenizes the name
(`MyBrandTextField` → `brand · text · field`), and scores those tokens against the
catalog's names, docs, and a synonym table. You get ready-to-paste JSON:

```text
# Suggested Figma → ThemeKit aliases (2/3)
- MyBrandTextField → TextInput  (95%)
- MyBrandButton → PrimaryButton  (90%)  alt: SecondaryButton, ThemeButton
- MyBrandWidget: no confident match — set it manually (search_components "MyBrandWidget")

{ "componentAliases": { "MyBrandTextField": "TextInput", "MyBrandButton": "PrimaryButton" } }
```

Low-confidence and no-match names are **flagged**, never guessed. Paste the block
into your file from step 2, fix the flagged ones, done.

## 4. For components that get renamed: key by `componentKey`

Layer names drift; a Figma **component key** is stable. For anything important,
use a full `componentRules` entry keyed by the key instead of the name:

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

`suggest_figma_mapping` prints each instance's `componentKey` (in URL mode), so
you can copy it here. Rules are the full-control form — see the next section.

## Aliases vs. rules — which to use

| | `componentAliases` | `componentRules` |
|---|---|---|
| Effort | one line | a JSON object |
| Args | auto-filled from the API | you choose the source (`{text}`, `$binding`, literals) |
| Match by | name / segment / prefix | name **or** stable `componentKey`, + node type |
| Style/variant axes | — | `styleFromNameSegment`, `styleModifier` |
| Container wrapping | — | `container: true` |
| State modifiers | auto (disabled / size) | explicit `modifiers` (`whenProp`, `whenName`) |

**Start with aliases.** Reach for a rule when you need a stable key, a custom
argument source, a style segment (`Badge/Error` → `.badgeStyle(.error)`), or a
container.

## Let an LLM read the mapping

The active mapping (bundled defaults **plus** your override) is exposed as the
`themekit://figma-mapping` **resource**. An assistant can read it to answer "what
does `MyBrandTextField` map to?" directly, instead of inferring from the name —
which keeps generated code consistent with your intent.

## Troubleshooting

- **My component still comes out `// ⚠️ unmapped`.** The alias key didn't match.
  Check the node's actual name in Figma (it may be `Component/Variant` — the
  first segment is what matches), and confirm `THEMEKIT_MAPPING` points at your
  file (the `themekit://figma-mapping` resource shows what's actually loaded).
- **It mapped to the wrong component.** Set the alias explicitly (it overrides the
  heuristics), or run `search_components "<name>"` to find the right target.
- **The output has a `<[Something]>` placeholder.** That's a required structured
  argument the generator can't synthesize — check the needs-review note and fill
  it in, or use a rule with an explicit `argsFrom`.
- **A container (Card-like) alias didn't wrap its children.** Aliases produce leaf
  calls; for a container use a `componentRules` entry with `"container": true`.

## The bigger picture

Component mapping is one half of the Figma bridge. The other is **design tokens** —
exporting ThemeKit's tokens as Figma Variables and importing a brand's file back
into a `ThemeConfig`. See **[Design Tokens ⇄ Figma Variables](../figma-variables/)**.
Together, your Figma kit and your ThemeKit code share one source of truth, both
ways.
