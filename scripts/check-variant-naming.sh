#!/usr/bin/env bash
#
# check-variant-naming.sh — grep-gate for the variant-matrix naming contract
# (HEROUI_INFRA_PLAN.md, ADR-3 / T3).
#
# The canonical component matrix is token-fed:
#   color axis   → `.color(_: SemanticColor)` / a theme token key — never raw `Color`
#   fill axis    → `.variant(_: FillVariant)` / a semantic per-component enum
#   size axis    → native `.controlSize(_:)` or `.size(_: <Component>Size)` — never a CGFloat knob
#
# This gate greps *public* modifier signatures under Sources/ for drift:
#   1. any public `func` taking a raw `Color` parameter, and
#   2. axis-named modifiers (`size` / `variant`) taking a raw `CGFloat`,
# skipping declarations that are non-public, `@_spi`, `@available(*, deprecated …)`
# (deprecate-and-forward escape hatches are the sanctioned back-compat path),
# or listed in scripts/variant-naming-allowlist.txt (genuine dimensions and
# color-math utilities with a documented rationale).
#
# It is a heuristic text gate, not a compiler plugin: multi-line signatures are
# joined until the body opens, and the return type after the final `->` is
# ignored so `-> (fill: Color, …)` result tuples don't false-positive.
#
# Wired into CI as an informational step (same policy as check-api.sh): a
# nonzero exit becomes a ::warning, never a red build.
#
# Usage: scripts/check-variant-naming.sh
set -euo pipefail

cd "$(dirname "$0")/.."

ALLOWLIST="scripts/variant-naming-allowlist.txt"

violations=$(
  find Sources -name '*.swift' -print0 | xargs -0 -n1 awk '
    # Pending attributes bless/mark the next declaration.
    /@available\(\*,[[:space:]]*deprecated/ { deprecated = 1 }
    /@_spi\(/ && $0 !~ /func/ { spi = 1 }

    # Track the enclosing top-level container (column-0 declarations): only
    # `public extension` members inherit `public` implicitly.
    /^(@[A-Za-z_(){}.,: ]*[[:space:]])?((public|private|fileprivate|internal|package)[[:space:]]+)?(final[[:space:]]+)?(extension|struct|class|enum|actor)[[:space:]]/ {
      inPublicExtension = ($0 ~ /(^|[[:space:]])public[[:space:]]+extension[[:space:]]/)
    }

    {
      if ($0 ~ /(^|[[:space:]])func[[:space:]]/) {
        sig = $0; name = $0
        sub(/.*func[[:space:]]+/, "", name); sub(/[(<].*/, "", name)
        explicitAccess = ($0 ~ /(^|[[:space:]])(private|fileprivate|internal|package)[[:space:]]/)
        explicitPublic = ($0 ~ /(^|[[:space:]])public[[:space:]]/)
        fileSpi = spi || ($0 ~ /@_spi\(/)
        # Join a multi-line signature until its body opens (bounded).
        joined = 0
        while (sig !~ /\{/ && joined < 12 && (getline line) > 0) { sig = sig " " line; joined++ }
        # Ignore the return type: drop everything after the final `->`.
        n = split(sig, parts, "->")
        if (n > 1) { sig = ""; for (i = 1; i < n; i++) sig = sig parts[i] }
        isPublic = explicitPublic || (inPublicExtension && !explicitAccess)
        if (!deprecated && !fileSpi && isPublic) { check(FILENAME, FNR, name, sig) }
        deprecated = 0; spi = 0
      } else if ($0 !~ /^[[:space:]]*(\/\/|@|$)/) {
        # Any other code line breaks attribute → declaration adjacency.
        deprecated = 0; spi = 0
      }
    }

    function check(file, lineno, name, sig) {
      # 1. Raw `Color` parameter (SemanticColor / token keys do not match: the
      #    type must start immediately after ": ").
      if (sig ~ /: Color\??[[:space:]]*[,)=]/) {
        printf "%s:%d: func %s(…) takes a raw Color — use SemanticColor or a theme token key (ADR-3)\n", file, lineno, name
      }
      # 2. Axis-named modifier fed a raw CGFloat instead of a size/variant enum.
      if ((name == "size" || name == "variant") && sig ~ /: CGFloat/) {
        printf "%s:%d: func %s(…) takes a raw CGFloat for a matrix axis — use a per-component enum or .controlSize (ADR-3)\n", file, lineno, name
      }
    }
  ' | {
    # Drop allowlisted `<file-basename>:<funcName>` entries (inline `#`
    # comments and surrounding whitespace are stripped from the allowlist).
    if [[ -f "$ALLOWLIST" ]]; then
      entries=$(sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$ALLOWLIST" | grep -v '^$' || true)
      while IFS= read -r finding; do
        base=$(basename "${finding%%:*}")
        fn=$(sed -E 's/.*func ([A-Za-z0-9_]+)\(.*/\1/' <<< "$finding")
        grep -qxF "${base}:${fn}" <<< "$entries" || printf '%s\n' "$finding"
      done
    else
      cat
    fi
  }
)

if [[ -n "$violations" ]]; then
  echo "▸ Variant-matrix naming drift (ADR-3) — token-feed these modifier signatures,"
  echo "  deprecate-and-forward them, or allowlist a documented genuine dimension in"
  echo "  ${ALLOWLIST}:"
  echo
  printf '%s\n' "$violations"
  exit 1
fi

echo "▸ Variant-matrix naming: clean (no raw Color / axis-CGFloat modifier signatures)."
