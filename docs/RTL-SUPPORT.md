# Right-to-Left (RTL) Support

The library is called *Global* and its examples are travel/hotel flows — markets
that include Arabic, Hebrew, and Farsi. Those languages read right-to-left, and a
design system that ignores that direction looks broken in half the world.

## What SwiftUI gives you for free

A lot. When the locale (or `\.layoutDirection`) is right-to-left, SwiftUI already:

- reverses `HStack` order,
- swaps `.leading` ⇄ `.trailing` (including `.padding(.leading)`, `.frame(alignment:)`),
- flips text alignment and list/navigation transitions.

Because every component here is built from those primitives, the **layout** mirrors
correctly with no per-component work.

## What it does NOT do — and what we fixed

SwiftUI does **not** mirror directional *glyphs*. A `chevron.right` disclosure
arrow keeps pointing right even in an RTL layout, where it should point left.
That's the one thing each component has to opt into.

`mirrorsInRTL()` (in `Accessibility/LayoutDirection.swift`) handles it:

```swift
Icon(systemName: "chevron.right").mirrorsInRTL()   // points left in RTL
```

It's applied to every directional glyph in the library — disclosure chevrons
(`ListRow`, `TreeSelect`, `RatingSummary`), previous/next controls (`Pagination`,
`Carousel`, `CalendarView`), back arrows (`SearchBar`, `PageHeader`), the
`Breadcrumbs` separator, and the `BlogCard` "read more" arrow.

### When to use it (and when not to)

| Use `mirrorsInRTL()` | Leave it alone |
|----------------------|----------------|
| Disclosure chevrons (`chevron.right`/`.left`) | Vertical chevrons (`chevron.up`/`.down`) |
| Previous / next / back / forward arrows | Symmetric icons (`arrow.left.and.right`) |
| "Read more" / progress-direction arrows | Icons whose direction is literal (a real-world map arrow) |

Rule of thumb: if the glyph means "go that way in the reading flow", mirror it.
If it points at a physical thing or has no reading-direction meaning, don't.

## Testing RTL

The snapshot helper renders in either direction:

```swift
func testRow_rightToLeft() {
    assertComponentSnapshot(MyRow(), layoutDirection: .rightToLeft)
}
```

For a quick manual check, force the whole Demo app RTL with the scheme option
*Edit Scheme → Run → Options → App Language → Right-to-Left Pseudolanguage*, or in
a preview:

```swift
#Preview { MyComponent().environment(\.layoutDirection, .rightToLeft) }
```
