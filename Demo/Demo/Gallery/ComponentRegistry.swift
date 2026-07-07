//
//  ComponentRegistry.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Single source of truth for the gallery. Adding a component is one entry:
//  `.knob("Name", .category, demo: NameDemo(), usage: #"..."#)` for an
//  interactive page, or `.static("Name", .category, usage:) { Component(...) }`.
//  `usage` is shown as a copyable code card on the component's page.
//

import SwiftUI
import ThemeKit

enum ComponentCategory: String, CaseIterable, Identifiable {
    case atoms = "Atoms"
    case molecules = "Molecules"
    case organisms = "Organisms"
    var id: String { rawValue }
}

struct ComponentEntry: Identifiable {
    let id = UUID()
    let name: String
    let category: ComponentCategory
    let usage: String?
    let make: () -> AnyView

    static func knob<D: View>(_ name: String, _ category: ComponentCategory, demo: @escaping @autoclosure () -> D, usage: String? = nil) -> ComponentEntry {
        ComponentEntry(name: name, category: category, usage: usage) { AnyView(demo()) }
    }

    static func `static`<P: View>(_ name: String, _ category: ComponentCategory, usage: String? = nil, @ViewBuilder preview: @escaping () -> P) -> ComponentEntry {
        ComponentEntry(name: name, category: category, usage: usage) { AnyView(ComponentStage(name) { preview() }) }
    }
}

/// Gives a `.static` gallery preview its own mutable `@State` so interactive
/// components (steppers, toggles) work without a bespoke Demo view.
struct StatefulPreview<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}

// Interactive travel demos (PriceTagDemo, SeatMapDemo, PriceHistogramDemo, …)
// live in Demos/TravelDemos.swift — every prop/modifier is an editable knob.

