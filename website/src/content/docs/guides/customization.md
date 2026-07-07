---
title: Customization & Style Protocols
description: Re-skin whole component families with style protocols, extend them with slots, and configure them without forking.
---

Beyond swapping a `Theme`, ThemeKit lets you re-skin whole **families** of
components — cards, fields, chips, bars, meters, toasts, list rows — without
forking a single one. This is the flexibility architecture that shipped across
0.11.0–0.16.0.

## Style protocols

Six archetype style protocols mirror SwiftUI's own `ButtonStyle` idiom: a
`Configuration` describing the component's state, a protocol with one
`makeBody(configuration:)` requirement, and a `.xStyle(_:)` modifier.

| Protocol | Modifier | Pilot / adopters |
|---|---|---|
| `CardStyle` | `.cardStyle(_:)` | `Card`, `FlightCard`, `RoomCard`, `DestinationCard`, `HotelResultCard`, `FareFamilyCard`… (16 card-family organisms) |
| `FieldStyle` | `.fieldStyle(_:)` | `TextInput`, `Select`, `DateField`, `TimeField`, `OTPInput`, `SearchBar`… (15 form-family molecules) |
| `ChipStyle` | `.chipStyle(_:)` | `Chip`, `ImageChip`, `CompactChip`, `ChoseChip`, `FilterChip`, `MapPriceMarker` |
| `BarStyle` | `.barStyle(_:)` | `SheetHeader`, `Footer`, `PageHeader`, `NavigationBar`, `StickyBookingBar` |
| `MeterStyle` | `.meterStyle(_:)` | `ProgressBar`, `RadialProgress`, `Steps` |
| `ToastStyle` | `.toastStyle(_:)` | `AlertToast`, `Feedback` |
| `ListRowStyle` | `.listRowStyle(_:)` | `ListRow` |

Every default style reproduces the component's original look exactly — adopting
a style protocol never changes existing call sites. Write a custom style once,
apply it to every component in the family:

```swift
struct GlassCardStyle: CardStyle {
    func makeBody(configuration: CardStyleConfiguration) -> some View {
        configuration.content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr)
    .price(1_299)
    .cardStyle(GlassCardStyle())   // re-skins the shell; FlightCard's content is untouched
```

## Slots

Presenter and container components expose `ViewBuilder` slots for injecting
custom content without a new initializer parameter:

```swift
ListRow("Account")
    .leading { Avatar(.initials("AB")).size(.sm) }
    .trailing { Badge("3").badgeStyle(.info) }

ListView(items) { ListRow($0.title) }
    .empty { EmptyState("No results").icon("magnifyingglass") }
    .loadingView { Spinner().style(.dots) }
```

## Config modifiers

Geometry that used to be a raw `CGFloat` now also accepts a theme token, so
spacing and radius stay on the token scale even where a raw override remains
available for edge cases:

```swift
FilterBar(filters, selection: $active)
    .spacing(.sm)          // Theme.SpacingKey, in addition to the raw CGFloat overload
AnimatedImage(gifURL)
    .cornerRadius(.card)   // Theme.RadiusRole, in addition to the raw CGFloat overload
```

And the one color verb across the catalog is `accent(_:)` — `Icon`, `Avatar`,
`ProgressBar`, `ScoreBadge`, `Counter`, `Breadcrumbs`, and more all take a
`SemanticColor?` through the same modifier name, so re-tinting a component
never requires learning a per-component color API.

:::note
See the [Design Principles](/ThemeKit/design/principles/) page for how these
protocols fit the library's broader conventions, and the
[DocC reference](/ThemeKit/api/documentation/themekit/) for every style's full
`Configuration` shape.
:::
