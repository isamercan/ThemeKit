---
title: Molecules
description: Every ThemeKit molecule, with a verified usage example for each.
---

Small groups of atoms combined into one interactive unit — fields, pickers, rows, and the travel-booking building blocks.

74 molecules. Every example below feeds modifiers with semantic color
tokens (`SemanticColor` cases, `theme.foreground(_:)`…) — never a raw `Color` or `CGFloat`
literal. See the [DocC reference](/ThemeKit/api/documentation/themekit/) for the full API.

### AmenityGrid {#amenitygrid}

Icon+label amenity grid with progressive disclosure.

```swift
AmenityGrid([Amenity("Free Wi-Fi", systemImage: "wifi"), …]).columns(2).size(.medium).limit(4).highlighted(["Free Wi-Fi"])
```

### Autocomplete {#autocomplete}

Text field with a suggestion list, synchronous or async.

```swift
Autocomplete("Destination", text: $text, suggestions: items)
// async: Autocomplete(text: $text, suggest: { await api.search($0) })
```

### Breadcrumbs {#breadcrumbs}

A path trail that collapses long paths behind an ellipsis.

```swift
Breadcrumbs([.init("Home", action: { }), .init("Current")], maxItems: 4)
```

### PrimaryButton / SecondaryButton / OutlineButton / GhostButton / LinkButton {#button}

The preset button family — five semantic styles sharing one modifier vocabulary (`.size` `.fullWidth` `.loading` …).

```swift
PrimaryButton("Continue") { }
```

### ButtonGroup {#buttongroup}

Lays out a row of buttons as one connected group.

```swift
ButtonGroup { PrimaryButton("OK") { } }
```

### CalendarView {#calendar}

Month calendar with date selection.

```swift
CalendarView(selection: $date)
```

### Checkbox {#checkbox}

A single checkbox with a label and validation info messages.

```swift
Checkbox("Accept terms", isChecked: $on).accent(.success).infoMessages(error ? [.init("Required", kind: .error)] : [])
```

### CheckboxGroup {#checkboxgroup}

A group of checkboxes bound to a selection set.

```swift
CheckboxGroup(options: items, selection: $set) { $0 }
```

### ImageChip / CompactChip / ChoseChip / FilterChip / ChipGroup {#chips}

The chip family — image, compact, price, and filter chips, plus `ChipGroup` for laying several out together.

```swift
CompactChip("Suit", price: "$899", isSelected: $on).rating(4.6)   // ChoseChip · ImageChip · FilterChip · ChipGroup
```

### ColorField {#colorfield}

A labeled color-swatch field bound to a `Color` selection.

```swift
ColorField("Brand color", selection: $color).supportsOpacity()
```

### CurrencyPicker {#currencypicker}

Searchable currency picker with a recents section.

```swift
CurrencyPicker(selection: $code, currencies: Currency.common).showsName().searchable().recents(recent)
```

### DateField {#datefield}

Date picker field with formatting styles and a locale.

```swift
DateField("Check-in", date: $date).style(.custom("EEE, d MMM")).clearable()
```

### DatePriceCard {#datepricecard}

A single selectable date + price card, as used inside `DatePriceStrip`.

```swift
DatePriceCard(DatePriceItem("18 Jul", price: 1_767.99), isSelected: true) { pick() }.currency("TRY").cheapest()
```

### DatePriceStrip {#datepricestrip}

A horizontal strip of date + price cards; `DatePriceCard` is a single selectable card.

```swift
DatePriceStrip([DatePriceItem("18 Jul", price: 1_767.99), …], selection: $i).columns(3).highlightCheapest()
```

### Dropdown {#dropdown}

Anchored action menu with item roles, dividers, and edge placement.

```swift
Dropdown(items: [.init("Rename", systemImage: "pencil"), .divider, .init("Delete", systemImage: "trash", role: .destructive)]) { trigger }.edge(.bottomTrailing)
```

