#!/usr/bin/env node
/**
 * ThemeKit MCP server — the design system's components, modifiers, tokens and
 * theme presets as on-demand tools, resources and prompts for MCP editors.
 *
 * Single source of truth: data/themekit.json is built from the DocC symbol graph
 * (precise component APIs) + the bundled theme JSON (tokens) by `npm run build:data`
 * (`make mcp-data`). Nothing here is hand-maintained.
 */
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { PNG } from "pngjs";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { fetchFigmaNode, fetchFigmaImages, parseFigmaUrl } from "./figma/client.js";
import { loadMapping } from "./figma/mapping.js";
import { generate, formatReport, type ComponentAPI } from "./figma/codegen.js";
import { deltaE, contrastRatio, wcagGrade } from "./figma/tokenMatch.js";
import { auditA11y, formatA11y } from "./figma/a11yAudit.js";
import { buildVariables, toFigmaRestPayload } from "./figma/variables.js";
interface Param { label: string; name: string; type: string; default?: string; }
interface Modifier { name: string; signature: string; doc: string; }
interface Component { name: string; category: string; doc: string; init: string; params: Param[]; inits?: string[]; modifiers: Modifier[]; usage: string; }
interface DesignToken { category: string; name: string; value: string; role?: string; }
interface ThemePreset { id: string; name: string; primary: string; secondary: string; accent: string; base: string; }
interface Data {
  summary: string; rules: string[]; components: Component[]; modifiers: string[];
  enums: Record<string, string[]>; tokens: DesignToken[]; themes: ThemePreset[];
}

const here = dirname(fileURLToPath(import.meta.url));        // mcp/dist
const REPO = join(here, "..", "..");                          // repo root (when run in-repo)
const data: Data = JSON.parse(readFileSync(join(here, "..", "data", "themekit.json"), "utf8"));
const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });
const find = (name: string) => data.components.find((c) => c.name.toLowerCase() === name.toLowerCase());
/** Exact catalog names — guards synonym/candidate lists against drift from the generated data. */
const CATALOG = new Set(data.components.map((c) => c.name));

// Single source of truth for the version — read package.json, never hardcode.
const pkg = JSON.parse(readFileSync(join(here, "..", "package.json"), "utf8")) as { version?: string };
const server = new McpServer({ name: "themekit", version: pkg.version ?? "0.0.0" });

// Config-driven SwiftUI → ThemeKit migration rules (migrate-rules.json). Editable, not hardcoded.
interface MigrateRule { find: string; replace: string; note: string; flags?: string; }
function loadMigrateRules(): MigrateRule[] {
  const path = join(here, "..", "migrate-rules.json");
  if (!existsSync(path)) return [];
  try {
    const raw = JSON.parse(readFileSync(path, "utf8")) as { rules?: MigrateRule[] };
    return (raw.rules ?? []).filter((r) => typeof r?.find === "string" && typeof r?.replace === "string");
  } catch { return []; }
}
const MIGRATE_RULES = loadMigrateRules();

// ── Read layer ─────────────────────────────────────────────────────────────

server.registerTool("usage_guide", {
  title: "ThemeKit usage guide",
  description: "The golden rules for writing correct ThemeKit code. Read this first.",
  inputSchema: {},
}, async () => text([data.summary, "", "Rules:", ...data.rules.map((r) => `- ${r}`)].join("\n")));

server.registerTool("list_components", {
  title: "List components",
  description: "All components by category (Atoms / Molecules / Organisms) with a one-line summary.",
  inputSchema: { category: z.enum(["Atoms", "Molecules", "Organisms"]).optional() },
}, async ({ category }) => {
  const items = data.components.filter((c) => !category || c.category === category);
  const byCat: Record<string, string[]> = {};
  for (const c of items) (byCat[c.category] ??= []).push(`${c.name}${c.doc ? ` — ${c.doc}` : ""}`);
  return text(Object.entries(byCat).map(([c, n]) => `## ${c} (${n.length})\n${n.map((x) => `- ${x}`).join("\n")}`).join("\n\n"));
});

server.registerTool("get_component_api", {
  title: "Get component API (exact)",
  description: "The PRECISE public API of a component from the symbol graph: init parameters (label, type, default, required), extra inits, and chainable modifiers with signatures. Use this so you never invent parameters.",
  inputSchema: { name: z.string().describe("Component name, e.g. Badge, TextInput, Carousel") },
}, async ({ name }) => {
  const c = find(name);
  if (!c) return text(`No component "${name}". Try list_components or search_components.`);
  const rows = c.params.map((p) => {
    const lbl = p.label === "_" ? `(positional) ${p.name}` : p.label;
    return `- ${lbl}: ${p.type}${p.default !== undefined ? ` = ${p.default}` : "  (required)"}`;
  });
  const out = [`# ${c.name} (${c.category})`, c.doc, "", `**Init:** \`${c.init}\``];
  if (rows.length) out.push("", "**Parameters:**", ...rows);
  if (c.inits?.length) out.push("", "**Other inits:**", ...c.inits.slice(1).map((i) => `- \`${i}\``));
  if (c.modifiers.length) {
    out.push("", "**Modifiers (chain after the init):**");
    for (const m of c.modifiers) out.push(`- \`.${m.signature.replace(/^\./, "")}\`${m.doc ? ` — ${m.doc}` : ""}`);
  }
  out.push("", `Example: \`${c.usage}\``, "Sizes use `.controlSize(_:)`; disabled uses `.disabled(_:)`; never hardcode a color.");
  return text(out.join("\n"));
});

