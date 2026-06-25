# Feedback patterns

Modeled on Ant Design's feedback levels: choose the **least intrusive** surface that
still gets the job done. Three levels, from weak to strong.

| Level | When | Surface(s) | How it's shown |
|---|---|---|---|
| **Silent / inline** | Status that lives *with* the content; non-blocking, no acknowledgement needed. | `InfoBanner`, `Callout`, `Badge`, `StatusDot`, inline field `errorText` | Placed in the view tree by the developer where the content is. |
| **Transient / global** | Result of a user action (saved, copied, failed) that doesn't block the next step. | **`feedback.toast(…)`** (built on `AlertToast`) | Auto-dismissing overlay at the app root. |
| **Modal / global** | A decision is required before continuing, or a destructive action needs confirmation. | **`feedback.confirm(…)`** (built on `Dialog`), `BottomSheet` | Dimmed scrim, blocks interaction until resolved. |

## Decision guide

- **Does the user need to act on it?**
  - No, it's just status → **inline** (`InfoBanner` / `Callout`).
  - No, but it confirms their action happened → **toast**.
  - Yes, they must choose / confirm → **confirm dialog** (or `BottomSheet` for richer choices).
- **Is it tied to one field?** → inline `errorText`, never a toast.
- **Is it destructive?** → `confirm(primaryKind: .error)` so the primary button is red.
- **Is it marketing / passive?** → `PromoBanner`, not feedback.

## Unified API

One presenter handles the two *global* levels so call sites don't wire bindings each time.
Install once at the app root, then call from anywhere:

```swift
// App root
ContentView().feedbackHost()

// Anywhere below
@EnvironmentObject var feedback: FeedbackPresenter

feedback.toast("Kaydedildi", kind: .success)            // transient
feedback.toast("Bağlantı yok", kind: .error)

feedback.confirm(                                       // modal
    title: "Rezervasyonu iptal et?",
    message: "Bu işlem geri alınamaz.",
    primaryTitle: "İptal et", primaryKind: .error,
    onPrimary: { … }
)
```

`FeedbackKind` (`success / info / warning / error`) maps to the token system — the same
intent drives the toast color and the confirm dialog's primary-button color.

Inline surfaces stay developer-placed (they belong *in* the layout, not over it), so they
have no presenter — see `InfoBanner` / `Callout` in the gallery.
