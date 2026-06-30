/** Walks a Figma node tree → ThemeKit SwiftUI, with token snapping + a mapping report. */
import type { FigmaNode } from "./client.js";
import { matchComponent, type Mapping, type ProduceRule } from "./mapping.js";
import { matchColor, snapMetric, figmaColorToHex, tokenAccessor, type DesignToken } from "./tokenMatch.js";
import { auditA11y, formatA11y, type A11yFinding } from "./a11yAudit.js";

export interface ComponentAPI { name: string; params: { label: string; name: string; type: string; default?: string }[]; }
export interface Report {
  nodes: number; matched: number; unmapped: string[];
  tokenSnaps: string[]; needsReview: string[]; lowConfidence: string[];
  a11y: A11yFinding[];
}
export interface GenResult { code: string; report: Report; }

const pad = (d: number) => "    ".repeat(d);

/**
 * Figma-snapped spacing token name → the `Theme.SpacingKey` Swift case.
 * Not a plain prefix strip: `spacing-none` → `none` and `sp-4xl` → `xl4`.
 */
const SPACING_CASE: Record<string, string> = {
  "spacing-none": "none", "sp-xs": "xs", "sp-sm": "sm", "sp-md": "md",
  "sp-base": "base", "sp-lg": "lg", "sp-xl": "xl", "sp-4xl": "xl4",
};
export function spacingValueExpr(token: string): string {
  return `Theme.SpacingKey.${SPACING_CASE[token] ?? token.replace(/^sp-/, "")}.value`;
}

function textOf(node: FigmaNode): string {
  if (node.characters) return node.characters;
  const t = (node.children ?? []).find((c) => c.type === "TEXT");
  return t?.characters ?? node.name;
}
function firstFill(node: FigmaNode) {
  return (node.fills ?? []).find((f) => f.visible !== false && f.type === "SOLID" && f.color);
}

/** Normalized Figma variant/boolean properties: { "state": "disabled", "size": "small", "enabled": false }. */
function nodeProps(node: FigmaNode): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [rawKey, prop] of Object.entries(node.componentProperties ?? {})) {
    const key = rawKey.split("#")[0].trim().toLowerCase();
    out[key] = String(prop.value).toLowerCase();
  }
  return out;
}

/**
 * State-aware chainable modifiers for a mapped leaf, from (1) explicit rule modifiers,
 * then (2) automatic detection of disabled / size from the node name + variant props.
 * Maps to the native, always-available `.disabled(_:)` / `.controlSize(_:)`.
 */
function stateModifiers(node: FigmaNode, produce: ProduceRule, report: Report): string[] {
  const mods: string[] = [];
  const name = node.name.toLowerCase();
  const props = nodeProps(node);
  const add = (m: string) => { if (!mods.includes(m)) mods.push(m); };

  // 1) Explicit rule-driven modifiers.
  for (const r of produce.modifiers ?? []) {
    const byName = r.whenName && new RegExp(r.whenName, "i").test(node.name);
    let byProp = false;
    if (r.whenProp) {
      const [k, v] = r.whenProp.split("=").map((s) => s.trim().toLowerCase());
      byProp = props[k] === v;
    }
    if (byName || byProp) add(r.emit);
  }

  // 2) Automatic disabled detection (name or Enabled=false / State=Disabled).
  const disabled = /\b(disabled|inactive)\b/.test(name) || props["enabled"] === "false" || props["state"] === "disabled" || props["disabled"] === "true";
  if (disabled) add(".disabled(true)");

  // 3) Automatic control size from name segment or a Size variant.
  const sizeWord = props["size"] || (name.match(/\b(mini|small|large|regular)\b/)?.[1] ?? "");
  const sizeMap: Record<string, string> = { mini: ".mini", small: ".small", regular: ".regular", large: ".large" };
  if (sizeMap[sizeWord]) add(`.controlSize(${sizeMap[sizeWord]})`);

  // 4) Selected/active is usually a binding — flag it for review rather than inventing one.
  if (/\b(selected|active)\b/.test(name) || props["state"] === "selected") {
    report.needsReview.push(`${node.name}: appears selected/active — wire a Binding (isSelected/isOn) on ${produce.component}.`);
  }
  return mods;
}

export interface GenOptions {
  /**
   * When true, an unmapped Figma component `INSTANCE` that has children is walked
   * into (like a FRAME/GROUP) instead of being emitted as an opaque `// ⚠️ unmapped`
   * leaf. Lets a screen built from nested instances (forms, headers, nav bars)
   * actually convert. Default false — preserves the opaque-leaf behavior.
   */
  expandInstances?: boolean;
}

