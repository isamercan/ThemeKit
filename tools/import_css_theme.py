#!/usr/bin/env python3
"""Import a HeroUI-style CSS theme (OKLCH custom properties) into ThemeKit
theme JSON — a light `<name>Theme.json` + dark `<name>ThemeDark.json` pair that
`Theme.loadTheme(named:)` / `setTheme(jsonData:)` can consume.

The CSS only specifies ~30 semantic variables; ThemeKit needs ~155 tokens
(the full 50..900 Ant-style ladders, badges, shadows, typography, radius roles).
So this importer:
  1. parses the light (`:root`/`.light`/`.default`) and dark (`.dark`) blocks,
  2. converts every color (oklch / #hex / rgb) to sRGB hex,
  3. seeds ThemeKit's on-device palette generator (tools/gen_tokens.py) from the
     brand accents (accent -> primary+info, danger/success/warning -> semantic),
  4. builds a pure-neutral gray ramp interpolated from the CSS's own L anchors
     (background / border / muted / foreground), so surfaces stay HeroUI-neutral,
  5. overrides the exact semantic tokens the CSS specifies with their exact hexes,
  6. maps `--radius` / `--field-radius` onto the `radius-box`/`-field` roles,
  7. mints per-component spacing tokens from `--card-padding` (aliases
     `--card-p` / `--padding-card`) and `--card-header/-body/-footer-padding`
     — declared-only, 1:1 (no cascade flattening; Card resolves precedence).

Everything the CSS does NOT specify (turquoise/orange/purple/pink families,
badges, shadows) falls back to ThemeKit's defaults.

Usage:
    python3 tools/import_css_theme.py tools/themes/heroui.css \
        --name heroui --out Sources/ThemeKitCore/Resources --font Inter

Then either bundle it (loadTheme(named: "herouiTheme")) or hand the JSON to a
consumer app at runtime (Theme.shared.setTheme(jsonData:)).
"""
import argparse
import json
import math
import os
import re
import sys

# --------------------------------------------------------------------------
# Color conversion
# --------------------------------------------------------------------------

def _srgb_gamma(x):
    x = max(0.0, min(1.0, x))
    return 1.055 * (x ** (1 / 2.4)) - 0.055 if x > 0.0031308 else 12.92 * x


def oklch_to_hex(L, C, H):
    """OKLCH (L in %, C chroma, H degrees) -> sRGB 'rrggbb'."""
    L = L / 100.0
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return "%02x%02x%02x" % (round(_srgb_gamma(r) * 255),
                             round(_srgb_gamma(g) * 255),
                             round(_srgb_gamma(bl) * 255))


_OKLCH_RE = re.compile(r"oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)", re.I)
_HEX_RE = re.compile(r"#([0-9a-fA-F]{3,8})\b")
_RGB_RE = re.compile(r"rgba?\(\s*([\d.]+)[ ,]+([\d.]+)[ ,]+([\d.]+)", re.I)


class Color:
    """A parsed color: its hex plus (for oklch) the L/C/H so we can read L anchors
    for the neutral ramp. `None` for transparent / none / var() references."""

    __slots__ = ("hex", "L", "C", "H")

    def __init__(self, hex, L=None, C=None, H=None):
        self.hex, self.L, self.C, self.H = hex, L, C, H


def parse_color(value):
    value = value.strip().rstrip(";").strip()
    if not value or value in ("transparent", "none") or value.startswith("var("):
        return None
    m = _OKLCH_RE.search(value)
    if m:
        L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
        return Color(oklch_to_hex(L, C, H), L, C, H)
    m = _HEX_RE.search(value)
    if m:
        h = m.group(1)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        return Color(h[:6].lower())
    m = _RGB_RE.search(value)
    if m:
        r, g, b = (int(float(m.group(i))) for i in (1, 2, 3))
        return Color("%02x%02x%02x" % (r, g, b))
    return None


# --------------------------------------------------------------------------
# CSS parsing
# --------------------------------------------------------------------------

_BLOCK_RE = re.compile(r"([^{}]+)\{([^{}]*)\}", re.S)
_DECL_RE = re.compile(r"--([\w-]+)\s*:\s*([^;]+);")


