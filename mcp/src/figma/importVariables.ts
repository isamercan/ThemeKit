/**
 * Figma Variables → ThemeKit theme (the reverse of variables.ts / export).
 *
 * Reads a Figma Variables JSON and resolves the four brand seeds
 * (primary / secondary / accent / base) for a chosen mode, then emits a
 * `ThemeConfig(...)` + a matching `theme.json` — ThemeKit derives the whole
 * palette from those seeds, so a company's Figma file re-skins every component.
 *
 * Accepts two shapes:
 *  - **Figma REST** `GET /v1/files/:key/variables/local` (`meta.variables` +
 *    `meta.variableCollections`), incl. `VARIABLE_ALIAS` indirection — a real
 *    file pulled from any company.
 *  - **Our export model** (from `export_figma_variables`, values keyed by mode
 *    name) — a lossless round-trip, because every variable carries its ThemeKit
 *    token in `codeSyntax`.
 *
 * Seed resolution, most trusted first: (1) `codeSyntax` naming a `brand.<role>`
 * token, (2) a caller-supplied alias, (3) a name heuristic. Anything unresolved
 * is reported, never guessed.
 */
import { figmaColorToHex, relativeLuminance } from "./tokenMatch.js";

export type Role = "primary" | "secondary" | "accent" | "base";
const ROLES: Role[] = ["primary", "secondary", "accent", "base"];

type FigmaColorVal = { r: number; g: number; b: number; a?: number };
type FigmaAlias = { type: "VARIABLE_ALIAS"; id: string };
type FigmaValue = FigmaColorVal | number | string | FigmaAlias;

interface RestVar {
  id: string; name: string; resolvedType: "COLOR" | "FLOAT" | "STRING";
  valuesByMode: Record<string, FigmaValue>;
  variableCollectionId: string;
  codeSyntax?: { iOS?: string; WEB?: string; ANDROID?: string };
}
interface RestCollection { id: string; name: string; modes: { modeId: string; name: string }[]; defaultModeId: string; }

/** Our own export model (subset we read back). */
interface ModelVar { name: string; type: string; token?: string; values: Record<string, FigmaValue>; }
interface ModelCollection { name: string; modes: string[]; variables: ModelVar[]; }

export interface ImportInput {
  meta?: { variables?: Record<string, RestVar>; variableCollections?: Record<string, RestCollection> };
  variables?: Record<string, RestVar>;
  variableCollections?: Record<string, RestCollection>;
  collections?: ModelCollection[];
}

/** A variable flattened to a common form; values keyed by mode NAME, aliases resolved. */
interface NormVar { name: string; type: string; token?: string; collection: string; byMode: Record<string, FigmaValue>; }

export interface ImportOptions {
  /** Mode to import (name, case-insensitive). Defaults to the first collection's default mode. */
  mode?: string;
  /** Variable-name → role overrides, e.g. { "Brand/500": "primary" }. */
  aliases?: Record<string, string>;
  /** Force dark; otherwise inferred from the mode name or the base color's luminance. */
  dark?: boolean;
}

export interface SeedResolution { role: Role; hex: string; source: "codeSyntax" | "alias" | "name"; via: string; }
export interface ImportResult {
  mode: string;
  modes: string[];
  seeds: Partial<Record<Role, SeedResolution>>;
  unresolved: Role[];
  lossless: boolean;             // every found seed came via codeSyntax
  themeConfigSwift: string;
  themeJson: Record<string, string | boolean>;
  notes: string[];
}

const clean = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
const leaf = (name: string) => clean(name.split("/").pop() ?? name);

/** Name → role heuristic (last, least-trusted). */
function roleFromName(name: string): Role | null {
  const l = leaf(name);
  if (l === "brand" || /^primary/.test(l)) return "primary";
  if (/^secondary/.test(l)) return "secondary";
  if (/^accent/.test(l)) return "accent";
  if (/^base/.test(l) || /^surface/.test(l) || /^background/.test(l) || l === "bg" || /^base100/.test(l)) return "base";
  return null;
}
/** codeSyntax token → role (our export writes `brand.<role>`; other tokens can map too). */
function roleFromToken(token?: string): Role | null {
  if (!token) return null;
  const t = token.toLowerCase();
  const m = t.match(/^brand\.(primary|secondary|accent|base)$/);
  if (m) return m[1] as Role;
  if (/(^|\.)base(hex)?$/.test(t) || t.includes("bg-white") || t.includes("background")) return "base";
  return null;
}