export function generate(root: FigmaNode, mapping: Mapping, tokens: DesignToken[], apis: Map<string, ComponentAPI>, opts: GenOptions = {}): GenResult {
  const report: Report = { nodes: 0, matched: 0, unmapped: [], tokenSnaps: [], needsReview: [], lowConfidence: [], a11y: [] };

  // Snap this node's visual values; record matches / needs-review.
  function snapColor(node: FigmaNode): void {
    const fill = firstFill(node);
    if (!fill?.color) return;
    const hex = figmaColorToHex(fill.color);
    const m = matchColor(hex, tokens, mapping.tolerances.colorDeltaE);
    if (m) report.tokenSnaps.push(`${node.name}: fill ${hex} → ${m.token} (ΔE ${m.deltaE.toFixed(1)})`);
    else report.needsReview.push(`${node.name}: fill ${hex} (no token within ΔE ${mapping.tolerances.colorDeltaE})`);
  }
  function spacingToken(node: FigmaNode): string | null {
    if (node.itemSpacing == null) return null;
    const t = snapMetric(node.itemSpacing, tokens, "spacing", mapping.tolerances.spacingSnapPx);
    if (t) report.tokenSnaps.push(`${node.name}: itemSpacing ${node.itemSpacing} → ${t}`);
    return t;
  }
  // Snapped foreground color modifier for a raw SwiftUI Text, or "" when no fill/token.
  function textColorMod(node: FigmaNode): string {
    const fill = firstFill(node);
    if (!fill?.color) return "";
    const cm = matchColor(figmaColorToHex(fill.color), tokens, mapping.tolerances.colorDeltaE);
    return cm ? `.foregroundStyle(${tokenAccessor(cm.token)})` : "";
  }

  function gen(node: FigmaNode, d: number): string {
    report.nodes++;
    snapColor(node);
    const match = matchComponent(node, mapping);

    if (match) {
      report.matched++;
      const tag = match.confidence < 0.6 ? `${pad(d)}// TODO: review (confidence ${match.confidence})\n` : "";
      if (match.confidence < 0.6) report.lowConfidence.push(`${node.name} → ${match.component} (${match.confidence})`);

      if (match.produce.container) {
        const sp = spacingToken(node);
        const stack = node.layoutMode === "HORIZONTAL" ? "HStack" : "VStack";
        const children = (node.children ?? []).map((c) => gen(c, d + 2)).join("\n");
        return `${tag}${pad(d)}Card {\n${pad(d + 1)}${stack}(${sp ? `spacing: ${spacingValueExpr(sp)}` : ""}) {\n${children}\n${pad(d + 1)}}\n${pad(d)}}`;
      }

      // Leaf component — build the init from the rule, verified against the real API.
      const api = apis.get(match.component);
      const args: string[] = [];
      const argsFrom = match.produce.argsFrom ?? {};
      for (const [label, src] of Object.entries(argsFrom)) {
        if (api && label !== "_" && !api.params.some((p) => p.label === label)) {
          report.needsReview.push(`${node.name}: ${match.component} has no param "${label}" (rule may be stale)`);
          continue;
        }
        const val = src === "{text}" ? `"${textOf(node).replace(/"/g, "'")}"` : src === "{label}" ? `"${node.name}"` : src;
        args.push(label === "_" ? val : `${label}: ${val}`);
      }
      const styleMods: string[] = [];
      if (match.produce.styleFromNameSegment != null) {
        const seg = node.name.split("/")[match.produce.styleFromNameSegment]?.toLowerCase();
        if (seg) {
          if (match.produce.styleModifier) {
            // Refactored API: the style axis is a chainable modifier, not an init arg.
            styleMods.push(`.${match.produce.styleModifier}(.${seg})`);
          } else if (!api || api.params.some((p) => p.label === "style")) {
            args.push(`style: .${seg}`);
          } else {
            report.needsReview.push(`${node.name}: ${match.component} has no "style" init param — set the style via its modifier.`);
          }
        }
      }
      let call = `${match.component}(${args.join(", ")})`;
      if (match.produce.trailingClosure) call += ` { }`;
      call += styleMods.join("");
      call += stateModifiers(node, match.produce, report).join("");
      // Raw SwiftUI Text (heuristic) — snap its fill to a token color instead of leaving it bare.
      if (match.component === "Text") call += textColorMod(node);
      return `${tag}${pad(d)}${call}`;
    }

    // Unmapped — raw SwiftUI fallback, flagged.
    if (node.type === "TEXT") {
      const color = textColorMod(node);
      const note = color ? `   // text color snapped to token` : `   // ⚠️ unmapped TEXT — use a Text token style`;
      return `${pad(d)}Text("${textOf(node).replace(/"/g, "'")}")${color}${note}`;
    }
    if ((node.type === "FRAME" || node.type === "GROUP" || (opts.expandInstances && node.type === "INSTANCE")) && node.children?.length) {
      report.unmapped.push(`${node.name} (${node.type})`);
      const sp = spacingToken(node);
      const stack = node.layoutMode === "HORIZONTAL" ? "HStack" : "VStack";
      const children = node.children.map((c) => gen(c, d + 1)).join("\n");
      return `${pad(d)}// ⚠️ unmapped: ${node.name}\n${pad(d)}${stack}(${sp ? `spacing: ${spacingValueExpr(sp)}` : ""}) {\n${children}\n${pad(d)}}`;
    }
    report.unmapped.push(`${node.name} (${node.type})`);
    return `${pad(d)}// ⚠️ unmapped: ${node.name} (${node.type})`;
  }

  const code = gen(root, 0);
  report.a11y = auditA11y(root);
  return { code, report };
}

export function formatReport(r: Report): string {
  const lines = [
    `Mapping report: ${r.matched}/${r.nodes} nodes mapped to ThemeKit components.`,
    r.tokenSnaps.length ? `\nToken snaps (${r.tokenSnaps.length}):\n${r.tokenSnaps.map((s) => `- ${s}`).join("\n")}` : "",
    r.needsReview.length ? `\n⚠️ Needs review (${r.needsReview.length}):\n${r.needsReview.map((s) => `- ${s}`).join("\n")}` : "",
    r.unmapped.length ? `\n⚠️ Unmapped nodes (${r.unmapped.length}):\n${r.unmapped.map((s) => `- ${s}`).join("\n")}` : "",
    r.lowConfidence.length ? `\nLow-confidence (review): ${r.lowConfidence.join(", ")}` : "",
    `\n${formatA11y(r.a11y)}`,
  ];
  return lines.filter(Boolean).join("\n");
}
