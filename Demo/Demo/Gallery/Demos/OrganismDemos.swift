//
//  OrganismDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Interactive demo pages + small stateful previews for organism components.
//

import SwiftUI
import ThemeKit

struct AccordionDemo: View {
    @State private var expanded = true
    @State private var number = false
    @State private var indicatorIdx = 0   // 0 chevron, 1 plusMinus
    @State private var sizeIdx = 1        // 0 large, 1 medium, 2 small

    private var indicator: AccordionIndicator { indicatorIdx == 1 ? .plusMinus : .chevron }
    private var titleSize: AccordionTitleSize { sizeIdx == 0 ? .large : sizeIdx == 2 ? .small : .medium }
    private var paddingSize: AccordionPaddingSize { sizeIdx == 0 ? .large : sizeIdx == 2 ? .small : .default }

    var body: some View {
        ComponentStage("Accordion", inspector: [("titleSize", sizeIdx == 0 ? "large" : sizeIdx == 2 ? "small" : "medium"), ("indicator", indicatorIdx == 1 ? "plusMinus" : "chevron")]) {
            Accordion("İade politikanız nedir?",
                      number: number ? 1 : nil,
                      indicator: indicator,
                      titleSize: titleSize, paddingSize: paddingSize,
                      initiallyExpanded: expanded) {
                Text("Satın alımdan sonraki 14 gün içinde iade talep edebilirsiniz.")
            }
            .id("\(expanded)\(number)\(indicatorIdx)\(sizeIdx)")
        } knobs: {
            Toggle("Initially expanded", isOn: $expanded)
            Toggle("Leading number (01)", isOn: $number)
            Picker("Title/padding size", selection: $sizeIdx) { Text("L").tag(0); Text("M").tag(1); Text("S").tag(2) }.pickerStyle(.segmented)
            Picker("Indicator", selection: $indicatorIdx) { Text("Chevron").tag(0); Text("+/−").tag(1) }.pickerStyle(.segmented)
        }
    }
}

struct CalloutDemo: View {
    @State private var type: CalloutType = .success
    @State private var soft = false

    var body: some View {
        ComponentStage("Callout", inspector: [("type", "\(type)"), ("style", soft ? "soft" : "plain")]) {
            Callout("Lorem ipsum placeholder text.", type: type, style: soft ? .soft : .plain)
        } knobs: {
            Picker("Type", selection: $type) {
                Text("Neutral").tag(CalloutType.neutral); Text("Info").tag(CalloutType.info); Text("Success").tag(CalloutType.success); Text("Warning").tag(CalloutType.warning); Text("Error").tag(CalloutType.error)
            }
            Toggle("Soft surface", isOn: $soft)
        }
    }
}

struct AlertToastDemo: View {
    @State private var type: AlertToastType = .success
    @State private var message = false
    @State private var closable = true

    var body: some View {
        ComponentStage("AlertToast", inspector: [("type", "\(type)")]) {
            AlertToast("Saved successfully", message: message ? "Your changes were stored." : nil, type: type, onClose: closable ? { flash("AlertToast kapatıldı") } : nil)
        } knobs: {
            Picker("Type", selection: $type) {
                Text("Success").tag(AlertToastType.success); Text("Warning").tag(AlertToastType.warning); Text("Danger").tag(AlertToastType.danger); Text("Info").tag(AlertToastType.info)
            }
            Toggle("Message", isOn: $message)
            Toggle("Closable", isOn: $closable)
        }
    }
}

struct InfoBannerDemo: View {
    @State private var type: InfoBannerType = .info
    @State private var title = true
    @State private var dismissable = false
    @State private var showIcon = true
    @State private var banner = false
    @State private var action = false
    @State private var inlineLink = false
    @State private var tapped = 0

    private var message: String {
        inlineLink ? "Rezervasyonun onaylandı. Detaylar için bilet sayfasına git." : "This is an informational message."
    }
    private var links: [(substring: String, action: () -> Void)] {
        inlineLink ? [("bilet sayfasına", { tapped += 1 })] : []
    }

