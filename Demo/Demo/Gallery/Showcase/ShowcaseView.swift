//
//  ShowcaseView.swift
//  Demo
//  Created by İsa Mercan.
//
//  The app's opening experience — a full-screen, tab-bar-free, non-scrolling
//  paged showcase built for screen recording. It opens on an Ant-Design-homepage
//  style collage, then swipes through curated, densely-packed pages (Overview ·
//  Travel · ThemeKitTravel · Content · Dashboard · Forms) with page dots at the
//  bottom. The ThemeKitTravel page is a distinct section for the opt-in
//  flight-booking edition (TripSearchCard, PaymentMethodSelector, FlightTracker…).
//  Each page fills
//  the screen with the richest components in the library. A theme-preset row
//  (top-right) re-skins the whole wall; "All components" opens the Rich
//  components shelf. Auto theme-cycle is OFF by default. Wide-canvas first
//  (iPad landscape / Mac Catalyst).
//

import SwiftUI
import Combine
import ThemeKit
import ThemeKitTravel

struct ShowcaseView: View {
    @EnvironmentObject private var themeStore: DemoThemeStore

    // The Showcase owns an ISOLATED theme instance: the global theme (themeStore /
    // Theme.shared) never changes the wall, and the wall's preset row never changes
    // the global. It re-skins only when the user taps the top-right row (or auto-cycle).
    @State private var localTheme: Theme = {
        let t = Theme(); t.loadTheme(named: DemoTheme.default.resourceName, dark: false); return t
    }()
    @State private var preset: DemoTheme = .default
    @State private var isDark = false

    @State private var page = UserDefaults.standard.integer(forKey: "startPage")
    @State private var autoCycle = false
    @State private var showBrowser = UserDefaults.standard.bool(forKey: "openBrowser")
    private let ticker = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            localTheme.background(.bgBase).ignoresSafeArea()

