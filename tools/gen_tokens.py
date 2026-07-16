#!/usr/bin/env python3
"""Generate the ThemeKit design-token JSON + Swift color enums from the
Etstur/MAF Figma design system. Token NAMES are semantic (brand-agnostic)."""
import json, os, sys

ROOT = sys.argv[1]
RES = os.path.join(ROOT, "Sources/ThemeKitCore/Resources")
GEN = os.path.join(ROOT, "Sources/ThemeKitCore/Theme")
os.makedirs(RES, exist_ok=True)

# ---- Semantic color tokens — Ant-style ALIAS layer DERIVED from the palette.
# Each token is one of:
#   ("d", family, step)        -> derive from the active (light/dark) palette ladder
#   ("a", light_hex, dark_hex) -> absolute anchor (white / inverse fills / alphas)
# Result: changing the theme palette (or dark mode) re-tints the whole UI, and
# dark mode "just works" by deriving from the dark palette. Only tokens actually
# used by components are kept (128 -> 53). "/" denotes nested groups.
FOREGROUND = {
    "fg-hero": ("d", "primary", 500),
    "fg-secondary": ("a", "ffffff", "ffffff"),     # text/icon on a vivid accent fill
    "fg-turquoise": ("d", "turquoise", 500),
    "badge/fg-maximumpink": ("d", "pink", 600),
    "badge/fg-turquoise": ("d", "turquoise", 600),
    "badge/fg-orange": ("d", "orange", 700),
    "systemcolors/fg-success": ("d", "success", 500),
    "systemcolors/fg-error": ("d", "error", 500),
    "systemcolors/fg-warning": ("d", "warning", 500),
    "systemcolors/fg-info": ("d", "info", 500),
}
BACKGROUND = {
    "bg-white": ("a", "ffffff", "181c24"),         # pure white (overlays, modals)
    "bg-base": ("d", "neutral-raw", 50),           # base-100 surface — TRUE neutral, exempt from re-skin tint
    "bg-hero": ("d", "primary", 500),
    "bg-elevator-primary": ("d", "neutral", 50),   # page background
    "bg-elevator-tertiary": ("d", "primary", 50),  # soft primary container
    "bg-secondary": ("d", "neutral", 300),
    "bg-secondary-light": ("d", "neutral", 100),
    "bg-tertiary": ("a", "000929", "3a4150"),      # neutral solid fill (white text on it)
    "bg-backdrop": ("a", "00000066", "0000008c"),  # modal scrim (Backdrop atom): black @ 40% light / 55% dark
    "bg-turquoise": ("d", "turquoise", 500),
    "bg-turquoise-light": ("d", "turquoise", 50),
    "bg-orange": ("d", "orange", 500),
    "badge/bg-maximumpink-base": ("d", "pink", 500),
    "badge/bg-maximumpink-light": ("d", "pink", 50),
    "badge/bg-purple": ("d", "purple", 50),
    "badge/bg-orange": ("d", "orange", 50),
    "badge/bg-turquoise-light": ("d", "turquoise", 100),
    "skeleton/bg-skeleton-base": ("a", "00092914", "ffffff14"),
    "systemcolors/bg-success": ("d", "success", 500),
    "systemcolors/bg-success-light": ("d", "success", 50),
    "systemcolors/bg-error": ("d", "error", 500),
    "systemcolors/bg-error-light": ("d", "error", 50),
    "systemcolors/bg-warning": ("d", "warning", 500),
    "systemcolors/bg-warning-light": ("d", "warning", 50),
    "systemcolors/bg-info": ("d", "info", 500),
    "systemcolors/bg-info-light": ("d", "info", 50),
}
BORDER = {
    "border-hero": ("d", "primary", 500),
    "border-primary": ("d", "neutral", 200),
    "border-orange": ("d", "orange", 300),
    "border-turquoise": ("d", "turquoise", 300),
    "systemcolors/border-success": ("d", "success", 500),
    "systemcolors/border-success-light": ("d", "success", 200),
    "systemcolors/border-error": ("d", "error", 500),
    "systemcolors/border-error-light": ("d", "error", 200),
    "systemcolors/border-warning": ("d", "warning", 500),
    "systemcolors/border-warning-light": ("d", "warning", 200),
    "systemcolors/border-info": ("d", "info", 500),
    "systemcolors/border-info-light": ("d", "info", 200),
}
TEXT = {
    "text-primary": ("d", "neutral", 900),
    "text-secondary": ("d", "neutral", 700),
    "text-tertiary": ("d", "neutral", 500),
    "text-disabled": ("d", "neutral", 300),
    "text-hero": ("d", "primary", 500),
    "text-purple": ("d", "purple", 500),
    "text-secondary-inverse": ("a", "d8d9de", "c5c6ce"),
}
CATEGORIES = [("foreground", FOREGROUND), ("background", BACKGROUND), ("border", BORDER), ("text", TEXT)]