### FieldButton {#fieldbutton}

A field-styled button that opens a picker or sheet.

```swift
FieldButton("2 Passengers · Economy") { openSheet() }.label("Passengers").icon("person.2.fill")
```

### Fieldset {#fieldset}

Groups fields under a title with helper text.

```swift
Fieldset("Contact") { inputs }.helper("…")
```

### FileInput {#fileinput}

File picker field with the picked file's name on display.

```swift
FileInput("Passport") { pick() }.fileName(name)
```

### FilterGroup {#filtergroup}

A group of filter options bound to a single selection.

```swift
FilterGroup(options: items, selection: $sel) { $0 }
```

### FilterRow {#filterrow}

A labeled checkbox filter row with a result count.

```swift
FilterRow("Direct", isOn: $direct).count(128).icon("airplane")   // Checkbox atom + title + count
```

### FlightRoute {#flightroute}

Origin → destination route line with stop count.

```swift
FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: arr).stops(1).nextDay()
```

### GuestSelector {#guestselector}

Rooms & guests stepper group for travel booking flows.

```swift
GuestSelector(selection: $guests).showsRooms(true).showsInfants(false).maxTotal(9)
```

### InputNumber {#inputnumber}

Stepper-backed numeric field with a range, step, and unit.

```swift
InputNumber("Max price", value: $n, range: 0...10000).step(50).unit("$")
```

### InstallmentPicker {#installmentpicker}

Installment option picker with monthly and total amounts.

```swift
InstallmentPicker([InstallmentOption(count: 3, total: 9_900, monthly: 3_300), …], selection: $count).currency("TRY")
```

### InstallmentSelector {#installmentselector}

Installment plan picker with interest-free and recommended badges.

```swift
InstallmentSelector(total: 12_000, options: [1, 3, 6, 12], selection: $months).interestFreeUpTo(3).recommended(6).surcharge([12: 750])
```

### LayoverRow {#layoverrow}

A layover duration row with a short-connection warning state.

```swift
LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").warning("Short connection")
```

### MapPriceMarker {#mappricemarker}

Price pill annotation for map pins.

```swift
MapPriceMarker("₺1.250").selected(isActive).icon("heart.fill")   // in any Map annotation
```

### MultiLineTextInput {#multilinetextinput}

Multi-line text field with a character counter.

```swift
MultiLineTextInput("Notes", text: $text).size(.small).characterLimit(200).countStyle(.remaining)
```

### MultiSelect {#multiselect}

Multi-selection dropdown field.

```swift
MultiSelect("Cities", options: items, selection: $set) { $0 }.optionEnabled { $0.inStock }.loading(loading)
```

### OTPInput {#otpinput}

One-time-passcode digit entry with a resend timer.

```swift
OTPInput(code: $code) { verify($0) }
         .digitCount(6).secure().resend(interval: 30) { resend() }
```

### Pagination {#pagination}

Numbered page navigation with a jump-to-page control.

```swift
Pagination(current: $page, total: 50).window(sibling: 2).jumper()
```

### PassengerRow {#passengerrow}

A passenger summary row with seat and check-in status.

```swift
PassengerRow("Alex Morgan").type("Adult").subtitle("Passport · TR12345").seat("14C").status("Checked in").onEdit { }
```

### PaymentCardField {#paymentcardfield}

Card number/expiry/CVV field with brand auto-detection.

```swift
PaymentCardField(number: $n, expiry: $e, cvv: $c).holder($name)   // brand auto-detect + 4-4-4-4 / MM/YY
```

### PriceBreakdown {#pricebreakdown}

Itemized price breakdown with discounts and extras.

```swift
PriceBreakdown(190_960).note("2 rooms · 4 nights").original(248_000).discountBadge("-23%").extra("Extra 8%", 175_683)
```

### PriceHistogram {#pricehistogram}

Price-distribution bars layered over a range slider.