def parse_css(text):
    """Return (light_vars, dark_vars): {var-name: raw-value}. A block is 'dark'
    if any selector in its comma list contains 'dark'; everything else is light."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)  # strip comments
    light, dark = {}, {}
    for sel, body in _BLOCK_RE.findall(text):
        target = dark if "dark" in sel.lower() else light
        for name, val in _DECL_RE.findall(body):
            target[name] = val.strip()
    return light, dark


# --------------------------------------------------------------------------
# ThemeKit token mapping
# --------------------------------------------------------------------------

# CSS var -> the ThemeKit semantic token(s) it should paint EXACTLY.
SEMANTIC_MAP = {
    "accent": ["foreground.fg-hero", "text.text-hero", "border.border-hero",
               "background.bg-hero", "background.systemcolors.bg-info",
               "border.systemcolors.border-info"],
    "focus": ["foreground.systemcolors.fg-info"],
    "accent-foreground": ["foreground.fg-secondary"],
    "danger": ["foreground.systemcolors.fg-error", "background.systemcolors.bg-error",
               "border.systemcolors.border-error"],
    "success": ["foreground.systemcolors.fg-success", "background.systemcolors.bg-success",
                "border.systemcolors.border-success"],
    "warning": ["foreground.systemcolors.fg-warning", "background.systemcolors.bg-warning",
                "border.systemcolors.border-warning"],
    "surface": ["background.bg-white"],
    "background": ["background.bg-base"],
    "border": ["border.border-primary"],
    "foreground": ["text.text-primary"],
    "muted": ["text.text-tertiary"],
    "surface-secondary": ["background.bg-elevator-primary"],
    "surface-tertiary": ["background.bg-secondary-light"],
    "default": ["background.bg-secondary"],
}

# CSS var -> palette family it seeds (full 50..900 ladder is regenerated from it).
SEED_MAP = {"accent": "primary", "focus": "info", "danger": "error",
            "success": "success", "warning": "warning"}
# `info` also tracks the accent unless the CSS gives an explicit focus color.
INFO_FALLBACK = "accent"

# Neutral gray ramp: which CSS var supplies the L anchor at each ladder step.
# Missing steps are linearly interpolated between the nearest anchors.
NEUTRAL_ANCHORS_LIGHT = {50: "background", 100: "surface-secondary", 200: "border",
                         500: "muted", 900: "foreground"}
NEUTRAL_ANCHORS_DARK = {50: "background", 100: "surface", 200: "border",
                        500: "muted", 900: "foreground"}
STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]

# CSS var(s) -> the demand-minted spacing token each mints, DECLARED-ONLY:
# a var maps 1:1 onto exactly ONE token — no cascade flattening here
# (`--card-padding` does not write header/body/footer entries). Precedence
# between the tokens lives in the component (Card) at render time.
# First name in the alias list wins within a scheme block.
SPACING_VAR_MAP = [
    ("card-padding", ["card-padding", "card-p", "padding-card"]),
    ("card-header-padding", ["card-header-padding"]),
    ("card-body-padding", ["card-body-padding"]),
    ("card-footer-padding", ["card-footer-padding"]),
]


def _lum_L(color, fallback):
    """L (0..100) of a parsed color; approximates from luminance when the source
    wasn't oklch (so hex/rgb inputs still yield a usable ramp anchor)."""
    if color is None:
        return fallback
    if color.L is not None:
        return color.L
    r = int(color.hex[0:2], 16) / 255
    g = int(color.hex[2:4], 16) / 255
    b = int(color.hex[4:6], 16) / 255
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) * 100


def build_neutral_ramp(vars_, anchors, hue):
    """Interpolate a pure-neutral (chroma 0) 10-step L ramp from the CSS anchors."""
    known = {}
    for step, var in anchors.items():
        c = parse_color(vars_.get(var, "")) if var in vars_ else None
        if c is not None:
            known[step] = _lum_L(c, None)
    if not known:  # nothing to anchor on — let the caller fall back to defaults
        return None
    xs = sorted(known)
    ramp = []
    for step in STEPS:
        if step in known:
            ramp.append(known[step])
        elif step <= xs[0]:
            ramp.append(known[xs[0]])
        elif step >= xs[-1]:
            ramp.append(known[xs[-1]])
        else:
            lo = max(x for x in xs if x < step)
            hi = min(x for x in xs if x > step)
            t = (step - lo) / (hi - lo)
            ramp.append(known[lo] + (known[hi] - known[lo]) * t)
    return [oklch_to_hex(L, 0.0, hue) for L in ramp]


def _rem_px(value):
    value = value.strip()
    if value.endswith("rem"):
        return round(float(value[:-3]) * 16)
    if value.endswith("px"):
        return round(float(value[:-2]))
    try:
        return round(float(value))
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Reuse gen_tokens.py's pure palette/token functions (without running its CLI).
# --------------------------------------------------------------------------

def load_gen_tokens(root):
    src = open(os.path.join(root, "tools", "gen_tokens.py")).read()
    sl = src[src.index("FOREGROUND = {"):src.index("# Each theme =")]
    ns = {}
    exec(compile(sl, "gen_tokens_slice", "exec"), ns)
    return ns