def resolve_token(token, palette, dark):
    """('d',family,step) -> palette hex; ('a',light,dark) -> the scheme's hex."""
    if token[0] == "d":
        _, family, step = token
        return palette["%s/%d" % (family, step)]
    _, light, darkv = token
    return darkv if dark else light

RADIUS = {"radius-none": 0, "rd-xs": 6, "rd-sm": 8, "rd-md": 16, "rd-base": 24, "rd-lg": 32, "rd-xl": 40, "rd-4xl": 64}
SPACING = {"spacing-none": 0, "sp-xs": 4, "sp-sm": 8, "sp-md": 16, "sp-base": 24, "sp-lg": 32, "sp-xl": 40, "sp-4xl": 64,
           # Semantic spacing role — inner padding of box-class surfaces (Theme.SpacingRole.box).
           # Default 16 (== sp-md); scales with the theme like the rest of the scale.
           "spacing-box": 16}

# ---- Typography ramp (name -> size, weight, lineHeight). Themed via JSON so a
# theme switch can change the font family + metrics, not just colors. ----
BASE_TYPOGRAPHY = {
    "displayLg": (48, "bold", 68), "displayMd": (44, "bold", 64), "displayBase": (40, "bold", 60), "displaySm": (36, "bold", 60),
    "heading2xl": (40, "semibold", 60), "headingXl": (36, "semibold", 54), "headingLg": (32, "semibold", 44),
    "headingMd": (28, "semibold", 40), "headingBase": (24, "semibold", 30), "headingSm": (20, "semibold", 26),
    "headingXs": (18, "semibold", 24), "heading2xs": (16, "semibold", 20), "heading3xs": (14, "semibold", 16),
    "labelLg600": (18, "semibold", 24), "labelLg700": (18, "bold", 24), "labelMd600": (16, "semibold", 20), "labelMd700": (16, "bold", 20),
    "labelBase600": (14, "semibold", 16), "labelBase700": (14, "bold", 16), "labelSm600": (12, "semibold", 14), "labelSm700": (12, "bold", 14),
    "bodyLg500": (18, "medium", 28), "bodyLg400": (18, "regular", 28), "bodyMd500": (16, "medium", 24), "bodyMd400": (16, "regular", 24),
    "bodyBase500": (14, "medium", 20), "bodyBase400": (14, "regular", 20), "bodySm500": (12, "medium", 16), "bodySm400": (12, "regular", 16),
    "overline400": (10, "regular", 12), "overline500": (10, "medium", 12),
    "linkMd": (16, "semibold", 24), "linkBase": (14, "semibold", 20), "linkSm": (12, "semibold", 16),
}

# ---- Shadows (name -> layered drop shadows). Themed via JSON so a theme can
# change elevation feel (softer/tighter) along with everything else. ----
# Color tokens are 8-digit RRGGBBAA.
_SH3, _SH5, _SH8, _TAB = "3352a408", "3352a40d", "3352a414", "0009291a"
BASE_SHADOWS = {
    "elevated": [(_SH8, 8, 0, 6), (_SH5, 14, 0, 9), (_SH3, 24, 0, 12)],
    "tabBar":   [(_TAB, 8, 0, 0)],
    "soft":     [(_SH8, 6, 0, 2)],
}