```swift
PriceHistogram(bins: counts, lowerValue: $low, upperValue: $high, in: 0...5_000).showsBounds().resultCount(n)
```

### PriceTrendChart {#pricetrendchart}

Per-day fare bar chart with paging.

```swift
PriceTrendChart(points, selection: $day).title("July").onPage(prev: …, next: …)   // per-day fare bars
```

### ProgressIndicator {#progressindicator}

Step, carousel, or video progress readout.

```swift
ProgressIndicator(variant: .carousel, current: 2, total: 8).stepText(.slash)
```

### QuantityStepper {#quantitystepper}

A +/- stepper bound to a numeric range.

```swift
QuantityStepper(value: $qty, range: 0...10)
```

### RadioButton {#radiobutton}

A single radio option bound to a selection.

```swift
RadioButton(isSelected: $on).accent(.error)
```

### RadioGroup / RadioButtonGroup {#radiogroup}

A group of radio options bound to a selection; `RadioButtonGroup` is the tag-based variant.

```swift
RadioGroup(options: items, selection: $sel) { $0 }
```

### RangeSlider {#rangeslider}

Dual-handle range slider with marks.

```swift
RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000).step(50).marks([0, 500, 1000]).onChangeEnd(search)
```

### RecentSearchRow {#recentsearchrow}

A recent-search summary row with a rerun action.

```swift
RecentSearchRow(from: "IST", to: "AYT") { rerun() }.roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { }
```

### ScrubGallery {#scrubgallery}

Finger-scrub image gallery — drag across to flip pages.

```swift
ScrubGallery(images).accent(.primary)   // scrub a finger across to flip pages
```

### SearchBar {#searchbar}

Search field with suggestions and a recent-searches list.

```swift
SearchBar(text: $text).suggestions(cities).recent(recent).onCommit(search)
```

### SearchField {#searchfield}

A labeled field row that opens a picker — the building block of flight/hotel search forms.

```swift
SearchField("From") { openPicker() }.value(code: "IST", title: "Istanbul", subtitle: "All airports")
// or fully custom: SearchField("Dates") { }.content { DateRange(…) }.onClear { }
```

### SegmentedControl {#segmentedcontrol}

Segmented picker over a set of items.

```swift
SegmentedControl([SegmentItem("List", systemImage: "list.bullet")], selection: $i)
```

### Select {#select}

Single-selection dropdown field, with optional search and loading state.

```swift
Select("City", options: items, selection: $city) { $0 }.searchable().loading(loading)
```

### SelectBox {#selectbox}

A lightweight select trigger box.

```swift
SelectBox("Country", options: items, selection: $sel) { $0 }
```

### Slider {#slider}

Single-value slider with marks and a value tooltip.

```swift
Slider(value: $v, in: 0...8).marks([0: "0", 8: "Max"]).showsValueTooltip()
```

### SmartSuggestion {#smartsuggestion}

An inline algorithmic tip/nudge banner.

```swift
SmartSuggestion("Berlin outbound is 12% cheaper on Sat 13 Sep.").label("Smart tip").tint(.success).onTap { }
```

### SortSummaryBar {#sortsummarybar}

A row of sort-option summaries; `SortTab` is a single tab within it.

```swift
SortSummaryBar([SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"), …], selection: $sort).onMore { }
```

### SortTab {#sorttab}

A single sort-option tab, as used inside `SortSummaryBar`.

```swift
SortTab(SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"), isSelected: true) { select() }
```

### Stat {#stat}

A labeled statistic with a trend indicator and an icon.

```swift
Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))
```

### StepperRow {#stepperrow}

A labeled +/- counter row (passengers, rooms, quantity).

```swift
StepperRow("Adult", value: $adults).subtitle("+12 yrs").range(1...9)   // passenger/room/quantity counter
```

### Steps {#steps}

Numbered step tracker with a state per step.

```swift
Steps([.init("Cart", description: "2 items", state: .done), .init("Pay", state: .error)]) { active = $0 }
```

