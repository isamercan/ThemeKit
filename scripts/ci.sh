#!/usr/bin/env bash
#
# Local mirror of the GitHub Actions gates — runs for $0 on your machine, so
# verification never depends on Actions billing. Same checks CI runs:
#   1. SwiftFormat  (lint mode, if installed)
#   2. SwiftLint    (if installed)
#   3. swift build --build-tests
#   4. swift test
#
# Usage:  scripts/ci.sh            # all gates
#         scripts/ci.sh --fast     # skip format/lint, just build + test
#         make ci                  # same thing
#
set -uo pipefail
cd "$(dirname "$0")/.."

FAST=0; [[ "${1:-}" == "--fast" ]] && FAST=1

bold=$'\033[1m'; green=$'\033[32m'; red=$'\033[31m'; yellow=$'\033[33m'; dim=$'\033[2m'; reset=$'\033[0m'
declare -a RESULTS
fail=0

step() { printf '\n%s▸ %s%s\n' "$bold" "$1" "$reset"; }
pass() { RESULTS+=("${green}✓${reset} $1"); }
warn() { RESULTS+=("${yellow}skip${reset} $1 ${dim}($2)${reset}"); }
die()  { RESULTS+=("${red}✗${reset} $1"); fail=1; }

# 1 + 2: style gates (best-effort — they don't block locally if the tool is absent;
# CI is the source of truth, but running them here catches issues before push).
if [[ $FAST -eq 0 ]]; then
  step "SwiftFormat (lint)"
  if command -v swiftformat >/dev/null 2>&1; then
    if swiftformat --lint . ; then pass "SwiftFormat"; else die "SwiftFormat — run 'make format'"; fi
  else
    warn "SwiftFormat" "not installed: brew install swiftformat"
  fi

  step "SwiftLint"
  if command -v swiftlint >/dev/null 2>&1; then
    if swiftlint lint --quiet ; then pass "SwiftLint"; else die "SwiftLint"; fi
  else
    warn "SwiftLint" "not installed: brew install swiftlint"
  fi
fi

# 3: build (the package + tests). This is the must-pass gate.
step "swift build --build-tests"
if swift build --build-tests ; then pass "Build"; else die "Build"; fi

# 4: test — only if the build succeeded (skip-build reuses step 3's products).
if [[ $fail -eq 0 ]]; then
  step "swift test"
  if swift test --skip-build 2>&1 | tee .ci-test.log ; then
    pass "Test — $(grep -oE 'Executed [0-9]+ tests' .ci-test.log | tail -1 || echo 'ok')"
  else
    die "Test"
  fi
  rm -f .ci-test.log
else
  RESULTS+=("${yellow}skip${reset} Test ${dim}(build failed)${reset}")
fi

# Summary
printf '\n%s── CI summary ──%s\n' "$bold" "$reset"
for r in "${RESULTS[@]}"; do printf '  %s\n' "$r"; done
if [[ $fail -eq 0 ]]; then
  printf '\n%s✓ all gates green%s\n' "$green$bold" "$reset"
else
  printf '\n%s✗ gates failed%s\n' "$red$bold" "$reset"
fi
exit $fail
