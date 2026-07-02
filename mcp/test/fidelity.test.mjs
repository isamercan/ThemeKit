// Tests for the fidelity pass: token-emitting containers (padding / background /
// radius / shadow), textStyle snapping, alignment + SPACE_BETWEEN, ZStack / axis
// inference, asset export, case-insensitive rules — and the server-level fixes
// (search_components synonym drift, get_migration_guide oldest-section regex).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { generate, matchTextStyle, radiusValueExpr, inferAxis } from "../dist/figma/codegen.js";
import { loadMapping, matchComponent } from "../dist/figma/mapping.js";

const here = dirname(fileURLToPath(import.meta.url));
const read = (rel) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const data = read("../data/themekit.json");
const mapping = loadMapping(join(here, "..", "figma-mapping.json"));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));
const gen = (node, opts) => generate(node, mapping, data.tokens, apis, opts);

const TEXT = (name, chars, extra = {}) => ({ id: `t-${name}`, name, type: "TEXT", characters: chars, ...extra });

// ── Container fidelity: padding / background / radius / shadow ─────────────

const promo = {
  id: "1:1", name: "Promo block", type: "INSTANCE", layoutMode: "VERTICAL", itemSpacing: 8,
  paddingLeft: 16, paddingRight: 16, paddingTop: 16, paddingBottom: 16, cornerRadius: 16,
  fills: [{ type: "SOLID", color: { r: 251 / 255, g: 253 / 255, b: 1, a: 1 } }], // #fbfdff = bg-white
  effects: [{ type: "DROP_SHADOW", visible: true, radius: 6, offset: { x: 0, y: 2 } }],
  children: [
    TEXT("Headline", "Hello", { style: { fontSize: 14, fontWeight: 400 } }),
    TEXT("Body", "World", { style: { fontSize: 14, fontWeight: 400 } }),
  ],
};

test("unmapped container emits token-snapped padding / background / radius / shadow", () => {
  const { code } = gen(promo, { expandInstances: true });
  assert.match(code, /\.padding\(Theme\.SpacingKey\.md\.value\)/);
  assert.match(code, /\.background\(theme\.background\(\.bgWhite\)\)/);
  assert.match(code, /\.cornerRadius\(Theme\.RadiusKey\.md\.value\)/);
  assert.match(code, /\.themeShadow\(\.soft\)/);
});

test("autolayout stack carries Figma's MIN alignment and snapped spacing", () => {
  const { code } = gen(promo, { expandInstances: true });
  assert.match(code, /VStack\(alignment: \.leading, spacing: Theme\.SpacingKey\.sm\.value\)/);
});

test("text nodes snap their font to a TextStyle token", () => {
  const { code, report } = gen(promo, { expandInstances: true });
  assert.match(code, /\.textStyle\(\.bodyBase400\)/);
  assert.ok(report.tokenSnaps.some((s) => s.includes(".textStyle(.bodyBase400)")));
});

// ── textStyle matcher ───────────────────────────────────────────────────────

test("matchTextStyle: exact size+weight, tolerance, and honest null", () => {
  const typo = data.tokens.filter((t) => t.category === "typography").map((t) => {
    const m = t.value.match(/^(\d+)\/\d+\s+(\w+)$/);
    return { name: t.name, size: Number(m[1]), weight: m[2] };
  });
  assert.equal(matchTextStyle(20, 600, typo), "headingSm");   // exact 20/semibold
  assert.equal(matchTextStyle(28, 600, typo), "headingMd");   // exact 28/semibold
  assert.equal(matchTextStyle(48, 500, typo), null);          // 48/medium — nothing close
});

test("radiusValueExpr maps token names to real RadiusKey cases (rd-4xl → xl4)", () => {
  assert.equal(radiusValueExpr("rd-4xl"), "Theme.RadiusKey.xl4.value");
  assert.equal(radiusValueExpr("radius-none"), "Theme.RadiusKey.none.value");
  assert.equal(radiusValueExpr("rd-sm"), "Theme.RadiusKey.sm.value");
});

