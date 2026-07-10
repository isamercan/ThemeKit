# HeroUI → ThemeKit Component-Catalog Gap Plan

**Author:** iOS Architect agent · **Date:** 2026-07-10 · **Status:** PROPOSED — ready for sr-ios-dev implementation
**Axis:** missing *components* relative to HeroUI's catalog (heroui.pro Pro catalog + `heroui-inc/heroui` branch `v3`, `packages/react/src/components`).
**NOT this doc:** cross-cutting infrastructure (providers, slots convention, variant matrix, controlled-state engine) — that is `HEROUI_INFRA_PLAN.md`. Per-component *feature* gaps on existing components — that is `HEROUI_NATIVE_AUDIT.md`. This plan only adds components ThemeKit does not have.

**Ground truth verified in source (2026-07-10, branch `feat/heroui-infra-sprint-1`):**

| Claimed gap | What actually exists | Consequence |
|---|---|---|
| Popover | `.themePopover(isPresented:title:message:...)` (titled card) + `.popconfirm(isPresented:content:)` (custom content) + `PopoverAlign`/`showsArrow` — all shipped in `Organisms/Popconfirm.swift` | Downgraded to a **small refine unit** (custom-content `.themePopover` overload + presenter extraction), not a new component |
| Trend Chip | `StatTrend` (`.up/.down` + spoken a11y) exists but the badge is **private** inside `Molecules/Stat.swift` | Build = **extraction**, not invention |
| Range calendar / date-range picker | `ThemeKitCalendar` add-on ships `DateRangePicker.swift` (opt-in `Calendar` trait, iOS-only) | Skip in core |
| Charts | `PriceTrendChart`/`PriceHistogram` are hand-drawn, domain-specific molecules; **zero** `import Charts` anywhere | Generic Swift Charts family is a real gap |
| Calendar year picker | `Molecules/CalendarView.swift` is a single-month day grid; header title is static text | Real gap |
| DataTable cell editors | `DataTable.Column` already accepts arbitrary `@ViewBuilder` cells | Build = **prebuilt editor cell views**, not table surgery |
| ControllableState | Shipped on this branch: `Sources/ThemeKitCore/ControllableState.swift` (`@MainActor` accessors, optional external binding) | New stateful components MUST use it |
| Backdrop | Shipped: `Atoms/Backdrop.swift` + `bgBackdrop` token (infra unit 2) | Command palette scrim reuses it |

---

## 1. Development rules (binding for every unit below)

Distilled from the `themekit-authoring` skill, the token-fed-modifiers rule, and the shipped infra conventions. The implementer follows these without exception.

1. **Stateless & data-driven.** Value types and provider closures in; no `ObservableObject`, no `Task`, no networking, no backend DTOs. Local UI-only `@State` (drag position, hover flag) is fine.
2. **Generic & brand-neutral.** No travel/Voyage coupling in these components; no "ets"/"etstur" anywhere. All user-facing strings **English only**, wrapped `String(themeKit:)` / `String(localized:bundle:.module)`.
3. **Init = required content + bindings + actions. Nothing else.** No `size:`, `variant:`, `isEnabled:` init parameters.
4. **All appearance = chainable copy-on-write modifiers** in a `public extension`, each routed through one private `copy(_ mutate: (inout Self) -> Void) -> Self` mutation point.
5. **Token-fed modifier signatures — the hard rule.** Override/customization modifiers take **theme token keys only**: `SemanticColor`, `Theme.RadiusRole`/`RadiusKey`, `Theme.SpacingKey`, `Theme.BackgroundColorKey`/`TextColorKey`, `TextStyle`, `Motion`, or a component-semantic enum that resolves to tokens. **Never raw `Color` or magic `CGFloat`.** Two sanctioned exceptions: (a) *color-as-data* — a `Binding<Color>`/`Color` that is the component's **content** (ColorField precedent: the user's picked color is data, not chrome); (b) *genuine geometry with no semantic token* (chart height, aspect ratio) — fixed internal constants or documented raw-geometry knobs, PriceTrendChart precedent ("Chart geometry is a legitimate raw-CGFloat knob").
6. **Native modifiers for native concepts.** Disabled → `.disabled(_:)` read via `@Environment(\.isEnabled)`; size where it maps → `.controlSize(_:)`; else a per-component `<Component>Size` enum.
7. **Optional slots = `@ViewBuilder` slot modifiers storing `AnyView?`** — never extra init overloads, never generic slot type parameters. Use the canonical vocabulary from `HEROUI_INFRA_PLAN.md` T2: `.header{}`, `.footer{}`, `.leading{}`, `.trailing{}`, `.label{}`, `.indicator{}`, `.emptyContent{}`. Required content stays a type-preserved generic `@ViewBuilder` init parameter.
8. **Controlled/uncontrolled state = `ControllableState`** (`Sources/ThemeKitCore/ControllableState.swift`). Dual inits: `initiallyX:` seeds the uncontrolled path; an overload takes `x: Binding<…>` for the controlled path (Accordion precedent). Presentation is `isPresented: Binding<Bool>`; selection is `selection: Binding<…>`. No `onXChange` callback pairs — the Binding is the change channel. Value-editing components (sliders, pickers) are controlled-only by nature: a required Binding is correct (Slider/CalendarView precedent).
9. **The Style-protocol recipe** (only for organisms with multiple fundamentally different layouts — do NOT add one speculatively):
   - `public struct <X>StyleConfiguration` — typed data + captured `locale`/flags/callbacks; content arrives as `AnyView` where pre-composed.
   - `public protocol <X>Style { associatedtype Body: View; @ViewBuilder @MainActor func makeBody(configuration:) -> Body }`.
   - One public struct per archetype, thin over a `private …Chrome` view; static accessors via `public extension <X>Style where Self == Concrete<X>Style { static var name … }`.
   - Erasure: `struct Any<X>Style: <X>Style { init<S: <X>Style>(_ style: sending S) { … } }` storing a `@MainActor (Configuration) -> AnyView` closure.
   - Plumbing: `private struct <X>StyleKey: EnvironmentKey` with the default style; **internal** `EnvironmentValues.<x>Style` accessor; **public** `func <x>Style<S: <X>Style>(_ style: sending S) -> some View` view modifier.
   - Copy an existing one verbatim (`Organisms/CardStyle.swift` is the cleanest reference; `ListRowStyle.swift`, `PageHeaderStyle.swift` for richer configurations).
