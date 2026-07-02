// Tests for import_figma_variables — the Figma → ThemeConfig direction that
// closes the round-trip. Covers: real export→import round-trip (lossless via
// codeSyntax), the Figma REST GET-local shape with VARIABLE_ALIAS, the
// name-heuristic and alias paths for a foreign company file, and mode picking.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { buildVariables } from "../dist/figma/variables.js";
import { importVariables } from "../dist/figma/importVariables.js";

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(new URL("../data/themekit.json", import.meta.url), "utf8"));

// ── Round-trip: export our tokens, import them straight back ────────────────

test("round-trip: export→import recovers the Default preset primary, losslessly", () => {
  const model = buildVariables(data.tokens, data.themes);      // our export model
  const r = importVariables(model, { mode: "Default" });
  const def = data.themes.find((t) => t.id === "default");
  assert.equal(r.seeds.primary.hex.replace(/^#/, ""), def.primary.toLowerCase());
  assert.equal(r.seeds.base.hex.replace(/^#/, ""), def.base.toLowerCase());
  assert.equal(r.seeds.primary.source, "codeSyntax", "resolved via codeSyntax");
  assert.ok(r.lossless, "flagged lossless");
  assert.match(r.themeConfigSwift, /Theme\.shared\.apply\(ThemeConfig\(primaryHex: "056bfd"/);
});

test("round-trip: importing the Dracula mode yields Dracula's seeds", () => {
  const model = buildVariables(data.tokens, data.themes);
  const dracula = data.themes.find((t) => /dracula/i.test(t.name) || t.id === "dracula");
  if (!dracula) return; // skip if the preset set changes
  const r = importVariables(model, { mode: dracula.name });
  assert.equal(r.seeds.primary.hex.replace(/^#/, ""), dracula.primary.toLowerCase());
  assert.equal(r.mode, dracula.name);
});

// ── Figma REST GET-local shape, with VARIABLE_ALIAS ─────────────────────────

const restLocal = {
  meta: {
    variableCollections: {
      "c1": { id: "c1", name: "Brand", defaultModeId: "m1", modes: [{ modeId: "m1", name: "Light" }, { modeId: "m2", name: "Dark" }] },
      "c2": { id: "c2", name: "Primitives", defaultModeId: "m3", modes: [{ modeId: "m3", name: "Value" }] },
    },
    variables: {
      // Brand/primary is an ALIAS to a primitive — must be dereferenced.
      "v1": { id: "v1", name: "primary", resolvedType: "COLOR", variableCollectionId: "c1",
              valuesByMode: { "m1": { type: "VARIABLE_ALIAS", id: "vp" }, "m2": { r: 0.1, g: 0.1, b: 0.1, a: 1 } } },
      "v2": { id: "v2", name: "Surface/base", resolvedType: "COLOR", variableCollectionId: "c1",
              valuesByMode: { "m1": { r: 1, g: 1, b: 1, a: 1 }, "m2": { r: 0, g: 0, b: 0, a: 1 } } },
      "vp": { id: "vp", name: "blue/500", resolvedType: "COLOR", variableCollectionId: "c2",
              valuesByMode: { "m3": { r: 0.0196, g: 0.4196, b: 0.9922, a: 1 } } },
    },
  },
};

test("REST GET-local: resolves an aliased primary and a name-matched base", () => {
  const r = importVariables(restLocal, { mode: "Light" });
  assert.equal(r.seeds.primary.hex.replace(/^#/, ""), "056bfd", "alias dereferenced to blue/500");
  assert.equal(r.seeds.primary.source, "name");        // no codeSyntax on this foreign file
  assert.equal(r.seeds.base.hex.replace(/^#/, ""), "ffffff");
  assert.ok(!r.lossless);
});

test("REST GET-local: Dark mode picks the dark values and infers dark:true", () => {
  const r = importVariables(restLocal, { mode: "Dark" });
  assert.equal(r.seeds.primary.hex.replace(/^#/, ""), "1a1a1a");
  assert.equal(r.themeJson.dark, true, "dark inferred from mode name");
});

// ── Foreign naming needs an alias ───────────────────────────────────────────

test("a company's own names resolve via aliases", () => {
  const foreign = {
    meta: {
      variableCollections: { "c": { id: "c", name: "Tokens", defaultModeId: "m", modes: [{ modeId: "m", name: "Default" }] } },
      variables: {
        "a": { id: "a", name: "Palette/BrandBlue", resolvedType: "COLOR", variableCollectionId: "c", valuesByMode: { "m": { r: 0.2, g: 0.4, b: 0.8, a: 1 } } },
      },
    },
  };
  const noAlias = importVariables(foreign, {});
  assert.ok(!noAlias.seeds.primary, "unmatched without an alias");
  assert.ok(noAlias.notes.some((n) => /primary/i.test(n)));

  const withAlias = importVariables(foreign, { aliases: { "Palette/BrandBlue": "primary" } });
  assert.equal(withAlias.seeds.primary.source, "alias");
  assert.ok(withAlias.seeds.primary.hex.startsWith("#"));
});

test("codeSyntax beats a conflicting name heuristic", () => {
  const input = {
    meta: {
      variableCollections: { "c": { id: "c", name: "Brand", defaultModeId: "m", modes: [{ modeId: "m", name: "Default" }] } },
      variables: {
        // named "primary" but codeSyntax says it's the accent — codeSyntax wins.
        "x": { id: "x", name: "primary", resolvedType: "COLOR", variableCollectionId: "c",
               codeSyntax: { iOS: "brand.accent" }, valuesByMode: { "m": { r: 0, g: 1, b: 0, a: 1 } } },
      },
    },
  };
  const r = importVariables(input, {});
  assert.ok(!r.seeds.primary, "not treated as primary");
  assert.equal(r.seeds.accent.hex.replace(/^#/, ""), "00ff00");
  assert.equal(r.seeds.accent.source, "codeSyntax");
});

// ── Server tool ───────────────────────────────────────────────────────────

test("import_figma_variables tool round-trips through the server", async () => {
  const model = buildVariables(data.tokens, data.themes);
  const transport = new StdioClientTransport({
    command: "node", args: [join(here, "..", "dist", "index.js")], env: { ...process.env },
  });
  const client = new Client({ name: "import-test", version: "1.0.0" });
  await client.connect(transport);
  try {
    const names = (await client.listTools()).tools.map((t) => t.name);
    assert.ok(names.includes("import_figma_variables"));
    const res = await client.callTool({ name: "import_figma_variables", arguments: { variablesJson: JSON.stringify(model), mode: "Default" } });
    assert.ok(!res.isError);
    assert.match(res.content[0].text, /primaryHex: "056bfd"/);
    assert.match(res.content[0].text, /lossless/);
  } finally {
    await client.close();
  }
});
