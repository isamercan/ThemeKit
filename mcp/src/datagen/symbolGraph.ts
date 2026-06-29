/**
 * Parses a DocC symbol graph (`swift package dump-symbol-graph`) into the precise
 * public API of every ThemeKit View component — init parameters (name, type,
 * default) and chainable modifiers (signature). This is the single source of
 * truth for component APIs; nothing here is hand-maintained.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const VIEW_USR = "s:7SwiftUI4ViewP";
const MODULE = "ThemeKit";

export interface Param {
  label: string;          // external arg label ("_" for positional)
  name: string;           // internal name
  type: string;
  default?: string;
}
export interface ComponentInit {
  signature: string;
  params: Param[];
}
export interface Modifier {
  name: string;
  signature: string;      // e.g. ".badgeShape(_ shape: BadgeShape)"
  doc: string;
}
export interface Component {
  name: string;
  doc: string;
  conformances: string[];
  inits: ComponentInit[];
  modifiers: Modifier[];
}

interface RawSymbol {
  kind: { identifier: string };
  identifier: { precise: string };
  names?: { title?: string };
  accessLevel?: string;
  declarationFragments?: { spelling: string }[];
  docComment?: { lines?: { text: string }[] };
}
interface SymbolGraph {
  symbols: RawSymbol[];
  relationships: { kind: string; source: string; target: string }[];
}

/** Ensures the public symbol graph exists, returns its parsed JSON. */
export function loadSymbolGraph(repoRoot: string): SymbolGraph {
  const candidates = [
    join(repoRoot, ".build/arm64-apple-macosx/symbolgraph/ThemeKit.symbols.json"),
    join(repoRoot, ".build/x86_64-apple-macosx/symbolgraph/ThemeKit.symbols.json"),
  ];
  let path = candidates.find(existsSync);
  if (!path) {
    execFileSync(
      "swift",
      ["package", "dump-symbol-graph", "--minimum-access-level", "public",
       "--omit-extension-block-symbols", "--skip-synthesized-members"],
      { cwd: repoRoot, stdio: "inherit" }
    );
    path = candidates.find(existsSync);
  }
  if (!path) throw new Error("symbol graph not produced — is this the ThemeKit repo root?");
  return JSON.parse(readFileSync(path, "utf8")) as SymbolGraph;
}

const frag = (s: RawSymbol) =>
  (s.declarationFragments ?? []).map((f) => f.spelling).join("").replace(/\s+/g, " ").trim();
const docOf = (s: RawSymbol) => {
  const text = (s.docComment?.lines ?? []).map((l) => l.text).join(" ").trim();
  return text ? text.split(/\.\s/)[0].replace(/\.$/, "") + (text ? "." : "") : "";
};

/** Splits a Swift param list on top-level commas (ignores < > ( ) [ ] nesting). */
function splitParams(body: string): string[] {
  const out: string[] = [];
  let depth = 0, token = "";
  for (const ch of body) {
    if ("<([".includes(ch)) depth++;
    else if (">)]".includes(ch)) depth--;
    if (ch === "," && depth === 0) { out.push(token); token = ""; }
    else token += ch;
  }
  if (token.trim()) out.push(token);
  return out.map((p) => p.trim()).filter(Boolean);
}

/** Parses one Swift parameter — "label name: Type = default" or "_ name: Type". */
function parseParam(p: string): Param {
  const eq = p.indexOf("=");
  const dflt = eq >= 0 ? p.slice(eq + 1).trim() : undefined;
  const head = (eq >= 0 ? p.slice(0, eq) : p).trim();
  const colon = head.indexOf(":");
  const names = head.slice(0, colon).trim().split(/\s+/);
  const type = head.slice(colon + 1).trim();
  const label = names[0];
  const name = names[1] ?? names[0];
  return { label, name, type, default: dflt };
}

/** Extracts the parameter list substring from a full declaration signature. */
function paramsOf(signature: string): Param[] {
  const open = signature.indexOf("(");
  if (open < 0) return [];
  let depth = 0, end = -1;
  for (let i = open; i < signature.length; i++) {
    if (signature[i] === "(") depth++;
    else if (signature[i] === ")") { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end < 0) return [];
  const body = signature.slice(open + 1, end);
  return body.trim() ? splitParams(body).map(parseParam) : [];
}

/** Public enum name → its case names (for variants/states + semantic colors). */
export function parseEnums(graph: SymbolGraph): Record<string, string[]> {
  const byId = new Map(graph.symbols.map((s) => [s.identifier.precise, s]));
  const membersOf = new Map<string, string[]>();
  for (const r of graph.relationships) {
    if (r.kind === "memberOf") (membersOf.get(r.target) ?? membersOf.set(r.target, []).get(r.target)!).push(r.source);
  }
  const out: Record<string, string[]> = {};
  for (const s of graph.symbols) {
    if (s.kind.identifier !== "swift.enum" || !s.identifier.precise.includes(MODULE)) continue;
    const name = s.names?.title;
    if (!name) continue;
    const cases = (membersOf.get(s.identifier.precise) ?? [])
      .map((id) => byId.get(id))
      .filter((m): m is RawSymbol => !!m && m.kind.identifier === "swift.enum.case")
      .map((m) => (m.names?.title ?? "").replace(/^.*\./, ""))   // "BadgeStyle.neutral" → "neutral"
      .filter(Boolean);
    if (cases.length) out[name] = cases;
  }
  return out;
}

export function parseComponents(graph: SymbolGraph): Component[] {
  const byId = new Map(graph.symbols.map((s) => [s.identifier.precise, s]));
  const conformsTo = new Map<string, string[]>();
  const membersOf = new Map<string, string[]>();
  for (const r of graph.relationships) {
    if (r.kind === "conformsTo") (conformsTo.get(r.source) ?? conformsTo.set(r.source, []).get(r.source)!).push(r.target);
    else if (r.kind === "memberOf") (membersOf.get(r.target) ?? membersOf.set(r.target, []).get(r.target)!).push(r.source);
  }

  const out: Component[] = [];
  for (const s of graph.symbols) {
    if (s.kind.identifier !== "swift.struct") continue;
    const usr = s.identifier.precise;
    if (!usr.includes(MODULE)) continue;                         // ThemeKit-declared only
    const confs = conformsTo.get(usr) ?? [];
    if (!confs.includes(VIEW_USR)) continue;                     // View components only
    const name = s.names?.title ?? "";

    const inits: ComponentInit[] = [];
    const modifiers: Modifier[] = [];
    for (const mid of membersOf.get(usr) ?? []) {
      const m = byId.get(mid);
      if (!m) continue;
      const sig = frag(m);
      if (m.kind.identifier === "swift.init") {
        inits.push({ signature: sig, params: paramsOf(sig) });
      } else if (m.kind.identifier === "swift.method" && new RegExp(`->\\s*${name}\\b`).test(sig)) {
        const mn = m.names?.title ?? sig.replace(/^.*?func\s+(\w+).*$/, "$1");
        modifiers.push({ name: mn, signature: sig.replace(/^@\w+\s+/, "").replace(/^func\s+/, "."), doc: docOf(m) });
      }
    }
    // Shortest init first (the common call site), then the rest.
    inits.sort((a, b) => a.params.length - b.params.length);
    modifiers.sort((a, b) => a.name.localeCompare(b.name));
    out.push({
      name,
      doc: docOf(s),
      conformances: confs.map((c) => c.replace(/^s:.*\d([A-Za-z]+)P$/, "$1")),
      inits,
      modifiers,
    });
  }
  out.sort((a, b) => a.name.localeCompare(b.name));
  return out;
}
