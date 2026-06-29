// Offline test of the figma → SwiftUI pipeline (no network — operates on a fixture node tree).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { generate } from "../dist/figma/codegen.js";
import { loadMapping } from "../dist/figma/mapping.js";

const read = (rel) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const data = read("../data/themekit.json");
const node = read("./fixtures/figma-card.json");
const mapping = loadMapping(fileURLToPath(new URL("../figma-mapping.json", import.meta.url)));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));

test("maps a button instance to the real PrimaryButton API", () => {
  const { code } = generate(node, mapping, data.tokens, apis);
  assert.match(code, /PrimaryButton\("Continue"\)\s*\{\s*\}/);
});

test("maps Badge/Error → Badge(style: .error)", () => {
  const { code } = generate(node, mapping, data.tokens, apis);
  assert.match(code, /Badge\("Sale", style: \.error\)/);
});

test("wraps the frame in a Card", () => {
  const { code } = generate(node, mapping, data.tokens, apis);
  assert.match(code, /Card \{/);
});

test("snaps the red fill to a token and reports it", () => {
  const { report } = generate(node, mapping, data.tokens, apis);
  assert.ok(report.tokenSnaps.some((s) => /error/i.test(s)), "red fill snapped to an error token");
});

test("flags the unmapped node — never silently dropped", () => {
  const { code, report } = generate(node, mapping, data.tokens, apis);
  assert.ok(report.unmapped.some((u) => /Mystery Widget/.test(u)));
  assert.match(code, /⚠️ unmapped: Mystery Widget/);
});
