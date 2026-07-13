#!/usr/bin/env bash
#
# check-theme-shared.sh — ADR-0006 §D7 enforcement gate.
#
# `Theme.shared` is the correct default for the engine (env fallback, root
# injectors, apply-to-global mutators) and for #Preview scaffolding — but a
# COMPONENT reaching past its `@Environment(\.theme)` to the singleton is
# exactly the bug ADR-0006 fixed (R1): it silently defeats per-subtree
# `.theme(_:)`. This gate keeps a new component from regressing it.
#
# HARD FAIL → a `Theme.shared` CODE read under Sources/ that is not:
#   - in a file listed in scripts/theme-shared-allowlist.txt (the engine/
#     preset/deprecate-forward/deferred-metric files ADR-0006 §D7 names), or
#   - a comment (a `//` line, or the trailing `// …` on a code line — ADR-0006
#     itself is documented in-line and legitimately spells out "Theme.shared"
#     dozens of times), or
#   - an `@available(*, deprecated, …)` message string (same reason — the
#     deprecation prose names the thing it's steering callers away from), or
#   - inside a `#Preview` body (everything at/after a file's first `#Preview`
#     line — previews correctly pin `.environment(Theme.shared)`).
#
# This is a text heuristic (like check-variant-naming.sh), not a compiler
# plugin: it can't see `.shared` used via type-inferred shorthand outside a
# `Theme.` receiver, only the literal spelled-out `Theme.shared` token the
# ADR's audit was built from.
#
# Usage: scripts/check-theme-shared.sh
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOWLIST="scripts/theme-shared-allowlist.txt"
red=$'\033[31m'; green=$'\033[32m'; dim=$'\033[2m'; reset=$'\033[0m'

allowed_files=""
if [[ -f "$ALLOWLIST" ]]; then
  allowed_files=$(sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$ALLOWLIST" | grep -v '^$')
fi

is_allowed() {
  grep -qxF "$1" <<< "$allowed_files"
}

violations=""
while IFS= read -r -d '' file; do
  is_allowed "$file" && continue

  hit=$(awk '
    /^[[:space:]]*#Preview/ { exit }
    {
      line = $0
      sub(/\/\/.*/, "", line)                              # drop trailing // comment
      if (line ~ /@available\(\*,[[:space:]]*deprecated/) next   # deprecation message prose
      if (line ~ /Theme\.shared/) printf "  %d: %s\n", NR, $0
    }
  ' "$file")

  if [[ -n "$hit" ]]; then
    violations+="${file}:"$'\n'"${hit}"$'\n'
  fi
done < <(find Sources -name '*.swift' -print0)

if [[ -n "$violations" ]]; then
  printf '%s✗ Theme.shared read(s) outside the allowlist (ADR-0006 §D7):%s\n' "$red" "$reset"
  printf '%s\n' "$violations"
  printf '%sFix: resolve against @Environment(\\.theme) in a View body, thread a `theme:`\n' "$dim"
  printf 'param through a helper (Class P), or store the SemanticColor and resolve in\n'
  printf '`body` instead of at modifier-call time (Class M). If this is a genuine new\n'
  printf 'engine/injector site, document it and add it to %s.%s\n' "$ALLOWLIST" "$reset"
  exit 1
fi

printf '%s✓%s no un-allowlisted Theme.shared reads under Sources/\n' "$green" "$reset"
