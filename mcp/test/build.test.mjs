// Validates the symbol-graph → themekit.json pipeline output (run after `npm run build:data`).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(join(here, "..", "data", "themekit.json"), "utf8"));

test("catalog is populated", () => {
  assert.ok(data.components.length >= 110, `expected ≥110 components, got ${data.components.length}`);
  assert.ok(data.modifiers.length >= 50);
  assert.ok(data.themes.length >= 33, `expected ≥33 theme presets, got ${data.themes.length}`);
});

test("Badge API is precise (from the symbol graph, not regex)", () => {
  const badge = data.components.find((c) => c.name === "Badge");
  assert.ok(badge, "Badge present");
  assert.equal(badge.category, "Atoms");
  const byLabel = Object.fromEntries(badge.params.map((p) => [p.label === "_" ? p.name : p.label, p]));
  assert.equal(byLabel.text.type, "String");
  assert.equal(byLabel.text.default, undefined, "text is required");
  // Post modifier-refactor (R1): init is content + action only; style/variant/size
  // moved to chainable modifiers.
  assert.ok(!byLabel.style, "style is no longer an init param (now a modifier)");
  assert.ok(badge.modifiers.some((m) => m.name.startsWith("badgeStyle")), "has .badgeStyle modifier");
  assert.ok(badge.modifiers.some((m) => m.name.startsWith("variant")), "has .variant modifier");
});

test("enums carry their cases", () => {
  assert.deepEqual(data.enums.FillVariant, ["solid", "soft", "outline", "ghost"]);
  assert.ok(data.enums.SemanticColor.includes("accent"));
});

test("tokens carry real values incl. radius roles", () => {
  const box = data.tokens.find((t) => t.category === "radiusRole" && t.name === "box");
  assert.equal(box.value, "16");
  assert.ok(data.tokens.some((t) => t.category === "background" && /^#/.test(t.value)));
});

test("multi-init components expose the extra inits", () => {
  const ti = data.components.find((c) => c.name === "TextInput");
  assert.ok(ti.inits && ti.inits.length >= 1, "TextInput has extra inits");
});