# ---- Primitive palettes (Ant Design 10-shade ladders) ----------------------
# Each semantic color is expanded into a 50..900 ladder with the exact
# @ant-design/colors `generate()` algorithm (HSV curve, base = step 500).
PALETTE_BASES = {
    "primary": "056bfd", "neutral": "808494", "info": "2e90fa",
    "success": "12b76a", "warning": "f79009", "error": "f04438",
    "turquoise": "0fb4ab", "orange": "ee9124", "purple": "b48bea", "pink": "ff0d87",
}
STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]

# Neutral grays are curated (the colorful HSV algorithm doesn't distribute a gray
# scale well). Cool-tinted to match the 808494 seed. Dark = the inverted ramp.
NEUTRAL_LIGHT = ["f6f7f9", "eceef1", "dde0e5", "c5c9d0", "a3a8b2", "808494", "5b5e69", "464951", "2b2d35", "0e1015"]
NEUTRAL_DARK = ["14161b", "1b1e24", "2a2e38", "3a3f4b", "565b68", "80858f", "9aa0ab", "bcc1ca", "d8dbe1", "f0f2f6"]

_HUE_STEP = 2
_SAT_STEP, _SAT_STEP2 = 0.16, 0.05
_BRI_STEP1, _BRI_STEP2 = 0.05, 0.15
_LIGHT_COUNT, _DARK_COUNT = 5, 4


def _hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _rgb_to_hex(r, g, b):
    return "%02x%02x%02x" % (round(r), round(g), round(b))


def _rgb_to_hsv(r, g, b):
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    v = mx
    s = 0 if mx == 0 else d / mx
    if d == 0:
        h = 0.0
    elif mx == r:
        h = ((g - b) / d + (6 if g < b else 0))
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60.0, s, v


def _hsv_to_rgb(h, s, v):
    h = (h % 360) / 60.0
    i = int(h) % 6
    f = h - int(h)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r = (v, q, p, p, t, v)[i]
    g = (t, v, v, q, p, p)[i]
    b = (p, p, t, v, v, q)[i]
    return r * 255, g * 255, b * 255


def _ant_hue(h, i, light):
    h = round(h)
    if 60 <= h <= 240:
        hue = h - _HUE_STEP * i if light else h + _HUE_STEP * i
    else:
        hue = h + _HUE_STEP * i if light else h - _HUE_STEP * i
    return hue % 360


def _ant_sat(h, s, i, light):
    if h == 0 and s == 0:
        return s
    if light:
        sat = s - _SAT_STEP * i
    elif i == _DARK_COUNT:
        sat = s + _SAT_STEP
    else:
        sat = s + _SAT_STEP2 * i
    sat = min(sat, 1.0)
    if light and i == _LIGHT_COUNT and sat > 0.1:
        sat = 0.1
    return round(max(sat, 0.06) * 100) / 100


def _ant_val(v, i, light):
    val = v + _BRI_STEP1 * i if light else v - _BRI_STEP2 * i
    return round(min(max(val, 0.0), 1.0) * 100) / 100   # clamp: mid-gray bases must not underflow


def ant_generate(base_hex):
    """Return 10 hex shades (lightest..darkest); index 5 == base."""
    h, s, v = _rgb_to_hsv(*_hex_to_rgb(base_hex))
    out = []
    for i in range(_LIGHT_COUNT, 0, -1):
        out.append(_rgb_to_hex(*_hsv_to_rgb(_ant_hue(h, i, True), _ant_sat(h, s, i, True), _ant_val(v, i, True))))
    out.append(base_hex.lstrip("#"))
    for i in range(1, _DARK_COUNT + 1):
        out.append(_rgb_to_hex(*_hsv_to_rgb(_ant_hue(h, i, False), _ant_sat(h, s, i, False), _ant_val(v, i, False))))
    return out