// ── Layout: axis inference, ZStack, SPACE_BETWEEN ───────────────────────────

test("overlapping absolute children → ZStack, flagged for review", () => {
  const node = {
    id: "2:1", name: "Hero", type: "FRAME", layoutMode: "NONE",
    children: [
      TEXT("Back", "Back", { absoluteBoundingBox: { x: 0, y: 0, width: 100, height: 40 } }),
      TEXT("Front", "Front", { absoluteBoundingBox: { x: 10, y: 10, width: 100, height: 40 } }),
    ],
  };
  const { code, report } = gen(node);
  assert.match(code, /ZStack\(alignment: \.topLeading\)/);
  assert.ok(report.needsReview.some((s) => s.includes("ZStack")));
});

test("non-overlapping GROUP children infer a VStack, sorted top-to-bottom", () => {
  const node = {
    id: "2:2", name: "Column", type: "GROUP",
    children: [ // listed bottom-first on purpose — output must be y-sorted
      TEXT("Second", "Second", { absoluteBoundingBox: { x: 0, y: 50, width: 100, height: 40 } }),
      TEXT("First", "First", { absoluteBoundingBox: { x: 0, y: 0, width: 100, height: 40 } }),
    ],
  };
  assert.equal(inferAxis(node), "VERTICAL");
  const { code } = gen(node);
  assert.ok(code.indexOf('Text("First")') < code.indexOf('Text("Second")'), "children re-ordered by y");
});

test("SPACE_BETWEEN emits Spacer() between children", () => {
  const node = {
    id: "2:3", name: "Toolbar", type: "FRAME", layoutMode: "HORIZONTAL",
    primaryAxisAlignItems: "SPACE_BETWEEN",
    children: [TEXT("Left", "Left"), TEXT("Right", "Right")],
  };
  const { code } = gen(node);
  assert.match(code, /HStack\(alignment: \.top\)/);
  assert.ok(/Text\("Left"\)[\s\S]*Spacer\(\)[\s\S]*Text\("Right"\)/.test(code), "Spacer between the two children");
});

test("a bare autolayout frame is a layout stack, not a Card", () => {
  const node = {
    id: "2:4", name: "Section", type: "FRAME", layoutMode: "VERTICAL",
    children: [TEXT("A", "A"), TEXT("B", "B")],
  };
  assert.equal(matchComponent(node, mapping), null, "no fill/stroke/shadow → no Card heuristic");
  const { code } = gen(node);
  assert.ok(code.includes("// layout: Section"));
  assert.ok(!code.includes("Card {"));
});

test("a filled frame still becomes a Card (surface look preserved)", () => {
  const node = {
    id: "2:5", name: "Panel", type: "FRAME", layoutMode: "VERTICAL",
    fills: [{ type: "SOLID", color: { r: 1, g: 1, b: 1, a: 1 } }],
    children: [TEXT("A", "A")],
  };
  const m = matchComponent(node, mapping);
  assert.equal(m?.component, "Card");
});

// ── Assets ──────────────────────────────────────────────────────────────────

