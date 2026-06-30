/**
 * Figma-layer accessibility audit. Walks the node tree (carrying the nearest
 * opaque surface color as background context) and grades it against WCAG 2.1 —
 * BEFORE any code is generated, using the design's real colors, font sizes and
 * dimensions. Complements the code-level a11y_audit (which scans generated Swift).
 */
import type { FigmaNode, FigmaPaint } from "./client.js";
import { contrastRatio, wcagGrade, figmaColorToHex } from "./tokenMatch.js";

export type Severity = "error" | "warning";

export interface A11yFinding {
  nodeId: string;
  node: string;
  severity: Severity;
  wcag: string;       // e.g. "1.4.3 Contrast (Minimum)"
  message: string;
}

/** Minimum touch-target (Apple HIG) and legible font floor, in pt ≈ px @1x. */
const MIN_TOUCH = 44;
const MIN_FONT = 11;

/** Interactive-looking node names — should be reachable and large enough. */
const INTERACTIVE_NAME = /\b(button|btn|input|field|textfield|toggle|switch|checkbox|radio|chip|tab|fab|select|dropdown|stepper|slider|link|menu\s*item)\b/i;
const ICON_NAME = /\b(icon|glyph|avatar|image|logo|illustration)\b/i;

/** First opaque SOLID fill of a node → hex, or null (transparent / gradient / image). */
function opaqueSolidFill(node: FigmaNode): string | null {
  const f = (node.fills ?? []).find(
    (p: FigmaPaint) => p.visible !== false && p.type === "SOLID" && p.color &&
      (p.opacity ?? 1) >= 0.99 && (p.color.a ?? 1) >= 0.99,
  );
  return f?.color ? figmaColorToHex(f.color) : null;
}

/** A SOLID fill (even semi-transparent) → hex, for the text's own color. */
function solidFill(node: FigmaNode): string | null {
  const f = (node.fills ?? []).find((p: FigmaPaint) => p.visible !== false && p.type === "SOLID" && p.color);
  return f?.color ? figmaColorToHex(f.color) : null;
}

function hasTextDescendant(node: FigmaNode): boolean {
  if (node.type === "TEXT" && (node.characters ?? "").trim()) return true;
  return (node.children ?? []).some(hasTextDescendant);
}

function isInteractive(node: FigmaNode): boolean {
  return INTERACTIVE_NAME.test(node.name) || node.type === "INSTANCE" && INTERACTIVE_NAME.test(node.name);
}

/** WCAG 1.4.3 thresholds: large text (≥18pt, or ≥14pt bold) needs only 3:1. */
function contrastThreshold(node: FigmaNode): { aa: number; large: boolean } {
  const size = node.style?.fontSize ?? 0;
  const bold = (node.style?.fontWeight ?? 400) >= 700;
  const large = size >= 18 || (size >= 14 && bold);
  return { aa: large ? 3 : 4.5, large };
}

/**
 * Audits a Figma node subtree for accessibility issues. `background` is the
 * inherited surface color (hex) used for text-contrast grading.
 */
export function auditA11y(root: FigmaNode): A11yFinding[] {
  const findings: A11yFinding[] = [];

  function walk(node: FigmaNode, background: string | null): void {
    if (node.visible === false) return;
    const surface = opaqueSolidFill(node) ?? background;

    // 1.4.3 — text contrast against the nearest opaque surface.
    if (node.type === "TEXT" && (node.characters ?? "").trim()) {
      const fg = solidFill(node);
      if (fg && background) {
        const ratio = contrastRatio(fg, background);
        const { aa, large } = contrastThreshold(node);
        if (ratio < aa) {
          findings.push({
            nodeId: node.id, node: node.name, severity: "error",
            wcag: "1.4.3 Contrast (Minimum)",
            message: `text ${fg} on ${background} is ${ratio.toFixed(2)}:1 — needs ≥ ${aa}:1 for ${large ? "large" : "normal"} text (${wcagGrade(ratio).level}).`,
          });
        }
      } else if (fg && !background) {
        findings.push({
          nodeId: node.id, node: node.name, severity: "warning",
          wcag: "1.4.3 Contrast (Minimum)",
          message: `text ${fg} has no resolvable opaque background — verify contrast manually.`,
        });
      }
      // 1.4.4 / legibility — tiny font.
      const size = node.style?.fontSize;
      if (size != null && size < MIN_FONT) {
        findings.push({
          nodeId: node.id, node: node.name, severity: "warning",
          wcag: "1.4.4 Resize Text",
          message: `font size ${size}pt is below the ${MIN_FONT}pt legibility floor.`,
        });
      }
    }

    // 2.5.5 — interactive target smaller than 44×44pt.
    if (isInteractive(node)) {
      const box = node.absoluteBoundingBox;
      if (box && (box.width < MIN_TOUCH || box.height < MIN_TOUCH)) {
        findings.push({
          nodeId: node.id, node: node.name, severity: "warning",
          wcag: "2.5.5 Target Size",
          message: `interactive target is ${Math.round(box.width)}×${Math.round(box.height)}pt — below the ${MIN_TOUCH}×${MIN_TOUCH}pt minimum.`,
        });
      }
      // 4.1.2 — interactive without an accessible name.
      if (!hasTextDescendant(node)) {
        findings.push({
          nodeId: node.id, node: node.name, severity: "warning",
          wcag: "4.1.2 Name, Role, Value",
          message: `interactive element has no visible text — add an accessibility label.`,
        });
      }
    }

    // 1.1.1 — icon/image with no text alternative anywhere in its subtree.
    const isImageFill = (node.fills ?? []).some((p) => p.visible !== false && p.type === "IMAGE");
    if ((node.type === "VECTOR" || isImageFill || ICON_NAME.test(node.name)) && !hasTextDescendant(node) && !isInteractive(node)) {
      findings.push({
        nodeId: node.id, node: node.name, severity: "warning",
        wcag: "1.1.1 Non-text Content",
        message: `image/icon with no text alternative — add .accessibilityLabel(_:) or mark it decorative.`,
      });
    }

    for (const child of node.children ?? []) walk(child, surface);
  }

  walk(root, opaqueSolidFill(root));
  return findings;
}

/** Renders findings as report lines, grouped error-first. */
export function formatA11y(findings: A11yFinding[]): string {
  if (!findings.length) return "✓ Accessibility: no WCAG issues detected at the Figma layer.";
  const order = (s: Severity) => (s === "error" ? 0 : 1);
  const sorted = [...findings].sort((a, b) => order(a.severity) - order(b.severity));
  const errors = sorted.filter((f) => f.severity === "error").length;
  const head = `♿ Accessibility — ${findings.length} issue(s)${errors ? `, ${errors} error(s)` : ""}:`;
  const lines = sorted.map((f) => `- [${f.severity === "error" ? "✗" : "⚠"} ${f.wcag}] ${f.node}: ${f.message}`);
  return [head, ...lines].join("\n");
}
