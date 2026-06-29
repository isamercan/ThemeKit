#!/usr/bin/env python3
"""
Generate skills/themekit/references/components.md from the ThemeKit source.

A compact, always-accurate catalog for the Claude Code skill: every public
component grouped by Atom / Molecule / Organism, plus every chainable modifier.
Re-run with `make skill` (or `python3 tools/gen_skill.py`) so the reference can
never drift from the code.
"""
import re
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / "Sources/ThemeKit/Components"
OUT = ROOT / "skills/themekit/references/components.md"
THEMES_SRC = ROOT / "Sources/ThemeKit/Theme/ThemePresets.swift"
THEMES_OUT = ROOT / "skills/themekit/references/themes.md"
LLMS_OUT = ROOT / "llms.txt"
THEME_RE = re.compile(r'\.init\(\s*"(\w+)",\s*"([^"]+)"')
THEME_FULL_RE = re.compile(
    r'\.init\(\s*"(\w+)",\s*"([^"]+)",\s*primary:\s*"(\w+)",\s*secondary:\s*"(\w+)",'
    r'\s*accent:\s*"(\w+)",\s*base:\s*"(\w+)"'
)


def full_themes():
    src = THEMES_SRC.read_text(encoding="utf-8")
    return [
        {"id": m[0], "name": m[1], "primary": m[2], "secondary": m[3], "accent": m[4], "base": m[5]}
        for m in THEME_FULL_RE.findall(src)
    ]

RULES = [
    "Read the theme via `@Environment(\\.theme) private var theme`; inject `.environment(Theme.shared)` once at the root.",
    "Never hardcode a color — use `theme.text(.textPrimary)`, `theme.background(.bgWhite)`, or a `SemanticColor`.",
    "Put required content/bindings/actions in `init`; set variants, sizes, flags, colors and callbacks with chainable modifiers.",
    "Sizes use `.controlSize(_:)`; disabled state uses `.disabled(_:)`; accessibility id uses `.a11yID(_:)`.",
    "Recolor everything with `Theme.shared.applyGenerated(primaryHex:)` or a theme preset: `ThemePreset.named(\"dracula\")?.apply()`.",
]

TOKENS = {
    "text": ["textPrimary", "textSecondary", "textTertiary", "textDisabled", "textHero"],
    "background": ["bgWhite", "bgElevatorPrimary", "bgSecondary", "bgSecondaryLight", "bgHero", "bgTertiary"],
    "border": ["borderPrimary", "borderHero"],
    "foreground": ["fgHero", "fgSecondary"],
    "semanticColor": ["primary", "secondary", "accent", "neutral", "info", "success", "warning", "error"],
    "fillVariant": ["solid", "soft", "outline", "ghost"],
    "radiusRole": ["box", "field", "selector"],
    "spacing": ["xs", "sm", "md", "base", "lg", "xl"],
}

CATEGORIES = [("Atoms", "Atoms"), ("Molecules", "Molecules"), ("Organisms", "Organisms")]

# `public struct Name: View` / `public struct Name<...>: View`
STRUCT_RE = re.compile(r"^public struct (\w+)(?:<[^>]*>)?\s*:\s*View\b", re.M)
# self-returning chainable modifiers: `func name(params) -> Self`
MODIFIER_RE = re.compile(r"\bfunc (\w+)\s*\(([^;{]*?)\)\s*->\s*Self\b", re.S)
INIT_RE = re.compile(r"public init\(\s*(.*?)\)\s*\{", re.S)


def split_top(body: str):
    """Split a param list on top-level commas only (ignore < > ( ) [ ] nesting)."""
    out, depth, token = [], 0, ""
    for ch in body:
        if ch in "<([":
            depth += 1
        elif ch in ">)]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(token); token = ""
        else:
            token += ch
    out.append(token)
    return [p.strip() for p in out if p.strip()]


def param_labels(swift: str) -> str:
    m = INIT_RE.search(swift)
    if not m:
        return ""
    names = []
    for p in split_top(m.group(1)):
        head = p.split(":")[0].strip()
        parts = head.split()
        if not parts:
            continue
        names.append(parts[1] if parts[0] == "_" and len(parts) > 1 else parts[0] + ":")
    return ", ".join(names[:6]) + (" …" if len(names) > 6 else "")


def doc_above(lines, idx) -> str:
    """Contiguous `///` doc lines just above line `idx` (skips a blank/attr gap)."""
    doc, i = [], idx - 1
    while i >= 0:
        s = lines[i].strip()
        if s.startswith("///"):
            doc.append(s[3:].strip())
        elif s.startswith("@") or s.startswith("//") or s == "":
            if s == "" and doc:
                break
            i -= 1
            continue
        else:
            break
        i -= 1
    doc.reverse()
    text = " ".join(d for d in doc if d).strip()
    return text.split(". ")[0].rstrip(".") + ("." if text else "")  # first sentence


def parse_modifiers(swift, lines):
    found = {}
    for m in MODIFIER_RE.finditer(swift):
        name = m.group(1)
        if name in found:
            continue
        params = re.sub(r"\s+", " ", m.group(2)).strip()
        ln = swift.count("\n", 0, m.start())
        found[name] = {"name": name, "signature": f"{name}({params})", "doc": doc_above(lines, ln)}
    return found


