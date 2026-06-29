#!/usr/bin/env node
/**
 * ThemeKit MCP server — exposes the ThemeKit SwiftUI design system (components,
 * modifiers, tokens, theme presets) as on-demand tools, resources and prompts
 * for MCP-compatible editors (Claude Code, Cursor, Windsurf…).
 *
 * Data comes from themekit.json, generated from the Swift source by
 * `tools/gen_skill.py` (`make skill`), so it never drifts from the library.
 */
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

interface Modifier { name: string; signature: string; doc: string; }
interface Component { name: string; category: string; doc: string; init: string; modifiers: Modifier[]; }
interface ThemePreset { id: string; name: string; primary: string; secondary: string; accent: string; base: string; }
interface Data {
  summary: string; rules: string[]; tokens: Record<string, string[]>;
  components: Component[]; modifiers: string[]; themes: ThemePreset[];
}

const here = dirname(fileURLToPath(import.meta.url));
const data: Data = JSON.parse(readFileSync(join(here, "..", "themekit.json"), "utf8"));
const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });
const findComponent = (name: string) =>
  data.components.find((c) => c.name.toLowerCase() === name.toLowerCase());

const server = new McpServer({ name: "themekit", version: "1.0.0" });

// ── Reference tools ────────────────────────────────────────────────────────

server.registerTool("usage_guide", {
  title: "ThemeKit usage guide",
  description: "The golden rules for writing correct ThemeKit code. Read this first.",
  inputSchema: {},
}, async () => text([data.summary, "", "Rules:", ...data.rules.map((r) => `- ${r}`)].join("\n")));

server.registerTool("list_components", {
  title: "List components",
  description: "List ThemeKit components, optionally filtered by category.",
  inputSchema: { category: z.enum(["Atoms", "Molecules", "Organisms"]).optional() },
}, async ({ category }) => {
  const items = data.components.filter((c) => !category || c.category === category);
  const byCat: Record<string, string[]> = {};
  for (const c of items) (byCat[c.category] ??= []).push(c.name);
  return text(Object.entries(byCat).map(([c, n]) => `## ${c} (${n.length})\n${n.join(", ")}`).join("\n\n"));
});

server.registerTool("get_component", {
  title: "Get component API",
  description: "A component's summary, init signature and chainable modifiers (with signatures + docs).",
  inputSchema: { name: z.string().describe("Component name, e.g. Badge, TextInput, Carousel") },
}, async ({ name }) => {
  const c = findComponent(name);
  if (!c) return text(`No component "${name}". Try list_components or search_components.`);
  const out = [`# ${c.name} (${c.category})`, c.doc, "", `**Init:** \`${c.init}\``];
  if (c.modifiers.length) {
    out.push("", "**Modifiers:**");
    for (const m of c.modifiers) out.push(`- \`.${m.signature}\`${m.doc ? ` — ${m.doc}` : ""}`);
  }
  out.push("", "Sizes use `.controlSize(_:)`; disabled uses `.disabled(_:)`; never hardcode a color.");
  return text(out.join("\n"));
});

server.registerTool("search_components", {
  title: "Search components",
  description: "Find components by a keyword in the name, init or summary (e.g. 'date', 'progress').",
  inputSchema: { query: z.string() },
}, async ({ query }) => {
  const q = query.toLowerCase();
  const hits = data.components.filter(
    (c) => c.name.toLowerCase().includes(q) || c.init.toLowerCase().includes(q) || c.doc.toLowerCase().includes(q)
  );
  if (!hits.length) return text(`No matches for "${query}".`);
  return text(hits.map((c) => `- ${c.name} (${c.category}) — ${c.init}`).join("\n"));
});

