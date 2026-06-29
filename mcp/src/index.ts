#!/usr/bin/env node
/**
 * ThemeKit MCP server — exposes the ThemeKit SwiftUI design system (components,
 * modifiers, tokens, daisyUI themes) as on-demand tools for MCP-compatible
 * editors (Claude Code, Cursor, Windsurf…).
 *
 * Data comes from themekit.json, generated from the Swift source by
 * `tools/gen_skill.py` (`make skill`), so it never drifts from the library.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

interface Component {
  name: string;
  category: string;
  init: string;
  modifiers: string[];
}
interface ThemeKitData {
  summary: string;
  rules: string[];
  tokens: Record<string, string[]>;
  components: Component[];
  modifiers: string[];
  themes: { id: string; name: string }[];
}

const here = dirname(fileURLToPath(import.meta.url));
const data: ThemeKitData = JSON.parse(readFileSync(join(here, "..", "themekit.json"), "utf8"));

const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });

const server = new McpServer({ name: "themekit", version: "1.0.0" });

server.registerTool(
  "usage_guide",
  {
    title: "ThemeKit usage guide",
    description: "The golden rules for writing correct ThemeKit code. Read this first.",
    inputSchema: {},
  },
  async () => text([data.summary, "", "Rules:", ...data.rules.map((r) => `- ${r}`)].join("\n"))
);

server.registerTool(
  "list_components",
  {
    title: "List components",
    description: "List ThemeKit components, optionally filtered by category (Atoms / Molecules / Organisms).",
    inputSchema: { category: z.enum(["Atoms", "Molecules", "Organisms"]).optional() },
  },
  async ({ category }) => {
    const items = data.components.filter((c) => !category || c.category === category);
    const byCat: Record<string, string[]> = {};
    for (const c of items) (byCat[c.category] ??= []).push(c.name);
    return text(
      Object.entries(byCat)
        .map(([cat, names]) => `## ${cat} (${names.length})\n${names.join(", ")}`)
        .join("\n\n")
    );
  }
);

server.registerTool(
  "get_component",
  {
    title: "Get component API",
    description: "Get one component's init signature + its chainable modifiers.",
    inputSchema: { name: z.string().describe("Component name, e.g. Badge, TextInput, Carousel") },
  },
  async ({ name }) => {
    const c = data.components.find((x) => x.name.toLowerCase() === name.toLowerCase());
    if (!c) return text(`No component named "${name}". Try list_components or search_components.`);
    const mods = c.modifiers.length ? `\nModifiers: ${c.modifiers.join(" ")}` : "";
    return text(`${c.category} · ${c.init}${mods}\n\nSet styling/variants/flags with the modifiers; sizes use .controlSize(_:), disabled uses .disabled(_:).`);
  }
);

server.registerTool(
  "search_components",
  {
    title: "Search components",
    description: "Find components by a keyword in the name or init (e.g. 'date', 'select', 'progress').",
    inputSchema: { query: z.string() },
  },
  async ({ query }) => {
    const q = query.toLowerCase();
    const hits = data.components.filter(
      (c) => c.name.toLowerCase().includes(q) || c.init.toLowerCase().includes(q)
    );
    if (!hits.length) return text(`No matches for "${query}".`);
    return text(hits.map((c) => `- ${c.name} (${c.category}) — ${c.init}`).join("\n"));
  }
);

server.registerTool(
  "list_themes",
  {
    title: "List daisyUI themes",
    description: "List the bundled daisyUI theme ids.",
    inputSchema: {},
  },
  async () => text(data.themes.map((t) => `${t.id} (${t.name})`).join("\n"))
);

server.registerTool(
  "theme_snippet",
  {
    title: "Theme apply snippet",
    description: "Swift code to apply a daisyUI theme (or show the ThemePicker).",
    inputSchema: { id: z.string().describe('Theme id, e.g. "dracula"').optional() },
  },
  async ({ id }) => {
    const found = id ? data.themes.find((t) => t.id === id) : undefined;
    if (id && !found) return text(`No theme "${id}". Use list_themes.`);
    const tid = found?.id ?? "dracula";
    return text(
      [
        `// Apply ${found?.name ?? "a"} theme live`,
        `DaisyTheme.named("${tid}")?.apply()`,
        ``,
        `// Or a tappable grid of all themes:`,
        `@State private var active: String? = "${tid}"`,
        `ThemePicker(selection: $active)`,
      ].join("\n")
    );
  }
);

server.registerTool(
  "token_reference",
  {
    title: "Token reference",
    description: "List ThemeKit design tokens (colors, radius roles, spacing, semantic colors). Pass a kind to filter.",
    inputSchema: { kind: z.string().optional().describe("e.g. text, background, semanticColor, radiusRole, spacing") },
  },
  async ({ kind }) => {
    const entries = Object.entries(data.tokens).filter(([k]) => !kind || k.toLowerCase() === kind.toLowerCase());
    if (!entries.length) return text(`No token kind "${kind}". Kinds: ${Object.keys(data.tokens).join(", ")}`);
    return text(entries.map(([k, v]) => `${k}: ${v.join(", ")}`).join("\n"));
  }
);

await server.connect(new StdioServerTransport());