def _mix(c1, c2, amount):
    """Blend `amount`% of c2 into c1 (tinycolor.mix). 0 -> c1, 100 -> c2."""
    a, b = _hex_to_rgb(c1), _hex_to_rgb(c2)
    p = amount / 100.0
    return _rgb_to_hex(*[b[i] * p + a[i] * (1 - p) for i in range(3)])


def _tint_neutral(shades, primary_base, tint):
    """Full re-skin: bleed the theme's primary into the neutral gray ramp so
    surfaces / borders / text all carry the theme hue. Graduated so light steps
    (surfaces) get the most tint and dark steps (text) the least — protecting
    text contrast/readability."""
    if tint <= 0:
        return shades
    n = len(shades)
    out = []
    for i, hexv in enumerate(shades):
        factor = tint * (1 - (i / (n - 1)) * 0.72)   # 50 -> full tint, 900 -> ~28%
        out.append(_mix(hexv, primary_base, factor * 100))
    return out


# Ant's dark-palette recipe: mix a light shade into the dark background by %.
_DARK_MIX = [(7, 15), (6, 25), (5, 30), (5, 45), (5, 65), (5, 85), (4, 90), (3, 95), (2, 97), (1, 98)]
_DARK_BG = "141414"


def ant_generate_dark(base_hex):
    """Dark 10-shade ladder (darkest container..lightest); index 5 == dark base."""
    light = ant_generate(base_hex)
    return [_mix(_DARK_BG, light[idx - 1], amt) for idx, amt in _DARK_MIX]


def build_palette(primary_base, dark=False, tint=0.0):
    """`palette.<family>.<step>` -> hex. Primary (and `info`, for a full re-skin)
    ladders follow the active theme; the neutral gray ramp is tinted toward the
    primary by `tint`; the remaining semantic families use Ant's HSV generator.
    success / warning / error keep their fixed semantic hue regardless of theme."""
    gen = ant_generate_dark if dark else ant_generate
    table = {}
    for family, base in PALETTE_BASES.items():
        if family == "neutral":
            raw = NEUTRAL_DARK if dark else NEUTRAL_LIGHT
            # The UNTINTED ladder stays addressable: base-100 surfaces must remain
            # true neutral on a re-skin, or every card gets washed in the accent.
            for step, hexv in zip(STEPS, raw):
                table["neutral-raw/%d" % step] = hexv
            shades = _tint_neutral(raw, primary_base, tint)
        else:
            # `info`/`link`/`selected` track the theme accent on a full re-skin.
            seed = primary_base if family in ("primary", "info") else base
            shades = gen(seed)
        for step, hexv in zip(STEPS, shades):
            table["%s/%d" % (family, step)] = hexv
    return table


def json_name(cat, sub):
    return cat + "." + sub.replace("/", ".")


def case_name(sub):
    parts = sub.replace("/", " ").replace("-", " ").replace("_", " ").split()
    first = parts[0].lower()
    rest = "".join(p[:1].upper() + p[1:] for p in parts[1:])
    return first + rest


# ---- Build theme JSON (colors + radius + spacing + typography + shadows) ----
# Anchor surfaces (pure white / solid neutral fill) that also get a faint primary
# wash on a full re-skin, so cards aren't a theme-neutral island.
SURFACE_TINT_KEYS = {("background", "bg-tertiary")}


