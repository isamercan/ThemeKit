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
  heuristics: Record<string, string>;
  tokenAliases: { color?: Record<string, string>; text?: Record<string, string> };
}

const DEFAULT: Mapping = {
  tolerances: { colorDeltaE: 10, spacingSnapPx: 2, radiusSnapPx: 2 },
  componentRules: [],
  heuristics: { frameContainer: "Card", textOnly: "Text", autolayoutSingleTextFill: "PrimaryButton", imageFill: "RemoteImage" },
  tokenAliases: {},
};

export function loadMapping(path: string): Mapping {
  if (!existsSync(path)) return DEFAULT;
  const raw = JSON.parse(readFileSync(path, "utf8")) as Partial<Mapping> & Record<string, unknown>;
  return {
    tolerances: { ...DEFAULT.tolerances, ...(raw.tolerances ?? {}) },
    componentRules: (raw.componentRules ?? []).filter((r): r is MappingRule => !!r?.match && !!r?.produce),
    heuristics: { ...DEFAULT.heuristics, ...(raw.heuristics ?? {}) },
    tokenAliases: raw.tokenAliases ?? {},
  };
}

export interface Match { component: string; confidence: number; produce: ProduceRule; via: "rule" | "heuristic"; }

/** First matching config rule, else a heuristic, else null (→ raw fallback). */
export function matchComponent(node: FigmaNode, m: Mapping): Match | null {
  for (const rule of m.componentRules) {
    const { namePattern, type, componentKey } = rule.match;
    if (type && node.type !== type) continue;
    if (namePattern && !new RegExp(namePattern).test(node.name)) continue;
    if (componentKey && node.componentId !== componentKey) continue;
    return { component: rule.produce.component, confidence: rule.produce.confidence ?? 0.8, produce: rule.produce, via: "rule" };
  }
  // Heuristics
  const hasFill = (node.fills ?? []).some((f) => f.visible !== false && f.type === "SOLID");
  const textChild = (node.children ?? []).filter((c) => c.type === "TEXT");
  if (node.type === "INSTANCE" && node.layoutMode && node.layoutMode !== "NONE" && textChild.length === 1 && hasFill)
    return { component: m.heuristics.autolayoutSingleTextFill, confidence: 0.5, produce: { component: m.heuristics.autolayoutSingleTextFill, argsFrom: { _: "{text}" }, trailingClosure: "action" }, via: "heuristic" };
  if (node.type === "TEXT")
    return { component: m.heuristics.textOnly, confidence: 0.6, produce: { component: m.heuristics.textOnly, argsFrom: { _: "{text}" } }, via: "heuristic" };
  if ((node.type === "FRAME" || node.type === "GROUP") && (node.children?.length ?? 0) > 0)
    return { component: m.heuristics.frameContainer, confidence: 0.45, produce: { component: m.heuristics.frameContainer, container: true }, via: "heuristic" };
  return null;
}
