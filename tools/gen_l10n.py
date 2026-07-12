#!/usr/bin/env python3
"""
Generate ThemeKit's localization catalogs + the consumer template from source
(ADR-0003 phase 0). Re-run with `make l10n`; CI asserts a re-run is a no-op.

WHAT IT EXTRACTS
  Every key passed to the two localization bridges —
      String(themeKit: "…")         → resolves against ThemeKitCore's bundle
      String(themeKitTravel: "…")   → resolves against ThemeKitTravel's bundle
  — across ALL of Sources/, with a real scanner (comment-aware, string-literal-
  aware): plain literals, interpolated literals, BOTH branches of ternaries
  (`direction < 0 ? "Previous month" : "Next month"`), and calls nested inside
  another call's interpolation (`"… \\(x ?? String(themeKit: "unassigned"))"`).

  Keys are grouped BY BRIDGE, not by file location: a `String(themeKit:)` call
  in a ThemeKitTravel file still resolves against ThemeKitCore's bundle at
  runtime, so its key must live in the CORE catalog or a consumer translation
  of it would be silently missed. (This is the invariant the CI gate proves:
  generator key == resolver runtime key == catalog key, for every call site.)

SPECIFIER STRATEGY (the invariant's crux — decided with the code in front of us)
  Every interpolation `\\(expr)` canonicalizes to `%@`, and the runtime capture
  type (`ThemeKitLocalizationValue`) stringifies every interpolated value and
  emits `%@` for it — the two mappings are identical BY CONSTRUCTION, with no
  type inference anywhere, so the invariant is trivially provable (and is
  proven for every interpolated shape by the generated
  `L10nKeyInvariantTests.swift`).

  Type-specific specifiers (`\\(count)` → %lld) were rejected: proving them
  would require Swift type-checking (lexically, `\\(score)` at Rating.swift is
  a String while `\\(count)` at InstallmentSelector.swift is an Int — they are
  indistinguishable to a scanner), and one wrong guess silently orphans a
  consumer translation. The cost of the uniform mapping is that number-driven
  `.stringsdict` plural variation cannot apply to interpolated keys — which
  ThemeKit does not use anyway (it ships separate keys: "room"/"rooms",
  "1 seat"/"%@ seats"); translators phrase interpolated keys naturally instead.

  In a canonical key, literal `%` characters are escaped to `%%` IF AND ONLY IF
  the key has interpolations (only then does the resolved value pass through
  `String(format:)`). Plain keys are never formatted and stay verbatim.
  `ThemeKitLocalizationValue` implements the same rule.

WHAT IT WRITES (all four are checked by `--check`)
  Sources/ThemeKitCore/Resources/Localizable.xcstrings     (themeKit keys)
  Sources/ThemeKitTravel/Resources/Localizable.xcstrings   (themeKitTravel keys)
  Templates/ThemeKit.xcstrings                             (union — the file a
                                                            consumer copies into
                                                            their app target)
  Tests/ThemeKitTests/Generated/L10nKeyInvariantTests.swift (one assertion per
                                                            interpolated key)

  Catalog entries carry `"extractionState": "manual"` so Xcode's catalog sync
  never fights this generator, and keep any human/legacy comment found in the
  previous catalog (typed legacy keys like "%@ out of %lld" are canonicalized
  to "%@ out of %@" for comment migration).

  `--check`: regenerate in memory, diff against disk, verify every extracted
  key exists in its on-disk catalog; non-zero exit on any drift. This is the
  "no missing key-value" guarantee.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN_ROOT = ROOT / "Sources"

# bridge label → (call-site regex, catalog path)
BRIDGES = {
    "themeKit": ROOT / "Sources/ThemeKitCore/Resources/Localizable.xcstrings",
    "themeKitTravel": ROOT / "Sources/ThemeKitTravel/Resources/Localizable.xcstrings",
}
CALL_RE = re.compile(r"String\(\s*(themeKitTravel|themeKit)\s*:")
TEMPLATE_OUT = ROOT / "Templates/ThemeKit.xcstrings"
TEST_OUT = ROOT / "Tests/ThemeKitTests/Generated/L10nKeyInvariantTests.swift"

SIMPLE_ESC = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "\\": "\\", '"': '"', "'": "'"}
# Legacy typed specifiers → canonical %@ (for migrating comments off old keys).
LEGACY_SPEC_RE = re.compile(r"%(\d+\$)?(?:lld|llu|lu|ld|lf|d|u|f|i|@)")


# ── comment stripping (string-literal- and interpolation-aware) ──────────────

def strip_comments(text: str) -> str:
    """Blank out // and /* */ comments (space-preserving), leaving string
    literals — including comments nested inside `\\(…)` interpolations —
    intact. Raw `#"…"#` strings are skipped verbatim."""
    out = list(text)
    i, n = 0, len(text)
    # stack frames: ("code", paren_depth_when_entered_via_interpolation) | ("str",) | ("mlstr",)
    stack = [("code", None)]
    while i < n:
        mode = stack[-1][0]
        c = text[i]
        if mode == "code":
            if c == "/" and i + 1 < n and text[i + 1] == "/":
                j = text.find("\n", i)
                j = n if j == -1 else j
                for k in range(i, j):
                    out[k] = " "
                i = j
                continue
            if c == "/" and i + 1 < n and text[i + 1] == "*":
                depth, j = 1, i + 2
                while j < n and depth:
                    if text.startswith("/*", j):
                        depth += 1
                        j += 2
                    elif text.startswith("*/", j):
                        depth -= 1
                        j += 2
                    else:
                        j += 1
                for k in range(i, j):
                    if out[k] != "\n":
                        out[k] = " "
                i = j
                continue
            if c == "#" and i + 1 < n and text[i + 1] == '"':
                j = text.find('"#', i + 2)
                i = (j + 2) if j != -1 else n
                continue
            if text.startswith('"""', i):
                stack.append(("mlstr", None))
                i += 3
                continue
            if c == '"':
                stack.append(("str", None))
                i += 1
                continue
            if stack[-1][1] is not None:  # inside an interpolation
                if c == "(":
                    stack[-1] = ("code", stack[-1][1] + 1)
                elif c == ")":
                    depth = stack[-1][1] - 1
                    if depth == 0:
                        stack.pop()  # back to the enclosing string
                    else:
                        stack[-1] = ("code", depth)
            i += 1
            continue
        if mode == "str":
            if c == "\\":
                if i + 1 < n and text[i + 1] == "(":
                    stack.append(("code", 1))
                    i += 2
                    continue
                i += 2
                continue
            if c == '"':
                stack.pop()
            i += 1
            continue
        if mode == "mlstr":
            if c == "\\" and i + 1 < n and text[i + 1] == "(":
                stack.append(("code", 1))
                i += 2
                continue
            if c == "\\":
                i += 2
                continue
            if text.startswith('"""', i):
                stack.pop()
                i += 3
                continue
            i += 1
            continue
    return "".join(out)


