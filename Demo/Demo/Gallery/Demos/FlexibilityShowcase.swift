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
                            .icon("magnifyingglass")
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
                            TextInput("Search destination", text: $email).icon("magnifyingglass")
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
                            .footer { AmenityGrid([Amenity("Free Wi-Fi", systemImage: "wifi"), Amenity("Pool", systemImage: "figure.pool.swim")]).columns(2) }
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