### SuggestionRow {#suggestionrow}

A single search-suggestion row, with nested sub-airport support.

```swift
SuggestionRow("Ankara, Turkey") { pick() }.icon("airplane").code("ANK").subtitle("Any").highlight(query)   // .nested() for sub-airports
```

### TextInput {#textinput}

The primary text field — icons, addons, formatting, and declarative validation.

```swift
TextInput("Email", text: $t).keyboard(.emailAddress, contentType: .emailAddress, submit: .next)
```

### ThemeButton {#themebutton}

A single configurable button — color, variant, size, and shape all as modifiers.

```swift
ThemeButton("Save") { }.color(.success).variant(.soft).size(.medium).shape(.pill)
```

### ThemeController {#themecontroller}

A picker for switching between named themes.

```swift
ThemeController(options: [.init(name: "oceanTheme", label: "Ocean")], selectedName: $name)
```

### ThemeToggle {#themetoggle}

Light/dark theme switch.

```swift
ThemeToggle(isOn: $on).accent(.success).symbols(on: "checkmark")
```

### ToggleGroup {#togglegroup}

A group of toggle switches bound to a selection set.

```swift
ToggleGroup(options: items, selection: $set, label: { $0 })
```

### Tooltip {#tooltip}

Anchored hint bubble with a placement edge and a color.

```swift
anchorView.tooltip("Hint", isPresented: $shown, edge: .top, color: .primary)
```

### TreeSelect {#treeselect}

Hierarchical tree selection field with cascading selection.

```swift
TreeSelect("Cities", nodes: tree, selection: $set, initiallyExpanded: ["tr"]).cascade().searchable()
```

### TripTypeToggle {#triptypetoggle}

One-way / round-trip / multi-city segmented toggle.

```swift
TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip).icons([…])
```

### Space {#space}

Even spacing between inline or stacked children — direction, size, align, wrap (Ant `Space`).

```swift
Space { Button("Save") { }; Button("Cancel") { } }.size(.large).wrap()
```

### Flex {#flex}

A flexbox container with main-axis `justify` and cross-axis `align` distribution (Ant `Flex`).

```swift
Flex { Tag("A"); Tag("B"); Tag("C") }.justify(.spaceBetween).align(.center)
```

### AnchorNav {#anchor}

A scroll-spy link rail; the active section highlights as you scroll (Ant `Anchor`).

```swift
AnchorNav(sections, active: $current).onSelect { proxy.scrollTo($0, anchor: .top) }
```

### Splitter {#splitter}

Two panes separated by a draggable, clamped divider (Ant `Splitter`).

```swift
Splitter(.horizontal) { Sidebar() } second: { Detail() }.bounds(min: 0.2, max: 0.8)
```

### Cascader {#cascader}

Pick a value from a multi-level option tree, one column per level (Ant `Cascader`).

```swift
Cascader(regions, selection: $path).placeholder("Region")
```

### Transfer {#transfer}

Move items between a source and a target list with checkboxes + arrows (Ant `Transfer`).

```swift
Transfer(items, target: $enabled).titles("Available", "Enabled")
```

### Mentions {#mentions}

A textarea where typing `@` opens a filterable mention list (Ant `Mentions`).

```swift
Mentions(text: $note, options: teammates).placeholder("Write a note…")
```

### Masonry {#masonry}

A Pinterest-style grid; items flow into the shortest column (Ant `Masonry`).

```swift
Masonry { ForEach(photos) { Card($0) } }.columns(2).spacing(.sm)
```

### TreeView {#tree}

A hierarchical tree with expand/collapse and optional cascade checkboxes (Ant `Tree`).

```swift
TreeView(nodes, selection: $checked).checkable()
```

### ColumnsGrid {#grid}

An equal-column grid with a token gutter; fixed or responsive-adaptive (Ant `Grid`).

```swift
ColumnsGrid { ForEach(items) { Card($0) } }.columns(3).gutter(.md)
```
