# Accessibility

Dynamic Type and Reduce Motion are honored across the library — without any
extra work from you.

## Overview

### Dynamic Type

The type ramp scales with the user's preferred text size. Each ``TextStyle``
token maps to a semantic `Font.TextStyle` (its ``TextStyle/relativeTextStyle``)
and the bundled font is built with `relativeTo:`, so text grows and shrinks with
the system setting:

```swift
Text("Trip summary").textStyle(.headingBase)   // scales with Dynamic Type
```

At the default content-size category nothing changes visually — sizes only
move when the user opts into larger or smaller text. The library never forces a
clamp; if a specific screen must not grow unbounded, clamp it yourself:

```swift
MyScreen().dynamicTypeSize(...DynamicTypeSize.accessibility2)
```

### Reduce Motion

When **Settings ▸ Accessibility ▸ Reduce Motion** is on, decorative and
continuous animation is suppressed while functional motion is preserved:

| Component | With Reduce Motion |
|---|---|
| `borderBeam` | static accent border (no traveling comet) |
| ``Skeleton`` | static placeholder (no shimmer sweep) |
| ``RollingNumber`` | snaps to the value (no roll) |
| ``StatusDot`` | solid dot (no pulse ring) |
| ``Carousel`` / ``PagingCarousel`` | autoplay paused (manual paging still works) |
| ``OTPInput`` | solid caret (no blink) |
| ``Spinner`` | **kept spinning** — it conveys progress |

Each component reads `@Environment(\.accessibilityReduceMotion)` and branches
internally, so no caller configuration is needed.
