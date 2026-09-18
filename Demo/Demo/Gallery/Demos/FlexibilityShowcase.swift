//
//  FlexibilityShowcase.swift
//  Demo
//
//  Wave-1 proof for the flexibility architecture: each pilot component is shown
//  three ways — default, slots filled, and re-skinned through a CUSTOM style
//  defined HERE in the demo target. If the library can look this different
//  without being forked, the slot + config + style API is doing its job.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

// MARK: - Page

struct FlexibilityShowcaseDemo: View {
    @Environment(\.theme) private var theme

    @State private var chipA = true
    @State private var chipB = false
    @State private var email = ""
    @State private var amount = ""
    @State private var progress = 0.62
    @State private var when: Date? = nil
    @State private var otp = ""
    @State private var tab = 0
    @State private var radioOn = true
    @State private var plainTip = true
    @State private var cardTip = true
    @State private var styledTab = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro

                section("ListRow — ListRowStyle") {
                    labeled("Default") {
                        ListRow("Mirage Park Resort") { }.subtitle("Kemer · Antalya")
                    }
                    labeled("Slots (.leading / .trailing)") {
                        ListRow("Mirage Park Resort") { }
                            .subtitle("Kemer · Antalya")
                            .leading { IconTile("building.2.fill").size(40).accent(.turquoise) }
                            .trailing { Badge("-20%").variant(.solid).badgeStyle(.success) }
                    }
                    labeled("Custom style (TimelineRowStyle — demo-defined)") {
                        VStack(spacing: 0) {
                            ListRow("Check-in") { }.subtitle("15:00 · reception")
                            ListRow("Spa reservation") { }.subtitle("17:30 · level -1")
                        }
                        .listRowStyle(TimelineRowStyle())
                    }
                }

                section("TextInput — FieldStyle") {
                    labeled("Default") {
                        TextInput("Email", text: $email).placeholder("you@example.com")
                    }
                    labeled("Slots (.leading / .trailing) + .underlined") {
                        TextInput("Amount", text: $amount)
                            .leading { Text("$").foregroundStyle(theme.text(.textTertiary)) }
                            .trailing { Text("USD").font(.caption).foregroundStyle(theme.text(.textTertiary)) }
                            .fieldStyle(.underlined)
                    }
                    labeled("Custom style (PillFieldStyle — demo-defined)") {
                        TextInput("Search destination", text: $email)
                            .icon(leading:"magnifyingglass")
                            .fieldStyle(PillFieldStyle())
                    }
                }

                section("Chip — ChipStyle") {
                    labeled("Default (tonal / solid built-ins)") {
                        HStack {
                            Chip("Tonal", isSelected: $chipA)
                            Chip("Solid", isSelected: $chipB).chipStyle(.solid)
                        }
                    }
                    labeled("Slots (.leading / .trailing)") {
                        Chip("Wi-Fi", isSelected: $chipA)
                            .leading { Image(systemName: "wifi").font(.system(size: 12)) }
                            .trailing { Text("·  124").font(.caption2) }
                    }
                    labeled("Custom style (OutlineChipStyle — demo-defined)") {
                        HStack {
                            Chip("Beachfront", isSelected: $chipA)
                            Chip("Pet friendly", isSelected: $chipB)
                        }
                        .chipStyle(OutlineChipStyle())
                    }
                }

                chromeStylesSection

                section("SheetHeader — BarStyle") {
                    labeled("Default") {
                        SheetHeader("Passenger details").subtitle("Step 2 of 4").progress(0.5).onClose { }
                    }
                    labeled("Slot (.leading) + .floating") {
                        SheetHeader("Filters")
                            .leading { Badge("12").variant(.solid) }
                            .onClose { }
                            .barStyle(.floating)
                    }
                    labeled("Custom style (AccentEdgeBarStyle — demo-defined)") {
                        SheetHeader("Payment").subtitle("Secured with 3-D Secure").onBack { }
                            .barStyle(AccentEdgeBarStyle())
                    }
                }

                section("ProgressBar — MeterStyle") {
                    labeled("Default (linear)") {
                        ProgressBar(value: progress).showsPercentage()
                    }
                    labeled("Built-in alternate (.striped) + steps") {
                        VStack(spacing: 12) {
                            ProgressBar(value: progress).meterStyle(.striped)
                            ProgressBar(value: progress).steps(8).meterStyle(.striped)
                        }
                    }
                    labeled("Custom style (TickMeterStyle — demo-defined)") {
                        ProgressBar(value: progress).showsPercentage().meterStyle(TickMeterStyle())
                    }
                }

