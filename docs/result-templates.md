# Result & exception templates

Ant Design's "Result" pattern: a full-page status view for the outcome of an operation,
or an exception page. `ResultView` covers both, and pairs with `EmptyState` for the
"no data" case.

## When to use which

| Situation | Use |
|---|---|
| An operation finished (success / failure / pending) | `ResultView(.success / .error / .warning / .info, …)` |
| Route/page error | `ResultView(.notFound /*404*/ / .forbidden /*403*/ / .serverError /*500*/, …)` |
| A list/search returned nothing | `EmptyState(systemImage:title:message:)` |
| Inline, non-blocking status | `InfoBanner` / `Callout` (see feedback-patterns.md) |

## API

```swift
ResultView(
    .success,
    title: "Rezervasyon onaylandı",
    message: "Onay e-postası gönderildi.",
    primaryTitle: "Detaylar",   onPrimary: { … },
    secondaryTitle: "Ana sayfa", onSecondary: { … }
)

// Exception page
ResultView(.notFound, title: "Sayfa bulunamadı",
           message: "Aradığınız sayfa taşınmış olabilir.",
           primaryTitle: "Ana sayfaya dön", onPrimary: { … })
```

- `ResultStatus`: `success · info · warning · error · notFound(404) · forbidden(403) · serverError(500)`.
- The status drives the icon **and** the primary action's color via `SemanticColor` — so colors
  follow the active theme and adapt to dark mode (the emblem uses the ladder roles `color.bg` / `color.base`).
- `404 / 403 / 500` render the status code as a large numeral; the others use an icon-in-circle emblem.
- Both actions are optional; pass only `primaryTitle` for a single CTA.

These are page-level templates — drop one into a `NavigationStack` destination or a full-screen
state, the same way Ant ships `Result` as a page block.