# ── literal / argument parsing ────────────────────────────────────────────────

def parse_string_literal(text: str, i: int):
    """text[i] == '"'. → (tokens, end). tokens: ("lit", decoded) | ("interp", raw expr)."""
    i += 1
    tokens, buf = [], []
    while i < len(text):
        c = text[i]
        if c == '"':
            if buf:
                tokens.append(("lit", "".join(buf)))
            return tokens, i + 1
        if c == "\\":
            nxt = text[i + 1]
            if nxt == "(":
                if buf:
                    tokens.append(("lit", "".join(buf)))
                    buf = []
                depth, j, expr = 1, i + 2, []
                while depth:
                    ch = text[j]
                    if ch == '"':
                        _, j2 = parse_string_literal(text, j)
                        expr.append(text[j:j2])
                        j = j2
                        continue
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                        if depth == 0:
                            j += 1
                            break
                    expr.append(ch)
                    j += 1
                tokens.append(("interp", "".join(expr)))
                i = j
                continue
            if nxt == "u":
                m = re.match(r"u\{([0-9A-Fa-f]+)\}", text[i + 1:])
                if m:
                    buf.append(chr(int(m.group(1), 16)))
                    i += 1 + m.end()
                    continue
            buf.append(SIMPLE_ESC.get(nxt, nxt))
            i += 2
            continue
        buf.append(c)
        i += 1
    raise ValueError("unterminated string literal")


def extract_argument(text: str, start: int):
    """start = just past 'String(themeKit…:'. → (argtext, end) up to the matching ')'."""
    depth, i = 1, start
    while depth:
        c = text[i]
        if c == '"':
            _, i = parse_string_literal(text, i)
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return text[start:i], i


