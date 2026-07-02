/** Config-driven Figma-node → ThemeKit-component matcher (rules first, heuristics last). */
import { readFileSync, existsSync } from "node:fs";
import type { FigmaNode } from "./client.js";

export interface ProduceRule {
  component: string;
  confidence?: number;
  argsFrom?: Record<string, string>;     // initLabel → "{text}" | "$text" | literal
  trailingClosure?: string;              // e.g. "action"
  styleFromNameSegment?: number;         // "Badge/Error" segment 1 → style: .error
  styleModifier?: string;                // emit the style as a modifier (e.g. "badgeStyle") instead of an init arg
  container?: boolean;                   // wraps children
  modifiers?: ModifierRule[];            // state-driven chainable modifiers
}

/** A chainable modifier emitted when a Figma state/property is detected on the node. */
export interface ModifierRule {
  /** Modifier emitted, e.g. ".disabled(true)" or ".controlSize(.small)". */
  emit: string;
  /** Emit when the node name matches this (case-insensitive) regex, e.g. "disabled|inactive". */
  whenName?: string;
  /** Emit when a Figma boolean/variant component-property matches (name=value), e.g. "State=Disabled". */
  whenProp?: string;
}
export interface MappingRule {
  match: { namePattern?: string; type?: string; componentKey?: string };
  produce: ProduceRule;
}
export interface Mapping {
  tolerances: { colorDeltaE: number; spacingSnapPx: number; radiusSnapPx: number };
  componentRules: MappingRule[];
  /**
   * The easy path: a Figma component name → a ThemeKit component. One line, no
   * params — the codegen fills the component's required init args from its
   * verified API (e.g. `"MARKAADITextField": "TextInput"` → `TextInput("…", text: $text)`).
   * For anything beyond the defaults (custom arg sources, style segments,
   * containers), write a full `componentRules` entry instead.
   */
  componentAliases: Record<string, string>;
  heuristics: Record<string, string>;
  tokenAliases: { color?: Record<string, string>; text?: Record<string, string> };
}

const DEFAULT: Mapping = {
  tolerances: { colorDeltaE: 10, spacingSnapPx: 2, radiusSnapPx: 2 },
  componentRules: [],
  componentAliases: {},
  heuristics: { frameContainer: "Card", textOnly: "Text", autolayoutSingleTextFill: "PrimaryButton", imageFill: "RemoteImage" },
  tokenAliases: {},
};

interface RawMapping {
  tolerances?: Partial<Mapping["tolerances"]>;
  componentRules?: MappingRule[];
  componentAliases?: Record<string, string>;
  heuristics?: Record<string, string>;
  tokenAliases?: Mapping["tokenAliases"];
}

function readRaw(path: string): RawMapping {
  if (!existsSync(path)) return {};
  try { return JSON.parse(readFileSync(path, "utf8")) as RawMapping; } catch { return {}; }
}

/** Normalize a (possibly-merged) raw object into a Mapping, applying defaults + filtering. */
function parseMapping(raw: RawMapping): Mapping {
  const aliases: Record<string, string> = {};
  for (const [k, v] of Object.entries(raw.componentAliases ?? {})) if (typeof v === "string" && !k.startsWith("//")) aliases[k] = v;
  return {
    tolerances: { ...DEFAULT.tolerances, ...(raw.tolerances ?? {}) },
    componentRules: (raw.componentRules ?? []).filter((r): r is MappingRule => !!r?.match && !!r?.produce),
    componentAliases: aliases,
    heuristics: { ...DEFAULT.heuristics, ...(raw.heuristics ?? {}) },
    tokenAliases: raw.tokenAliases ?? {},
  };
}

/**
 * Load the mapping from the bundled `figma-mapping.json`, then overlay an
 * optional **user-owned** file (path from `THEMEKIT_MAPPING`) so a user can add
 * their own `componentAliases` / `componentRules` from their project without
 * editing inside `node_modules`. The user file wins: their rules are tried first
 * and their aliases override. The override can be partial — just the keys it sets.
 */
export function loadMapping(path: string, overridePath?: string): Mapping {
  const base = readRaw(path);
  const over = overridePath ? readRaw(overridePath) : {};
  return parseMapping({
    tolerances: { ...base.tolerances, ...over.tolerances },
    componentRules: [...(over.componentRules ?? []), ...(base.componentRules ?? [])], // user rules first
    componentAliases: { ...base.componentAliases, ...over.componentAliases },
    heuristics: { ...base.heuristics, ...over.heuristics },
    tokenAliases: { color: { ...base.tokenAliases?.color, ...over.tokenAliases?.color }, text: { ...base.tokenAliases?.text, ...over.tokenAliases?.text } },
  });
}

export interface Match { component: string; confidence: number; produce: ProduceRule; via: "rule" | "alias" | "heuristic"; }

const clean = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
/** A Figma node name matches an alias key by exact, first-segment, or prefix (case/punct-insensitive). */
function matchesAlias(nodeName: string, key: string): boolean {
  const n = clean(nodeName), k = clean(key);
  if (!k) return false;
  return n === k || clean(nodeName.split("/")[0]) === k || n.startsWith(k);
}

/** First matching config rule, else a heuristic, else null (→ raw fallback). */
export function matchComponent(node: FigmaNode, m: Mapping): Match | null {
  for (const rule of m.componentRules) {
    const { namePattern, type, componentKey } = rule.match;
    if (type && node.type !== type) continue;
    // Case-insensitive: real layer names are "button/primary" as often as "Button/Primary".
    if (namePattern && !new RegExp(namePattern, "i").test(node.name)) continue;
    if (componentKey && node.componentId !== componentKey) continue;
    return { component: rule.produce.component, confidence: rule.produce.confidence ?? 0.8, produce: rule.produce, via: "rule" };
  }
  // componentAliases — the one-line shorthand. No argsFrom: the codegen fills the
  // component's required init args from its verified API. Explicit rules win over these.
  for (const [key, component] of Object.entries(m.componentAliases)) {
    if (matchesAlias(node.name, key)) return { component, confidence: 0.9, produce: { component }, via: "alias" };
  }
  // Heuristics
  const hasFill = (node.fills ?? []).some((f) => f.visible !== false && f.type === "SOLID");
  const textChild = (node.children ?? []).filter((c) => c.type === "TEXT");
  if (node.type === "INSTANCE" && node.layoutMode && node.layoutMode !== "NONE" && textChild.length === 1 && hasFill)
    return { component: m.heuristics.autolayoutSingleTextFill, confidence: 0.5, produce: { component: m.heuristics.autolayoutSingleTextFill, argsFrom: { _: "{text}" }, trailingClosure: "action" }, via: "heuristic" };
  if (node.type === "TEXT")
    return { component: m.heuristics.textOnly, confidence: 0.6, produce: { component: m.heuristics.textOnly, argsFrom: { _: "{text}" } }, via: "heuristic" };
  // A frame becomes a Card only when it LOOKS like a surface (fill / stroke / shadow).
  // A bare autolayout frame is layout, not a card — forcing Card on every frame was
  // the single biggest source of "doesn't look like the design" output.
  const looksLikeSurface = hasFill
    || (node.strokes ?? []).some((s) => s.visible !== false)
    || (node.effects ?? []).some((e) => e.visible !== false && e.type === "DROP_SHADOW");
  if ((node.type === "FRAME" || node.type === "GROUP") && (node.children?.length ?? 0) > 0 && looksLikeSurface)
    return { component: m.heuristics.frameContainer, confidence: 0.45, produce: { component: m.heuristics.frameContainer, container: true }, via: "heuristic" };
  return null;
}
