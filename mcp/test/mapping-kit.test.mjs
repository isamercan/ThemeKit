// Tests for mapping a Figma UI kit to ThemeKit: componentAliases (+ the codegen
// auto-fill of required args), the THEMEKIT_MAPPING user-override merge, the
// suggest_figma_mapping tool, and the themekit://figma-mapping resource.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { generate } from "../dist/figma/codegen.js";
import { loadMapping, matchComponent } from "../dist/figma/mapping.js";

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(new URL("../data/themekit.json", import.meta.url), "utf8"));
const apis = new Map(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));
const bundled = join(here, "..", "figma-mapping.json");
const userMap = join(here, "user-mapping.tmp.json");

const withUserMapping = (obj, fn) => {
  writeFileSync(userMap, JSON.stringify(obj));
  try { return fn(loadMapping(bundled, userMap)); } finally { rmSync(userMap, { force: true }); }
};

// ── componentAliases + codegen auto-fill ────────────────────────────────────

test("an alias maps a brand component to ThemeKit with auto-filled args", () => {
  withUserMapping({ componentAliases: { MARKAADITextField: "TextInput" } }, (m) => {
    const node = { id: "1", name: "MARKAADITextField/Filled", type: "INSTANCE", children: [{ id: "2", name: "l", type: "TEXT", characters: "E-posta" }] };
    const match = matchComponent(node, m);
    assert.equal(match.component, "TextInput");
    assert.equal(match.via, "alias");
    const { code } = generate(node, m, data.tokens, apis, {});
    assert.equal(code.trim(), 'TextInput("E-posta", text: $text)');
  });
});

test("alias matches by exact name, first segment, or prefix — case-insensitive", () => {
  withUserMapping({ componentAliases: { markaadibutton: "PrimaryButton" } }, (m) => {
    for (const name of ["MARKAADIButton", "MarkaadiButton/Default", "MARKAADIButtonLarge"]) {
      assert.equal(matchComponent({ type: "INSTANCE", name, children: [] }, m)?.component, "PrimaryButton", name);
    }
  });
});

test("an alias to a component with a complex required arg flags needs-review, not silent junk", () => {
  // Select needs options:[Option] + selection binding — the array can't be synthesized.
  withUserMapping({ componentAliases: { AcmeDropdown: "Select" } }, (m) => {
    const node = { id: "1", name: "AcmeDropdown", type: "INSTANCE", children: [{ id: "2", name: "l", type: "TEXT", characters: "Pick" }] };
    const { code, report } = generate(node, m, data.tokens, apis, {});
    assert.match(code, /Select\(/);
    assert.ok(report.needsReview.some((r) => /Select/.test(r) && /Option/.test(r)), "reports the unsynthesizable arg");
  });
});

// ── THEMEKIT_MAPPING override merge ─────────────────────────────────────────

test("a partial user file overrides/adds without dropping the bundled rules", () => {
  withUserMapping({ componentAliases: { Foo: "Badge" } }, (m) => {
    assert.equal(m.componentAliases.Foo, "Badge", "user alias added");
    assert.ok(m.componentRules.length > 5, "bundled componentRules survive a partial override");
  });
});

test("a user componentRule is tried before the bundled ones", () => {
  const userRule = { match: { namePattern: "^Badge", type: "INSTANCE" }, produce: { component: "Tag", argsFrom: { _: "{text}" } } };
  withUserMapping({ componentRules: [userRule] }, (m) => {
    // bundled maps ^Badge → Badge; the user rule (first) must win → Tag.
    const match = matchComponent({ type: "INSTANCE", name: "Badge/Error", children: [] }, m);
    assert.equal(match.component, "Tag");
  });
});

// ── suggest_figma_mapping + resource (server) ───────────────────────────────

test("suggest_figma_mapping drafts aliases from brand names; resource reflects the override", async () => {
  writeFileSync(userMap, JSON.stringify({ componentAliases: { AlreadyMapped: "Badge" } }));
  const transport = new StdioClientTransport({
    command: "node", args: [join(here, "..", "dist", "index.js")],
    env: { ...process.env, THEMEKIT_MAPPING: userMap },
  });
  const client = new Client({ name: "kit-test", version: "1.0.0" });
  await client.connect(transport);
  try {
    const names = (await client.listTools()).tools.map((t) => t.name);
    assert.ok(names.includes("suggest_figma_mapping"));

    const res = await client.callTool({ name: "suggest_figma_mapping", arguments: { names: ["MARKAADITextField", "MARKAADIButton", "AlreadyMapped"], brandPrefix: "MARKAADI" } });
    const out = res.content[0].text;
    assert.match(out, /MARKAADITextField → TextInput/);
    assert.match(out, /MARKAADIButton → PrimaryButton/);
    assert.match(out, /AlreadyMapped: already mapped/);   // skipped, already in the override
    // ready-to-paste JSON block contains the aliases
    const block = out.match(/```json\n([\s\S]*?)\n```/);
    const parsed = JSON.parse(block[1]);
    assert.equal(parsed.componentAliases.MARKAADITextField, "TextInput");

    // The resource exposes the active mapping (incl. the override) for LLMs.
    const rsrc = await client.readResource({ uri: "themekit://figma-mapping" });
    assert.match(rsrc.contents[0].text, /AlreadyMapped → Badge/);
    assert.match(rsrc.contents[0].text, /Includes your override/);
  } finally {
    await client.close();
    rmSync(userMap, { force: true });
  }
});