server.registerTool("get_design_tokens", {
  title: "Get design tokens",
  description: "Design tokens with their real values — colors, radius (+ box/field/selector roles), spacing, typography, shadow, semantic colors. Use category 'contrast' for a WCAG text-on-surface contrast report. Filter by category.",
  inputSchema: { category: z.string().optional().describe("e.g. text, background, radius, radiusRole, spacing, typography, semanticColor, contrast") },
}, async ({ category }) => {
  if (category && category.toLowerCase() === "contrast") {
    const surfaces = data.tokens.filter((t) => t.category === "background" && /^#[0-9a-fA-F]{6}$/.test(t.value) && /bg-white|bg-elevator-primary|bg-hero|bg-tertiary/.test(t.name));
    const texts = data.tokens.filter((t) => t.category === "text" && /^#[0-9a-fA-F]{6}$/.test(t.value));
    const out: string[] = ["## Text-on-surface contrast (WCAG 2.1)", "Ratio ≥ 4.5 = AA normal · ≥ 3 = AA large · ≥ 7 = AAA.", ""];
    for (const s of surfaces) {
      out.push(`### on ${s.name} (${s.value})`);
      for (const t of texts) {
        const r = contrastRatio(t.value, s.value);
        const g = wcagGrade(r);
        out.push(`- ${t.name}: ${r.toFixed(2)}:1  ${g.level === "FAIL" ? "✗ FAIL" : "✓ " + g.level}`);
      }
      out.push("");
    }
    return text(out.join("\n"));
  }
  const toks = data.tokens.filter((t) => !category || t.category.toLowerCase() === category.toLowerCase());
  if (!toks.length) {
    const cats = [...new Set(data.tokens.map((t) => t.category))].join(", ");
    return text(`No tokens for "${category}". Categories: ${cats}, contrast`);
  }
  const byCat: Record<string, string[]> = {};
  for (const t of toks) (byCat[t.category] ??= []).push(`${t.name} = ${t.value}${t.role ? `  (${t.role})` : ""}`);
  return text(Object.entries(byCat).map(([c, v]) => `## ${c}\n${v.join("\n")}`).join("\n\n"));
});

server.registerTool("get_usage_snippet", {
  title: "Get usage snippet",
  description: "A copy-paste example for a component. variant: basic (minimal init) / full (init + its modifiers chained).",
  inputSchema: { name: z.string(), variant: z.enum(["basic", "full"]).optional() },
}, async ({ name, variant }) => {
  const c = find(name);
  if (!c) return text(`No component "${name}".`);
  if (variant === "full" && c.modifiers.length) {
    const chain = c.modifiers.slice(0, 3).map((m) => `.${m.name.replace(/\(.*/, "")}()`).join("");
    return text("```swift\n" + `${c.usage}${chain}` + "\n```");
  }
  return text("```swift\n" + c.usage + "\n```");
});

const SYNONYMS: Record<string, string[]> = {
  date: ["DateField", "CalendarView"], calendar: ["CalendarView", "DateField"],
  picker: ["Select", "SelectBox", "MultiSelect", "SegmentedControl", "ThemePicker"],
  dropdown: ["Select", "MultiSelect", "Autocomplete"], select: ["Select", "SelectBox", "MultiSelect"],
  input: ["TextInput", "MultiLineTextInput", "InputNumber", "OTPInput", "SearchBar"],
  text: ["TextInput", "MultiLineTextInput", "Title", "InlineText"], search: ["SearchBar", "Autocomplete"],
  number: ["InputNumber", "QuantityStepper", "RollingNumber", "Counter"], otp: ["OTPInput"],
  toggle: ["ThemeToggle", "Checkbox", "RadioButton", "Swap"], checkbox: ["Checkbox", "CheckboxGroup"],
  radio: ["RadioButton", "RadioGroup"], slider: ["Slider", "RangeSlider"],
  list: ["DataTable", "Accordion", "TreeSelect"], table: ["DataTable"], tree: ["TreeSelect"],
  feedback: ["AlertToast", "Callout", "InfoBanner", "ResultView", "EmptyState"],
  alert: ["AlertToast", "Callout", "InfoBanner"], toast: ["AlertToast"], empty: ["EmptyState"],
  loading: ["Spinner", "Skeleton", "ProgressBar", "RadialProgress"], progress: ["ProgressBar", "RadialProgress", "Steps"],
  button: ["PrimaryButton", "SecondaryButton", "ThemeButton", "ButtonGroup", "ShareButton"],
  rating: ["Rating"], star: ["Rating"], badge: ["Badge", "ScoreBadge", "Counter"],
  filter: ["Chip", "FilterChip", "ChipGroup", "FilterGroup"], chip: ["Chip", "ImageChip", "CompactChip"],
  tag: ["Tag"], avatar: ["Avatar", "AvatarGroup"], card: ["Card", "CardStack"], carousel: ["Carousel"],
  image: ["RemoteImage", "AnimatedImage", "ImageChip"], video: ["VideoPlayerView"],
  nav: ["NavigationBar", "Breadcrumbs", "SegmentedTabBar", "Pagination"], tab: ["SegmentedTabBar", "SegmentedControl"],
  theme: ["ThemePicker", "ThemeToggle", "ColorField"], color: ["ColorField"],
  step: ["Steps", "StepIndicator", "QuantityStepper"], divider: ["DividerView"],
};

server.registerTool("search_components", {
  title: "Search components by intent",
  description: "Find components for a need, e.g. 'a selectable filter list' or 'date picker'. Keyword + synonym scoring.",
  inputSchema: { intent: z.string() },
}, async ({ intent }) => {
  const words = intent.toLowerCase().split(/\W+/).filter(Boolean);
  const score = new Map<string, number>();
  const bump = (name: string, by: number) => score.set(name, (score.get(name) ?? 0) + by);
  for (const w of words) {
    // Only bump synonyms that exist in the generated catalog — a stale synonym must never crash the tool.
    for (const cand of SYNONYMS[w] ?? []) if (CATALOG.has(cand)) bump(cand, 3);
    for (const c of data.components) {
      if (c.name.toLowerCase() === w) bump(c.name, 5);
      else if (c.name.toLowerCase().includes(w)) bump(c.name, 2);
      if (c.doc.toLowerCase().includes(w)) bump(c.name, 1);
    }
  }
  const ranked = [...score.entries()].filter(([, s]) => s > 0).sort((a, b) => b[1] - a[1]).slice(0, 10);
  if (!ranked.length) return text(`No components matched "${intent}". Try list_components.`);
  return text(ranked.flatMap(([n, s]) => {
    const c = find(n);
    return c ? [`- ${n} (${c.category}, score ${s}) — ${c.doc || c.init}`] : [];
  }).join("\n"));
});

server.registerTool("get_variants_states", {
  title: "Get variants & states",
  description: "A component's style variants (enum-typed params resolved to their cases) and the states it supports (disabled / size / selection / flags).",
  inputSchema: { name: z.string() },
}, async ({ name }) => {
  const c = find(name);
  if (!c) return text(`No component "${name}".`);
  const out = [`# ${c.name} — variants & states`];
  const variantParams = c.params.filter((p) => data.enums[p.type.replace(/\?$/, "")]);
  if (variantParams.length) {
    out.push("", "**Variants:**");
    for (const p of variantParams) out.push(`- ${p.label === "_" ? p.name : p.label} (${p.type}): ${data.enums[p.type.replace(/\?$/, "")].join(", ")}`);
  }
  const flags = c.modifiers.filter((m) => /Bool = true|_ on:|_ enabled:/.test(m.signature) || /^(loading|highlighted|exists|interactive|expands|gradient|fade|loop|arrows|dots|muted|allowHalf|simple)/.test(m.name)).map((m) => `.${m.name.replace(/\(.*/, "")}()`);
  out.push("", "**States:** `.disabled(_:)` · `.controlSize(_:)`" + (c.params.some((p) => /Binding<Bool>/.test(p.type)) ? " · selection (Binding)" : "") + (flags.length ? " · flags: " + flags.join(" ") : ""));
  return text(out.join("\n"));
});

server.registerTool("get_migration_guide", {
  title: "Migration guide between versions",
  description: "What changed between two ThemeKit versions (from the CHANGELOG) — breaking changes first, then additions. Omit `to` for the latest.",
  inputSchema: { fromVersion: z.string().describe('e.g. "0.1.1"'), toVersion: z.string().optional() },
}, async ({ fromVersion, toVersion }) => {
  // In-repo: the live CHANGELOG at the repo root. npm install: the copy bundled
  // into data/ by build:data (REPO points outside the package there).
  const candidates = [join(REPO, "CHANGELOG.md"), join(here, "..", "data", "THEMEKIT-CHANGELOG.md")];
  const path = candidates.find(existsSync);
  if (!path) return text("The ThemeKit CHANGELOG was not found (rebuild the package data with `make mcp-data`).");
  const md = readFileSync(path, "utf8");
  // Split into [version] sections in file order (newest first).
  // NB: JS has no \Z anchor — `$(?![\s\S])` is the true end-of-string (so the oldest section still matches).
  const re = /^##\s*\[(\d+\.\d+\.\d+)\][^\n]*\n([\s\S]*?)(?=^##\s*\[|$(?![\s\S]))/gm;
  const sections: { v: string; body: string }[] = [];
  for (const m of md.matchAll(re)) sections.push({ v: m[1], body: m[2].trim() });
  const versions = sections.map((s) => s.v);
  const cmp = (a: string, b: string) => a.split(".").map(Number).reduce((acc, n, i) => acc || n - Number(b.split(".")[i]), 0);
  if (!versions.includes(fromVersion)) return text(`Version "${fromVersion}" not in the changelog. Available: ${versions.join(", ")}`);
  const to = toVersion ?? versions[0];
  // Sections strictly above `from`, up to and including `to`.
  const range = sections.filter((s) => cmp(s.v, fromVersion) > 0 && cmp(s.v, to) <= 0);
  if (!range.length) return text(`No releases between ${fromVersion} and ${to}.`);
  const out = [`# Migrating ${fromVersion} → ${to}`];
  for (const s of range) {
    out.push(`\n## ${s.v}`);
    const breaking = s.body.match(/###\s*[⚠️\s]*Breaking[\s\S]*?(?=\n###|\Z)/);
    if (breaking) out.push(breaking[0].trim());
    else out.push(s.body.split("\n").slice(0, 12).join("\n"));
  }
  out.push("\nFor full details see CHANGELOG.md.");
  return text(out.join("\n"));
});

// ── Theme tools ────────────────────────────────────────────────────────────

server.registerTool("list_themes", {
  title: "List theme presets", description: "The bundled theme-preset ids.", inputSchema: {},
}, async () => text(data.themes.map((t) => `${t.id} (${t.name})`).join("\n")));

server.registerTool("theme_colors", {
  title: "Theme preset colors", description: "A preset's primary / secondary / accent / base hexes.",
  inputSchema: { id: z.string().describe('Preset id, e.g. "dracula"') },
}, async ({ id }) => {
  const t = data.themes.find((x) => x.id === id);
  if (!t) return text(`No preset "${id}". Use list_themes.`);
  return text(`${t.name}\nprimary #${t.primary}\nsecondary #${t.secondary}\naccent #${t.accent}\nbase #${t.base}`);
});

server.registerTool("diff_theme", {
  title: "Diff two theme presets",
  description: "Compares two presets channel by channel — primary / secondary / accent / base — with the per-channel CIE76 ΔE so you can see how far apart two brands really are. ΔE < 2 ≈ indistinguishable; 2–10 close; > 10 clearly different.",
  inputSchema: {
    a: z.string().describe('First preset id, e.g. "dracula"'),
    b: z.string().describe('Second preset id, e.g. "nord"'),
  },
}, async ({ a, b }) => {
  const ta = data.themes.find((t) => t.id === a);
  const tb = data.themes.find((t) => t.id === b);
  if (!ta) return text(`No preset "${a}". Use list_themes.`);
  if (!tb) return text(`No preset "${b}". Use list_themes.`);
  const channels: ("primary" | "secondary" | "accent" | "base")[] = ["primary", "secondary", "accent", "base"];
  const rows = channels.map((ch) => {
    const ha = `#${ta[ch]}`, hb = `#${tb[ch]}`;
    const dE = deltaE(ha, hb);
    const verdict = dE < 2 ? "≈ same" : dE <= 10 ? "close" : "different";
    return `- ${ch}: ${ha} → ${hb}  (ΔE ${dE.toFixed(1)}, ${verdict})`;
  });
  const changed = channels.filter((ch) => ta[ch].toLowerCase() !== tb[ch].toLowerCase()).length;
  return text([`# ${ta.name} → ${tb.name}`, `${changed}/${channels.length} channels differ.`, "", ...rows].join("\n"));
});

server.registerTool("theme_snippet", {
  title: "Theme apply snippet", description: "Swift code to apply a preset live, or show the picker.",
  inputSchema: { id: z.string().optional() },
}, async ({ id }) => {
  const found = id ? data.themes.find((t) => t.id === id) : undefined;
  if (id && !found) return text(`No preset "${id}". Use list_themes.`);
  const tid = found?.id ?? data.themes[0]?.id ?? "light";
  return text([`ThemePreset.named("${tid}")?.apply()         // recolor live`, ``,
    `@State private var active: String? = "${tid}"`, `ThemePicker(selection: $active)              // a grid of all presets`].join("\n"));
});

server.registerTool("generate_theme", {
  title: "Generate a theme", description: "Swift applying a custom theme from an accent (+ optional base / secondary / accent / dark).",
  inputSchema: { primaryHex: z.string(), baseHex: z.string().optional(), secondaryHex: z.string().optional(), accentHex: z.string().optional(), dark: z.boolean().optional() },
}, async ({ primaryHex, baseHex, secondaryHex, accentHex, dark }) => {
  const a = [`primaryHex: "${primaryHex}"`];
  if (baseHex) a.push(`baseHex: "${baseHex}"`);
  if (secondaryHex) a.push(`secondaryHex: "${secondaryHex}"`);
  if (accentHex) a.push(`accentHex: "${accentHex}"`);
  if (dark) a.push(`dark: true`);
  return text(`Theme.shared.apply(ThemeConfig(${a.join(", ")}))`);
});

server.registerTool("design_md_to_themeconfig", {
  title: "design.md → ThemeConfig",
  description:
    "Turn a free-form design.md into a ThemeKit ThemeConfig. You (the client) read the markdown and infer each value; this tool validates/normalizes them (clamps tint, lowercases hex, whitelists the font) and emits both the `Theme.shared.apply(ThemeConfig(...))` snippet and a matching theme.json block for `ThemeConfig(jsonData:)`. Every component re-skins to the result.",
  inputSchema: {
    primaryHex: z.string().describe("6-digit RRGGBB derived from the doc's brand/primary color"),
    baseHex: z.string().optional().describe("Surface / background (daisyUI base-100)"),
    secondaryHex: z.string().optional(),
    accentHex: z.string().optional(),
    tint: z.number().min(0).max(0.25).optional().describe("How strongly the accent bleeds into neutrals"),
    dark: z.boolean().optional(),
    font: z.enum(["Montserrat", "System", "SystemRounded", "SystemSerif", "SystemMono"]).optional(),
    fontScale: z.number().optional(),
    radiusScale: z.number().optional().describe("≈1.0; <1 sharper corners, >1 rounder"),
    spacingScale: z.number().optional().describe("≈1.0; <1 compact, >1 airy"),
    shadowScale: z.number().optional().describe("0 flat … >1 elevated"),
    notes: z.string().optional().describe("What in the doc drove each choice (echoed for confirmation)"),
  },
}, async (a) => {
  const hex = (h?: string) => (h ? h.replace(/^#/, "").toLowerCase() : undefined);
  const isHex6 = (h?: string) => !!h && /^[0-9a-f]{6}$/.test(h);
  const primary = hex(a.primaryHex);
  if (!isHex6(primary)) return text(`Invalid primaryHex "${a.primaryHex}" — expected 6-digit RRGGBB.`);

  const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);
  const cfg: Record<string, string | number | boolean> = { primaryHex: primary! };
  const base = hex(a.baseHex); if (isHex6(base)) cfg.baseHex = base!;
  const sec = hex(a.secondaryHex); if (isHex6(sec)) cfg.secondaryHex = sec!;
  const acc = hex(a.accentHex); if (isHex6(acc)) cfg.accentHex = acc!;
  if (a.tint !== undefined) cfg.tint = clamp(a.tint, 0, 0.25);
  if (a.dark !== undefined) cfg.dark = a.dark;
  if (a.font) cfg.font = a.font;
  if (a.fontScale !== undefined) cfg.fontScale = a.fontScale;
  if (a.radiusScale !== undefined) cfg.radiusScale = a.radiusScale;
  if (a.spacingScale !== undefined) cfg.spacingScale = a.spacingScale;
  if (a.shadowScale !== undefined) cfg.shadowScale = a.shadowScale;

  const args = Object.entries(cfg)
    .map(([k, v]) => (typeof v === "string" ? `${k}: "${v}"` : `${k}: ${v}`))
    .join(", ");
  const lines = [
    a.notes ? `// ${a.notes}` : undefined,
    `Theme.shared.apply(ThemeConfig(${args}))`,
    ``,
    `// or ship it as theme.json and apply with ThemeConfig(jsonData:):`,
    JSON.stringify(cfg, null, 2),
  ].filter(Boolean) as string[];
  return text(lines.join("\n"));
});

// ── Theme preview image (pngjs) ────────────────────────────────────────────

function hexToRgb(h: string): [number, number, number] {
  const s = h.replace("#", "");
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function themePNG(t: ThemePreset): string {
  const W = 480, H = 150;
  const png = new PNG({ width: W, height: H });
  const base = hexToRgb(t.base);
  const isDark = (base[0] * 0.299 + base[1] * 0.587 + base[2] * 0.114) / 255 < 0.5;
  const border: [number, number, number] = isDark ? [255, 255, 255] : [0, 0, 0];
  const set = (x: number, y: number, c: [number, number, number], a = 255) => {
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    const i = (W * y + x) << 2; png.data[i] = c[0]; png.data[i + 1] = c[1]; png.data[i + 2] = c[2]; png.data[i + 3] = a;
  };
  const rect = (x0: number, y0: number, w: number, h: number, c: [number, number, number], a = 255) => {
    for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) set(x, y, c, a);
  };
  rect(0, 0, W, H, base);
  rect(0, 0, W, 8, hexToRgb(t.primary));
  const cols = [t.primary, t.secondary, t.accent].map(hexToRgb);
  const pad = 28, gap = 20, sh = 78, sw = Math.round((W - pad * 2 - gap * 2) / 3);
  cols.forEach((c, i) => { const x = pad + i * (sw + gap), y = 44; rect(x - 1, y - 1, sw + 2, sh + 2, border, 40); rect(x, y, sw, sh, c); });
  return PNG.sync.write(png).toString("base64");
}

server.registerTool("theme_preview", {
  title: "Theme preview image", description: "A PNG swatch card for a preset (renders inline).",
  inputSchema: { id: z.string() },
}, async ({ id }) => {
  const t = data.themes.find((x) => x.id === id);
  if (!t) return text(`No preset "${id}". Use list_themes.`);
  return { content: [
    { type: "image" as const, data: themePNG(t), mimeType: "image/png" },
    { type: "text" as const, text: `${t.name} — primary #${t.primary} · secondary #${t.secondary} · accent #${t.accent} · base #${t.base}` },
  ] };
});

server.registerTool("render_preview", {
  title: "Render a component preview",
  description: "Returns the rendered PNG of a component (the library's own gallery render), light or dark. Lets you see what it looks like before using it.",
  inputSchema: { component: z.string().describe("Component name, e.g. Badge"), dark: z.boolean().optional() },
}, async ({ component, dark }) => {
  const c = find(component);
  const name = c?.name ?? component;
  const fileName = `${name}${dark ? "-dark" : ""}.png`;
  const file = join(REPO, "Screenshots", fileName);
  let png: string | null = null;
  if (existsSync(file)) {
    png = readFileSync(file).toString("base64");
  } else {
    // npm install: the gallery isn't bundled (≈8 MB) — fetch the same render from GitHub.
    try {
      const res = await fetch(`https://raw.githubusercontent.com/isamercan/ThemeKit/main/Screenshots/${encodeURIComponent(fileName)}`);
      if (res.ok) png = Buffer.from(await res.arrayBuffer()).toString("base64");
    } catch { /* offline — fall through to the text fallback */ }
  }
  if (!png) {
    return text(`No rendered preview for "${name}". Gallery renders live in Screenshots/ (regenerate with \`make screenshots\`); some live/overlay components aren't captured. Try get_component_api + get_usage_snippet instead.`);
  }
  return { content: [
    { type: "image" as const, data: png, mimeType: "image/png" },
    { type: "text" as const, text: `${name}${dark ? " (dark)" : ""} — ${c?.usage ?? ""}` },
  ] };
});

// ── Act tools ──────────────────────────────────────────────────────────────

const LINT_RULES: { re: RegExp; msg: string }[] = [
  { re: /Color\((?:hex:|red:|\.s)/, msg: "Hardcoded color — use a theme token or SemanticColor." },
  { re: /\.(?:foregroundStyle|foregroundColor|fill|background|tint)\(\s*\.(?:blue|red|green|orange|yellow|purple|pink|gray|grey|black|white|indigo|teal|mint|cyan|brown)\b/, msg: "Hardcoded system color — use a theme token / SemanticColor." },
  { re: /\bisEnabled:\s*/, msg: "`isEnabled:` is not an init arg — use the native `.disabled(_:)` modifier." },
  { re: /\.cornerRadius\(\s*\d/, msg: "Hardcoded corner radius — use Theme.RadiusRole.box/field/selector.value." },
  { re: /cornerRadius:\s*\d/, msg: "Hardcoded corner radius literal — use a RadiusRole/RadiusKey token." },
  { re: /\.font\(\.system\(/, msg: "Raw system font — use `.textStyle(.bodyBase400 | .headingSm | …)`." },
  { re: /\.padding\(\s*\d/, msg: "Hardcoded padding — use Theme.SpacingKey.sm/md/lg.value." },
];
const PREFER_RULES: { re: RegExp; msg: string }[] = [
  { re: /(?<![.\w])Button\s*\(/, msg: "Prefer a ThemeKit button: PrimaryButton / SecondaryButton / ThemeButton." },
  { re: /(?<![.\w])TextField\s*\(/, msg: "Prefer TextInput (or MultiLineTextInput)." },
  { re: /(?<!Theme)(?<![.\w])Toggle\s*\(/, msg: "Prefer ThemeToggle." },
  { re: /(?<![.\w])Divider\s*\(\s*\)/, msg: "Prefer DividerView." },
  { re: /(?<![.\w])ProgressView\s*\(/, msg: "Prefer Spinner or ProgressBar." },
];

server.registerTool("lint_snippet", {
  title: "Lint ThemeKit code", description: "Flags ThemeKit anti-patterns (hardcoded colors / radius / fonts / padding, isEnabled: arg) with fixes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  const lines = swift.split("\n");
  const f: string[] = [];
  lines.forEach((line, i) => { for (const r of LINT_RULES) if (r.re.test(line)) f.push(`L${i + 1}: ${r.msg}\n    ${line.trim()}`); });
  return text(f.length ? `${f.length} issue(s):\n\n${f.join("\n\n")}` : "✓ No ThemeKit anti-patterns found.");
});

// Known SwiftUI / Foundation types & ThemeKit non-View types — so they're never flagged as "unknown".
const SWIFTUI_BUILTINS = new Set([
  "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "LazyVGrid", "LazyHGrid", "Grid", "GridRow",
  "ScrollView", "List", "ForEach", "Group", "Section", "Text", "Image", "Color", "Label", "Spacer",
  "Divider", "Button", "Toggle", "TextField", "SecureField", "Picker", "Slider", "Stepper", "ProgressView",
  "NavigationStack", "NavigationView", "NavigationLink", "NavigationSplitView", "TabView", "Form",
  "GeometryReader", "Rectangle", "RoundedRectangle", "Circle", "Capsule", "Ellipse", "Path", "Menu",
  "Link", "DatePicker", "Gauge", "Table", "DisclosureGroup", "ControlGroup", "ViewThatFits", "AnyView",
  "EmptyView", "Font", "LinearGradient", "RadialGradient", "AngularGradient", "Gradient", "Animation",
  "Binding", "State", "EnvironmentObject", "ObservedObject", "StateObject",
]);
const THEMEKIT_TYPES = new Set([
  "Theme", "ThemeConfig", "ThemePreset", "ThemeContext", "SemanticColor", "TextStyle", "ShadowStyle",
  "ValidationRule", "AsyncValidationRule", "Validator", "FormValidator", "InfoMessage",
]);

/** Blanks string literals and strips line comments so detectors don't trip on text/comments. */
function maskCode(line: string): string {
  return line.replace(/\/\/.*$/, "").replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

/** Levenshtein distance (for "did you mean" suggestions). */
function lev(a: string, b: string): number {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) => [i, ...Array(n).fill(0)]);
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) for (let j = 1; j <= n; j++)
    dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return dp[m][n];
}

server.registerTool("validate_code", {
  title: "Validate a ThemeKit screen",
  description: "Full check: anti-patterns (string/comment-aware) + raw-SwiftUI components that have ThemeKit equivalents + unknown/hallucinated component detection (vs the real catalog, with a did-you-mean) + multi-line brace/paren/bracket balance + a PASS/FAIL verdict.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => text(lintVerdict(swift)));

/** Core of validate_code: returns the formatted PASS/FAIL verdict for a snippet. */
function lintVerdict(swift: string): string {
  const lines = swift.split("\n");
  const masked = lines.map(maskCode);
  const issues: string[] = [];
  // Anti-patterns (run on masked lines so strings/comments don't false-positive).
  masked.forEach((line, i) => { for (const r of [...LINT_RULES, ...PREFER_RULES]) if (r.re.test(line)) issues.push(`L${i + 1}: ${r.msg}\n    ${lines[i].trim()}`); });

  // Multi-line awareness: brace / paren / bracket balance across the whole snippet.
  const masktext = masked.join("\n");
  const balance: string[] = [];
  for (const [open, close, label] of [["{", "}", "braces"], ["(", ")", "parens"], ["[", "]", "brackets"]] as const) {
    const diff = masktext.split(open).length - masktext.split(close).length;
    if (diff !== 0) balance.push(`Unbalanced ${label}: ${Math.abs(diff)} ${diff > 0 ? `unclosed '${open}'` : `extra '${close}'`}.`);
  }

  // Known ThemeKit components actually used.
  const names = new Set(data.components.map((c) => c.name));
  const calls = [...new Set((masktext.match(/\b[A-Z]\w+(?=\s*\()/g) || []))];
  const used = calls.filter((n) => names.has(n));

  // Unknown PascalCase calls that are neither ThemeKit nor known SwiftUI/ThemeKit types → likely hallucinated.
  const unknown = calls.filter((n) => !names.has(n) && !SWIFTUI_BUILTINS.has(n) && !THEMEKIT_TYPES.has(n));
  const unknownReport = unknown.map((n) => {
    const near = [...names].map((c) => [c, lev(n.toLowerCase(), c.toLowerCase())] as const).sort((a, b) => a[1] - b[1])[0];
    const hint = near && near[1] <= 3 ? `  (did you mean ${near[0]}?)` : "  (verify it exists — search_components)";
    return `- ${n}${hint}`;
  });

  // FAIL on anti-patterns, unbalanced delimiters, or unknown components (hallucinated APIs).
  const failCount = issues.length + balance.length + unknown.length;
  const head = failCount ? `✗ FAIL — ${failCount} issue(s):` : "✓ PASS — no ThemeKit issues found.";
  const parts = [head];
  if (issues.length) parts.push("\n" + issues.join("\n\n"));
  if (balance.length) parts.push("\nStructure:\n" + balance.map((b) => `- ${b}`).join("\n"));
  if (unknown.length) parts.push(`\n⚠️ Unknown components (not in the ThemeKit catalog or known SwiftUI types):\n${unknownReport.join("\n")}`);
  parts.push(used.length ? `\nThemeKit components used (${used.length}): ${used.join(", ")}` : "\n⚠️ No ThemeKit components detected.");
  return parts.join("\n");
}

// Components that are interactive (should carry an accessibility id / label).
const INTERACTIVE = /\b(PrimaryButton|SecondaryButton|ThemeButton|ShareButton|ButtonGroup|TextInput|MultiLineTextInput|InputNumber|OTPInput|SearchBar|Select|MultiSelect|Autocomplete|Checkbox|RadioButton|RadioGroup|Slider|RangeSlider|ThemeToggle|SegmentedControl|QuantityStepper|Chip|FAB|DateField)\s*\(/;

server.registerTool("a11y_audit", {
  title: "Accessibility audit",
  description: "Audits a ThemeKit SwiftUI snippet for accessibility gaps: interactive components missing `.a11yID(_:)`, images/icons without an accessibility label, hardcoded colors (which break Dynamic Color / contrast guarantees), and any hex pairs whose WCAG contrast you should verify. Returns a PASS/WARN verdict with line numbers and fixes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  const lines = swift.split("\n");
  const findings: string[] = [];
  lines.forEach((line, i) => {
    const ln = i + 1;
    if (INTERACTIVE.test(line) && !/\.a11yID\(/.test(line)) {
      // Allow a multi-line chain: only flag if the next 2 lines also lack a11yID.
      const window = lines.slice(i, i + 3).join(" ");
      if (!/\.a11yID\(/.test(window)) findings.push(`L${ln}: interactive control without .a11yID(_:) — add an identifier for UI tests & VoiceOver.\n    ${line.trim()}`);
    }
    if (/\b(Icon|RemoteImage|AnimatedImage|Image)\s*\(/.test(line) && !/accessibilityLabel|\.a11yID\(|decorative/.test(lines.slice(i, i + 3).join(" "))) {
      findings.push(`L${ln}: image/icon without an accessibility label — add .accessibilityLabel(_:) or mark it decorative.\n    ${line.trim()}`);
    }
    const hex = line.match(/Color\(hex:\s*"?#?([0-9a-fA-F]{6})"?\)/);
    if (hex) findings.push(`L${ln}: hardcoded color #${hex[1]} — use a theme token so contrast tracks the active theme.\n    ${line.trim()}`);
  });
  // If two hardcoded hexes appear, compute their contrast as a hint.
  const hexes = [...swift.matchAll(/#([0-9a-fA-F]{6})\b/g)].map((m) => `#${m[1]}`);
  let contrastNote = "";
  if (hexes.length >= 2) {
    const r = contrastRatio(hexes[0], hexes[1]);
    const g = wcagGrade(r);
    contrastNote = `\n\nContrast hint: ${hexes[0]} vs ${hexes[1]} = ${r.toFixed(2)}:1 (${g.level}). Prefer tokens; check get_design_tokens category=contrast.`;
  }
  const head = findings.length ? `⚠️ WARN — ${findings.length} accessibility issue(s):` : "✓ PASS — no obvious accessibility gaps. Verify color contrast with get_design_tokens category=contrast.";
  return text(`${head}${findings.length ? "\n\n" + findings.join("\n\n") : ""}${contrastNote}`);
});

const SCAFFOLDS: Record<string, string> = {
  form: `Card(title: "Sign up") {\n  VStack(spacing: Theme.SpacingKey.md.value) {\n    TextInput("Email", text: $email, leadingSystemImage: "envelope").a11yID("email")\n    TextInput("Password", text: $pw, isSecure: true).a11yID("pw")\n    Checkbox("Accept terms", isChecked: $agree)\n    PrimaryButton("Create account", block: true) { submit() }.disabled(!agree)\n  }\n}`,
  list: `ScrollView {\n  VStack(spacing: Theme.SpacingKey.sm.value) {\n    ForEach(items) { item in Card { ListRow(title: item.title, subtitle: item.subtitle) } }\n  }.padding(Theme.SpacingKey.md.value)\n}.background(theme.background(.bgElevatorPrimary))`,
  detail: `ScrollView {\n  VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {\n    Title("Detail")\n    HStack { Badge("Info").badgeStyle(.info); Rating(value: 4.5) }\n    PrimaryButton("Continue", block: true) {}\n  }.padding(Theme.SpacingKey.lg.value)\n}`,
  settings: `ScrollView {\n  VStack(spacing: Theme.SpacingKey.md.value) {\n    Card(title: "Preferences") { ToggleGroup { ThemeToggle(isOn: $notify) } }\n    Card(title: "Theme") { ThemePicker(selection: $active) }\n  }.padding(Theme.SpacingKey.md.value)\n}`,
};
server.registerTool("scaffold_screen", {
  title: "Scaffold a screen", description: "A starter SwiftUI screen built from ThemeKit components.",
  inputSchema: { kind: z.enum(["form", "list", "detail", "settings"]) },
}, async ({ kind }) => text("```swift\n" + SCAFFOLDS[kind] + "\n```"));

server.registerTool("compose_screen", {
  title: "Compose a screen from components",
  description: "Builds a token-bound SwiftUI screen from an ordered list of ThemeKit component names. Each name is verified against the real catalog (unknown ones are flagged, never silently dropped) and rendered from its synthesized usage snippet, wrapped in a token-spaced layout. Use this instead of scaffold_screen when you know exactly which components you want.",
  inputSchema: {
    components: z.array(z.string()).min(1).describe('Ordered component names, e.g. ["Title","TextInput","PrimaryButton"]'),
    title: z.string().optional().describe("Optional screen title rendered as a Title atom"),
    layout: z.enum(["vstack", "scroll", "card"]).optional().describe("vstack (default) / scroll / card-wrapped"),
    spacing: z.enum(["sm", "md", "lg"]).optional().describe("Theme.SpacingKey between items (default md)"),
  },
}, async ({ components, title, layout, spacing }) => {
  const sp = spacing ?? "md";
  const indent = "    ";
  const body: string[] = [];
  const unknown: string[] = [];
  if (title) body.push(`Title("${title.replace(/"/g, "'")}")`);
  for (const name of components) {
    const c = find(name);
    if (!c) { unknown.push(name); body.push(`// ⚠️ unknown component "${name}" — not in the ThemeKit catalog`); continue; }
    body.push(c.usage);
  }
  const inner = body.map((l) => indent + indent + l).join("\n");
  const stack = `${indent}VStack(alignment: .leading, spacing: Theme.SpacingKey.${sp}.value) {\n${inner}\n${indent}}`;
  let composed: string;
  if (layout === "scroll") composed = `ScrollView {\n${stack}\n${indent}.padding(Theme.SpacingKey.${sp}.value)\n}\n.background(theme.background(.bgElevatorPrimary))`;
  else if (layout === "card") composed = `Card {\n${stack}\n}`;
  else composed = stack.replace(/^ {4}/, "").replace(/\n {4}/g, "\n");
  const note = unknown.length ? `\n\n⚠️ Unknown components (verify with search_components / list_components): ${unknown.join(", ")}` : "";
  return text("```swift\n" + composed + "\n```" + "\n\nEvery color resolves from the theme; verify any init you customized with get_component_api, then validate_code." + note);
});

server.registerTool("migrate_snippet", {
  title: "Migrate SwiftUI → ThemeKit", description: "Rewrite plain SwiftUI toward ThemeKit (tokens + components) using the config-driven rule set in migrate-rules.json, with notes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  let out = swift; const notes: string[] = [];
  for (const rule of MIGRATE_RULES) {
    const re = new RegExp(rule.find, rule.flags ?? "g");
    if (re.test(out)) { out = out.replace(new RegExp(rule.find, rule.flags ?? "g"), rule.replace); notes.push(rule.note); }
  }
  return text(`Suggested:\n\n\`\`\`swift\n${out}\n\`\`\`\n\nNotes:\n${notes.length ? notes.map((n) => `- ${n}`).join("\n") : "- (none automatic; run validate_code)"}\n\nReplace plain Button/TextField with PrimaryButton/TextInput; check param names with get_component_api.`);
});

// ── Figma → SwiftUI (the star) ─────────────────────────────────────────────

const designToCodeConfig = {
  title: "Figma → SwiftUI (ThemeKit)",
  description: "Fetches a Figma node (REST) and generates ThemeKit SwiftUI: snaps colors/spacing/radius to design tokens, maps nodes to components (figma-mapping.json rules, then heuristics), emits code with VERIFIED parameter names, and returns a mapping report (matched / unmapped / token snaps / needs-review) plus a WCAG accessibility audit of the design. Pass a Figma `url` directly (recommended), or an explicit `fileKey` + `nodeId`. Set dryRun for the plan only, or a11yOnly to return just the accessibility audit. Needs FIGMA_TOKEN in the env.",
  inputSchema: {
    url: z.string().optional().describe("Figma file/design URL (e.g. https://www.figma.com/design/<key>/App?node-id=25795-9030). Parsed into fileKey + nodeId; overrides them if both are also given."),
    fileKey: z.string().optional().describe("Figma file key (from the file URL). Optional if `url` is given."),
    nodeId: z.string().optional().describe("Node id, e.g. 1:23 (from 'Copy link to selection'). Optional if `url` is given."),
    dryRun: z.boolean().optional().describe("Return only the mapping plan + report, no code"),
    a11yOnly: z.boolean().optional().describe("Return only the WCAG accessibility audit of the Figma design (no code, no mapping)"),
    expandInstances: z.boolean().optional().describe("Walk into unmapped Figma component INSTANCEs (forms, headers, nav bars) instead of emitting an opaque leaf. Use for screens built from nested instances; default false."),
  },
};

const runDesignToCode = async ({ url, fileKey, nodeId, dryRun, a11yOnly, expandInstances }: {
  url?: string; fileKey?: string; nodeId?: string; dryRun?: boolean; a11yOnly?: boolean; expandInstances?: boolean;
}) => {
  const token = process.env.FIGMA_TOKEN;
  if (!token) return text("FIGMA_TOKEN is not set. Add it to the MCP server's env (see the README) and retry.");
  if (url) {
    try { ({ fileKey, nodeId } = parseFigmaUrl(url)); }
    catch (e) { return text(`Could not parse the Figma URL: ${(e as Error).message}`); }
  }
  if (!fileKey || !nodeId) return text("Provide a Figma `url`, or both `fileKey` and `nodeId`.");
  let node;
  try { node = await fetchFigmaNode(fileKey, nodeId, token); }
  catch (e) { return text(`Figma fetch failed: ${(e as Error).message}`); }
  if (a11yOnly) {
    const findings = auditA11y(node);
    return text(`# Accessibility audit — Figma design (WCAG 2.1)\n\n${formatA11y(findings)}\n\nThis audits the design's real colors, font sizes and dimensions before any code is generated.`);
  }
  const mapping = loadMapping(join(here, "..", "figma-mapping.json"));
  const apis = new Map<string, ComponentAPI>(data.components.map((c) => [c.name, { name: c.name, params: c.params }]));
  const { code, report } = generate(node, mapping, data.tokens, apis, { expandInstances });
  // Icons/images the design uses → temporary PNG export URLs (the images API renders them).
  let assetSection = "";
  if (report.assets.length) {
    try {
      const urls = await fetchFigmaImages(fileKey, report.assets.map((a) => a.nodeId), token);
      const rows = report.assets.map((a) => `- ${a.name} → Image("${a.slug}"): ${urls[a.nodeId] ?? "(no render)"}`);
      assetSection = `\n\n## Asset export URLs (PNG @2x — expire after ~14 days)\n${rows.join("\n")}`;
    } catch (e) {
      assetSection = `\n\n## Assets\nCould not fetch export URLs: ${(e as Error).message}`;
    }
  }
  if (dryRun) return text(`# Dry run — mapping plan (no code generated)\n\n${formatReport(report)}${assetSection}`);
  const verdict = lintVerdict(code);
  return text(`\`\`\`swift\n${code}\n\`\`\`\n\n---\n${formatReport(report)}${assetSection}\n\n## Auto-validation (validate_code)\n${verdict}\n\nReview the ⚠️ items and verify any param with get_component_api.`);
};

// Primary, readable name; `figma_to_swiftui` is kept as a backward-compatible alias
// so existing prompts and automations keep working.
server.registerTool("design_to_code",
  { ...designToCodeConfig, title: "Design → Code (Figma → ThemeKit SwiftUI)" },
  runDesignToCode);
server.registerTool("figma_to_swiftui",
  { ...designToCodeConfig, title: "Figma → SwiftUI (ThemeKit) — alias of design_to_code" },
  runDesignToCode);

// ── Code → Figma: design tokens as a Figma Variables library ────────────────
// The reverse of design_to_code. Round-trip-ready: reversible token↔variable
// names + codeSyntax carry the ThemeKit token, so a future Figma → tokens
// import can read the design back into a theme.json.
server.registerTool("export_figma_variables", {
  title: "Export design tokens as Figma Variables",
  description:
    "Turns ThemeKit's design tokens + the 32 theme presets into a Figma Variables library: a **Brand** collection with one MODE per preset (primary/secondary/accent/base — flip themes like the app does), plus **Color** (every resolved color token), **Radius** (scale + box/field/selector roles), **Spacing**, and **Typography** (size/lineHeight/weight) collections. Returns a tool-agnostic model by default, or `format: \"figma-rest\"` for the exact body to POST to the Figma Variables REST API (`/v1/files/:key/variables`). Every variable carries its ThemeKit token in `codeSyntax` so design and code stay in sync (and a future Figma→tokens import can round-trip). Filter with `collections`.",
  inputSchema: {
    format: z.enum(["model", "figma-rest"]).optional().describe("model (default, tool-agnostic) or figma-rest (Figma bulk-write POST body)"),
    collections: z.array(z.string()).optional().describe('Only these collections, e.g. ["Brand","Color"] (default: all five)'),
  },
}, async ({ format, collections }) => {
  let model = buildVariables(data.tokens, data.themes);
  if (collections?.length) {
    const want = new Set(collections.map((c) => c.toLowerCase()));
    model = { ...model, collections: model.collections.filter((c) => want.has(c.name.toLowerCase())) };
    if (!model.collections.length) return text(`No collection matched ${JSON.stringify(collections)}. Available: Brand, Color, Radius, Spacing, Typography.`);
  }
  const payload = format === "figma-rest" ? toFigmaRestPayload(model) : model;
  const summary =
    `Figma Variables — ${model.collections.length} collection(s), ${model.meta.variableCount} variables, ${model.meta.presetModes} preset modes.\n` +
    model.collections.map((c) => `- ${c.name}: ${c.variables.length} vars, ${c.modes.length} mode(s)`).join("\n") +
    (model.skipped.length ? `\nSkipped: ${model.skipped.join("; ")}` : "") +
    (format === "figma-rest" ? `\n\nPOST this to https://api.figma.com/v1/files/<FILE_KEY>/variables (header X-Figma-Token).` : "");
  return text(`${summary}\n\n\`\`\`json\n${JSON.stringify(payload, null, 2)}\n\`\`\``);
});

// ── Resources & prompts ────────────────────────────────────────────────────

server.registerResource("guide", "themekit://guide",
  { title: "ThemeKit guide", description: "Summary + golden rules", mimeType: "text/markdown" },
  async (uri) => ({ contents: [{ uri: uri.href, text: [data.summary, "", ...data.rules.map((r) => `- ${r}`)].join("\n") }] }));
server.registerResource("components", "themekit://components",
  { title: "ThemeKit components", description: "All components by category", mimeType: "text/markdown" },
  async (uri) => ({ contents: [{ uri: uri.href, text: data.components.map((c) => `- ${c.name} (${c.category}) — ${c.init}`).join("\n") }] }));
server.registerResource("component", new ResourceTemplate("themekit://component/{name}", { list: undefined }),
  { title: "ThemeKit component", description: "One component's API" },
  async (uri, { name }) => {
    const c = find(String(name));
    const body = c ? [`# ${c.name}`, c.doc, `Init: ${c.init}`, ...c.modifiers.map((m) => `.${m.signature.replace(/^\./, "")} — ${m.doc}`)].join("\n") : `Unknown: ${name}`;
    return { contents: [{ uri: uri.href, text: body }] };
  });

server.registerPrompt("themekit-screen",
  { title: "Build a ThemeKit screen", description: "Generate a screen with ThemeKit", argsSchema: { description: z.string() } },
  ({ description }) => ({ messages: [{ role: "user", content: { type: "text", text:
    `Build a SwiftUI screen with ThemeKit for: ${description}\n\nUse ThemeKit components + modifiers, resolve every color from theme tokens (never hardcode), inject \`.environment(Theme.shared)\`. Call get_component_api for any API you're unsure of, then validate_code on the result.` } }] }));
server.registerPrompt("migrate-to-themekit",
  { title: "Migrate to ThemeKit", description: "Rewrite plain SwiftUI with ThemeKit", argsSchema: { code: z.string() } },
  ({ code }) => ({ messages: [{ role: "user", content: { type: "text", text:
    `Migrate this SwiftUI to ThemeKit (tokens, ThemeKit components). Run migrate_snippet then validate_code.\n\n\`\`\`swift\n${code}\n\`\`\`` } }] }));

await server.connect(new StdioServerTransport());
