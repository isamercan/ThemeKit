---
title: Organisms
description: Every ThemeKit organism, with a verified usage example for each.
---

Complete, self-contained sections — cards, overlays, and full booking-flow surfaces composed from atoms and molecules.

67 organisms. Every example below feeds modifiers with semantic color
tokens (`SemanticColor` cases, `theme.foreground(_:)`…) — never a raw `Color` or `CGFloat`
literal. See the [DocC reference](/ThemeKit/api/documentation/themekit/) for the full API.

### Accordion {#accordion}

A collapsible content section.

```swift
Accordion("Title", initiallyExpanded: false) { Text("Body") }
```

### AccordionGroup {#accordiongroup}

A group of accordions with single- or multi-expand modes.

```swift
AccordionGroup(faqs) { $0.q } content: { Text($0.a) }.mode(.single)
```

### AgentPriceRow {#agentpricerow}

An OTA/agent price comparison row.

```swift
AgentPriceRow("Trip.com") { open() }.logo(url).rating(4.2).badge("Cheapest").original(4_100).price(3_538).cta("Go to site").recommended()
```

### AlertToast {#alerttoast}

A toast/snackbar notification card.

```swift
AlertToast("Saved").variant(.success).onClose { }
```

### AncillaryCard {#ancillarycard}

An add-on/ancillary purchase row with a quantity stepper.

```swift
AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg").price(450, suffix: "/ bag").quantity($bags, range: 0...4)   // or .added($on)
```

### BlogCard {#blogcard}

A blog/article preview card.

```swift
BlogCard(title: "…") { mediaView }.excerpt("…").readMore { }
```

### BoardingPass {#boardingpass}

A boarding-pass card with gate, seat, and barcode.

```swift
BoardingPass(passenger: "Alex Morgan", from: "SAW", to: "BER").airline("Pegasus").flightNo("PC 1234").times(departure: "13:15", arrival: "16:05").gate("A12", seat: "14C", boarding: "12:45").barcode("…")
```

### BottomSheet {#bottomsheet}

A presented bottom sheet with configurable detents.

```swift
// install once: .sheetHost()
@Environment(SheetPresenter.self) var sheet: SheetPresenter
sheet.present(detents: [.height(280), .large]) { FilterView() }
// or declarative: someView.bottomSheet(isPresented: $open, detents: [.medium]) { … }
```

### BrowserFrame {#browserframe}

Browser-chrome mockup frame around any content.

```swift
BrowserFrame(url: "https://themekit.dev") { content }.accent(.primary)
```

### Callout {#callout}

An inline message callout.

```swift
Callout("Message").variant(.success).calloutStyle(.plain)
```

### Card {#card}

The base surface/shell container — every card-family organism routes its shell through `CardStyle`.

```swift
Card { content }.elevation(.soft)
```

### Carousel {#carousel}

An auto-playing media carousel with arrows.

```swift
Carousel(items) { item in mediaView }.autoplay(2).arrows()
```

### ChatBubble {#chatbubble}

A chat message bubble.

```swift
ChatBubble("Hi!", time: "09:24").side(.outgoing).accent(.success)
```

### Counter {#counter}

A days/hours/minutes countdown readout.

```swift
Counter(days: 2, hours: 8, minutes: 45)
```

### Coupon {#coupon}

A copyable coupon code card.

```swift
Coupon(code: "UXMUQ", onCopy: { }).couponStyle(.outlined)
```

### DataTable {#datatable}

A sortable, paginated data table.

```swift
DataTable(columns: cols, rows: rows, selection: $selected).pageSize(10)
```

### DestinationCard {#destinationcard}

A destination discovery card with a ribbon, rating, and favorite toggle.

```swift
DestinationCard("Bali & 3-Days", image: url).ribbon("Top #1").price(1_450).rating(4.8).favorite($fav).tags(["Beach", "Culture"]).onTap { }
```

### Dialog {#dialog}

A presented modal dialog with a content and footer builder.

```swift
view.dialog(isPresented: $show, title: "…") { content } footer: { buttons }
```