server.registerTool("token_reference", {
  title: "Token reference",
  description: "ThemeKit design tokens (colors, radius roles, spacing, semantic colors). Pass a kind to filter.",
  inputSchema: { kind: z.string().optional().describe("e.g. text, background, semanticColor, radiusRole, spacing") },
}, async ({ kind }) => {
  const entries = Object.entries(data.tokens).filter(([k]) => !kind || k.toLowerCase() === kind.toLowerCase());
  if (!entries.length) return text(`No token kind "${kind}". Kinds: ${Object.keys(data.tokens).join(", ")}`);
  return text(entries.map(([k, v]) => `${k}: ${v.join(", ")}`).join("\n"));
});

// ── Theme tools ────────────────────────────────────────────────────────────

server.registerTool("list_themes", {
  title: "List theme presets",
  description: "List the bundled theme-preset ids.",
  inputSchema: {},
}, async () => text(data.themes.map((t) => `${t.id} (${t.name})`).join("\n")));

server.registerTool("theme_colors", {
  title: "Theme preset colors",
  description: "The primary / secondary / accent / base hexes of a theme preset.",
  inputSchema: { id: z.string().describe('Preset id, e.g. "dracula"') },
}, async ({ id }) => {
  const t = data.themes.find((x) => x.id === id);
  if (!t) return text(`No preset "${id}". Use list_themes.`);
  return text(`${t.name}\nprimary #${t.primary}\nsecondary #${t.secondary}\naccent #${t.accent}\nbase #${t.base}`);
});

server.registerTool("generate_theme", {
  title: "Generate a theme",
  description: "Swift code applying a custom theme from an accent (+ optional base / secondary / accent / dark).",
  inputSchema: {
    primaryHex: z.string().describe("RRGGBB, no #"),
    baseHex: z.string().optional(), secondaryHex: z.string().optional(),
    accentHex: z.string().optional(), dark: z.boolean().optional(),
  },
}, async ({ primaryHex, baseHex, secondaryHex, accentHex, dark }) => {
  const args = [`primaryHex: "${primaryHex}"`];
  if (baseHex) args.push(`baseHex: "${baseHex}"`);
  if (secondaryHex) args.push(`secondaryHex: "${secondaryHex}"`);
  if (accentHex) args.push(`accentHex: "${accentHex}"`);
  if (dark) args.push(`dark: true`);
  return text(`Theme.shared.apply(ThemeConfig(${args.join(", ")}))\n\n// Every component recolors from these tokens — don't restyle them by hand.`);
});

server.registerTool("theme_snippet", {
  title: "Theme apply snippet",
  description: "Swift code to apply a theme preset live, or show the theme picker.",
  inputSchema: { id: z.string().optional().describe('Preset id, e.g. "dracula"') },
}, async ({ id }) => {
  const found = id ? data.themes.find((t) => t.id === id) : undefined;
  if (id && !found) return text(`No preset "${id}". Use list_themes.`);
  const tid = found?.id ?? data.themes[0].id;
  return text([
    `DaisyTheme.named("${tid}")?.apply()          // recolor live`,
    ``,
    `@State private var active: String? = "${tid}"`,
    `ThemePicker(selection: $active)              // a grid of all presets`,
  ].join("\n"));
});

// ── Actionable tools ───────────────────────────────────────────────────────