test("vector nodes and all-vector frames become exported assets", () => {
  const node = {
    id: "3:0", name: "Row", type: "FRAME", layoutMode: "HORIZONTAL",
    children: [
      { id: "3:1", name: "Star", type: "VECTOR" },
      {
        id: "3:2", name: "Icon/Search", type: "FRAME",
        children: [{ id: "3:3", name: "shape", type: "VECTOR" }, { id: "3:4", name: "handle", type: "LINE" }],
      },
    ],
  };
  const { code, report } = gen(node);
  assert.match(code, /Image\("star"\)/);
  assert.match(code, /Image\("icon-search"\)/);
  assert.equal(report.assets.length, 2, "the icon frame exports as ONE asset, not per-vector");
  assert.deepEqual(report.assets.map((a) => a.nodeId).sort(), ["3:1", "3:2"]);
  assert.match(code, /\.accessibilityLabel\(/);
});

test("gradient fills are flagged as needs-review, never silently dropped", () => {
  const node = {
    id: "3:5", name: "Gradient hero", type: "FRAME", layoutMode: "VERTICAL",
    fills: [{ type: "GRADIENT_LINEAR" }],
    children: [TEXT("T", "T")],
  };
  const { report } = gen(node);
  assert.ok(report.needsReview.some((s) => s.includes("gradient fill")));
});

test("a decorative rectangle with a token fill becomes a real shape", () => {
  const node = { // NB: not named "Divider…" — that would hit the DividerView rule first
    id: "3:6", name: "Accent bar", type: "RECTANGLE", cornerRadius: 8,
    fills: [{ type: "SOLID", color: { r: 251 / 255, g: 253 / 255, b: 1, a: 1 } }],
    absoluteBoundingBox: { x: 0, y: 0, width: 320, height: 4 },
  };
  const { code } = gen(node);
  assert.match(code, /RoundedRectangle\(cornerRadius: Theme\.RadiusKey\.sm\.value\)\.fill\(theme\.background\(\.bgWhite\)\)/);
  assert.match(code, /\.frame\(height: 4\)/);
});

// ── Mapping rules ───────────────────────────────────────────────────────────

test("rules match case-insensitively (button/primary → PrimaryButton)", () => {
  const node = {
    id: "4:1", name: "button/primary", type: "INSTANCE", layoutMode: "HORIZONTAL",
    fills: [{ type: "SOLID", color: { r: 0, g: 0.4, b: 1, a: 1 } }],
    children: [TEXT("L", "Sign in")],
  };
  const { code } = gen(node);
  assert.match(code, /PrimaryButton\("Sign in"\) \{ \}/);
});

test("new catalog rules map common instances (Tag, OTP, Skeleton)", () => {
  for (const [name, expected] of [
    ["Tag/Default", 'Tag("'],
    ["OTP Input", "OTPInput(code: .constant("],
    ["Skeleton/Line", "Skeleton()"],
  ]) {
    const node = { id: `4:${name}`, name, type: "INSTANCE", children: [TEXT("L", "New")] };
    const { code } = gen(node);
    assert.ok(code.includes(expected), `${name} → ${expected} (got: ${code.trim()})`);
  }
});

test("every new mapping rule targets a real catalog component with real param labels", () => {
  const names = new Set(data.components.map((c) => c.name));
  for (const rule of mapping.componentRules) {
    const c = data.components.find((x) => x.name === rule.produce.component);
    assert.ok(names.has(rule.produce.component), `${rule.produce.component} exists`);
    for (const label of Object.keys(rule.produce.argsFrom ?? {})) {
      if (label === "_") continue;
      assert.ok(c.params.some((p) => p.label === label), `${rule.produce.component} has a "${label}" param`);
    }
  }
});

// ── Server-level: synonym drift + migration-guide regex ─────────────────────

test("search_components and get_migration_guide survive their old crash inputs", async () => {
  const transport = new StdioClientTransport({
    command: "node",
    args: [join(here, "..", "dist", "index.js")],
    env: { ...process.env },
  });
  const client = new Client({ name: "fidelity-test", version: "1.0.0" });
  await client.connect(transport);
  try {
    // "toast" used to hit a ghost synonym and crash with a TypeError.
    const search = await client.callTool({ name: "search_components", arguments: { intent: "toast notification" } });
    assert.ok(!search.isError, "search_components did not error");
    assert.ok(search.content[0].text.includes("AlertToast"), "AlertToast is suggested");

    // The oldest CHANGELOG section was dropped by the \Z regex; 0.1.0 must resolve now.
    const guide = await client.callTool({ name: "get_migration_guide", arguments: { fromVersion: "0.1.0" } });
    assert.ok(!guide.isError, "get_migration_guide did not error");
    assert.match(guide.content[0].text, /# Migrating 0\.1\.0 → /);
  } finally {
    await client.close();
  }
});