10. **Motion is token-gated.** Every animation uses `Motion` tokens (`.instant/.fast/.base/.slow/.slower`, `.animation`/`.spring`) through `MicroMotion.animation(_:enabled:reduceMotion:)` with `@Environment(\.microAnimations)` + `@Environment(\.accessibilityReduceMotion)`. Gestures keep working with motion off; only the animation drops.
11. **Accessibility by construction.** Every non-text control gets `.accessibilityLabel`; togglers get state-aware labels; selected items get `.isSelected`; adjustable controls get `accessibilityAdjustableAction` + spoken `accessibilityValue`; tap targets ≥ 44pt (CalendarView precedent: visual 36pt circle inside a 44pt frame); stable test ids via `.a11yID("…")` where the convention exists. Dynamic Type via `.textStyle(_:)` — never `.font(.system(size:))` for text.
12. **RTL-safe by construction.** Compose from `HStack`/`VStack` (auto-mirroring); `leading`/`trailing` never `left`/`right`; hand-drawn `Path`s get `.flipsForRightToLeftLayoutDirection(true)`; drag math reads `@Environment(\.layoutDirection)`. Dates/numbers format with the captured `locale` (`.formatted(….locale(locale))`), overridable via a `.locale(_:)` modifier.
13. **Placement & naming.** Atom = smallest reusable unit → `Components/Atoms/`; molecule = a few atoms + light logic → `Components/Molecules/`; organism = shipped multi-part component → `Components/Organisms/`. Sub-views stay `private` in the same file; shared models go in `<Component>Models.swift`. `PascalCase` types, booleans read `is…/has…/should…`. Compose existing atoms (Icon, Badge, Kbd, CountBadge, Backdrop, SearchField, RollingNumber, Confetti) — never re-implement one.
14. **Every component ships with:** (a) a `#Preview` exercising **every** variant/enum (`ForEach(….allCases)`) plus a themed/dark case; (b) a Demo entry in `Demo/Demo/Gallery/ComponentRegistry.swift` (`.knob("Name", .category, demo: NameDemo(), usage: #"…"#, isNew: true)` or `.static`), verified live via `xcrun simctl launch <bundle> -startTab 0 -openDemo "<Name>"`; (c) inclusion in the snapshot/a11y/RTL harness; (d) unit tests where there is logic (sorting, color math, filtering).
15. **Purely additive.** The library is public at v1.0.0. No renames, no signature changes, no new external dependencies. Swift Charts (`import Charts`) is a system framework and is allowed. Anything that must change existing API is deprecate-and-forward with a migration note — none is anticipated in this plan.

---

## 2. Validated gap table

Placement: A = atom, M = molecule, O = organism. "Style proto" = needs a new `…Style` protocol.

### Build

| Component | Layer | Style proto | Rationale | Verdict |
|---|---|---|---|---|
| ThemePopover custom content | O (modifier) | No | `.themePopover` titled + `.popconfirm(content:)` exist; the *generic content popover under the right name* + shared internal presenter is the missing 10% that Wave-2 components build on | **Build (refine)** — Wave 1 |
| ColorSwatch | A | No | Nothing renders a labeled color chip (alpha checkerboard, selection ring) | **Build** — Wave 1 |
| ColorSwatchPicker | M | No | No preset-palette grid picker; composes ColorSwatch | **Build** — Wave 1 |
| ColorSlider | M | No | ColorField only wraps the *system* ColorPicker; no in-canvas channel slider | **Build** — Wave 1 |
| ColorArea | M | No | No 2D saturation×brightness plane; pairs with ColorSlider via a shared HSBA model | **Build** — Wave 1 |
| CalendarYearPicker | M | No | CalendarView header is static text; no year/month jump (HeroUI `calendar-year-picker`) | **Build** — Wave 1 |
| TrendChip | A | No | `StatTrend` badge exists but is private to Stat; HeroUI Pro ships it standalone | **Build (extract)** — Wave 1 |
| LineChart | M | No | No generic charts; PriceTrendChart is domain-specific + hand-drawn | **Build** — Wave 2 |
| AreaChart | M | No | Sibling of LineChart (shared internals + `ChartSeries` model) | **Build** — Wave 2 |
| BarChart | M | No | Generic grouped/stacked bars via Swift Charts | **Build** — Wave 2 |
| DonutChart | M | No | Pie/donut via `SectorMark` (iOS 17 ✓) | **Build** — Wave 2 |
| HoverCard | M (modifier) | No | Long-press/pointer-hover preview card; rides the Wave-1 presenter | **Build** — Wave 2 |
| CommandPalette | O | No | ⌘K palette; composes SearchField + Kbd + Backdrop | **Build** — Wave 2 |
| ActionBar | O | No | Contextual multi-select floating bar; nothing covers it (ButtonDock is static) | **Build** — Wave 2 |
| Agenda | O | No | Date-grouped event list with time rail; Timeline is a progress rail, different job | **Build** — Wave 3 |
| Table cell editors | M ×4 | No | Prebuilt `TableToggleCell`/`TableSelectCell`/`TableSliderCell`/`TableColorCell` for DataTable's existing custom-cell slot | **Build** — Wave 3 |
| ThemeContextMenu | M (modifier) | No | Data-driven wrapper over native `.contextMenu` + preview slot; chrome stays native (honest limit) | **Build** — Wave 3 |
| EmojiReactionButton | M | No | Reaction toggle + count + burst; composes RollingNumber + Confetti-style burst | **Build** — Wave 3 |
| ColorPickerPanel | O | No | HeroUI `color-picker`: composes ColorArea + ColorSlider + ColorSwatchPicker + hex TextInput | **Build** — Wave 3 |
| KanbanBoard | O | No (card is a required `@ViewBuilder` closure) | Board with columns + cross-column drag; biggest single unit | **Build** — Wave 3 |

### Skip (covered — covering component named)

