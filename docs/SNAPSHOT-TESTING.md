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

Pick one simulator as the team's source of truth (match it in `.github/workflows/ci.yml`):

```bash
# 1. Record reference images (commit the generated __Snapshots__ folders)
RUN_SNAPSHOTS=1 RECORD_SNAPSHOTS=1 xcodebuild test \
  -scheme GlobalUIComponents \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'

# 2. Verify everything matches (this is what reviewers re-run)
RUN_SNAPSHOTS=1 xcodebuild test \
  -scheme GlobalUIComponents \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

A failing snapshot writes a side-by-side diff image; open it to see exactly what
moved. If the change is intentional, re-record and commit the new reference.

## Adding coverage

The seed set in `ComponentSnapshotTests.swift` covers a slice of atoms. Extend it
the same way — one method per state that matters:

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
