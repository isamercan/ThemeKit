# Component gallery — screenshots, GIFs & recordings

The README gallery is generated from the library itself. Three tiers, by how much
of a component can be captured headlessly.

## 1. Static stills (most components)

`make screenshots` renders ~86 components to `Screenshots/<Name>.png` via SwiftUI
`ImageRenderer` on macOS — no simulator — and rebuilds the README gallery between
the `<!-- GALLERY -->` markers.

- Source: `Tests/ThemeKitTests/ScreenshotGenerator.swift` (gated by
  `GENERATE_SCREENSHOTS=1`, so it never runs in the normal suite).
- **Text fields:** `ImageRenderer` can't draw `TextField`/`TextEditor` headlessly
  (yellow placeholder), so those examples use `hosted: true` — rendered in a real
  offscreen `NSWindow` (`NSHostingView` + `cacheDisplay`).

## 2. Synthesised overlay GIFs (custom overlays)

`make screenshots` also runs `GifGenerator`, which renders each custom overlay's
**presented** state via the offscreen-window path and synthesises a fade+scale
entrance into `Screenshots/<Name>.gif` (Core Graphics → ImageIO, no ffmpeg):
**Dialog, Drawer, Popconfirm, AlertToast, Tooltip**.

## 3. Real recordings (OS-owned presentations)

Some components present through **the OS, outside the SwiftUI view tree** — a
native `Menu` popup (**SelectBox**) or a `.sheet` (**BottomSheet**), plus the
presenter overlays **Tour** / **Feedback**. No offscreen renderer can capture
these; they must be recorded from the running app.

```bash
make record-gif NAME=SelectBox          # or: scripts/record-gif.sh SelectBox 7
```

What it does (all automatic except one tap):

1. Boots the **iPhone 17 Pro** simulator (override with `RECORD_DEVICE`).
2. Builds + installs + launches the **Demo** app.
3. Brings the Simulator window forward and records the screen for N seconds.
4. Converts the `.mov` → `Screenshots/<Name>.gif` via `Tools/mov2gif.swift`
   (AVFoundation + ImageIO — **no ffmpeg dependency**).

**The one manual step:** during the recording window, tap the component in the
simulator (e.g. open the SelectBox dropdown). There is no headless tap injection
available here (no `idb` / `cliclick` / XCUITest target) and a SwiftUI `Menu` can't
be opened programmatically — so that single tap is yours. Everything around it is
scripted.

Then drop the new GIF into the gallery (add it to `gifs.tsv` or the generator) and
run `make screenshots` to rebuild the README.
