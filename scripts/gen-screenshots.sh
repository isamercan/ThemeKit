#!/usr/bin/env bash
#
# Render every captured component to Screenshots/<Name>.png and rebuild the gallery
# in README.md (between the GALLERY markers), grouped by category from the
# generator's manifest. Runs on macOS via ImageRenderer — no simulator.
#
#   scripts/gen-screenshots.sh        # generate PNGs + rebuild README gallery
#   make screenshots                  # same
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Set SKIP_RENDER=1 to rebuild only the README gallery from the PNGs already on disk
# (e.g. after a layout tweak) without re-rendering every component.
if [ "${SKIP_RENDER:-0}" != "1" ]; then
    echo "▸ Rendering component screenshots + overlay GIFs…"
    # Both generators share "Generator" in their name.
    GENERATE_SCREENSHOTS=1 swift test --filter Generator >/dev/null
fi

MANIFEST="Screenshots/manifest.tsv"
[ -f "$MANIFEST" ] || { echo "✗ $MANIFEST missing (did the generator run?)"; exit 1; }

GALLERY="$(mktemp)"
COLS=3
emit_category() {
    local cat="$1"
    local names; names=$(awk -F '\t' -v c="$cat" '$1==c {print $2}' "$MANIFEST")
    [ -z "$names" ] && return
    {
        echo
        echo "### $cat"
        echo
        echo "<table>"
        local i=0
        while IFS= read -r name; do
            [ "$((i % COLS))" -eq 0 ] && echo "<tr>"
            # Display each preview at its OWN size: the PNG is rendered @2x, so the
            # natural width is pixelWidth/2. Cap at 240 so wide ones fit the cell;
            # small ones (Badge, Spinner) stay small instead of being upscaled.
            local pw; pw=$(sips -g pixelWidth "Screenshots/$name.png" 2>/dev/null | awk '/pixelWidth/{print $2}')
            local w=$(( ${pw:-480} / 2 )); [ "$w" -gt 240 ] && w=240
            printf '<td align="center" valign="top" width="33%%"><picture><source media="(prefers-color-scheme: dark)" srcset="Screenshots/%s-dark.png"><img src="Screenshots/%s.png" width="%s" alt="%s"></picture><br><sub><b>%s</b></sub></td>\n' "$name" "$name" "$w" "$name" "$name"
            i=$((i + 1))
            [ "$((i % COLS))" -eq 0 ] && echo "</tr>"
        done <<< "$names"
        [ "$((i % COLS))" -ne 0 ] && echo "</tr>"
        echo "</table>"
    } >> "$GALLERY"
}

emit_category "Atoms"
emit_category "Molecules"
emit_category "Organisms"

# Animated overlay GIFs (presented state — they can't be a single static frame).
if [ -f "Screenshots/gifs.tsv" ]; then
    {
        echo
        echo "### Overlays (animated)"
        echo
        echo "_Entrance previews rendered from the live components. SelectBox, BottomSheet, Tour and Feedback use OS-owned presentations (native \`Menu\` / \`.sheet\`) that no offscreen renderer can capture — record them from the running app with \`make record-gif NAME=SelectBox\` (boots the simulator, you tap to open the dropdown; see [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md))._"
        echo
        echo "<table>"
        i=0
        while IFS=$'\t' read -r _ name; do
            [ -z "$name" ] && continue
            [ "$((i % COLS))" -eq 0 ] && echo "<tr>"
            printf '<td align="center" width="33%%"><img src="Screenshots/%s.gif" width="260" alt="%s"><br><sub><b>%s</b></sub></td>\n' "$name" "$name" "$name"
            i=$((i + 1))
            [ "$((i % COLS))" -eq 0 ] && echo "</tr>"
        done < "Screenshots/gifs.tsv"
        [ "$((i % COLS))" -ne 0 ] && echo "</tr>"
        echo "</table>"
    } >> "$GALLERY"
fi

COUNT=$(grep -c '<img ' "$GALLERY")
echo "▸ $COUNT components → rebuilding README gallery…"

# Splice the gallery between the markers in README.md.
awk -v galleryfile="$GALLERY" '
    /<!-- GALLERY:START -->/ { print; while ((getline line < galleryfile) > 0) print line; skip=1; next }
    /<!-- GALLERY:END -->/   { skip=0 }
    !skip { print }
' README.md > README.md.tmp && mv README.md.tmp README.md
rm -f "$GALLERY"
echo "✓ README gallery updated ($COUNT screenshots)."