| HeroUI component | Covered by | 
|---|---|
| Popover (as a new component) | `.themePopover` + `.popconfirm(isPresented:content:)` (`Organisms/Popconfirm.swift`); Wave-1 unit closes the naming/extraction remainder |
| Range Calendar / Date Range Picker | `ThemeKitCalendar/DateRangePicker.swift` (opt-in trait add-on; core stays lean) |
| Carousel | `Organisms/Carousel.swift`, `PagingCarousel.swift` |
| File Tree | `Molecules/TreeView.swift` |
| Floating TOC | `Molecules/AnchorNav.swift` |
| Item Card / Item Card Group | `Organisms/Card.swift`, `SelectionCards.swift`, `MenuCard.swift` |
| KPI / KPI Group | `Molecules/Stat.swift` + `StatStyle.swift` + `ColumnsGrid` |
| Number Value | `Atoms/RollingNumber.swift` |
| Pressable Feedback | Audit item (ThemeButton press-feedback variants) — `HEROUI_NATIVE_AUDIT.md`, not a new component |
| Rating | `Atoms/Rating.swift` |
| Resizable | `Molecules/Splitter.swift` |
| Number Stepper | `Molecules/InputNumber.swift`, `QuantityStepper.swift` |
| Drop Zone | `Molecules/FileInput.swift`, `Organisms/Upload.swift` |
| Inline Select / Native Select | `Molecules/Select.swift`, `SelectBox.swift`, `Dropdown.swift` |
| Checkbox/Radio Button Group | `Molecules/CheckboxGroup.swift`, `RadioGroup.swift`, `ToggleGroup.swift` |
| Navbar | `Organisms/NavigationBar.swift` |
| Segment | `Molecules/SegmentedControl.swift`, `Organisms/SegmentedTabBar.swift` |
| Stepper (navigation) | `Molecules/Steps.swift`, `ProgressIndicator.swift` |
| Sheet | `Organisms/BottomSheet.swift`, `Drawer.swift` |
| Chart Tooltip | Folded into each chart's built-in scrub annotation (see Wave 2) — not a standalone component in SwiftUI |
| Combo Box | `Molecules/Autocomplete.swift` |
| Empty State, Timeline, List View, Kbd, Scroll Shadow, Code Block, Skeleton, Meter, … (core catalog) | Same-named ThemeKit components — verified present |

### Defer / out of scope

| Component | Verdict | Why |
|---|---|---|
| RadarChart | **Defer** | Not supported by Swift Charts; needs bespoke `Path` polar geometry + RTL/axis-label work for a niche form. Revisit after the core four ship |
| RadialChart (radial bars) | **Defer** | Same: custom polar drawing, low demand; `RadialProgress`/`GaugeView` cover the common cases |
| ComposedChart | **Defer** | Swift Charts composes marks natively inside one `Chart{}`; a generic "composed" wrapper would be an API without a shape. Document composition in DocC instead |
| Data Grid | **Defer** | Virtualized editable grid (column resize, pinning) is an engine, not a component; `DataTable` + Wave-3 cell editors cover the realistic SwiftUI use |
| AppLayout | **Defer** | `NavigationSplitView` already is the responsive shell on Apple platforms; ThemeKit ships the pieces (Sidebar, NavigationBar, PageHeader, Footer). A wrapper would fight native navigation state. Revisit as a DocC "app shell recipe" |
| Map | **Skip** | MapKit integration is app domain; ThemeKit ships map *overlays* (`MapCallout`, `MapPriceMarker`) |
| Rich Text Editor | **Skip** | Stateful editing engine; violates the stateless/zero-dep charter |
| Emoji Picker | **Skip** | The system keyboard is the emoji picker on Apple platforms; a custom grid duplicates it worse |
| Widget | **Skip** | Amorphous container; `Card` + slots covers it |
| AI family (15 components: Chat*, Prompt*, Markdown, Chain of Thought, …) | **Non-goal** | Explicitly out of scope for this sweep (`CodeBlock` already exists; `ChatBubble` covers the message primitive) |

---

## 3. Sequenced waves

PR-per-component. Every PR: component + `#Preview` matrix + ComponentRegistry entry (`isNew: true`) + snapshot/a11y/RTL harness + deep-link verification.

### Wave 1 — foundations & small parity wins (6 PRs, full ADRs in §4)

| # | Unit | Effort | Depends on |
|---|---|---|---|
| 1.1 | AnchoredPopover extraction + `.themePopover(isPresented:content:)` | low | — (foundation for 2.5, 3.3) |
| 1.2 | ColorSwatch + ColorSwatchPicker | low | — |
| 1.3 | `HSBAColor` model + ColorSlider | medium | — |
| 1.4 | ColorArea | medium | 1.3 (shares `HSBAColor`) |
| 1.5 | CalendarYearPicker + CalendarView wiring | medium | — |
| 1.6 | TrendChip (extract from Stat) | low | — |

### Wave 2 — charts & anchored surfaces (6 PRs)

| # | Unit | Effort | Depends on |
|---|---|---|---|
| 2.1 | `ChartModels` (ChartSeries/ChartPoint/ChartPalette) + LineChart | medium | — |
| 2.2 | AreaChart | low | 2.1 |
| 2.3 | BarChart | medium | 2.1 |
| 2.4 | DonutChart | medium | 2.1 |
| 2.5 | HoverCard | medium | 1.1 |
| 2.6 | CommandPalette | high | Kbd, SearchField, Backdrop (all shipped) |

### Wave 3 — larger organisms & conveniences (7 PRs)

| # | Unit | Effort | Depends on |
|---|---|---|---|
| 3.1 | ActionBar | medium | — |
| 3.2 | Agenda | medium | — |
| 3.3 | ThemeContextMenu | low | 1.1 (preview-card reuse is optional; native path has no dep) |
| 3.4 | Table cell editors (4 cells, one PR) | medium | — |
| 3.5 | EmojiReactionButton | low | — |
| 3.6 | ColorPickerPanel | medium | 1.2, 1.3, 1.4 |
| 3.7 | KanbanBoard | high | — |

Cross-wave dependencies, explicitly: **1.1 → 2.5** (HoverCard presents through the extracted presenter); **1.3 → 1.4 → 3.6** (HSBA model → area → panel); **2.1 → 2.2/2.3/2.4** (shared series model + categorical palette); everything else is independent and parallelizable.

---

## 4. Wave-1 ADR specs

### 4.1 AnchoredPopover extraction + `.themePopover(isPresented:content:)`

**Decision.** Popover parity is ~90% shipped; do not build a `Popover` component. Instead: (a) move the private `PopconfirmPresenter`, `PopconfirmSurface` (and reference the existing internal `TooltipArrow`/`PopoverTapCatcher`) into a new internal home so Wave-2/3 components can present through them; (b) add the one missing public surface — custom content under the *popover* name.