### Diff {#diff}

A before/after comparison slider.

```swift
Diff { beforeView } after: { afterView }.aspect(1.6)
```

### Drawer {#drawer}

A presented side drawer with drag-to-dismiss.

```swift
someView.drawer(isPresented: $open, edge: .leading) { menu }
// or imperative: install .drawerHost(); @Environment(DrawerPresenter.self) var drawer: DrawerPresenter
drawer.present(edge: .leading) { menu }   // drag-to-dismiss built in
```

### EmptyState {#emptystate}

An empty/error state placeholder with a primary and secondary action.

```swift
EmptyState("Empty").icon("tray").message("…").primaryAction("Retry") { }
```

### FloatingActionButton {#fab}

A floating action button with speed-dial actions.

```swift
FloatingActionButton(systemImage: "plus", actions: [.init(systemImage: "camera", action: { })])
```

### FareFamilyCard {#farefamilycard}

A fare-family comparison card with an included-features list.

```swift
FareFamilyCard("Super Eco", price: 1_871.99).accent(.success).features([FareFeature("Cabin bag", systemImage: "handbag")]).selection($picked)
```

### FareSummary {#faresummary}

An itemized fare summary with a hero total.

```swift
FareSummary([.item("Base fare", 1_100, info: "…"), .discount("Member", 100), .total("Total", 1_199)]).onInfo { line in } footer: { TermsLink() }
```

### Feedback {#feedback}

A toast/snackbar presenter host — install once, present from anywhere.

```swift
@Environment(FeedbackPresenter.self) var feedback: FeedbackPresenter
feedback.toast("Saved", kind: .success)              // stacks
feedback.toast("Deleted", action: ToastAction("Undo") { }, duration: nil)
await feedback.toastTask(loading: "Saving…", success: "Saved") { try await save() }
// install once: .feedbackHost(maxVisibleToasts: 3, toastPosition: .bottom)
```

### FilterBar {#filterbar}

A horizontal quick-filter bar that collapses on scroll.

```swift
FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront"), …], selection: $active).onFilter { }.onSort { }   // leading buttons collapse on scroll
```

### FilterList {#filterlist}

A titled list of filter options with a select-all action.

```swift
FilterList([FilterOption("Direct", count: 128), …], selection: $stops).title("Stops").bordered().selectAll("All")
```

### FlightCard {#flightcard}

A flight search result card — times, route, price, and a select action.

```swift
FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr).stops(0).price(1_299).badge("Cheapest").scarcity(3).fareBrand("Eco Flex").onSelect { }
// multi-leg: FlightCard(legs: [outbound, ret]).price(7_178)
```

### FlightResultRow {#flightresultrow}

A flight search result row, with an optional return leg.

```swift
FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: arr).flightNo("TK 2434").price(3_538.99).baggage("15 kg").badge("Cheapest").returnLeg(from: "AYT", to: "IST", departure: d2, arrival: a2).onSelect { }
```

### FlightListItem {#flightlistitem}

A style-driven flight search-result list item: the component holds the data (legs, fares, price, deal signals, schedule, baggage) and a `FlightListItemStyle` owns the entire layout. Nine built-in styles cover the industry archetypes — `.compact` (one-line row), `.timeline` (route-track card, default), `.fareBoard` (fare-family chips), `.deal` (price judgment + sparkline), `.ticket` (perforated pass), `.journey` (expandable leg timeline), `.slices` (round-trip/multi-city card), `.timetable` (carrier departure chips), `.tray` (nested card + CTA rail, from the design-system spec) — and custom styles receive the same typed configuration.

```swift
FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
    .flightNo("SK 1123")
    .price(214, currencyCode: "USD", caption: "from")
    .badge("Best")
    .onSelect { }
    .flightListItemStyle(.deal)   // or .compact, .ticket, .journey, …
```

### FlightTicketCard {#flightticketcard}

A compact flight ticket summary card.