def build_theme(ns, vars_, dark, hue, font):
    accent = parse_color(vars_["accent"]).hex

    # 1) reseed the colorful ladders from the CSS brand colors
    bases = dict(ns["PALETTE_BASES"])
    for var, family in SEED_MAP.items():
        c = parse_color(vars_.get(var, "")) if var in vars_ else None
        if c is not None:
            bases[family] = c.hex
    if "focus" not in vars_ and parse_color(vars_.get(INFO_FALLBACK, "")):
        bases["info"] = accent
    ns["PALETTE_BASES"] = bases

    # 2) replace the neutral ramp with one interpolated from the CSS L anchors
    ramp = build_neutral_ramp(vars_, NEUTRAL_ANCHORS_DARK if dark else NEUTRAL_ANCHORS_LIGHT, hue)
    if ramp:
        ns["NEUTRAL_DARK" if dark else "NEUTRAL_LIGHT"] = ramp

    # 3) generate the full token set (tint 0: HeroUI surfaces stay neutral)
    data = ns["build_theme"](primary_base=accent, dark=dark, tint=0.0, font=font)

    # 4) override the exact semantic tokens the CSS specifies
    overrides = {}
    for var, tokens in SEMANTIC_MAP.items():
        c = parse_color(vars_.get(var, "")) if var in vars_ else None
        if c is None:
            continue
        for tok in tokens:
            overrides[tok] = c.hex
    for entry in data["colors"]:
        if entry["name"] in overrides:
            entry["hex"] = overrides[entry["name"]]

    # 5) radius roles from --radius / --field-radius (box / field / selector)
    box = _rem_px(vars_.get("radius", "")) if "radius" in vars_ else None
    field = _rem_px(vars_.get("field-radius", "")) if "field-radius" in vars_ else None
    roles = []
    if box is not None:
        roles += [{"name": "radius-box", "radius": box}, {"name": "radius-selector", "radius": box}]
    if field is not None:
        roles.append({"name": "radius-field", "radius": field})
    have = {r["name"] for r in data["radius"]}
    data["radius"] += [r for r in roles if r["name"] not in have]

    # 6) per-component spacing tokens from --card-padding & friends (declared-only)
    have_spacing = {s["name"] for s in data["spacing"]}
    for token, names in SPACING_VAR_MAP:
        raw = next((vars_[n] for n in names if n in vars_), None)
        px = _rem_px(raw) if raw is not None else None
        if px is not None and token not in have_spacing:
            data["spacing"].append({"name": token, "spacing": px})
    return data


def main():
    ap = argparse.ArgumentParser(description="Import a HeroUI-style CSS theme into ThemeKit JSON.")
    ap.add_argument("css", help="Path to the CSS file (HeroUI theme variables).")
    ap.add_argument("--name", required=True, help="Theme base name, e.g. 'heroui' -> herouiTheme.json.")
    ap.add_argument("--out", default="Sources/ThemeKitCore/Resources", help="Output directory.")
    ap.add_argument("--font", default="System", help="Typography font family (must be bundled to render).")
    ap.add_argument("--root", default=os.getcwd(), help="Repo root (to locate tools/gen_tokens.py).")
    args = ap.parse_args()

    light, dark = parse_css(open(args.css).read())
    if "accent" not in light:
        sys.exit("error: no --accent variable found in the light block; is this a HeroUI theme CSS?")
    if not dark:
        dark = light  # single-scheme CSS -> reuse light for the dark file
    else:
        # Structural (non-color) tokens are usually declared once in :root and
        # apply to both schemes — inherit them into dark when it omits them.
        for k in ("radius", "field-radius"):
            if k in light:
                dark.setdefault(k, light[k])
        # Spacing tokens inherit per-TOKEN (not per-alias): a dark block that
        # declares ANY alias of a token keeps its own alias order — light's
        # higher-priority alias must not shadow it (mirrors CSSTheme.swift).
        for _, names in SPACING_VAR_MAP:
            if not any(n in dark for n in names):
                for n in names:
                    if n in light:
                        dark[n] = light[n]

    hue_c = parse_color(light["accent"])
    hue = hue_c.H if hue_c and hue_c.H is not None else 253.83

    os.makedirs(args.out, exist_ok=True)
    for suffix, vars_, is_dark in [("", light, False), ("Dark", dark, True)]:
        ns = load_gen_tokens(args.root)  # fresh namespace per build (globals are mutated)
        data = build_theme(ns, vars_, is_dark, hue, args.font)
        path = os.path.join(args.out, f"{args.name}Theme{suffix}.json")
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(f"wrote {path}  (colors={len(data['colors'])}, font={args.font})")


if __name__ == "__main__":
    main()
