# Global defaults (Provider)

Set app-wide component defaults from one place — ThemeKit's equivalent of a
provider wrapper is the environment stack itself.

## Overview

Libraries like HeroUI wrap the app in a `HeroUIProvider` that supplies global
text, input, animation, and toast defaults. ThemeKit deliberately ships **no
wrapper view**: SwiftUI's environment already is that provider, and every
default is a chainable modifier you compose once at the root — or on any
subtree, which a wrapper can't do without re-wrapping.

The full "provider recipe":

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .themeKit()                                          // theme + tokens
                .componentDefaults(accent: .turquoise)               // house accent
                .fieldDefaults(size: .large)                          // field family defaults
                .feedbackDefaults(toastPosition: .top, toastDuration: 3) // toast defaults
                .microAnimations(true)                                // motion switch
                .feedbackHost()                                       // toast/confirm overlays
        }
    }
}
```

Every layer is optional, additive, and subtree-scopable. The precedence is
always the same: **an explicit per-component modifier wins, the subtree default
fills the gap, the component's own default is the last resort.**

### The layers

| Modifier | Scope | Axes |
| --- | --- | --- |
| `.themeKit()` / `.theme(_:)` | Tokens | The active `Theme` — colors, radii, spacing, type, shadows |
| `.componentDefaults(accent:)` | Chrome | `accent` (semantic house tint for accent-driven components) |
| `.fieldDefaults(...)` | Field family | `size`, `messagesAnimated`, `requiredIndicator` |
| `.feedbackDefaults(...)` | Toasts / notifications | `toastPosition`, `toastDuration`, `maxVisibleToasts` |
| `.microAnimations(_:)` | Motion | Built-in micro-animation switch (Reduce Motion always wins) |
| `.cardStyle(_:)`, `.fieldStyle(_:)`, `.toastStyle(_:)`, … | Chrome archetypes | The active style protocol per component family |
| `.feedbackHost(...)` | Overlays | Installs the shared `FeedbackPresenter` + toast/confirm layers |

### Field defaults

``FieldDefaults`` covers the text-field family — ``TextInput``,
``MultiLineTextInput``, ``SearchBar``, ``DateField``, ``InputNumber``,
``OTPInput``:

```swift
BookingForm()
    .fieldDefaults(size: .large,            // control-size preset for the family
                   messagesAnimated: false, // InfoMessageList rows snap instead of sliding
                   requiredIndicator: true) // .required() fields show their asterisk
```

- A field's explicit `.size(_:)` always wins over `fieldDefaults(size:)`.
  Fields without their own size axis (SearchBar, DateField, InputNumber,
  OTPInput) map the default onto their nearest control metric.
- `messagesAnimated` narrows the field family's message-row motion; the
  `microAnimations` switch and the system Reduce Motion setting still win.
- `requiredIndicator: false` hides the asterisk visual only — the ", required"
  accessibility suffix is always spoken.

> Note: `TextInputModel(size:)` — the legacy init parameter — is
> indistinguishable from the `.medium` default and therefore *yields* to
> `fieldDefaults(size:)`. Use the `.size(_:)` modifier to pin a size.

### Feedback defaults

``FeedbackDefaults`` covers the imperative ``FeedbackPresenter`` layer and the
declarative `.toast(isPresented:)`. Apply it *around* (or above) the
`.feedbackHost(...)` so the host's overlays can read it:

```swift
RootView()
    .feedbackHost()
    .feedbackDefaults(toastPosition: .top,  // default stack edge
                      toastDuration: 3,     // default auto-dismiss (seconds)
                      maxVisibleToasts: 2)  // stack cap (oldest drops)
```

- A per-toast `toast(position:)` wins over `toastPosition`, which wins over the
  `feedbackHost(toastPosition:)` parameter.
- `toastDuration` applies to calls that *omit* their `duration:` /
  `autoDismiss:` argument. An explicit duration — including `nil`, which means
  *sticky* — always wins:

```swift
feedback.toast("Saved", kind: .success)          // uses the 3s default
feedback.toast("Undo?", duration: nil)           // explicitly sticky
feedback.toast("Quick note", duration: 1.5)      // explicitly 1.5s
```

### Text and animation defaults

There is no `textDefaults` group — text defaults *are* the typography tokens.
Restyle `TextStyle` entries via the theme (`fontScale`, custom token JSON) and
every `.textStyle(_:)` call site follows. Likewise animation defaults are the
`.microAnimations(_:)` switch plus the `Motion` token ramp.

## Soft foreground colors

HeroUI ships per-color *soft* text tokens (`text-{color}-soft`,
`text-{color}-soft-hover`). ThemeKit already covers these through
`SemanticColor` — no extra API. Use this mapping instead of reaching for raw
shades:

| HeroUI token | ThemeKit | Role |
| --- | --- | --- |
| `text-{color}-soft` | `SemanticColor.accent` | Readable foreground on the color's `soft` / `outline` / `ghost` fills |
| `text-{color}-soft-hover` | `SemanticColor.strong` (`shade(.s700)`) | Hover / pressed deepening of the soft foreground |
| `text-{color}` (solid surfaces) | `SemanticColor.onSolid` | Foreground on the color's `solid` fill |

```swift
Text("12 seats left")
    .foregroundStyle(SemanticColor.warning.accent)   // text-warning-soft
    .padding(8)
    .background(SemanticColor.warning.soft)
```

The pairing rule of thumb: `soft` background → `accent` foreground;
`solid` background → `onSolid` foreground; interactive deepening → `strong`.

## Topics

### Defaults groups

- ``FieldDefaults``
- ``FeedbackDefaults``
- ``ComponentDefaults``

### Related

- ``FeedbackPresenter``
- <doc:Theming>