                section("Chips, bars & meters (Wave 4)") {
                    labeled("Rich chips through a custom style (.solid)") {
                        HStack(spacing: 12) {
                            CompactChip("Standard", price: "$399", isSelected: $chipA)
                            CompactChip("Suite", price: "$899", isSelected: $chipB)
                        }
                        .chipStyle(.solid)
                    }
                    labeled("NavigationBar — .item{} slot + .floating bar") {
                        NavigationBar(items: [
                            .init(systemImage: "house", label: "Home"),
                            .init(systemImage: "heart", label: "Saved"),
                            .init(systemImage: "person", label: "Profile"),
                        ], selection: $tab)
                        .item { item, isActive in
                            VStack(spacing: 4) {
                                Image(systemName: item.systemImage)
                                if let label = item.label { Text(label).font(.caption2) }
                            }
                            .opacity(isActive ? 1 : 0.45)
                        }
                        .barStyle(.floating)
                    }
                    labeled("RadialProgress — default ring vs custom meter") {
                        HStack(spacing: 24) {
                            RadialProgress(progress).showsLabel()
                            RadialProgress(progress).showsLabel().meterStyle(TickMeterStyle())
                        }
                    }
                }

                section("Form family — FieldStyle (Wave 3)") {
                    labeled("Every field reads the ambient style") {
                        VStack(spacing: 12) {
                            TextInput("Email", text: $email).placeholder("you@example.com")
                            DateField("Departure", date: $when)
                            OTPInput(code: $otp)
                        }
                    }
                    labeled("Built-in .underlined across the family") {
                        VStack(spacing: 12) {
                            TextInput("Email", text: $email)
                            DateField("Departure", date: $when)
                        }
                        .fieldStyle(.underlined)
                    }
                    labeled("One custom style, whole form (PillFieldStyle)") {
                        VStack(spacing: 12) {
                            TextInput("Search destination", text: $email).icon(leading: "magnifyingglass")
                            DateField("Departure", date: $when)
                        }
                        .fieldStyle(PillFieldStyle())
                    }
                }

                section("Card family — CardStyle (Wave 2)") {
                    labeled("isSelected flows through the style") {
                        HStack(spacing: 12) {
                            RadioCard("Round trip", isSelected: true) { }
                            CheckboxCard("Add baggage", isChecked: true) { }
                        }
                    }
                    labeled("Slot (.leading) — NotificationCard") {
                        NotificationCard(title: "Price dropped 8%")
                            .message("IST → AYT is now ₺3.538")
                            .leading { Avatar(.initials("TK")).size(.sm) }
                    }
                    labeled("One custom style reskins the whole family (PosterCardStyle)") {
                        VStack(spacing: 12) {
                            FareFamilyCard("Extra Fly", price: 4_250).selected()
                            NotificationCard(title: "Gate changed").message("New gate: B7")
                        }
                        .cardStyle(PosterCardStyle())
                    }
                }

