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
# Component roots scanned for the reference/llms output. The neutral catalog plus
# any domain editions (e.g. ThemeKitTravel) that also ship atomic-layer components,
# so edition components are counted alongside the neutral ones.
COMPONENT_ROOTS = [COMPONENTS, ROOT / "Sources/ThemeKitTravel/Components"]
OUT = ROOT / "skills/themekit/references/components.md"
# ThemePresets moved into the ThemeKitCore target during the Core split; fall back
# to the legacy path so this stays runnable on older checkouts.
THEMES_SRC = ROOT / "Sources/ThemeKitCore/Theme/ThemePresets.swift"
if not THEMES_SRC.exists():
    THEMES_SRC = ROOT / "Sources/ThemeKit/Theme/ThemePresets.swift"
THEMES_OUT = ROOT / "skills/themekit/references/themes.md"
LLMS_OUT = ROOT / "llms.txt"
LLMS_COMPONENTS_OUT = ROOT / "llms-components.txt"
# Curated companions (hand-maintained architecture + recipe prose); copied through
# to the docs site but NOT regenerated here.
CURATED_LLMS = [ROOT / "llms-full.txt", ROOT / "llms-patterns.txt"]
WEBSITE_PUBLIC = ROOT / "website/public"
# Optional richer per-component data (full param types + a usage snippet) from the
# MCP dataset; used only to enrich llms-components.txt when a component is present.
THEMEKIT_JSON = ROOT / "mcp/data/themekit.json"
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
    "Sizes use `.controlSize(_:)`; disabled state uses `.disabled(_:)` (both native/universal). Many components also expose `.a11yID(_:)` (see each entry) — it is not global, so use SwiftUI's `.accessibilityIdentifier(_:)` where a component lacks it.",
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
# self-returning chainable modifiers: `func name(params) -> Self`.
# Capture any access keyword before `func` so private/internal helpers (e.g. the
# copy-on-write `copy(_:)`) can be filtered out — only the public surface is documented.
MODIFIER_RE = re.compile(r"\b(private|fileprivate|internal|public)?\s*func (\w+)\s*\(([^;{]*?)\)\s*->\s*Self\b", re.S)
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


def param_labels(swift: str, start: int = 0) -> str:
    # Extract the init that belongs to THIS component struct, not the first init in
    # the file: search from the struct's declaration (`start`) up to the next
    # top-level `public struct` (a helper type). Without this, a file that declares a
    # non-View helper first (e.g. `CodeLine` before `CodeBlock`, `TransferItem` before
    # `Transfer`) would surface the helper's init and emit non-compiling call sites.
    nxt = swift.find("\npublic struct ", start + 1)
    region = swift[start:] if nxt == -1 else swift[start:nxt]
    m = INIT_RE.search(region)
    if not m:
        return ""
    names = []
    for p in split_top(m.group(1)):
        head = p.split(":")[0].strip()
        parts = head.split()
        # Drop leading parameter attributes (e.g. `@ViewBuilder content:` → `content:`)
        # so the label, not the attribute, is shown.
        while parts and parts[0].startswith("@"):
            parts.pop(0)
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
        access = m.group(1)
        # Skip non-public helpers (a `public extension`'s members are public when
        # unannotated; an explicit `private`/`fileprivate`/`internal` is not API).
        if access in ("private", "fileprivate", "internal"):
            continue
        name = m.group(2)
        if name in found:
            continue
        params = re.sub(r"\s+", " ", m.group(3)).strip()
        ln = swift.count("\n", 0, m.start())
        found[name] = {"name": name, "signature": f"{name}({params})", "doc": doc_above(lines, ln)}
    return found