**Files.** New `Sources/ThemeKit/Components/Organisms/AnchoredPopover.swift` (internal `AnchoredPopoverPresenter<Card: View>: ViewModifier` = today's `PopconfirmPresenter` verbatim; internal `AnchoredCardSurface: ViewModifier` = today's `PopconfirmSurface`). `Popconfirm.swift` shrinks to the popconfirm/themePopover modifiers calling the shared internals. Pure move — zero public API change from the move itself.

**Public API (additive).**
```swift
public extension View {
    /// Anchored popover with fully custom content on the standard card shell
    /// (white surface, hairline, elevated shadow). Same presentation engine as
    /// `.popconfirm` / the titled `.themePopover`: edge + align placement,
    /// outside-tap dismissal, optional arrow, micro-motion fade+scale.
    func themePopover<V: View>(
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false,
        @ViewBuilder content: () -> V
    ) -> some View
}
```
No copy-on-write modifiers — this is a presentation view-modifier family (Tooltip/Popconfirm precedent); its knobs are parameters, matching the shipped siblings exactly.

**Tokens.** All inherited from the moved internals: `bgWhite` surface, `borderPrimary` hairline, `RadiusKey.sm`, `SpacingKey.md`, `.elevated` shadow, `MicroMotion.animation(.fast, …)`.

**Controlled/uncontrolled.** Controlled only (`isPresented: Binding<Bool>`), consistent with `.popconfirm`/`.themePopover`. (A self-managed variant exists on `.tooltip`; presenters with arbitrary content stay binding-driven.)

**A11y/RTL.** Inherited: `.accessibilityAddTraits(.isModal)` + `.accessibilityAction(.escape)` on the card; arrow already `.flipsForRightToLeftLayoutDirection(true)`; leading/trailing edges mirror via `TooltipEdge`.

**Risks.** (1) Overload ambiguity between titled and content `themePopover` — none: distinguished by `title:` vs trailing closure labels. (2) The 260pt fixed card width lives in `AnchoredCardSurface`; the audit's `[low]` `PopoverWidth` item should later land *there* once, benefiting all four modifiers — do not implement it in this PR, just leave the seam. **Open question for sr-ios-dev:** should `.popconfirm(isPresented:content:)` get a doc-comment steer ("prefer `.themePopover(content:)` for non-confirmation content")? Recommend yes, no deprecation.

**Call site.**
```swift
@State private var showFilters = false
IconButtonRow()
    .themePopover(isPresented: $showFilters, edge: .bottom, align: .end, showsArrow: true) {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text("Quick filters").textStyle(.labelBase600)
            ToggleGroup(…)
        }
    }
```

**Verify.** `-openDemo "Popover"` (new registry entry grouping tooltip/popconfirm/themePopover demos); existing Popconfirm snapshots must be byte-identical after the move.

---

### 4.2 ColorSwatch (atom) + ColorSwatchPicker (molecule)

**Decision.** Two components, one PR. `ColorSwatch` renders one color chip: alpha checkerboard underlay, hairline border, optional selection ring. `ColorSwatchPicker` lays swatches in a grid and drives a required selection binding. The swatch color is **content, not chrome** (rule 5a) — raw `Color` in init is correct here, exactly like `ColorField`'s `Binding<Color>`.

**Files.** `Sources/ThemeKit/Components/Atoms/ColorSwatch.swift`, `Sources/ThemeKit/Components/Molecules/ColorSwatchPicker.swift`.

**Public API.**
```swift
public enum ColorSwatchShape: CaseIterable { case square, circle }   // square → RadiusRole.selector
public enum ColorSwatchSize: CaseIterable { case small, medium, large }  // 20 / 28 / 36pt internal constants

public struct ColorSwatch: View {
    /// `label` is the spoken/name identity of the color ("Crimson"); required
    /// because a bare color is invisible to VoiceOver.
    public init(_ color: Color, label: String)
}
public extension ColorSwatch {
    func shape(_ s: ColorSwatchShape) -> Self
    func size(_ s: ColorSwatchSize) -> Self
    func selected(_ on: Bool = true) -> Self       // hero-token ring: theme.border(.borderHero), 2pt
}

public struct ColorSwatchItem: Identifiable, Equatable {
    public let id: String            // defaults to label
    public let color: Color
    public let label: String
    public init(_ color: Color, label: String, id: String? = nil)
}

public struct ColorSwatchPicker: View {
    public init(_ items: [ColorSwatchItem], selection: Binding<ColorSwatchItem?>)
}
public extension ColorSwatchPicker {
    func columns(_ n: Int?) -> Self               // nil (default) = FlowLayout wrap; n = LazyVGrid
    func swatchShape(_ s: ColorSwatchShape) -> Self
    func swatchSize(_ s: ColorSwatchSize) -> Self
}
```

**Tokens.** Checkerboard cells: `theme.background(.bgSecondaryLight)` on `.bgWhite`; border `theme.border(.borderPrimary)` 1pt; selection ring `borderHero` 2pt (+ a contrast-safe inner `bgWhite` ring, 1pt, so the selection reads on dark swatches); square radius `Theme.RadiusRole.selector.value`; grid spacing `Theme.SpacingKey.sm.value`; selection change animated `MicroMotion.animation(.fast, …)`.

**Controlled/uncontrolled.** Picker is controlled-only (`selection: Binding<ColorSwatchItem?>`) — it is a value editor (rule 8). Swatch is stateless.

**A11y/RTL.** Each swatch in the picker is a `Button` with `.accessibilityLabel(item.label)`, `.accessibilityAddTraits(.isSelected)` when selected, ≥ 44pt tap frame around the visual chip (CalendarView pattern). Grid mirrors automatically (LazyVGrid/FlowLayout). No text inside swatches → no Dynamic Type hazard; the label is a11y-only.

**Risks.** Checkerboard drawing — use a tiny `Canvas` or two offset fills, fixed 4pt cells (genuine geometry, internal constant). `Color` equality for selection is unreliable across color spaces → selection keys off `ColorSwatchItem.id`, never off `Color` — that is why the item type exists.

**Call site.**
```swift
@State private var brand: ColorSwatchItem?
ColorSwatchPicker(ColorSwatchItem.demoPalette, selection: $brand)
    .columns(6).swatchShape(.circle).swatchSize(.large)
```