                section("HotelResultCard — CardStyle") {
                    labeled("Default") {
                        HotelResultCard(name: "Mirage Park Resort")
                            .location("Kemer, Antalya")
                            .score(8.9, reviews: 1_284)
                            .price(9_600)
                    }
                    labeled("Slots (.media / .overlay / .footer)") {
                        HotelResultCard(name: "Mirage Park Resort")
                            .location("Kemer, Antalya")
                            .score(8.9, reviews: 1_284)
                            .price(9_600)
                            .media {
                                LinearGradient(colors: [SemanticColor.info.base, SemanticColor.turquoise.base],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .frame(height: 140)
                            }
                            .overlay { Ribbon("Last 2 rooms") { Color.clear.frame(height: 140) } }
                            .footer { AmenityGrid([ThemeKit.Amenity("Free Wi-Fi", systemImage: "wifi"), ThemeKit.Amenity("Pool", systemImage: "figure.pool.swim")]).columns(2) }
                    }
                    labeled("Custom style (PosterCardStyle — demo-defined)") {
                        HotelResultCard(name: "Mirage Park Resort")
                            .location("Kemer, Antalya")
                            .score(8.9)
                            .price(9_600)
                            .cardStyle(PosterCardStyle())
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flexibility Showcase")
    }

    /// Consumer chrome styles (ADR-0009): each component keeps its behaviour and
    /// content; a demo-defined style draws the chrome. Built-in look on the left
    /// (or first), the custom chrome next to it.
    private var chromeStylesSection: some View {
        section("Consumer chrome styles") {
            labeled("ThemeButton — ButtonChromeStyle (+ .label / .loadingIndicator slots)") {
                VStack(spacing: 12) {
                    HStack {
                        ThemeButton("Built-in") {}.variant(.soft)
                        ThemeButton("Continue") {}.icon(trailing: "arrow.right")
                            .buttonChromeStyle(DemoPillButtonChrome())
                    }
                    HStack {
                        ThemeButton("Pay 42.00") {}
                            .label { Text("Pay \(Text("42.00").bold())") }
                            .spacing(.sm)
                            .buttonChromeStyle(DemoPillButtonChrome())
                        ThemeButton("Saving") {}
                            .loading().spinnerPlacement(.leading)
                            .loadingIndicator { Spinner().style(.dots).controlSize(.small) }
                            .buttonChromeStyle(DemoPillButtonChrome())
                    }
                }
            }
            labeled("Badge — BadgeChromeStyle (+ .leading slot)") {
                HStack {
                    Badge("Built-in").badgeStyle(.info).icon("tag.fill")
                    Badge("Custom").badgeStyle(.info)
                        .leading { Circle().frame(width: 6, height: 6) }
                        .badgeChromeStyle(DemoTagBadgeChrome())
                    Badge("Tap", action: {}).badgeStyle(.success)
                        .trailing { Image(systemName: "chevron.right") }
                        .badgeChromeStyle(DemoTagBadgeChrome())
                }
            }
            labeled("CountBadge — CountBadgeStyle") {
                HStack(spacing: 16) {
                    CountBadge(7)
                    CountBadge("+1").accent(.primary)
                    Group {
                        CountBadge(128)
                        CountBadge { Image(systemName: "checkmark") }.accent(.success)
                        Image(systemName: "bell.fill").font(.title2).countBadge(3).padding(.trailing, 8)
                    }
                    .countBadgeStyle(DemoSquareCountBadgeStyle())
                }
            }
            labeled("IconTile — IconTileStyle (+ glyph init, .tileShape)") {
                HStack {
                    IconTile("airplane")
                    IconTile("heart.fill").accent(.pink).tileShape(.circle)
                    IconTile { Text("A").textStyle(.labelBase700) }.accent(.info).tileShape(.circle)
                    IconTile("bell.fill").accent(.success).size(32)
                        .iconTileStyle(DemoRingIconTileStyle())
                }
            }
            labeled("PriceTag — PriceTagStyle (+ verbatim text)") {
                HStack(alignment: .top, spacing: 24) {
                    PriceTag(verbatim: "EUR 1.299").original(verbatim: "EUR 1.899").discountBadge("-15%")
                    PriceTag(verbatim: "EUR 1.299").prefix("Total").original(verbatim: "EUR 1.899").discountBadge("-15%")
                        .priceTagStyle(DemoStackedPriceTagStyle())
                }
            }
            labeled("RadioButton — RadioButtonChromeStyle (+ .description)") {
                VStack(alignment: .leading, spacing: 8) {
                    RadioButton("Built-in", isSelected: $radioOn).description("Pay at the property.")
                    RadioButton("Card row", isSelected: $radioOn).description("Pay now, cancel for free.")
                        .radioButtonChromeStyle(DemoCardRadioChrome())
                    RadioButton("Unavailable", isSelected: .constant(false)).disabled(true)
                        .radioButtonChromeStyle(DemoCardRadioChrome())
                }
            }
            labeled("Skeleton — SkeletonStyle") {
                HStack(spacing: 12) {
                    Skeleton(.capsule).size(width: 90, height: 12)
                    Skeleton(.capsule).size(width: 90, height: 12)
                        .skeletonStyle(DemoTintSkeletonStyle())
                    Skeleton(.circle).size(width: 28, height: 28)
                        .skeletonStyle(DemoTintSkeletonStyle())
                }
            }
            labeled("DividerView — DividerStyle") {
                VStack(spacing: 12) {
                    DividerView("OR")
                    DividerView("OR").dividerStyle(DemoAccentDividerStyle())
                    DividerView().dashed().dividerStyle(DemoAccentDividerStyle())
                }
            }
            labeled("Callout — CalloutChromeStyle (+ .statusLabel / .fullWidth)") {
                VStack(alignment: .leading, spacing: 8) {
                    Callout("Prices may change until you book.").variant(.warning).calloutStyle(.soft)
                    Callout("Prices may change until you book.").variant(.warning)
                        .action("Details") {}
                        .statusLabel("Warning")
                        .fullWidth()
                        .calloutChromeStyle(DemoBorderedCalloutChrome())
                }
            }
            labeled("InlineText — InlineTextStyle (+ .leading / .trailing)") {
                VStack(alignment: .leading, spacing: 8) {
                    InlineText("Read the guidelines before publishing.", links: [("guidelines", {})])
                        .leading { Image(systemName: "book") }
                    InlineText("Read the guidelines before publishing.", links: [("guidelines", {})])
                        .leading { Image(systemName: "book") }
                        .trailing { Badge("New").badgeStyle(.success).size(.small) }
                        .inlineTextStyle(DemoBodyInlineTextStyle())
                }
            }
            labeled("Tooltip — TooltipStyle (+ TooltipArrowShape, dismiss)") {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle").font(.title3)
                        .foregroundStyle(theme.foreground(.fgHero))
                        .tooltip("Built-in bubble", isPresented: $plainTip)
                        .onTapGesture { plainTip.toggle() }
                        .frame(maxWidth: .infinity)
                    Image(systemName: "suitcase.rolling").font(.title3)
                        .foregroundStyle(theme.foreground(.fgHero))
                        .tooltip(isPresented: $cardTip, maxWidth: 200) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Baggage allowance").fontWeight(.semibold)
                                Text("One cabin bag up to 8 kg is included.")
                            }
                        }
                        .tooltipStyle(DemoCardTooltipStyle())
                        .onTapGesture { cardTip.toggle() }
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 112)
            }
            labeled("Title — TitleStyle (+ .leading slot, heading semantics)") {
                VStack(alignment: .leading, spacing: 12) {
                    Title("Popular destinations")
                        .subtitle("Where travellers go next")
                        .action("See all", action: {})
                    Title("Popular destinations")
                        .eyebrow("This week")
                        .subtitle("Where travellers go next")
                        .leading { Image(systemName: "sparkles") }
                        .action("See all", action: {})
                        .titleStyle(DemoBoxedTitleStyle())
                }
            }
            labeled("SegmentedTabBar — SegmentedTabBarChromeStyle (+ TabItem.leading, fillsWidth, baseline)") {
                VStack(alignment: .leading, spacing: 16) {
                    SegmentedTabBar(["Flights", "Hotels", "Cars"], selection: $styledTab)
                    SegmentedTabBar([TabItem("Flights").leading { Image(systemName: "airplane") },
                                     TabItem("Hotels", badge: "12").leading { Image(systemName: "bed.double.fill") },
                                     TabItem("Cars").leading { Image(systemName: "car.fill") }],
                                    selection: $styledTab)
                        .fillsWidth(false)
                        .baseline()
                        .segmentedTabBarChromeStyle(DemoSlidingBarTabChrome())
                }
            }
            labeled("SheetHeader — SheetHeaderStyle (wired back/close, unpainted)") {
                VStack(alignment: .leading, spacing: 12) {
                    SheetHeader("Passengers").subtitle("Who is travelling?").onBack {}.onClose {}
                    SheetHeader("Passengers").subtitle("Who is travelling?").onBack {}.onClose {}
                        .sheetHeaderStyle(DemoCornerCloseSheetHeaderStyle())
                }
            }
            labeled("buttonDock — ButtonDockChromeStyle (ThemeKit keeps the pinning)") {
                VStack(alignment: .leading, spacing: 12) {
                    dockCell
                    dockCell.buttonDockChromeStyle(DemoLiftedButtonDockStyle())
                }
            }
        }
    }

    /// A fixed-height page with a docked bar, so the safe-area inset has
    /// something to inset.
    private var dockCell: some View {
        theme.background(.bgSecondaryLight)
            .buttonDock {
                HStack {
                    PriceTag(1249)
                    Spacer(minLength: Theme.SpacingKey.md.value)
                    PrimaryButton("Select") {}
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var intro: some View {
        Text("Every variant below is produced without forking a component — slots for structure, modifiers for configuration, and a Style protocol for full visual override. The custom styles are defined in the demo target, not the library.")
            .font(.footnote)
            .foregroundStyle(theme.text(.textSecondary))
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func labeled<C: View>(_ caption: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.text(.textTertiary))
            content()
        }
    }
}

// MARK: - Custom styles (defined in the DEMO — the fork-free proof)

/// A ListRow chrome that renders rows as a vertical timeline: accent marker +
/// connector line instead of the plain row surface.
private struct TimelineRowStyle: ListRowStyle {
    func makeBody(configuration: ListRowStyleConfiguration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(SemanticColor.primary.base).frame(width: 10, height: 10)
                Rectangle().fill(SemanticColor.primary.bg).frame(width: 2).frame(maxHeight: .infinity)
            }
            .padding(.top, 6)
            HStack(spacing: 8) {
                configuration.content
                if let trailing = configuration.trailing { trailing }
            }
            .padding(.bottom, 18)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A capsule search-pill chrome for text fields.
private struct PillFieldStyle: FieldStyle {
    func makeBody(configuration: FieldStyleConfiguration) -> some View {
        configuration.content
            .background(Theme.shared.background(.bgElevatorTertiary), in: Capsule())
            .overlay(Capsule().strokeBorder(
                configuration.isFocused ? SemanticColor.primary.base : .clear,
                lineWidth: 1.5))
    }
}

/// A transparent, heavy-outline chip that fills with the accent when selected.
private struct OutlineChipStyle: ChipStyle {
    func makeBody(configuration: ChipStyleConfiguration) -> some View {
        configuration.content
            .padding(.horizontal, configuration.size == .large ? 16 : 12)
            .padding(.vertical, configuration.size == .large ? 12 : 8)
            .background(configuration.isSelected ? SemanticColor.primary.bg : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(configuration.isSelected ? SemanticColor.primary.base : SemanticColor.neutral.base.opacity(0.4),
                              lineWidth: 2))
            .opacity(configuration.isEnabled ? 1 : 0.5)
    }
}

/// A header chrome with a thick accent edge instead of a hairline divider.
private struct AccentEdgeBarStyle: BarStyle {
    func makeBody(configuration: BarStyleConfiguration) -> some View {
        HStack(spacing: 12) {
            if let leading = configuration.leading { leading }
            configuration.content
            if let trailing = configuration.trailing { trailing }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(SemanticColor.primary.bg)
        .overlay(alignment: configuration.edge == .top ? .bottom : .top) {
            Rectangle().fill(SemanticColor.primary.base).frame(height: 3)
        }
    }
}

/// An equalizer-tick meter: 24 vertical bars filled up to the fraction.
private struct TickMeterStyle: MeterStyle {
    func makeBody(configuration: MeterStyleConfiguration) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Double(index) / 24.0 < configuration.fraction
                              ? AnyShapeStyle(configuration.fill)
                              : AnyShapeStyle(configuration.track))
                        .frame(height: index % 4 == 0 ? 22 : 14)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24)
            if let label = configuration.label { label }
        }
    }
}

