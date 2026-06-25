# Visual Regression (Snapshot) Testing

Unit tests prove a component's *logic*; snapshot tests prove how it *looks*. In a
108-component design system the dangerous bug is the silent one: a token, a
padding, or a corner-radius tweak that quietly reshapes a dozen screens. Snapshot
tests render each component to an image and compare it against a committed
reference, so that diff shows up in the PR instead of in production.

## How it's wired

- **Library:** [`swift-snapshot-testing`](https://github.com/pointfreeco/swift-snapshot-testing),
  a **test-only** dependency. The shipped `GlobalUIComponents` library stays
  zero-dependency.
- **Where it runs:** iOS only. `SnapshotSupport.swift` and the tests are wrapped
  in `#if canImport(UIKit)`, so `swift test` on macOS skips them entirely and the
  logic suite stays fast and host-independent.
- **Determinism:** every component renders at a fixed width, sized to fit, with an
  explicit color scheme and content-size category. Tolerances (`precision`,
  `perceptualPrecision` in `SnapshotConfig`) absorb sub-pixel antialiasing noise
  without letting real regressions through.

## Why it's opt-in

Image rendering varies subtly across OS versions and GPUs, so the suite does not
block CI by default — it would flake whenever a runner image changed. Instead it
runs **on demand**, on a simulator your team pins, gated behind `RUN_SNAPSHOTS=1`.
This keeps CI deterministic while still giving you a real visual gate locally and
in a dedicated job.

## Recording references

The committed references in `__Snapshots__/` were recorded on **iPhone 17 /
iOS 26** — that's the team's source of truth. Use the same device when you
record or verify, or the antialiasing will drift and produce false diffs.

> **Gotcha — environment variables don't cross into the Simulator.** A shell
> `RUN_SNAPSHOTS=1 xcodebuild test …` does **not** reach the test process running
> inside the Simulator, so the suite would just skip. Set the variables on the
> **scheme's Test action** (where they're delivered into the test runtime), then
> run from Xcode or the CLI:

1. **Configure once** — Xcode → Edit Scheme → `GlobalUIComponents-Package` →
   Test → Arguments → Environment Variables: add `RUN_SNAPSHOTS = 1` (and
   `RECORD_SNAPSHOTS = 1` only while recording).

2. **Record** (with `RECORD_SNAPSHOTS = 1`), then commit the generated
   `__Snapshots__/` folders:
   ```bash
   xcodebuild test -scheme GlobalUIComponents-Package \
     -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

3. **Verify** — turn `RECORD_SNAPSHOTS` off and re-run the same command. This is
   what reviewers re-run; it must pass against the committed references.

A failing snapshot writes a side-by-side diff image; open it to see exactly what
moved. If the change is intentional, re-record and commit the new reference.

Note the scheme name: `GlobalUIComponents-Package` is the one wired for the test
action (the plain `GlobalUIComponents` scheme builds only the library product).

## Adding coverage

Coverage is organised by altitude, each suite subclassing `SnapshotTestCase`:

- `ComponentSnapshotTests` — small atoms (Badge, Tag, ScoreBadge, StatusDot, Chip).
- `ButtonSnapshotTests` — `GlobalButton` across the full variant × color × size ×
  shape × state matrix, plus the presets.
- `FormControlSnapshotTests` — TextInput (incl. error state), Checkbox, RadioButton,
  SegmentedControl.
- `DisplaySnapshotTests` — Avatar, Card, Callout, EmptyState, Rating, Progress, Stat.

Extend any of them the same way — one method per state that matters:

```swift
func testMyComponent() {
    assertComponentSnapshot(MyComponent(title: "Hello"))
}

// Prove it adapts:
func testMyComponent_darkMode() {
    assertComponentSnapshot(MyComponent(title: "Hello"), colorScheme: .dark)
}
func testMyComponent_largeText() {
    assertComponentSnapshot(MyComponent(title: "Hello"),
                            contentSize: .accessibilityExtraExtraExtraLarge)
}
```

Prioritise components with many visual states (buttons, badges, inputs) and the
shared primitives (theme tokens, typography) where one change ripples widest.
