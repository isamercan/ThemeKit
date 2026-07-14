#!/usr/bin/env bash
#
# check-api.sh — diagnose public-API breaking changes against a baseline.
#
# Usage:
#   scripts/check-api.sh [baseline]
#
#   baseline   git treeish to compare against (default: the latest release tag,
#              or origin/main if no tags exist).
#
# A non-zero exit means the public API of `ThemeKit` changed in a
# source-breaking way versus the baseline. That's allowed — but it MUST come
# with a MAJOR version bump (see docs/API-STABILITY.md). Intentional breaks can
# be recorded in .api-breakage-allowlist.txt to keep CI green.
#
# NOTE on the allowlist: `swift package diagnose-api-breaking-changes` in the
# current toolchain (Swift 6.2 / Xcode 26) does NOT forward
# `--breakage-allowlist-path` to the underlying `swift-api-digester`, so the
# flag alone no longer suppresses recorded breaks (verified: the digester
# honours the exact-message allowlist when invoked directly, but SwiftPM drops
# it). We therefore filter allowlisted breakages here, in the script, matching
# each `.api-breakage-allowlist.txt` line against the digester's printed
# `API breakage: …` messages exactly. The flag is still passed so this keeps
# working automatically if/when SwiftPM fixes the plumbing.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ge 1 ]]; then
  BASELINE="$1"
else
  # Prefer the most recent semver tag; fall back to origin/main.
  BASELINE="$(git describe --tags --abbrev=0 2>/dev/null || echo "origin/main")"
fi

echo "▸ Comparing public API against baseline: ${BASELINE}"

ALLOWLIST_FILE=".api-breakage-allowlist.txt"
ALLOWLIST_ARG=()
if [[ -f "${ALLOWLIST_FILE}" ]]; then
  ALLOWLIST_ARG=(--breakage-allowlist-path "${ALLOWLIST_FILE}")
fi

# Run the digester. It may exit non-zero when breaks exist (allowlisted or not),
# so don't let `set -e` abort here — we decide pass/fail from the parsed output.
set +e
DIAG_OUTPUT="$(swift package diagnose-api-breaking-changes "${BASELINE}" \
  --products ThemeKit \
  "${ALLOWLIST_ARG[@]}" 2>&1)"
set -e

# Surface the full digester output (build log + breakage list) in CI.
printf '%s\n' "${DIAG_OUTPUT}"

# Extract the breakage messages the digester reported, normalised to the exact
# `API breakage: …` text (drops the leading whitespace + 💔 emoji prefix).
BREAKAGES="$(printf '%s\n' "${DIAG_OUTPUT}" | grep -o 'API breakage:.*' || true)"

if [[ -z "${BREAKAGES}" ]]; then
  echo "▸ No public-API breakages detected."
  exit 0
fi

# Allowlist patterns: every non-comment, non-blank line of the allowlist file.
ALLOWLIST_PATTERNS=""
if [[ -f "${ALLOWLIST_FILE}" ]]; then
  ALLOWLIST_PATTERNS="$(grep -vE '^[[:space:]]*(#|$)' "${ALLOWLIST_FILE}" || true)"
fi

# Remaining = reported breakages that are NOT in the allowlist (exact, whole-line).
REMAINING="$(printf '%s\n' "${BREAKAGES}" \
  | grep -Fxv -f <(printf '%s\n' "${ALLOWLIST_PATTERNS}") || true)"

if [[ -n "${REMAINING}" ]]; then
  echo ""
  echo "✗ Un-allowlisted source-breaking public-API change(s) vs ${BASELINE}:"
  printf '%s\n' "${REMAINING}" | sed 's/^/  💔 /'
  echo ""
  echo "  If intentional: add the exact line(s) above to ${ALLOWLIST_FILE}"
  echo "  together with a MAJOR version bump + CHANGELOG note"
  echo "  (see docs/API-STABILITY.md, docs/2.0-removal-epoch.md)."
  exit 1
fi

echo ""
echo "▸ All ${BASELINE} API breakages are allowlisted — OK."
exit 0
