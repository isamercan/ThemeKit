// WCAG contrast helpers (tokenMatch) — the design_to_code codegen / mapping /
// figma-node a11y tests were removed with those modules (superseded by
// design_via_figma_mcp).
import { test } from "node:test";
import assert from "node:assert/strict";
import { contrastRatio, wcagGrade, relativeLuminance } from "../dist/figma/tokenMatch.js";

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