**Verify.** `-openDemo "Color Swatch Picker"`; preview matrix: both shapes × three sizes × selected/unselected × an alpha color; dark theme case.

---

### 4.3 HSBAColor model + ColorSlider (molecule)

**Decision.** Custom color internals need one shared, platform-safe value model; SwiftUI's `Color` cannot be decomposed portably. Ship `HSBAColor` (plain `Equatable`/`Sendable` struct) in `ColorModels.swift`, plus `ColorSlider` — an in-canvas channel slider with a token-ringed thumb over a computed gradient track.

**Files.** `Sources/ThemeKit/Components/Molecules/ColorModels.swift` (HSBAColor + `Color` bridging), `Sources/ThemeKit/Components/Molecules/ColorSlider.swift`.

**Public API.**
```swift
/// Hue/saturation/brightness/alpha in 0…1. The working currency of ColorSlider,
/// ColorArea and ColorPickerPanel — bridge to `Color` at the edges.
public struct HSBAColor: Equatable, Sendable {
    public var hue, saturation, brightness, alpha: Double   // clamped 0…1
    public init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1)
    public init(_ color: Color)        // resolves via platform color (see Risks)
    public var color: Color            // Color(hue:saturation:brightness:opacity:)
}

public enum ColorChannel: CaseIterable { case hue, saturation, brightness, alpha }

public struct ColorSlider: View {
    public init(_ channel: ColorChannel, color: Binding<HSBAColor>)
}
public extension ColorSlider {
    func trackHeight(_ h: ColorSliderTrackHeight) -> Self   // .regular / .compact enum — not a CGFloat
}
```

**Tokens.** Thumb: 28pt circle (internal constant, ≥ 44pt hit frame), filled with the *current* channel color, ringed `theme.background(.bgWhite)` 2pt + `borderPrimary` hairline (the dataviz "surface ring" rule); track corner `Capsule`; alpha track over the same checkerboard as ColorSwatch; focus/drag scale gated `MicroMotion.animation(.fast, …)`.

**Behavior.** Track gradient computed per channel from the bound color (hue → 7-stop rainbow at current S/B; saturation → gray→hue; brightness → black→hue; alpha → clear→opaque over checkerboard). Drag updates only that channel through the binding.

**Controlled/uncontrolled.** Controlled-only (`Binding<HSBAColor>`) — value editor.

**A11y/RTL.** `.accessibilityLabel` per channel ("Hue", "Saturation", …, `String(themeKit:)`), `accessibilityValue` as spoken percent, `accessibilityAdjustableAction` stepping ±5%. Drag math: `x / width` flipped when `layoutDirection == .rightToLeft`; gradient uses `UnitPoint.leading/.trailing` (auto-mirrors) so visuals and math stay in sync.

**Risks.** (1) `Color → HSBA` bridging: `UIColor.getHue` on iOS; on macOS `NSColor` must be converted with `usingColorSpace(.deviceRGB)` first or it traps on catalog colors — the `HSBAColor.init(_:)` doc must state it falls back to `(0,0,1,1)`-ish defaults when resolution fails, never traps. (2) Hue = 1.0 wraps to 0 — clamp to `0…0.9999` internally so the thumb doesn't snap. (3) Gradient stop count for hue: 7 fixed stops is visually sufficient; do not resample per-pixel.

**Call site.**
```swift
@State private var working = HSBAColor(hue: 0.6, saturation: 0.8, brightness: 0.9)
VStack(spacing: Theme.SpacingKey.md.value) {
    ColorSlider(.hue, color: $working)
    ColorSlider(.alpha, color: $working).trackHeight(.compact)
}
```

**Verify.** `-openDemo "Color Slider"` (all four channels bound to one color, live swatch preview); RTL screenshot; unit tests on HSBA clamp/bridge math.

---

### 4.4 ColorArea (molecule)

**Decision.** The 2D saturation (x) × brightness (y) plane for the bound color's hue — the missing piece between ColorSlider and a full picker. Rendering is two layered gradients (white→hue horizontal wash, transparent→black vertical) — cheap, standard, no Canvas per-pixel work.

**Files.** `Sources/ThemeKit/Components/Molecules/ColorArea.swift` (shares `HSBAColor`).

**Public API.**
```swift
public struct ColorArea: View {
    public init(color: Binding<HSBAColor>)
}
public extension ColorArea {
    func cornerRadius(_ role: Theme.RadiusRole) -> Self    // default .field — token-typed per rule 5
}
```
(Height: fixed 4:3 aspect via `.aspectRatio` internally — genuine geometry; callers size it with standard `frame` like any view.)

**Tokens.** Border `theme.border(.borderPrimary)` 1pt on the plane; thumb identical spec to ColorSlider's (current color fill + `bgWhite` 2pt surface ring + hairline); radius from the `RadiusRole` (capped via the shipped `value(cappedFor:)` helper against the plane height); drag snap animation `MicroMotion.animation(.fast, …)` (position tracking itself is unanimated — it follows the finger).

**Controlled/uncontrolled.** Controlled-only (`Binding<HSBAColor>`); updates `saturation` + `brightness`, reads `hue`/`alpha`.

**A11y/RTL.** Single adjustable element: `accessibilityLabel("Saturation and brightness")`, `accessibilityValue` speaking both percents; `accessibilityAdjustableAction` adjusts **brightness**; two custom actions ("Increase saturation"/"Decrease saturation") cover the second axis — the pattern VoiceOver users actually get on system color panes. Saturation axis flips with `layoutDirection`; brightness (vertical) does not.

**Risks.** (1) Thumb must stay draggable at the plane's edges — inset the thumb center clamp by half the thumb, not the value range (values still reach exactly 0/1). (2) Gesture vs ScrollView conflict in the demo — use `.gesture(DragGesture(minimumDistance: 0))` and document that hosts should not wrap it in a same-axis scroll. (3) Keep the two gradients in one `ZStack` compositing group so dark-mode blending doesn't shift the rendered color.

**Call site.**
```swift
@State private var working = HSBAColor(hue: 0.08, saturation: 0.9, brightness: 0.95)
VStack(spacing: Theme.SpacingKey.md.value) {
    ColorArea(color: $working).cornerRadius(.box)
    ColorSlider(.hue, color: $working)
}
```

**Verify.** `-openDemo "Color Area"`; RTL + dark snapshots; unit test: drag-point → (s, b) mapping incl. clamps and RTL flip.

