// Regression tests for the design_to_code fidelity fixes:
//   icon-font → SF Symbol · layoutWrap → VStack · palette accessor · checkbox label.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { generate } from "../dist/figma/codegen.js";
import { tokenAccessor } from "../dist/figma/tokenMatch.js";
import { loadMapping } from "../dist/figma/mapping.js";

const read = (rel) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const data = read("../data/themekit.json");
const mapping = loadMapping(fileURLToPath(new URL("../figma-mapping.json", import.meta.url)));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));
const gen = (node) => generate(node, mapping, data.tokens, apis, { expandInstances: true });

// ── icon fonts ────────────────────────────────────────────────────────────
test("a FontAwesome text glyph becomes an SF Symbol Image, not raw Text", () => {
  const node = { id: "1", name: "Frame", type: "FRAME", layoutMode: "VERTICAL", children: [
    { id: "2", name: "chevron", type: "TEXT", characters: "chevron-right",
      style: { fontFamily: "Font Awesome 6 Pro", fontSize: 16 } },
  ] };
  const { code } = gen(node);
  assert.match(code, /Image\(systemName: "chevron\.right"\)/);
  assert.doesNotMatch(code, /Text\("chevron-right"\)/);
});

test("an unmapped icon-font glyph is flagged, not silently emitted as text", () => {
  const node = { id: "1", name: "Frame", type: "FRAME", layoutMode: "VERTICAL", children: [
    { id: "2", name: "x", type: "TEXT", characters: "some-obscure-glyph",
      style: { fontFamily: "FontAwesome", fontSize: 16 } },
  ] };
  const { code, report } = gen(node);
  assert.match(code, /Image\(systemName:/);              // still an Image, not literal text
  assert.ok(report.needsReview.some((r) => /no SF Symbol mapping/.test(r)));
});

test("a normal (non-icon-font) text is untouched", () => {
  const node = { id: "1", name: "Frame", type: "FRAME", layoutMode: "VERTICAL", children: [
    { id: "2", name: "t", type: "TEXT", characters: "Giriş Yap", style: { fontFamily: "Inter", fontSize: 16 } },
  ] };
  const { code } = gen(node);
  assert.match(code, /Text\("Giriş Yap"\)/);
  assert.doesNotMatch(code, /Image\(systemName:/);
});

// ── layoutWrap ──────────────────────────────────────────────────────────────
test("a HORIZONTAL frame with layoutWrap=WRAP and full-width rows becomes a VStack", () => {
  const bb = (y) => ({ x: 0, y, width: 311, height: 48 });
  const node = { id: "1", name: "Inputs", type: "FRAME", layoutMode: "HORIZONTAL", layoutWrap: "WRAP",
    absoluteBoundingBox: { x: 0, y: 0, width: 311, height: 112 }, children: [
      { id: "2", name: "A", type: "TEXT", characters: "A", absoluteBoundingBox: bb(0) },
      { id: "3", name: "B", type: "TEXT", characters: "B", absoluteBoundingBox: bb(64) },
    ] };
  const { code } = gen(node);
  assert.match(code, /VStack/);
  assert.doesNotMatch(code, /HStack/);
});

test("a HORIZONTAL frame WITHOUT wrap still becomes an HStack", () => {
  const node = { id: "1", name: "Row", type: "FRAME", layoutMode: "HORIZONTAL", children: [
    { id: "2", name: "A", type: "TEXT", characters: "A" },
    { id: "3", name: "B", type: "TEXT", characters: "B" },
  ] };
  assert.match(gen(node).code, /HStack/);
});

// ── palette accessor ─────────────────────────────────────────────────────────
test("tokenAccessor routes a palette token to theme.palette(), not theme.background()", () => {
  assert.equal(tokenAccessor("palette.primary.300"), "theme.palette(.primary300)");
  assert.equal(tokenAccessor("palette.neutral.600"), "theme.palette(.neutral600)");
  // and leaves the real background/text/foreground accessors intact
  assert.equal(tokenAccessor("background.bg-white"), "theme.background(.bgWhite)");
  assert.equal(tokenAccessor("text.text-primary"), "theme.text(.textPrimary)");
});

// ── checkbox label ───────────────────────────────────────────────────────────
test("a mapped Checkbox lifts its inner label instead of dropping it", () => {
  const node = { id: "1", name: "Row", type: "FRAME", layoutMode: "HORIZONTAL", children: [
    { id: "2", name: "Checkbox", type: "INSTANCE", children: [
      { id: "3", name: "label", type: "TEXT", characters: "Beni Hatırla" },
    ] },
  ] };
  assert.match(gen(node).code, /Checkbox\("Beni Hatırla"/);
});

// ── unmapped component → visible placeholder ─────────────────────────────────
test("a component instance with no ThemeKit match becomes a visible placeholder Card", () => {
  const node = { id: "1", name: "Root", type: "FRAME", layoutMode: "VERTICAL", children: [
    { id: "2", name: "FancyWidget", type: "INSTANCE" }, // no children, no mapping rule
  ] };
  const { code } = gen(node);
  assert.match(code, /Card \{/);
  assert.match(code, /FancyWidget — no ThemeKit match/);
  assert.doesNotMatch(code, /\/\/ ⚠️ unmapped: FancyWidget/); // not a hidden comment anymore
});