            TabView(selection: $page) {
                OverviewPage().tag(0)
                TravelPage().tag(1)
                ThemeKitTravelPage().tag(5)
                ContentPage().tag(2)
                DashboardPage().tag(3)
                FormsPage().tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            topBar
        }
        .theme(localTheme)   // isolate the whole wall on the Showcase's own theme
        .environment(\.locale, Locale(identifier: "en_US"))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: preset) { _, _ in applyTheme() }
        .onChange(of: isDark) { _, _ in applyTheme() }
        .onReceive(ticker) { _ in if autoCycle { advanceTheme() } }
        .fullScreenCover(isPresented: $showBrowser) {
            RichComponentsBrowser(theme: localTheme, preset: $preset, isDark: $isDark)
                .theme(localTheme)
                .environmentObject(themeStore)
                .feedbackHost()
                .sheetHost()
                .drawerHost()
        }
    }

    /// Load the selected preset into the Showcase's own theme (never `Theme.shared`).
    private func applyTheme() {
        localTheme.loadTheme(named: preset.resourceName, dark: isDark)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showBrowser = true
            } label: {
                Label("All components", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(localTheme.background(.bgWhite), in: Capsule())
                    .overlay(Capsule().stroke(localTheme.border(.borderPrimary), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            ThemePresetRow(theme: localTheme, preset: $preset, isDark: $isDark, autoCycle: $autoCycle)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(localTheme.background(.bgWhite), in: Capsule())
                .overlay(Capsule().stroke(localTheme.border(.borderPrimary), lineWidth: 0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private func advanceTheme() {
        let cases = DemoTheme.allCases
        guard let idx = cases.firstIndex(of: preset) else { return }
        let next = (idx + 1) % cases.count
        preset = cases[next]                 // onChange(of:) applies it to localTheme
        if next == 0 { isDark.toggle() }
    }
}

// MARK: - Page 0 · OVERVIEW (Ant-Design-homepage-style opening)

private struct OverviewPage: View {
    @State private var email = ""
    @State private var fruits: Set<String> = ["Apple", "Banana"]
    @State private var brandColor = Color(red: 0.086, green: 0.463, blue: 1.0)
    @State private var pickedDate: Date? = nil
    @State private var checkApple = true
    @State private var checkPear = false
    @State private var radioApple = true
    @State private var radioPear = false
    @State private var switchOn = true
    @State private var rangeTab = 0
    @State private var otp = "4320"
    @State private var calDate: Date? = nil

    var body: some View {
        PageScaffold(
            title: "ThemeKit",
            subtitle: "\(ComponentRegistry.all.count) native SwiftUI components · one theme, infinite skins."
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { inputsCard; choicesCard; calendarCard }
                VStack(spacing: 16) { verifyCard; buttonsCard; loyaltyCard }
                VStack(spacing: 16) { accountCard; dataCard; menuCard }
            }
        }
    }

    private var inputsCard: some View {
        CollageCard("Inputs") {
            VStack(spacing: 12) {
                TextInput("Email", text: $email).placeholder("antd@email.com").icon(leading: "envelope")
                MultiSelect("Fruits", options: ["Apple", "Banana", "Cherry", "Pear"], selection: $fruits) { $0 }
                    .placeholder("Select")
                HStack(spacing: 10) {
                    ColorField("Color", selection: $brandColor)
                    DateField(date: $pickedDate).placeholder("Date")
                }
            }
        }
    }

    private var choicesCard: some View {
        CollageCard("Choices") {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Checkbox("Apple", isChecked: $checkApple)
                    Checkbox("Pear", isChecked: $checkPear)
                }
                VStack(alignment: .leading, spacing: 10) {
                    RadioButton("Apple", isSelected: $radioApple)
                    RadioButton("Pear", isSelected: $radioPear)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ThemeToggle(isOn: $switchOn)
                    Spinner().style(.ring).size(20)
                }
            }
        }
    }

    private var calendarCard: some View {
        CollageCard("Calendar") {
            CalendarView(selection: $calDate)
        }
    }

    private var verifyCard: some View {
        CollageCard {
            VStack(spacing: 10) {
                AvatarGroup([
                    .initials("İM"), .icon("person.fill"), .initials("EK"),
                    .icon("person.crop.circle.fill"), .initials("AY"), .initials("MB"), .initials("SD"),
                ])
                .maxVisible(5).size(.sm)
                Text("Verify account").font(.headline)
                Text("Code sent to a****@gmail.com").font(.caption).foregroundStyle(.secondary)
                OTPInput(code: $otp).digitCount(6)
                HStack(spacing: 4) {
                    Text("Didn't get it?").font(.caption).foregroundStyle(.secondary)
                    TextLink("Resend") { }.accent(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var buttonsCard: some View {
        CollageCard("Buttons") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    PrimaryButton("Primary") { }.fullWidth()
                    ThemeButton("Danger") { }.color(.error).fullWidth()
                }
                HStack(spacing: 10) {
                    ThemeButton("Outlined") { }.variant(.outline).fullWidth()
                    ThemeButton("Round") { }.variant(.outline).color(.error).shape(.pill).fullWidth()
                }
                SegmentedControl(["1D", "7D", "1M", "1Y", "All"], selection: $rangeTab).fullWidth()
            }
        }
    }

    private var loyaltyCard: some View {
        LoyaltyCard(tier: "Gold", points: 8_430)
            .memberName("İsa Mercan")
            .progress(0.62, toNextTier: "Platinum")
            .flippable()
    }

    private var accountCard: some View {
        CollageCard {
            VStack(spacing: 12) {
                Avatar(.icon("person.crop.circle.fill")).size(.lg).accent(.primary)
                VStack(spacing: 3) {
                    Text("Create an account").font(.headline)
                    Text("Start your free 7-day trial. No credit card required.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                PrimaryButton("Get Started") { }.fullWidth()
                DividerView("OR")
                ThemeButton("Continue with Google") { }.variant(.outline).fullWidth().icon(leading: "g.circle.fill")
                ThemeButton("Continue with Apple") { }.variant(.outline).fullWidth().icon(leading: "apple.logo")
            }
            .frame(maxWidth: .infinity)
        }
        .borderBeam(cornerRadius: 18, lineWidth: 2)
    }

    private var dataCard: some View {
        CollageCard("Data & actions") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    QRCode("https://themekit.dev").size(72)
                    VStack(alignment: .leading, spacing: 8) {
                        Rating(value: 3).maxValue(5).starSize(16)
                        Spinner().style(.dots).size(18)
                    }
                }
                Flex {
                    Tag("Twitter").icon("at").color(.info).variant(.outline)
                    Tag("YouTube").icon("play.rectangle.fill").color(.error).variant(.outline)
                    Tag("Facebook").icon("f.square.fill").color(.primary).variant(.outline)
                }
            }
        }
    }

    private var menuCard: some View {
        MenuCard(items: [
            .init(title: "Reservations", subtitle: "3 upcoming", systemImage: "calendar"),
            .init(title: "Payment methods", systemImage: "creditcard"),
            .init(title: "Settings", systemImage: "gearshape"),
        ])
    }
}

// MARK: - Page 1 · TRAVEL (flight & booking component suite)

private struct TravelPage: View {
    @State private var flightFilters: Set<String> = ["cheapest"]
    @State private var viewMode = 0
    @State private var trendDay = 3
    @State private var sortSel = 0
    @State private var histLow = 800.0
    @State private var histHigh = 3_200.0

    private let departure = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 7))
        ?? Date(timeIntervalSince1970: 0)
    private var arrival: Date { departure.addingTimeInterval(3 * 3600 + 15 * 60) }
    private let trendPoints: [PriceTrendPoint] = [
        PriceTrendPoint("Mon", price: 1_450), PriceTrendPoint("Tue", price: 1_320),
        PriceTrendPoint("Wed", price: 1_680), PriceTrendPoint("Thu", price: 1_290),
        PriceTrendPoint("Fri", price: 1_540), PriceTrendPoint("Sat", price: 1_210),
        PriceTrendPoint("Sun", price: 1_760),
    ]
    private let sortOptions = [
        SortOption("Best", value: "₺2.777", subtitle: "1h 07m", icon: "star.fill"),
        SortOption("Cheapest", value: "₺2.178", subtitle: "6h 45m", icon: "tag.fill"),
        SortOption("Fastest", value: "₺3.410", subtitle: "1h 05m", icon: "bolt.fill"),
    ]

    var body: some View {
        PageScaffold(title: "Travel", subtitle: "A full flight-booking flow, assembled from ThemeKit.") {
            VStack(spacing: 16) {
                filterCard
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) { flightTrayCard; hotelCard }
                    VStack(spacing: 16) { priceTrendCard; sortSummaryCard; priceHistogramCard }
                    VStack(spacing: 16) { boardingPassCard; fareFamilyCard }
                }
            }
        }
    }

    private var filterCard: some View {
        CollageCard("Flight filters") {
            VStack(spacing: 12) {
                FilterBar([
                    QuickFilter("Cheapest", id: "cheapest"),
                    QuickFilter("Fastest"),
                    QuickFilter("Fast & Cheap"),
                    QuickFilter("Direct"),
                ], selection: $flightFilters)
                    .chipStyle(.outlined).size(.small)
                    .onFilter { }.onSort { }
                HStack {
                    TextLink("About prices & deals") { }
                    Spacer()
                    SegmentedControl([
                        SegmentItem(icon: "chart.bar.fill"),
                        SegmentItem(icon: "square.grid.2x2.fill"),
                    ], selection: $viewMode)
                        .tinted().dividers().shape(.round).fullWidth(false).size(.small)
                        .fixedSize()
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var flightTrayCard: some View {
        FlightListItem(legs: [
            FlightLeg(airline: "Skyline Air", from: "SAW", to: "AYT",
                      departure: departure, arrival: arrival, stops: 0, layover: nil),
        ])
        .cabin("Economy")
        .baggage("8 kg", checked: "20 kg")
        .price(12_700, currencyCode: "TRY", caption: "from")
        .original(22_700)
        .badge("Best value")
        .onDetails { }
        .onSelect { }
        .flightListItemStyle(.tray)
    }

    private var hotelCard: some View {
        HotelResultCard(name: "Mirage Park Resort")
            .location("Kemer, Antalya")
            .score(8.9, reviews: 1_284)
            .price(9_600)
            .media {
                LinearGradient(colors: [SemanticColor.info.base, SemanticColor.turquoise.base],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 130)
            }
    }

    private var priceTrendCard: some View {
        CollageCard("Price trend") {
            PriceTrendChart(trendPoints, selection: $trendDay).title("This week")
        }
    }

    private var sortSummaryCard: some View {
        CollageCard("Sort by") {
            SortSummaryBar(sortOptions, selection: $sortSel).onMore { }
        }
    }

    private var priceHistogramCard: some View {
        CollageCard("Price distribution") {
            PriceHistogram(bins: [2, 5, 9, 14, 18, 22, 19, 12, 8, 5, 3, 2],
                           lowerValue: $histLow, upperValue: $histHigh, in: 0...5_000)
                .barHeight(48).currency("TRY").showsBounds(true).resultCount(119)
        }
    }

    private var boardingPassCard: some View {
        BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER")
            .airline("Pegasus")
            .flightNo("PC 1234")
            .times(departure: "13:15", arrival: "16:05")
            .gate("A12", seat: "14C", boarding: "12:45")
            .barcode("PC1234SAWBER14C")
    }

    private var fareFamilyCard: some View {
        FareFamilyCard("Super Eco", price: 1_871.99)
            .accent(.success)
            .currency("TRY")
            .features([
                FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                FareFeature("Checked bag 20 kg", systemImage: "suitcase", status: .included),
                FareFeature("Non-changeable", systemImage: "nosign", status: .excluded),
            ])
            .onSelect { }
    }
}

// MARK: - Page 2 · CONTENT (messaging, offers, feedback, reviews)

private struct ContentPage: View {
    @State private var dismissedTip = false
    @State private var saleDeadline = Date.now.addingTimeInterval(45 * 60)
    private let paletteColors: [SemanticColor] = [.primary, .success, .warning, .error, .info, .purple]

    var body: some View {
        PageScaffold(title: "Content & feedback", subtitle: "Messaging, offers, reviews, status and timelines.") {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { chatCard; reviewCard }
                VStack(spacing: 16) { feedbackCard; accordionCard; tagsCard }
                VStack(spacing: 16) { couponCard; countdownCard; alertToastCard; paletteCard }
                VStack(spacing: 16) { timelineCard; ratingCard; alertCard }
            }
        }
    }

    private var tagsCard: some View {
        CollageCard("Tags") {
            Flex {
                Tag("Beachfront").color(.turquoise).variant(.soft)
                Tag("Free cancel").color(.success).variant(.soft)
                Tag("Breakfast").color(.info).variant(.soft)
                Tag("Pool").color(.primary).variant(.outline)
                Tag("Sold out", onRemove: { }).color(.error).variant(.solid)
            }
        }
    }

    private var countdownCard: some View {
        CollageCard("Flash sale") {
            VStack(spacing: 8) {
                Text("Ends soon — book now").font(.caption).foregroundStyle(.secondary)
                CountdownTimer(until: saleDeadline).style(.urgent).format(.boxed).size(.large).showsDays(false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var alertToastCard: some View {
        CollageCard("Alerts") {
            VStack(spacing: 8) {
                AlertToast("Saved successfully").variant(.success)
                AlertToast("Check your details").variant(.warning)
            }
        }
    }

    private var paletteCard: some View {
        CollageCard("Color palette") {
            VStack(spacing: 6) {
                ForEach(Array(paletteColors.enumerated()), id: \.offset) { _, color in
                    HStack(spacing: 4) {
                        ForEach(SemanticColor.Shade.allCases, id: \.rawValue) { shade in
                            RoundedRectangle(cornerRadius: 3).fill(color.shade(shade)).frame(height: 16)
                        }
                    }
                }
            }
        }
    }

    private var chatCard: some View {
        CollageCard("Chat") {
            VStack(alignment: .leading, spacing: 8) {
                ChatBubble("Hey! Is the flight confirmed?", time: "09:24").side(.incoming)
                ChatBubble("Yes — boarding at 12:45 ✈️", time: "09:25").side(.outgoing).accent(.success)
                ChatBubble("Perfect, see you there!", time: "09:26").side(.incoming)
            }
        }
    }

    private var couponCard: some View {
        CollageCard("Coupon") {
            Coupon(code: "THEMEKIT20", onCopy: { })
                .couponStyle(.outlined)
                .discount("20% OFF")
                .expiry("Valid until Dec 31")
        }
    }

    private var reviewCard: some View {
        ReviewCard(author: "Elif Kaya", score: 9.2,
                   text: "Absolutely loved the stay — spotless rooms, friendly staff and an unbeatable seafront location. Would book again in a heartbeat.")
            .verified(true).stars(true).title("Would absolutely stay again").date(.now)
    }

    private var feedbackCard: some View {
        CollageCard("Feedback") {
            VStack(alignment: .leading, spacing: 14) {
                Steps([
                    Steps.Step("Finished", state: .done),
                    Steps.Step("In Process", state: .error),
                    Steps.Step("Waiting", state: .todo),
                ])
                ProgressBar(value: 0.5).showsPercentage()
                Flex {
                    StatusDot(.online, label: "Success")
                    StatusDot(.busy, label: "Error")
                    StatusDot(.away, label: "Warning")
                }
            }
        }
    }

    private var ratingCard: some View {
        CollageCard("Reviews") {
            RatingSummary(score: 9.0).label("Excellent").reviews(count: 1_284)
        }
    }

    private var accordionCard: some View {
        CollageCard("FAQ") {
            VStack(spacing: 8) {
                Accordion("Can I cancel?", initiallyExpanded: true) {
                    Text("Free cancellation up to 24 hours before departure.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Accordion("What are the payment options?") {
                    Text("All major cards, Apple Pay and up to 12 installments.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var timelineCard: some View {
        CollageCard("Order timeline") {
            Timeline([
                Timeline.Item(title: "Order placed", time: "09:24", state: .done),
                Timeline.Item(title: "Packed", time: "10:10", state: .done),
                Timeline.Item(title: "Shipped", time: "12:00", state: .active),
                Timeline.Item(title: "Delivered", state: .todo),
            ])
            .pending("Awaiting courier…")
        }
    }

    private var alertCard: some View {
        Group {
            if !dismissedTip {
                NotificationCard(title: "ThemeKit") {
                    HStack(spacing: 8) {
                        ThemeButton("Cancel") { dismissedTip = true }.variant(.ghost).size(.small)
                        PrimaryButton("OK") { dismissedTip = true }.size(.small)
                    }
                }
                .message("Token-driven theming — swap one theme, restyle every component instantly.")
                .onClose { dismissedTip = true }
            }
        }
    }
}

// MARK: - Page 3 · DASHBOARD (product screen)

private struct DashboardPage: View {
    @State private var page = 1
    @State private var histLow = 900.0
    @State private var histHigh = 3_400.0
    @State private var installments = 1

    private struct Booking: Identifiable {
        let id: Int; let hotel: String; let nights: Int; let total: String
    }
    private let bookings: [Booking] = [
        Booking(id: 1, hotel: "Mirage Park Resort", nights: 4, total: "₺190,960"),
        Booking(id: 2, hotel: "Blue Lagoon Suites", nights: 2, total: "₺84,300"),
        Booking(id: 3, hotel: "Skyline Grand", nights: 3, total: "₺121,500"),
        Booking(id: 4, hotel: "Harbor View Hotel", nights: 5, total: "₺210,000"),
    ]

    var body: some View {
        PageScaffold(title: "Dashboard", subtitle: "The same components, composed into a product screen.") {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { statsCard; gaugesCard; seatMapCard }
                VStack(spacing: 16) { histogramCard; installmentCard; roomCard }
                VStack(spacing: 16) { tableCard; amenityCard; summaryCard }
                VStack(spacing: 16) { timelineCard; goalsCard }
            }
        }
    }

    private var seatMapCard: some View {
        CollageCard("Seat layouts") {
            SeatMap(columns: "AB CDE FG", rows: [1, 2, 3, 4], selection: .constant(["1A", "2C", "3F"])) { id, _, _ in
                SeatInfo(available: id != "2D")
            }
            .legend()
        }
    }

    private var installmentCard: some View {
        CollageCard("Installments") {
            InstallmentPicker([
                InstallmentOption(count: 1, total: 9_600),
                InstallmentOption(count: 3, total: 9_900, monthly: 3_300),
                InstallmentOption(count: 6, total: 10_200, monthly: 1_700),
            ], selection: $installments).currency("TRY")
        }
    }

    private var roomCard: some View {
        RoomCard(name: "Deluxe Room, Sea View")
            .board("All-inclusive").occupancy("2 adults, 1 child")
            .features([
                FareFeature("Free cancellation", systemImage: "checkmark.circle", status: .included),
                FareFeature("Breakfast included", systemImage: "cup.and.saucer", status: .included),
            ])
            .original(12_000).discountBadge("-20%").price(9_600).unit("/ night")
            .badge("Last 2").onSelect { }
    }

    private var amenityCard: some View {
        CollageCard("Amenities") {
            AmenityGrid([
                ThemeKit.Amenity("Free Wi-Fi", systemImage: "wifi"),
                ThemeKit.Amenity("Pool", systemImage: "figure.pool.swim"),
                ThemeKit.Amenity("Breakfast", systemImage: "cup.and.saucer"),
                ThemeKit.Amenity("Parking", systemImage: "car.fill"),
                ThemeKit.Amenity("Gym", systemImage: "dumbbell.fill"),
                ThemeKit.Amenity("Spa", systemImage: "sparkles"),
            ]).columns(2).size(.medium)
        }
    }

    private var statsCard: some View {
        CollageCard {
            VStack(spacing: 14) {
                Stat(title: "Bookings", value: 1_284).icon("ticket").trend(.up("+12%")).description("this month")
                Divider()
                Stat(title: "Revenue", value: 486).prefix("₺").suffix("K").icon("creditcard").trend(.up("+8%")).description("this month")
            }
        }
    }

    private var gaugesCard: some View {
        CollageCard("Utilization") {
            HStack(spacing: 18) {
                gauge(0.72, "CPU", .primary)
                gauge(0.54, "Memory", .purple)
                gauge(0.88, "Disk", .success)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func gauge(_ v: Double, _ label: String, _ accent: SemanticColor) -> some View {
        VStack(spacing: 6) {
            RadialProgress(v).size(76).showsLabel().accent(accent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var histogramCard: some View {
        CollageCard("Spend distribution") {
            PriceHistogram(bins: [3, 7, 12, 18, 24, 20, 15, 10, 6, 4, 2, 1],
                           lowerValue: $histLow, upperValue: $histHigh, in: 0...5_000)
                .barHeight(44).currency("TRY").showsBounds(true)
        }
    }

    private var tableCard: some View {
        CollageCard("Recent bookings") {
            VStack(spacing: 12) {
                DataTable<Booking>(columns: [
                    DataTable<Booking>.Column("Hotel", align: .leading, value: { $0.hotel }),
                    DataTable<Booking>.Column("Nights", align: .center, value: { "\($0.nights)" }),
                    DataTable<Booking>.Column("Total", align: .trailing, value: { $0.total }),
                ], rows: bookings)
                    .striped()
                Pagination(current: $page, total: 12).simple()
            }
        }
    }

    private var summaryCard: some View {
        KeyValueTable(rows: [
            KeyValueTable.Row("Gross revenue", value: "₺486,000"),
            KeyValueTable.Row("Refunds", value: "−₺12,400"),
            KeyValueTable.Row("Fees", value: "−₺8,900"),
            KeyValueTable.Row("Net", value: "₺464,700"),
        ])
        .title("Revenue breakdown")
        .bordered()
    }

    private var timelineCard: some View {
        CollageCard("Order timeline") {
            Timeline([
                Timeline.Item(title: "Order placed", time: "09:24", state: .done),
                Timeline.Item(title: "Packed", time: "10:10", state: .done),
                Timeline.Item(title: "Shipped", time: "12:00", state: .active),
                Timeline.Item(title: "Delivered", state: .todo),
            ])
            .pending("Awaiting courier…")
        }
    }

    private var goalsCard: some View {
        CollageCard("Goals") {
            VStack(alignment: .leading, spacing: 12) {
                goal("New users", 0.68, .active)
                goal("Revenue target", 0.42, .normal)
                goal("Retention", 0.91, .success)
            }
        }
    }

    private func goal(_ label: String, _ v: Double, _ status: ProgressStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            ProgressBar(value: v).showsPercentage().status(status)
        }
    }
}

// MARK: - Page 4 · FORMS & LISTS (grouped inputs · multi-select · passenger rows)

private struct FormsPage: View {
    @State private var email = ""
    @State private var newsletter = true
    @State private var interests: Set<String> = ["Design", "Code"]
    @State private var cities: Set<String> = ["Istanbul", "Rome"]
    @State private var nickname = ""
    @State private var priceAlerts = true

    var body: some View {
        PageScaffold(title: "Forms & lists",
                     subtitle: "Grouped inputs, multi-select, amenities and passenger rows — all live.") {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { fieldsetCard; checkboxGroupCard }
                VStack(spacing: 16) { multiSelectCard; amenitiesCard }
                VStack(spacing: 16) { passengersCard; whatsNewCard }
            }
        }
    }

    private var fieldsetCard: some View {
        CollageCard("Fieldset") {
            Fieldset("Contact") {
                VStack(alignment: .leading, spacing: 12) {
                    TextInput("Email", text: $email).placeholder("antd@email.com").icon(leading: "envelope")
                    Checkbox("Subscribe to the newsletter", isChecked: $newsletter)
                }
            }
            .helper("We'll only email booking updates.")
        }
    }

    private var checkboxGroupCard: some View {
        CollageCard("CheckboxGroup") {
            CheckboxGroup(title: "Interests",
                          options: ["Design", "Code", "Travel", "Music"],
                          selection: $interests) { $0 }
        }
    }

    private var multiSelectCard: some View {
        CollageCard("MultiSelect") {
            MultiSelect("Cities",
                        options: ["Istanbul", "Rome", "Paris", "Tokyo", "Berlin"],
                        selection: $cities) { $0 }
                .placeholder("Select")
        }
    }

    private var amenitiesCard: some View {
        CollageCard("Amenities") {
            AmenityGrid([
                ThemeKit.Amenity("Free Wi-Fi", systemImage: "wifi"),
                ThemeKit.Amenity("Breakfast", systemImage: "cup.and.saucer.fill"),
                ThemeKit.Amenity("Pool", systemImage: "figure.pool.swim"),
                ThemeKit.Amenity("Parking", systemImage: "parkingsign"),
            ])
            .columns(2)
            .highlighted(["Free Wi-Fi"])
        }
    }

    private var passengersCard: some View {
        CollageCard("Passengers") {
            VStack(spacing: 8) {
                PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345").seat("14C").status("Checked in").onEdit { }
                PassengerRow("Ada Lovelace").type("Adult").subtitle("Passport · UK88231").seat("14D").onEdit { }
                PassengerRow("Kid Mercan").type("Child").subtitle("12 years").seat("14E").onEdit { }
            }
        }
    }

    /// Compact tour of the six freshly-shipped components: CloseButton,
    /// HelperText, SurfaceView, SkeletonGroup, ControlRow and ScrollShadow.
    private var whatsNewCard: some View {
        CollageCard {
            VStack(alignment: .leading, spacing: 12) {
                // Title row — Badge-tagged, with a CloseButton in the corner.
                HStack(spacing: 8) {
                    Text("Just shipped").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Badge("New").badgeStyle(.success).size(.small)
                    Spacer()
                    CloseButton { }.controlSize(.mini)
                }

                // HelperText under a mock field.
                VStack(alignment: .leading, spacing: 4) {
                    TextInput("Nickname", text: $nickname).placeholder("e.g. skywalker")
                    HelperText("Visible only to your travel group.")
                }

                // ControlRow with a checkbox control.
                ControlRow("Email me price drops", isOn: $priceAlerts)
                    .control(.checkbox)
                    .description("One email per route, max.")

                // Horizontal chip row fading at the edges via ScrollShadow.
                ScrollShadow {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Nonstop", "Morning", "Refundable", "Baggage", "Window seat"], id: \.self) { title in
                                Chip(title, isSelected: .constant(false))
                            }
                        }
                    }
                }
                .axis(.horizontal)
                .length(.md)
                .fadeColor(.bgWhite)

                // Nested SurfaceView levels wrapping a skeleton-only SkeletonGroup.
                SurfaceView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surface · secondary").font(.caption).foregroundStyle(.secondary)
                        SurfaceView {
                            SkeletonGroup {
                                HStack(spacing: 8) {
                                    Skeleton(.circle).size(width: 28, height: 28)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Skeleton(.capsule).size(width: 120, height: 8)
                                        Skeleton(.capsule).size(width: 80, height: 8)
                                    }
                                }
                            }
                            .skeletonOnly()
                            .loading(true)
                        }
                        .level(.tertiary)
                        .contentPadding(.sm)
                    }
                }
                .level(.secondary)
                .contentPadding(.sm)
            }
        }
    }
}

// MARK: - Page 5 · THEMEKITTRAVEL (the opt-in flight-booking edition)

private struct ThemeKitTravelPage: View {
    // A populated draft so the search CTA reads as ready (blue), not disabled (grey).
    @State private var trip: TripSearchDraft = {
        var d = TripSearchDraft()
        d.origin = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
        d.destination = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
        d.departureDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        d.returnDate = Date(timeIntervalSinceReferenceDate: 800_000_000 + 7 * 86_400)
        return d
    }()
    @State private var cabin: CabinClass = .business
    @State private var method: String? = "card"
    @State private var months = 3
    @State private var phone = "532 123 45 67"
    @State private var lang = "en"
    @State private var cardID: String? = "visa"
    @State private var passenger = PassengerDraft()
    @State private var checkinStep = 0
    @State private var airportSel: Airport?

    private let airports: [Airport] = [
        Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR"),
        Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB"),
        Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US"),
        Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR"),
        Airport(code: "BER", name: "Brandenburg Airport", city: "Berlin", countryCode: "DE"),
        Airport(code: "DXB", name: "Dubai International", city: "Dubai", countryCode: "AE"),
    ]
    private let paymentOptions: [PaymentMethodOption] = [
        .init(id: "card", kind: .card, title: "Credit / debit card"),
        .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
    ]
    private let cards: [SavedCard] = [
        SavedCard(id: "visa", brand: .visa, last4: "4242", holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
        SavedCard(id: "mc", brand: .mastercard, last4: "4444", holder: "Alex Morgan", expiryMonth: 1, expiryYear: 2031),
    ]
    private let languages: [AppLanguage] = [
        AppLanguage(code: "en"), AppLanguage(code: "tr"), AppLanguage(code: "de"), AppLanguage(code: "fr"),
    ]
    private let checkinSteps: [Steps.Step] = [
        .init("Passengers", state: .active),
        .init("Seats", state: .todo),
        .init("Boarding pass", state: .todo),
    ]
    private var trackerInfo: FlightStatusInfo {
        let dep = Date(timeIntervalSinceReferenceDate: 790_000_000)
        return FlightStatusInfo(
            leg: FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: dep, arrival: dep.addingTimeInterval(4 * 3600)),
            status: .boarding, gate: "B12", terminal: "1", checkInDesk: "34–38")
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("ThemeKitTravel").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("The opt-in flight-booking edition — every component, one import.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 34) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        TripSearchCard(draft: $trip, onSearch: { _ in })
                            .airports(suggestions: airports, recent: Array(airports.prefix(2)))
                            .variant(.card)
                        CollageCard("Cabin class") {
                            // .chips (not .segmented): a narrow column can't give four
                            // equal segments enough width for "Premium Economy" without
                            // wrapping the labels character-by-character.
                            CabinClassSelector(selection: $cabin).variant(.chips).showsGlyphs()
                        }
                        CollageCard("Contact & language") {
                            VStack(spacing: 12) {
                                PhoneField("Phone", number: $phone).formatsNumber()
                                LanguageSwitcher(languages, selection: $lang).variant(.inline).showsFlags()
                            }
                        }
                    }
                    VStack(spacing: 16) {
                        CollageCard("Airport search") {
                            AirportPicker(selection: $airportSel, suggestions: airports)
                                .recent([airports[0], airports[1]])
                                .popular([airports[2], airports[3]])
                                .presentation(.inline)
                        }
                        CollageCard("Passenger form") {
                            PassengerForm("Passenger 1 · Adult", draft: $passenger)
                                .fields([.givenName, .familyName, .documentNumber])
                                .documentRequired()
                        }
                    }
                    VStack(spacing: 16) {
                        CollageCard("Payment method") {
                            PaymentMethodSelector(paymentOptions, selection: $method)
                                .installments([1, 3, 6, 9], selection: $months, total: 9_600)
                        }
                        SavedCardsList(cards, selection: $cardID).flagsExpired()
                        CollageCard("Check-in flow") {
                            CheckInFlow(steps: checkinSteps, selection: $checkinStep) { index in
                                checkinPage(index)
                            }
                            .frame(height: 230)
                        }
                    }
                    VStack(spacing: 16) {
                        FlightTracker(trackerInfo).progress(0.62).showsTimeline()
                        TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                            .price(19).duration("2h 10m").badge("Eco").onSelect { }
                    }
                }
                .frame(maxWidth: 1500)

                variantsBand
                }
                .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 78)
        .padding(.bottom, 18)
    }

    // MARK: New in the flexibility sweep — alternative variants, layouts & styles
    private var variantsBand: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Flexibility sweep").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("The same components, re-skinned through additive variants, layouts and slots — no forking.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            HStack(alignment: .top, spacing: 16) {
                CollageCard("Cabin class · .cards") {
                    CabinClassSelector(selection: $cabin).variant(.cards).showsGlyphs()
                }
                CollageCard("Payment · .grid") {
                    PaymentMethodSelector(paymentOptions, selection: $method).variant(.grid)
                }
                CollageCard("Saved cards · .wallet") {
                    SavedCardsList(cards, selection: $cardID).variant(.wallet).flagsExpired()
                }
                CollageCard("Tracker · .compact") {
                    FlightTracker(trackerInfo).variant(.compact).progress(0.62)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                CollageCard("Fare families · .layout(.column)") {
                    HStack(spacing: 10) {
                        FareFamilyCard("Eco Fly", price: 3_116).layout(.column)
                        FareFamilyCard("Extra Fly", price: 4_250).accent(.info).layout(.column)
                    }
                }
                CollageCard("Status badge · .emphasis") {
                    HStack(spacing: 8) {
                        FlightStatusBadge(.boarding).emphasis(.soft)
                        FlightStatusBadge(.boarding).emphasis(.solid)
                        FlightStatusBadge(.delayed).emphasis(.outline)
                        FlightStatusBadge(.arrived).emphasis(.dot)
                    }
                }
                CollageCard("Transport · .tile") {
                    TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                        .variant(.tile).size(.small).price(19).duration("6h 30m").onSelect { }
                }
            }
            CollageCard("FlightListItem · new presets — .tile · .hero · .receipt") {
                HStack(alignment: .top, spacing: 16) {
                    baseFlightItem().flightListItemStyle(.tile).frame(width: 200)
                    VStack(spacing: 12) {
                        baseFlightItem().flightListItemStyle(.hero)
                        baseFlightItem().flightListItemStyle(.receipt)
                    }
                }
            }
        }
        .frame(maxWidth: 1500)
    }

    private func baseFlightItem() -> FlightListItem {
        let dep = Date(timeIntervalSinceReferenceDate: 800_000_000)
        return FlightListItem(legs: [
            FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                      departure: dep, arrival: dep.addingTimeInterval(4 * 3600), stops: 0, layover: nil),
        ])
        .cabin("Economy")
        .baggage("8 kg", checked: "20 kg")
        .price(214, currencyCode: "USD", caption: "from")
        .original(320)
        .badge("Best")
        .onSelect { }
    }

    @ViewBuilder private func checkinPage(_ index: Int) -> some View {
        let glyphs = ["person.2.fill", "chair.fill", "qrcode"]
        let titles = ["Traveler details", "Choose your seats", "Your boarding pass"]
        VStack(spacing: 8) {
            Image(systemName: glyphs[min(index, 2)]).font(.system(size: 36)).foregroundStyle(.secondary)
            Text(titles[min(index, 2)]).font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Shared page scaffold (title + centered, fit-to-screen body)

private struct PageScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(title).font(.system(size: 34, weight: .bold, design: .rounded))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            content()
                .frame(maxWidth: 1300)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 78)
        .padding(.bottom, 52)
    }
}

// MARK: - Titled collage container (Ant-style rounded card)

struct CollageCard<Content: View>: View {
    @Environment(\.theme) private var theme
    private let title: String?
    @ViewBuilder private let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: 0.5)
        )
    }
}

// MARK: - Theme preset row (swatches + dark toggle + auto-cycle)

struct ThemePresetRow: View {
    let theme: Theme                 // the Showcase's own theme (for chrome tint)
    @Binding var preset: DemoTheme   // drives the local theme via the parent's onChange
    @Binding var isDark: Bool
    @Binding var autoCycle: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(DemoTheme.allCases) { p in
                Button { preset = p } label: {
                    Circle()
                        .fill(swatch(p))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.primary.opacity(preset == p ? 0.9 : 0), lineWidth: 2))
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(p.label)
            }

            Divider().frame(height: 18)

            Button { isDark.toggle() } label: {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle dark mode")

            Button { autoCycle.toggle() } label: {
                Image(systemName: autoCycle ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.foreground(.systemcolorsFgInfo))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(autoCycle ? "Pause auto theme cycle" : "Start auto theme cycle")
        }
    }

    private func swatch(_ theme: DemoTheme) -> Color {
        switch theme {
        case .default: return Color(red: 0.086, green: 0.463, blue: 1.0)
        case .ocean: return Color(red: 0.0, green: 0.60, blue: 0.65)
        case .sunset: return Color(red: 1.0, green: 0.48, blue: 0.20)
        }
    }
}

#Preview {
    ShowcaseView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
