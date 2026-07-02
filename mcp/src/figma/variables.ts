/**
 * ThemeKit design tokens → Figma Variables.
 *
 * The reverse of `design_to_code`: instead of Figma → SwiftUI, this turns the
 * token catalog (the single source of truth in data/themekit.json) into a Figma
 * Variables library — a **Brand** collection with one MODE per theme preset
 * (so a designer flips brand/theme like the app does), plus Color / Radius /
 * Spacing / Typography collections.
 *
 * Round-trip by design: the token↔variable name mapping is a pure, invertible
 * function (`tokenToPath` / `pathToToken`) and every variable carries its
 * originating ThemeKit token in `codeSyntax.iOS`, so a future Figma → tokens
 * importer can read the design back into a theme.json without guessing.
 */
import type { DesignToken } from "./tokenMatch.js";

export interface ThemePreset { id: string; name: string; primary: string; secondary: string; accent: string; base: string; }

export type VarType = "COLOR" | "FLOAT" | "STRING";
export interface FigmaColor { r: number; g: number; b: number; a: number; }
export type VarValue = FigmaColor | number | string;

export interface VarDef {
  /** Figma variable name (grouped by "/", e.g. "palette/primary/50"). */
  name: string;
  type: VarType;
  /** Originating ThemeKit token name — the round-trip key (also emitted as codeSyntax). */
  token: string;
  /** modeName → value. Single-mode collections use just "Default". */
  values: Record<string, VarValue>;
}
export interface Collection {
  name: string;
  /** Mode display names; [0] is the collection's initial mode. */
  modes: string[];
  variables: VarDef[];
}
export interface VariablesModel {
  collections: Collection[];
  /** Token categories intentionally not exported as variables (with why). */
  skipped: string[];
  meta: { tokenCount: number; variableCount: number; presetModes: number };
}

const DEFAULT_MODE = "Default";
const isHex6 = (v: string) => /^#?[0-9a-fA-F]{6}$/.test(v);