/// A poster-like card shell: oversized continuous radius, gradient frame, deep shadow.
private struct PosterCardStyle: CardStyle {
    func makeBody(configuration: CardStyleConfiguration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return configuration.content
            .background(Theme.shared.background(configuration.surfaceKey), in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [SemanticColor.primary.base, SemanticColor.purple.base],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 2))
            .shadow(color: SemanticColor.primary.base.opacity(0.25), radius: 18, y: 10)
    }
}

// MARK: - Consumer chrome styles (ADR-0009 — defined in the DEMO)
//
// Each style draws only the chrome; the component keeps its behaviour, content
// and accessibility. Colors resolve from the environment theme inside a View, so
// per-subtree `.theme(_:)` and `theme.custom` tokens reach them too.

/// A tall capsule button with a bold title and a pressed shade.
private struct DemoPillButtonChrome: ButtonChromeStyle {
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        DemoPillButtonBody(configuration: configuration)
    }
}

private struct DemoPillButtonBody: View {
    let configuration: ButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let fill = theme.resolve(configuration.color)
        configuration.label
            .textStyle(.labelLg600)
            .foregroundStyle(configuration.isEnabled ? fill.onSolid : theme.text(.textDisabled))
            .tint(fill.onSolid)
            .padding(.horizontal, configuration.isIconOnly ? 0 : Theme.SpacingKey.lg.value)
            .frame(minWidth: configuration.isIconOnly ? 48 : nil, minHeight: 48)
            .frame(maxWidth: configuration.isFullWidth ? .infinity : nil)
            .background(configuration.isPressed ? fill.active : fill.solid, in: Capsule())
            .opacity(configuration.isEnabled ? 1 : 0.5)
            .overlay {
                Capsule().stroke(fill.accent, lineWidth: 2).padding(-3)
                    .opacity(configuration.isFocused ? 1 : 0)
            }
    }
}