/** Normalize either input shape into NormVars + the ordered mode-name list. */
function normalize(input: ImportInput): { vars: NormVar[]; modes: string[] } {
  // Our export model.
  if (Array.isArray(input.collections)) {
    const vars: NormVar[] = [];
    const modeSet = new Set<string>();
    for (const c of input.collections) {
      for (const m of c.modes) modeSet.add(m);
      for (const v of c.variables) vars.push({ name: v.name, type: v.type, token: v.token, collection: c.name, byMode: v.values });
    }
    return { vars, modes: [...modeSet] };
  }
  // Figma REST GET-local shape (meta.* or top-level).
  const rawVars = input.meta?.variables ?? input.variables ?? {};
  const rawCols = input.meta?.variableCollections ?? input.variableCollections ?? {};
  const byId = new Map(Object.values(rawVars).map((v) => [v.id, v]));
  const modeName = new Map<string, string>();       // modeId → name
  const orderedModes: string[] = [];
  for (const col of Object.values(rawCols)) {
    for (const m of col.modes ?? []) {
      modeName.set(m.modeId, m.name);
      if (!orderedModes.includes(m.name)) orderedModes.push(m.name);
    }
  }
  // Resolve a value, following VARIABLE_ALIAS chains. An alias points at a
  // variable that may live in another collection with its own modes, so read the
  // target in the current modeId if present, else its collection's default mode,
  // else its sole value — and thread that effective mode into the next hop.
  const resolve = (val: FigmaValue, modeId: string, depth = 0): FigmaValue | undefined => {
    if (val && typeof val === "object" && "type" in val && val.type === "VARIABLE_ALIAS") {
      if (depth > 6) return undefined;
      const target = byId.get(val.id);
      if (!target) return undefined;
      const vbm = target.valuesByMode ?? {};
      let useMode = modeId;
      if (!(modeId in vbm)) {
        const defId = rawCols[target.variableCollectionId]?.defaultModeId;
        const keys = Object.keys(vbm);
        useMode = (defId && defId in vbm) ? defId : (keys.length === 1 ? keys[0] : "");
      }
      const next = vbm[useMode];
      return next === undefined ? undefined : resolve(next, useMode, depth + 1);
    }
    return val;
  };
  const vars: NormVar[] = [];
  for (const v of Object.values(rawVars)) {
    const col = rawCols[v.variableCollectionId];
    const byMode: Record<string, FigmaValue> = {};
    for (const [modeId, val] of Object.entries(v.valuesByMode ?? {})) {
      const name = modeName.get(modeId);
      const resolved = resolve(val, modeId);
      if (name && resolved !== undefined) byMode[name] = resolved;
    }
    vars.push({ name: v.name, type: v.resolvedType, token: v.codeSyntax?.iOS, collection: col?.name ?? "", byMode });
  }
  return { vars, modes: orderedModes };
}

function valueToHex(val: FigmaValue | undefined): string | null {
  if (val && typeof val === "object" && "r" in val) return figmaColorToHex(val);
  return null;
}