enum ComponentRegistry {
    static let all: [ComponentEntry] = [
        // MARK: Atoms
        .knob("Avatar", .atoms, demo: AvatarDemo(), usage: #"Avatar(.initials("AB")).size(.md).presence(.online)"#),
        .knob("Badge", .atoms, demo: BadgeDemo(), usage: #"Badge("Label").badgeStyle(.info).icon("star.fill")"#),
        .knob("Chip", .atoms, demo: ChipDemo(), usage: #"Chip("Recommended", isSelected: $selected).chipStyle(.tonal)"#),
        .knob("Color Palette", .atoms, demo: ColorLadderDemo(), usage: #"SemanticColor.primary.shade(.s500)   // base · .bg .hover .active .strong"#),
        .knob("CountBadge", .atoms, demo: CountBadgeDemo(), usage: ##"icon.countBadge(5)   //  .dotBadge() · Ribbon("New") { card }"##),
        .knob("BorderBeam", .atoms, demo: BorderBeamDemo(), usage: #"card.borderBeam(cornerRadius: 16, lineWidth: 2)"#),
        .knob("Divider", .atoms, demo: DividerDemo(), usage: #"DividerView("OR").dashed().titleAlign(.center)"#),
        .knob("Icon", .atoms, demo: IconDemo(), usage: #"Icon(systemName: "star.fill").size(.md).color(theme.foreground(.fgHero))"#),
        .knob("InputLabel", .atoms, demo: InputLabelDemo(), usage: #"InputLabel("Email").required().hasInfo()"#),
        .knob("ProgressBar", .atoms, demo: ProgressBarDemo(), usage: #"ProgressBar(value: 0.4).showsPercentage()"#),
        .knob("RadialProgress", .atoms, demo: RadialProgressDemo(), usage: #"RadialProgress(0.6).size(96).accent(.purple).showsLabel()"#),
        .knob("RemoteImage", .atoms, demo: RemoteImageDemo(), usage: #"RemoteImage(url, ratio: "16:9").cornerRadius(12)   // .gif/.apng animate natively"#),
        .knob("AnimatedImage", .atoms, demo: AnimatedImageDemo(), usage: #"AnimatedImage(gifURL).contentMode(.fit).cornerRadius(16)   // GIF/APNG via ImageIO — no dependency"#),
        .knob("RollingNumber", .atoms, demo: RollingNumberDemo(), usage: #"RollingNumber(1284).size(40)   // odometer digit roll"#),
        .knob("Indicator", .atoms, demo: IndicatorDemo(), usage: #"icon.indicatorDot()   // or .indicator { Badge("3") }"#),
        .knob("Kbd", .atoms, demo: KbdDemo(), usage: #"Kbd("⌘").size(.lg)  Kbd("K").size(.lg)   // xs/sm/md/lg"#),
        .knob("Status", .atoms, demo: StatusDotDemo(), usage: #"StatusDot(.online, label: "Online").pulse()"#),
        .knob("Swap", .atoms, demo: SwapDemo(), usage: #"Swap(isOn: $on).symbols(on: "xmark", off: "line.3.horizontal")"#),
        .knob("TextLink", .atoms, demo: TextLinkDemo(), usage: #"TextLink("Forgot password?") { }.accent(.primary)   // .underline(false) to remove"#),
        .knob("Rating", .atoms, demo: RatingDemo(), usage: #"Rating(value: 4.5).allowHalf().onRate { value = $0 }"#),
        .knob("ScoreBadge", .atoms, demo: ScoreBadgeDemo(), usage: #"ScoreBadge(9.0, large: false)"#),
        .knob("Skeleton", .atoms, demo: SkeletonDemo(), usage: #"Text("Loading…").skeleton(isLoading)"#),
        .knob("Spinner", .atoms, demo: SpinnerDemo(), usage: #"Spinner().style(.dots).accent(.success).size(24)   // ring/dots/bars/ball/infinity"#),
        .knob("Tag", .atoms, demo: TagDemo(), usage: #"Tag("Sold out", onRemove: { }).tagStyle(.error).variant(.solid)"#),
        .knob("Title", .atoms, demo: TitleDemo(), usage: #"Title("Section").subtitle("Sub").action("See all", action: { })"#),
        .knob("InlineText", .atoms, demo: InlineTextDemo(), usage: #"InlineText("Accept the Terms.", links: [("Terms", { })]).inlineStyle(.bodyBase400).color(tint)"#),
        .knob("Join", .atoms, demo: JoinDemo(), usage: #"Join(.horizontal) { ButtonA; ButtonB; ButtonC }   // connected group, rounded outer corners"#),
        .knob("Mask", .atoms, demo: MaskDemo(), usage: #"image.themeMask(.squircle)   // .circle / .squircle / .hexagon / .star"#),
        .knob("TextRotate", .atoms, demo: TextRotateDemo(), usage: #"TextRotate(["faster.", "themed.", "accessible."], interval: 2)"#),
        .knob("Gauge", .atoms, demo: GaugeDemo(), usage: #"GaugeView(value: 0.72, label: "CPU").gaugeStyle(.circular).showsValue()"#),
        .knob("ShareButton", .atoms, demo: ShareButtonDemo(), usage: #"ShareButton(item: url)   // wraps SwiftUI ShareLink"#),
        .knob("PriceTag", .atoms, demo: PriceTagDemo(), usage: #"PriceTag(1_299).original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()   // .free() · .soldOut() · .from() · .fractionDigits(2)"#),
        .knob("PointsBadge", .atoms, demo: PointsBadgeDemo(), usage: #"PointsBadge(1_250).unit("mil").style(.earn).size(.large).showsSign(true)   // .earn · .redeem · .balance"#),
        .knob("CountdownTimer", .atoms, demo: CountdownTimerDemo(), usage: #"CountdownTimer(until: deadline).style(.urgent).format(.boxed).size(.large).showsDays(false)"#),
        .knob("QRCode", .atoms, demo: QRCodeDemo(), usage: #"QRCode("https://themekit.dev/pass/BID12025").size(160)   // CoreImage, no dep"#),
        .knob("Barcode", .atoms, demo: BarcodeDemo(), usage: #"Barcode("9824097217421298").height(56).showsValue()   // Code 128, no dep"#),
        .knob("Confetti", .atoms, demo: ConfettiDemo(), usage: #"Confetti().pieceCount(60)   // or: view.confetti(trigger: submissions)"#),
        .knob("FareFeatureRow", .atoms, demo: FareFeatureRowDemo(), usage: ##"FareFeatureRow("Checked bag", systemImage: "suitcase.fill", detail: "1 × 20 kg", status: .included)   // .included/.excluded/.info"##),
        .knob("SwapButton", .atoms, demo: SwapButtonDemo(), usage: #"SwapButton { swap(&from, &to) }.size(34)   // action flip; see Swap for the on/off toggle"#),
        .static("SearchBadge", .atoms, usage: ##"SearchBadge("SAW")   // soft-blue pill; .colors(background:foreground:) · .icon("bolt.fill")"##) {
            HStack(spacing: 8) { SearchBadge("SAW"); SearchBadge("23 Jul '24"); SearchBadge("4 Guests"); SearchBadge("Direct").colors(background: .badgeBgPurple, foreground: .textPurple).icon("bolt.fill") }
        },
        .knob("FlightStatusBadge", .atoms, demo: FlightStatusBadgeDemo(), usage: ##"FlightStatusBadge(.delayed).time("+35m").solid()   // on-time/boarding/delayed/cancelled…"##),
        .knob("IconTile", .atoms, demo: IconTileDemo(), usage: ##"IconTile("suitcase.fill").accent(.turquoise).size(46)   // shared leading tile"##),
        .static("Aura", .atoms, usage: ##"card.aura(.primary)   // breathing glow halo · Aura().color(.purple).size(120).intensity(0.7)"##) {
            HStack(spacing: 48) {
                Aura().color(.primary).size(90)
                Card { Text("Featured").padding(28) }.aura(.purple)
            }
            .padding(.vertical, 32)
        },
        .static("TiltCard", .atoms, usage: ##"card.tilt3D(shine: true)   // drag to tilt · TiltCard { … }.maxAngle(.degrees(12))"##) {
            Card {
                VStack(spacing: 8) {
                    Text("✈️").font(.largeTitle)
                    Text("Drag me").font(.headline)
                }
                .padding(36)
            }
            .tilt3D(shine: true)
        },
        .static("CodeBlock", .atoms, usage: ##"CodeBlock([CodeLine("npm i themekit", prefix: "$"), CodeLine("Done!", prefix: ">", highlight: .success)]).copyable()"##) {
            CodeBlock([
                CodeLine("npm i themekit", prefix: "$"),
                CodeLine("added 1 package in 2s", prefix: ">"),
                CodeLine("Done!", prefix: ">", highlight: .success)
            ]).copyable()
        },

        // MARK: Molecules
        .knob("ColorField", .molecules, demo: ColorFieldDemo(), usage: #"ColorField("Brand color", selection: $color).supportsOpacity()"#),
        .knob("Autocomplete", .molecules, demo: AutocompleteDemo(), usage: #"Autocomplete("Destination", text: $text, suggestions: items)\n// async: Autocomplete(text: $text, suggest: { await api.search($0) })"#),
        .knob("Button", .molecules, demo: ButtonDemo(), usage: #"PrimaryButton("Continue") { }"#),
        .knob("ButtonGroup", .molecules, demo: ButtonGroupDemo(), usage: #"ButtonGroup { PrimaryButton("OK") { } }"#),
        .knob("ThemeButton", .molecules, demo: ThemeButtonDemo(), usage: #"ThemeButton("Save") { }.color(.success).variant(.soft).size(.medium).shape(.pill)"#),
        .knob("Checkbox", .molecules, demo: CheckboxDemo(), usage: #"Checkbox("Accept terms", isChecked: $on).accent(.success).infoMessages(error ? [.init("Required", kind: .error)] : [])"#),
        .knob("CheckboxGroup", .molecules, demo: CheckboxGroupDemo(), usage: #"CheckboxGroup(options: items, selection: $set) { $0 }"#),
        .knob("InputNumber", .molecules, demo: InputNumberDemo(), usage: #"InputNumber("Max price", value: $n, range: 0...10000).step(50).unit("$")"#),
        .knob("MultiLineTextInput", .molecules, demo: MultiLineDemo(), usage: #"MultiLineTextInput("Notes", text: $text).size(.small).characterLimit(200).countStyle(.remaining)"#),
        .knob("OTPInput", .molecules, demo: OTPDemo(), usage: #"OTPInput(code: $code) { verify($0) }\n         .digitCount(6).secure().resend(interval: 30) { resend() }"#),
        .knob("Breadcrumbs", .molecules, demo: BreadcrumbsDemo(), usage: #"Breadcrumbs([.init("Home", action: { }), .init("Current")], maxItems: 4)"#),
        .knob("Calendar", .molecules, demo: CalendarDemo(), usage: #"CalendarView(selection: $date)"#),
        .knob("DateField", .molecules, demo: DateFieldDemo(), usage: ##"DateField("Check-in", date: $date).style(.custom("EEE, d MMM")).clearable()"##),
        .knob("Fieldset", .molecules, demo: FieldsetDemo(), usage: #"Fieldset("Contact") { inputs }.helper("…")"#),
        .knob("Form", .molecules, demo: FormDemo(), usage: ##"@State var form = FormValidator<Field>([.email: [.required(), .email()]])\nform.validateAll([.email: email])  // → first invalid field, focuses it"##),
        .knob("FileInput", .molecules, demo: FileInputDemo(), usage: #"FileInput("Passport") { pick() }.fileName(name)"#),
        .knob("FilterGroup", .molecules, demo: FilterGroupDemo(), usage: #"FilterGroup(options: items, selection: $sel) { $0 }"#),
        .knob("Chips", .molecules, demo: ChipsDemo(), usage: #"CompactChip("Suit", price: "$899", isSelected: $on).rating(4.6)   // ChoseChip · ImageChip · FilterChip · ChipGroup"#),
        .knob("ProgressIndicator", .molecules, demo: ProgressIndicatorDemo(), usage: #"ProgressIndicator(variant: .carousel, current: 2, total: 8).stepText(.slash)"#),
        .knob("ThemeController", .molecules, demo: ThemeControllerDemo(), usage: #"ThemeController(options: [.init(name: "oceanTheme", label: "Ocean")], selectedName: $name)"#),
        .knob("Pagination", .molecules, demo: PaginationDemo(), usage: #"Pagination(current: $page, total: 50).window(sibling: 2).jumper()"#),
        .knob("Stat", .molecules, demo: StatDemo(), usage: #"Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))"#),
        .knob("Steps", .molecules, demo: StepsDemo(), usage: #"Steps([.init("Cart", description: "2 items", state: .done), .init("Pay", state: .error)]) { active = $0 }"#),
        .knob("QuantityStepper", .molecules, demo: QuantityStepperDemo(), usage: #"QuantityStepper(value: $qty, range: 0...10)"#),
        .knob("Micro-motion", .molecules, demo: MicroMotionDemo(), usage: #"View().microAnimations(false)   // theme-wide at root, or per-component"#),
        .knob("RadioButton", .molecules, demo: RadioButtonDemo(), usage: #"RadioButton(isSelected: $on).accent(.error)"#),
        .knob("RadioGroup", .molecules, demo: RadioGroupDemo(), usage: #"RadioGroup(options: items, selection: $sel) { $0 }"#),
        .knob("RangeSlider", .molecules, demo: RangeSliderDemo(), usage: #"RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000).step(50).marks([0, 500, 1000]).onChangeEnd(search)"#),
        .knob("SearchBar", .molecules, demo: SearchBarDemo(), usage: #"SearchBar(text: $text).suggestions(cities).recent(recent).onCommit(search)"#),
        .knob("SegmentedControl", .molecules, demo: SegmentedControlDemo(), usage: #"SegmentedControl([SegmentItem("List", systemImage: "list.bullet")], selection: $i)"#),
        .knob("Select", .molecules, demo: SelectDemo(), usage: #"Select("City", options: items, selection: $city) { $0 }.searchable().loading(loading)"#),
        .knob("MultiSelect", .molecules, demo: MultiSelectDemo(), usage: #"MultiSelect("Cities", options: items, selection: $set) { $0 }.optionEnabled { $0.inStock }.loading(loading)"#),
        .knob("TreeSelect", .molecules, demo: TreeSelectDemo(), usage: #"TreeSelect("Cities", nodes: tree, selection: $set, initiallyExpanded: ["tr"]).cascade().searchable()"#),
        .knob("SelectBox", .molecules, demo: SelectBoxDemo(), usage: #"SelectBox("Country", options: items, selection: $sel) { $0 }"#),
        .knob("Slider", .molecules, demo: SliderDemo(), usage: #"Slider(value: $v, in: 0...8).marks([0: "0", 8: "Max"]).showsValueTooltip()"#),
        .knob("TextInput", .molecules, demo: TextInputDemo(), usage: ##"TextInput("Email", text: $t).keyboard(.emailAddress, contentType: .emailAddress, submit: .next)"##),
        .knob("ThemeToggle", .molecules, demo: ToggleDemo(), usage: #"ThemeToggle(isOn: $on).accent(.success).symbols(on: "checkmark")"#),
        .knob("ToggleGroup", .molecules, demo: ToggleGroupDemo(), usage: #"ToggleGroup(options: items, selection: $set, label: { $0 })"#),
        .knob("Tooltip", .molecules, demo: TooltipDemo(), usage: #"anchorView.tooltip("Hint", isPresented: $shown, edge: .top, color: .primary)"#),
        .knob("GuestSelector", .molecules, demo: GuestSelectorDemo(), usage: #"GuestSelector(selection: $guests).showsRooms(true).showsInfants(false).maxTotal(9)"#),
        .knob("AmenityGrid", .molecules, demo: AmenityGridDemo(), usage: #"AmenityGrid([Amenity("Free Wi-Fi", systemImage: "wifi"), …]).columns(2).size(.medium).limit(4).highlighted(["Free Wi-Fi"])"#),
        .knob("PriceHistogram", .molecules, demo: PriceHistogramDemo(), usage: #"PriceHistogram(bins: counts, lowerValue: $low, upperValue: $high, in: 0...5_000).showsBounds().resultCount(n)"#),
        .knob("PriceTrendChart", .molecules, demo: PriceTrendChartDemo(), usage: ##"PriceTrendChart(points, selection: $day).title("July").onPage(prev: …, next: …)   // per-day fare bars"##),
        .knob("PriceBreakdown", .molecules, demo: PriceBreakdownDemo(), usage: ##"PriceBreakdown(190_960).note("2 rooms · 4 nights").original(248_000).discountBadge("-23%").extra("Extra 8%", 175_683)"##),
        .knob("DatePriceStrip", .molecules, demo: DatePriceStripDemo(), usage: ##"DatePriceStrip([DatePriceItem("18 Jul", price: 1_767.99), …], selection: $i).columns(3).highlightCheapest()"##),
        .static("DatePriceCard", .molecules, usage: ##"DatePriceCard(DatePriceItem("18 Jul", price: 1_767.99), isSelected: true) { pick() }.currency("TRY").cheapest()"##) {
            HStack(spacing: 8) {
                DatePriceCard(DatePriceItem("17 Jul", price: 1_474.99), isSelected: false) { }.cheapest()
                DatePriceCard(DatePriceItem("18 Jul", price: 1_767.99), isSelected: true) { }
            }.frame(maxWidth: 240)
        },
        .knob("SortSummaryBar", .molecules, demo: SortSummaryBarDemo(), usage: ##"SortSummaryBar([SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"), …], selection: $sort).onMore { }"##),
        .static("SortTab", .molecules, usage: ##"SortTab(SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"), isSelected: true) { select() }"##) {
            HStack(spacing: 20) {
                SortTab(SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"), isSelected: true) { }
                SortTab(SortOption("Cheapest", value: "₺2.178", subtitle: "6h 45m", icon: "tag.fill"), isSelected: false) { }
            }
        },
        .knob("FlightRoute", .molecules, demo: FlightRouteDemo(), usage: ##"FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: arr).stops(1).nextDay()"##),
        .knob("FieldButton", .molecules, demo: FieldButtonDemo(), usage: ##"FieldButton("2 Passengers · Economy") { openSheet() }.label("Passengers").icon("person.2.fill")"##),
        .knob("SearchField", .molecules, demo: SearchFieldDemo(), usage: ##"SearchField("From") { openPicker() }.value(code: "IST", title: "Istanbul", subtitle: "All airports")\n// or fully custom: SearchField("Dates") { }.content { DateRange(…) }.onClear { }"##),
        .knob("SuggestionRow", .molecules, demo: SuggestionRowDemo(), usage: ##"SuggestionRow("Ankara, Türkiye") { pick() }.icon("airplane").code("ANK").subtitle("Any").highlight(query)   // .nested() for sub-airports"##),
        .knob("SmartSuggestion", .molecules, demo: SmartSuggestionDemo(), usage: ##"SmartSuggestion("Berlin outbound is 12% cheaper on Sat 13 Sep.").label("Smart tip").tint(.success).onTap { }"##),
        .knob("PassengerRow", .molecules, demo: PassengerRowDemo(), usage: ##"PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345").seat("14C").status("Checked in").onEdit { }"##),
        .knob("LayoverRow", .molecules, demo: LayoverRowDemo(), usage: ##"LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").warning("Short connection")"##),
        .knob("StepperRow", .molecules, demo: StepperRowDemo(), usage: ##"StepperRow("Adult", value: $adults).subtitle("+12 yrs").range(1...9)   // passenger/room/quantity counter"##),
        .knob("RecentSearchRow", .molecules, demo: RecentSearchRowDemo(), usage: ##"RecentSearchRow(from: "IST", to: "AYT") { rerun() }.roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { }"##),
        .knob("TripTypeToggle", .molecules, demo: TripTypeToggleDemo(), usage: ##"TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip).icons([…])"##),
        .knob("InstallmentSelector", .molecules, demo: InstallmentSelectorDemo(), usage: #"InstallmentSelector(total: 12_000, options: [1, 3, 6, 12], selection: $months).interestFreeUpTo(3).recommended(6).surcharge([12: 750])"#),
        .knob("CurrencyPicker", .molecules, demo: CurrencyPickerDemo(), usage: #"CurrencyPicker(selection: $code, currencies: Currency.common).showsName().searchable().recents(recent)"#),
        .static("Dropdown", .molecules, usage: ##"Dropdown(items: [.init("Rename", systemImage: "pencil"), .divider, .init("Delete", systemImage: "trash", role: .destructive)]) { trigger }.edge(.bottomTrailing)"##) {
            Dropdown(items: [
                DropdownItem("Rename", systemImage: "pencil"),
                DropdownItem("Duplicate", systemImage: "plus.square.on.square"),
                .divider,
                DropdownItem("Delete", systemImage: "trash", role: .destructive)
            ]) {
                Label("Actions", systemImage: "chevron.down")
            }
            .padding(.bottom, 160)
        },
        .static("ScrubGallery", .molecules, usage: ##"ScrubGallery(images).accent(.primary)   // scrub a finger across to flip pages"##) {
            ScrubGallery(count: 3) { i in
                ZStack {
                    Rectangle().fill([SemanticColor.primary, .purple, .turquoise][i].soft)
                    Text("Page \(i + 1)").font(.headline)
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
        },
        .static("Validation", .molecules, usage: ##"TextInput("Email", text: $t).validate([.required(), .email()], on: .editingEnd).onValidation { ok in … }"##) {
            StatefulPreview("") { text in
                TextInput("Email", text: text).validate([.required(), .email()], on: .live)
            }
            .padding(.horizontal, 24)
        },

        // MARK: Organisms
        .knob("Accordion", .organisms, demo: AccordionDemo(), usage: #"Accordion("Title", initiallyExpanded: false) { Text("Body") }"#),
        .knob("AccordionGroup", .organisms, demo: AccordionGroupDemo(), usage: #"AccordionGroup(faqs) { $0.q } content: { Text($0.a) }.mode(.single)"#),
        .knob("AlertToast", .organisms, demo: AlertToastDemo(), usage: #"AlertToast("Saved").variant(.success).onClose { }"#),
        .knob("BlogCard", .organisms, demo: BlogCardDemo(), usage: #"BlogCard(title: "…") { mediaView }.excerpt("…").readMore { }"#),
        .knob("BottomSheet", .organisms, demo: BottomSheetDemo(), usage: #"// install once: .sheetHost()\n@Environment(SheetPresenter.self) var sheet: SheetPresenter\nsheet.present(detents: [.height(280), .large]) { FilterView() }\n// or declarative: someView.bottomSheet(isPresented: $open, detents: [.medium]) { … }"#),
        .knob("Callout", .organisms, demo: CalloutDemo(), usage: #"Callout("Message").variant(.success).calloutStyle(.plain)"#),
        .knob("Card", .organisms, demo: CardDemo(), usage: #"Card { content }.elevation(.soft)"#),
        .knob("ChatBubble", .organisms, demo: ChatBubbleDemo(), usage: #"ChatBubble("Hi!", time: "09:24").side(.outgoing).accent(.success)"#),
        .knob("Counter", .organisms, demo: CounterDemo(), usage: #"Counter(days: 2, hours: 8, minutes: 45)"#),
        .knob("DataTable", .organisms, demo: DataTableDemo(), usage: #"DataTable(columns: cols, rows: rows, selection: $selected).pageSize(10)"#),
        .knob("Drawer", .organisms, demo: DrawerDemo(), usage: #"someView.drawer(isPresented: $open, edge: .leading) { menu }\n// or imperative: install .drawerHost(); @Environment(DrawerPresenter.self) var drawer: DrawerPresenter\ndrawer.present(edge: .leading) { menu }   // drag-to-dismiss built in"#),
        .knob("FAB", .organisms, demo: FABDemo(), usage: #"FloatingActionButton(systemImage: "plus", actions: [.init(systemImage: "camera", action: { })])"#),
        .knob("Hero", .organisms, demo: HeroDemo(), usage: #"Hero(title: "…").subtitle("…").cta("Explore", action: { })"#),
        .knob("Stack", .organisms, demo: CardStackDemo(), usage: #"CardStack(items) { item in cardView }"#),
        .knob("Footer", .organisms, demo: FooterDemo(), usage: #"Footer(columns: [.init("Company", items: [.init("About")])], note: "© 2026")"#),
        .knob("Diff", .organisms, demo: DiffDemo(), usage: #"Diff { beforeView } after: { afterView }.aspect(1.6)"#),
        .knob("Timeline", .organisms, demo: TimelineDemo(), usage: #"Timeline([.init(title: "Placed", state: .done, color: .success)]).pending("Awaiting…")"#),
        .knob("Coupon", .organisms, demo: CouponDemo(), usage: #"Coupon(code: "UXMUQ", onCopy: { }).couponStyle(.outlined)"#),
        .knob("EmptyState", .organisms, demo: EmptyStateDemo(), usage: #"EmptyState("Empty").icon("tray").message("…").primaryAction("Retry") { }"#),
        .knob("Feedback", .organisms, demo: FeedbackDemo(), usage: #"@Environment(FeedbackPresenter.self) var feedback: FeedbackPresenter\nfeedback.toast("Saved", kind: .success)              // stacks\nfeedback.toast("Deleted", action: ToastAction("Undo") { }, duration: nil)\nawait feedback.toastTask(loading: "Saving…", success: "Saved") { try await save() }\n// install once: .feedbackHost(maxVisibleToasts: 3, toastPosition: .bottom)"#),
        .knob("Gallery", .organisms, demo: GalleryDemo(), usage: #"Gallery(items) { item in mediaView }.columns(2).aspect(.square)"#),
        .knob("ImageCollage", .organisms, demo: ImageCollageDemo(), usage: #"ImageCollage(urls) { index in open(index) }.height(220)   // 1·2·3·4+ layouts + "+N""#),
        .knob("InfoBanner", .organisms, demo: InfoBannerDemo(), usage: #"InfoBanner("Message", links: [("link", action)]).variant(.info)"#),
        .knob("ListRow", .organisms, demo: ListRowDemo(), usage: #"ListRow("Account", action: { }).subtitle("…").trailing(.chevron)"#),
        .knob("List", .organisms, demo: ListDemo(), usage: #"ListView(items) { ListRow($0.title) }.header("Settings").footer("3 items").bordered()"#),
        .knob("MenuCard", .organisms, demo: MenuCardDemo(), usage: #"MenuCard(items: [.init(title: "Reservations", systemImage: "calendar")])"#),
        .knob("NavigationBar", .organisms, demo: NavigationBarDemo(), usage: #"NavigationBar(items: [.init(systemImage: "house")], selection: $tab)"#),
        .knob("NotificationCard", .organisms, demo: NotificationDemo(), usage: #"NotificationCard(title: "…").message("…").date("…").unread()"#),
        .knob("PageHeader", .organisms, demo: PageHeaderDemo(), usage: #"PageHeader("Title").subtitle("…").onBack { }"#),
        .knob("PromoBanner", .organisms, demo: PromoBannerDemo(), usage: #"PromoBanner("…", action: { }).icon("sun.max.fill").ctaTitle("Go")"#),
        .knob("RatingSummary", .organisms, demo: RatingSummaryDemo(), usage: #"RatingSummary(score: 9.0).label("Excellent").reviews(count: 1200)"#),
        .knob("Result", .organisms, demo: ResultDemo(), usage: #"ResultView(.notFound, title: "Page not found").message("…").primaryAction("Home") { }"#),
        .knob("Popconfirm", .organisms, demo: PopconfirmDemo(), usage: ##"trigger.popconfirm(isPresented: $show, title: "Delete?", confirmTitle: "Delete") { delete() }"##),
        .knob("Tour", .organisms, demo: TourDemo(), usage: ##"view.tourTarget("search");  root.tourHost(tour, steps: [TourStep("search", title: "…", message: "…")])"##),
        .knob("Dialog", .organisms, demo: DialogDemo(), usage: #"view.dialog(isPresented: $show, title: "…") { content } footer: { buttons }"#),
        .knob("SegmentedTabBar", .organisms, demo: SegmentedTabBarDemo(), usage: #"SegmentedTabBar([TabItem("Reviews", badge: "12"), TabItem("Off", isEnabled: false)], selection: $i).tabStyle(.pill)"#),
        .knob("SelectionCards", .organisms, demo: SelectionCardsDemo(), usage: #"RadioCard("Standard", isSelected: sel == id) { sel = id }.description("…")"#),
        .knob("Upload", .organisms, demo: UploadDemo(), usage: #"@State var uploads = UploadController()\nUploadList(controller: uploads) { /* pick */ }\nawait uploads.upload(name: file.name) { progress in /* report 0…1 */ }"#),
        .knob("Carousel", .organisms, demo: CarouselDemo(), usage: #"Carousel(items) { item in mediaView }.autoplay(2).arrows()"#),
        .knob("PagingCarousel", .organisms, demo: PagingCarouselDemo(), usage: #"PagingCarousel(items) { item in mediaView }.peek(36).autoplay(2)"#),
        .knob("VideoPlayer", .organisms, demo: VideoPlayerDemo(), usage: #"VideoPlayerView(url).loop().muted().muteToggle()"#),
        .knob("KeyValueTable", .organisms, demo: KeyValueTableDemo(), usage: #"KeyValueTable(rows: [...]).title("Summary").bordered()"#),
        .knob("FlightCard", .organisms, demo: FlightCardDemo(), usage: #"FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr).stops(0).price(1_299).badge("Cheapest").scarcity(3).fareBrand("Eco Flex").onSelect { }\n// multi-leg: FlightCard(legs: [outbound, ret]).price(7_178)"#),
        .knob("FareSummary", .organisms, demo: FareSummaryDemo(), usage: #"FareSummary([.item("Base fare", 1_100, info: "…"), .discount("Member", 100), .total("Total", 1_199)]).onInfo { line in } footer: { TermsLink() }"#),
        .knob("ReviewCard", .organisms, demo: ReviewCardDemo(), usage: #"ReviewCard(author: "Elif K.", score: 9.2, text: "…").date(d).title("…").verified().stars().expandable().photos(urls).onPhotoTap { }"#),
        .knob("LoyaltyCard", .organisms, demo: LoyaltyCardDemo(), usage: #"LoyaltyCard(tier: "Gold", points: 8_430).memberName("Elif K.").progress(0.62, toNextTier: "Platinum").membership(.qr(id)).flippable().logo { }"#),
        .knob("SeatMap", .organisms, demo: SeatMapDemo(), usage: ##"SeatMap(columns: "ABC DEF", rows: Array(1...30), selection: $picked) { id, row, col in\n    SeatInfo(available: !sold.contains(id), price: row <= 3 ? 600 : 80, tier: row == 14 ? .exit : .standard)\n}.legend().showsSeatInfo().recommended(["11C"])"##),
        .static("Seat Layouts", .organisms, usage: ##"// letters = seats, spaces = gaps (repeat = wider aisle)\nSeatMap(columns: "AB CDE FG", rows: Array(1...30), selection: $picked)   // 2·3·2"##) { SeatLayoutsShowcase() },
        .knob("LocationCard", .organisms, demo: LocationCardDemo(), usage: #"LocationCard(title: "Marina Bay Hotel", latitude: 38.42, longitude: 27.14).subtitle("…").distance("1.2 km").directions().pois(pins).snapshot()"#),
        .knob("TicketStub", .organisms, demo: TicketStubDemo(), usage: #"TicketStub { FlightCard(...) }.stub { Barcode(id).showsValue() }.notchRadius(12).perforation().elevation(.elevated)"#),
        .knob("DestinationCard", .organisms, demo: DestinationCardDemo(), usage: #"DestinationCard("Bali & 3-Days", image: url).ribbon("Top #1").price(1_450).rating(4.8).favorite($fav).tags(["Beach", "Culture"]).onTap { }"#),
        .knob("FareFamilyCard", .organisms, demo: FareFamilyCardDemo(), usage: ##"FareFamilyCard("Super Eco", price: 1_871.99).accent(.success).features([FareFeature("Cabin bag", systemImage: "handbag")]).selection($picked)"##),
        .knob("FlightResultRow", .organisms, demo: FlightResultRowDemo(), usage: ##"FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: arr).flightNo("TK 2434").price(3_538.99).baggage("15 kg").badge("Cheapest").returnLeg(from: "AYT", to: "IST", departure: d2, arrival: a2).onSelect { }"##),
        .knob("DateRangePicker", .organisms, demo: DateRangePickerDemo(), usage: ##"DateRangePicker(.hotel) { result in … }.display(.month/.week/.year/.browse).daySelection(.rounded).accent(.turquoise).day { ctx in HeatCell(ctx) }.holiday(on: days, color: .error, name: "…")   // or someView.dateRangePicker(isPresented: $show) { … }"##),
        .knob("SheetHeader", .organisms, demo: SheetHeaderDemo(), usage: ##"SheetHeader("Passengers").onBack { }.onClose { }.progress(0.4)   // modal header (not the tab NavigationBar)"##),
        .knob("Calendar Designer", .organisms, demo: CalendarDesignerDemo(), usage: ##"CalendarStyleConfigurator(style: $style)   // live design playground → style.generatedSwiftCode (Almanac)"##),
        .knob("TimeWheel", .molecules, demo: TimeWheelDemo(), usage: ##"TimeWheel(hour: $h, minute: $m, isAM: $am).format(.amPm)   // themed drum time picker (Almanac)"##),
        .knob("FilterRow", .molecules, demo: FilterRowDemo(), usage: ##"FilterRow("Direct", isOn: $direct).count(128).icon("airplane")   // Checkbox atom + title + count"##),
        .knob("FilterList", .organisms, demo: FilterListDemo(), usage: ##"FilterList([FilterOption("Direct", count: 128), …], selection: $stops).title("Stops").bordered().selectAll("All")"##),
        .knob("FilterBar", .organisms, demo: FilterBarDemo(), usage: ##"FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront"), …], selection: $active).onFilter { }.onSort { }   // leading buttons collapse on scroll"##),
        .knob("HotelResultCard", .organisms, demo: HotelResultCardDemo(), usage: ##"HotelResultCard(name: "Mirage Park Resort").images(urls).score(8.9, reviews: 949).features([…]).original(248_000).discountBadge("-23%").price(190_960).extraDiscount("Extra 8%", 175_683).favorite($fav).onSelect { }"##),
        .knob("FlightTicketCard", .organisms, demo: FlightTicketCardDemo(), usage: ##"FlightTicketCard(from: "NYC", to: "SFO").cities(from: "New York City", to: "San Francisco").duration("1h 45m").times(departure: "10:00 AM", arrival: "11:30 AM").airline("Garuda").price(140, currencyCode: "USD").favorite($fav)"##),
        .knob("BoardingPass", .organisms, demo: BoardingPassDemo(), usage: ##"BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER").airline("Pegasus").flightNo("PC 1234").times(departure: "13:15", arrival: "16:05").gate("A12", seat: "14C", boarding: "12:45").barcode("…")"##),
        .knob("AncillaryCard", .organisms, demo: AncillaryCardDemo(), usage: ##"AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg").price(450, suffix: "/ bag").quantity($bags, range: 0...4)   // or .added($on)"##),
        .knob("RoomCard", .organisms, demo: RoomCardDemo(), usage: ##"RoomCard(name: "Deluxe Room").board("All-inclusive").features([FareFeature(…)]).original(12_000).discountBadge("-20%").price(9_600).unit("/ night").onSelect { }"##),
        .knob("StickyBookingBar", .organisms, demo: StickyBookingBarDemo(), usage: ##"StickyBookingBar("Book now") { }.price(9_600).original(12_000).discountBadge("-20%").note("2 rooms · 4 nights")   // .safeAreaInset(.bottom)"##),
        .knob("MapCallout", .organisms, demo: MapCalloutDemo(), usage: ##"MapCallout(title: "Mirage Park Resort").image(url).score(8.9).price(9_600).onSelect { }   // over any Map, no MapKit dep"##),
        .knob("AgentPriceRow", .organisms, demo: AgentPriceRowDemo(), usage: ##"AgentPriceRow("Trip.com") { open() }.logo(url).rating(4.2).badge("Cheapest").original(4_100).price(3_538).cta("Go to site").recommended()"##),
        .knob("PriceAlertCard", .organisms, demo: PriceAlertCardDemo(), usage: ##"PriceAlertCard("Get price alerts", isOn: $alerts).subtitle("…").price(3_538).trend(.down, "-8%")"##),
        .knob("PaymentCardField", .molecules, demo: PaymentCardFieldDemo(), usage: ##"PaymentCardField(number: $n, expiry: $e, cvv: $c).holder($name)   // brand auto-detect + 4-4-4-4 / MM/YY"##),
        .knob("InstallmentPicker", .molecules, demo: InstallmentPickerDemo(), usage: ##"InstallmentPicker([InstallmentOption(count: 3, total: 9_900, monthly: 3_300), …], selection: $count).currency("TRY")"##),
        .knob("MapPriceMarker", .molecules, demo: MapPriceMarkerDemo(), usage: ##"MapPriceMarker("₺1.250").selected(isActive).icon("heart.fill")   // in any Map annotation"##),
        .knob("Theme Injection", .organisms, demo: ThemeInjectionDemo(), usage: #"let ocean = Theme(); ocean.loadTheme(named: "oceanTheme")\nmySubtree.theme(ocean)   // re-skins just this subtree"#),
        .static("BrowserFrame", .organisms, usage: ##"BrowserFrame(url: "https://themekit.dev") { content }.accent(.primary)"##) {
            BrowserFrame(url: "https://themekit.dev") {
                VStack(spacing: 8) {
                    Text("Hello, web").font(.headline)
                    Text("Any content works here").font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(36)
            }
            .padding(.horizontal, 24)
        },
        .static("WindowFrame", .organisms, usage: ##"WindowFrame("Preferences") { content }.accent(.info)"##) {
            WindowFrame("Preferences") {
                VStack(spacing: 8) {
                    Text("General").font(.headline)
                    Text("Window chrome around any content").font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(36)
            }
            .padding(.horizontal, 24)
        },
        .knob("Flexibility Showcase", .organisms, demo: FlexibilityShowcaseDemo(), usage: #"ListRow("…").leading { Avatar(…) }.listRowStyle(TimelineRowStyle())   // slots + custom styles, fork-free"#),
        .static("PhoneFrame", .organisms, usage: ##"PhoneFrame { AppScreen() }.notch(.island).bezel(.neutral)"##) {
            PhoneFrame {
                VStack(spacing: 8) {
                    Text("📱").font(.largeTitle)
                    Text("App screen").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 380)
        },
    ]

    static func entries(in category: ComponentCategory) -> [ComponentEntry] {
        all.filter { $0.category == category }.sorted { $0.name < $1.name }
    }
}
