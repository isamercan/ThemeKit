# Automated accessibility audit

`Tests/.../AccessibilitySemanticsTests.swift` cover a11y *semantics* (labels, traits,
values) at the unit level. This adds **runtime** auditing —
`XCUIApplication.performAccessibilityAudit()` (iOS 17+) — which catches contrast,
dynamic-type clipping, hit-region size, and element-description issues that only show
up on a rendered screen.

The test code lives in `Demo/DemoUITests/AccessibilityAuditTests.swift`. It drives the
gallery and representative component pages through the Demo's `-openDemo` deep-link.

## One-time target setup (Xcode)

A UI-testing target can't be added safely by editing `project.pbxproj` by hand, so this
is a manual step:

1. **File ▸ New ▸ Target… ▸ UI Testing Bundle.** Name it `DemoUITests`, Target to Test = `Demo`.
2. Delete the auto-generated `DemoUITests.swift` and, in the new target's folder, **add the existing** `Demo/DemoUITests/AccessibilityAuditTests.swift` (Target Membership = `DemoUITests`).
3. The `Demo` scheme's **Test** action picks up `DemoUITests` automatically. (Optional: share the scheme so CI can run it.)

## Running

```bash
xcodebuild test -project Demo/Demo.xcodeproj -scheme Demo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DemoUITests
```

or **⌘U** in Xcode.

## Triaging findings

`performAccessibilityAudit()` fails on any issue. To accept a known, intentional
exception, pass an audit-type set and/or an issue handler:

```swift
try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion]) { issue in
    // return true to IGNORE this issue (e.g. a decorative element)
    issue.element?.label == "decorative-spacer"
}
```

Start strict (audit everything), record the real findings, fix them in the components,
and only then add narrowly-scoped ignores for anything genuinely intentional.