/// A squared tag with its own label type; the hue still comes from the badge's tone.
private struct DemoTagBadgeChrome: BadgeChromeStyle {
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        DemoTagBadgeBody(configuration: configuration)
    }
}

private struct DemoTagBadgeBody: View {
    let configuration: BadgeChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let tone = theme.resolve(configuration.tone.semantic)
        HStack(spacing: Theme.SpacingKey.xs.value) {
            configuration.leading
            Text(configuration.text).textStyle(.labelSm700).lineLimit(1)
            configuration.trailing
        }
        .foregroundStyle(configuration.isEnabled ? tone.onSolid : theme.text(.textDisabled))
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .background(configuration.isPressed ? tone.active : tone.solid,
                    in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }
}

/// A rounded-square count tag instead of the stock capsule.
private struct DemoSquareCountBadgeStyle: CountBadgeStyle {
    func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
        DemoSquareCountBadgeBody(configuration: configuration)
    }
}

private struct DemoSquareCountBadgeBody: View {
    let configuration: CountBadgeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let hue = theme.resolve(configuration.accent)
        Group {
            switch configuration.content {
            case .text(let text): Text(text).textStyle(.labelSm700)
            case .glyph(let glyph): glyph.font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(hue.onSolid)
        .padding(.horizontal, Theme.SpacingKey.xs.value)
        .frame(minWidth: 20, minHeight: 20)
        .background(hue.solid, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }
}

/// An outlined disc that honours the requested size.
private struct DemoRingIconTileStyle: IconTileStyle {
    func makeBody(configuration: IconTileStyleConfiguration) -> some View {
        DemoRingIconTileBody(configuration: configuration)
    }
}

private struct DemoRingIconTileBody: View {
    let configuration: IconTileStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let hue = theme.resolve(configuration.accent ?? .primary)
        configuration.glyph
            .font(.system(size: configuration.requestedSize * 0.5))
            .foregroundStyle(hue.base)
            .frame(width: configuration.requestedSize, height: configuration.requestedSize)
            .overlay(Circle().strokeBorder(hue.border, lineWidth: 1.5))
    }
}

/// A trailing-aligned price block: caption, headline price, then original + offer.
private struct DemoStackedPriceTagStyle: PriceTagStyle {
    func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
        DemoStackedPriceTagBody(configuration: configuration)
    }
}