---

### 4.5 CalendarYearPicker (molecule) + CalendarView wiring

**Decision.** Two additive pieces: a standalone `CalendarYearPicker` (paged 12-year grid, HeroUI `calendar-year-picker`), and an **opt-in** `.yearPicker(true)` on `CalendarView` that turns the static "July 2026" header into a button flipping the day grid to year → month stages. Opt-in (default off) so existing snapshots and the non-interactive header contract don't churn.

**Files.** `Sources/ThemeKit/Components/Molecules/CalendarYearPicker.swift`; `Molecules/CalendarView.swift` (additive: one modifier + a private stage enum + two private grids).

**Public API.**
```swift
public struct CalendarYearPicker: View {
    public init(selection: Binding<Int>)          // Gregorian-agnostic: year number in the active calendar
}
public extension CalendarYearPicker {
    func range(_ years: ClosedRange<Int>) -> Self  // default: (currentYear - 100)...(currentYear + 20)
    func accent(_ color: SemanticColor?) -> Self   // nil = hero tokens (CalendarView precedent)
}

public extension CalendarView {
    /// Makes the month-year header tappable: day grid → year grid → month grid,
    /// then back to the chosen month. Off by default.
    func yearPicker(_ enabled: Bool = true) -> Self
}
```

**Tokens.** Cell chrome copies CalendarView's day cells exactly: selected fill `accent?.solid ?? theme.background(.bgHero)`, selected text `accent?.onSolid ?? theme.foreground(.fgSecondary)`, current-year ring `accent?.border ?? theme.border(.borderHero)`; text `.textStyle(.bodyBase400)`; grid spacing `SpacingKey.sm`; stage flip animated `MicroMotion.animation(.base, …)` (cross-fade only under Reduce Motion).

**Behavior.** 3×4 grid of years per page; chevron paging by 12 (reusing CalendarView's `navButton` pattern incl. `mirrorsInRTL()` + 44pt targets); year labels formatted `year.formatted(.number.grouping(.never).locale(locale))` so localized digits render correctly. The CalendarView month stage is a 3×4 grid of `calendar.shortMonthSymbols` honoring the captured locale.

**Controlled/uncontrolled.** Controlled-only (`selection: Binding<Int>`); inside CalendarView the stage state is private `@State` (pure UI navigation), and the displayed month remains internal exactly as today.

**A11y/RTL.** Header button gets a state-aware label ("Choose year" / "Back to days", `String(themeKit:)`); year/month cells: `.accessibilityLabel` (full month name / spoken year), `.isSelected` trait; grids mirror automatically; chevrons mirrored.

**Risks.** (1) `Calendar.component(.year, …)` vs non-Gregorian calendars — always read/write years through the *captured* `calendar` (CalendarView already builds one from `\.locale`), never hardcode ranges against Gregorian assumptions. (2) Keep the header layout identical when `yearPicker` is off — zero visual diff for existing users. (3) Stage height jump between 6-row day grid and 4-row year grid — fix the grid container height to the day-grid height so the card doesn't pump.

**Call site.**
```swift
@State private var date: Date?
CalendarView(selection: $date).yearPicker()        // header now jumps to any month/year

@State private var year = 2026
CalendarYearPicker(selection: $year).range(2000...2030).accent(.success)
```

**Verify.** `-openDemo "Calendar"` (new year-picker knob) + `-openDemo "Calendar Year Picker"`; snapshot: default CalendarView unchanged; RTL chevron check.

---

### 4.6 TrendChip (atom, extraction)

**Decision.** Publish Stat's private trend badge as a standalone atom and have Stat consume it (behavior-neutral). Reuse the existing public `StatTrend` enum unchanged — **do not add cases** (a new case breaks consumers' exhaustive switches).

**Files.** `Sources/ThemeKit/Components/Atoms/TrendChip.swift`; `Molecules/Stat.swift` (private `trendBadge` body replaced by `TrendChip`, rendering pixel-identical).

**Public API.**
```swift
public struct TrendChip: View {
    public init(_ trend: StatTrend)               // .up("+12%") / .down("-3%")
}
public extension TrendChip {
    /// Whether an upward trend is the good outcome (default true). `false`
    /// flips the semantic mapping — a falling price is a success.
    func positiveIsUp(_ on: Bool = true) -> Self
    func showsIcon(_ on: Bool = true) -> Self
    func size(_ s: TrendChipSize) -> Self          // .small / .medium — labelSm600 / labelBase600
}
```

**Tokens.** Good direction: `theme.background(.systemcolorsBgSuccessLight)` fill + `theme.foreground(.systemcolorsFgSuccess)`; bad: the error pair — via the `SemanticColor.success/.error` soft/accent roles if that is what Stat's current badge resolves to (implementer: match Stat's exact current token pair, then reuse). Shape `Capsule`; padding `SpacingKey.xs/.sm`; arrows `arrow.up.right`/`arrow.down.right` (Stat's glyphs).

**Controlled/uncontrolled.** Stateless.

**A11y/RTL.** Port Stat's spoken-direction a11y verbatim (label reads "up 12 percent", never the bare glyph); the diagonal-arrow glyphs are directional but *slope*, not reading-direction — do **not** mirror them (matches Stat today); HStack layout mirrors fine.

**Risks.** Only the Stat regression: guard with the existing Stat snapshot — the refactor must be pixel-identical. Keep `positiveIsUp` out of Stat's surface for now (Stat's semantics are unchanged; the flag is TrendChip-only until someone asks).

**Call site.**
```swift
HStack {
    Text("$412").textStyle(.headingSm)
    TrendChip(.down("-8%")).positiveIsUp(false)    // price drop = green
}
```

**Verify.** `-openDemo "Trend Chip"`; Stat snapshots unchanged; preview matrix: up/down × positiveIsUp × sizes.

---

## 5. Wave 2–3 sketches (1 paragraph each)

