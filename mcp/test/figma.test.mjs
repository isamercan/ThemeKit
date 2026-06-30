// Offline test of the figma → SwiftUI pipeline (no network — operates on a fixture node tree).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { generate, spacingValueExpr } from "../dist/figma/codegen.js";
import { loadMapping } from "../dist/figma/mapping.js";
import { parseFigmaUrl } from "../dist/figma/client.js";

const read = (rel) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const data = read("../data/themekit.json");
const node = read("./fixtures/figma-card.json");
const mapping = loadMapping(fileURLToPath(new URL("../figma-mapping.json", import.meta.url)));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));

test("maps a button instance to the real PrimaryButton API", () => {
  const { code } = generate(node, mapping, data.tokens, apis);
  assert.match(code, /PrimaryButton\("Continue"\)\s*\{\s*\}/);
});

test("maps Badge/Error → Badge(...).badgeStyle(.error)", () => {
  const { code } = generate(node, mapping, data.tokens, apis);
  assert.match(code, /Badge\("Sale"\)\.badgeStyle\(\.error\)/);
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

test("parseFigmaUrl: /design/ URL — dash node-id normalised to colon", () => {
  const { fileKey, nodeId } = parseFigmaUrl(
    "https://www.figma.com/design/MX2ACwPhpSO9gyRImA7Dnc/App--All-Screens?node-id=25795-9030&m=dev",
  );
  assert.equal(fileKey, "MX2ACwPhpSO9gyRImA7Dnc");
  assert.equal(nodeId, "25795:9030");
});

test("parseFigmaUrl: legacy /file/ URL with encoded colon node-id", () => {
  const { fileKey, nodeId } = parseFigmaUrl("https://www.figma.com/file/ABC123/My-File?node-id=1%3A23");
  assert.equal(fileKey, "ABC123");
  assert.equal(nodeId, "1:23");
});

test("parseFigmaUrl: throws on a non-Figma / malformed URL", () => {
  assert.throws(() => parseFigmaUrl("https://example.com/foo"), /fileKey/);
  assert.throws(() => parseFigmaUrl("https://www.figma.com/design/KEY/Title"), /node-id/);
  assert.throws(() => parseFigmaUrl("not a url"), /valid Figma URL/);
});

test("spacingValueExpr: maps token names to the real SpacingKey cases (not a naive strip)", () => {
  assert.equal(spacingValueExpr("sp-md"), "Theme.SpacingKey.md.value");
  assert.equal(spacingValueExpr("sp-4xl"), "Theme.SpacingKey.xl4.value");      // not .4xl (invalid Swift)
  assert.equal(spacingValueExpr("spacing-none"), "Theme.SpacingKey.none.value"); // not .spacing-none
});

const instance = read("./fixtures/figma-instance.json");

test("expandInstances off (default): an unmapped INSTANCE stays an opaque leaf", () => {
  const { code } = generate(instance, mapping, data.tokens, apis);
  assert.match(code, /⚠️ unmapped: Login Form \(INSTANCE\)/);
  assert.doesNotMatch(code, /Giriş Yap/); // children are not walked
});

test("expandInstances on: recurses into the INSTANCE and emits valid spacing", () => {
  const { code } = generate(instance, mapping, data.tokens, apis, { expandInstances: true });
  assert.match(code, /Text\("Giriş Yap"\)/);              // child surfaced
  assert.match(code, /Theme\.SpacingKey\.xl4\.value/);    // sp-4xl → xl4 (compiles)
  assert.doesNotMatch(code, /SpacingKey\.4xl/);           // never the invalid form
  assert.doesNotMatch(code, /Text\("scribble"\)/);        // placeholder text filtered out
});

test("figma-mapping: control instances map to their ThemeKit component", () => {
  const leaf = (name, type = "INSTANCE") => ({ id: "n:1", name, type });
  const gen1 = (node) => generate(node, mapping, data.tokens, apis).code;
  assert.match(gen1(leaf("Checkbox")), /Checkbox\(isChecked: \.constant\(false\)\)/);
  assert.match(gen1(leaf("Radio")), /RadioButton\(isSelected: \.constant\(false\)\)/);
  assert.match(gen1(leaf("Toggle")), /ThemeToggle\(isOn: \.constant\(false\)\)/);
  // Divider rule is type-agnostic — also matches a "Divider Container" frame.
  assert.match(gen1(leaf("Divider Container", "FRAME")), /DividerView\(/);
});