export function importVariables(input: ImportInput, opts: ImportOptions = {}): ImportResult {
  const { vars, modes } = normalize(input);
  const notes: string[] = [];
  if (!modes.length) throw new Error("No variable modes found — is this a Figma variables export?");

  const wanted = opts.mode ? modes.find((m) => m.toLowerCase() === opts.mode!.toLowerCase()) : undefined;
  if (opts.mode && !wanted) notes.push(`Mode "${opts.mode}" not found; using "${modes[0]}". Available: ${modes.join(", ")}.`);
  const mode = wanted ?? modes[0];

  const aliasRole = new Map<string, Role>();
  for (const [name, role] of Object.entries(opts.aliases ?? {})) {
    if ((ROLES as string[]).includes(role)) aliasRole.set(clean(name), role as Role);
  }

  // Resolve each seed with the most trusted candidate available across all COLOR vars.
  const seeds: Partial<Record<Role, SeedResolution>> = {};
  const rank = { codeSyntax: 3, alias: 2, name: 1 } as const;
  for (const v of vars) {
    if (v.type !== "COLOR") continue;
    const hex = valueToHex(v.byMode[mode]);
    if (!hex) continue;
    let role: Role | null = null;
    let source: SeedResolution["source"] | null = null;
    if ((role = roleFromToken(v.token))) source = "codeSyntax";
    else if (aliasRole.has(clean(v.name))) { role = aliasRole.get(clean(v.name))!; source = "alias"; }
    else if ((role = roleFromName(v.name))) source = "name";
    if (!role || !source) continue;
    const prev = seeds[role];
    if (!prev || rank[source] > rank[prev.source]) {
      seeds[role] = { role, hex, source, via: source === "codeSyntax" ? (v.token ?? v.name) : v.name };
    }
  }

  const unresolved = ROLES.filter((r) => !seeds[r]);
  const found = ROLES.filter((r) => seeds[r]);
  const lossless = found.length > 0 && found.every((r) => seeds[r]!.source === "codeSyntax");

  if (!seeds.primary) {
    notes.push("No `primary` seed resolved — ThemeConfig needs at least a primary. Pass `aliases` to map a variable to it, e.g. { \"YourBrand/500\": \"primary\" }.");
  }

  // Dark: explicit → mode name → base luminance.
  let dark = opts.dark;
  if (dark === undefined) {
    if (/dark/i.test(mode)) dark = true;
    else if (seeds.base) dark = relativeLuminance("#" + seeds.base.hex.replace(/^#/, "")) < 0.4;
  }

  // Build ThemeConfig + theme.json from whatever seeds resolved.
  const cfg: Record<string, string | boolean> = {};
  for (const r of ROLES) if (seeds[r]) cfg[`${r}Hex`] = seeds[r]!.hex.replace(/^#/, "").toLowerCase();
  if (dark) cfg.dark = true;
  const args = Object.entries(cfg).map(([k, v]) => (typeof v === "string" ? `${k}: "${v}"` : `${k}: ${v}`)).join(", ");
  const themeConfigSwift = args
    ? `// imported from Figma — mode "${mode}"${lossless ? " (lossless via codeSyntax)" : ""}\nTheme.shared.apply(ThemeConfig(${args}))`
    : `// No seeds resolved from mode "${mode}".`;

  return { mode, modes, seeds, unresolved, lossless, themeConfigSwift, themeJson: cfg, notes };
}

/** Human-readable report for the tool output. */
export function formatImport(r: ImportResult): string {
  const lines = [
    `# Imported Figma mode: ${r.mode}${r.lossless ? "  ✓ lossless (codeSyntax)" : ""}`,
    r.modes.length > 1 ? `Modes in file: ${r.modes.join(", ")}` : "",
    "",
    "## Seeds",
    ...(["primary", "secondary", "accent", "base"] as Role[]).map((role) => {
      const s = r.seeds[role];
      return s ? `- ${role}: #${s.hex.replace(/^#/, "")}  (via ${s.source}: ${s.via})` : `- ${role}: — not resolved`;
    }),
    r.unresolved.length ? `\n⚠️ Unresolved: ${r.unresolved.join(", ")} — pass \`aliases\` to map them.` : "",
    r.notes.length ? `\nNotes:\n${r.notes.map((n) => `- ${n}`).join("\n")}` : "",
    "",
    "## ThemeConfig",
    "```swift",
    r.themeConfigSwift,
    "```",
    "",
    "## theme.json (for ThemeConfig(jsonData:))",
    "```json",
    JSON.stringify(r.themeJson, null, 2),
    "```",
  ];
  return lines.filter((l) => l !== "").join("\n");
}
