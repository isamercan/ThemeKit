/**
 * Builds mcp/data/themekit.json from the single source of truth:
 *   - component APIs  → DocC symbol graph (precise; params/types/defaults/modifiers)
 *   - design tokens   → bundled theme JSON
 *   - categories      → Components/{Atoms,Molecules,Organisms} folder layout
 *   - theme presets   → ThemePresets.swift
 * Run with `npm run build:data` (or `make mcp-data`). Never hand-edited.
 */
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSymbolGraph, parseComponents, parseEnums, type Component, type Param } from "./symbolGraph.js";
import { extractTokens, type DesignToken } from "./tokens.js";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const OUT = join(REPO, "mcp", "data", "themekit.json");

const RULES = [
  "Read the theme via `@Environment(\\.theme) private var theme`; inject `.environment(Theme.shared)` once at the root.",
  "Never hardcode a color — use `theme.text(.textPrimary)`, `theme.background(.bgWhite)`, or a `SemanticColor`.",
  "Put required content/bindings/actions in `init`; set variants, sizes, flags, colors and callbacks with chainable modifiers.",
  "Sizes use `.controlSize(_:)`; disabled state uses `.disabled(_:)`; accessibility id uses `.a11yID(_:)`.",
  "Recolor everything with `Theme.shared.applyGenerated(primaryHex:)` or a preset: `ThemePreset.named(\"dracula\")?.apply()`.",
];

/** name → Atoms/Molecules/Organisms, from the folder a component is declared in. */
function categorize(): Map<string, string> {
  const map = new Map<string, string>();
  const base = join(REPO, "Sources/ThemeKit/Components");
  for (const cat of ["Atoms", "Molecules", "Organisms"]) {
    const walk = (dir: string) => {
      for (const e of readdirSync(dir, { withFileTypes: true })) {
        const p = join(dir, e.name);
        if (e.isDirectory()) walk(p);
        else if (e.name.endsWith(".swift")) {
          const src = readFileSync(p, "utf8");
          for (const m of src.matchAll(/public struct (\w+)(?:<[^>]*>)?\s*:\s*View\b/g)) map.set(m[1], cat);
        }
      }
    };
    try { walk(join(base, cat)); } catch { /* skip */ }
  }
  return map;
}

function themePresets(): { id: string; name: string; primary: string; secondary: string; accent: string; base: string }[] {
  const src = readFileSync(join(REPO, "Sources/ThemeKit/Theme/ThemePresets.swift"), "utf8");
  const re = /\.init\(\s*"(\w+)",\s*"([^"]+)",\s*primary:\s*"(\w+)",\s*secondary:\s*"(\w+)",\s*accent:\s*"(\w+)",\s*base:\s*"(\w+)"/g;
  return [...src.matchAll(re)].map((m) => ({ id: m[1], name: m[2], primary: m[3], secondary: m[4], accent: m[5], base: m[6] }));
}

/** A copy-paste usage snippet synthesized from the shortest init's params. */
function synthUsage(name: string, params: Param[]): string {
  const placeholder = (p: Param): string => {
    const t = p.type.replace(/\s/g, "");
    if (/^Binding</.test(t)) return `$${p.name}`;
    if (/->Void$/.test(t) || /^\(\)->/.test(t)) return p.label === "_" ? "{ }" : `${p.label}: { }`;
    if (/String/.test(t)) return p.label === "_" ? `"${p.name}"` : `${p.label}: "${p.name}"`;
    if (/Int|Double|CGFloat/.test(t)) return p.label === "_" ? "1" : `${p.label}: 1`;
    if (/Bool/.test(t)) return `${p.label}: true`;
    // Unknown/complex type (e.g. a model or enum) — honest placeholder, not a guess.
    const val = p.default ?? `<${p.type.replace(/\?$/, "")}>`;
    return p.label === "_" ? val : `${p.label}: ${val}`;
  };
  const required = params.filter((p) => p.default === undefined);
  const args = required.map(placeholder).join(", ");
  return `${name}(${args})`;
}

function main() {
  const graph = loadSymbolGraph(REPO);
  const components = parseComponents(graph);
  const enums = parseEnums(graph);
  const cats = categorize();
  const tokens = extractTokens(REPO);

  const out = {
    name: "themekit",
    summary:
      "A token-driven, brand-neutral SwiftUI design system. Every color / radius / spacing / " +
      "type style is a token resolved at runtime from the active Theme; components never hardcode a color.",
    rules: RULES,
    components: components.map((c: Component) => {
      const primary = c.inits[0];
      return {
        name: c.name,
        category: cats.get(c.name) ?? "Organisms",
        doc: c.doc,
        init: primary?.signature.replace(/^@\w+\s+/, "") ?? `init()`,
        params: primary?.params ?? [],
        inits: c.inits.length > 1 ? c.inits.map((i) => i.signature.replace(/^@\w+\s+/, "")) : undefined,
        modifiers: c.modifiers,
        usage: synthUsage(c.name, primary?.params ?? []),
      };
    }),
    modifiers: [...new Set(components.flatMap((c) => c.modifiers.map((m) => m.name)))].sort(),
    enums,
    tokens,
    themes: themePresets(),
  };

  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, JSON.stringify(out, null, 2));
  console.log(
    `Wrote ${OUT} — ${out.components.length} components, ${out.modifiers.length} modifiers, ` +
    `${(out.tokens as DesignToken[]).length} tokens, ${out.themes.length} presets`
  );
}

main();
