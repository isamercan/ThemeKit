// Tests for the v2.3 improvements: WCAG contrast, modifier-aware codegen,
// token-snapped TEXT fallback, and the config-driven migrate / mapping rules.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { contrastRatio, wcagGrade, relativeLuminance } from "../dist/figma/tokenMatch.js";
import { generate } from "../dist/figma/codegen.js";
import { loadMapping } from "../dist/figma/mapping.js";

const read = (rel) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const data = read("../data/themekit.json");
const mapping = loadMapping(fileURLToPath(new URL("../figma-mapping.json", import.meta.url)));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));

// ── WCAG contrast helpers ──────────────────────────────────────────────────
test("contrastRatio: black on white is 21:1", () => {
  assert.ok(Math.abs(contrastRatio("#000000", "#ffffff") - 21) < 0.01);
});

test("contrastRatio is symmetric and self-contrast is 1", () => {
  assert.ok(Math.abs(contrastRatio("#123456", "#abcdef") - contrastRatio("#abcdef", "#123456")) < 1e-9);
  assert.ok(Math.abs(contrastRatio("#445566", "#445566") - 1) < 1e-9);
});

test("relativeLuminance: white=1, black=0", () => {
  assert.ok(Math.abs(relativeLuminance("#ffffff") - 1) < 1e-9);
  assert.ok(Math.abs(relativeLuminance("#000000")) < 1e-9);
});

test("wcagGrade thresholds (AAA / AA / FAIL)", () => {
  assert.equal(wcagGrade(21).level, "AAA");
  assert.equal(wcagGrade(4.6).level, "AA");
  assert.equal(wcagGrade(3.2).level, "AA Large only");
  assert.equal(wcagGrade(1.5).level, "FAIL");
  assert.equal(wcagGrade(4.6).aaNormal, true);
});

// ── Modifier-aware Figma codegen ───────────────────────────────────────────
const states = read("./fixtures/figma-states.json");

test("emits .disabled(true) + .controlSize(.large) from variant properties", () => {
  const { code } = generate(states, mapping, data.tokens, apis);
  assert.match(code, /PrimaryButton\("Save"\)\s*\{\s*\}\.disabled\(true\)\.controlSize\(\.large\)/);
});

test("unmapped TEXT snaps its fill to a theme token color", () => {
  const { code } = generate(states, mapping, data.tokens, apis);
  assert.match(code, /Text\("Hello"\)\.foregroundStyle\(theme\.(?:text|foreground|background)\(\.\w+\)\)/);
});

// ── Config-driven migrate rules ────────────────────────────────────────────
const migrate = read("../migrate-rules.json");

test("migrate-rules.json is well-formed and every find compiles", () => {
  assert.ok(Array.isArray(migrate.rules) && migrate.rules.length > 0);
  for (const r of migrate.rules) {
    assert.equal(typeof r.find, "string");
    assert.equal(typeof r.replace, "string");
    assert.equal(typeof r.note, "string");
    assert.doesNotThrow(() => new RegExp(r.find, r.flags ?? "g"));
  }
});

test("a migrate rule rewrites Toggle → ThemeToggle", () => {
  const rule = migrate.rules.find((r) => /ThemeToggle/.test(r.replace));
  assert.ok(rule, "Toggle rule present");
  const out = 'Toggle("On", isOn: $flag)'.replace(new RegExp(rule.find, rule.flags ?? "g"), rule.replace);
  assert.match(out, /ThemeToggle\(isOn: \$flag\)/);
});

// ── Config-driven figma mapping modifiers ──────────────────────────────────
test("figma-mapping PrimaryButton rule carries modifier rules", () => {
  const rule = mapping.componentRules.find((r) => r.produce.component === "PrimaryButton");
  assert.ok(rule?.produce.modifiers?.some((m) => /State=Disabled/i.test(m.whenProp ?? "")));
});

// ── Figma-layer accessibility audit ────────────────────────────────────────
import { auditA11y, formatA11y } from "../dist/figma/a11yAudit.js";
const a11yNode = read("./fixtures/figma-a11y.json");
const findings = auditA11y(a11yNode);
const has = (wcag) => findings.some((f) => f.wcag.startsWith(wcag));

test("flags low-contrast text as a 1.4.3 error", () => {
  const f = findings.find((x) => x.wcag.startsWith("1.4.3") && x.node === "Faint label");
  assert.ok(f, "1.4.3 contrast finding present");
  assert.equal(f.severity, "error");
});

test("flags a sub-44pt interactive target (2.5.5)", () => {
  assert.ok(has("2.5.5"), "small touch target flagged");
});

test("flags an icon with no text alternative (1.1.1)", () => {
  assert.ok(findings.some((f) => f.wcag.startsWith("1.1.1") && /Icon\/star/.test(f.node)));
});

test("flags a sub-11pt font (1.4.4)", () => {
  assert.ok(findings.some((f) => f.wcag.startsWith("1.4.4") && f.node === "Tiny print"));
});

test("formatA11y renders a clean pass for no findings", () => {
  assert.match(formatA11y([]), /no WCAG issues/);
});

test("generate() populates report.a11y and formatReport includes it", () => {
  const card = read("./fixtures/figma-card.json");
  const { report } = generate(card, mapping, data.tokens, apis);
  assert.ok(Array.isArray(report.a11y), "report.a11y is an array");
});

