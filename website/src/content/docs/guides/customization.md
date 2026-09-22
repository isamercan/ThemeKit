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

## Chrome styles (your design system's paint)

A host design system often wraps a ThemeKit component and needs its own
tokens, text styles and icon font to match its spec. Chrome styles let it draw
the chrome while ThemeKit keeps the behaviour, content, slots, accessibility,
RTL and state. Each ships only `.default` — the built-in look — and with no
style set the component renders exactly as before.

| Protocol | Modifier | Component |
|---|---|---|
| `ButtonChromeStyle` | `.buttonChromeStyle(_:)` | `ThemeButton` |
| `BadgeChromeStyle` | `.badgeChromeStyle(_:)` | `Badge` |
| `CountBadgeStyle` | `.countBadgeStyle(_:)` | `CountBadge`, `.countBadge(_:)` overlays |
| `IconTileStyle` | `.iconTileStyle(_:)` | `IconTile` |
| `PriceTagStyle` | `.priceTagStyle(_:)` | `PriceTag` |
| `RadioButtonChromeStyle` | `.radioButtonChromeStyle(_:)` | `RadioButton`, `RadioGroup` rows |
| `SkeletonStyle` | `.skeletonStyle(_:)` | `Skeleton`, `.skeleton(_:)`, loading states |
| `DividerStyle` | `.dividerStyle(_:)` | `DividerView`, component separators |
| `CalloutChromeStyle` | `.calloutChromeStyle(_:)` | `Callout` |
| `InlineTextStyle` | `.inlineTextStyle(_:)` | `InlineText`, linked helper text |
| `TooltipStyle` | `.tooltipStyle(_:)` | `.tooltip(…)` bubbles, `InputLabel` info tooltips |
| `TitleStyle` | `.titleStyle(_:)` | `Title` section headers |
| `SegmentedTabBarChromeStyle` | `.segmentedTabBarChromeStyle(_:)` | one `SegmentedTabBar` tab (the style owns the indicator) |
| `ButtonDockChromeStyle` | `.buttonDockChromeStyle(_:)` | the bar of `.buttonDock { }` (ThemeKit keeps the pinning) |
| `SheetHeaderStyle` | `.sheetHeaderStyle(_:)` | `SheetHeader` — the whole layout, outside `BarStyle` |
| `DialogStyle` | `.dialogStyle(_:)` | the fixed-layout dialog card of `.dialog(isPresented:title:…)` and `confirm(…)` (ThemeKit keeps the scrim and dismissal) |

```swift
struct HostButtonChrome: ButtonChromeStyle {
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        HostButtonChromeBody(configuration: configuration)
    }
}

private struct HostButtonChromeBody: View {
    let configuration: ButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let fill = theme.resolve(configuration.color)
        configuration.label
            .textStyle(.labelLg600)                              // re-fonts the title
            .foregroundStyle(fill.onSolid)
            .tint(fill.onSolid)                                  // the loading spinner
            .padding(.horizontal, Theme.SpacingKey.base.value)
            .frame(minHeight: 52)
            .frame(maxWidth: configuration.isFullWidth ? .infinity : nil)
            .background(configuration.isPressed ? fill.active : fill.solid, in: Capsule())
            .opacity(configuration.isEnabled ? 1 : 0.4)
    }
}

RootView().buttonChromeStyle(HostButtonChrome())   // every ThemeButton below
```

The style is read from the environment, so it also reaches the copies ThemeKit
composes inside other components (dialog actions, price tags inside cards, list
separators…). Resolve colors inside the style from `@Environment(\.theme)` so
`theme.custom` tokens and per-subtree `.theme(_:)` both apply. Design rationale:
[ADR-0009](https://github.com/isamercan/ThemeKit/blob/main/docs/ADR-0009-consumer-chrome-styles.md).

`DialogStyle` draws the whole dialog card — its buttons, its width and its
margin from the screen's edges too (ThemeKit adds none around a custom card;
pad by `configuration.stockMargin` to keep the stock clearance). Call each
action's `perform` and the configuration's `onClose`: they carry ThemeKit's
loading and dismissal. Set it on the `.dialog(…)` call's result (or on
`.feedbackHost()`'s, for `confirm(…)`) or an ancestor. The slotted forms —
`.dialog(content:footer:)`, `.dialog(header:content:footer:)`,
`.dialog(content:)` — and `AlertDialog` don't consult it.

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