/** token name "foreground.fg-hero" → Figma path "foreground/fg-hero". Reversible: names never contain "/". */
export function tokenToPath(token: string): string { return token.replace(/\./g, "/"); }
/** Inverse of `tokenToPath` — for the future Figma → tokens importer. Paths never contain ".". */
export function pathToToken(path: string): string { return path.replace(/\//g, "."); }

/** "#rrggbb" (or "rrggbb") → Figma {r,g,b,a} in 0..1, rounded to 4dp for stable payloads. */
export function hexToFigmaColor(hex: string): FigmaColor {
  const s = hex.replace(/^#/, "");
  const ch = (i: number) => Math.round((parseInt(s.slice(i, i + 2), 16) / 255) * 1e4) / 1e4;
  return { r: ch(0), g: ch(2), b: ch(4), a: 1 };
}

/** Ensure Figma mode names are unique (Figma requires it); collisions get their preset id appended. */
function uniqueModeNames(presets: ThemePreset[]): Map<string, string> {
  const seen = new Set<string>();
  const out = new Map<string, string>();
  for (const p of presets) {
    let name = p.name || p.id;
    if (seen.has(name)) name = `${name} (${p.id})`;
    seen.add(name);
    out.set(p.id, name);
  }
  return out;
}

const floatVar = (name: string, token: string, value: number): VarDef =>
  ({ name, type: "FLOAT", token, values: { [DEFAULT_MODE]: value } });

/** Build the tool-agnostic variables model from the token catalog + theme presets. */
export function buildVariables(tokens: DesignToken[], presets: ThemePreset[]): VariablesModel {
  const collections: Collection[] = [];
  const skipped: string[] = [];

  // 1) Brand — 4 seed channels, one MODE per preset. The theming anchor + round-trip core.
  const modeName = uniqueModeNames(presets);
  const modes = presets.map((p) => modeName.get(p.id)!);
  const channels: ("primary" | "secondary" | "accent" | "base")[] = ["primary", "secondary", "accent", "base"];
  const brandVars: VarDef[] = channels.map((ch) => ({
    name: ch, type: "COLOR", token: `brand.${ch}`,
    values: Object.fromEntries(presets.map((p) => [modeName.get(p.id)!, hexToFigmaColor(p[ch])])),
  }));
  collections.push({ name: "Brand", modes, variables: brandVars });

  // 2) Color — every resolved color token (single Default mode = the bundled theme).
  const colorCats = new Set(["foreground", "background", "border", "text", "palette"]);
  const colorVars: VarDef[] = tokens
    .filter((t) => colorCats.has(t.category) && isHex6(t.value))
    .map((t) => ({ name: tokenToPath(t.name), type: "COLOR", token: t.name, values: { [DEFAULT_MODE]: hexToFigmaColor(t.value) } }));
  collections.push({ name: "Color", modes: [DEFAULT_MODE], variables: colorVars });

  // 3) Radius — size scale + semantic roles (box/field/selector) as FLOAT.
  const radiusVars: VarDef[] = [
    ...tokens.filter((t) => t.category === "radius" && /^\d+$/.test(t.value)).map((t) => floatVar(t.name, t.name, Number(t.value))),
    ...tokens.filter((t) => t.category === "radiusRole" && /^\d+$/.test(t.value)).map((t) => floatVar(`role/${t.name}`, `radiusRole.${t.name}`, Number(t.value))),
  ];
  collections.push({ name: "Radius", modes: [DEFAULT_MODE], variables: radiusVars });

  // 4) Spacing — FLOAT.
  const spacingVars = tokens.filter((t) => t.category === "spacing" && /^\d+$/.test(t.value)).map((t) => floatVar(t.name, t.name, Number(t.value)));
  collections.push({ name: "Spacing", modes: [DEFAULT_MODE], variables: spacingVars });

  // 5) Typography — per style: size + lineHeight (FLOAT) and weight (STRING).
  //    (Figma text *styles* would be richer, but variables keep it token-driven & round-trippable.)
  const typoVars: VarDef[] = [];
  for (const t of tokens.filter((x) => x.category === "typography")) {
    const m = t.value.match(/^(\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)\s+(\w+)$/);
    if (!m) continue;
    typoVars.push(floatVar(`${t.name}/size`, `${t.name}.size`, Number(m[1])));
    typoVars.push(floatVar(`${t.name}/lineHeight`, `${t.name}.lineHeight`, Number(m[2])));
    typoVars.push({ name: `${t.name}/weight`, type: "STRING", token: `${t.name}.weight`, values: { [DEFAULT_MODE]: m[3] } });
  }
  collections.push({ name: "Typography", modes: [DEFAULT_MODE], variables: typoVars });

  skipped.push("shadow → Figma effect styles, not variables (3 tokens)");
  skipped.push("semanticColor → resolved through the palette ladder at runtime (8 descriptive tokens)");

  const variableCount = collections.reduce((n, c) => n + c.variables.length, 0);
  return { collections, skipped, meta: { tokenCount: tokens.length, variableCount, presetModes: presets.length } };
}

// ── Figma REST bulk-write payload ──────────────────────────────────────────
// Body for POST /v1/files/:file_key/variables. The initial mode of each
// collection is auto-created with the collection; we reference it by the temp
// id we assign to `initialModeId` and rename it via an UPDATE (Figma resolves
// the temp id). Additional modes (Brand's presets) are CREATEd.

export interface FigmaRestPayload {
  variableCollections: object[];
  variableModes: object[];
  variables: object[];
  variableModeValues: object[];
}

export function toFigmaRestPayload(model: VariablesModel): FigmaRestPayload {
  const variableCollections: object[] = [];
  const variableModes: object[] = [];
  const variables: object[] = [];
  const variableModeValues: object[] = [];
  let seq = 0;
  const uid = (p: string) => `${p}${seq++}`;

  for (const col of model.collections) {
    const colId = uid("col:");
    const modeId = new Map<string, string>();
    col.modes.forEach((mode, i) => {
      const id = uid("mode:");
      modeId.set(mode, id);
      variableModes.push({ action: i === 0 ? "UPDATE" : "CREATE", id, name: mode, variableCollectionId: colId });
    });
    variableCollections.push({ action: "CREATE", id: colId, name: col.name, initialModeId: modeId.get(col.modes[0]) });

    for (const v of col.variables) {
      const varId = uid("var:");
      variables.push({
        action: "CREATE", id: varId, name: v.name, variableCollectionId: colId, resolvedType: v.type,
        codeSyntax: { iOS: v.token },
      });
      for (const [mode, value] of Object.entries(v.values)) {
        variableModeValues.push({ variableId: varId, modeId: modeId.get(mode), value });
      }
    }
  }
  return { variableCollections, variableModes, variables, variableModeValues };
}