private struct DemoStackedPriceTagBody: View {
    let configuration: PriceTagStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: configuration.spacing(.xs)) {
            if let prefix = configuration.prefix {
                Text(prefix).textStyle(.overline400).foregroundStyle(theme.text(.textSecondary))
            }
            Text(configuration.stateText ?? configuration.price)
                .textStyle(.headingSm)
                .foregroundStyle(theme.foreground(.fgHero))
            HStack(spacing: configuration.spacing(.xs)) {
                if let original = configuration.original {
                    Text(original).strikethrough().textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                }
                if let discount = configuration.discount {
                    Badge(discount).badgeStyle(.success).size(.small)
                }
            }
        }
    }
}

/// A full-width card row: label + description first, the indicator pinned trailing.
private struct DemoCardRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        DemoCardRadioBody(configuration: configuration)
    }
}

private struct DemoCardRadioBody: View {
    let configuration: RadioButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let c = configuration
        let accent = theme.resolve(c.accent ?? .primary)
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
                if let label = c.label {
                    Text(label).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                }
                if let description = c.description {
                    Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            Circle()
                .strokeBorder(c.isSelected ? accent.solid : theme.border(.borderPrimary), lineWidth: c.isSelected ? 6 : 1)
                .frame(width: 20, height: 20)
                .animation(c.animation, value: c.isSelected)
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c.isSelected ? accent.bg : theme.background(.bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                .strokeBorder(c.isSelected ? accent.border : theme.border(.borderPrimary), lineWidth: 1)
        )
        .opacity(c.isEnabled ? (c.isPressed ? 0.8 : 1) : 0.4)
        .contentShape(Rectangle())
    }
}

/// A soft-tinted placeholder that dims instead of sweeping; static when motion is off.
private struct DemoTintSkeletonStyle: SkeletonStyle {
    func makeBody(configuration: SkeletonStyleConfiguration) -> some View {
        DemoTintSkeletonBody(configuration: configuration)
    }
}

private struct DemoTintSkeletonBody: View {
    let configuration: SkeletonStyleConfiguration
    @Environment(\.theme) private var theme
    @State private var dimmed = false