const LINT_RULES: { re: RegExp; msg: string }[] = [
  { re: /Color\((?:hex:|red:|\.s)/, msg: "Hardcoded color — use a theme token (theme.text/.background/.foreground) or a SemanticColor." },
  { re: /\.(?:foregroundStyle|foregroundColor|fill|background|tint)\(\s*\.(?:blue|red|green|orange|yellow|purple|pink|gray|grey|black|white|indigo|teal|mint|cyan|brown)\b/,
    msg: "Hardcoded system color — use a theme token / SemanticColor." },
  { re: /\bisEnabled:\s*/, msg: "`isEnabled:` is not an init arg — use the native `.disabled(_:)` modifier." },
  { re: /\.cornerRadius\(\s*\d/, msg: "Hardcoded corner radius — use Theme.RadiusRole.box/field/selector.value." },
  { re: /cornerRadius:\s*\d/, msg: "Hardcoded corner radius literal — use a RadiusRole/RadiusKey token." },
  { re: /\.font\(\.system\(/, msg: "Raw system font — use `.textStyle(.bodyBase400 | .headingSm | …)`." },
  { re: /\.padding\(\s*\d/, msg: "Hardcoded padding — use Theme.SpacingKey.sm/md/lg.value." },
];

server.registerTool("lint_snippet", {
  title: "Lint ThemeKit code",
  description: "Scan a SwiftUI snippet for ThemeKit anti-patterns (hardcoded colors / radius / fonts, isEnabled: arg) and report fixes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  const lines = swift.split("\n");
  const findings: string[] = [];
  lines.forEach((line, i) => {
    for (const rule of LINT_RULES) {
      if (rule.re.test(line)) findings.push(`L${i + 1}: ${rule.msg}\n    ${line.trim()}`);
    }
  });
  return text(findings.length ? `${findings.length} issue(s):\n\n${findings.join("\n\n")}` : "✓ No ThemeKit anti-patterns found.");
});

const SCAFFOLDS: Record<string, string> = {
  form: `@Environment(\\.theme) private var theme
@State private var email = ""; @State private var pw = ""; @State private var agree = false
var body: some View {
    Card(title: "Sign up") {
        VStack(spacing: Theme.SpacingKey.md.value) {
            TextInput("Email", text: $email, leadingSystemImage: "envelope").a11yID("email")
            TextInput("Password", text: $pw, isSecure: true).a11yID("pw")
            Checkbox("Accept terms", isChecked: $agree)
            PrimaryButton("Create account", block: true) { submit() }.disabled(!agree)
        }
    }
}`,
  list: `@Environment(\\.theme) private var theme
var body: some View {
    ScrollView {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(items) { item in
                Card { ListRow(title: item.title, subtitle: item.subtitle) }
            }
        }
        .padding(Theme.SpacingKey.md.value)
    }
    .background(theme.background(.bgElevatorPrimary))
}`,
  detail: `@Environment(\\.theme) private var theme
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            Title("Detail")
            HStack { Badge("Info", style: .info); Rating(value: 4.5) }
            Text(body).textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
            PrimaryButton("Continue", block: true) {}
        }
        .padding(Theme.SpacingKey.lg.value)
    }
}`,
  settings: `@Environment(\\.theme) private var theme
@State private var notify = true; @State private var active: String? = "light"
var body: some View {
    ScrollView {
        VStack(spacing: Theme.SpacingKey.md.value) {
            Card(title: "Preferences") {
                ToggleGroup { ThemeToggle(isOn: $notify) }
            }
            Card(title: "Theme") { ThemePicker(selection: $active) }
        }.padding(Theme.SpacingKey.md.value)
    }
}`,
};

server.registerTool("scaffold_screen", {
  title: "Scaffold a screen",
  description: "A starter SwiftUI screen built from ThemeKit components.",
  inputSchema: { kind: z.enum(["form", "list", "detail", "settings"]) },
}, async ({ kind }) => text("```swift\n" + SCAFFOLDS[kind] + "\n```"));

server.registerTool("migrate_snippet", {
  title: "Migrate SwiftUI → ThemeKit",
  description: "Rewrite a plain-SwiftUI snippet toward ThemeKit (tokens + components), with notes.",
  inputSchema: { swift: z.string() },
}, async ({ swift }) => {
  let out = swift;
  const notes: string[] = [];
  const sub = (re: RegExp, to: string, note: string) => {
    if (re.test(out)) { out = out.replace(re, to); notes.push(note); }
  };
  sub(/\.foregroundColor\(\.(?:blue|accentColor)\)/g, ".foregroundStyle(theme.text(.textHero))", "system accent → theme.text(.textHero)");
  sub(/Color\.blue/g, "theme.foreground(.fgHero)", "Color.blue → theme.foreground(.fgHero)");
  sub(/\.cornerRadius\(\s*\d+\s*\)/g, ".cornerRadius(Theme.RadiusRole.box.value)", "hardcoded radius → RadiusRole.box");
  sub(/\bToggle\(("[^"]*",\s*)?isOn:\s*(\$\w+)\)/g, "ThemeToggle(isOn: $2)", "Toggle → ThemeToggle");
  return text(`Suggested:\n\n\`\`\`swift\n${out}\n\`\`\`\n\nNotes:\n${notes.length ? notes.map((n) => `- ${n}`).join("\n") : "- (no automatic rewrites; check lint_snippet)"}\n\nReplace plain Button/TextField with PrimaryButton/TextInput, and any remaining hardcoded colors with theme tokens.`);
});

// ── Resources (attachable context) ─────────────────────────────────────────

server.registerResource("guide", "themekit://guide",
  { title: "ThemeKit guide", description: "Summary + golden rules", mimeType: "text/markdown" },
  async (uri) => ({ contents: [{ uri: uri.href, text: [data.summary, "", ...data.rules.map((r) => `- ${r}`)].join("\n") }] }));

server.registerResource("components", "themekit://components",
  { title: "ThemeKit components", description: "All components by category", mimeType: "text/markdown" },
  async (uri) => ({ contents: [{ uri: uri.href, text: data.components.map((c) => `- ${c.name} (${c.category}) — ${c.init}`).join("\n") }] }));

server.registerResource("component", new ResourceTemplate("themekit://component/{name}", { list: undefined }),
  { title: "ThemeKit component", description: "One component's API" },
  async (uri, { name }) => {
    const c = findComponent(String(name));
    const body = c ? [`# ${c.name}`, c.doc, `Init: ${c.init}`, ...c.modifiers.map((m) => `.${m.signature} — ${m.doc}`)].join("\n") : `Unknown: ${name}`;
    return { contents: [{ uri: uri.href, text: body }] };
  });

// ── Prompts (slash-command templates) ──────────────────────────────────────

server.registerPrompt("themekit-screen",
  { title: "Build a ThemeKit screen", description: "Generate a screen with ThemeKit components",
    argsSchema: { description: z.string().describe("What the screen should do") } },
  ({ description }) => ({ messages: [{ role: "user", content: { type: "text", text:
    `Build a SwiftUI screen with ThemeKit for: ${description}\n\nUse ThemeKit components + modifiers, resolve every color from theme tokens (never hardcode), inject \`.environment(Theme.shared)\`. Call get_component for any API you're unsure of, and lint_snippet on the result.` } }] }));

server.registerPrompt("themekit-theme",
  { title: "Theme a ThemeKit app", description: "Apply or generate a theme",
    argsSchema: { idOrColor: z.string().describe("A preset id (e.g. dracula) or an accent hex") } },
  ({ idOrColor }) => ({ messages: [{ role: "user", content: { type: "text", text:
    `Apply a ThemeKit theme: "${idOrColor}". If it's a preset id use DaisyTheme.named(...)?.apply(); if it's a hex use Theme.shared.applyGenerated(primaryHex:). Confirm with theme_colors / list_themes.` } }] }));

server.registerPrompt("migrate-to-themekit",
  { title: "Migrate to ThemeKit", description: "Rewrite plain SwiftUI with ThemeKit",
    argsSchema: { code: z.string().describe("The SwiftUI code to migrate") } },
  ({ code }) => ({ messages: [{ role: "user", content: { type: "text", text:
    `Migrate this SwiftUI to ThemeKit — tokens instead of hardcoded colors, ThemeKit components instead of raw ones. Run migrate_snippet then lint_snippet.\n\n\`\`\`swift\n${code}\n\`\`\`` } }] }));

await server.connect(new StdioServerTransport());
