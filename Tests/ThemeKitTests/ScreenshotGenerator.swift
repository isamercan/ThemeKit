//
//  ScreenshotGenerator.swift
//  ThemeKitTests
//
//  Renders a representative example of (almost) every component to
//  Screenshots/<Name>.png via SwiftUI's ImageRenderer — no simulator needed, runs
//  under `swift test` on macOS. Opt-in: only runs when GENERATE_SCREENSHOTS=1.
//
//      GENERATE_SCREENSHOTS=1 swift test --filter ScreenshotGenerator
//      scripts/gen-screenshots.sh          # generate + rebuild the README gallery
//
//  Pure-overlay / presenter / network-image / video components (Dialog, Drawer,
//  BottomSheet, Tour, Feedback, VideoPlayer, RemoteImage, …) are best seen live in
//  the Demo app and are intentionally not captured here.
//

#if os(macOS)
import XCTest
import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import ThemeKit

@available(macOS 13.0, *)
@MainActor
final class ScreenshotGenerator: XCTestCase {

    private var outDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Screenshots", isDirectory: true)
    }

    /// `(category, name)` in render order — written to Screenshots/manifest.tsv so
    /// the README gallery can be rebuilt grouped, without duplicating this list.
    private var manifest: [(String, String)] = []
    private var category = ""
    /// Active appearance for the current render pass — drives the file suffix
    /// (`<name>` vs `<name>-dark`) and the backdrop, so the README can serve a
    /// `<picture>` that follows the reader's color scheme.
    private var scheme: ColorScheme = .light

    /// Identifiable stand-in + colored tiles for the media containers (Carousel /
    /// Gallery / CardStack) so they render without network images.
    private struct Tile: Identifiable { let id: Int; let color: Color }
    private var tiles: [Tile] {
        [SemanticColor.primary, .success, .warning, .info].enumerated().map { Tile(id: $0.offset, color: $0.element.solid) }
    }
    private func tileView(_ tile: Tile) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tile.color)
            .frame(height: 120)
            .overlay(Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(.white.opacity(0.9)))
    }

    func testGenerateAll() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GENERATE_SCREENSHOTS"] == "1",
            "Set GENERATE_SCREENSHOTS=1 to render component screenshots."
        )
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // Opt-in: BANNER_ONLY=1 re-renders just the header banner (e.g. after a
        // count change) without touching the 96 component PNGs.
        let bannerOnly = ProcessInfo.processInfo.environment["BANNER_ONLY"] == "1"

        func renderAll() {
            shot("Banner", featureBanner(), inGallery: false)   // README header banner (not a gallery row)
            if bannerOnly { return }
            category = "Atoms"; atoms()
            category = "Molecules"; molecules()
            category = "Organisms"; organisms()
            category = "Guides"; shot("ThemeInjection", themeInjectionProof())
        }

        // Light pass → `<name>.png` (+ manifest). Dark pass → `<name>-dark.png`.
        scheme = .light; Theme.shared.loadTheme(named: "defaultTheme", dark: false); renderAll()
        scheme = .dark;  Theme.shared.loadTheme(named: "defaultTheme", dark: true);  renderAll()
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)   // restore

        guard !bannerOnly else { return }   // keep the existing manifest.tsv intact
        let tsv = manifest.map { "\($0.0)\t\($0.1)" }.joined(separator: "\n") + "\n"
        try tsv.write(to: outDir.appendingPathComponent("manifest.tsv"), atomically: true, encoding: .utf8)
    }

    // MARK: Atoms

    private func atoms() {
        shot("Avatar", HStack(spacing: 12) {
            Avatar(.initials("CD")).size(.lg).presence(.online)
            Avatar(.initials("AB")).size(.md)
            Avatar(.icon("person.fill")).size(.md)
        })
        shot("Badge", HStack(spacing: 8) {
            Badge("Success").badgeStyle(.success)
            Badge("Info").badgeStyle(.info).icon("star.fill")
            Badge("Error").badgeStyle(.error).variant(.solid)
        })
        shot("Chip", HStack(spacing: 8) {
            Chip("Selected", isSelected: .constant(true))
            Chip("Unselected", isSelected: .constant(false))
        })
        shot("CountBadge", Icon(systemName: "bell").size(.xl).color(Theme.shared.text(.textPrimary)).countBadge(5))
        shot("Divider", DividerView("OR").dashed().titleAlign(.center).frame(width: 240))
        shot("Icon", HStack(spacing: 14) {
            Icon(systemName: "star.fill").size(.xl).color(Theme.shared.foreground(.fgHero))
            Icon(systemName: "heart.fill").size(.xl).color(Theme.shared.foreground(.systemcolorsFgError))
            Icon(systemName: "checkmark.seal.fill").size(.xl).color(Theme.shared.foreground(.systemcolorsFgSuccess))
        })
        shot("Indicator", Icon(systemName: "bell").size(.xl).color(Theme.shared.text(.textPrimary)).indicatorDot())
        shot("InputLabel", InputLabel("Email").required().hasInfo())
        shot("Kbd", HStack(spacing: 6) { Kbd("⌘"); Kbd("K") })
        shot("ProgressBar", ProgressBar(value: 0.6).showsPercentage().frame(width: 240))
        shot("RadialProgress", RadialProgress(0.66).size(96).showsLabel())
        shot("Rating", Rating(value: 4.3).countLabel("(128)"))
        shot("RollingNumber", RollingNumber(1284).size(40))
        shot("ScoreBadge", ScoreBadge(9.0))
        shot("Skeleton", HStack(spacing: 12) {
            Skeleton(.circle).size(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(.capsule).size(width: 160, height: 12)
                Skeleton(.capsule).size(width: 110, height: 12)
            }
        })
        shot("Spinner", Spinner().size(32).lineWidth(3))
        shot("StatusDot", HStack(spacing: 16) {
            StatusDot(.online, label: "Online")
            StatusDot(.away, label: "Away")
            StatusDot(.busy, label: "Busy")
        })
        shot("Swap", Swap(isOn: .constant(true)).symbols(on: "xmark", off: "line.3.horizontal"))
        shot("Tag", HStack(spacing: 8) {
            Tag("Success").tagStyle(.success)
            Tag("Error").tagStyle(.error).variant(.solid)
            Tag("Info").tagStyle(.info).variant(.outline)
        })
        shot("TextLink", TextLink("Forgot password?") {})
        shot("Title", Title("Section title").subtitle("Supporting subtitle").action("See all") {}.frame(width: 320))
        shot("InlineText", InlineText("By continuing you accept the Terms and the Privacy Policy.",
                                      links: [("Terms", {}), ("Privacy Policy", {})]).frame(width: 320))
        shot("BorderBeam", RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.shared.background(.bgWhite))
            .frame(width: 200, height: 80)
            .overlay(Text("Featured").textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary)))
            .borderBeam(cornerRadius: 16, lineWidth: 2))
        shot("Join", Join {
            ForEach(["Day", "Week", "Month"], id: \.self) { l in
                Text(l).textStyle(.labelBase600).padding(.horizontal, 14).frame(height: 40)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
            }
        })
        shot("Mask", HStack(spacing: 14) {
            ForEach(MaskShape.allCases, id: \.self) { s in
                Rectangle().fill(Theme.shared.foreground(.fgHero).gradient).frame(width: 52, height: 52).themeMask(s)
            }
        })
        shot("TextRotate", HStack(spacing: 4) {
            Text("Build").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            TextRotate(["themed.", "accessible."])
        })
        shot("Gauge", HStack(spacing: 24) {
            GaugeView(value: 0.72, label: "CPU")
            GaugeView(value: 0.4, label: "Disk").gaugeStyle(.linear).frame(width: 140)
        }, hosted: true)
        shot("ShareButton", ShareButton(item: "https://github.com/isamercan/ThemeKit"), hosted: true)
        shot("Aura", HStack(spacing: 40) {
            Aura().accent(.turquoise).size(90)
            Text("Featured Deal")
                .textStyle(.labelMd600)
                .foregroundStyle(Theme.shared.text(.textPrimary))
                .padding(24)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 16))
                .aura(.purple, radius: 28, intensity: 0.7)
        }.padding(32))
        shot("CodeBlock", CodeBlock([
            CodeLine("swift build", prefix: "$"),
            CodeLine("Compiling ThemeKit...", prefix: ">"),
            CodeLine("Warning: 1 deprecated API", prefix: ">", highlight: .warning),
            CodeLine("Build complete!", prefix: ">", highlight: .success),
        ]).copyable().frame(width: 320))
        shot("Confetti", ZStack {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
                Text("Booking confirmed!")
                    .textStyle(.headingSm)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
            }
            Confetti().pieceCount(60)   // animated: freezes at first frame offscreen
        }.frame(width: 300, height: 200))
        shot("FareFeatureRow", VStack(alignment: .leading, spacing: 8) {
            FareFeatureRow("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm")
            FareFeatureRow("Checked bag", systemImage: "suitcase.fill", detail: "1 × 20 kg", status: .included)
            FareFeatureRow("Non-refundable", systemImage: "nosign", status: .excluded)
            FareFeatureRow("Priority boarding", systemImage: "figure.walk").icon("hare.fill").accent(.purple)
        }.frame(width: 280))
        shot("FlightStatusBadge", HStack(spacing: 8) {
            FlightStatusBadge(.onTime).time("13:15")
            FlightStatusBadge(.boarding)
            FlightStatusBadge(.delayed).time("+35m").solid()
        })
        shot("IconTile", HStack(spacing: 12) {
            IconTile("airplane")
            IconTile("suitcase.fill").accent(.turquoise)
            IconTile("bell.fill").accent(.warning).size(40)
        })
        shot("SearchBadge", HStack(spacing: 8) {
            SearchBadge("SAW")
            SearchBadge("23 Jul '26")
            SearchBadge("4 Guests")
            SearchBadge("Direct").colors(background: .badgeBgPurple, foreground: .textPurple).icon("bolt.fill")
        })
        shot("SwapButton", HStack(spacing: 16) {
            Text("IST").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            SwapButton {}
            Text("AYT").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
        })
        shot("TiltCard", TiltCard {   // animated: renders at rest pose offscreen
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium Cabin").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                Text("Lie-flat seats on long-haul routes").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
            }
            .padding(24)
            .frame(width: 260)
            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
        }.maxAngle(.degrees(12)).shine())
        shot("Watermark", Text("Boarding pass")
            .textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            .padding(28).frame(width: 260)
            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 16))
            .watermark("SPECIMEN", fontSize: 13))
    }

    // MARK: Molecules

    private func molecules() {
        shot("Button", HStack(spacing: 10) {
            PrimaryButton("Continue") {}.fullWidth()
            SecondaryButton("Cancel") {}
            OutlineButton("More") {}
        })
        shot("ThemeButton", HStack(spacing: 10) {
            ThemeButton("Solid") {}.color(.primary)
            ThemeButton("Soft") {}.color(.success).variant(.soft)
            ThemeButton("Pill") {}.color(.error).variant(.outline).shape(.pill)
        })
        shot("Checkbox", VStack(alignment: .leading, spacing: 10) {
            Checkbox("Accept the terms", isChecked: .constant(true))
            Checkbox("Subscribe to updates", isChecked: .constant(false))
        })
        shot("CheckboxGroup", CheckboxGroup(title: "Amenities", options: ["Wifi", "Pool", "Parking"],
                                            selection: .constant(["Wifi", "Pool"])) { $0 }.selectAll("Select all").frame(width: 280))
        shot("RadioButton", RadioButton("Remember me", isSelected: .constant(true)))
        shot("RadioGroup", RadioGroup(title: "Class", options: ["Economy", "Business", "First"],
                                      selection: .constant("Business")) { $0 }.frame(width: 240))
        shot("ToggleGroup", ThemeToggle(isOn: .constant(true)))
        shot("ThemeToggle", HStack(spacing: 16) {
            ThemeToggle(isOn: .constant(true))
            ThemeToggle(isOn: .constant(false))
        })
        shot("SegmentedControl", SegmentedControl(["Daily", "Weekly", "Monthly"], selection: .constant(1)).frame(width: 300))
        shot("QuantityStepper", QuantityStepper(value: .constant(2), range: 0...10))
        shot("Stat", Stat(title: "Total bookings", value: "1,284")
                          .suffix("$").description("this month").icon("ticket").trend(.up("+12%")).frame(width: 280))
        shot("Steps", Steps([.init("Cart", description: "2 items", systemImage: "cart", state: .done),
                             .init("Payment", description: "Card", state: .active),
                             .init("Done", state: .todo)]).frame(width: 360))
        shot("Slider", ThemeKit.Slider(value: .constant(4), in: 0...8, label: "Guests")
                                       .marks([0: "0", 4: "4", 8: "8"]).frame(width: 300))
        shot("Breadcrumbs", Breadcrumbs([.init("Home", action: {}), .init("Hotels", action: {}), .init("Istanbul")]).frame(width: 320))
        shot("TextInput", TextInput("Email", text: .constant("user@example.com")).frame(width: 300), hosted: true)
        shot("FileInput", FileInput("Passport", onPick: {}).fileName("passport-scan.jpg").onClear({}).frame(width: 320))
        shot("Pagination", Pagination(current: .constant(4), total: 50).frame(width: 360))
        shot("Fieldset", Fieldset("Contact details") {
            TextInput("Email", text: .constant("user@example.com"))
        }.helper("We never share your info.").frame(width: 320), hosted: true)
        shot("DateField", DateField("Check-in", date: .constant(nil)).frame(width: 280))
        shot("Select", Select("City", options: ["Istanbul", "Ankara", "Izmir"],
                              selection: .constant(Optional("Istanbul"))) { $0 }.searchable().frame(width: 280), hosted: true)
        // SelectBox is a native SwiftUI Menu — its label doesn't draw into an
        // offscreen snapshot, so it's shown live in the Demo app instead.
        shot("MultiSelect", MultiSelect("Cities", options: ["Istanbul", "Ankara", "Izmir"],
                                        selection: .constant(Set(["Istanbul", "Ankara"]))) { $0 }.frame(width: 300))
        shot("TreeSelect", TreeSelect("Cities",
                                      nodes: [TreeNode(id: "tr", "Turkey", systemImage: "flag",
                                                       children: [TreeNode(id: "ist", "Istanbul"), TreeNode(id: "ank", "Ankara")])],
                                      selection: .constant(Set(["ist"])), initiallyExpanded: ["tr"]).frame(width: 300))
        shot("Autocomplete", Autocomplete("Destination", text: .constant("Istanbul"),
                                          suggestions: ["Istanbul", "Izmir"]).frame(width: 300), hosted: true)
        shot("SearchBar", SearchBar(text: .constant("Istanbul")).frame(width: 320), hosted: true)
        shot("OTPInput", OTPInput(code: .constant("1234")).digitCount(6).frame(width: 300))
        shot("InputNumber", InputNumber("Max price", value: .constant(250), range: 0...1000).step(50).unit("$").frame(width: 280), hosted: true)
        shot("RangeSlider", RangeSlider(lowerValue: .constant(200), upperValue: .constant(800),
                                        in: 0...1000).step(50).marks([0, 500, 1000]).frame(width: 320))
        shot("MultiLineTextInput", MultiLineTextInput("Notes", text: .constant("It was a wonderful stay, I would definitely recommend it.")).frame(width: 300), hosted: true)
        shot("Tooltip", Icon(systemName: "info.circle").size(.lg).color(Theme.shared.foreground(.fgHero))
            .tooltip("Helpful tip", isPresented: .constant(true), edge: .top)
            .padding(.top, 36))
        shot("Chips", CompactChip("Suit", price: "$899", isSelected: .constant(true)).rating(4.6))
        shot("FilterGroup", FilterGroup(options: ["All", "Hotel", "Villa", "Apartment"],
                                        selection: .constant(Optional("Hotel"))) { $0 }.frame(width: 320))
        shot("ProgressIndicator", ProgressIndicator(variant: .carousel, current: 2, total: 8).frame(width: 240))
        shot("ThemeController", ThemeController(options: [.init(name: "defaultTheme", label: "Default"),
                                                          .init(name: "oceanTheme", label: "Ocean"),
                                                          .init(name: "sunsetTheme", label: "Sunset")],
                                                selectedName: .constant("oceanTheme")).frame(width: 320))
        shot("Calendar", CalendarView(selection: .constant(nil)).frame(width: 320))
        shot("ColorField", ColorField("Brand color", selection: .constant(Theme.shared.foreground(.fgHero))).frame(width: 280), hosted: true)
        shot("DatePriceCard", DatePriceCard(DatePriceItem("18 Jul", price: 129.99), isSelected: true, action: {}).currency("USD").frame(width: 120))
        shot("DatePriceStrip", DatePriceStrip([DatePriceItem("17 Jul", price: 149.99),
                                               DatePriceItem("18 Jul", price: 119.99),
                                               DatePriceItem("19 Jul", price: 174.50),
                                               DatePriceItem("20 Jul", price: 132.00),
                                               DatePriceItem("21 Jul", price: 128.75),
                                               DatePriceItem("22 Jul", price: 156.25)],
                                              selection: .constant(1)).columns(3).currency("USD").highlightCheapest().frame(width: 360))
        shot("Dropdown", Dropdown(items: [DropdownItem("Rename", systemImage: "pencil"),
                                          DropdownItem("Duplicate", systemImage: "plus.square.on.square"),
                                          .divider,
                                          DropdownItem("Delete", systemImage: "trash", role: .destructive)]) {
            Label("Actions", systemImage: "chevron.down")
        })
        shot("FieldButton", FieldButton("Istanbul (IST)", action: {}).label("From").icon("airplane.departure").frame(width: 300))
        shot("FilterRow", FilterRow("Direct flights only", isOn: .constant(true)).count(42).icon("airplane").frame(width: 320))
        shot("FlightRoute", FlightRoute(from: "IST", to: "JFK",
                                        departure: Date(timeIntervalSince1970: 1_760_000_000),
                                        arrival: Date(timeIntervalSince1970: 1_760_000_000 + 37_800)).stops(1).frame(width: 340))
        shot("InstallmentPicker", InstallmentPicker([InstallmentOption(count: 1, total: 900),
                                                     InstallmentOption(count: 3, total: 930, monthly: 310),
                                                     InstallmentOption(count: 6, total: 960, monthly: 160)],
                                                    selection: .constant(1)).currency("USD").frame(width: 340))
        shot("LayoverRow", LayoverRow(duration: "2h 15m", airport: "Vienna (VIE)").warning("Short connection").frame(width: 340))
        shot("MapPriceMarker", MapPriceMarker("$129").selected())
        shot("PassengerRow", PassengerRow("Emma Johnson", action: {}).type("Adult").subtitle("Passport U1234567").seat("14A").status("Checked in").accessory(.chevron).frame(width: 360))
        shot("PaymentCardField", PaymentCardField(number: .constant("4111 1111 1111 1111"),
                                                  expiry: .constant("12/28"),
                                                  cvv: .constant("123")).holder(.constant("EMMA JOHNSON")).frame(width: 340), hosted: true)
        shot("PriceBreakdown", PriceBreakdown(249.99, currencyCode: "USD").original(299.99).discountBadge("-17%").unit("per night").note("Includes taxes and fees").frame(width: 280))
        shot("PriceTrendChart", PriceTrendChart([PriceTrendPoint("14", sublabel: "Mon", price: 129),
                                                 PriceTrendPoint("15", sublabel: "Tue", price: 99),
                                                 PriceTrendPoint("16", sublabel: "Wed", price: 142),
                                                 PriceTrendPoint("17", sublabel: "Thu", price: 118),
                                                 PriceTrendPoint("18", sublabel: "Fri", price: 175),
                                                 PriceTrendPoint("19", sublabel: "Sat", price: 160)],
                                                selection: .constant(1)).title("July").currency("USD").frame(width: 360))
        shot("RecentSearchRow", RecentSearchRow(from: "Istanbul", to: "Rome", action: {}).roundTrip().dates("18 Jul - 25 Jul").passengers("2 adults").onRemove({}).frame(width: 340))
        shot("ScrubGallery", ScrubGallery(count: 3) { i in
            ZStack {
                Rectangle().fill([SemanticColor.primary, .purple, .turquoise][i].soft)
                Text("Photo \(i + 1)").font(.headline)
            }
        }.indicator().frame(width: 320, height: 180))
        shot("SearchField", SearchField("Where from?", action: {}).value(code: "IST", title: "Istanbul", subtitle: "All airports").icon("airplane.departure").frame(width: 340))
        shot("SmartSuggestion", SmartSuggestion("Fly on Tuesday and save $42").label("Tip").icon("sparkles").action("Apply", perform: {}).frame(width: 340))
        shot("SortSummaryBar", SortSummaryBar([SortOption("Best", value: "$277", subtitle: "1h 07m", icon: "star.fill"),
                                               SortOption("Cheapest", value: "$219", subtitle: "2h 30m"),
                                               SortOption("Fastest", value: "$342", subtitle: "55m")],
                                              selection: .constant(0)).onMore(action: {}).frame(width: 360))
        shot("SortTab", SortTab(SortOption("Cheapest", value: "$219", subtitle: "2h 30m", icon: "arrow.down"), isSelected: true, action: {}))
        shot("StepperRow", StepperRow("Adults", value: .constant(2)).subtitle("12 years and older").range(1...9).icon("person.fill").frame(width: 320))
        shot("SuggestionRow", SuggestionRow("Rome", action: {}).code("FCO").subtitle("Leonardo da Vinci Airport, Italy").icon("airplane").accessory(.chevron).frame(width: 340))
        shot("TripTypeToggle", TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: .constant(1))
            .icons(["arrow.right", "arrow.left.arrow.right", "point.topleft.down.curvedto.point.bottomright.up"])
            .frame(width: 340))
        shot("Space", Space { Tag("Istanbul"); Tag("Rome"); Tag("Paris") }.size(.medium))
        shot("Flex", Flex { Tag("Back"); Tag("Save"); Tag("Next") }.justify(.spaceBetween).frame(width: 320))
        shot("Anchor", AnchorNav([AnchorItem("a", title: "Introduction"), AnchorItem("b", title: "Installation"),
                                  AnchorItem("c", title: "Usage", level: 1), AnchorItem("d", title: "API")],
                                 active: .constant("a")).frame(width: 200))
        shot("Splitter", Splitter(.horizontal, initialFraction: 0.42) {
            Text("Sidebar").textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textPrimary))
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.shared.background(.bgElevatorPrimary))
        } second: {
            Text("Detail").textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textPrimary))
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.shared.background(.bgWhite))
        }
        .frame(width: 320, height: 130).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1)))
        shot("Cascader", Cascader([
            CascaderOption("us", label: "United States", children: [
                CascaderOption("ca", label: "California", children: [CascaderOption("berkeley", label: "Berkeley")])])],
            selection: .constant(["tr", "34", "kadikoy"])).frame(width: 320))
        shot("Transfer", Transfer([TransferItem("wifi", title: "Wi-Fi"), TransferItem("pool", title: "Pool"),
                                   TransferItem("gym", title: "Gym"), TransferItem("spa", title: "Spa")],
                                  target: .constant(["wifi"])).titles("Available", "Included").frame(width: 360),
             hosted: true)   // internal ScrollView → needs the real AppKit render pass
        shot("Mentions", Mentions(text: .constant("Great work @ada — thanks!"),
                                  options: [MentionOption("ada", label: "Ada Lovelace")]).frame(width: 320), hosted: true)
        shot("Masonry", Masonry {
            ForEach(Array([70.0, 110, 90, 60, 100, 80].enumerated()), id: \.offset) { _, h in
                RoundedRectangle(cornerRadius: 10).fill(SemanticColor.primary.soft).frame(height: h)
            }
        }.columns(3).frame(width: 300))
        shot("Tree", TreeView([
            TreeNode(id: "docs", "Documents", systemImage: "folder", children: [
                TreeNode(id: "cv", "Resume.pdf", systemImage: "doc"),
                TreeNode(id: "img", "Images", systemImage: "folder")]),
            TreeNode(id: "music", "Music", systemImage: "folder", children: [
                TreeNode(id: "s", "song.mp3", systemImage: "music.note")])],
            selection: .constant(["cv"])).checkable().frame(width: 300))
        shot("Grid", ColumnsGrid {
            ForEach(0..<6) { i in
                RoundedRectangle(cornerRadius: 10).fill(SemanticColor.info.soft).frame(height: 48)
                    .overlay(Text("\(i)").textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textPrimary)))
            }
        }.columns(3).gutter(.small).frame(width: 300))
        shot("Affix", HStack {
            Icon(systemName: "pin.fill").size(.sm).accent(.primary)
            Text("Pinned toolbar").textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textPrimary))
            Spacer()
            Badge("Affixed").badgeStyle(.info)
        }
        .padding(12).frame(width: 300)
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 12))
        .themeShadow(.soft).padding(6))
        shot("SearchSummary", SearchSummary(time: "2h 30m", adults: 2).frame(width: 340))
    }

    // MARK: Organisms

    private func organisms() {
        shot("Accordion", Accordion("What is your return policy?", initiallyExpanded: true) {
            Text("You can request a refund within 14 days of purchase.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.frame(width: 340))
        shot("AlertToast", AlertToast("Saved successfully").message("Your changes were stored.").variant(.success).frame(width: 340))
        shot("Callout", VStack(alignment: .leading, spacing: 10) {
            Callout("Saved successfully.").variant(.success)
            Callout("Please review your details.").variant(.warning).calloutStyle(.soft)
            Callout("Something went wrong.").variant(.error).calloutStyle(.soft)
        }.frame(width: 320))
        shot("Card", Card("Reservation") {
            Text("Hilton London — Deluxe room, breakfast included.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.subtitle("2 nights · 2 guests").extraAction("Details", action: {}).frame(width: 320))
        shot("ChatBubble", VStack(alignment: .leading, spacing: 8) {
            ChatBubble("Hi! Your reservation is confirmed.", author: "Support", time: "09:24").side(.incoming)
            ChatBubble("Thanks!", time: "09:25").side(.outgoing)
        }.frame(width: 320))
        shot("Counter", Counter(days: 2, hours: 8, minutes: 45))
        shot("Coupon", Coupon(code: "UXMUQ").couponStyle(.outlined).frame(width: 300))
        shot("EmptyState", EmptyState("No results found")
                                      .icon("magnifyingglass")
                                      .message("Try adjusting your search or filters.")
                                      .primaryAction("Clear filters") {}
                                      .secondaryAction("Learn more") {}.frame(width: 320))
        shot("InfoBanner", InfoBanner("Your reservation is confirmed. Go to the ticket page for details.",
                                      title: "Heads up").variant(.info).frame(width: 340))
        shot("KeyValueTable", KeyValueTable(rows: [.init("Status", value: "Active", style: .success),
                                                   .init("Old price", value: "$5,000", style: .strikethrough),
                                                   .init("Total", value: "$4,250")])
                                            .title("Reservation summary").bordered().frame(width: 320))
        shot("ListRow", VStack(spacing: 0) {
            ListRow("My account", action: {}).subtitle("Profile and security").icon("person.circle")
            DividerView().size(.small)
            ListRow("Notifications", action: {}).subtitle("Email and push").icon("bell")
        }.frame(width: 320))
        shot("NotificationCard", NotificationCard(title: "We Have a Suggestion for Your Trip")
                                                  .message("24 days until your Hilton London reservation.")
                                                  .date("December 5, 2024").unread().variant(.success).frame(width: 340))
        shot("PageHeader", PageHeader("Search results").subtitle("128 hotels")
                                      .tags([.init("Active", style: .success)]).onBack({}).frame(width: 340))
        shot("RatingSummary", RatingSummary(score: 9.0).label("Excellent").reviews(count: 1200).frame(width: 300))
        shot("ResultView", ResultView(.notFound, title: "Page not found")
                                      .message("The page you're looking for may have moved.")
                                      .primaryAction("Home", action: {}).frame(width: 320))
        shot("SegmentedTabBar", SegmentedTabBar([TabItem("Overview"), TabItem("Reviews", badge: "12"),
                                                 TabItem("Location")], selection: .constant(1)).frame(width: 340))
        shot("Timeline", Timeline([.init(title: "Order received", time: "09:24", systemImage: "cart", state: .done, color: .success),
                                   .init(title: "Preparing", time: "09:40", systemImage: "shippingbox", state: .active),
                                   .init(title: "On the way", state: .todo)]).pending("Waiting for courier…").frame(width: 320))
        shot("Upload", Upload(prompt: "You can upload up to 3 photos.",
                              files: [.init(name: "room-1.jpg", status: .done),
                                      .init(name: "room-2.jpg", status: .uploading(0.6))],
                              onPick: {}, onRemove: { _ in })
                            .buttonTitle("Add photo").maxCount(3).frame(width: 320))
        shot("PromoBanner", PromoBanner("Early booking", action: {})
                                        .subtitle("Save up to 30% on summer").icon("sun.max.fill").ctaTitle("Explore").frame(width: 340))
        let rowTitles = ["My account", "Notifications", "Language", "Payment"]
        shot("ListView", ListView(tiles) { tile in
            ListRow(rowTitles[tile.id], action: {}).subtitle("Details").icon("gearshape")
        }.header("Settings").footer("\(tiles.count) items").bordered().frame(width: 320))
        shot("MenuCard", MenuCard(items: [
            .init(title: "Reservations", subtitle: "Upcoming & past", systemImage: "calendar"),
            .init(title: "Payment methods", subtitle: "Cards & wallets", systemImage: "creditcard"),
            .init(title: "Settings", subtitle: "App preferences", systemImage: "gearshape"),
        ]).frame(width: 320))
        shot("NavigationBar", NavigationBar(items: [
            .init(systemImage: "house"), .init(systemImage: "heart"), .init(systemImage: "bag"), .init(systemImage: "person"),
        ], selection: .constant(0)).frame(width: 320))
        shot("FAB", FloatingActionButton(systemImage: "plus") {})
        shot("Hero", Hero(title: "Early booking") { Theme.shared.background(.bgHero) }
                          .subtitle("Up to 30% off your summer holiday")
                          .cta("Explore", action: {}).frame(width: 340, height: 180))
        shot("SelectionCards", VStack(spacing: 10) {
            RadioCard("Standard", isSelected: true) {}.description("Free cancellation")
            RadioCard("Flexible", isSelected: false) {}.description("Change anytime")
        }.frame(width: 320))
        shot("CardStack", CardStack(tiles) { self.tileView($0) }.frame(width: 300))
        // Carousel / PagingCarousel use a paged TabView, which ImageRenderer can't
        // capture on macOS — see them live in the Demo app.
        shot("Gallery", Gallery(tiles) { self.tileView($0) }.columns(2).frame(width: 320))
        shot("Footer", Footer(columns: [
            .init("Company", items: [.init("About"), .init("Careers")]),
            .init("Support", items: [.init("Help"), .init("Contact")]),
        ], note: "© 2026 ThemeKit.").frame(width: 340))
        shot("Diff", Diff {
            Theme.shared.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
        } after: {
            Theme.shared.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
        }.frame(width: 320, height: 140))
        organismsTravel()
    }

    /// The travel-wave organisms — split out to keep `organisms()` under the
    /// linter's function-body ceiling.
    private func organismsTravel() {
        shot("AgentPriceRow", AgentPriceRow("Skytrip") {}
            .rating(4.5).badge("Cheapest").subtitle("Free cancellation within 24h")
            .original(452).price(429, currencyCode: "USD").cta("Go to site").recommended()
            .frame(width: 340))
        shot("AncillaryCard", AncillaryCard("Checked baggage")
            .icon("suitcase.fill").subtitle("23 kg").badge("Popular")
            .price(60, currencyCode: "USD", suffix: "/ bag")
            .quantity(.constant(1), range: 0...4)
            .frame(width: 340))
        shot("BoardingPass", BoardingPass(passenger: "Emily Carter", from: "IST", to: "JFK")
            .airline("Skyline Air").flightNo("SK 1123").cabin("Economy")
            .cities(from: "Istanbul", to: "New York").times(departure: "09:40", arrival: "13:25").date("12 Sep")
            .gate("B22", seat: "14C", boarding: "09:05", terminal: "1")
            .bookingRef("PNR: A7K2QF").barcode("SK1123ISTJFK14C")
            .frame(width: 340))
        shot("BrowserFrame", BrowserFrame(url: "https://skylineair.com/deals") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Summer fares to London").textStyle(.headingSm)
                Text("Fly IST to LHR from $189 round trip.")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
            }
            .padding()
        }
        .elevation(.soft)
        .frame(width: 320))
        shot("DestinationCard", DestinationCard("Santorini Sunset Escape")
            .media {
                LinearGradient(colors: [Theme.shared.background(.bgHero), Theme.shared.background(.bgTurquoise)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            }
            .subtitle("Greece").ribbon("Top #1")
            .price(899, currencyCode: "EUR").rating(4.8).favorite(.constant(true))
            .tags(["Beach", "Culture"])
            .frame(width: 320))
        shot("FareFamilyCard", FareFamilyCard("Comfort Flex", price: 249.99)
            .currency("USD").accent(.purple)
            .features([FareFeature("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm"),
                       FareFeature("Checked bag", systemImage: "suitcase.fill", detail: "1 × 23 kg", status: .included),
                       FareFeature("Free rebooking", systemImage: "arrow.uturn.backward", status: .included),
                       FareFeature("Non-refundable", systemImage: "nosign", status: .excluded)])
            .onSelect {}
            .frame(width: 320))
        shot("FilterBar", FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront"), QuickFilter("Pool"),
                                     QuickFilter("Free cancellation"), QuickFilter("Breakfast")],
                                    selection: .constant(["8+ rating"]))
            .onFilter {}.onSort {}
            .frame(width: 380))
        shot("FilterList", FilterList([FilterOption("Direct", count: 128),
                                       FilterOption("1 stop", count: 64),
                                       FilterOption("2+ stops", count: 12)],
                                      selection: .constant(["Direct"]))
            .title("Stops").bordered().selectAll("All")
            .frame(width: 320))
        shot("FlightResultRow", FlightResultRow(airline: "Skyline Air", from: "IST", to: "LHR",
                                                departure: Date(timeIntervalSince1970: 1_781_000_000),
                                                arrival: Date(timeIntervalSince1970: 1_781_014_700))
            .flightNo("SK 1123").cabin("Economy")
            .price(429.99, currencyCode: "USD").baggage("23 kg").badge("Best")
            .onSelect("Select") {}.onDetails {}
            .frame(width: 380))
        shot("FlightTicketCard", FlightTicketCard(from: "IST", to: "LHR")
            .cities(from: "Istanbul", to: "London").duration("4h 05m")
            .times(departure: "09:40", arrival: "12:45")
            .airline("Skyline Air").price(219, currencyCode: "USD")
            .favorite(.constant(true)).accent(.info)
            .frame(width: 320))
        shot("HotelResultCard", HotelResultCard(name: "Harbor View Resort")
            .media {
                LinearGradient(colors: [Theme.shared.background(.bgHero), Theme.shared.background(.bgTurquoise)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .location("Santorini, Greece")
            .score(9.2, label: "Exceptional", reviews: 1_284)
            .features(["All-inclusive", "Seafront"])
            .promos(["Members save 10%", "Free airport shuttle"])
            .stay("2 guests | 4 nights")
            .original(1_450).discountBadge("-18%").price(1_189, currencyCode: "EUR")
            .badge("Deal").favorite(.constant(true)).onSelect {}
            .frame(width: 360))
        shot("MapCallout", MapCallout(title: "Harbor View Resort")
            .subtitle("Santorini, Greece").score(9.2)
            .price(189, currencyCode: "EUR").onSelect {}
            .frame(width: 280))
        shot("PhoneFrame", PhoneFrame {
            VStack(spacing: 8) {
                Spacer()
                Text("Skyline Air").textStyle(.headingSm)
                Text("Your gate is now B22")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                Spacer()
            }
        }
        .notch(.island)
        .frame(width: 260))
        shot("PriceAlertCard", PriceAlertCard("Get price alerts", isOn: .constant(true))
            .subtitle("We'll notify you when IST-JFK fares change")
            .price(429, currencyCode: "USD").trend(.down, "-8%")
            .frame(width: 360))
        shot("RoomCard", RoomCard(name: "Deluxe Room, Sea View")
            .board("All-inclusive").occupancy("2 adults, 1 child")
            .features([FareFeature("Free cancellation", systemImage: "checkmark.circle", status: .included),
                       FareFeature("Breakfast included", systemImage: "cup.and.saucer", status: .included)])
            .original(240).discountBadge("-20%").price(192, currencyCode: "EUR").unit("/ night")
            .badge("Last 2").onSelect {}
            .frame(width: 360))
        shot("SheetHeader", SheetHeader("Passengers")
            .subtitle("Step 2 of 4").onBack {}.onClose {}.progress(0.5)
            .frame(width: 360))
        shot("StickyBookingBar", StickyBookingBar("Book now") {}
            .note("2 travellers | Round trip")
            .original(1_480).discountBadge("-16%").price(1_240, currencyCode: "USD")
            .ctaIcon("arrow.right")
            .frame(width: 380))
        shot("TicketStub", TicketStub {
            VStack(alignment: .leading, spacing: 8) {
                Text("SKYLINE AIR").textStyle(.labelMd700)
                HStack {
                    VStack(alignment: .leading) {
                        Text("09:40").textStyle(.headingSm)
                        Text("IST").textStyle(.labelSm600)
                    }
                    Spacer()
                    Image(systemName: "airplane").foregroundStyle(Theme.shared.foreground(.fgHero))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("12:45").textStyle(.headingSm)
                        Text("LHR").textStyle(.labelSm600)
                    }
                }
            }
        }
        .stub {
            HStack {
                Text("Booking").textStyle(.bodySm400)
                Spacer()
                Text("SKY4H8Q2").textStyle(.labelSm700)
            }
        }
        .elevation(.elevated)
        .frame(width: 340))
        shot("FlightListItem", VStack(spacing: 14) {
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: Date(timeIntervalSince1970: 1_781_000_000),
                           arrival: Date(timeIntervalSince1970: 1_781_014_700))
                .flightNo("SK 1123").price(214, currencyCode: "USD", caption: "from").badge("Best")
                .onSelect { }
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: Date(timeIntervalSince1970: 1_781_000_000),
                           arrival: Date(timeIntervalSince1970: 1_781_014_700))
                .price(164, currencyCode: "USD").original(214)
                .deal("23% below typical", tone: .success)
                .trend([0.82, 0.78, 0.9, 0.66, 0.52, 0.44])
                .flightListItemStyle(.deal)
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: Date(timeIntervalSince1970: 1_781_000_000),
                           arrival: Date(timeIntervalSince1970: 1_781_014_700))
                .cabin("Economy").baggage("8kg")
                .price(214, currencyCode: "USD", caption: "Per person").original(276)
                .onDetails { }.onSelect { }
                .flightListItemStyle(.tray)
        }.frame(width: 360))
        shot("WindowFrame", WindowFrame("Trip Planner") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Istanbul to London").textStyle(.headingSm)
                Text("3 flights saved for September.")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
            }
            .padding()
        }
        .accent(.info)
        .frame(width: 320))
    }

    // MARK: Render

    /// `hosted: true` renders the view inside a real offscreen NSWindow rather than
    /// through ImageRenderer. ImageRenderer can't draw `TextField`/`TextEditor`
    /// (they need a window + responder) and falls back to a yellow placeholder, so
    /// text-input components are captured by caching a live AppKit hierarchy.
    /// The README header banner — a bento grid of the kit's selling points, rendered
    /// BY ThemeKit's own tokens + components (so it re-skins light/dark for free).
    @MainActor
    private func featureBanner() -> some View {
        let t = Theme.shared
        func card<C: View>(_ fill: Color? = nil, stroke: Color? = nil, @ViewBuilder _ content: () -> C) -> some View {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .background(fill ?? t.background(.bgWhite), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(stroke ?? .clear, lineWidth: 1.5))
        }
        func heading(_ s: String, _ color: Color) -> some View {
            Text(s).font(.system(size: 28, weight: .heavy)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
        }
        func tiny(_ s: String) -> some View { Text(s).textStyle(.labelSm600).foregroundStyle(t.text(.textTertiary)) }
        func sub(_ s: String) -> some View { Text(s).textStyle(.bodyBase400).foregroundStyle(t.text(.textSecondary)) }

        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                card { VStack(alignment: .leading, spacing: 6) {
                    Text("204").font(.system(size: 46, weight: .black)).foregroundStyle(t.text(.textPrimary))
                    tiny("COMPONENTS"); sub("50 atoms · 81 molecules · 73 organisms")
                }}.frame(width: 330)
                card { VStack(alignment: .leading, spacing: 6) { heading("Zero deps", t.text(.textPrimary)); sub("native SwiftUI core") }}
                card(t.background(.systemcolorsBgSuccessLight)) { VStack(alignment: .leading, spacing: 6) {
                    heading("Fully\nTokenized", t.foreground(.systemcolorsFgSuccess)); sub("JSON token pipeline")
                }}.frame(width: 300)
                card { VStack(alignment: .leading, spacing: 6) { heading("Swift 6", t.text(.textPrimary)); sub("@Observable · strict") }}
            }
            .frame(height: 148)

            HStack(spacing: 16) {
                card { VStack(alignment: .leading, spacing: 12) {
                    heading("Per-subtree\nTheming", t.foreground(.fgHero))
                    HStack(spacing: 0) {
                        ForEach(Array([SemanticColor.info, .purple, .pink, .turquoise, .success].enumerated()), id: \.offset) { _, c in
                            Rectangle().fill(c.solid).frame(height: 16)
                        }
                    }.clipShape(Capsule())
                    tiny(".theme(_:) environment")
                }}.frame(width: 330)

                VStack(spacing: 10) {
                    Text("ThemeKit").font(.system(size: 50, weight: .black)).foregroundStyle(t.text(.textPrimary))
                    sub("Native SwiftUI design system")
                    Badge("v1.0.0 · iOS 17+").badgeStyle(.info).icon("swift")
                    HStack(spacing: 12) {
                        RadialProgress(0.72).size(52).showsLabel(false)
                        ProgressBar(value: 0.62).frame(width: 130)
                    }.padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
                .background(t.background(.bgWhite), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(t.border(.borderHero), lineWidth: 1.5))

                card { VStack(alignment: .leading, spacing: 10) {
                    heading("Variable\nThemes", SemanticColor.pink.solid)
                    VStack(spacing: 0) {
                        ForEach(Array(["Default", "Ocean", "Sunset", "Grape"].enumerated()), id: \.offset) { _, name in
                            let on = name == "Ocean"
                            HStack {
                                Text(name).textStyle(.bodyBase400).foregroundStyle(on ? t.foreground(.fgSecondary) : t.text(.textPrimary))
                                Spacer()
                                if on { Icon(systemName: "checkmark").size(.sm).color(t.foreground(.fgSecondary)) }
                            }
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(on ? t.foreground(.fgHero) : Color.clear)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(t.border(.borderPrimary)))
                }}.frame(width: 330)
            }
            .frame(height: 250)

            HStack(spacing: 16) {
                card { VStack(alignment: .leading, spacing: 6) { heading("Liquid\nGlass", SemanticColor.purple.solid); tiny("iOS 26 · MATERIAL FALLBACK") }}
                card { VStack(alignment: .leading, spacing: 6) { heading("Light +\nDark", t.text(.textPrimary)); tiny("EVERY COMPONENT") }}
                card { VStack(alignment: .leading, spacing: 6) { heading("Accessible", t.foreground(.systemcolorsFgInfo)); tiny("VOICEOVER · RTL · REDUCE MOTION") }}
                card { VStack(alignment: .leading, spacing: 8) {
                    tiny("BUILT-IN")
                    HStack(spacing: 6) { Tag("DocC"); Tag("Snapshots") }
                    HStack(spacing: 6) { Tag("CI"); Tag("EN+TR") }
                }}.frame(width: 300)
            }
            .frame(height: 148)
        }
        .frame(width: 1180)
        .padding(28)
        .background(t.background(.bgSecondaryLight))
    }

    /// Proof that `.theme(_:)` re-skins a subtree: the SAME components rendered four
    /// times, each subtree given a different `Theme` instance via `.theme(_:)`. If the
    /// rollout works, each column shows that theme's brand/semantic colors — no
    /// `Theme.shared` mutation, no global state, just the injected environment.
    @MainActor
    private func themeInjectionProof() -> some View {
        func named(_ name: String) -> Theme { let t = Theme(); t.loadTheme(named: name); return t }
        let ocean = named("oceanTheme")
        let sunset = named("sunsetTheme")
        let grape = Theme(); grape.applyGenerated(primaryHex: "#7C3AED")   // generated on-device

        @ViewBuilder func sample() -> some View {
            Hero(title: "Stay").subtitle("Find your spot").cta("Book", action: {})
                .frame(height: 128)
            HStack(spacing: 6) {
                Badge("Info").badgeStyle(.info).icon("bell.fill")
                Tag("Filter", onRemove: {})
            }
            InfoBanner("Subtree-themed").variant(.success)
            Stat(title: "Bookings", value: "1,284").icon("ticket").trend(.up("+12%"))
            PrimaryButton("Continue") {}.fullWidth()
        }

        func column(_ title: String, _ theme: Theme) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                sample()
            }
            .frame(width: 250, alignment: .leading)
            .padding(14)
            .background(theme.background(.bgWhite))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)))
            .theme(theme)   // <-- the whole point: inject a theme into just this subtree
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Same components · four injected themes · one screen").font(.title3.bold())
            HStack(alignment: .top, spacing: 14) {
                column("Default", Theme.shared)
                column("Ocean", ocean)
                column("Sunset", sunset)
                column("Grape (generated)", grape)
            }
        }
    }

    private func shot(_ name: String, _ view: some View, hosted: Bool = false, inGallery: Bool = true) {
        // The backdrop reads the active theme's surface, so loading the dark theme
        // (in `testGenerateAll`) makes both component + backdrop dark.
        // Force English locale so date/number-bearing components (CalendarView,
        // DateField…) render English month/day names regardless of the host's
        // system language — the project ships English-only screenshots.
        let decorated = view.padding(16)
            .background(Theme.shared.background(.bgWhite))
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "en_US"))
        let cg = hosted ? hostedCGImage(decorated) : imageRendererCGImage(decorated)
        guard let cg else { XCTFail("\(name): no image"); return }
        let fileName = scheme == .dark ? "\(name)-dark" : name
        let url = outDir.appendingPathComponent("\(fileName).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            XCTFail("\(name): no PNG destination"); return
        }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        if scheme == .light && inGallery { manifest.append((category, name)) }   // manifest = one row per gallery component
    }

    private func imageRendererCGImage(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// Host the view in a borderless offscreen window and cache its rendered AppKit
    /// layer — so `TextField`-backed controls draw real text instead of a placeholder.
    private func hostedCGImage(_ view: some View) -> CGImage? {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        guard size.width > 1, size.height > 1 else { return nil }
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        // Give SwiftUI/AppKit a couple of run-loop turns to lay out and draw the
        // text controls before we snapshot.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        // Drop first responder so text fields snapshot in their resting state (no
        // focus ring, no auto-selected text) rather than focused-and-selected.
        window.makeFirstResponder(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        return rep.cgImage
    }
}
#endif
