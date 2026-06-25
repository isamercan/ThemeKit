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
# A non-zero exit means the public API of `GlobalUIComponents` changed in a
# source-breaking way versus the baseline. That's allowed — but it MUST come
# with a MAJOR version bump (see docs/API-STABILITY.md). Intentional breaks can
# be recorded in .api-breakage-allowlist.txt to keep CI green.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ge 1 ]]; then
  BASELINE="$1"
else
  # Prefer the most recent semver tag; fall back to origin/main.
  BASELINE="$(git describe --tags --abbrev=0 2>/dev/null || echo "origin/main")"
fi

echo "▸ Comparing public API against baseline: ${BASELINE}"

ALLOWLIST_ARG=()
if [[ -f .api-breakage-allowlist.txt ]]; then
  ALLOWLIST_ARG=(--breakage-allowlist-path .api-breakage-allowlist.txt)
fi

swift package diagnose-api-breaking-changes "${BASELINE}" \
  --products GlobalUIComponents \
  "${ALLOWLIST_ARG[@]}"