    var body: some View {
        ComponentStage("InfoBanner", inspector: [("type", "\(type)"), ("linkTaps", "\(tapped)")]) {
            InfoBanner(message, type: type, title: title ? "Heads up" : nil, links: links,
                       showIcon: showIcon, banner: banner,
                       actionTitle: action ? "Undo" : nil, onAction: action ? { flash("InfoBanner: Undo") } : nil,
                       onDismiss: dismissable ? { flash("InfoBanner kapatıldı") } : nil)
        } knobs: {
            Picker("Type", selection: $type) {
                Text("Neutral").tag(InfoBannerType.neutral); Text("Info").tag(InfoBannerType.info); Text("Success").tag(InfoBannerType.success); Text("Warning").tag(InfoBannerType.warning); Text("Error").tag(InfoBannerType.error)
            }
            Toggle("Inline tappable link", isOn: $inlineLink)
            Toggle("Title", isOn: $title)
            Toggle("Show icon", isOn: $showIcon)
            Toggle("Banner mode", isOn: $banner)
            Toggle("Action button", isOn: $action)
            Toggle("Dismissable", isOn: $dismissable)
        }
    }
}

struct CounterDemo: View {
    @State private var days = 2
    @State private var hours = 8
    @State private var minutes = 45

    var body: some View {
        ComponentStage("Counter", inspector: [("days", "\(days)"), ("hours", "\(hours)"), ("minutes", "\(minutes)")]) {
            Counter(days: days, hours: hours, minutes: minutes)
        } knobs: {
            Stepper("Days: \(days)", value: $days, in: 0...30)
            Stepper("Hours: \(hours)", value: $hours, in: 0...23)
            Stepper("Minutes: \(minutes)", value: $minutes, in: 0...59)
        }
    }
}

struct CouponDemo: View {
    @State private var code = "UXMUQ"
    @State private var style: CouponStyle = .outlined

    var body: some View {
        ComponentStage("Coupon", inspector: [("style", "\(style)")]) {
            Coupon(code: code, style: style)
        } knobs: {
            TextField("Code", text: $code).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $style) {
                Text("Filled").tag(CouponStyle.filled); Text("Outlined").tag(CouponStyle.outlined); Text("Plain").tag(CouponStyle.plain)
            }.pickerStyle(.segmented)
        }
    }
}

struct PromoBannerDemo: View {
    @State private var tint: PromoBannerTint = .blue
    @State private var cta = true

    var body: some View {
        ComponentStage("PromoBanner", inspector: [("tint", "\(tint)")]) {
            PromoBanner(title: "Early booking", subtitle: "Save up to 30% on summer",
                        systemImage: "sun.max.fill", ctaTitle: cta ? "Explore" : nil, tint: tint, action: cta ? { flash("PromoBanner CTA") } : nil)
        } knobs: {
            Picker("Tint", selection: $tint) {
                Text("Blue").tag(PromoBannerTint.blue); Text("Dark").tag(PromoBannerTint.dark); Text("Turquoise").tag(PromoBannerTint.turquoise)
            }.pickerStyle(.segmented)
            Toggle("CTA button", isOn: $cta)
        }
    }
}

struct NavigationBarDemo: View {
    @State private var selection = 1

    var body: some View {
        ComponentStage("NavigationBar", inspector: [("selection", "\(selection)")]) {
            NavigationBar(items: [
                .init(systemImage: "house"), .init(systemImage: "heart"), .init(systemImage: "bag"), .init(systemImage: "person"),
            ], selection: $selection)
        } knobs: {
            Stepper("Selection: \(selection)", value: $selection, in: 0...3)
        }
    }
}

struct SegmentedTabBarDemo: View {
    @State private var selection = 0
    @State private var scrollable = false
    @State private var rich = true
    @State private var captions = false
    @State private var card = false
    @State private var editable = false
    @State private var cardTabs = ["Sekme 1", "Sekme 2", "Sekme 3"]
    @State private var nextTab = 4

