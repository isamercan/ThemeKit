#!/usr/bin/env bash
#
# Record a real Demo-app interaction on the iOS Simulator and convert it to an
# animated GIF — for components that can't be captured as a static frame or by the
# offscreen renderer (native Menu / .sheet presentations: SelectBox, BottomSheet…).
#
#   scripts/record-gif.sh SelectBox [seconds]     # default 7s
#   make record-gif NAME=SelectBox
#
# The simulator window is brought to the front; during the recording window, TAP
# the component (e.g. open the SelectBox dropdown). There is no headless way to
# inject that tap here (no idb/cliclick/UI-test target), so it's the one manual
# step. Everything else — boot, build, install, launch, record, GIF — is automatic.
#
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?usage: record-gif.sh <ComponentName> [seconds]}"
SECS="${2:-7}"
DEVICE="${RECORD_DEVICE:-iPhone 17 Pro}"
DERIVED=".build/demo"
mkdir -p Screenshots

echo "▸ Booting ${DEVICE}…"
UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-Fa-f-]{36}')
[ -n "$UDID" ] || { echo "✗ no available '$DEVICE' simulator"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "▸ Building + installing the Demo app (first build is slow)…"
xcodebuild -project Demo/Demo.xcodeproj -scheme Demo \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" \
    -quiet build
APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name "*.app" | head -1)
[ -n "$APP" ] || { echo "✗ built .app not found"; exit 1; }
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
open -a Simulator

MOV="Screenshots/_rec_${NAME}.mov"
echo "▸ Recording ${SECS}s → now open '$NAME' in the simulator…"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$MOV" &
REC=$!
sleep "$SECS"
kill -INT "$REC" 2>/dev/null || true
wait "$REC" 2>/dev/null || true

echo "▸ Converting to GIF…"
swift Tools/mov2gif.swift "$MOV" "Screenshots/${NAME}.gif" 12 480
rm -f "$MOV"
echo "✓ Screenshots/${NAME}.gif — add it to the gallery, then 'make screenshots' to rebuild the README."
