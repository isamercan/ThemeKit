# Micro-motion

ThemeKit components animate **micro** state changes — a press scale, a selection
slide, a value tick — and nothing showy. Every bit of that motion is switchable, at
two scopes, and the system **Reduce Motion** setting always overrides both.

## Turning it off

```swift
// Theme-wide — one switch at the app root disables motion everywhere downstream.
RootView()
    .microAnimations(false)

// Per-component — override just one component (or one subtree).
PrimaryButton("Still") { … }
    .microAnimations(false)
```

`microAnimations` is a SwiftUI `EnvironmentValues` flag (default `true`) read by the
shared button styles and by individual components. Because it's environment-based,
the **same modifier** does both jobs: set it high for a global switch, set it low to
override a branch. The effective rule is:

```
animate  ==  microAnimations  &&  !accessibilityReduceMotion
```

So a Reduce-Motion user never sees motion regardless of the flag, and you can still
force a specific component still even when motion is on globally.

## Using it in a component

```swift
@Environment(\.microAnimations) private var micro
@Environment(\.accessibilityReduceMotion) private var reduceMotion

someView
    .animation(
        MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion),
        value: state
    )
```

`MicroMotion.animation(_:enabled:reduceMotion:)` returns `nil` when motion is off,
and a `nil` animation makes the state change apply instantly (no motion) — so the UI
stays fully functional, it just stops moving.

For a tappable surface that isn't already a ThemeKit `ButtonStyle`, the gated
press-scale helper:

```swift
myView.microPressScale(isPressed)   // 0.97 by default, snaps when motion is off
```

## Design rules (what "micro" means here)

- **Durations** come from the `Motion` tokens — `instant` (0.10s) for press,
  `fast` (0.20s) for state/selection. Nothing slower for interaction feedback.
- **Magnitudes** stay small: ~0.97 scale, opacity, 2–4 pt offset. No bounce, no
  overshoot, no attention-grabbing springs.
- **Static** atoms (Divider, Kbd, InlineText) get no animation — motion is reserved
  for interactive and stateful components.

Try it live: **Gallery → Micro-motion** (per-component override) and **Configurator →
Micro-animations** (theme-wide switch).
