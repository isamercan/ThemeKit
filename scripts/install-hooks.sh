#!/usr/bin/env bash
#
# Install a pre-push hook that runs the local CI gates (scripts/ci.sh) before any
# push reaches GitHub — so a red build never leaves your machine, billing or not.
# Run once:  scripts/install-hooks.sh   (or `make hooks`)
#
set -euo pipefail
cd "$(dirname "$0")/.."

HOOK=".git/hooks/pre-push"
cat > "$HOOK" <<'HOOK_BODY'
#!/usr/bin/env bash
# Auto-installed by scripts/install-hooks.sh — runs local CI before push.
# Skip once with:  git push --no-verify
echo "▸ pre-push: running local CI gates (scripts/ci.sh)…"
exec bash "$(git rev-parse --show-toplevel)/scripts/ci.sh"
HOOK_BODY

chmod +x "$HOOK"
echo "✓ installed $HOOK — local CI now runs on every 'git push' (bypass: git push --no-verify)"
