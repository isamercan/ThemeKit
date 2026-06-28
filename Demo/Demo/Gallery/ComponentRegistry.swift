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

enum ComponentRegistry {
    static let all: [ComponentEntry] = [
        // MARK: Atoms
        .knob("Avatar", .atoms, demo: AvatarDemo(), usage: #"Avatar(.initials("AB"), size: .md, presence: .online)"#),
        .knob("Badge", .atoms, demo: BadgeDemo(), usage: #"Badge("Label", style: .info, leadingSystemImage: "star.fill")"#),
        .knob("Chip", .atoms, demo: ChipDemo(), usage: #"Chip("Recommended", isSelected: $selected, selectionStyle: .tonal)"#),
        .knob("Color Palette", .atoms, demo: ColorLadderDemo(), usage: #"SemanticColor.primary.shade(.s500)   // base · .bg .hover .active .strong"#),
        .knob("CountBadge", .atoms, demo: CountBadgeDemo(), usage: ##"icon.countBadge(5)   //  .dotBadge() · Ribbon("New") { card }"##),
        .knob("BorderBeam", .atoms, demo: BorderBeamDemo(), usage: #"card.borderBeam(cornerRadius: 16, lineWidth: 2)"#),
        .knob("Divider", .atoms, demo: DividerDemo(), usage: #"DividerView(dashed: true, title: "OR", titleAlign: .center)"#),
        .knob("Icon", .atoms, demo: IconDemo(), usage: #"Icon(systemName: "star.fill", size: .md, color: theme.foreground(.fgHero))"#),
        .knob("InputLabel", .atoms, demo: InputLabelDemo(), usage: #"InputLabel("Email", isRequired: true, hasInfo: true)"#),
        .knob("ProgressBar", .atoms, demo: ProgressBarDemo(), usage: #"ProgressBar(value: 0.4, showPercentage: true)"#),
        .knob("RadialProgress", .atoms, demo: RadialProgressDemo(), usage: #"RadialProgress(value: 0.6, size: 96, showLabel: true)"#),
        .knob("RemoteImage", .atoms, demo: RemoteImageDemo(), usage: #"RemoteImage(url, ratio: "16:9", cornerRadius: 12)   // .gif/.apng animate natively"#),
        .static("AnimatedImage", .atoms, usage: #"AnimatedImage(gifURL)   // GIF/APNG via ImageIO — no dependency"#) { AnimatedImage(URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/d3/Newtons_cradle_animation_book_2.gif")).frame(width: 180, height: 180).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) },
        .knob("RollingNumber", .atoms, demo: RollingNumberDemo(), usage: #"RollingNumber(1284, size: 40)   // odometer digit roll"#),
        .knob("Indicator", .atoms, demo: IndicatorDemo(), usage: #"icon.indicatorDot()   // or .indicator { Badge("3") }"#),
        .static("Kbd", .atoms, usage: #"Kbd("⌘")  Kbd("K")"#) { HStack(spacing: 6) { Kbd("⌘"); Kbd("K"); Text("then").font(.caption).foregroundStyle(.secondary); Kbd("esc") } },
        .knob("Status", .atoms, demo: StatusDotDemo(), usage: #"StatusDot(.online, label: "Online", pulse: true)"#),
        .knob("Swap", .atoms, demo: SwapDemo(), usage: #"Swap(isOn: $on, on: "xmark", off: "line.3.horizontal")"#),
        .knob("TextLink", .atoms, demo: TextLinkDemo(), usage: #"TextLink("Forgot password?", underline: true) { }"#),
        .knob("Rating", .atoms, demo: RatingDemo(), usage: #"Rating(value: 4.5, allowHalf: true) { value = $0 }"#),
        .knob("ScoreBadge", .atoms, demo: ScoreBadgeDemo(), usage: #"ScoreBadge(9.0, large: false)"#),
        .knob("Skeleton", .atoms, demo: SkeletonDemo(), usage: #"Text("Loading…").skeleton(isLoading)"#),
        .knob("Spinner", .atoms, demo: SpinnerDemo(), usage: #"Spinner(size: 24, lineWidth: 3)"#),
        .knob("Tag", .atoms, demo: TagDemo(), usage: #"Tag("Sold out", style: .error, variant: .solid, onRemove: { })"#),
        .knob("Title", .atoms, demo: TitleDemo(), usage: #"Title("Section", subtitle: "Sub", actionTitle: "See all", action: { })"#),
        .static("InlineText", .atoms, usage: #"InlineText("Accept the Terms.", links: [("Terms", { })])"#) {
            InlineText("By continuing you accept the Terms and the Privacy Policy.", links: [("Terms", {}), ("Privacy Policy", {})])
        },
        .static("Join", .atoms, usage: #"Join { ButtonA; ButtonB; ButtonC }   // connected group, rounded outer corners"#) {
            Join { ForEach(["Day", "Week", "Month"], id: \.self) { Text($0).textStyle(.labelBase600).padding(.horizontal, 14).frame(height: 40) } }
        },
        .static("Mask", .atoms, usage: #"image.themeMask(.squircle)   // .circle / .squircle / .hexagon / .star"#) {
            HStack(spacing: 14) { ForEach(MaskShape.allCases, id: \.self) { Rectangle().fill(.blue.gradient).frame(width: 52, height: 52).themeMask($0) } }
        },
        .static("TextRotate", .atoms, usage: #"TextRotate(["faster.", "themed.", "accessible."], interval: 2)"#) {
            HStack(spacing: 4) { Text("Build").textStyle(.headingSm); TextRotate(["faster.", "themed.", "accessible."]) }
        },
        .static("Gauge", .atoms, usage: #"GaugeView(value: 0.72, label: "CPU", style: .circular)"#) {
            HStack(spacing: 24) { GaugeView(value: 0.72, label: "CPU"); GaugeView(value: 0.4, label: "Disk", style: .linear).frame(width: 140) }
        },
        .static("ShareButton", .atoms, usage: #"ShareButton(item: url)   // wraps SwiftUI ShareLink"#) {
            ShareButton(item: "https://github.com/isamercan/ThemeKit")
        },

        // MARK: Molecules
        .static("ColorField", .molecules, usage: #"ColorField("Brand color", selection: $color)"#) {
            ColorField("Brand color", selection: .constant(.blue)).frame(maxWidth: 320)
        },
        .knob("Autocomplete", .molecules, demo: AutocompleteDemo(), usage: #"Autocomplete(label: "Destination", text: $text, suggestions: items)\n// async: Autocomplete(text: $text, suggest: { await api.search($0) })"#),
        .knob("Button", .molecules, demo: ButtonDemo(), usage: #"PrimaryButton("Continue") { }"#),
        .knob("ButtonGroup", .molecules, demo: ButtonGroupDemo(), usage: #"ButtonGroup { PrimaryButton("OK") { } }"#),
        .knob("ThemeButton", .molecules, demo: ThemeButtonDemo(), usage: #"ThemeButton("Save", color: .success, variant: .soft, size: .medium, shape: .pill) { }"#),
        .knob("Checkbox", .molecules, demo: CheckboxDemo(), usage: #"Checkbox("Accept terms", isChecked: $on, infoMessages: error ? [.init("Required", kind: .error)] : [])"#),
        .knob("CheckboxGroup", .molecules, demo: CheckboxGroupDemo(), usage: #"CheckboxGroup(options: items, selection: $set) { $0 }"#),
        .knob("InputNumber", .molecules, demo: InputNumberDemo(), usage: #"InputNumber(label: "Max price", value: $n, range: 0...10000, step: 50, unit: "₺")"#),
        .knob("MultiLineTextInput", .molecules, demo: MultiLineDemo(), usage: #"MultiLineTextInput("Notes", text: $text, characterLimit: 200)"#),
        .knob("OTPInput", .molecules, demo: OTPDemo(), usage: #"OTPInput(code: $code, digitCount: 6, isSecure: true,\n         onComplete: { verify($0) }, resendInterval: 30, onResend: { resend() })"#),
        .knob("Breadcrumbs", .molecules, demo: BreadcrumbsDemo(), usage: #"Breadcrumbs([.init("Home", action: { }), .init("Current")], maxItems: 4)"#),
        .knob("Calendar", .molecules, demo: CalendarDemo(), usage: #"CalendarView(selection: $date)"#),
        .knob("DateField", .molecules, demo: DateFieldDemo(), usage: ##"DateField(label: "Check-in", date: $date, style: .custom("EEE, d MMM"), allowClear: true)"##),
        .knob("Fieldset", .molecules, demo: FieldsetDemo(), usage: #"Fieldset("Contact", helper: "…") { inputs }"#),
        .knob("Form", .molecules, demo: FormDemo(), usage: ##"@State var form = FormValidator<Field>([.email: [.required(), .email()]])\nform.validateAll([.email: email])  // → first invalid field, focuses it"##),
        .knob("FileInput", .molecules, demo: FileInputDemo(), usage: #"FileInput(label: "Passport", fileName: name) { pick() }"#),
        .knob("FilterGroup", .molecules, demo: FilterGroupDemo(), usage: #"FilterGroup(options: items, selection: $sel) { $0 }"#),
        .knob("Chips", .molecules, demo: ChipsDemo(), usage: #"CompactChip(isSelected: $on, text: "Suit", price: "₺899", rating: 4.6)   // ChoseChip · ImageChip · FilterChip · ChipGroup"#),
        .knob("ProgressIndicator", .molecules, demo: ProgressIndicatorDemo(), usage: #"ProgressIndicator(variant: .carousel, current: 2, total: 8, stepText: .slash)"#),
        .knob("ThemeController", .molecules, demo: ThemeControllerDemo(), usage: #"ThemeController(options: [.init(name: "oceanTheme", label: "Ocean")], selectedName: $name)"#),
        .knob("Pagination", .molecules, demo: PaginationDemo(), usage: #"Pagination(current: $page, total: 50, siblingCount: 2, showJumper: true)"#),
        .knob("Stat", .molecules, demo: StatDemo(), usage: #"Stat(title: "Bookings", value: "1,284", systemImage: "ticket", trend: .up("+12%"))"#),
        .knob("Steps", .molecules, demo: StepsDemo(), usage: #"Steps([.init("Cart", description: "2 items", state: .done), .init("Pay", state: .error)]) { active = $0 }"#),
        .knob("QuantityStepper", .molecules, demo: QuantityStepperDemo(), usage: #"QuantityStepper(value: $qty, range: 0...10)"#),
        .knob("Micro-motion", .molecules, demo: MicroMotionDemo(), usage: #"View().microAnimations(false)   // theme-wide at root, or per-component"#),
        .knob("RadioButton", .molecules, demo: RadioButtonDemo(), usage: #"RadioButton(isSelected: $on)"#),
        .knob("RadioGroup", .molecules, demo: RadioGroupDemo(), usage: #"RadioGroup(options: items, selection: $sel) { $0 }"#),
        .knob("RangeSlider", .molecules, demo: RangeSliderDemo(), usage: #"RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50, marks: [0, 500, 1000], onChangeEnd: search)"#),
        .knob("SearchBar", .molecules, demo: SearchBarDemo(), usage: #"SearchBar(text: $text, suggestions: cities, recent: recent, onSubmit: search)"#),
        .knob("SegmentedControl", .molecules, demo: SegmentedControlDemo(), usage: #"SegmentedControl([SegmentItem("List", systemImage: "list.bullet")], selection: $i)"#),
        .knob("Select", .molecules, demo: SelectDemo(), usage: #"Select("City", options: items, selection: $city, searchable: true, isLoading: loading) { $0 }"#),
        .knob("MultiSelect", .molecules, demo: MultiSelectDemo(), usage: #"MultiSelect(label: "Cities", options: items, selection: $set, isLoading: loading, isOptionEnabled: { $0.inStock }) { $0 }"#),
        .knob("TreeSelect", .molecules, demo: TreeSelectDemo(), usage: #"TreeSelect(label: "Cities", nodes: tree, selection: $set, initiallyExpanded: ["tr"])"#),
        .knob("SelectBox", .molecules, demo: SelectBoxDemo(), usage: #"SelectBox(label: "Country", options: items, selection: $sel) { $0 }"#),
        .knob("Slider", .molecules, demo: SliderDemo(), usage: #"Slider(value: $v, in: 0...8, marks: [0: "0", 8: "Max"], showValueTooltip: true)"#),
        .knob("TextInput", .molecules, demo: TextInputDemo(), usage: ##"TextInput("Email", text: $t, keyboardType: .emailAddress, textContentType: .emailAddress, submitLabel: .next)"##),
        .knob("ThemeToggle", .molecules, demo: ToggleDemo(), usage: #"ThemeToggle(isOn: $on, isLoading: false, onSystemImage: "checkmark")"#),
        .knob("ToggleGroup", .molecules, demo: ToggleGroupDemo(), usage: #"ToggleGroup(options: items, selection: $set, label: { $0 })"#),
        .knob("Tooltip", .molecules, demo: TooltipDemo(), usage: #"anchorView.tooltip("Hint", isPresented: $shown, edge: .top)"#),

        // MARK: Organisms
        .knob("Accordion", .organisms, demo: AccordionDemo(), usage: #"Accordion("Title", initiallyExpanded: false) { Text("Body") }"#),
        .knob("AccordionGroup", .organisms, demo: AccordionGroupDemo(), usage: #"AccordionGroup(faqs, mode: .single) { $0.q } content: { Text($0.a) }"#),
        .knob("AlertToast", .organisms, demo: AlertToastDemo(), usage: #"AlertToast("Saved", type: .success, onClose: { })"#),
        .knob("BlogCard", .organisms, demo: BlogCardDemo(), usage: #"BlogCard(title: "…", excerpt: "…", onReadMore: { }) { mediaView }"#),
        .knob("BottomSheet", .organisms, demo: BottomSheetDemo(), usage: #"// install once: .sheetHost()\n@Environment(SheetPresenter.self) var sheet: SheetPresenter\nsheet.present(detents: [.height(280), .large]) { FilterView() }\n// or declarative: someView.bottomSheet(isPresented: $open, detents: [.medium]) { … }"#),
        .knob("Callout", .organisms, demo: CalloutDemo(), usage: #"Callout("Message", type: .success, style: .plain)"#),
        .knob("Card", .organisms, demo: CardDemo(), usage: #"Card(elevation: .soft) { content }"#),
        .knob("ChatBubble", .organisms, demo: ChatBubbleDemo(), usage: #"ChatBubble("Hi!", side: .outgoing, time: "09:24", avatarSystemImage: "person.fill")"#),
        .knob("Counter", .organisms, demo: CounterDemo(), usage: #"Counter(days: 2, hours: 8, minutes: 45)"#),
        .knob("DataTable", .organisms, demo: DataTableDemo(), usage: #"DataTable(columns: cols, rows: rows, selection: $selected, pageSize: 10)"#),
        .knob("Drawer", .organisms, demo: DrawerDemo(), usage: #"someView.drawer(isPresented: $open, edge: .leading) { menu }\n// or imperative: install .drawerHost(); @Environment(DrawerPresenter.self) var drawer: DrawerPresenter\ndrawer.present(edge: .leading) { menu }   // drag-to-dismiss built in"#),
        .knob("FAB", .organisms, demo: FABDemo(), usage: #"FloatingActionButton(systemImage: "plus", actions: [.init(systemImage: "camera", action: { })])"#),
        .knob("Hero", .organisms, demo: HeroDemo(), usage: #"Hero(title: "…", subtitle: "…", ctaTitle: "Explore", action: { })"#),
        .knob("Stack", .organisms, demo: CardStackDemo(), usage: #"CardStack(items) { item in cardView }"#),
        .static("Footer", .organisms, usage: #"Footer(columns: [.init("Company", items: [.init("About")])], note: "© 2026")"#) {
            Footer(columns: [.init("Company", items: [.init("About"), .init("Careers")]), .init("Support", items: [.init("Help"), .init("Contact")]), .init("Legal", items: [.init("Terms"), .init("Privacy")])], note: "© 2026 ThemeKit.")
        },
        .static("Diff", .organisms, usage: #"Diff { beforeView } after: { afterView }"#) {
            Diff {
                Theme.shared.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
            } after: {
                Theme.shared.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
            }
        },
        .knob("Timeline", .organisms, demo: TimelineDemo(), usage: #"Timeline([.init(title: "Placed", state: .done, color: .success)], pending: "Awaiting…")"#),
        .knob("Coupon", .organisms, demo: CouponDemo(), usage: #"Coupon(code: "UXMUQ", style: .outlined, onCopy: { })"#),
        .knob("EmptyState", .organisms, demo: EmptyStateDemo(), usage: #"EmptyState(systemImage: "tray", title: "Empty", message: "…", buttonTitle: "Retry", action: { })"#),
        .knob("Feedback", .organisms, demo: FeedbackDemo(), usage: #"@Environment(FeedbackPresenter.self) var feedback: FeedbackPresenter\nfeedback.toast("Saved", kind: .success)              // stacks\nfeedback.toast("Deleted", action: ToastAction("Undo") { }, duration: nil)\nawait feedback.toastTask(loading: "Saving…", success: "Saved") { try await save() }\n// install once: .feedbackHost(maxVisibleToasts: 3, toastPosition: .bottom)"#),
        .knob("Gallery", .organisms, demo: GalleryDemo(), usage: #"Gallery(items, columns: 2, aspect: .square) { item in mediaView }"#),
        .knob("ImageCollage", .organisms, demo: ImageCollageDemo(), usage: #"ImageCollage(urls, height: 220) { index in open(index) }   // 1·2·3·4+ layouts + "+N""#),
        .knob("InfoBanner", .organisms, demo: InfoBannerDemo(), usage: #"InfoBanner("Message", type: .info, links: [("link", action)])"#),
        .knob("ListRow", .organisms, demo: ListRowDemo(), usage: #"ListRow("Account", subtitle: "…", trailing: .chevron, action: { })"#),
        .knob("List", .organisms, demo: ListDemo(), usage: #"ListView(items, header: "Settings", footer: "3 items", bordered: true) { ListRow($0.title) }"#),
        .knob("MenuCard", .organisms, demo: MenuCardDemo(), usage: #"MenuCard(items: [.init(title: "Reservations", systemImage: "calendar")])"#),
        .knob("NavigationBar", .organisms, demo: NavigationBarDemo(), usage: #"NavigationBar(items: [.init(systemImage: "house")], selection: $tab)"#),
        .knob("NotificationCard", .organisms, demo: NotificationDemo(), usage: #"NotificationCard(title: "…", message: "…", date: "…", isUnread: true)"#),
        .knob("PageHeader", .organisms, demo: PageHeaderDemo(), usage: #"PageHeader("Title", subtitle: "…", onBack: { })"#),
        .knob("PromoBanner", .organisms, demo: PromoBannerDemo(), usage: #"PromoBanner(title: "…", systemImage: "sun.max.fill", ctaTitle: "Go", action: { })"#),
        .knob("RatingSummary", .organisms, demo: RatingSummaryDemo(), usage: #"RatingSummary(score: 9.0, label: "Mükemmel", reviewCount: 1200)"#),
        .knob("Result", .organisms, demo: ResultDemo(), usage: #"ResultView(.notFound, title: "Sayfa bulunamadı", message: "…", primaryTitle: "Ana sayfa") { }"#),
        .knob("Popconfirm", .organisms, demo: PopconfirmDemo(), usage: ##"trigger.popconfirm(isPresented: $show, title: "Sil?", confirmTitle: "Sil") { delete() }"##),
        .knob("Tour", .organisms, demo: TourDemo(), usage: ##"view.tourTarget("search");  root.tourHost(tour, steps: [TourStep("search", title: "…", message: "…")])"##),
        .knob("Dialog", .organisms, demo: DialogDemo(), usage: #"view.dialog(isPresented: $show, title: "…") { content } footer: { buttons }"#),
        .knob("SegmentedTabBar", .organisms, demo: SegmentedTabBarDemo(), usage: #"SegmentedTabBar([TabItem("Reviews", badge: "12"), TabItem("Off", isEnabled: false)], selection: $i)"#),
        .knob("SelectionCards", .organisms, demo: SelectionCardsDemo(), usage: #"RadioCard("Standard", description: "…", isSelected: sel == id) { sel = id }"#),
        .knob("Upload", .organisms, demo: UploadDemo(), usage: #"@State var uploads = UploadController()\nUploadList(controller: uploads) { /* pick */ }\nawait uploads.upload(name: file.name) { progress in /* report 0…1 */ }"#),
        .knob("Carousel", .organisms, demo: CarouselDemo(), usage: #"Carousel(items, autoplay: 2, showsArrows: true) { item in mediaView }"#),
        .knob("PagingCarousel", .organisms, demo: PagingCarouselDemo(), usage: #"PagingCarousel(items, peek: 36, autoplay: 2) { item in mediaView }"#),
        .knob("VideoPlayer", .organisms, demo: VideoPlayerDemo(), usage: #"VideoPlayerView(url, autoplay: true, loop: true, muted: true)"#),
        .static("KeyValueTable", .organisms, usage: #"KeyValueTable(rows: [...], title: "Özet", bordered: true)"#) {
            KeyValueTable(rows: [.init("Status", value: "Aktif", style: .success), .init("Old price", value: "5.000 TL", style: .strikethrough), .init("Total", value: "4.250 TL")], title: "Rezervasyon özeti", bordered: true)
        },
        .knob("Theme Injection", .organisms, demo: ThemeInjectionDemo(), usage: #"let ocean = Theme(); ocean.loadTheme(named: "oceanTheme")\nmySubtree.theme(ocean)   // re-skins just this subtree"#),
    ]

    static func entries(in category: ComponentCategory) -> [ComponentEntry] {
        all.filter { $0.category == category }.sorted { $0.name < $1.name }
    }
}