def build_theme(primary_base="056bfd", dark=False, tint=0.0,
                font="Montserrat", font_scale=1.0, radius_scale=1.0, spacing_scale=1.0, shadow_scale=1.0):
    palette = build_palette(primary_base, dark=dark, tint=tint)
    surface_tint = tint * 0.25   # a quarter of the neutral tint — barely-there on cards
    colors = []
    # Semantic alias tokens, derived from the (light/dark) palette.
    for cat, table in CATEGORIES:
        for sub, token in table.items():
            hexv = resolve_token(token, palette, dark)
            if (cat, sub) in SURFACE_TINT_KEYS and surface_tint > 0:
                hexv = _mix(hexv, primary_base, surface_tint * 100)
            colors.append({"name": json_name(cat, sub), "hex": hexv})
    # The primitive 50..900 ladders themselves. `neutral-raw` is resolution-only
    # plumbing (the untinted ramp bg-base reads from) — not a public ladder.
    for sub, hexv in palette.items():
        if sub.startswith("neutral-raw/"):
            continue
        colors.append({"name": json_name("palette", sub), "hex": hexv})
    radius = [{"name": k, "radius": round(v * radius_scale)} for k, v in RADIUS.items()]
    spacing = [{"name": k, "spacing": round(v * spacing_scale)} for k, v in SPACING.items()]
    typography = [{"name": n, "font": font, "size": round(sz * font_scale), "weight": w,
                   "lineHeight": round(lh * font_scale)} for n, (sz, w, lh) in BASE_TYPOGRAPHY.items()]
    shadows = [{"name": n, "layers": [{"color": c, "radius": round(r * shadow_scale), "x": x,
                                       "y": round(y * shadow_scale)} for (c, r, x, y) in layers]}
               for n, layers in BASE_SHADOWS.items()]
    return {"colors": colors, "radius": radius, "spacing": spacing, "typography": typography, "shadows": shadows}


# Each theme = a primary seed + full token-set variation (font / radius / spacing
# / shadow scale). The whole semantic layer derives from the primary palette, so
# one switch restyles everything; dark variants derive from the dark palette.
# `tint` = how strongly the primary bleeds into neutrals/surfaces (full re-skin).
DEFAULT = dict(primary_base="056bfd", tint=0.06)
OCEAN = dict(primary_base="0fb4ab", tint=0.13, font="SystemRounded", radius_scale=1.5, spacing_scale=1.15, shadow_scale=1.4)
SUNSET = dict(primary_base="ee9124", tint=0.11, font="SystemSerif", font_scale=1.05, radius_scale=0.5, spacing_scale=0.9, shadow_scale=0.6)

THEMES = {
    "defaultTheme": build_theme(**DEFAULT),
    "oceanTheme": build_theme(**OCEAN),
    "sunsetTheme": build_theme(**SUNSET),
    "defaultThemeDark": build_theme(dark=True, **DEFAULT),
    "oceanThemeDark": build_theme(dark=True, **OCEAN),
    "sunsetThemeDark": build_theme(dark=True, **SUNSET),
}
for name, data in THEMES.items():
    with open(os.path.join(RES, name + ".json"), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("wrote", name, "colors=%d" % len(data["colors"]))

# ---- Generate Swift color key enums ----
def emit_enum(swift_name, cat, table):
    lines = [f"    public enum {swift_name}: String, CaseIterable, Sendable {{"]
    for sub in table:
        lines.append(f'        case {case_name(sub)} = "{json_name(cat, sub)}"')
    lines.append("    }")
    return "\n".join(lines)

swift = ['//',
         '//  ColorTokens.generated.swift',
         '//  ThemeKit',
         '//  Created by İsa Mercan on 23.06.2026.',
         '//',
         '//  GENERATED from the Figma design system — do not edit by hand.',
         '//  Token names are semantic / brand-agnostic.',
         '//',
         '',
         'import SwiftUI',
         '',
         'extension Theme {',
         emit_enum("ForegroundColorKey", "foreground", FOREGROUND),
         '',
         emit_enum("BackgroundColorKey", "background", BACKGROUND),
         '',
         emit_enum("BorderColorKey", "border", BORDER),
         '',
         emit_enum("TextColorKey", "text", TEXT),
         '',
         emit_enum("PaletteColorKey", "palette",
                   {k: None for k in build_palette("056bfd") if not k.startswith("neutral-raw/")}),
         '}',
         '']
with open(os.path.join(GEN, "ColorTokens.generated.swift"), "w") as f:
    f.write("\n".join(swift))
print("wrote ColorTokens.generated.swift  (fg=%d bg=%d border=%d text=%d)" %
      (len(FOREGROUND), len(BACKGROUND), len(BORDER), len(TEXT)))