def scan(text: str, rel: str, sites: list, problems: list):
    """Collect every bridge call in (already de-commented) `text`, recursing
    into interpolation expressions for nested calls."""
    for m in CALL_RE.finditer(text):
        bridge = m.group(1)
        line = text.count("\n", 0, m.start()) + 1
        arg, _ = extract_argument(text, m.end())
        literals, i, outside = [], 0, []
        while i < len(arg):
            if arg[i] == '"':
                toks, i = parse_string_literal(arg, i)
                literals.append(toks)
            else:
                if not arg[i].isspace():
                    outside.append(arg[i])
                i += 1
        outside = "".join(outside)
        if not literals:
            problems.append(f"{rel}:{line}: no string literal in String({bridge}:) — key not extractable")
            continue
        if len(literals) > 1 and not ("?" in outside and ":" in outside):
            problems.append(f"{rel}:{line}: multiple literals without a ternary shape")
        for toks in literals:
            sites.append({"bridge": bridge, "file": rel, "line": line, "tokens": toks})
            for kind, val in toks:  # nested calls inside interpolations
                if kind == "interp" and "String(" in val:
                    scan(val, f"{rel}:{line}(nested)", sites, problems)


def canonical_key(tokens) -> str:
    has_interp = any(k == "interp" for k, _ in tokens)
    parts = []
    for kind, val in tokens:
        if kind == "lit":
            parts.append(val.replace("%", "%%") if has_interp else val)
        else:
            parts.append("%@")
    return "".join(parts)


# ── catalog / template emission ───────────────────────────────────────────────

def load_comments(catalog_path: pathlib.Path) -> dict:
    """key (canonicalized) → comment, from the existing catalog if readable."""
    try:
        old = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    comments = {}
    for key, entry in old.get("strings", {}).items():
        comment = entry.get("comment")
        if not comment:
            continue
        comments.setdefault(key, comment)
        # migrate comments stranded on legacy typed keys ("%@ out of %lld")
        comments.setdefault(LEGACY_SPEC_RE.sub("%@", key), comment)
    return comments


def render_catalog(keys, comments) -> str:
    strings = {}
    for key in sorted(keys):
        # extractionState "manual": Xcode's catalog sync never touches
        # generator-owned entries. generatesSymbol false: ThemeKit strings
        # resolve through String(themeKit:), never through Xcode's generated
        # string symbols — and symbol generation would collide on the many
        # case-/punctuation-differing keys ("Adults"/"adults", "Loading"/
        # "Loading…", "Total: %@"/"%@ total"), breaking every Xcode build.
        entry = {"extractionState": "manual", "generatesSymbol": False}
        if key in comments:
            entry["comment"] = comments[key]
        strings[key] = entry
    doc = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    return json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


# ── generated invariant test ──────────────────────────────────────────────────

def swift_escape(s: str) -> str:
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\0":
            out.append("\\0")
        else:
            out.append(ch)
    return "".join(out)


