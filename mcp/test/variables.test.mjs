// Tests for the token → Figma Variables export (the code→Figma direction) and
// its round-trip guarantees.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import {
  buildVariables, toFigmaRestPayload, hexToFigmaColor, tokenToPath, pathToToken,
} from "../dist/figma/variables.js";

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(new URL("../data/themekit.json", import.meta.url), "utf8"));
const model = buildVariables(data.tokens, data.themes);
const col = (name) => model.collections.find((c) => c.name === name);

// ── Conversions ─────────────────────────────────────────────────────────────

test("hexToFigmaColor: white / black / known hex, 0..1 with alpha", () => {
  assert.deepEqual(hexToFigmaColor("#ffffff"), { r: 1, g: 1, b: 1, a: 1 });
  assert.deepEqual(hexToFigmaColor("000000"), { r: 0, g: 0, b: 0, a: 1 });
  const c = hexToFigmaColor("#056bfd");
  assert.ok(Math.abs(c.r - 5 / 255) < 1e-3 && Math.abs(c.b - 253 / 255) < 1e-3);
});

test("tokenToPath / pathToToken round-trip on real token names", () => {
  for (const name of ["foreground.fg-hero", "palette.primary.50", "text.text-primary"]) {
    assert.equal(pathToToken(tokenToPath(name)), name);
  }
});

// ── Model shape ───────────────────────────────────────────────────────────

test("five collections, all present", () => {
  assert.deepEqual(model.collections.map((c) => c.name), ["Brand", "Color", "Radius", "Spacing", "Typography"]);
});

test("Brand: one mode per preset, four seed channels", () => {
  const brand = col("Brand");
  assert.equal(brand.modes.length, data.themes.length, "one mode per preset");
  assert.deepEqual(brand.variables.map((v) => v.name), ["primary", "secondary", "accent", "base"]);
  // Every channel has a value for every mode.
  for (const v of brand.variables) assert.equal(Object.keys(v.values).length, data.themes.length);
});

test("Brand modes are unique (Figma requires it)", () => {
  const modes = col("Brand").modes;
  assert.equal(new Set(modes).size, modes.length);
});

test("Brand default mode carries the Default preset's primary seed", () => {
  const def = data.themes.find((t) => t.id === "default");
  const primary = col("Brand").variables.find((v) => v.name === "primary");
  assert.deepEqual(primary.values[def.name], hexToFigmaColor(def.primary));
});

test("Color collection has every resolved color token, as a COLOR var", () => {
  const colorCats = new Set(["foreground", "background", "border", "text", "palette"]);
  const expected = data.tokens.filter((t) => colorCats.has(t.category) && /^#[0-9a-fA-F]{6}$/.test(t.value)).length;
  const color = col("Color");
  assert.equal(color.variables.length, expected);
  assert.ok(color.variables.every((v) => v.type === "COLOR"));
});

test("Radius includes the size scale AND the box/field/selector roles", () => {
  const names = col("Radius").variables.map((v) => v.name);
  assert.ok(names.includes("rd-md"));
  assert.ok(names.includes("role/box") && names.includes("role/field") && names.includes("role/selector"));
  assert.ok(col("Radius").variables.every((v) => v.type === "FLOAT"));
});

test("Typography emits size+lineHeight (FLOAT) and weight (STRING) per style", () => {
  const t = col("Typography");
  const size = t.variables.find((v) => v.name === "headingSm/size");
  const lh = t.variables.find((v) => v.name === "headingSm/lineHeight");
  const w = t.variables.find((v) => v.name === "headingSm/weight");
  assert.equal(size.values.Default, 20);
  assert.equal(lh.values.Default, 26);
  assert.equal(w.type, "STRING");
  assert.equal(w.values.Default, "semibold");
});

test("every variable's codeSyntax token round-trips (design ↔ code)", () => {
  for (const c of model.collections) for (const v of c.variables) {
    assert.ok(typeof v.token === "string" && v.token.length, `${v.name} has a token`);
    // Color/Radius/Spacing paths mirror their token 1:1; grouped ones (role/, typography) are prefixed.
    if (c.name === "Color") assert.equal(pathToToken(v.name), v.token);
  }
});

// ── Figma REST payload ───────────────────────────────────────────────────────

test("REST payload: collections CREATE, initial mode UPDATE, extra modes CREATE", () => {
  const p = toFigmaRestPayload(model);
  assert.equal(p.variableCollections.length, 5);
  assert.ok(p.variableCollections.every((c) => c.action === "CREATE" && c.initialModeId));
  // Brand has 33 modes: 1 UPDATE (initial) + 32 CREATE.
  const brandColId = p.variableCollections.find((c) => c.name === "Brand").id;
  const brandModes = p.variableModes.filter((m) => m.variableCollectionId === brandColId);
  assert.equal(brandModes.filter((m) => m.action === "UPDATE").length, 1);
  assert.equal(brandModes.filter((m) => m.action === "CREATE").length, data.themes.length - 1);
});

test("REST payload: every mode value references a declared variable and mode id", () => {
  const p = toFigmaRestPayload(model);
  const varIds = new Set(p.variables.map((v) => v.id));
  const modeIds = new Set(p.variableModes.map((m) => m.id));
  for (const mv of p.variableModeValues) {
    assert.ok(varIds.has(mv.variableId), "value → known variable");
    assert.ok(modeIds.has(mv.modeId), "value → known mode");
  }
  assert.ok(p.variables.every((v) => v.codeSyntax && v.codeSyntax.iOS), "codeSyntax carries the token");
});

// ── Server tool ───────────────────────────────────────────────────────────

test("export_figma_variables is registered and returns valid JSON", async () => {
  const transport = new StdioClientTransport({
    command: "node", args: [join(here, "..", "dist", "index.js")], env: { ...process.env },
  });
  const client = new Client({ name: "variables-test", version: "1.0.0" });
  await client.connect(transport);
  try {
    const names = (await client.listTools()).tools.map((t) => t.name);
    assert.ok(names.includes("export_figma_variables"));

    const res = await client.callTool({ name: "export_figma_variables", arguments: { format: "figma-rest", collections: ["Brand"] } });
    assert.ok(!res.isError);
    const jsonBlock = res.content[0].text.match(/```json\n([\s\S]*?)\n```/);
    assert.ok(jsonBlock, "response embeds a json block");
    const payload = JSON.parse(jsonBlock[1]);
    assert.equal(payload.variableCollections.length, 1, "filtered to Brand only");
    assert.equal(payload.variableCollections[0].name, "Brand");
  } finally {
    await client.close();
  }
});
