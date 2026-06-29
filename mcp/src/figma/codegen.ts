/** Walks a Figma node tree → ThemeKit SwiftUI, with token snapping + a mapping report. */
import type { FigmaNode } from "./client.js";
import { matchComponent, type Mapping } from "./mapping.js";
import { matchColor, snapMetric, figmaColorToHex, tokenAccessor, type DesignToken } from "./tokenMatch.js";

export interface ComponentAPI { name: string; params: { label: string; name: string; type: string; default?: string }[]; }
export interface Report {
  nodes: number; matched: number; unmapped: string[];
  tokenSnaps: string[]; needsReview: string[]; lowConfidence: string[];
}
export interface GenResult { code: string; report: Report; }

const pad = (d: number) => "    ".repeat(d);

function textOf(node: FigmaNode): string {
  if (node.characters) return node.characters;
  const t = (node.children ?? []).find((c) => c.type === "TEXT");
  return t?.characters ?? node.name;
}
function firstFill(node: FigmaNode) {
  return (node.fills ?? []).find((f) => f.visible !== false && f.type === "SOLID" && f.color);
}

export function generate(root: FigmaNode, mapping: Mapping, tokens: DesignToken[], apis: Map<string, ComponentAPI>): GenResult {
  const report: Report = { nodes: 0, matched: 0, unmapped: [], tokenSnaps: [], needsReview: [], lowConfidence: [] };

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
        return `${tag}${pad(d)}Card {\n${pad(d + 1)}${stack}(${sp ? `spacing: Theme.SpacingKey.${sp.replace(/^sp-/, "")}.value` : ""}) {\n${children}\n${pad(d + 1)}}\n${pad(d)}}`;
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
      if (match.produce.styleFromNameSegment != null) {
        const seg = node.name.split("/")[match.produce.styleFromNameSegment]?.toLowerCase();
        if (seg) args.push(`style: .${seg}`);
      }
      let call = `${match.component}(${args.join(", ")})`;
      if (match.produce.trailingClosure) call += ` { }`;
      return `${tag}${pad(d)}${call}`;
    }

    // Unmapped — raw SwiftUI fallback, flagged.
    if (node.type === "TEXT") return `${pad(d)}Text("${textOf(node).replace(/"/g, "'")}")   // ⚠️ unmapped TEXT — use Text token style`;
    if ((node.type === "FRAME" || node.type === "GROUP") && node.children?.length) {
      report.unmapped.push(`${node.name} (${node.type})`);
      const sp = spacingToken(node);
      const stack = node.layoutMode === "HORIZONTAL" ? "HStack" : "VStack";
      const children = node.children.map((c) => gen(c, d + 1)).join("\n");
      return `${pad(d)}// ⚠️ unmapped: ${node.name}\n${pad(d)}${stack}(${sp ? `spacing: Theme.SpacingKey.${sp.replace(/^sp-/, "")}.value` : ""}) {\n${children}\n${pad(d)}}`;
    }
    report.unmapped.push(`${node.name} (${node.type})`);
    return `${pad(d)}// ⚠️ unmapped: ${node.name} (${node.type})`;
  }

  const code = gen(root, 0);
  return { code, report };
}

export function formatReport(r: Report): string {
  const lines = [
    `Mapping report: ${r.matched}/${r.nodes} nodes mapped to ThemeKit components.`,
    r.tokenSnaps.length ? `\nToken snaps (${r.tokenSnaps.length}):\n${r.tokenSnaps.map((s) => `- ${s}`).join("\n")}` : "",
    r.needsReview.length ? `\n⚠️ Needs review (${r.needsReview.length}):\n${r.needsReview.map((s) => `- ${s}`).join("\n")}` : "",
    r.unmapped.length ? `\n⚠️ Unmapped nodes (${r.unmapped.length}):\n${r.unmapped.map((s) => `- ${s}`).join("\n")}` : "",
    r.lowConfidence.length ? `\nLow-confidence (review): ${r.lowConfidence.join(", ")}` : "",
  ];
  return lines.filter(Boolean).join("\n");
}