def collect():
    out = {}
    all_modifiers = set()
    for label, folder in CATEGORIES:
        items = []
        base = COMPONENTS / folder
        for path in sorted(base.rglob("*.swift")):
            swift = path.read_text(encoding="utf-8")
            lines = swift.split("\n")
            structs = [(m.group(1), swift[:m.start()].count("\n")) for m in STRUCT_RE.finditer(swift)]
            if not structs:
                continue
            mods = parse_modifiers(swift, lines)
            primary_params = param_labels(swift)
            for i, (name, ln) in enumerate(structs):
                is_primary = i == 0
                all_modifiers.update(mods.keys())
                items.append({
                    "name": name,
                    "doc": doc_above(lines, ln),
                    "params": primary_params if is_primary else "",
                    "modifiers": list(mods.values()) if is_primary else [],
                })
        out[label] = items
    return out, sorted(all_modifiers)


def render(cats, modifiers):
    total = sum(len(v) for v in cats.values())
    lines = [
        "<!-- GENERATED by tools/gen_skill.py — do not edit by hand. Run `make skill`. -->",
        "# ThemeKit component reference",
        "",
        f"{total} public SwiftUI components. Every one reads `@Environment(\\.theme)` and "
        "resolves all colors from tokens — **never hardcode a color**. Init shows the "
        "*required/common* params; long-tail styling is set with the chainable modifiers "
        "listed at the bottom.",
        "",
    ]
    for label, _ in CATEGORIES:
        items = cats[label]
        lines.append(f"## {label} ({len(items)})")
        lines.append("")
        for c in items:
            sig = f"`{c['name']}({c['params']})`" if c["params"] else f"`{c['name']}`"
            doc = f" — {c['doc']}" if c["doc"] else ""
            extra = f" · modifiers: {', '.join('`.' + m['name'] + '()`' for m in c['modifiers'])}" if c["modifiers"] else ""
            lines.append(f"- {sig}{doc}{extra}")
        lines.append("")
    lines.append("## Chainable modifiers (all components)")
    lines.append("")
    lines.append("Set styling/variants/flags AFTER the init, SwiftUI-style:")
    lines.append("")
    lines.append(" ".join(f"`.{m}()`" for m in modifiers))
    lines.append("")
    lines.append("Plus the native cross-cuts every control honors: `.disabled(_:)`, "
                 "`.controlSize(_:)`, `.a11yID(_:)`.")
    lines.append("")
    return "\n".join(lines)


def render_themes(themes):
    lines = [
        "<!-- GENERATED by tools/gen_skill.py — do not edit by hand. Run `make skill`. -->",
        "# ThemeKit theme presets",
        "",
        f"{len(themes)} theme presets (color sets inspired by daisyUI). Apply one live, or show them in a "
        "`ThemePicker` grid.",
        "",
        "```swift",
        'ThemePreset.named("dracula")?.apply()          // recolor Theme.shared',
        'Theme.shared.apply(ThemePreset.named("nord")!.config)',
        "",
        "@State private var active: String? = \"cupcake\"",
        "ThemePicker(selection: $active)               // grid of all themes",
        "```",
        "",
        "## Theme ids",
        "",
    ]
    lines += [f"- `{tid}` ({name})" for tid, name in themes]
    lines.append("")
    return "\n".join(lines), len(themes)


def render_llms(cats, modifiers, themes):
    total = sum(len(v) for v in cats.values())
    lines = [
        "# ThemeKit",
        "",
        f"> A token-driven, brand-neutral SwiftUI design system — {total} components, "
        f"runtime theming, and the {len(themes)} theme presets. Every color / radius / spacing / "
        "type style is a design token resolved at runtime from the active `Theme`; "
        "components never hardcode a color.",
        "",
        "Rules for generating ThemeKit code:",
        "- Read the theme via `@Environment(\\.theme) private var theme`; inject "
        "`.environment(Theme.shared)` once at the root. Never hardcode a color — use "
        "`theme.text(.textPrimary)`, `theme.background(.bgWhite)`, or a `SemanticColor`.",
        "- Put required content/bindings/actions in `init`; set variants, sizes, flags, "
        "colors and callbacks with chainable modifiers.",
        "- Sizes use `.controlSize(_:)`; disabled state uses `.disabled(_:)`.",
        "- Recolor everything with `Theme.shared.applyGenerated(primaryHex:)` or a "
        "daisyUI theme: `ThemePreset.named(\"dracula\")?.apply()`.",
        "",
        "## Docs",
        "- [SKILL.md](skills/themekit/SKILL.md): idioms, setup, patterns, anti-patterns",
        "- [Components reference](skills/themekit/references/components.md): every component's init + modifiers",
        "- [Themes reference](skills/themekit/references/themes.md): the theme-preset catalog",
        "",
    ]
    for label, _ in CATEGORIES:
        names = ", ".join(f"`{c['name']}`" for c in cats[label])
        lines.append(f"## {label}")
        lines.append("")
        lines.append(names)
        lines.append("")
    lines.append("## Chainable modifiers")
    lines.append("")
    lines.append(" ".join(f"`.{m}()`" for m in modifiers))
    lines.append("")
    lines.append("## Theme presets")
    lines.append("")
    lines.append(", ".join(f"`{tid}`" for tid, _ in themes))
    lines.append("")
    return "\n".join(lines)



def main():
    cats, modifiers = collect()
    themes = THEME_RE.findall(THEMES_SRC.read_text(encoding="utf-8"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(cats, modifiers), encoding="utf-8")
    themes_md, n_themes = render_themes(themes)
    THEMES_OUT.write_text(themes_md, encoding="utf-8")
    LLMS_OUT.write_text(render_llms(cats, modifiers, themes), encoding="utf-8")
    total = sum(len(v) for v in cats.values())
    print(f"Wrote {OUT.relative_to(ROOT)} — {total} components, {len(modifiers)} modifiers")
    print(f"Wrote {THEMES_OUT.relative_to(ROOT)} — {n_themes} theme presets")
    print(f"Wrote {LLMS_OUT.relative_to(ROOT)} — llms.txt index")


if __name__ == "__main__":
    main()
