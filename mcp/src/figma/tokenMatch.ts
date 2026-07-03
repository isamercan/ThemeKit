/** Matches raw Figma values to ThemeKit design tokens (color ΔE, spacing/radius snap). */

export interface DesignToken { category: string; name: string; value: string; role?: string; }

interface Lab { L: number; a: number; b: number; }

function hexToLab(hex: string): Lab {
  const s = hex.replace("#", "");
  const srgb = [0, 2, 4].map((i) => parseInt(s.slice(i, i + 2), 16) / 255);
  const lin = srgb.map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  const [r, g, b] = lin;
  // sRGB → XYZ (D65)
  const X = r * 0.4124 + g * 0.3576 + b * 0.1805;
  const Y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  const Z = r * 0.0193 + g * 0.1192 + b * 0.9505;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f(X / 0.95047), fy = f(Y / 1.0), fz = f(Z / 1.08883);
  return { L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
}

/** CIE76 ΔE between two hex colors. */
export function deltaE(hex1: string, hex2: string): number {
  const a = hexToLab(hex1), b = hexToLab(hex2);
  return Math.hypot(a.L - b.L, a.a - b.a, a.b - b.b);
}

export interface ColorMatch { token: string; deltaE: number; }

/** Nearest color token within tolerance, or null ("needs review"). */
export function matchColor(hex: string, tokens: DesignToken[], maxDeltaE: number): ColorMatch | null {
  const colors = tokens.filter((t) => /^#[0-9a-fA-F]{6}$/.test(t.value));
  let best: ColorMatch | null = null;
  for (const t of colors) {
    const dE = deltaE(hex, t.value);
    if (!best || dE < best.deltaE) best = { token: t.name, deltaE: dE };
  }
  return best && best.deltaE <= maxDeltaE ? best : null;
}

/** Figma RGBA (0..1) → "RRGGBB" hex. */
export function figmaColorToHex(c: { r: number; g: number; b: number }): string {
  const h = (n: number) => Math.round(n * 255).toString(16).padStart(2, "0");
  return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
}

/** Snaps a px value to the nearest spacing/radius token within tolerance. */
export function snapMetric(px: number, tokens: DesignToken[], category: string, tolPx: number): string | null {
  const metrics = tokens.filter((t) => t.category === category && /^\d+$/.test(t.value));
  let best: { name: string; diff: number } | null = null;
  for (const t of metrics) {
    const diff = Math.abs(Number(t.value) - px);
    if (!best || diff < best.diff) best = { name: t.name, diff };
  }
  return best && best.diff <= tolPx ? best.name : null;
}

/** Maps a Figma color token-name to a ThemeKit accessor, e.g. `theme.background(.bgWhite)`. */
export function tokenAccessor(tokenName: string): string {
  // tokenName like "background.bg-white" / "text.text-primary"
  const [cat, ...rest] = tokenName.split(".");
  const camel = rest.join(".").replace(/[-.]+(\w)/g, (_, c: string) => c.toUpperCase());
  switch (cat) {
    case "foreground": return `theme.foreground(.${camel})`;
    case "border": return `theme.border(.${camel})`;
    case "text": return `theme.text(.${camel})`;
    case "palette": return `theme.palette(.${camel})`;
    case "background":
    default: return `theme.background(.${camel})`;
  }
}

/** Relative luminance (WCAG 2.x) of an "#RRGGBB" / "RRGGBB" hex. */
export function relativeLuminance(hex: string): number {
  const s = hex.replace("#", "");
  const [r, g, b] = [0, 2, 4].map((i) => {
    const c = parseInt(s.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two hex colors (1..21). */
export function contrastRatio(hexA: string, hexB: string): number {
  const la = relativeLuminance(hexA), lb = relativeLuminance(hexB);
  const [hi, lo] = la >= lb ? [la, lb] : [lb, la];
  return (hi + 0.05) / (lo + 0.05);
}

export interface WcagVerdict { ratio: number; aaNormal: boolean; aaLarge: boolean; aaaNormal: boolean; level: string; }

/** Grades a contrast ratio against WCAG 2.1 thresholds (normal & large text). */
export function wcagGrade(ratio: number): WcagVerdict {
  const aaNormal = ratio >= 4.5, aaLarge = ratio >= 3, aaaNormal = ratio >= 7;
  const level = aaaNormal ? "AAA" : aaNormal ? "AA" : aaLarge ? "AA Large only" : "FAIL";
  return { ratio, aaNormal, aaLarge, aaaNormal, level };
}
