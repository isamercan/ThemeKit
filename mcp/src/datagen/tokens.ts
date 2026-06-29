/**
 * Extracts design tokens (their real values) from ThemeKit's bundled default
 * theme JSON + the metric scales. Single source of truth — the same JSON the
 * library loads at runtime.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";

export interface DesignToken {
  category: string;       // text | background | border | foreground | palette | radius | spacing | typography | shadow | radiusRole | semanticColor
  name: string;
  value: string;
  role?: string;
}

interface ThemeJSON {
  colors?: { name: string; hex: string }[];
  radius?: { name: string; radius: number }[];
  spacing?: { name: string; spacing: number }[];
  typography?: { name: string; size: number; weight: string; lineHeight: number }[];
  shadows?: { name: string; layers?: unknown[] }[];
}

export function extractTokens(repoRoot: string): DesignToken[] {
  const path = join(repoRoot, "Sources/ThemeKit/Resources/defaultTheme.json");
  const t = JSON.parse(readFileSync(path, "utf8")) as ThemeJSON;
  const out: DesignToken[] = [];

  for (const c of t.colors ?? []) {
    const category = c.name.split(".")[0]; // foreground|background|border|text|palette
    out.push({ category, name: c.name, value: `#${c.hex}` });
  }
  for (const r of t.radius ?? []) out.push({ category: "radius", name: r.name, value: `${r.radius}` });
  for (const s of t.spacing ?? []) out.push({ category: "spacing", name: s.name, value: `${s.spacing}` });
  for (const ty of t.typography ?? [])
    out.push({ category: "typography", name: ty.name, value: `${ty.size}/${ty.lineHeight} ${ty.weight}` });
  for (const sh of t.shadows ?? []) out.push({ category: "shadow", name: sh.name, value: `${(sh.layers ?? []).length} layer(s)` });

  // Role-based radii (daisyUI-style) + the chosen surface fallbacks.
  for (const [role, key] of [["box", "rd-md"], ["field", "rd-sm"], ["selector", "rd-xs"]] as const) {
    const v = (t.radius ?? []).find((r) => r.name === key)?.radius;
    out.push({ category: "radiusRole", name: role, value: `${v ?? "?"}`, role: `falls back to ${key}` });
  }
  // Semantic colors are resolved through the palette; list the names + roles.
  for (const sc of ["primary", "secondary", "accent", "neutral", "info", "success", "warning", "error"])
    out.push({ category: "semanticColor", name: sc, value: ".solid / .soft / .outline / .ghost + 50..900 ladder", role: "brand/status" });

  return out;
}
