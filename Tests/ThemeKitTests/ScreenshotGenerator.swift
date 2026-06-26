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

    func testGenerateAll() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GENERATE_SCREENSHOTS"] == "1",
            "Set GENERATE_SCREENSHOTS=1 to render component screenshots."
        )
        Theme.shared.loadTheme(named: "defaultTheme")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        category = "Atoms"; atoms()
        category = "Molecules"; molecules()
        category = "Organisms"; organisms()

        let tsv = manifest.map { "\($0.0)\t\($0.1)" }.joined(separator: "\n") + "\n"
        try tsv.write(to: outDir.appendingPathComponent("manifest.tsv"), atomically: true, encoding: .utf8)
    }

    // MARK: Atoms

    private func atoms() {
        shot("Avatar", HStack(spacing: 12) {
            Avatar(.initials("İM"), size: .lg, presence: .online)
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
    }

    // MARK: Molecules

    private func molecules() {
        shot("Button", HStack(spacing: 10) {
            PrimaryButton("Continue") {}
            SecondaryButton("Cancel") {}
            OutlineButton("More") {}
        })
        shot("ThemeButton", HStack(spacing: 10) {
            ThemeButton("Solid", color: .primary) {}
            ThemeButton("Soft", color: .success, variant: .soft) {}
            ThemeButton("Pill", color: .error, variant: .outline, shape: .pill) {}
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
        shot("Stat", Stat(title: "Total bookings", value: "1,284", suffix: "₺",
                          description: "this month", systemImage: "ticket", trend: .up("+12%")).frame(width: 280))
        shot("Steps", Steps([.init("Cart", description: "2 items", systemImage: "cart", state: .done),
                             .init("Payment", description: "Card", state: .active),
                             .init("Done", state: .todo)]).frame(width: 360))
        shot("Slider", ThemeKit.Slider(value: .constant(4), in: 0...8, label: "Guests",
                                       marks: [0: "0", 4: "4", 8: "8"], showValueTooltip: false).frame(width: 300))
        shot("Breadcrumbs", Breadcrumbs([.init("Home", action: {}), .init("Hotels", action: {}), .init("İstanbul")]).frame(width: 320))
        shot("TextInput", TextInput("Email", text: .constant("user@example.com")).frame(width: 300))
        shot("FileInput", FileInput(label: "Passport", fileName: "passport-scan.jpg", onPick: {}, onClear: {}).frame(width: 320))
        shot("Pagination", Pagination(current: .constant(4), total: 50).frame(width: 360))
        shot("Fieldset", Fieldset("Contact details", helper: "We never share your info.") {
            TextInput("Email", text: .constant("user@example.com"))
        }.frame(width: 320))
        shot("DateField", DateField(label: "Check-in", date: .constant(nil)).frame(width: 280))
    }

    // MARK: Organisms

    private func organisms() {
        shot("Accordion", Accordion("İade politikanız nedir?", initiallyExpanded: true) {
            Text("Satın alımdan sonraki 14 gün içinde iade talep edebilirsiniz.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.frame(width: 340))
        shot("AlertToast", AlertToast("Saved successfully", message: "Your changes were stored.", type: .success).frame(width: 340))
        shot("Callout", VStack(alignment: .leading, spacing: 10) {
            Callout("Saved successfully.", type: .success)
            Callout("Please review your details.", type: .warning, style: .soft)
            Callout("Something went wrong.", type: .error, style: .soft)
        }.frame(width: 320))
        shot("Card", Card(elevation: .soft, title: "Rezervasyon", subtitle: "2 gece · 2 misafir", extraTitle: "Detay", onExtra: {}) {
            Text("Hilton İstanbul Bomonti — Deluxe oda, kahvaltı dahil.")
                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
        }.frame(width: 320))
        shot("ChatBubble", VStack(alignment: .leading, spacing: 8) {
            ChatBubble("Merhaba! Rezervasyonunuz onaylandı.", side: .incoming, author: "Destek", time: "09:24")
            ChatBubble("Teşekkürler!", side: .outgoing, time: "09:25")
        }.frame(width: 320))
        shot("Counter", Counter(days: 2, hours: 8, minutes: 45))
        shot("Coupon", Coupon(code: "UXMUQ", style: .outlined).frame(width: 300))
        shot("EmptyState", EmptyState(systemImage: "magnifyingglass", title: "No results found",
                                      message: "Try adjusting your search or filters.",
                                      buttonTitle: "Clear filters", action: {},
                                      secondaryTitle: "Learn more", onSecondary: {}).frame(width: 320))
        shot("InfoBanner", InfoBanner("Rezervasyonun onaylandı. Detaylar için bilet sayfasına git.",
                                      type: .info, title: "Heads up").frame(width: 340))
        shot("KeyValueTable", KeyValueTable(rows: [.init("Status", value: "Aktif", style: .success),
                                                   .init("Old price", value: "5.000 TL", style: .strikethrough),
                                                   .init("Total", value: "4.250 TL")],
                                            title: "Rezervasyon özeti", bordered: true).frame(width: 320))
        shot("ListRow", VStack(spacing: 0) {
            ListRow("Hesabım", subtitle: "Profil ve güvenlik", leadingSystemImage: "person.circle", action: {})
            DividerView(size: .small)
            ListRow("Bildirimler", subtitle: "E-posta ve push", leadingSystemImage: "bell", action: {})
        }.frame(width: 320))
        shot("NotificationCard", NotificationCard(title: "Tatilinle İlgili Bir Önerimiz Var",
                                                  message: "Hilton İstanbul rezervasyonuna 24 gün kaldı.",
                                                  date: "5 Aralık 2024", isUnread: true, type: .success).frame(width: 340))
        shot("PageHeader", PageHeader("Search results", subtitle: "128 hotels",
                                      tags: [.init("Aktif", style: .success)], onBack: {}).frame(width: 340))
        shot("RatingSummary", RatingSummary(score: 9.0, label: "Mükemmel", reviewCount: 1200).frame(width: 300))
        shot("ResultView", ResultView(.notFound, title: "Sayfa bulunamadı",
                                      message: "Aradığınız sayfa taşınmış olabilir.",
                                      primaryTitle: "Ana sayfa", onPrimary: {}).frame(width: 320))
        shot("SegmentedTabBar", SegmentedTabBar([TabItem("Genel"), TabItem("Yorumlar", badge: "12"),
                                                 TabItem("Konum")], selection: .constant(1)).frame(width: 340))
        shot("Timeline", Timeline([.init(title: "Sipariş alındı", time: "09:24", systemImage: "cart", state: .done, color: .success),
                                   .init(title: "Hazırlanıyor", time: "09:40", systemImage: "shippingbox", state: .active),
                                   .init(title: "Yolda", state: .todo)], pending: "Kurye bekleniyor…").frame(width: 320))
        shot("Upload", Upload(prompt: "En fazla 3 fotoğraf yükleyebilirsin.", buttonTitle: "Fotoğraf ekle",
                              files: [.init(name: "room-1.jpg", status: .done),
                                      .init(name: "room-2.jpg", status: .uploading(0.6))], maxCount: 3,
                              onPick: {}, onRemove: { _ in }).frame(width: 320))
        shot("PromoBanner", PromoBanner(title: "Early booking", subtitle: "Save up to 30% on summer",
                                        systemImage: "sun.max.fill", ctaTitle: "Explore", action: {}).frame(width: 340))
    }

    // MARK: Render

    private func shot(_ name: String, _ view: some View) {
        let renderer = ImageRenderer(content:
            view
                .padding(16)
                .background(Theme.shared.background(.bgWhite))
        )
        renderer.scale = 2
        guard let cg = renderer.cgImage else { XCTFail("\(name): no image"); return }
        let url = outDir.appendingPathComponent("\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            XCTFail("\(name): no PNG destination"); return
        }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        manifest.append((category, name))
    }
}
#endif
