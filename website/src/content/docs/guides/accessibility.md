---
title: Accessibility
description: Dynamic Type, VoiceOver, and Reduce Motion are built in — not bolted on.
---

Accessibility is a property of the system, not a feature you add per screen.
ThemeKit components are accessible by default; in most cases you write nothing
extra.

## Dynamic Type

Text styles scale with the user's preferred content size. Because typography is a
token (`textStyle(_:)`) rather than a fixed point size, every component grows and
shrinks consistently when the user changes their text size.

```swift
Text("Welcome").textStyle(.headingBase)   // scales with Dynamic Type
```

## VoiceOver

Components ship sensible accessibility labels, traits, and grouping. Interactive
controls expose their role (button, toggle, slider…) so VoiceOver announces them
correctly out of the box.

## Reduce Motion

Micro-animations honor the system **Reduce Motion** setting automatically. You can
also override motion at theme-wide or per-component scope — see
[Motion](../motion/).

## Auditing

ThemeKit's own test suite runs automated accessibility audits using iOS 17+
`performAccessibilityAudit()` (contrast, Dynamic Type clipping, hit-region size).
You can apply the same pattern in your app's UI tests to catch regressions.

:::tip
The fastest accessibility win is to never hard-code a font size or color — use
`textStyle(_:)` and theme color tokens, and scaling/contrast come for free.
:::
