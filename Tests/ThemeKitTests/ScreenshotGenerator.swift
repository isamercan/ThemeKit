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
            Avatar(.initials("CD"), size: .lg, presence: .online)
            Avatar(.initials("AB"), size: .md)
            Avatar(.icon("person.fill"), size: .md)
        })
        shot("Badge", HStack(spacing: 8) {
            Badge("Success", style: .success)
            Badge("Info", style: .info, leadingSystemImage: "star.fill")
            Badge("Error", style: .error, variant: .solid)
        })
        shot("Chip", HStack(spacing: 8) {
            Chip("Selected", isSelected: .constant(true))
            Chip("Unselected", isSelected: .constant(false))
        })
        shot("CountBadge", Icon(systemName: "bell", size: .xl, color: Theme.shared.text(.textPrimary)).countBadge(5))
        shot("Divider", DividerView(dashed: true, title: "OR", titleAlign: .center).frame(width: 240))
        shot("Icon", HStack(spacing: 14) {
            Icon(systemName: "star.fill", size: .xl, color: Theme.shared.foreground(.fgHero))
            Icon(systemName: "heart.fill", size: .xl, color: Theme.shared.foreground(.systemcolorsFgError))
            Icon(systemName: "checkmark.seal.fill", size: .xl, color: Theme.shared.foreground(.systemcolorsFgSuccess))
        })
        shot("Indicator", Icon(systemName: "bell", size: .xl, color: Theme.shared.text(.textPrimary)).indicatorDot())
        shot("InputLabel", InputLabel("Email", isRequired: true, hasInfo: true))
        shot("Kbd", HStack(spacing: 6) { Kbd("⌘"); Kbd("K") })
        shot("ProgressBar", ProgressBar(value: 0.6, showPercentage: true).frame(width: 240))
        shot("RadialProgress", RadialProgress(value: 0.66, size: 96, showLabel: true))
        shot("Rating", Rating(value: 4.3, countLabel: "(128)"))
        shot("RollingNumber", RollingNumber(1284, size: 40))
        shot("ScoreBadge", ScoreBadge(9.0))
        shot("Skeleton", HStack(spacing: 12) {
            Skeleton(.circle, width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(.capsule, width: 160, height: 12)
                Skeleton(.capsule, width: 110, height: 12)
            }
        })
        shot("Spinner", Spinner(size: 32, lineWidth: 3))
        shot("StatusDot", HStack(spacing: 16) {
            StatusDot(.online, label: "Online")
            StatusDot(.away, label: "Away")
            StatusDot(.busy, label: "Busy")
        })
        shot("Swap", Swap(isOn: .constant(true), on: "xmark", off: "line.3.horizontal"))
        shot("Tag", HStack(spacing: 8) {
            Tag("Success", style: .success)
            Tag("Error", style: .error, variant: .solid)
            Tag("Info", style: .info, variant: .outline)
        })
        shot("TextLink", TextLink("Forgot password?", underline: true) {})
        shot("Title", Title("Section title", subtitle: "Supporting subtitle", actionTitle: "See all") {}.frame(width: 320))
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
            GaugeView(value: 0.4, label: "Disk", style: .linear).frame(width: 140)
        }, hosted: true)
        shot("ShareButton", ShareButton(item: "https://github.com/isamercan/ThemeKit"), hosted: true)
    }

    // MARK: Molecules

    private func molecules() {
        shot("Button", HStack(spacing: 10) {
            PrimaryButton("Continue", block: true) {}
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
                                            selection: .constant(["Wifi", "Pool"]), selectAllTitle: "Select all") { $0 }.frame(width: 280))
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
        shot("Stat", Stat(title: "Total bookings", value: "1,284", suffix: "$",
                          description: "this month", systemImage: "ticket", trend: .up("+12%")).frame(width: 280))
        shot("Steps", Steps([.init("Cart", description: "2 items", systemImage: "cart", state: .done),
                             .init("Payment", description: "Card", state: .active),
                             .init("Done", state: .todo)]).frame(width: 360))
        shot("Slider", ThemeKit.Slider(value: .constant(4), in: 0...8, label: "Guests")
                                       .marks([0: "0", 4: "4", 8: "8"]).frame(width: 300))
        shot("Breadcrumbs", Breadcrumbs([.init("Home", action: {}), .init("Hotels", action: {}), .init("Istanbul")]).frame(width: 320))
        shot("TextInput", TextInput("Email", text: .constant("user@example.com")).frame(width: 300), hosted: true)
        shot("FileInput", FileInput(label: "Passport", fileName: "passport-scan.jpg", onPick: {}, onClear: {}).frame(width: 320))
        shot("Pagination", Pagination(current: .constant(4), total: 50).frame(width: 360))
        shot("Fieldset", Fieldset("Contact details", helper: "We never share your info.") {
            TextInput("Email", text: .constant("user@example.com"))
        }.frame(width: 320), hosted: true)
        shot("DateField", DateField("Check-in", date: .constant(nil)).frame(width: 280))
        shot("Select", Select("City", options: ["Istanbul", "Ankara", "Izmir"],
                              selection: .constant(Optional("Istanbul")), searchable: true) { $0 }.frame(width: 280), hosted: true)
        // SelectBox is a native SwiftUI Menu — its label doesn't draw into an
        // offscreen snapshot, so it's shown live in the Demo app instead.
        shot("MultiSelect", MultiSelect(label: "Cities", options: ["Istanbul", "Ankara", "Izmir"],
                                        selection: .constant(Set(["Istanbul", "Ankara"]))) { $0 }.frame(width: 300))
        shot("TreeSelect", TreeSelect(label: "Cities",
                                      nodes: [TreeNode(id: "tr", "Turkey", systemImage: "flag",
                                                       children: [TreeNode(id: "ist", "Istanbul"), TreeNode(id: "ank", "Ankara")])],
                                      selection: .constant(Set(["ist"])), initiallyExpanded: ["tr"]).frame(width: 300))
        shot("Autocomplete", Autocomplete(label: "Destination", text: .constant("Istanbul"),
                                          suggestions: ["Istanbul", "Izmir"]).frame(width: 300), hosted: true)
        shot("SearchBar", SearchBar(text: .constant("Istanbul")).frame(width: 320), hosted: true)
        shot("OTPInput", OTPInput(code: .constant("1234"), digitCount: 6).frame(width: 300))
        shot("InputNumber", InputNumber(label: "Max price", value: .constant(250), range: 0...1000, step: 50, unit: "$").frame(width: 280), hosted: true)
        shot("RangeSlider", RangeSlider(lowerValue: .constant(200), upperValue: .constant(800),
                                        in: 0...1000, step: 50).marks([0, 500, 1000]).frame(width: 320))
        shot("MultiLineTextInput", MultiLineTextInput("Notes", text: .constant("It was a wonderful stay, I would definitely recommend it.")).frame(width: 300), hosted: true)
        shot("Tooltip", Icon(systemName: "info.circle", size: .lg, color: Theme.shared.foreground(.fgHero))
            .tooltip("Helpful tip", isPresented: .constant(true), edge: .top)
            .padding(.top, 36))
        shot("Chips", CompactChip(isSelected: .constant(true), text: "Suit", price: "$899", rating: 4.6))
        shot("FilterGroup", FilterGroup(options: ["All", "Hotel", "Villa", "Apartment"],
                                        selection: .constant(Optional("Hotel"))) { $0 }.frame(width: 320))
        shot("ProgressIndicator", ProgressIndicator(variant: .carousel, current: 2, total: 8).frame(width: 240))
        shot("ThemeController", ThemeController(options: [.init(name: "defaultTheme", label: "Default"),
                                                          .init(name: "oceanTheme", label: "Ocean"),
                                                          .init(name: "sunsetTheme", label: "Sunset")],
                                                selectedName: .constant("oceanTheme")).frame(width: 320))
        shot("Calendar", CalendarView(selection: .constant(nil)).frame(width: 320))
        shot("ColorField", ColorField("Brand color", selection: .constant(Theme.shared.foreground(.fgHero))).frame(width: 280), hosted: true)
    }

    // MARK: Organisms

    private func organisms() {
        shot("Accordion", Accordion("What is your return policy?", initiallyExpanded: true) {
            Text("You can request a refund within 14 days of purchase.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.frame(width: 340))
        shot("AlertToast", AlertToast("Saved successfully", message: "Your changes were stored.", type: .success).frame(width: 340))
        shot("Callout", VStack(alignment: .leading, spacing: 10) {
            Callout("Saved successfully.", type: .success)
            Callout("Please review your details.", type: .warning, style: .soft)
            Callout("Something went wrong.", type: .error, style: .soft)
        }.frame(width: 320))
        shot("Card", Card(elevation: .soft, title: "Reservation", subtitle: "2 nights · 2 guests", extraTitle: "Details", onExtra: {}) {
            Text("Hilton London — Deluxe room, breakfast included.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.frame(width: 320))
        shot("ChatBubble", VStack(alignment: .leading, spacing: 8) {
            ChatBubble("Hi! Your reservation is confirmed.", side: .incoming, author: "Support", time: "09:24")
            ChatBubble("Thanks!", side: .outgoing, time: "09:25")
        }.frame(width: 320))
        shot("Counter", Counter(days: 2, hours: 8, minutes: 45))
        shot("Coupon", Coupon(code: "UXMUQ", style: .outlined).frame(width: 300))
        shot("EmptyState", EmptyState(systemImage: "magnifyingglass", title: "No results found",
                                      message: "Try adjusting your search or filters.",
                                      buttonTitle: "Clear filters", action: {},
                                      secondaryTitle: "Learn more", onSecondary: {}).frame(width: 320))
        shot("InfoBanner", InfoBanner("Your reservation is confirmed. Go to the ticket page for details.",
                                      type: .info, title: "Heads up").frame(width: 340))
        shot("KeyValueTable", KeyValueTable(rows: [.init("Status", value: "Active", style: .success),
                                                   .init("Old price", value: "$5,000", style: .strikethrough),
                                                   .init("Total", value: "$4,250")],
                                            title: "Reservation summary", bordered: true).frame(width: 320))
        shot("ListRow", VStack(spacing: 0) {
            ListRow("My account", action: {}).subtitle("Profile and security").icon("person.circle")
            DividerView(size: .small)
            ListRow("Notifications", action: {}).subtitle("Email and push").icon("bell")
        }.frame(width: 320))
        shot("NotificationCard", NotificationCard(title: "We Have a Suggestion for Your Trip",
                                                  message: "24 days until your Hilton London reservation.",
                                                  date: "December 5, 2024", isUnread: true, type: .success).frame(width: 340))
        shot("PageHeader", PageHeader("Search results", subtitle: "128 hotels",
                                      tags: [.init("Active", style: .success)], onBack: {}).frame(width: 340))
        shot("RatingSummary", RatingSummary(score: 9.0, label: "Excellent", reviewCount: 1200).frame(width: 300))
        shot("ResultView", ResultView(.notFound, title: "Page not found",
                                      message: "The page you're looking for may have moved.",
                                      primaryTitle: "Home", onPrimary: {}).frame(width: 320))
        shot("SegmentedTabBar", SegmentedTabBar([TabItem("Overview"), TabItem("Reviews", badge: "12"),
                                                 TabItem("Location")], selection: .constant(1)).frame(width: 340))
        shot("Timeline", Timeline([.init(title: "Order received", time: "09:24", systemImage: "cart", state: .done, color: .success),
                                   .init(title: "Preparing", time: "09:40", systemImage: "shippingbox", state: .active),
                                   .init(title: "On the way", state: .todo)], pending: "Waiting for courier…").frame(width: 320))
        shot("Upload", Upload(prompt: "You can upload up to 3 photos.", buttonTitle: "Add photo",
                              files: [.init(name: "room-1.jpg", status: .done),
                                      .init(name: "room-2.jpg", status: .uploading(0.6))], maxCount: 3,
                              onPick: {}, onRemove: { _ in }).frame(width: 320))
        shot("PromoBanner", PromoBanner(title: "Early booking", subtitle: "Save up to 30% on summer",
                                        systemImage: "sun.max.fill", ctaTitle: "Explore", action: {}).frame(width: 340))
        let rowTitles = ["My account", "Notifications", "Language", "Payment"]
        shot("ListView", ListView(tiles, header: "Settings", footer: "\(tiles.count) items", bordered: true) { tile in
            ListRow(rowTitles[tile.id], action: {}).subtitle("Details").icon("gearshape")
        }.frame(width: 320))
        shot("MenuCard", MenuCard(items: [
            .init(title: "Reservations", subtitle: "Upcoming & past", systemImage: "calendar"),
            .init(title: "Payment methods", subtitle: "Cards & wallets", systemImage: "creditcard"),
            .init(title: "Settings", subtitle: "App preferences", systemImage: "gearshape"),
        ]).frame(width: 320))
        shot("NavigationBar", NavigationBar(items: [
            .init(systemImage: "house"), .init(systemImage: "heart"), .init(systemImage: "bag"), .init(systemImage: "person"),
        ], selection: .constant(0)).frame(width: 320))
        shot("FAB", FloatingActionButton(systemImage: "plus") {})
        shot("Hero", Hero(title: "Early booking", subtitle: "Up to 30% off your summer holiday",
                          ctaTitle: "Explore", action: {}) { Theme.shared.background(.bgHero) }.frame(width: 340, height: 180))
        shot("SelectionCards", VStack(spacing: 10) {
            RadioCard("Standard", description: "Free cancellation", isSelected: true) {}
            RadioCard("Flexible", description: "Change anytime", isSelected: false) {}
        }.frame(width: 320))
        shot("CardStack", CardStack(tiles) { self.tileView($0) }.frame(width: 300))
        // Carousel / PagingCarousel use a paged TabView, which ImageRenderer can't
        // capture on macOS — see them live in the Demo app.
        shot("Gallery", Gallery(tiles, columns: 2) { self.tileView($0) }.frame(width: 320))
        shot("Footer", Footer(columns: [
            .init("Company", items: [.init("About"), .init("Careers")]),
            .init("Support", items: [.init("Help"), .init("Contact")]),
        ], note: "© 2026 ThemeKit.").frame(width: 340))
        shot("Diff", Diff {
            Theme.shared.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
        } after: {
            Theme.shared.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
        }.frame(width: 320, height: 140))
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
                    Text("117").font(.system(size: 46, weight: .black)).foregroundStyle(t.text(.textPrimary))
                    tiny("COMPONENTS"); sub("29 atoms · 45 molecules · 43 organisms")
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
                    Badge("v0.2.0 · iOS 17+", style: .info, leadingSystemImage: "swift")
                    HStack(spacing: 12) {
                        RadialProgress(value: 0.72, size: 52, showLabel: false)
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
                                if on { Icon(systemName: "checkmark", size: .sm, color: t.foreground(.fgSecondary)) }
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
            Hero(title: "Stay", subtitle: "Find your spot", ctaTitle: "Book", action: {})
                .frame(height: 128)
            HStack(spacing: 6) {
                Badge("Info", style: .info, leadingSystemImage: "bell.fill")
                Tag("Filter", onRemove: {})
            }
            InfoBanner("Subtree-themed", type: .success)
            Stat(title: "Bookings", value: "1,284", systemImage: "ticket", trend: .up("+12%"))
            PrimaryButton("Continue", block: true) {}
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
        let decorated = view.padding(16)
            .background(Theme.shared.background(.bgWhite))
            .environment(\.colorScheme, scheme)
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