```swift
FlightTicketCard(from: "NYC", to: "SFO").cities(from: "New York City", to: "San Francisco").duration("1h 45m").times(departure: "10:00 AM", arrival: "11:30 AM").airline("Garuda").price(140, currencyCode: "USD").favorite($fav)
```

### Footer {#footer}

A multi-column site/app footer.

```swift
Footer(columns: [.init("Company", items: [.init("About")])], note: "© 2026")
```

### Gallery {#gallery}

A grid image gallery.

```swift
Gallery(items) { item in mediaView }.columns(2).aspect(.square)
```

### Hero {#hero}

A hero banner section with title, subtitle, and CTA.

```swift
Hero(title: "…").subtitle("…").cta("Explore", action: { })
```

### HotelResultCard {#hotelresultcard}

A hotel search result card — images, score, price, and discount.

```swift
HotelResultCard(name: "Mirage Park Resort").images(urls).score(8.9, reviews: 949).features([…]).original(248_000).discountBadge("-23%").price(190_960).extraDiscount("Extra 8%", 175_683).favorite($fav).onSelect { }
```

### ImageCollage {#imagecollage}

A 1–4+ tile photo collage with a "+N" overflow tile.

```swift
ImageCollage(urls) { index in open(index) }.height(220)   // 1·2·3·4+ layouts + "+N"
```

### InfoBanner {#infobanner}

A full-width informational banner with inline links.

```swift
InfoBanner("Message", links: [("link", action)]).variant(.info)
```

### KeyValueTable {#keyvaluetable}

A bordered key/value summary table.

```swift
KeyValueTable(rows: [...]).title("Summary").bordered()
```

### ListView {#list}

A lazy list container with header/footer and border styles.

```swift
ListView(items) { ListRow($0.title) }.header("Settings").footer("3 items").bordered()
```

### ListRow / ListSectionHeader {#listrow}

A single list row; `ListSectionHeader` groups rows under a titled section.

```swift
ListRow("Account", action: { }).subtitle("…").trailing(.chevron)
```

### LocationCard {#locationcard}

A MapKit preview card with an address and distance.

```swift
LocationCard(title: "Marina Bay Hotel", latitude: 38.42, longitude: 27.14).subtitle("…").distance("1.2 km").directions().pois(pins).snapshot()
```

### LoyaltyCard {#loyaltycard}

A loyalty tier/points card that flips to a membership QR/barcode face.

```swift
LoyaltyCard(tier: "Gold", points: 8_430).memberName("Elif K.").progress(0.62, toNextTier: "Platinum").membership(.qr(id)).flippable().logo { }
```

### MapCallout {#mapcallout}

A map pin callout card, for use over any `Map`.

```swift
MapCallout(title: "Mirage Park Resort").image(url).score(8.9).price(9_600).onSelect { }   // over any Map, no MapKit dep
```

### MenuCard {#menucard}

A card of navigable menu items.

```swift
MenuCard(items: [.init(title: "Reservations", systemImage: "calendar")])
```

### NavigationBar {#navigationbar}

A bottom tab navigation bar.

```swift
NavigationBar(items: [.init(systemImage: "house")], selection: $tab)
```

### NotificationCard {#notificationcard}

A notification/inbox card with read/unread state.

```swift
NotificationCard(title: "…").message("…").date("…").unread()
```

### PageHeader {#pageheader}

A page title bar with a back action.

```swift
PageHeader("Title").subtitle("…").onBack { }
```

### PagingCarousel {#pagingcarousel}

A paged carousel with a peeking edge.

```swift
PagingCarousel(items) { item in mediaView }.peek(36).autoplay(2)
```

### PhoneFrame {#phoneframe}

Phone bezel mockup frame, with notch/island styles.

```swift
PhoneFrame { AppScreen() }.notch(.island).bezel(.neutral)
```

### Popconfirm {#popconfirm}

An inline tap-to-confirm popover.

```swift
trigger.popconfirm(isPresented: $show, title: "Delete?", confirmTitle: "Delete") { delete() }
```

### PriceAlertCard {#pricealertcard}

