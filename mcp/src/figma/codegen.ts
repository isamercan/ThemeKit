/** Walks a Figma node tree → ThemeKit SwiftUI, with token snapping + a mapping report. */
import type { FigmaNode } from "./client.js";
import { matchComponent, type Mapping, type ProduceRule } from "./mapping.js";
import { matchColor, snapMetric, figmaColorToHex, tokenAccessor, type DesignToken } from "./tokenMatch.js";
import { auditA11y, formatA11y, type A11yFinding } from "./a11yAudit.js";

export interface ComponentAPI { name: string; params: { label: string; name: string; type: string; default?: string }[]; }
/** An icon/image node the design uses — exported via the Figma images API, never inlined. */
export interface AssetRef { nodeId: string; name: string; slug: string; }
export interface Report {
  nodes: number; matched: number; unmapped: string[];
  tokenSnaps: string[]; needsReview: string[]; lowConfidence: string[];
  assets: AssetRef[];
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

/** Radius token name → the `Theme.RadiusKey` Swift case (same shape as SPACING_CASE). */
const RADIUS_CASE: Record<string, string> = {
  "radius-none": "none", "rd-xs": "xs", "rd-sm": "sm", "rd-md": "md",
  "rd-base": "base", "rd-lg": "lg", "rd-xl": "xl", "rd-4xl": "xl4",
};
export function radiusValueExpr(token: string): string {
  return `Theme.RadiusKey.${RADIUS_CASE[token] ?? token.replace(/^rd-/, "")}.value`;
}

// ── Typography: Figma fontSize/weight → nearest TextStyle token ────────────

interface TypeToken { name: string; size: number; weight: string; }
/** Typography tokens are stored as "size/lineHeight weight" (see datagen/tokens.ts). */
function parseTypography(tokens: DesignToken[]): TypeToken[] {
  return tokens.filter((t) => t.category === "typography").flatMap((t) => {
    const m = t.value.match(/^(\d+(?:\.\d+)?)\/\d+(?:\.\d+)?\s+(\w+)$/);
    return m ? [{ name: t.name, size: Number(m[1]), weight: m[2] }] : [];
  });
}
function weightName(w?: number): string {
  if (!w) return "regular";
  if (w >= 700) return "bold";
  if (w >= 600) return "semibold";
  if (w >= 500) return "medium";
  return "regular";
}
/**
 * Nearest TextStyle case for a Figma text node's size + weight — conservative:
 * only a same-weight token within 2pt matches; anything else is "needs review".
 */
export function matchTextStyle(fontSize: number | undefined, fontWeight: number | undefined, typo: TypeToken[]): string | null {
  if (fontSize == null) return null;
  const w = weightName(fontWeight);
  let best: { name: string; score: number } | null = null;
  for (const t of typo) {
    const score = Math.abs(t.size - fontSize) + (t.weight === w ? 0 : 3);
    if (!best || score < best.score) best = { name: t.name, score };
  }
  return best && best.score <= 2 ? best.name : null;
}

// ── Layout: axis inference for absolute (non-autolayout) containers ────────

export type Axis = "VERTICAL" | "HORIZONTAL" | "STACKED";
/**
 * The stack axis for a container. Autolayout frames declare it; GROUPs and
 * `layoutMode: NONE` frames are inferred from the child bounding boxes —
 * non-overlapping top-to-bottom → VStack, left-to-right → HStack, genuinely
 * overlapping → STACKED (ZStack). Beats the old behavior of forcing VStack.
 */
export function inferAxis(node: FigmaNode): Axis {
  if (node.layoutMode === "VERTICAL") return "VERTICAL";
  if (node.layoutMode === "HORIZONTAL") return "HORIZONTAL";
  const kids = node.children ?? [];
  const boxes = kids.map((c) => c.absoluteBoundingBox).filter(Boolean) as { x: number; y: number; width: number; height: number }[];
  if (boxes.length >= 2 && boxes.length === kids.length) {
    const TOL = 4;
    const byY = [...boxes].sort((a, b) => a.y - b.y);
    if (byY.every((b, i) => i === 0 || b.y >= byY[i - 1].y + byY[i - 1].height - TOL)) return "VERTICAL";
    const byX = [...boxes].sort((a, b) => a.x - b.x);
    if (byX.every((b, i) => i === 0 || b.x >= byX[i - 1].x + byX[i - 1].width - TOL)) return "HORIZONTAL";
    return "STACKED";
  }
  return "VERTICAL";
}

function textOf(node: FigmaNode): string {
  if (node.characters) return node.characters;
  const t = (node.children ?? []).find((c) => c.type === "TEXT");
  return t?.characters ?? node.name;
}

/**
 * Design-system scaffolding text that should not become real SwiftUI `Text` —
 * e.g. an icon "scribble" placeholder, or generic component slot labels. Skipped
 * by the codegen so the output isn't polluted with placeholder copy.
 */
const PLACEHOLDER_TEXT = new Set([
  "scribble", "action button", "input label", "supporting text title",
  "placeholder", "label", "text", "title",
]);
function isPlaceholderText(node: FigmaNode): boolean {
  return node.type === "TEXT" && PLACEHOLDER_TEXT.has((node.characters ?? "").trim().toLowerCase());
}

function firstFill(node: FigmaNode) {
  return (node.fills ?? []).find((f) => f.visible !== false && f.type === "SOLID" && f.color);
}

/** Vector-ish node types that are drawings, not layout — exported as assets. */
const VECTORISH = new Set(["VECTOR", "BOOLEAN_OPERATION", "STAR", "POLYGON", "REGULAR_POLYGON", "LINE"]);
function hasImageFill(node: FigmaNode): boolean {
  return (node.fills ?? []).some((f) => f.visible !== false && f.type === "IMAGE");
}
/** A node whose entire subtree is vector drawing — one icon, exported whole.
 *  An autolayout container is layout (a row OF icons), never a single drawing. */
function allVectorish(node: FigmaNode): boolean {
  if (VECTORISH.has(node.type)) return true;
  if (node.layoutMode === "HORIZONTAL" || node.layoutMode === "VERTICAL") return false;
  if ((node.type === "FRAME" || node.type === "GROUP" || node.type === "INSTANCE") && node.children?.length)
    return node.children.every(allVectorish);
  return false;
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
  /**
   * Max indentation depth to which `expandInstances` will recurse into nested
   * component instances, guarding against runaway output on deeply-nested boards.
   * Default 8. Beyond it, an instance falls back to an opaque `// ⚠️ unmapped` leaf.
   */
  instanceMaxDepth?: number;
}

export function generate(root: FigmaNode, mapping: Mapping, tokens: DesignToken[], apis: Map<string, ComponentAPI>, opts: GenOptions = {}): GenResult {
  const report: Report = { nodes: 0, matched: 0, unmapped: [], tokenSnaps: [], needsReview: [], lowConfidence: [], assets: [], a11y: [] };
  const typo = parseTypography(tokens);

  // Snap this node's visual values; record matches / needs-review.
  function snapColor(node: FigmaNode): void {
    const grad = (node.fills ?? []).find((f) => f.visible !== false && /^GRADIENT_/.test(f.type));
    if (grad) report.needsReview.push(`${node.name}: gradient fill (${grad.type}) — no single token; apply a gradient manually`);
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
  // Snapped `.textStyle(...)` for a text node's font size + weight, or "" (reported either way).
  function textStyleMod(node: FigmaNode): string {
    const size = node.style?.fontSize;
    if (size == null) return "";
    const t = matchTextStyle(size, node.style?.fontWeight, typo);
    if (t) {
      report.tokenSnaps.push(`${node.name}: font ${size}pt ${weightName(node.style?.fontWeight)} → .textStyle(.${t})`);
      return `.textStyle(.${t})`;
    }
    report.needsReview.push(`${node.name}: font ${size}pt ${weightName(node.style?.fontWeight)} — no matching TextStyle token`);
    return "";
  }

  /**
   * Token-snapped container modifiers for a RAW layout stack — padding, background,
   * corner radius, shadow. ThemeKit components stay theme-driven (their colors come
   * from the active theme), so these are only chained onto unmapped SwiftUI stacks.
   */
  function containerMods(node: FigmaNode): string[] {
    const mods: string[] = [];
    const { paddingLeft: l = 0, paddingRight: r = 0, paddingTop: t = 0, paddingBottom: b = 0 } = node;
    const snapPad = (v: number) => snapMetric(v, tokens, "spacing", mapping.tolerances.spacingSnapPx);
    if (l || r || t || b) {
      if (l === r && r === t && t === b) {
        const tok = snapPad(l);
        if (tok) { mods.push(`.padding(${spacingValueExpr(tok)})`); report.tokenSnaps.push(`${node.name}: padding ${l} → ${tok}`); }
        else report.needsReview.push(`${node.name}: padding ${l}px has no spacing token`);
      } else {
        if (l === r && l > 0) {
          const tok = snapPad(l);
          if (tok) { mods.push(`.padding(.horizontal, ${spacingValueExpr(tok)})`); report.tokenSnaps.push(`${node.name}: h-padding ${l} → ${tok}`); }
          else report.needsReview.push(`${node.name}: horizontal padding ${l}px has no spacing token`);
        }
        if (t === b && t > 0) {
          const tok = snapPad(t);
          if (tok) { mods.push(`.padding(.vertical, ${spacingValueExpr(tok)})`); report.tokenSnaps.push(`${node.name}: v-padding ${t} → ${tok}`); }
          else report.needsReview.push(`${node.name}: vertical padding ${t}px has no spacing token`);
        }
        if (l !== r || t !== b) report.needsReview.push(`${node.name}: asymmetric padding (t${t}/r${r}/b${b}/l${l}) — set per-edge manually`);
      }
    }
    const fill = firstFill(node);
    if (fill?.color) {
      const cm = matchColor(figmaColorToHex(fill.color), tokens, mapping.tolerances.colorDeltaE);
      if (cm) mods.push(`.background(${tokenAccessor(cm.token)})`);
    }
    if (node.cornerRadius && node.cornerRadius > 0) {
      const rt = snapMetric(node.cornerRadius, tokens, "radius", mapping.tolerances.radiusSnapPx);
      if (rt) { mods.push(`.cornerRadius(${radiusValueExpr(rt)})`); report.tokenSnaps.push(`${node.name}: corner radius ${node.cornerRadius} → ${rt}`); }
      else report.needsReview.push(`${node.name}: corner radius ${node.cornerRadius}px has no radius token`);
    }
    const shadow = (node.effects ?? []).find((e) => e.visible !== false && e.type === "DROP_SHADOW");
    if (shadow) {
      const style = (shadow.radius ?? 0) <= 8 ? "soft" : "elevated";
      mods.push(`.themeShadow(.${style})`);
      report.tokenSnaps.push(`${node.name}: drop shadow (blur ${shadow.radius ?? 0}) → .themeShadow(.${style})`);
    }
    return mods;
  }

  /** Children in visual order: autolayout keeps Figma order; inferred axes sort by y/x; ZStack keeps z-order. */
  function orderedChildren(node: FigmaNode, axis: Axis): FigmaNode[] {
    const kids = node.children ?? [];
    if (node.layoutMode === "VERTICAL" || node.layoutMode === "HORIZONTAL") return kids;
    if (kids.some((k) => !k.absoluteBoundingBox)) return kids;
    if (axis === "VERTICAL") return [...kids].sort((a, b) => a.absoluteBoundingBox!.y - b.absoluteBoundingBox!.y);
    if (axis === "HORIZONTAL") return [...kids].sort((a, b) => a.absoluteBoundingBox!.x - b.absoluteBoundingBox!.x);
    return kids; // ZStack: Figma children are bottom → top, which is exactly ZStack order.
  }

  /** The stack block for a container node: axis + alignment + spacing + SPACE_BETWEEN Spacers. */
  function stackBlock(node: FigmaNode, d: number): string {
    const axis = inferAxis(node);
    const isAutolayout = node.layoutMode === "VERTICAL" || node.layoutMode === "HORIZONTAL";
    const spaceBetween = isAutolayout && node.primaryAxisAlignItems === "SPACE_BETWEEN";
    const sp = spaceBetween ? null : spacingToken(node);
    const stack = axis === "HORIZONTAL" ? "HStack" : axis === "VERTICAL" ? "VStack" : "ZStack";
    const args: string[] = [];
    // Figma's default counter-axis alignment is MIN (top/left); SwiftUI's is center.
    const counter = node.counterAxisAlignItems ?? (isAutolayout ? "MIN" : undefined);
    if (stack === "VStack") {
      if (counter === "MIN") args.push("alignment: .leading");
      else if (counter === "MAX") args.push("alignment: .trailing");
    } else if (stack === "HStack") {
      if (counter === "MIN") args.push("alignment: .top");
      else if (counter === "MAX") args.push("alignment: .bottom");
      else if (counter === "BASELINE") args.push("alignment: .firstTextBaseline");
    } else {
      args.push("alignment: .topLeading");
      report.needsReview.push(`${node.name}: absolute layout flattened to ZStack — verify child positions`);
    }
    if (sp && stack !== "ZStack") args.push(`spacing: ${spacingValueExpr(sp)}`);
    const kids = orderedChildren(node, axis).map((c) => gen(c, d + 1)).filter(Boolean);
    const sep = spaceBetween ? `\n${pad(d + 1)}Spacer()\n` : "\n";
    const head = args.length ? `${stack}(${args.join(", ")})` : stack;
    return `${pad(d)}${head} {\n${kids.join(sep)}\n${pad(d)}}`;
  }

  function gen(node: FigmaNode, d: number): string {
    // Skip design-system placeholder text (e.g. "scribble") so it never becomes
    // real copy. Returns "" — callers filter empty children before joining.
    if (isPlaceholderText(node)) return "";
    report.nodes++;
    snapColor(node);
    const match = matchComponent(node, mapping);

    if (match) {
      report.matched++;
      const tag = match.confidence < 0.6 ? `${pad(d)}// TODO: review (confidence ${match.confidence})\n` : "";
      if (match.confidence < 0.6) report.lowConfidence.push(`${node.name} → ${match.component} (${match.confidence})`);

      if (match.produce.container) {
        // The matched component (Card by default) supplies its own surface, padding
        // and rounding from the theme — only the inner stack is emitted here.
        const inner = stackBlock(node, d + 1);
        return `${tag}${pad(d)}${match.component} {\n${inner}\n${pad(d)}}`;
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
      // Raw SwiftUI Text (heuristic) — snap its font to a TextStyle and its fill to a token color.
      if (match.component === "Text") call += textStyleMod(node) + textColorMod(node);
      return `${tag}${pad(d)}${call}`;
    }

    // Unmapped — raw SwiftUI fallback, flagged.
    if (node.type === "TEXT") {
      const style = textStyleMod(node);
      const color = textColorMod(node);
      const note = style || color ? `   // snapped to tokens` : `   // ⚠️ unmapped TEXT — use a Text token style`;
      return `${pad(d)}Text("${textOf(node).replace(/"/g, "'")}")${style}${color}${note}`;
    }

    // Icon / image → an asset to export (the images API hands out the PNG URLs; see the report).
    if (hasImageFill(node) || allVectorish(node)) {
      const slug = node.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "asset";
      report.assets.push({ nodeId: node.id, name: node.name, slug });
      return `${pad(d)}Image("${slug}").accessibilityLabel("${node.name.replace(/"/g, "'")}")   // ⚠️ asset: add to the asset catalog (export URL in the report)`;
    }

    // Decorative shape with a token-matched fill → a real shape, not a comment.
    if ((node.type === "RECTANGLE" || node.type === "ELLIPSE") && firstFill(node)?.color) {
      const cm = matchColor(figmaColorToHex(firstFill(node)!.color!), tokens, mapping.tolerances.colorDeltaE);
      if (cm) {
        const box = node.absoluteBoundingBox;
        let shape: string;
        if (node.type === "ELLIPSE") {
          shape = box && Math.abs(box.width - box.height) <= 1 ? "Circle()" : "Ellipse()";
        } else {
          const rt = node.cornerRadius ? snapMetric(node.cornerRadius, tokens, "radius", mapping.tolerances.radiusSnapPx) : null;
          shape = rt ? `RoundedRectangle(cornerRadius: ${radiusValueExpr(rt)})` : "Rectangle()";
        }
        const frame = box ? `.frame(${box.width <= 64 ? `width: ${Math.round(box.width)}, ` : ""}height: ${Math.round(box.height)})` : "";
        return `${pad(d)}${shape}.fill(${tokenAccessor(cm.token)})${frame}`;
      }
    }

    const canExpandInstance = !!opts.expandInstances && node.type === "INSTANCE" && d < (opts.instanceMaxDepth ?? 8);
    if ((node.type === "FRAME" || node.type === "GROUP" || canExpandInstance) && node.children?.length) {
      report.unmapped.push(`${node.name} (${node.type})`);
      const mods = containerMods(node).map((m) => `\n${pad(d)}${m}`).join("");
      // A frame with no visual styling is just layout, not a missing component.
      const plainLayout = !firstFill(node) && !mods;
      const note = plainLayout ? `// layout: ${node.name}` : `// ⚠️ unmapped: ${node.name}`;
      return `${pad(d)}${note}\n${stackBlock(node, d)}${mods}`;
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
    r.assets.length ? `\n🖼 Assets to export (${r.assets.length}):\n${r.assets.map((a) => `- ${a.name} → Image("${a.slug}")`).join("\n")}` : "",
    r.needsReview.length ? `\n⚠️ Needs review (${r.needsReview.length}):\n${r.needsReview.map((s) => `- ${s}`).join("\n")}` : "",
    r.unmapped.length ? `\n⚠️ Unmapped nodes (${r.unmapped.length}):\n${r.unmapped.map((s) => `- ${s}`).join("\n")}` : "",
    r.lowConfidence.length ? `\nLow-confidence (review): ${r.lowConfidence.join(", ")}` : "",
    `\n${formatA11y(r.a11y)}`,
  ];
  return lines.filter(Boolean).join("\n");
}