    var body: some View {
        configuration.shape.anyShape
            .fill(theme.resolve(configuration.highlight ?? .info).soft)
            .opacity(dimmed ? 0.5 : 1)
            .onAppear {
                guard configuration.isAnimated else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dimmed = true }
            }
    }
}

/// A 2 pt hero-colored rule with a body-type title.
private struct DemoAccentDividerStyle: DividerStyle {
    func makeBody(configuration: DividerStyleConfiguration) -> some View {
        DemoAccentDividerBody(configuration: configuration)
    }
}

private struct DemoAccentDividerBody: View {
    let configuration: DividerStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        switch configuration.axis {
        case .horizontal:
            HStack(spacing: Theme.SpacingKey.sm.value) {
                rule
                if let title = configuration.title {
                    Text(title).textStyle(.bodySm500).foregroundStyle(theme.foreground(.fgHero)).fixedSize()
                    rule
                }
            }
        case .vertical:
            rule.frame(width: 2).frame(maxHeight: .infinity)
        }
    }

    private var rule: some View {
        DemoRuleShape()
            .stroke(theme.border(.borderHero),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: configuration.isDashed ? [2, 6] : []))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .flipsForRightToLeftLayoutDirection(configuration.isDashed)
    }
}

/// A horizontal line inset by one point so round caps stay inside the frame.
private struct DemoRuleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.midY))
        return path
    }
}

/// A bordered callout with primary body text and a centered row.
private struct DemoBorderedCalloutChrome: CalloutChromeStyle {
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        DemoBorderedCalloutBody(configuration: configuration)
    }
}

private struct DemoBorderedCalloutBody: View {
    let configuration: CalloutChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let tone = theme.resolve(semantic)
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            if let symbol = configuration.leadingSystemImage {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(tone.accent)
                    .accessibilityLabel(configuration.statusLabel ?? "")
            } else {
                configuration.leading
            }
            configuration.content
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(maxWidth: configuration.isFullWidth ? .infinity : nil, alignment: .leading)
            configuration.trailing
            configuration.actionButton.foregroundStyle(tone.accent)
            configuration.closeButton.foregroundStyle(theme.text(.textTertiary))
        }
        .padding(Theme.SpacingKey.md.value)
        .background(tone.bg, in: shape)
        .overlay(shape.strokeBorder(tone.border, lineWidth: 1))
    }

    private var semantic: SemanticColor {
        switch configuration.tone {
        case .neutral: return .neutral
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .accent: return .primary
        }
    }
}

/// Primary body text on one centered row; slot glyphs in the secondary color.
private struct DemoBodyInlineTextStyle: InlineTextStyle {
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        DemoBodyInlineTextBody(configuration: configuration)
    }
}

private struct DemoBodyInlineTextBody: View {
    let configuration: InlineTextStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            configuration.leading
            configuration.content
                .textStyle(.bodyBase500)
                .foregroundStyle(theme.text(.textPrimary))
            configuration.trailing
        }
        .foregroundStyle(theme.text(.textSecondary))
    }
}

/// A section title with a boxed glyph, its own type ramp and a pill action —
/// the wired action keeps ThemeKit's button and takes the demo's type.
private struct DemoBoxedTitleStyle: TitleStyle {
    func makeBody(configuration: TitleStyleConfiguration) -> some View {
        DemoBoxedTitleBody(configuration: configuration)
    }
}

private struct DemoBoxedTitleBody: View {
    let configuration: TitleStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            if let leading = configuration.leading {
                leading
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.foreground(.fgHero))
                    .frame(width: 36, height: 36)
                    .background(theme.resolve(.primary).soft,
                                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                if let eyebrow = configuration.eyebrow {
                    Text(eyebrow.uppercased()).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
                }
                configuration.content.textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                if let subtitle = configuration.subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            configuration.action?
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textHero))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(theme.resolve(.primary).soft, in: Capsule())
        }
    }
}

/// One tab with its own padding and a 3pt selection bar that slides between
/// tabs through the configuration's geometry namespace.
private struct DemoSlidingBarTabChrome: SegmentedTabBarChromeStyle {
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        DemoSlidingBarTabBody(configuration: configuration)
    }
}