A price-alert opt-in card with a trend indicator.

```swift
PriceAlertCard("Get price alerts", isOn: $alerts).subtitle("…").price(3_538).trend(.down, "-8%")
```

### PromoBanner {#promobanner}

A promotional banner with an icon and a CTA.

```swift
PromoBanner("…", action: { }).icon("sun.max.fill").ctaTitle("Go")
```

### RatingSummary {#ratingsummary}

An aggregate rating summary with a review count.

```swift
RatingSummary(score: 9.0).label("Excellent").reviews(count: 1200)
```

### ResultView {#result}

A full-page result state — not found, error, success…

```swift
ResultView(.notFound, title: "Page not found").message("…").primaryAction("Home") { }
```

### ReviewCard {#reviewcard}

A single review card with a score, text, and photo strip.

```swift
ReviewCard(author: "Elif K.", score: 9.2, text: "…").date(d).title("…").verified().stars().expandable().photos(urls).onPhotoTap { }
```

### RoomCard {#roomcard}

A hotel room offer card with board type and price.

```swift
RoomCard(name: "Deluxe Room").board("All-inclusive").features([FareFeature(…)]).original(12_000).discountBadge("-20%").price(9_600).unit("/ night").onSelect { }
```

### SeatMap {#seatmap}

A seat-selection grid for flights, with aisles and per-seat state.

```swift
SeatMap(columns: "ABC DEF", rows: Array(1...30), selection: $picked) { id, row, col in
    SeatInfo(available: !sold.contains(id), price: row <= 3 ? 600 : 80, tier: row == 14 ? .exit : .standard)
}.legend().showsSeatInfo().recommended(["11C"])
```

### SegmentedTabBar {#segmentedtabbar}

A scrollable tab bar with per-tab badges.

```swift
SegmentedTabBar([TabItem("Reviews", badge: "12"), TabItem("Off", isEnabled: false)], selection: $i).tabStyle(.pill)
```

### RadioCard / CheckboxCard {#selectioncards}

Radio- and checkbox-style selectable option cards.

```swift
RadioCard("Standard", isSelected: sel == id) { sel = id }.description("…")
```

### SheetHeader {#sheetheader}

A modal sheet header with a back/close action and progress.

```swift
SheetHeader("Passengers").onBack { }.onClose { }.progress(0.4)   // modal header (not the tab NavigationBar)
```

### CardStack {#stack}

A swipeable, fanned card deck.

```swift
CardStack(items) { item in cardView }
```

### StickyBookingBar {#stickybookingbar}

A sticky bottom booking bar with price and a primary action.

```swift
StickyBookingBar("Book now") { }.price(9_600).original(12_000).discountBadge("-20%").note("2 rooms · 4 nights")   // .safeAreaInset(.bottom)
```

### TicketStub {#ticketstub}

A notched, perforated ticket shell around any content and stub.

```swift
TicketStub { FlightCard(...) }.stub { Barcode(id).showsValue() }.notchRadius(12).perforation().elevation(.elevated)
```

### Timeline {#timeline}

A vertical or horizontal event timeline.

```swift
Timeline([.init(title: "Placed", state: .done, color: .success)]).pending("Awaiting…")
```

### Tour {#tour}

A guided coach-mark tour across tagged targets.

```swift
view.tourTarget("search");  root.tourHost(tour, steps: [TourStep("search", title: "…", message: "…")])
```

### Upload / UploadList {#upload}

An upload list bound to an `UploadController`, with per-file progress.

```swift
@State var uploads = UploadController()
UploadList(controller: uploads) { /* pick */ }
await uploads.upload(name: file.name) { progress in /* report 0…1 */ }
```

### VideoPlayerView {#videoplayer}

An inline video player with loop, mute, and a mute toggle.

```swift
VideoPlayerView(url).loop().muted().muteToggle()
```

### WindowFrame {#windowframe}

OS window-chrome mockup frame around any content.

```swift
WindowFrame("Preferences") { content }.accent(.info)
```