def collect():
    out = {}
    all_modifiers = set()
    for label, folder in CATEGORIES:
        items = []
        bases = [root / folder for root in COMPONENT_ROOTS if (root / folder).is_dir()]
        for path in sorted(p for base in bases for p in base.rglob("*.swift")):
            swift = path.read_text(encoding="utf-8")
            lines = swift.split("\n")
            # (name, char-offset) — the offset scopes init extraction to the component.
            structs = [(m.group(1), m.start()) for m in STRUCT_RE.finditer(swift)]
            if not structs:
                continue
            mods = parse_modifiers(swift, lines)
            for i, (name, off) in enumerate(structs):
                is_primary = i == 0
                ln = swift.count("\n", 0, off)
                all_modifiers.update(mods.keys())
                items.append({
                    "name": name,
                    "doc": doc_above(lines, ln),
                    "params": param_labels(swift, off) if is_primary else "",
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
                 "`.controlSize(_:)`. Many components also add `.a11yID(_:)` (listed per entry); "
                 "it is not a global modifier — use SwiftUI's `.accessibilityIdentifier(_:)` otherwise.")
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
    """The enriched HeroUI-style quick-reference index. Inventory (component names,
    modifiers, preset ids, counts) is derived from source; the architectural prose
    (rules, tokens, packages, integration) is a stable constant."""
    n_atoms, n_mol, n_org = (len(cats["Atoms"]), len(cats["Molecules"]), len(cats["Organisms"]))
    total = n_atoms + n_mol + n_org
    lines = [
        "# ThemeKit",
        "",
        f"> A token-driven, **brand-neutral** SwiftUI design system — **{total} components** "
        f"({n_atoms} atoms · {n_mol} molecules · {n_org} organisms), **{len(themes)} theme presets**, "
        "**217 design tokens**, runtime theming, and an AI-native toolchain (MCP server + agent "
        "skill + Figma round-trip). Every color, radius, spacing, type style and shadow is a design "
        "token resolved at runtime from the active `Theme`; **components never hardcode a color**, so "
        "the whole UI re-skins from a single accent color. Swift 6.2 · iOS 17+ / macOS 14+ · zero "
        "core dependencies.",
        "",
        "This is the quick-reference index. Deeper files:",
        "- **llms-full.txt** — architecture, token deep-dive, code-generation rules, patterns, integration.",
        "- **llms-components.txt** — every component's init + modifiers + usage snippet.",
        "- **llms-patterns.txt** — recipes (custom themes, per-subtree theming, custom styles, forms…).",
        "",
        "## Philosophy",
        "",
        "1. **Token-driven.** No literal colors/radii/spacings in UI — only tokens from the active `Theme`.",
        "2. **Brand-neutral.** One accent hex generates a full palette on-device (`ThemeGenerator`).",
        "3. **Composable & chainable.** Required content/bindings in `init`; everything else a modifier.",
        "4. **AI-native.** The same data drives an MCP server (22 tools), an agent skill, and Figma round-trip.",
        "",
        "## Rules for generating ThemeKit code (critical)",
        "",
        "1. **Never hardcode a color.** No `.foregroundStyle(.blue)` / `Color(hex:)`. Use "
        "`theme.text(.textPrimary)`, `theme.background(.bgWhite)`, or a `SemanticColor`.",
        "2. **Read the theme from the environment:** `@Environment(\\.theme) private var theme` "
        "(defaults to `Theme.shared`). **Inject once at the root:** `.environment(Theme.shared)`.",
        "3. **Required content/bindings/actions in `init`;** variants/sizes/flags/colors/callbacks are "
        "**chainable modifiers** — `Badge(\"New\").badgeStyle(.info).badgeShape(.rounded)`.",
        "4. **Sizes** use `.controlSize(_:)`; **disabled** uses `.disabled(_:)` (native, universal). "
        "Never `size:` / `isEnabled:` init args. Many components also expose `.a11yID(_:)` — check the "
        "component's modifier list; where absent use SwiftUI's `.accessibilityIdentifier(_:)`.",
        "5. **No hardcoded radius/spacing.** Use `Theme.RadiusRole.box.value` / `Theme.SpacingKey.md.value`.",
        "6. **Recolor** with `Theme.shared.applyGenerated(primaryHex:)` or `ThemePreset.named(\"dracula\")?"
        ".apply()`. Scope to one subtree with `.theme(customTheme)`.",
        "7. **Don't re-implement** a Card / Sheet / Toast / field — use the existing component.",
        "",
        "## Token system (resolved from the active `Theme`)",
        "",
        "- **Text** `theme.text(_:)` — `.textPrimary .textSecondary .textTertiary .textDisabled "
        ".textHero .textPurple .textSecondaryInverse`",
        "- **Surfaces** `theme.background(_:)` — `.bgWhite` (default surface) `.bgHero "
        ".bgElevatorPrimary .bgSecondary .bgTertiary` + system/badge tints (24 keys)",
        "- **Borders** `theme.border(_:)` (12 keys) · **Foreground** `theme.foreground(_:)` (10 keys)",
        "- **Semantic colors** `SemanticColor` — `.primary .secondary .accent .neutral .info .success "
        ".warning .error .turquoise .orange .purple .pink`; 50→900 shade ladder; pair with "
        "`FillVariant` (`.solid .soft .outline .ghost`).",
        "- **Radius** — role: `Theme.RadiusRole.box|field|selector`; size: "
        "`Theme.RadiusKey.none|xs|sm|md|base|lg|xl|xl4` (`rd-xs`…`rd-4xl`).",
        "- **Spacing** `Theme.SpacingKey.none|xs|sm|md|base|lg|xl|xl4` (`sp-xs`…`sp-4xl`).",
        "- **Typography** `.textStyle(_:)` — 34 `TextStyle`s (Montserrat): Display, Heading (2xl→3xs), "
        "Label, Body, Overline, Link.",
        "- **Shadows** `ShadowStyle.elevated|.tabBar|.soft`.",
        "",
        "## Packages (SPM products)",
        "",
        "- **ThemeKit** — full catalog (re-exports the core). `import ThemeKit`.",
        "- **ThemeKitCore** — token engine only (tokens + `@Environment(\\.theme)` + presets + "
        "generator), zero components, zero third-party deps.",
        "- **ThemeKitLottie** — optional Lottie animations (behind the `Lottie` package trait).",
        "- **ThemeKitCalendar** — optional token-bound calendar (behind the `Calendar` trait, iOS-only).",
        "",
        "Default traits are **empty**, so a plain package reference resolves **zero** dependencies.",
        "",
    ]
    for label, _ in CATEGORIES:
        names = ", ".join(f"`{c['name']}`" for c in cats[label])
        lines.append(f"## {label} ({len(cats[label])})")
        lines.append("")
        lines.append(names)
        lines.append("")
    lines += [
        "## Style protocols (flexibility architecture)",
        "",
        "Six component families are style-driven (`ButtonStyle`-shaped — a `Configuration` + `makeBody`):",
        "- `CardStyle` → `.cardStyle(_:)` — cards. Built-ins `.default`, `.outlined`.",
        "- `FieldStyle` → `.fieldStyle(_:)` — text fields. Built-ins `.default`, `.muted`, `.underlined`.",
        "- `ChipStyle` → chips. Built-ins `.tonal`, `.solid`.",
        "- `BarStyle` → `.barStyle(_:)` — bottom/booking bars. Built-ins `.default`, `.floating`.",
        "- `MeterStyle` → `.meterStyle(_:)` — progress/meters. Built-ins `.linear`, `.striped`, `.radial`.",
        "- `ToastStyle` → `.toastStyle(_:)` — toasts. Built-ins `.default`, `.capsule`.",
        "",
        "## Chainable modifiers",
        "",
        " ".join(f"`.{m}()`" for m in modifiers),
        "",
        "## Theme presets",
        "",
        ", ".join(f"`{tid}`" for tid, _ in themes),
        "",
        "```swift",
        'ThemePreset.named("dracula")?.apply()            // recolor Theme.shared live',
        'Theme.shared.applyGenerated(primaryHex: "7C3AED") // generate a full palette from one accent',
        "ThemePicker(selection: $activeThemeID)            // tappable grid of all presets",
        "```",
        "",
        "## AI-native toolchain",
        "",
        "- **MCP server** (`@isamercan/themekit-mcp`, 22 tools) — `list_components`, `get_component_api`, "
        "`get_design_tokens`, `get_usage_snippet`, `search_components`, `list_themes`, `generate_theme`, "
        "`lint_snippet`, `validate_code`, `a11y_audit`, `scaffold_screen`, `compose_screen`, "
        "`design_via_figma_mcp`, `export_figma_variables`, `import_figma_variables`, … (full list in llms-full.txt).",
        "- **Agent skill** — `skills/themekit/SKILL.md` (idioms, setup, anti-patterns) + references.",
        "- **Figma round-trip** — `export_figma_variables` / `import_figma_variables` and `design_via_figma_mcp`.",
        "",
        "## Localization & accessibility",
        "",
        "- **Strings:** bundled String Catalog, English default (`en`); every user-facing string is also "
        "overridable via an init/modifier parameter. Add your own localizations in-app.",
        "- **Accessibility:** many components expose `.a11yID(_:)` / `.a11yLabel(_:)` (not global — use "
        "SwiftUI's `.accessibilityIdentifier(_:)` where a component lacks it); 44 pt touch targets and "
        "RTL-directional mirroring are built in.",
        "",
        "## Links",
        "",
        "- Docs — https://isamercan.github.io/ThemeKit/",
        "- API reference (DocC) — https://isamercan.github.io/ThemeKit/api/documentation/themekit",
        "- GitHub — https://github.com/isamercan/ThemeKit · Wiki — https://github.com/isamercan/ThemeKit/wiki",
        "- MCP (npm) — https://www.npmjs.com/package/@isamercan/themekit-mcp",
        "- Skill — [skills/themekit/SKILL.md](skills/themekit/SKILL.md) · Components ref — "
        "[skills/themekit/references/components.md](skills/themekit/references/components.md)",
        "",
    ]
    return "\n".join(lines)


def load_component_enrichment():
    """name → {init, usage} from the MCP dataset, if present (optional richer data)."""
    if not THEMEKIT_JSON.exists():
        return {}
    try:
        data = json.loads(THEMEKIT_JSON.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}
    return {c["name"]: c for c in data.get("components", [])}


def render_llms_components(cats, enrich):
    """Full per-component reference (all components, from source), enriched with the
    MCP dataset's richer init signature + usage snippet where a component is present."""
    n_atoms, n_mol, n_org = (len(cats["Atoms"]), len(cats["Molecules"]), len(cats["Organisms"]))
    total = n_atoms + n_mol + n_org
    blurb = {
        "Atoms": "Smallest building blocks — a single visual/interactive primitive.",
        "Molecules": "Compositions of atoms — inputs, buttons, selectors, small layouts.",
        "Organisms": "Full sections — cards, tables, navigation, banners, domain surfaces.",
    }
    style_rows = [
        ("CardStyle", "`.cardStyle(_:)`", "cards (Card, RadioCard, CheckboxCard, MenuCard…)", "`.default`, `.outlined`"),
        ("FieldStyle", "`.fieldStyle(_:)`", "text fields (TextInput, DateField, ColorField, OTPInput…)", "`.default`, `.muted`, `.underlined`"),
        ("ChipStyle", "tonal/solid chip styles", "Chip", "`.tonal`, `.solid`"),
        ("BarStyle", "`.barStyle(_:)`", "bottom/booking bars", "`.default`, `.floating`"),
        ("MeterStyle", "`.meterStyle(_:)`", "progress/meters (ProgressBar, RadialProgress, GaugeView)", "`.linear`, `.striped`, `.radial`"),
        ("ToastStyle", "`.toastStyle(_:)`", "toasts (AlertToast)", "`.default`, `.capsule`"),
    ]
    lines = [
        "# ThemeKit — Component Reference",
        "",
        "<!-- GENERATED by tools/gen_skill.py — do not edit by hand. Run `make skill`. -->",
        "",
        "> Per-component API for the ThemeKit SwiftUI design system: init signature, chainable",
        "> modifiers, and (where available) a usage snippet. Companion files: **llms.txt** (index),",
        "> **llms-full.txt** (architecture + tokens), **llms-patterns.txt** (recipes).",
        "",
        "## How to read this file",
        "",
        "- **Init** — required content/bindings/actions only. Everything else is a modifier.",
        "- **Modifiers** — chainable, copy-on-write; order does not matter.",
        "- **Native modifiers apply too** — sizing is `.controlSize(_:)`, disabling is `.disabled(_:)`.",
        "- **Accessibility ids** — many components expose `.a11yID(_:)` (shown in their modifier list);",
        "  it is not a global modifier, so use SwiftUI's `.accessibilityIdentifier(_:)` where absent.",
        "",
        "## Golden rule for every snippet below",
        "",
        "Never hardcode a color, radius, or spacing. Read the theme from the environment",
        "(`@Environment(\\.theme) private var theme`) and pull tokens — `theme.text(.textPrimary)`,",
        "`theme.background(.bgWhite)`, `Theme.SpacingKey.md.value`, `Theme.RadiusRole.box.value`.",
        "",
        "## Style protocols (flexibility architecture)",
        "",
        "| Protocol | Apply with | Covers | Built-in styles |",
        "| --- | --- | --- | --- |",
    ]
    for name, apply, covers, builtins in style_rows:
        lines.append(f"| `{name}` | {apply} | {covers} | {builtins} |")
    lines += [
        "",
        "Each has a `Configuration` struct + a `makeBody(configuration:)` requirement — like SwiftUI's",
        "`ButtonStyle`. Full recipe in **llms-patterns.txt**.",
        "",
        f"This reference documents all **{total}** components ({n_atoms} atoms · {n_mol} molecules · "
        f"{n_org} organisms). Where a component appears in the MCP dataset, its full init signature and a",
        "usage snippet are shown; otherwise the init's required/common parameter labels are listed.",
        "",
    ]
    for label, _ in CATEGORIES:
        lines += ["---", "", f"# {label} ({len(cats[label])})", "", f"_{blurb[label]}_", ""]
        for c in cats[label]:
            e = enrich.get(c["name"])
            lines.append(f"## {c['name']}")
            lines.append("")
            doc = ((e.get("doc") if e else "") or c.get("doc") or "").strip()
            # Drop uninformative stubs like "Atom." / "Organism." — API is the value here.
            if re.fullmatch(r"(Atom|Molecule|Organism)\.?", doc):
                doc = ""
            if doc:
                lines.append(doc)
                lines.append("")
            lines.append("```swift")
            if e and e.get("init"):
                lines.append(e["init"])
            elif c["params"]:
                lines.append(f"{c['name']}({c['params']})")
            else:
                lines.append(f"{c['name']}()")
            if e and e.get("usage") and e["usage"] != (e.get("init") or ""):
                lines.append("")
                lines.append(f"// usage: {e['usage']}")
            lines.append("```")
            lines.append("")
            if c["modifiers"]:
                lines.append("**Modifiers**")
                lines.append("")
                for m in c["modifiers"]:
                    d = f" — {m['doc']}" if m.get("doc") else ""
                    lines.append(f"- `.{m['name']}`{d}")
                lines.append("")
    return "\n".join(lines)



def main():
    cats, modifiers = collect()
    themes = THEME_RE.findall(THEMES_SRC.read_text(encoding="utf-8"))
    enrich = load_component_enrichment()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(cats, modifiers), encoding="utf-8")
    themes_md, n_themes = render_themes(themes)
    THEMES_OUT.write_text(themes_md, encoding="utf-8")
    LLMS_OUT.write_text(render_llms(cats, modifiers, themes), encoding="utf-8")
    LLMS_COMPONENTS_OUT.write_text(render_llms_components(cats, enrich), encoding="utf-8")
    total = sum(len(v) for v in cats.values())
    print(f"Wrote {OUT.relative_to(ROOT)} — {total} components, {len(modifiers)} modifiers")
    print(f"Wrote {THEMES_OUT.relative_to(ROOT)} — {n_themes} theme presets")
    print(f"Wrote {LLMS_OUT.relative_to(ROOT)} — llms.txt index")
    print(f"Wrote {LLMS_COMPONENTS_OUT.relative_to(ROOT)} — {total} components"
          f" ({len(enrich)} enriched from the MCP dataset)")

    # Publish the full llms.* set (2 generated here + 2 curated companions) to the docs
    # site so they are fetchable over HTTP, e.g. https://isamercan.github.io/ThemeKit/llms.txt
    if WEBSITE_PUBLIC.is_dir():
        published = [LLMS_OUT, LLMS_COMPONENTS_OUT] + [p for p in CURATED_LLMS if p.exists()]
        for src in published:
            (WEBSITE_PUBLIC / src.name).write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Published {len(published)} llms.* files to {WEBSITE_PUBLIC.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()
