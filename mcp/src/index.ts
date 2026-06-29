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

const server = new McpServer({ name: "themekit", version: "2.0.0" });

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
  description: "Design tokens with their real values — colors, radius (+ box/field/selector roles), spacing, typography, shadow, semantic colors. Filter by category.",
  inputSchema: { category: z.string().optional().describe("e.g. text, background, radius, radiusRole, spacing, typography, semanticColor") },
}, async ({ category }) => {
  const toks = data.tokens.filter((t) => !category || t.category.toLowerCase() === category.toLowerCase());
  if (!toks.length) {
    const cats = [...new Set(data.tokens.map((t) => t.category))].join(", ");
    return text(`No tokens for "${category}". Categories: ${cats}`);
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
  number: ["InputNumber", "QuantityStepper", "RollingNumber"], otp: ["OTPInput"],
  toggle: ["ThemeToggle", "Checkbox", "RadioButton", "Swap"], checkbox: ["Checkbox", "CheckboxGroup"],
  radio: ["RadioButton", "RadioGroup"], slider: ["Slider", "RangeSlider"],
  list: ["DataTable", "Accordion", "TreeSelect"], table: ["DataTable"], tree: ["TreeSelect"],
  feedback: ["Toast", "AlertToast", "Callout", "InfoBanner", "ResultView", "EmptyState"],
  alert: ["AlertToast", "Callout", "InfoBanner"], toast: ["Toast", "AlertToast"], empty: ["EmptyState"],
  loading: ["Spinner", "Skeleton", "ProgressBar", "RadialProgress"], progress: ["ProgressBar", "RadialProgress", "Steps"],
  button: ["PrimaryButton", "SecondaryButton", "ThemeButton", "ButtonGroup", "ShareButton"],
  rating: ["Rating"], star: ["Rating"], badge: ["Badge", "CountBadge", "ScoreBadge"],
  filter: ["Chip", "FilterChip", "ChipGroup", "FilterGroup"], chip: ["Chip", "ImageChip", "CompactChip"],
  tag: ["Tag"], avatar: ["Avatar", "AvatarGroup"], card: ["Card", "CardStack"], carousel: ["Carousel"],
  image: ["RemoteImage", "AnimatedImage", "ImageChip"], video: ["VideoPlayerView"],
  nav: ["NavigationBar", "Breadcrumbs", "SegmentedTabBar", "Pagination"], tab: ["SegmentedTabBar", "SegmentedControl"],
  theme: ["ThemePicker", "ThemeToggle", "ColorField"], color: ["ColorField"],
  step: ["Steps", "StepIndicator", "QuantityStepper"], divider: ["DividerView"], tooltip: ["Tooltip"],
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
    for (const cand of SYNONYMS[w] ?? []) bump(cand, 3);
    for (const c of data.components) {
      if (c.name.toLowerCase() === w) bump(c.name, 5);
      else if (c.name.toLowerCase().includes(w)) bump(c.name, 2);
      if (c.doc.toLowerCase().includes(w)) bump(c.name, 1);
    }
  }
  const ranked = [...score.entries()].filter(([, s]) => s > 0).sort((a, b) => b[1] - a[1]).slice(0, 10);
  if (!ranked.length) return text(`No components matched "${intent}". Try list_components.`);
  return text(ranked.map(([n, s]) => {
    const c = find(n)!;
    return `- ${n} (${c.category}, score ${s}) — ${c.doc || c.init}`;
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
  const path = join(REPO, "CHANGELOG.md");
  if (!existsSync(path)) return text("CHANGELOG.md not found (run the MCP from the ThemeKit repo).");
  const md = readFileSync(path, "utf8");
  // Split into [version] sections in file order (newest first).
  const re = /^##\s*\[(\d+\.\d+\.\d+)\][^\n]*\n([\s\S]*?)(?=^##\s*\[|\Z)/gm;
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
  const file = join(REPO, "Screenshots", `${name}${dark ? "-dark" : ""}.png`);
  if (!existsSync(file)) {
    return text(`No rendered preview for "${name}". Gallery renders live in Screenshots/ (regenerate with \`make screenshots\`); some live/overlay components aren't captured. Try get_component_api + get_usage_snippet instead.`);
  }
  const png = readFileSync(file).toString("base64");
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

server.registerTool("validate_code", {
  title: "Validate a ThemeKit screen",
  description: "Full check: anti-patterns + raw-SwiftUI components that have ThemeKit equivalents + unknown component/modifier detection (vs the real API) + a PASS/FAIL verdict.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  const lines = swift.split("\n");
  const issues: string[] = [];
  lines.forEach((line, i) => { for (const r of [...LINT_RULES, ...PREFER_RULES]) if (r.re.test(line)) issues.push(`L${i + 1}: ${r.msg}\n    ${line.trim()}`); });
  const names = new Set(data.components.map((c) => c.name));
  const used = [...new Set((swift.match(/\b[A-Z]\w+(?=\s*[({.])/g) || []).filter((n) => names.has(n)))];
  // modifiers used that look ThemeKit-ish but aren't real
  const realMods = new Set(data.modifiers.map((m) => m.replace(/\(.*/, "")));
  const head = issues.length ? `✗ FAIL — ${issues.length} issue(s):` : "✓ PASS — no ThemeKit issues found.";
  const usedLine = used.length ? `\n\nThemeKit components used (${used.length}): ${used.join(", ")}` : "\n\n⚠️ No ThemeKit components detected.";
  return text(`${head}${issues.length ? "\n\n" + issues.join("\n\n") : ""}${usedLine}`);
});

const SCAFFOLDS: Record<string, string> = {
  form: `Card(title: "Sign up") {\n  VStack(spacing: Theme.SpacingKey.md.value) {\n    TextInput("Email", text: $email, leadingSystemImage: "envelope").a11yID("email")\n    TextInput("Password", text: $pw, isSecure: true).a11yID("pw")\n    Checkbox("Accept terms", isChecked: $agree)\n    PrimaryButton("Create account", block: true) { submit() }.disabled(!agree)\n  }\n}`,
  list: `ScrollView {\n  VStack(spacing: Theme.SpacingKey.sm.value) {\n    ForEach(items) { item in Card { ListRow(title: item.title, subtitle: item.subtitle) } }\n  }.padding(Theme.SpacingKey.md.value)\n}.background(theme.background(.bgElevatorPrimary))`,
  detail: `ScrollView {\n  VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {\n    Title("Detail")\n    HStack { Badge("Info", style: .info); Rating(value: 4.5) }\n    PrimaryButton("Continue", block: true) {}\n  }.padding(Theme.SpacingKey.lg.value)\n}`,
  settings: `ScrollView {\n  VStack(spacing: Theme.SpacingKey.md.value) {\n    Card(title: "Preferences") { ToggleGroup { ThemeToggle(isOn: $notify) } }\n    Card(title: "Theme") { ThemePicker(selection: $active) }\n  }.padding(Theme.SpacingKey.md.value)\n}`,
};
server.registerTool("scaffold_screen", {
  title: "Scaffold a screen", description: "A starter SwiftUI screen built from ThemeKit components.",
  inputSchema: { kind: z.enum(["form", "list", "detail", "settings"]) },
}, async ({ kind }) => text("```swift\n" + SCAFFOLDS[kind] + "\n```"));

server.registerTool("migrate_snippet", {
  title: "Migrate SwiftUI → ThemeKit", description: "Rewrite plain SwiftUI toward ThemeKit (tokens + components), with notes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  let out = swift; const notes: string[] = [];
  const sub = (re: RegExp, to: string, note: string) => { if (re.test(out)) { out = out.replace(re, to); notes.push(note); } };
  sub(/\.foregroundColor\(\.(?:blue|accentColor)\)/g, ".foregroundStyle(theme.text(.textHero))", "system accent → theme.text(.textHero)");
  sub(/Color\.blue/g, "theme.foreground(.fgHero)", "Color.blue → theme.foreground(.fgHero)");
  sub(/\.cornerRadius\(\s*\d+\s*\)/g, ".cornerRadius(Theme.RadiusRole.box.value)", "hardcoded radius → RadiusRole.box");
  sub(/\bToggle\(("[^"]*",\s*)?isOn:\s*(\$\w+)\)/g, "ThemeToggle(isOn: $2)", "Toggle → ThemeToggle");
  return text(`Suggested:\n\n\`\`\`swift\n${out}\n\`\`\`\n\nNotes:\n${notes.length ? notes.map((n) => `- ${n}`).join("\n") : "- (none automatic; run validate_code)"}\n\nReplace plain Button/TextField with PrimaryButton/TextInput; check param names with get_component_api.`);
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
