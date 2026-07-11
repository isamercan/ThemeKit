#!/usr/bin/env bash
#
# Brand-neutrality & i18n gate. ThemeKit is a brand-neutral, English-only
# catalog (see the project rules + THEMEKIT_COMPONENT_AUDIT.md).
#
#   HARD FAIL  → a real brand name ("etstur") or Turkish-language string leaked
#                into shipped source/tests/previews, or a hardcoded "TRY"
#                currency default came back. These must stay at zero.
#   ADVISORY   → raw Color.white/.black/hex in component bodies and in-component
#                URLSession/Task (House-Rule-1). Tracked as P0.2/P0.3 in the
#                audit; printed for visibility, NOT blocking yet.
#
# Usage:  scripts/check-neutrality.sh
#
set -uo pipefail
cd "$(dirname "$0")/.."

red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; dim=$'\033[2m'; reset=$'\033[0m'
fail=0

# --- HARD gate 1: brand name + Turkish-language tokens (English-only rule) ---
# NOTE: matches Turkish-LANGUAGE tokens + brand only. Real place names in Latin/English
# (e.g. "Istanbul", "Sabiha Gokcen Airport" in the ThemeKitTravel edition) are fine.
# Token-specific so the author's name ("İsa Mercan") in file headers never trips it.
BRAND_RE='etstur|Etstur|Türkiye|Havaliman|Esenboğa|Kadıköy|Gökçen|İstanbul|"/ ay"'
brand_hits=$(grep -rnE "$BRAND_RE" Sources Tests --include='*.swift' 2>/dev/null || true)
if [[ -n "$brand_hits" ]]; then
  printf '%s✗ brand / Turkish-language leak(s):%s\n' "$red" "$reset"
  printf '%s\n' "$brand_hits"
  fail=1
else
  printf '%s✓%s no brand / Turkish-language leaks\n' "$green" "$reset"
fi

# --- HARD gate 2: hardcoded "TRY" currency default (the CurrencyPicker catalog
#     entry "Turkish Lira" is a legitimate list item and is allow-listed) ---
try_hits=$(grep -rn '"TRY"' Sources --include='*.swift' 2>/dev/null | grep -v 'Turkish Lira' || true)
if [[ -n "$try_hits" ]]; then
  printf '%s✗ hardcoded "TRY" currency default (use the FormatDefaults env chain):%s\n' "$red" "$reset"
  printf '%s\n' "$try_hits"
  fail=1
else
  printf '%s✓%s no hardcoded "TRY" currency default\n' "$green" "$reset"
fi

# --- ADVISORY (non-blocking; audit P0.2/P0.3) ---
comp='Sources/ThemeKit/Components'
raw_color=$(grep -rnE 'Color\.white|Color\.black|Color\(hex' "$comp" --include='*.swift' 2>/dev/null | wc -l | tr -d ' ')
net=$(grep -rn 'URLSession' "$comp" --include='*.swift' 2>/dev/null | wc -l | tr -d ' ')
printf '%sadvisory%s (not blocking — see THEMEKIT_COMPONENT_AUDIT.md P0.2/P0.3):\n' "$dim" "$reset"
printf '  %s⚠%s raw Color.white/.black/hex in components: %s site(s) — ADR-0002\n' "$yellow" "$reset" "$raw_color"
printf '  %s⚠%s in-component URLSession (House-Rule-1): %s site(s) — AnimatedImage is a documented exception\n' "$yellow" "$reset" "$net"

exit $fail