private struct DemoSlidingBarTabBody: View {
    let configuration: SegmentedTabBarChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            configuration.leading
            Text(configuration.title)
                .textStyle(configuration.isSelected ? .labelBase700 : .labelBase600)
                .lineLimit(1)
            if let badge = configuration.badge {
                Text(badge)
                    .textStyle(.overline500)
                    .foregroundStyle(theme.resolve(.primary).onSolid)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(theme.resolve(.primary).solid, in: Capsule())
            }
        }
        .foregroundStyle(configuration.isSelected ? theme.text(.textHero) : theme.text(.textSecondary))
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        // An overlay, so the indicator never stretches the tab.
        .overlay(alignment: .bottom) {
            if configuration.isSelected {
                Capsule().fill(theme.resolve(.primary).solid).frame(height: 3)
                    .matchedGeometryEffect(id: configuration.indicatorID, in: configuration.indicatorNamespace)
            }
        }
        .frame(maxWidth: configuration.isStretched ? .infinity : nil)
        .opacity(configuration.isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
        .contentShape(Rectangle())
    }
}

/// A white card with a close button; its arrow is ThemeKit's
/// `TooltipArrowShape`, filled and hairline-stroked, already turned for RTL.
private struct DemoCardTooltipStyle: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DemoCardTooltipBody(configuration: configuration)
    }
}

private struct DemoCardTooltipBody: View {
    let configuration: TooltipStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let surface = theme.background(.bgWhite)
        let stroke = configuration.tint.map { theme.resolve($0).border } ?? theme.border(.borderPrimary)
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)

        let card = HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            configuration.content
                .textStyle(.bodySm400)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let dismiss = configuration.dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.caption.weight(.semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle().inset(by: -12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.text(.textTertiary))
                .accessibilityLabel("Close")
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(width: configuration.maxWidth ?? 240)
        .background(surface, in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

        let vertical = configuration.edge == .top || configuration.edge == .bottom
        let arrow = configuration.arrowShape.fill(surface)
            .overlay(configuration.arrowShape.stroke(stroke, lineWidth: 1))
            .frame(width: vertical ? 16 : 8, height: vertical ? 8 : 16)
            .zIndex(1)

        switch configuration.edge {
        case .top: VStack(spacing: -1) { card; arrow }
        case .bottom: VStack(spacing: -1) { arrow; card }
        case .leading: HStack(spacing: -1) { card; arrow }
        case .trailing: HStack(spacing: -1) { arrow; card }
        }
    }
}

// MARK: - Dock + sheet-header chrome (1.8.0)

/// A docked bar with rounded top corners, a top rule and a lifted shadow. The
/// bottom inset keeps a floor over whatever the home indicator claims —
/// ThemeKit measures it and hands it over, so the style reads no geometry.
private struct DemoLiftedButtonDockStyle: ButtonDockChromeStyle {
    func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
        DemoLiftedButtonDockBody(configuration: configuration)
    }
}

private struct DemoLiftedButtonDockBody: View {
    let configuration: ButtonDockChromeStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: ThemeUnevenRoundedRect {
        ThemeUnevenRoundedRect(topLeadingRadius: Theme.RadiusRole.box.value,
                               topTrailingRadius: Theme.RadiusRole.box.value)
    }

    var body: some View {
        configuration.content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.top, Theme.SpacingKey.md.value)
            .padding(.bottom, max(Theme.SpacingKey.xl.value, configuration.safeAreaBottomInset))
            .background(theme.background(.bgWhite), in: shape)
            .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
            .themeShadow(.elevated)
    }
}

/// A sheet header laid out the host's way: the title on the leading edge after
/// the back arrow, the close button in the corner, the description underneath.
/// Both buttons are ThemeKit's, wired and unpainted — the style sizes and tints
/// their glyphs.
private struct DemoCornerCloseSheetHeaderStyle: SheetHeaderStyle {
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        DemoCornerCloseSheetHeaderBody(configuration: configuration)
    }
}

private struct DemoCornerCloseSheetHeaderBody: View {
    let configuration: SheetHeaderStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
                if let leading = configuration.leading { leading } else {
                    glyph(configuration.backButton, tint: theme.text(.textPrimary))
                }
                configuration.content.textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                Spacer(minLength: Theme.SpacingKey.md.value)
                if let trailing = configuration.trailing { trailing } else {
                    glyph(configuration.closeButton, tint: theme.text(.textSecondary))
                }
            }
            if let subtitle = configuration.subtitle {
                Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.base.value)
        .background(theme.background(.bgWhite))
    }

    @ViewBuilder private func glyph(_ button: AnyView?, tint: Color) -> some View {
        if let button {
            button.font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
        }
    }
}