**2.1 ChartModels + LineChart** (`Molecules/Charts/ChartModels.swift`, `LineChart.swift`). Shared value model: `ChartPoint` (`x: Date|Double|String` via a small `ChartXValue` enum, `y: Double`), `ChartSeries` (`label`, `[ChartPoint]`, optional explicit `SemanticColor`). **Categorical color law (from the dataviz method, encoded in `ChartPalette`):** a *fixed, ordered* slot list of non-status hues — `[.primary, .orange, .turquoise, .purple, .pink, .info]` — assigned to series in sequence, never cycled, never re-assigned when a series is filtered out (color follows the entity); > 6 series folds the tail into an "Other" series in `.neutral`; `success/warning/error` are **reserved status hues** and only appear when a caller sets `series.color` explicitly. Implementer must validate the default theme's six resolved hex values once with the dataviz palette validator (adjacent-pair CVD ≥ 8 with the mandatory secondary encoding: legend + direct end-labels) and record the result in the PR. Marks: 2pt round-join lines, ≥ 8pt end markers with a 2pt surface ring; axis/grid hairlines in `borderPrimary`, tick text `.textStyle(.overline400)` in `textTertiary` — **text never wears the series color**. Legend: auto for ≥ 2 series, none for one. Built-in scrub selection via `chartXSelection` with a token-styled annotation card (this is the "Chart Tooltip" answer); selection exposed dual-mode via `ControllableState` (`initiallySelected:` rarely useful, so: uncontrolled by default, `selection: Binding<ChartXValue?>` overload). One `.animation(Motion.base, …)` on data changes gated by MicroMotion. API shape: `LineChart(_ series: [ChartSeries])` + `.height(_ h: ChartHeight)` (semantic enum `.compact/.regular/.tall` — internal constants), `.showsLegend(_:)`, `.showsGrid(_:)`, `.locale(_:)`, `.curved(_:)` (monotone interpolation), `.labeled(_:)` (selective end-labels, default on for ≤ 4 series).

**2.2 AreaChart.** `AreaChart(_ series: [ChartSeries])`, same surface as LineChart plus `.stacked(_:)`; fill is the series hue at ~10% opacity (a wash) under a 2pt line — the dataviz area spec; shares every internal with LineChart (one file may host both chromes).

**2.3 BarChart.** `BarChart(_ series: [ChartSeries])` with `.grouped`/`.stacked` via `.mode(_ m: BarChartMode)`; bars ≤ 24pt thick with 4pt rounded data-end (square at baseline — `.clipShape` per-mark), 2pt surface gaps between stacked segments and touching bars; one baseline, **never** a dual axis; per-mark hover/scrub annotation like LineChart.

**2.4 DonutChart.** `DonutChart(_ slices: [ChartSlice])` (`ChartSlice`: label, value, optional `SemanticColor`) via `SectorMark(angularInset:)` for the 2pt surface gaps; `.innerRadius(_ r: DonutRatio)` semantic enum (`.pie/.ring/.thin`); center slot via `.label {}` slot modifier for a hero figure; legend always (identity is otherwise color-alone on a donut); ≤ 6 slices then "Other" fold, same palette law as 2.1.

**2.5 HoverCard.** `.hoverCard(edge:align:) { content }` view modifier presenting the 1.1 presenter's card from **long-press** (0.35s, haptic via the existing Haptics util) on touch, and pointer **hover** (`.onHover`/`hoverEffect`, 0.5s intent delay) on iPad/macOS; self-managed `@State` presentation (gesture-driven; no binding overload — pressing is the intent), `PopoverTapCatcher` dismissal, `.accessibilityAction(named: "Show preview")` for VoiceOver users who can't long-press-hover; content is the caller's `@ViewBuilder` (type-preserved into the generic presenter, no AnyView needed).

**2.6 CommandPalette.** Organism, `Organisms/CommandPalette.swift` + a `.commandPalette(isPresented:sections:)` host modifier. Model: `CommandItem` (id, title, `systemImage`, keywords, optional `shortcut: [String]` rendered by `Kbd`, `action`), `CommandSection` (optional heading + items). Presentation: shipped `Backdrop` atom + a top-third card (`bgWhite`, `RadiusRole.box`, `.elevated` shadow) on compact, centered 560pt on regular/macOS; `SearchField` pinned at top with auto-focus; filtering = case/diacritic-insensitive token prefix match over title + keywords (pure function, unit-tested); highlighted row follows keyboard on macOS/iPad (`.onKeyPress` up/down/return — iOS 17 API ✓) and taps elsewhere; empty state via the `.emptyContent {}` slot (default `EmptyState`); rows use `labelBase600` + `Icon` + trailing `Kbd`, selection tint `SemanticColor.primary.soft`. Controlled-only `isPresented: Binding<Bool>` (a palette is summoned by an app-level shortcut the app owns). Strings English via `String(themeKit:)` ("Search commands…", "No results").

**3.1 ActionBar.** Organism + convenience: `ActionBar(count: Int, actions: [ActionBarAction])` (`ActionBarAction`: title, systemImage, `role: ButtonRole?`, action) — a floating bottom capsule (`bgTertiary`-on-dark styling like the dark tooltip? No — standard `bgWhite` + `.elevated`, hero-tinted leading count via `CountBadge`), plus `.actionBar(selection: Binding<Set<ID>>, actions:)` view modifier that shows/hides it as `!selection.isEmpty` with a bottom slide+fade gated by MicroMotion (fade-only under Reduce Motion), inset above the safe area. Trailing "Deselect" affordance clears the binding (`CloseButton`). A11y: `UIAccessibility`-style announcement via `AccessibilityNotification.Announcement` on appearance ("3 selected"), bar is a container with sorted actions. RTL-safe HStack; destructive actions rendered in the error semantic pair.

**3.2 Agenda.** Organism: `Agenda(_ events: [AgendaEvent])` (`AgendaEvent`: id, title, optional subtitle/location, `start`/`end: Date`, optional `accent: SemanticColor`, optional `onTap`); groups by day with `Date.FormatStyle` day headers ("Today"/"Tomorrow" via `RelativeDateTimeFormatter`-style localized logic, captured locale), a leading time column (`labelSm600`, `textTertiary`, locale-formatted, tabular where columnar), a 3pt accent rail per event (`accent?.solid ?? primary.solid`), all-day chips via `Tag`. Slots: `.emptyContent {}` (default `EmptyState`), `.header {}`. `.showsDayHeaders(_:)`, `.locale(_:)`. Distinct from Timeline (progress rail with states) — Agenda is a schedule list. RTL: time column leads via HStack; Dynamic Type: rows grow, no fixed heights.