def render_invariant_test(interp_sites) -> str:
    """One assertion per DISTINCT interpolated key: rebuild the call-site
    literal with a String dummy per interpolation and assert the runtime
    capture (`ThemeKitLocalizationValue.key`) equals the generator's key.
    Dummy args are Strings; type-independence of the mapping (every type →
    `%@`) is covered by the hand-written `L10nResolverTests`."""
    by_key = {}
    for s in interp_sites:
        by_key.setdefault(canonical_key(s["tokens"]), s)
    rows = []
    for key in sorted(by_key):
        toks = by_key[key]["tokens"]
        literal = "".join(
            swift_escape(v) if k == "lit" else "\\(d)" for k, v in toks
        )
        nargs = sum(1 for k, _ in toks if k == "interp")
        rows.append((key, literal, nargs, f'{by_key[key]["file"]}:{by_key[key]["line"]}'))

    lines = [
        "//",
        "//  L10nKeyInvariantTests.swift",
        "//  GENERATED by tools/gen_l10n.py — do not edit by hand. Run `make l10n`.",
        "//",
        "//  ADR-0003's core invariant, proven per interpolated call-site shape:",
        "//      generator-produced key == ThemeKitLocalizationValue.key (runtime)",
        "//  Both map every interpolation to %@ (and escape literal % as %% in",
        "//  interpolated keys), so a consumer translation authored against the",
        "//  generated catalogs can never be missed by the resolver.",
        "//",
        "",
        "import XCTest",
        "import ThemeKitCore",
        "",
        "final class L10nKeyInvariantTests: XCTestCase {",
        '    private let d = "\\u{2022}"   // dummy interpolation value',
        "",
        "    private func assertKey(",
        "        _ value: ThemeKitLocalizationValue, _ expected: String, _ arguments: Int,",
        "        site: String, file: StaticString = #filePath, line: UInt = #line",
        "    ) {",
        '        XCTAssertEqual(value.key, expected, "key drift at \\(site)", file: file, line: line)',
        '        XCTAssertEqual(value.arguments.count, arguments, "argument-count drift at \\(site)", file: file, line: line)',
        "    }",
    ]
    chunk = 25
    for c in range(0, len(rows), chunk):
        lines.append("")
        lines.append(f"    func testInterpolatedKeyShapes{c // chunk + 1}() {{")
        for key, literal, nargs, site in rows[c:c + chunk]:
            lines.append("        assertKey(")
            lines.append(f'            "{literal}",')
            lines.append(f'            "{swift_escape(key)}", {nargs},')
            lines.append(f'            site: "{swift_escape(site)}")')
        lines.append("    }")
    lines.append("}")
    return "\n".join(lines) + "\n"


# ── main ──────────────────────────────────────────────────────────────────────

def generate():
    sites, problems = [], []
    for path in sorted(SCAN_ROOT.rglob("*.swift")):
        text = strip_comments(path.read_text(encoding="utf-8"))
        scan(text, str(path.relative_to(ROOT)), sites, problems)

    outputs = {}
    for bridge, catalog_path in BRIDGES.items():
        keys = {canonical_key(s["tokens"]) for s in sites if s["bridge"] == bridge}
        outputs[catalog_path] = render_catalog(keys, load_comments(catalog_path))

    all_keys = {canonical_key(s["tokens"]) for s in sites}
    merged_comments = {}
    for catalog_path in BRIDGES.values():
        for key, comment in load_comments(catalog_path).items():
            merged_comments.setdefault(key, comment)
    outputs[TEMPLATE_OUT] = render_catalog(all_keys, merged_comments)

    interp_sites = [s for s in sites if any(k == "interp" for k, _ in s["tokens"])]
    outputs[TEST_OUT] = render_invariant_test(interp_sites)
    return sites, outputs, problems


def main():
    check = "--check" in sys.argv
    sites, outputs, problems = generate()
    for p in problems:
        print(f"warning: {p}", file=sys.stderr)

    failed = False
    if check:
        for path, content in outputs.items():
            on_disk = path.read_text(encoding="utf-8") if path.exists() else ""
            if on_disk != content:
                print(f"DRIFT: {path.relative_to(ROOT)} is stale — run `make l10n`", file=sys.stderr)
                failed = True
        # completeness: every extracted key exists in its on-disk catalog
        for bridge, catalog_path in BRIDGES.items():
            try:
                disk_keys = set(json.loads(catalog_path.read_text(encoding="utf-8"))["strings"])
            except (OSError, ValueError, KeyError):
                disk_keys = set()
            missing = {
                canonical_key(s["tokens"]) for s in sites if s["bridge"] == bridge
            } - disk_keys
            for key in sorted(missing):
                print(f"MISSING: {catalog_path.relative_to(ROOT)} lacks key {key!r}", file=sys.stderr)
                failed = True
        if failed:
            sys.exit(1)
        print(f"l10n check OK — {len(sites)} keys extracted, catalogs + template + invariant test in sync")
        return

    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(f"Wrote {path.relative_to(ROOT)}")
    n_interp = sum(1 for s in sites if any(k == "interp" for k, _ in s["tokens"]))
    for bridge, catalog_path in BRIDGES.items():
        n = len({canonical_key(s['tokens']) for s in sites if s['bridge'] == bridge})
        print(f"  {bridge}: {n} keys → {catalog_path.relative_to(ROOT)}")
    print(f"  total: {len(sites)} extracted keys ({n_interp} interpolated)")


if __name__ == "__main__":
    main()