    var body: some View {
        ComponentStage("SegmentedTabBar", inspector: [("selection", "\(selection)"), ("style", card ? "card" : "underline")]) {
            if card {
                SegmentedTabBar(cardTabs.map { TabItem($0) }, selection: $selection, style: .card,
                                onClose: editable ? { idx in
                                    cardTabs.remove(at: idx)
                                    if selection >= cardTabs.count { selection = max(0, cardTabs.count - 1) }
                                    flash("Sekme kapatıldı")
                                } : nil,
                                onAdd: editable ? {
                                    cardTabs.append("Sekme \(nextTab)"); nextTab += 1; selection = cardTabs.count - 1
                                    flash("Sekme eklendi")
                                } : nil)
            } else if captions && !scrollable {
                SegmentedTabBar([TabItem("Ekonomi", caption: "₺2.450", systemImage: "airplane"),
                                 TabItem("Business", caption: "₺6.900", trailingSystemImage: "star.fill"),
                                 TabItem("First", caption: "Dolu", isEnabled: false)], selection: $selection)
            } else if rich && !scrollable {
                SegmentedTabBar([TabItem("Overview", systemImage: "square.grid.2x2"),
                                 TabItem("Reviews", badge: "12"),
                                 TabItem("Archived", isEnabled: false)], selection: $selection)
            } else {
                SegmentedTabBar(scrollable ? ["All", "Flights", "Hotels", "Cars", "Tours"] : ["Overview", "Details", "Reviews"], selection: $selection, scrollable: scrollable)
            }
        } knobs: {
            Toggle("Card style", isOn: $card)
            if card { Toggle("Editable (close + add)", isOn: $editable) }
            Toggle("Icons + badge + disabled", isOn: $rich)
            Toggle("Captions + trailing icon", isOn: $captions)
            Toggle("Scrollable", isOn: $scrollable)
        }
    }
}

struct SelectionCardsDemo: View {
    @State private var useCheckbox = false
    @State private var checked = true
    @State private var radio = "std"

    var body: some View {
        ComponentStage("SelectionCards", inspector: [("kind", useCheckbox ? "checkbox" : "radio")]) {
            if useCheckbox {
                CheckboxCard("Add checked bag", description: "+₺250", isChecked: checked) { checked.toggle(); flash("CheckboxCard: \(checked ? "seçildi" : "kaldırıldı")") }
            } else {
                VStack(spacing: 12) {
                    RadioCard("Standard", description: "Free delivery in 3–5 days", isSelected: radio == "std") { radio = "std"; flash("RadioCard: Standard") }
                    RadioCard("Express", description: "Next-day delivery", isSelected: radio == "exp") { radio = "exp"; flash("RadioCard: Express") }
                }
            }
        } knobs: {
            Toggle("Checkbox variant", isOn: $useCheckbox)
        }
    }
}

// MARK: - Static previews

struct CarouselDemo: View {
    private struct Slide: Identifiable { let id = UUID(); let color: Color; let title: String }
    private let slides = [Slide(color: .blue, title: "Flights"), Slide(color: .teal, title: "Hotels"), Slide(color: .orange, title: "Tours")]
    @State private var autoplay = false
    @State private var arrows = true
    @State private var loop = true
    @State private var fade = false
    @State private var dotsTop = false
    @State private var page = 0

    var body: some View {
        ComponentStage("Carousel", inspector: [("currentIndex", "\(page)"), ("effect", fade ? "fade" : "slide")]) {
            VStack(spacing: 12) {
                Carousel(slides, autoplay: autoplay ? 2 : nil, showsArrows: arrows, loop: loop,
                         fade: fade, dotPosition: dotsTop ? .top : .bottom, currentIndex: $page) { s in
                    RoundedRectangle(cornerRadius: 16).fill(s.color.opacity(0.25)).overlay(Text(s.title).textStyle(.headingSm))
                }
                .frame(height: 160)
                Text("Page \(page + 1) / \(slides.count)").textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textSecondary))
            }
        } knobs: {
            Toggle("Fade effect", isOn: $fade)
            Toggle("Dots on top", isOn: $dotsTop)
            Toggle("Infinite loop", isOn: $loop)
            Toggle("Autoplay (2s)", isOn: $autoplay)
            Toggle("Arrows", isOn: $arrows)
            Stepper("Jump to page \(page + 1)", value: $page, in: 0...(slides.count - 1))
        }
    }
}