**3.3 ThemeContextMenu.** View modifier `.themeContextMenu(_ actions: [MenuAction])` + optional `.preview {}` slot mapping to native `contextMenu(menuItems:preview:)`; `MenuAction` (title, systemImage, `role: ButtonRole?`, `disabled`, action, optional `children: [MenuAction]` → native `Menu` submenu). The honest contract, documented: menu **chrome is native and not token-stylable** — the component's value is the data-driven model shared in shape with `DropdownItem`, the token-styled *preview* card (via the 1.1 surface), and API consistency. No custom long-press re-implementation (rejected: fights the system menu, loses blur/behaviors).

**3.4 Table cell editors.** One PR, `Molecules/TableCells.swift`: `TableToggleCell(isOn: Binding<Bool>)`, `TableSelectCell(_ options: [String], selection: Binding<String>)` (compact `Dropdown`-backed), `TableSliderCell(value: Binding<Double>, in: ClosedRange<Double>)`, `TableColorCell(selection: Binding<Color>)` (system well, `ColorField` internals) — each a compact-height (row-friendly, `controlSize(.small)`) wrapper over the existing control, designed to sit inside `DataTable.Column`'s already-shipped custom-cell `@ViewBuilder`. Bindings come from the caller's row store (`Binding` into their collection) — DataTable itself is untouched. Each cell forwards an `accessibilityLabel` from its column context parameter (`label:` init arg, required).

**3.5 EmojiReactionButton.** Molecule: `EmojiReactionButton(_ emoji: String, count: Int)` — uncontrolled `initiallyReacted: Bool = false` + controlled `isReacted: Binding<Bool>` dual init via `ControllableState`; capsule chip (`bgSecondaryLight` idle → `SemanticColor.primary.soft` + `.border` hairline when reacted), count via `RollingNumber`, a one-shot particle burst of the emoji on react (6 particles, `Motion.fast`, fully suppressed by MicroMotion/Reduce Motion), haptic tick. A11y: label "React with 👍, 12 reactions", `.isSelected` when reacted.

**3.6 ColorPickerPanel.** Organism composing Wave 1: `ColorPickerPanel(color: Binding<HSBAColor>)` = ColorArea + hue/alpha ColorSliders + optional `.swatches(_ items: [ColorSwatchItem])` row + a hex `TextInput` (uppercase 8-digit formatter via the existing `TextInputFormatter`, two-way to HSBA). Modifiers: `.showsAlpha(_:)`, `.showsHexField(_:)`. This is HeroUI's `color-picker`/`color-input-group` answer in one surface; DateField-style: apps present it in a `.themePopover` or `BottomSheet` themselves.

**3.7 KanbanBoard.** Organism: `KanbanBoard(columns: Binding<[KanbanColumn<Item>]>, @ViewBuilder card: @escaping (Item) -> CardContent)` where `Item: Identifiable & Equatable`; `KanbanColumn` (id, title, `accent: SemanticColor?`, `items: [Item]`, optional `limit: Int`). Horizontal `ScrollView` of fixed-width (280pt internal constant) columns; column chrome = `bgSecondaryLight` surface, `RadiusRole.box`, header with title + `CountBadge` (+ over-limit warning pair); cards wear `cardChrome`-equivalent surface. Drag: `.draggable`/`.dropDestination` with a `Transferable` wrapper over the item **ID string** (not the item), all mutation through the columns binding (component stays stateless); insertion indicator = 2pt `borderHero` rule animated by MicroMotion. **A11y is the hard requirement, not the drag:** every card gets `accessibilityActions` "Move to <column>" ×(n−1) so VoiceOver users are not locked out of drag-and-drop. RTL: column order mirrors (HStack). Risks to pressure-test: `dropDestination` insertion-index math inside `LazyVStack`, and drag preview identity across column moves — prototype before committing the PR.

---

## 6. Non-goals / skipped (justifications)

- **AI component family (15)** — explicitly out of this sweep's scope; `CodeBlock`/`ChatBubble`/`Skeleton` already cover the reusable primitives.
- **Map** — MapKit wiring is app domain; ThemeKit ships the token-styled overlays (`MapCallout`, `MapPriceMarker`).
- **Rich Text Editor** — a stateful editing engine violates the stateless, zero-dep charter; not a component.
- **Emoji Picker** — duplicates the system keyboard's emoji plane, worse; skip.
- **Data Grid** — an engine (virtualization, column resize/pin); `DataTable` + cell editors (3.4) cover the SwiftUI-realistic need. Defer.
- **AppLayout** — `NavigationSplitView` is the platform's responsive shell; ThemeKit provides the parts (Sidebar/NavigationBar/PageHeader/Footer). Ship a DocC "app shell" recipe instead. Defer.
- **RadarChart / RadialChart / ComposedChart** — outside Swift Charts (custom polar geometry) or already native composition; defer until the core four prove demand.
- **Range calendar / date-range picker** — shipped in the `ThemeKitCalendar` opt-in add-on; core duplication would violate the modular roadmap (#229).
- **Number Stepper, Drop Zone, Inline/Native Select, KPI, Widget, Number Value, File Tree, Floating TOC, Resizable, Carousel, Item Card, Pressable Feedback, Navbar, Segment, Stepper, Sheet, Checkbox/Radio Button Group, Combo Box** — covered by existing components named in the §2 Skip table.

## 7. Open questions for sr-ios-dev (pressure-test with call sites before locking)

1. **1.3/4.4** — confirm `NSColor` HSB bridging on macOS 14 for `Color(uiColor:)`-style dynamic colors (catalog colors need `usingColorSpace(.deviceRGB)`); decide the documented fallback values when resolution fails.
2. **2.1** — Swift Charts `chartXSelection` + `ControllableState` interplay: does the controlled overload need the selection to be `Optional<Date>`-typed per x-axis kind, or can `ChartXValue` erase it without fighting `Plottable`? Prototype before freezing `ChartModels`.
3. **2.6** — `.onKeyPress` availability/behavior on iOS 17 hardware-keyboard vs macOS (Catalyst not a target); confirm focus hand-off between `SearchField` and the results list.
4. **3.7** — prototype `dropDestination` insertion-index math in `LazyVStack` and cross-column drag preview identity before the PR is scheduled; if unreliable on iOS 17, fall back to long-press + accessibility-style move actions as the only mechanism and say so.
5. **1.1** — agree the doc-comment steer on `.popconfirm(isPresented:content:)` (recommend: steer, don't deprecate).
