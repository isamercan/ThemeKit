//
//  MoreDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Additional interactive demo pages (upgrades of the static registry entries).
//

import SwiftUI
import ThemeKit

// MARK: - Atoms

struct DividerDemo: View {
    @State private var dashed = false
    @State private var withText = true
    @State private var align = 1   // 0 leading, 1 center, 2 trailing

    private var alignment: DividerTextAlign { align == 0 ? .leading : align == 2 ? .trailing : .center }

    var body: some View {
        ComponentStage("Divider", inspector: [("dashed", "\(dashed)"), ("text", withText ? "OR" : "—")]) {
            VStack(spacing: 24) {
                DividerView(dashed: dashed, title: withText ? "OR" : nil, titleAlign: alignment)
                HStack(spacing: 16) {
                    Text("A"); DividerView(axis: .vertical, dashed: dashed); Text("B"); DividerView(axis: .vertical); Text("C")
                }
                .frame(height: 24)
            }
        } knobs: {
            Toggle("Dashed", isOn: $dashed)
            Toggle("Text label", isOn: $withText)
            Picker("Align", selection: $align) { Text("Left").tag(0); Text("Center").tag(1); Text("Right").tag(2) }.pickerStyle(.segmented)
        }
    }
}

struct IconDemo: View {
    @State private var symbol = "star.fill"
    @State private var size: IconSize = .md

    var body: some View {
        ComponentStage("Icon", inspector: [("size", "\(size.rawValue) · \(Int(size.value))")]) {
            Icon(systemName: symbol, size: size, color: Theme.shared.foreground(.fgHero))
        } knobs: {
            TextField("SF Symbol", text: $symbol).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            Picker("Size", selection: $size) { ForEach(IconSize.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }
    }
}

struct InputLabelDemo: View {
    @State private var text = "Email"
    @State private var required = false
    @State private var info = true
    @State private var error = false

    var body: some View {
        ComponentStage("InputLabel", inspector: [("required", "\(required)"), ("hasError", "\(error)")]) {
            InputLabel(text, isRequired: required, hasInfo: info, hasError: error)
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            Toggle("Required", isOn: $required)
            Toggle("Info glyph", isOn: $info)
            Toggle("Error", isOn: $error)
        }
    }
}

struct ScoreBadgeDemo: View {
    @State private var score = 9.0
    @State private var large = false
    var body: some View {
        ComponentStage("ScoreBadge", inspector: [("score", String(format: "%.1f", score))]) {
            ScoreBadge(score, large: large)
        } knobs: {
            HStack { Text("Score"); SwiftUI.Slider(value: $score, in: 0...10, step: 0.1) }
            Toggle("Large", isOn: $large)
        }
    }
}

struct SkeletonDemo: View {
    @State private var loading = true
    @State private var shapes = false
    var body: some View {
        ComponentStage("Skeleton", inspector: [("isLoading", "\(loading)")]) {
            if shapes {
                HStack(spacing: 12) {
                    Skeleton(.circle, width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        Skeleton(.capsule, width: 160, height: 12)
                        Skeleton(.capsule, width: 110, height: 12)
                        Skeleton(.rounded(6), width: 200, height: 12)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Loaded title").font(.title3.bold()).skeleton(loading)
                    Text("A line of body text that loads in.").skeleton(loading)
                    RoundedRectangle(cornerRadius: 12).fill(Theme.shared.background(.bgElevatorTertiary)).frame(height: 80).skeleton(loading, cornerRadius: 12)
                }
            }
        } knobs: {
            Toggle("Loading", isOn: $loading)
            Toggle("Standalone shapes (circle/capsule)", isOn: $shapes)
            Text("Skeleton tokens adapt to the dark theme automatically.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TitleDemo: View {
    @State private var eyebrow = false
    @State private var subtitle = true
    @State private var action = true
    var body: some View {
        ComponentStage("Title") {
            Title("Popular destinations",
                  subtitle: subtitle ? "Where travellers go" : nil,
                  eyebrow: eyebrow ? "Limited time" : nil,
                  actionTitle: action ? "See all" : nil,
                  action: action ? { flash("Title: See all") } : nil)
        } knobs: {
            Toggle("Eyebrow", isOn: $eyebrow)
            Toggle("Subtitle", isOn: $subtitle)
            Toggle("Action", isOn: $action)
        }
    }
}

// MARK: - Molecules

struct SearchBarDemo: View {
    @State private var text = ""
    @State private var back = false
    @State private var trailing = true
    @State private var typeahead = true
    @State private var recent = ["İstanbul", "Bursa"]

    private let cities = ["İstanbul", "İzmir", "İzmit", "Ankara", "Antalya", "Bursa", "Adana"]

    var body: some View {
        ComponentStage("SearchBar", inspector: [("text", "\"\(text)\""), ("suggestions", "\(typeahead)"), ("recent", "\(recent.count)")]) {
            SearchBar(
                text: $text,
                suggestions: typeahead ? cities : [],
                recent: typeahead ? recent : [],
                onSelect: { flash("Selected: \($0)") },
                onSubmit: { flash("Submit: \($0)") },
                onClearRecent: typeahead ? { recent = []; flash("Recent cleared") } : nil
            )
            .backButton(back)
            .trailingIcon(trailing ? "barcode.viewfinder" : nil)
        } knobs: {
            Toggle("Back button", isOn: $back)
            Toggle("Trailing icon", isOn: $trailing)
            Toggle("Suggestions + recent", isOn: $typeahead)
        }
    }
}

struct SelectDemo: View {
    @State private var city: String?
    @State private var clearable = true
    @State private var searchable = false
    @State private var loading = false
    @State private var disableSoldOut = false   // marks "Konya" disabled
    @State private var filled = false

    private var selectView: some View {
        Select("Şehir", sections: [
            .init("Marmara", ["İstanbul", "Bursa", "Kocaeli"]),
            .init("Ege", ["İzmir", "Aydın", "Muğla"]),
            .init("İç Anadolu", ["Ankara", "Konya"]),
        ], selection: $city, allowClear: clearable, searchable: searchable, isLoading: loading,
           isOptionEnabled: disableSoldOut ? { $0 != "Konya" } : nil) { $0 }
    }

    var body: some View {
        ComponentStage("Select", inspector: [("style", filled ? "filled" : "default"), ("selection", city ?? "nil")]) {
            if filled {
                selectView.selectStyle(.filled)   // custom SelectStyle via .selectStyle(_:)
            } else {
                selectView
            }
        } knobs: {
            Toggle("Filled style (.selectStyle)", isOn: $filled)
            Toggle("Searchable (inline panel + sections)", isOn: $searchable)
            Toggle("Allow clear", isOn: $clearable)
            Toggle("Loading (async)", isOn: $loading)
            Toggle("Disable \"Konya\"", isOn: $disableSoldOut)
            Text(searchable ? "Tap → açılır panel: ara, loading & \"No results\" durumları." : "Tap → native Menu (gruplu Section'lar).").font(.caption).foregroundStyle(.secondary)
            Button("Clear") { city = nil }
        }
    }
}

struct MultiSelectDemo: View {
    @State private var picks: Set<String> = ["İstanbul", "Ankara", "İzmir", "Bursa"]
    @State private var searchable = true
    @State private var clearable = true
    @State private var capTags = true
    @State private var enabled = true
    @State private var loading = false
    @State private var disableSoldOut = false   // marks "Adana" disabled
    private let cities = ["İstanbul", "Ankara", "İzmir", "Antalya", "Bursa", "Adana", "Konya"]

    var body: some View {
        ComponentStage("MultiSelect", inspector: [("count", "\(picks.count)"), ("loading", "\(loading)")]) {
            MultiSelect(label: "Cities", options: cities, selection: $picks,
                        searchable: searchable, allowClear: clearable,
                        maxTagCount: capTags ? 2 : nil, isLoading: loading,
                        isOptionEnabled: disableSoldOut ? { $0 != "Adana" } : nil) { $0 }
            .disabled(!enabled)
        } knobs: {
            Toggle("Searchable", isOn: $searchable)
            Toggle("Allow clear", isOn: $clearable)
            Toggle("Max 2 tags (+N)", isOn: $capTags)
            Toggle("Loading (async)", isOn: $loading)
            Toggle("Disable \"Adana\"", isOn: $disableSoldOut)
            Toggle("Enabled", isOn: $enabled)
            Button("Reset") { picks = ["İstanbul", "Ankara", "İzmir", "Bursa"] }
        }
    }
}

struct SelectBoxDemo: View {
    @State private var country: String? = "Türkiye"
    @State private var error = false
    @State private var enabled = true
    var body: some View {
        ComponentStage("SelectBox", inspector: [("selection", country ?? "nil"), ("isEnabled", "\(enabled)")]) {
            SelectBox(label: "Country", options: ["Türkiye", "Germany", "France"], selection: $country,
                      hint: error ? nil : "Pick your country", errorText: error ? "Required" : nil) { $0 }
            .disabled(!enabled)
        } knobs: {
            Toggle("Error state", isOn: $error)
            Toggle("Enabled", isOn: $enabled)
            Button("Clear") { country = nil }
        }
    }
}

struct MultiLineDemo: View {
    @State private var text = ""
    @State private var limit = true
    @State private var error = false
    var body: some View {
        ComponentStage("MultiLineTextInput", inspector: [("count", "\(text.count)")]) {
            MultiLineTextInput("Notes", text: $text, placeholder: "Write something…",
                               characterLimit: limit ? 200 : nil, errorText: error ? "Required" : nil)
        } knobs: {
            Toggle("Character limit", isOn: $limit)
            Toggle("Error state", isOn: $error)
        }
    }
}

struct OTPDemo: View {
    @State private var code = "12"
    @State private var six = false
    @State private var error = false
    @State private var secure = false
    @State private var resend = false
    @State private var lastComplete = "—"
    var body: some View {
        ComponentStage("OTPInput", inspector: [("code", "\"\(code)\""), ("completed", lastComplete)]) {
            OTPInput(
                code: $code,
                digitCount: six ? 6 : 4,
                isSecure: secure,
                errorText: error ? "Invalid code" : nil,
                onComplete: { lastComplete = $0 },
                resendInterval: resend ? 30 : nil,
                onResend: resend ? { lastComplete = "resent" } : nil
            )
        } knobs: {
            Toggle("6 digits", isOn: $six)
            Toggle("Secure entry", isOn: $secure)
            Toggle("Error state", isOn: $error)
            Toggle("Resend timer", isOn: $resend)
        }
    }
}

struct TooltipDemo: View {
    @State private var shown = true
    @State private var edge: TooltipEdge = .top
    @State private var colored = false
    var body: some View {
        ComponentStage("Tooltip", inspector: [("isPresented", "\(shown)"), ("edge", "\(edge)"), ("style", colored ? "info" : "default")]) {
            Icon(systemName: "info.circle", size: .lg, color: Theme.shared.foreground(.fgHero))
                .tooltip("Helpful hint", isPresented: $shown, edge: edge, style: colored ? .info : nil)
                .padding(60)
        } knobs: {
            Toggle("Presented", isOn: $shown)
            Toggle("Colored (info)", isOn: $colored)
            Picker("Edge", selection: $edge) {
                Text("Top").tag(TooltipEdge.top)
                Text("Bottom").tag(TooltipEdge.bottom)
                Text("Leading").tag(TooltipEdge.leading)
                Text("Trailing").tag(TooltipEdge.trailing)
            }.pickerStyle(.segmented)
        }
    }
}

struct ButtonGroupDemo: View {
    @State private var horizontal = false
    var body: some View {
        ComponentStage("ButtonGroup", inspector: [("axis", horizontal ? "horizontal" : "vertical")]) {
            if horizontal {
                ButtonGroup(.horizontal) { SecondaryButton("Cancel") { flash("Cancel") }; PrimaryButton("Confirm") { flash("Confirm") } }
            } else {
                ButtonGroup { PrimaryButton("Continue", block: true) { flash("Continue") }; SecondaryButton("Not now", block: true) { flash("Not now") } }
            }
        } knobs: {
            Toggle("Horizontal", isOn: $horizontal)
        }
    }
}

struct CheckboxGroupDemo: View {
    @State private var sel: Set<String> = ["Wifi"]
    @State private var selectAll = true
    @State private var enabled = true
    @State private var disableParking = false
    private let options = ["Wifi", "Pool", "Parking", "Breakfast"]
    var body: some View {
        ComponentStage("CheckboxGroup", inspector: [("selected", sel.sorted().joined(separator: ", "))]) {
            CheckboxGroup(title: "Amenities", options: options, selection: $sel,
                          selectAllTitle: selectAll ? "Tümünü seç" : nil,
                          isEnabled: enabled,
                          isOptionEnabled: disableParking ? { $0 != "Parking" } : nil) { $0 }
        } knobs: {
            Toggle("Select-all (indeterminate)", isOn: $selectAll)
            Toggle("Enabled (whole group)", isOn: $enabled)
            Toggle("Disable “Parking”", isOn: $disableParking)
            Button("Clear") { sel = [] }
        }
    }
}

struct RadioGroupDemo: View {
    @State private var sel: String? = "Economy"
    @State private var styleIdx = 0   // 0 stacked, 1 button-solid, 2 button-outline
    @State private var enabled = true
    @State private var disableFirst = false
    private var optionEnabled: ((String) -> Bool)? { disableFirst ? { $0 != "First" } : nil }

    var body: some View {
        ComponentStage("RadioGroup", inspector: [("selection", sel ?? "nil"), ("style", styleIdx == 0 ? "stacked" : styleIdx == 1 ? "button/solid" : "button/outline"), ("enabled", "\(enabled)")]) {
            switch styleIdx {
            case 1:
                RadioButtonGroup(options: ["Economy", "Business", "First"], selection: $sel, style: .solid, expandsHorizontally: true, isEnabled: enabled, isOptionEnabled: optionEnabled) { $0 }
            case 2:
                RadioButtonGroup(options: ["Economy", "Business", "First"], selection: $sel, style: .outline, expandsHorizontally: true, isEnabled: enabled, isOptionEnabled: optionEnabled) { $0 }
            default:
                RadioGroup(title: "Class", options: ["Economy", "Business", "First"], selection: $sel, isEnabled: enabled, isOptionEnabled: optionEnabled) { $0 }
            }
        } knobs: {
            Picker("Style", selection: $styleIdx) { Text("Stacked").tag(0); Text("Button solid").tag(1); Text("Button outline").tag(2) }.pickerStyle(.segmented)
            Toggle("Enabled (whole group)", isOn: $enabled)
            Toggle("Disable “First” option", isOn: $disableFirst)
            Button("Clear") { sel = nil }
        }
    }
}

struct ToggleGroupDemo: View {
    @State private var sel: Set<String> = ["push"]
    var body: some View {
        ComponentStage("ToggleGroup", inspector: [("on", sel.sorted().joined(separator: ", "))]) {
            ToggleGroup(title: "Notifications", options: ["push", "email", "sms"], selection: $sel,
                        label: { ["push": "Push", "email": "Email", "sms": "SMS"][$0] ?? $0 },
                        description: { _ in "Supporting text." })
        } knobs: {
            Button("Enable all") { sel = ["push", "email", "sms"] }
        }
    }
}

struct AutocompleteDemo: View {
    @State private var text = ""
    @State private var asyncMode = false
    @State private var disableSoldOut = false
    private let cities = ["İstanbul", "İzmir", "İzmit", "Ankara", "Antalya", "Bursa"]
    private var enabledPredicate: ((String) -> Bool)? {
        disableSoldOut ? { $0 != "İzmit" } : nil
    }
    var body: some View {
        ComponentStage("Autocomplete", inspector: [("text", "\"\(text)\""), ("mode", asyncMode ? "async" : "static"), ("disabled", disableSoldOut ? "İzmit" : "—")]) {
            if asyncMode {
                Autocomplete(label: "Destination", text: $text, suggest: { query in
                    try? await Task.sleep(nanoseconds: 400_000_000)   // simulate network
                    return cities.filter { $0.localizedCaseInsensitiveContains(query) }
                }, isSuggestionEnabled: enabledPredicate)
            } else {
                Autocomplete(label: "Destination", text: $text, suggestions: cities, isSuggestionEnabled: enabledPredicate)
            }
        } knobs: {
            Toggle("Async (remote-style)", isOn: $asyncMode)
            Toggle("Disable “İzmit”", isOn: $disableSoldOut)
            Text("Type to filter suggestions.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Organisms

struct CardDemo: View {
    @State private var elevation: CardElevation = .soft
    @State private var padding = 16.0
    @State private var tappable = false
    @State private var header = true
    @State private var loading = false
    @State private var outlined = false
    @State private var taps = 0

    private var cardBody: some View {
        Card(elevation: elevation, padding: padding,
             title: header ? "Rezervasyon" : nil,
             subtitle: header ? "2 gece · 2 misafir" : nil,
             extraTitle: header ? "Detay" : nil,
             onExtra: header ? { flash("Detay") } : nil,
             isLoading: loading,
             action: tappable ? { taps += 1; flash("Card tıklandı") } : nil) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tappable ? "Tappable card" : "Card body").textStyle(.headingSm)
                Text(tappable ? "Press me — scales with feedback." : "Supporting body text inside a card surface.")
                    .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
            }
        }
    }

    var body: some View {
        ComponentStage("Card", inspector: [("style", outlined ? "outlined" : "default"), ("elevation", "\(elevation)"), ("header", "\(header)")]) {
            if outlined {
                cardBody.cardStyle(.outlined)   // custom CardStyle via the .cardStyle(_:) modifier
            } else {
                cardBody                        // default env CardStyle
            }
        } knobs: {
            Toggle("Outlined style (.cardStyle)", isOn: $outlined)
            Toggle("Header (title + extra)", isOn: $header)
            Toggle("Loading (skeleton)", isOn: $loading)
            Toggle("Tappable (press feedback)", isOn: $tappable)
            Picker("Elevation", selection: $elevation) { Text("None").tag(CardElevation.none); Text("Soft").tag(CardElevation.soft); Text("Elevated").tag(CardElevation.elevated) }.pickerStyle(.segmented)
            HStack { Text("Padding"); SwiftUI.Slider(value: $padding, in: 0...32, step: 4) }
        }
    }
}

struct EmptyStateDemo: View {
    @State private var hasButton = true
    @State private var secondary = false
    @State private var customImage = false
    @State private var tintIcon = false
    @State private var animated = false
    private let gifURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/d3/Newtons_cradle_animation_book_2.gif")
    var body: some View {
        ComponentStage("EmptyState", inspector: [("media", animated ? "gif" : customImage ? "custom" : "symbol")]) {
            if animated {
                EmptyState(animatedURL: gifURL, imageMaxHeight: 140,
                           title: "Yükleniyor", message: "İçerik hazırlanıyor…",
                           buttonTitle: hasButton ? "Yenile" : nil, action: hasButton ? { flash("EmptyState: Yenile") } : nil)
            } else if customImage {
                EmptyState(image: Image(systemName: "sailboat.fill"), imageMaxHeight: 120,
                           title: "Sepetin boş", message: "Henüz bir şey eklemedin.",
                           buttonTitle: hasButton ? "Keşfet" : nil, action: hasButton ? { flash("EmptyState: Keşfet") } : nil)
            } else {
                EmptyState(systemImage: "magnifyingglass",
                           iconForeground: tintIcon ? Theme.shared.foreground(.systemcolorsFgWarning) : nil,
                           iconBackground: tintIcon ? Theme.shared.background(.systemcolorsBgWarningLight) : nil,
                           iconCircleSize: tintIcon ? 104 : 88,
                           title: "No results found",
                           message: "Try adjusting your search or filters.",
                           buttonTitle: hasButton ? "Clear filters" : nil, action: hasButton ? { flash("EmptyState: Clear filters") } : nil,
                           secondaryTitle: secondary ? "Learn more" : nil, onSecondary: secondary ? { flash("EmptyState: Learn more") } : nil)
            }
        } knobs: {
            Toggle("Animated illustration (GIF, native)", isOn: $animated)
            Toggle("Custom illustration", isOn: $customImage)
            Toggle("Tinted + larger icon", isOn: $tintIcon)
            Toggle("Action button", isOn: $hasButton)
            Toggle("Secondary action (symbol)", isOn: $secondary)
        }
    }
}

struct ListRowDemo: View {
    enum Kind: String, CaseIterable { case chevron, value, toggle, checkmark, checkbox, button, price, status, none }
    enum Lead: String, CaseIterable { case icon, image, number, radio, none }
    @State private var kind: Kind = .chevron
    @State private var lead: Lead = .icon
    @State private var on = true
    @State private var agree = false
    @State private var picked = true
    @State private var subtitle = true
    @State private var withMeta = false
    @State private var selected = false
    @State private var moreInfo = false
    @State private var alert = false

    private var trailing: ListRowTrailing {
        switch kind {
        case .chevron: return .chevron
        case .value: return .value("English")
        case .toggle: return .toggle($on)
        case .checkmark: return .checkmark(on)
        case .checkbox: return .checkbox($agree)
        case .button: return .button("Düzenle", action: { flash("ListRow: Düzenle") })
        case .price: return .price(.init(total: "₺14.400", each: "₺1.200", unit: "/ ay"))
        case .status: return .status("Müsait", systemImage: "checkmark.seal.fill")
        case .none: return .none
        }
    }

    private var imageURL: URL? { URL(string: "https://picsum.photos/seed/listrow/120") }
    private var meta: ListRowMeta? { withMeta ? ListRowMeta(rating: 8.4, sentiment: "Mükemmel", commentLabel: "1.284 yorum") : nil }
    private var infos: [ListRowInfo] {
        moreInfo ? [ListRowInfo(systemImage: "checkmark", "Ücretsiz iptal"),
                    ListRowInfo(systemImage: "wifi", "Ücretsiz wifi"),
                    ListRowInfo("Kapıda ödeme yok")] : []
    }

    var body: some View {
        ComponentStage("ListRow", inspector: [("trailing", kind.rawValue), ("leading", lead.rawValue)]) {
            VStack(spacing: 0) {
                ListSectionHeader("Konaklama")
                ListRow("Grand Hotel İstanbul", subtitle: subtitle ? "Deniz manzaralı · Kahvaltı dahil" : nil,
                        number: lead == .number ? 1 : nil,
                        leadingSystemImage: lead == .icon ? "building.2" : nil,
                        leadingImageURL: lead == .image ? imageURL : nil,
                        leadingSelection: lead == .radio ? $picked : nil,
                        alertCount: alert ? 3 : nil,
                        meta: meta, infos: infos, isSelected: selected,
                        multilineTitle: moreInfo,
                        infoAction: kind == .price ? { flash("ListRow: fiyat bilgisi") } : nil,
                        trailing: trailing, action: { flash("ListRow tıklandı") })
            }
        } knobs: {
            Picker("Trailing", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Leading", selection: $lead) { ForEach(Lead.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Toggle("Subtitle", isOn: $subtitle)
            Toggle("More-info list (paragraph items)", isOn: $moreInfo)
            Toggle("Alert count badge (on icon)", isOn: $alert)
            Toggle("Meta line (rating/comment)", isOn: $withMeta)
            Toggle("Selected (active bg)", isOn: $selected)
            Toggle("Toggle / checkmark on", isOn: $on)
        }
    }
}

struct NotificationDemo: View {
    @State private var unread = true
    @State private var actions = true
    @State private var closable = false
    @State private var typed = false
    private var type: FeedbackKind? { typed ? .success : nil }
    var body: some View {
        ComponentStage("NotificationCard", inspector: [("isUnread", "\(unread)"), ("type", typed ? "success" : "default")]) {
            if actions {
                NotificationCard(title: "Tatilinle İlgili Bir Önerimiz Var",
                                 message: "Hilton İstanbul rezervasyonuna 24 gün kaldı.",
                                 date: "5 Aralık 2024", isUnread: unread, type: type,
                                 onClose: closable ? { flash("Notification kapatıldı") } : nil) {
                    ButtonGroup(.horizontal) {
                        SecondaryButton("Sonra", size: .small) { flash("Notification: Sonra") }
                        PrimaryButton("İncele", size: .small) { flash("Notification: İncele") }
                    }
                }
            } else {
                NotificationCard(title: "Tatilinle İlgili Bir Önerimiz Var",
                                 message: "Hilton İstanbul rezervasyonuna 24 gün kaldı.",
                                 date: "5 Aralık 2024", isUnread: unread, type: type,
                                 onClose: closable ? { flash("Notification kapatıldı") } : nil)
            }
        } knobs: {
            Toggle("Unread", isOn: $unread)
            Toggle("Actions", isOn: $actions)
            Toggle("Type (success icon)", isOn: $typed)
            Toggle("Closable", isOn: $closable)
        }
    }
}

struct PageHeaderDemo: View {
    @State private var back = true
    @State private var subtitle = true
    @State private var actions = true
    @State private var tags = false
    var body: some View {
        ComponentStage("PageHeader") {
            PageHeader("Search results", subtitle: subtitle ? "128 hotels" : nil,
                       tags: tags ? [.init("Aktif", style: .success), .init("Beta", style: .info)] : [],
                       onBack: back ? { flash("PageHeader: geri") } : nil,
                       actions: actions ? [.init(systemImage: "slider.horizontal.3", handler: { flash("PageHeader: filtre") }), .init(systemImage: "heart", handler: { flash("PageHeader: favori") })] : [])
        } knobs: {
            Toggle("Back button", isOn: $back)
            Toggle("Subtitle", isOn: $subtitle)
            Toggle("Status tags", isOn: $tags)
            Toggle("Actions", isOn: $actions)
        }
    }
}

struct RatingSummaryDemo: View {
    @State private var score = 9.0
    @State private var reviews = true
    var body: some View {
        ComponentStage("RatingSummary", inspector: [("score", String(format: "%.1f", score))]) {
            RatingSummary(score: score, label: "Mükemmel", reviewCount: reviews ? 1200 : nil, onReviews: reviews ? { flash("Yorumlara dokunuldu") } : nil)
        } knobs: {
            HStack { Text("Score"); SwiftUI.Slider(value: $score, in: 0...10, step: 0.1) }
            Toggle("Review count", isOn: $reviews)
        }
    }
}

struct BlogCardDemo: View {
    @State private var compact = false
    var body: some View {
        ComponentStage("BlogCard", inspector: [("compact", "\(compact)")]) {
            BlogCard(title: "Kapadokya'yı Tek Başına Keşfetmeye Ne Dersin?",
                     excerpt: "Kimine göre doğanın bir mucizesi, kimine göre periler diyarı…",
                     compact: compact, onReadMore: { flash("BlogCard: devamını oku") }) {
                Theme.shared.background(.bgTertiary)
            }
        } knobs: {
            Toggle("Compact", isOn: $compact)
        }
    }
}

struct GalleryDemo: View {
    private struct Photo: Identifiable { let id = UUID(); let color: Color }
    private let photos = [Color.blue, .teal, .orange, .purple, .pink, .mint].map { Photo(color: $0) }
    @State private var columns = 2.0
    @State private var aspect: AspectRatioToken = .landscape4x3

    var body: some View {
        ComponentStage("Gallery", inspector: [("columns", "\(Int(columns))"), ("aspect", aspect.rawValue)]) {
            Gallery(photos, columns: Int(columns), aspect: aspect) { $0.color.opacity(0.3) }
        } knobs: {
            Stepper("Columns: \(Int(columns))", value: $columns, in: 1...4, step: 1)
            Picker("Aspect", selection: $aspect) {
                Text("1:1").tag(AspectRatioToken.square); Text("4:3").tag(AspectRatioToken.landscape4x3); Text("16:9").tag(AspectRatioToken.landscape16x9); Text("3:4").tag(AspectRatioToken.portrait3x4)
            }.pickerStyle(.segmented)
        }
    }
}

struct UploadDemo: View {
    private struct DemoUploadError: LocalizedError { var errorDescription: String? { "Dosya çok büyük" } }

    @State private var uploads = UploadController()
    @State private var counter = 0
    @State private var picked: [UploadFile] = []

    var body: some View {
        ComponentStage("Upload", inspector: [("files", "\(uploads.files.count)"), ("picked", "\(picked.count)/3")]) {
            VStack(spacing: 20) {
                UploadList(controller: uploads) { start(fail: false) }
                Upload(prompt: "En fazla 3 fotoğraf yükleyebilirsin.", buttonTitle: "Fotoğraf ekle",
                       files: picked, maxCount: 3,
                       onPick: { picked.append(.init(name: "img-\(picked.count + 1).jpg", status: .done)) },
                       onRemove: { file in picked.removeAll { $0.id == file.id } })
            }
        } knobs: {
            Button("Simulate upload") { start(fail: false) }
            Button("Simulate failure") { start(fail: true) }
            Button("Clear") { uploads.files.map(\.id).forEach { uploads.remove($0) }; picked = [] }
        }
    }

    private func start(fail: Bool) {
        counter += 1
        let name = "photo-\(counter).jpg"
        Task {
            await uploads.upload(name: name) { progress in
                for step in 1 ... 5 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    progress(Double(step) / 5)
                }
                if fail { throw DemoUploadError() }
            }
        }
    }
}

struct MenuCardDemo: View {
    @State private var count = 3.0
    private let items: [MenuCard.Item] = [
        .init(title: "Reservations", subtitle: "Upcoming & past", systemImage: "calendar"),
        .init(title: "Payment methods", subtitle: "Cards & wallets", systemImage: "creditcard"),
        .init(title: "Help center", subtitle: "FAQ & support", systemImage: "questionmark.circle"),
        .init(title: "Settings", subtitle: "App preferences", systemImage: "gearshape"),
    ]

    var body: some View {
        ComponentStage("MenuCard", inspector: [("items", "\(Int(count))")]) {
            MenuCard(items: Array(items.prefix(Int(count))))
        } knobs: {
            Stepper("Items: \(Int(count))", value: $count, in: 1...4, step: 1)
        }
    }
}

// MARK: - daisyUI gap components

struct RadialProgressDemo: View {
    @State private var value = 0.6
    @State private var label = true
    @State private var dashboard = false
    @State private var statusIdx = 0
    private var status: ProgressStatus { statusIdx == 1 ? .success : statusIdx == 2 ? .exception : .normal }
    var body: some View {
        ComponentStage("RadialProgress", inspector: [("value", String(format: "%.2f", value)), ("dashboard", "\(dashboard)")]) {
            RadialProgress(value: value, size: 96, lineWidth: 8, showLabel: label, status: status, dashboard: dashboard)
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value) }
            Picker("Status", selection: $statusIdx) { Text("Normal").tag(0); Text("Success").tag(1); Text("Exception").tag(2) }.pickerStyle(.segmented)
            Toggle("Dashboard (gap)", isOn: $dashboard)
            Toggle("Show label", isOn: $label)
        }
    }
}

struct IndicatorDemo: View {
    enum Kind: String, CaseIterable { case dot, badge }
    @State private var kind: Kind = .dot
    @State private var position: IndicatorPosition = .topTrailing
    var body: some View {
        ComponentStage("Indicator", inspector: [("kind", kind.rawValue)]) {
            Group {
                if kind == .dot {
                    Icon(systemName: "bell", size: .xl, color: Theme.shared.text(.textPrimary)).indicatorDot(position: position)
                } else {
                    Icon(systemName: "envelope", size: .xl, color: Theme.shared.text(.textPrimary)).indicator(position) { Badge("3", style: .error, size: .small) }
                }
            }
        } knobs: {
            Picker("Kind", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Picker("Position", selection: $position) {
                Text("TR").tag(IndicatorPosition.topTrailing); Text("TL").tag(IndicatorPosition.topLeading)
                Text("BR").tag(IndicatorPosition.bottomTrailing); Text("BL").tag(IndicatorPosition.bottomLeading)
            }.pickerStyle(.segmented)
        }
    }
}

struct StatDemo: View {
    enum Trend: String, CaseIterable { case up, down, none }
    @State private var trend: Trend = .up
    @State private var figure = true
    @State private var loading = false
    @State private var animated = false
    @State private var centered = false
    @State private var count = 1284
    private var statTrend: StatTrend? { trend == .up ? .up("+12%") : trend == .down ? .down("-3%") : nil }
    @ViewBuilder private var statView: some View {
        if animated {
            Stat(title: "Total bookings", value: count, suffix: "₺", isLoading: loading,
                 description: "this month", systemImage: figure ? "ticket" : nil, trend: statTrend)
        } else {
            Stat(title: "Total bookings", value: "1,284", suffix: "₺", isLoading: loading,
                 description: "this month", systemImage: figure ? "ticket" : nil, trend: statTrend)
        }
    }
    var body: some View {
        ComponentStage("Stat", inspector: [("style", centered ? "centered" : "default"), ("trend", trend.rawValue), ("loading", "\(loading)")]) {
            if centered {
                statView.statStyle(.centered)   // custom StatStyle via .statStyle(_:)
            } else {
                statView
            }
        } knobs: {
            Toggle("Centered style (.statStyle)", isOn: $centered)
            Picker("Trend", selection: $trend) { ForEach(Trend.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Toggle("Figure icon", isOn: $figure)
            Toggle("Loading (skeleton)", isOn: $loading)
            Toggle("Animated value (RollingNumber)", isOn: $animated)
            if animated { Button("+1.000") { count += 1000 } }
        }
    }
}

struct StepsDemo: View {
    @State private var active = 2
    @State private var vertical = false
    @State private var error = false
    @State private var descriptions = true
    @State private var progressDot = false
    @State private var percent = false
    private let titles = ["Cart", "Address", "Payment", "Done"]
    private let subs = ["2 items", "İstanbul", "Card ••42", "Confirm"]
    private var steps: [Steps.Step] {
        titles.enumerated().map { i, t in
            let state: StepState = (error && i == active) ? .error
                : i < active ? .done : i == active ? .active : .todo
            return .init(t, description: descriptions ? subs[i] : nil, state: state,
                         percent: (percent && state == .active) ? 0.6 : nil)
        }
    }
    var body: some View {
        ComponentStage("Steps", inspector: [("active", "\(active)"), ("progressDot", "\(progressDot)")]) {
            Steps(steps, axis: vertical ? .vertical : .horizontal, progressDot: progressDot) { active = $0; flash("Adım \($0 + 1) seçildi") }
        } knobs: {
            Stepper("Active: \(active)", value: $active, in: 0...3)
            Text("Tip: tap a step to jump to it.").font(.caption).foregroundStyle(.secondary)
            Toggle("Progress dot", isOn: $progressDot)
            Toggle("Active percent ring (60%)", isOn: $percent)
            Toggle("Error at active", isOn: $error)
            Toggle("Descriptions", isOn: $descriptions)
            Toggle("Vertical", isOn: $vertical)
        }
    }
}

struct BreadcrumbsDemo: View {
    @State private var depth = 6.0
    @State private var collapse = true
    private let all = ["Home", "Hotels", "Turkey", "Marmara", "İstanbul", "Grand Hotel"]
    var body: some View {
        ComponentStage("Breadcrumbs", inspector: [("depth", "\(Int(depth))"), ("maxItems", collapse ? "4" : "—")]) {
            Breadcrumbs(all.prefix(Int(depth)).enumerated().map { i, t in .init(t, action: i < Int(depth) - 1 ? { flash("Breadcrumb: \(t)") } : nil) },
                        maxItems: collapse ? 4 : nil)
        } knobs: {
            Stepper("Depth: \(Int(depth))", value: $depth, in: 1...6)
            Toggle("Collapse middle (maxItems 4 → …)", isOn: $collapse)
        }
    }
}

struct TimelineDemo: View {
    @State private var step = 2.0
    @State private var pending = true
    @State private var failed = false
    @State private var horizontal = false
    @State private var mode: TimelineMode = .left
    @State private var reverse = false
    private var modeLabel: String {
        switch mode { case .left: return "left"; case .right: return "right"; case .alternate: return "alternate" }
    }
    var body: some View {
        ComponentStage("Timeline", inspector: [("active", "\(Int(step))"), ("axis", horizontal ? "horizontal" : "vertical"), ("mode", modeLabel), ("reverse", "\(reverse)")]) {
            Timeline([
                .init(title: "Sipariş", time: "09:24", systemImage: "cart", state: .done, color: .success),
                .init(title: "Hazırlanıyor", time: "09:40", systemImage: "shippingbox", state: Int(step) > 1 ? .done : .active),
                failed
                    ? .init(title: "Hata", time: "09:45", description: horizontal ? nil : "Kartı tekrar dene.", state: .error)
                    : .init(title: "Yolda", time: "—", systemImage: "truck.box", state: Int(step) > 2 ? .done : Int(step) == 2 ? .active : .todo),
            ], axis: horizontal ? .horizontal : .vertical, mode: mode, reverse: reverse,
               pending: (!horizontal && pending) ? "Kurye bekleniyor…" : nil)
        } knobs: {
            Stepper("Active: \(Int(step))", value: $step, in: 0...3)
            Toggle("Horizontal", isOn: $horizontal)
            Toggle("Pending node (vertical)", isOn: $pending)
            Toggle("Error item", isOn: $failed)
            Toggle("Reverse order", isOn: $reverse)
            Picker("Mode (vertical)", selection: $mode) {
                Text("Left").tag(TimelineMode.left)
                Text("Right").tag(TimelineMode.right)
                Text("Alternate").tag(TimelineMode.alternate)
            }.pickerStyle(.segmented)
        }
    }
}

struct ChatBubbleDemo: View {
    @State private var outgoing = false
    @State private var avatar = true
    @State private var meta = true
    var body: some View {
        ComponentStage("ChatBubble", inspector: [("side", outgoing ? "outgoing" : "incoming")]) {
            ChatBubble("Merhaba! Rezervasyonunuz onaylandı.",
                       side: outgoing ? .outgoing : .incoming,
                       author: meta ? "Destek" : nil, time: meta ? "09:24" : nil,
                       avatarSystemImage: avatar ? "person.fill" : nil)
        } knobs: {
            Toggle("Outgoing", isOn: $outgoing)
            Toggle("Avatar", isOn: $avatar)
            Toggle("Author / time", isOn: $meta)
        }
    }
}

struct DrawerDemo: View {
    @Environment(DrawerPresenter.self) private var drawer: DrawerPresenter
    @State private var open = false
    @State private var trailing = false
    var body: some View {
        ComponentStage("Drawer", inspector: [("isPresented", "\(open)"), ("edge", trailing ? "trailing" : "leading")]) {
            PrimaryButton("Open drawer") { open = true; flash("Drawer açıldı") }
                .frame(maxWidth: .infinity, minHeight: 160)
                .drawer(isPresented: $open, edge: trailing ? .trailing : .leading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Menu").textStyle(.headingSm)
                        ListRow("Account", leadingSystemImage: "person.circle", action: { open = false; flash("Drawer: Account") })
                        ListRow("Settings", leadingSystemImage: "gearshape", action: { open = false; flash("Drawer: Settings") })
                        Spacer()
                    }
                    .padding()
                    .padding(.top, 50)
                }
        } knobs: {
            Toggle("Trailing edge", isOn: $trailing)
            Button("Open (declarative)") { open = true }
            Button("Open (imperative host)") {
                drawer.present(edge: trailing ? .trailing : .leading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Menu").textStyle(.headingSm)
                        ListRow("Account", leadingSystemImage: "person.circle", action: { drawer.dismiss(); flash("Drawer: Account") })
                        ListRow("Settings", leadingSystemImage: "gearshape", action: { drawer.dismiss(); flash("Drawer: Settings") })
                        Spacer()
                    }
                    .padding()
                    .padding(.top, 50)
                }
            }
            Text("Drag the panel toward its edge to dismiss.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - daisyUI gap components (batch 2)

struct StatusDotDemo: View {
    @State private var kind: StatusKind = .online
    @State private var pulse = true
    var body: some View {
        ComponentStage("Status", inspector: [("kind", "\(kind)")]) {
            StatusDot(kind, size: 14, label: "Status", pulse: pulse)
        } knobs: {
            Picker("Kind", selection: $kind) {
                Text("Online").tag(StatusKind.online); Text("Busy").tag(StatusKind.busy); Text("Away").tag(StatusKind.away); Text("Offline").tag(StatusKind.offline)
            }.pickerStyle(.segmented)
            Toggle("Pulse", isOn: $pulse)
        }
    }
}

struct SwapDemo: View {
    enum Pair: String, CaseIterable { case menu, theme }
    @State private var on = false
    @State private var pair: Pair = .menu
    var body: some View {
        ComponentStage("Swap", inspector: [("isOn", "\(on)")]) {
            Group {
                if pair == .menu { Swap(isOn: $on, on: "xmark", off: "line.3.horizontal", size: 32) }
                else { Swap(isOn: $on, on: "moon.fill", off: "sun.max.fill", size: 32) }
            }
        } knobs: {
            Picker("Icons", selection: $pair) { Text("Menu / Close").tag(Pair.menu); Text("Sun / Moon").tag(Pair.theme) }.pickerStyle(.segmented)
            Toggle("On", isOn: $on)
            Text("Tap the icon to swap.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct TextLinkDemo: View {
    @State private var underline = true
    var body: some View {
        ComponentStage("TextLink", inspector: [("underline", "\(underline)")]) {
            TextLink("Forgot password?", underline: underline) {}
        } knobs: {
            Toggle("Underline", isOn: $underline)
        }
    }
}

struct HeroDemo: View {
    @State private var dark = false
    @State private var subtitle = true
    @State private var cta = true
    var body: some View {
        ComponentStage("Hero", inspector: [("dark", "\(dark)")]) {
            Hero(title: dark ? "Summer Sale" : "Discover İstanbul",
                 subtitle: subtitle ? "Hand-picked stays at the best prices." : nil,
                 ctaTitle: cta ? "Explore" : nil, dark: dark, action: cta ? { flash("Hero: Explore") } : nil)
        } knobs: {
            Toggle("Dark", isOn: $dark)
            Toggle("Subtitle", isOn: $subtitle)
            Toggle("CTA", isOn: $cta)
        }
    }
}

struct FABDemo: View {
    @State private var speedDial = true
    @State private var square = false
    @State private var badge = false
    @State private var color: SemanticColor = .primary

    var body: some View {
        ComponentStage("FAB", inspector: [("speedDial", "\(speedDial)"), ("shape", square ? "square" : "circle")]) {
            FloatingActionButton(systemImage: speedDial ? "plus" : "bell.fill", actions: speedDial ? [
                .init(systemImage: "camera", label: "Photo", action: { flash("FAB: Photo") }),
                .init(systemImage: "doc", label: "Document", action: { flash("FAB: Document") }),
                .init(systemImage: "link", label: "Link", action: { flash("FAB: Link") }),
            ] : [], shape: square ? .square : .circle, color: color, badge: badge ? 3 : nil, action: { flash("FAB tıklandı") })
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .bottomTrailing)
        } knobs: {
            Toggle("Speed dial", isOn: $speedDial)
            Toggle("Square shape", isOn: $square)
            Toggle("Badge (3)", isOn: $badge)
            Picker("Color", selection: $color) { Text("Primary").tag(SemanticColor.primary); Text("Success").tag(SemanticColor.success); Text("Error").tag(SemanticColor.error) }.pickerStyle(.segmented)
        }
    }
}

struct CardStackDemo: View {
    private struct Item: Identifiable { let id = UUID(); let color: Color; let title: String }
    private let all = [Item(color: .blue, title: "Front"), Item(color: .teal, title: "Middle"), Item(color: .orange, title: "Back")]
    @State private var count = 3.0
    var body: some View {
        ComponentStage("Stack", inspector: [("count", "\(Int(count))")]) {
            CardStack(Array(all.prefix(Int(count)))) { item in
                RoundedRectangle(cornerRadius: 16).fill(item.color.opacity(0.3))
                    .frame(height: 110).overlay(Text(item.title).font(.headline)).frame(maxWidth: .infinity)
            }
        } knobs: {
            Stepper("Count: \(Int(count))", value: $count, in: 1...3, step: 1)
        }
    }
}

// MARK: - Config-completion components

struct CalendarDemo: View {
    @State private var date: Date? = .now
    var body: some View {
        ComponentStage("Calendar", inspector: [("selection", date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "nil")]) {
            CalendarView(selection: $date)
        } knobs: {
            Button("Clear") { date = nil }
        }
    }
}

struct DateFieldDemo: View {
    private enum Style: String, CaseIterable { case abbreviated, numeric, long, full, relative, custom }
    @State private var date: Date? = .now
    @State private var styleSel: Style = .custom
    @State private var withTime = false
    @State private var clearable = true
    @State private var enabled = true
    @State private var error = false

    private var style: DateFieldStyle {
        switch styleSel {
        case .abbreviated: return .abbreviated
        case .numeric: return .numeric
        case .long: return .long
        case .full: return .full
        case .relative: return .relative
        case .custom: return .custom("EEE, d MMM")
        }
    }
    private var messages: [InfoMessage] { error ? [InfoMessage("Tarih zorunlu", kind: .error)] : [] }

    var body: some View {
        ComponentStage("DateField", inspector: [("style", styleSel.rawValue), ("value", date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "nil")]) {
            DateField(label: "Tarih", date: $date, style: style,
                      components: withTime ? .dateAndTime : .date,
                      infoMessages: messages, allowClear: clearable,
                      leadingSystemImage: "calendar")
                    .a11yID("demoDate")
                    .disabled(!enabled)
        } knobs: {
            Text("style = display format (custom = \"EEE, d MMM\"). Tap the field to open the themed picker.").font(.caption).foregroundStyle(.secondary)
            Picker("Style", selection: $styleSel) { ForEach(Style.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Toggle("With time", isOn: $withTime)
            Toggle("Clearable", isOn: $clearable)
            Toggle("Error message", isOn: $error)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct DataTableDemo: View {
    private struct Booking: Identifiable { let id = UUID(); let hotel: String; let nights: Int; let price: Double }
    private let rows: [Booking] = [
        ("Grand Hotel", 3, 4250), ("Sea Resort", 5, 7800), ("City Inn", 2, 1900),
        ("Pine Lodge", 4, 5200), ("Bay Suites", 6, 9100), ("Old Town B&B", 1, 1200),
        ("Sky Tower", 3, 6400), ("Garden Palace", 7, 11800), ("Harbor View", 2, 3300),
        ("Mountain Cabin", 5, 4700),
    ].map { Booking(hotel: $0.0, nights: $0.1, price: $0.2) }

    @State private var striped = true
    @State private var selectable = false
    @State private var paged = true
    @State private var loading = false
    @State private var selected: Set<UUID> = []

    var body: some View {
        ComponentStage("DataTable", inspector: [("rows", "\(rows.count)"), ("paged", paged ? "4/page" : "off")]) {
            DataTable(columns: [
                .init("Hotel", sortKey: { .string($0.hotel) }) { $0.hotel },
                .init("Nights", align: .center, sortKey: { .number(Double($0.nights)) }) { "\($0.nights)" },
                .init("Price", align: .trailing, sortKey: { .number($0.price) }) { "₺\(Int($0.price))" },
            ], rows: rows, striped: striped, selection: selectable ? $selected : nil,
               pageSize: paged ? 4 : nil, isLoading: loading)
        } knobs: {
            Toggle("Striped", isOn: $striped)
            Toggle("Selectable rows", isOn: $selectable)
            Toggle("Paginated (4 / page)", isOn: $paged)
            Toggle("Loading", isOn: $loading)
            Text("Tap a column header to sort; the page resets to 1.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct BottomSheetDemo: View {
    @Environment(SheetPresenter.self) private var sheet: SheetPresenter
    @State private var showDeclarative = false
    var body: some View {
        ComponentStage("BottomSheet") {
            VStack(spacing: 12) {
                PrimaryButton("Imperative present") {
                    sheet.present(detents: [.height(260), .large]) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Filters").textStyle(.headingSm)
                            Text("Presented via SheetPresenter — no local binding.")
                                .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                    }
                }
                ThemeButton("Declarative sheet", variant: .outline) { showDeclarative = true }
            }
            .bottomSheet(isPresented: $showDeclarative, detents: [.medium]) {
                Text("Declarative .bottomSheet with a [.medium] detent.").textStyle(.bodyBase400)
            }
        } knobs: {
            Text("sheetHost() is installed at the app root.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct FilterGroupDemo: View {
    @State private var sel: String? = "Hotels"
    var body: some View {
        ComponentStage("FilterGroup", inspector: [("selection", sel ?? "nil")]) {
            FilterGroup(title: "Category", options: ["Hotels", "Flights", "Cars", "Tours"], selection: $sel) { $0 }
        } knobs: {
            Button("Clear") { sel = nil }
        }
    }
}

struct FieldsetDemo: View {
    @State private var name = ""
    @State private var helper = true
    @State private var subscribe = true
    var body: some View {
        ComponentStage("Fieldset") {
            Fieldset("Contact details", helper: helper ? "We'll only use this to confirm your booking." : nil) {
                TextInput("Full name", text: $name)
                HStack { Checkbox(isChecked: $subscribe); Text("Subscribe to newsletter").textStyle(.bodyBase400); Spacer() }
            }
        } knobs: {
            Toggle("Helper text", isOn: $helper)
        }
    }
}

struct FileInputDemo: View {
    @State private var picked = false
    @State private var error = false
    @State private var clearable = true
    private var messages: [InfoMessage] {
        error ? [InfoMessage("Dosya 5 MB'tan küçük olmalı", kind: .error)] : []
    }
    var body: some View {
        ComponentStage("FileInput", inspector: [("fileName", picked ? "passport-scan.jpg" : "nil"), ("error", "\(error)")]) {
            FileInput(label: "Passport", fileName: picked ? "passport-scan.jpg" : nil,
                      infoMessages: messages,
                      onPick: { picked = true; flash("FileInput: dosya seçildi") },
                      onClear: clearable ? { picked = false; flash("FileInput: temizlendi") } : nil)
        } knobs: {
            Toggle("File chosen", isOn: $picked)
            Toggle("Validation error", isOn: $error)
            Toggle("Clearable", isOn: $clearable)
        }
    }
}

struct ThemeControllerDemo: View {
    @State private var name = "defaultTheme"
    var body: some View {
        ComponentStage("ThemeController", inspector: [("selected", name)]) {
            VStack(spacing: 16) {
                ThemeController(options: [
                    .init(name: "defaultTheme", label: "Default"),
                    .init(name: "oceanTheme", label: "Ocean"),
                    .init(name: "sunsetTheme", label: "Sunset"),
                ], selectedName: $name)
                PrimaryButton("Sample button") { flash("Sample button tıklandı") }
            }
        } knobs: {
            Text("Switches Theme.shared live.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Configurable (daisyUI-style) components

struct ThemeButtonDemo: View {
    @State private var color: SemanticColor = .primary
    @State private var variant: ButtonVariant = .solid
    @State private var size: ButtonSize = .medium
    @State private var shape: ButtonShape = .rounded
    @State private var block = true
    @State private var icon = false
    @State private var trailingIcon = false
    @State private var loading = false

    private var iconOnly: Bool { shape == .circle || shape == .square }

    var body: some View {
        ComponentStage("ThemeButton", inspector: [
            ("color", color.rawValue), ("variant", variant.rawValue), ("shape", shape.rawValue), ("size", "\(size)"),
        ]) {
            ThemeButton(iconOnly ? nil : "Button",
                         systemImage: (icon || iconOnly) ? "star.fill" : nil,
                         iconPosition: trailingIcon ? .trailing : .leading,
                         color: color, variant: variant, size: size, shape: shape,
                         block: block && !iconOnly, isLoading: $loading) { flash("ThemeButton tıklandı") }
        } knobs: {
            Picker("Color", selection: $color) { ForEach(SemanticColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Variant", selection: $variant) { ForEach(ButtonVariant.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Size", selection: $size) {
                Text("XS").tag(ButtonSize.xsmall); Text("S").tag(ButtonSize.small); Text("M").tag(ButtonSize.medium); Text("L").tag(ButtonSize.large)
            }.pickerStyle(.segmented)
            Picker("Shape", selection: $shape) { ForEach(ButtonShape.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
            Toggle("Block (full width)", isOn: $block)
            Toggle("Leading icon", isOn: $icon)
            Toggle("Trailing icon position", isOn: $trailingIcon)
            Toggle("Loading", isOn: $loading)
        }
    }
}

// MARK: - Color Palette (Ant-style 50…900 ladder + roles)

struct ColorLadderDemo: View {
    @State private var color: SemanticColor = .primary

    private let steps = SemanticColor.Shade.allCases

    var body: some View {
        ComponentStage("Color Palette", inspector: [
            ("base", color.rawValue), ("ladder", "50…900"), ("base hex", "step 500"),
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 0) {
                    ForEach(steps, id: \.self) { step in
                        Rectangle()
                            .fill(color.shade(step))
                            .frame(height: 60)
                            .overlay(alignment: .bottom) {
                                Text("\(step.rawValue)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(step.rawValue >= 400 ? .white : .black.opacity(0.7))
                                    .padding(.bottom, 3)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 8) {
                    roleRow("bg", "50", color.bg)
                    roleRow("bgHover", "100", color.bgHover)
                    roleRow("borderSubtle", "200", color.borderSubtle)
                    roleRow("hover", "400", color.hover)
                    roleRow("base", "500", color.base)
                    roleRow("active", "600", color.active)
                    roleRow("strong", "700", color.strong)
                }
            }
            .padding(.vertical, 4)
        } knobs: {
            Picker("Color", selection: $color) {
                ForEach(SemanticColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
        }
    }

    private func roleRow(_ name: String, _ step: String, _ swatch: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(swatch)
                .frame(width: 44, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.08)))
            Text(".\(name)").font(.system(size: 13, weight: .medium, design: .monospaced))
            Text("(\(step))").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Feedback (unified presenter: toast + confirm)

struct FeedbackDemo: View {
    @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
    @State private var kind: FeedbackKind = .success
    @State private var last = "—"

    var body: some View {
        ComponentStage("Feedback", inspector: [("level", "global"), ("last action", last)]) {
            VStack(spacing: 12) {
                ThemeButton("Toast göster", color: kind.semanticColor, block: true) {
                    feedback.toast("\(kind.rawValue.capitalized) mesajı",
                                   message: "Bu bir \(kind.rawValue) bildirimi.", kind: kind)
                    last = "toast: \(kind.rawValue)"
                }
                ThemeButton("Stack (3 toast)", color: kind.semanticColor, variant: .soft, block: true) {
                    for i in 1 ... 3 { feedback.toast("Toast #\(i)", kind: kind) }
                    last = "stack: 3"
                }
                ThemeButton("Undo (action + sticky)", variant: .outline, block: true) {
                    feedback.toast("Mesaj silindi", kind: .info,
                                   action: ToastAction("Geri al") { feedback.toast("Geri alındı", kind: .success) },
                                   duration: nil)
                    last = "undo toast"
                }
                ThemeButton("Async görev (task)", variant: .outline, block: true) {
                    Task {
                        await feedback.toastTask(loading: "Kaydediliyor…", success: "Kaydedildi") {
                            try await Task.sleep(nanoseconds: 1_500_000_000)
                        }
                    }
                    last = "async task"
                }
                ThemeButton("Bildirim göster (notification)", color: kind.semanticColor, variant: .soft, block: true) {
                    feedback.notify("\(kind.rawValue.capitalized)", message: "Üstten gelen bir bildirim.", kind: kind)
                    last = "notify: \(kind.rawValue)"
                }
                ThemeButton("Yükleniyor (loading)", systemImage: "arrow.clockwise", variant: .outline, block: true) {
                    feedback.loading("Kaydediliyor…")
                    last = "loading"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        feedback.dismissLoading(); feedback.toast("Kaydedildi", kind: .success)
                    }
                }
                ThemeButton("Onay iste (confirm)", color: .error, variant: .outline, block: true) {
                    feedback.confirm(
                        title: "Rezervasyonu iptal et?",
                        message: "Bu işlem geri alınamaz.",
                        primaryTitle: "İptal et", primaryKind: .error,
                        onPrimary: { last = "confirmed"; feedback.toast("İptal edildi", kind: .success); flash("Onaylandı") },
                        secondaryTitle: "Vazgeç", onSecondary: { last = "dismissed"; flash("Vazgeçildi") }
                    )
                }
            }
        } knobs: {
            Picker("Kind", selection: $kind) {
                ForEach(FeedbackKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .onAppear {
            // Screenshot hook: launch with `-feedbackDemo toast|confirm|notify`.
            switch UserDefaults.standard.string(forKey: "feedbackDemo") {
            case "toast": feedback.toast("Kaydedildi", message: "Değişiklikler kaydedildi.", kind: .success)
            case "notify": feedback.notify("Yeni mesaj", message: "Rezervasyonunuz onaylandı.", kind: .info)
            case "confirm": feedback.confirm(title: "Rezervasyonu iptal et?", message: "Bu işlem geri alınamaz.",
                                             primaryTitle: "İptal et", primaryKind: .error, secondaryTitle: "Vazgeç")
            default: break
            }
        }
    }
}

// MARK: - Result / Exception templates

struct ResultDemo: View {
    @State private var status: ResultStatus = .success

    private var copy: (String, String) {
        switch status {
        case .success: return ("Rezervasyon onaylandı", "Onay e-postası gönderildi.")
        case .info: return ("Bilgilendirme", "İşleminiz sıraya alındı.")
        case .warning: return ("Ödeme beklemede", "Banka onayı bekleniyor.")
        case .error: return ("Ödeme başarısız", "Kart bilgilerinizi kontrol edip tekrar deneyin.")
        case .notFound: return ("Sayfa bulunamadı", "Aradığınız sayfa taşınmış veya silinmiş olabilir.")
        case .forbidden: return ("Erişim engellendi", "Bu sayfayı görüntüleme yetkiniz yok.")
        case .serverError: return ("Bir şeyler ters gitti", "Sunucu hatası oluştu, lütfen tekrar deneyin.")
        }
    }

    var body: some View {
        ComponentStage("Result", inspector: [("status", status.rawValue), ("code", status.codeText)]) {
            ResultView(status, title: copy.0, message: copy.1,
                       primaryTitle: "Tekrar dene", onPrimary: { flash("Result: Tekrar dene") },
                       secondaryTitle: "Ana sayfa", onSecondary: { flash("Result: Ana sayfa") })
        } knobs: {
            Picker("Status", selection: $status) {
                ForEach(ResultStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        .onAppear {
            // Screenshot hook: launch with `-resultStatus notFound|forbidden|serverError|error|…`.
            if let raw = UserDefaults.standard.string(forKey: "resultStatus"),
               let s = ResultStatus(rawValue: raw) { status = s }
        }
    }
}

private extension ResultStatus {
    var codeText: String {
        switch self {
        case .notFound: return "404"
        case .forbidden: return "403"
        case .serverError: return "500"
        default: return "—"
        }
    }
}

// MARK: - Batch 6: new components

struct BorderBeamDemo: View {
    @State private var lineWidth = 3.0
    @State private var duration = 4.0
    @State private var pill = false
    @State private var glow = true
    @State private var paletteIdx = 0   // 0 accent, 1 purple→pink, 2 sunset

    private var colors: [Color]? {
        switch paletteIdx {
        case 1: return [SemanticColor.purple.base, SemanticColor.pink.base]
        case 2: return [SemanticColor.orange.base, SemanticColor.warning.base]
        default: return nil   // theme accent + turquoise
        }
    }

    var body: some View {
        ComponentStage("BorderBeam", inspector: [("lineWidth", String(format: "%.0f", lineWidth)), ("glow", "\(glow)")]) {
            Text(pill ? "Pro" : "Featured")
                .textStyle(.headingSm)
                .foregroundStyle(Theme.shared.text(.textPrimary))
                .padding(.horizontal, pill ? 28 : 48)
                .padding(.vertical, pill ? 14 : 44)
                .background(Theme.shared.background(.bgElevatorTertiary), in: RoundedRectangle(cornerRadius: pill ? 100 : 20, style: .continuous))
                .borderBeam(cornerRadius: pill ? 100 : 20, lineWidth: lineWidth, duration: duration, glow: glow, colors: colors)
        } knobs: {
            HStack { Text("Width"); SwiftUI.Slider(value: $lineWidth, in: 1...6, step: 1) }
            HStack { Text("Speed"); SwiftUI.Slider(value: $duration, in: 1.5...8) }
            Picker("Colors", selection: $paletteIdx) { Text("Accent").tag(0); Text("Purple→Pink").tag(1); Text("Sunset").tag(2) }.pickerStyle(.segmented)
            Toggle("Glow halo", isOn: $glow)
            Toggle("Pill shape", isOn: $pill)
        }
    }
}

struct PopconfirmDemo: View {
    @State private var show = false
    @State private var edge: TooltipEdge = .bottom
    @State private var asyncConfirm = false
    @State private var last = "—"
    var body: some View {
        ComponentStage("Popconfirm", inspector: [("isPresented", "\(show)"), ("edge", "\(edge)"), ("last", last)]) {
            ThemeButton("Sil", systemImage: "trash", color: .error, variant: .soft) { show.toggle() }
                .popconfirm(isPresented: $show, title: "Bu öğeyi sil?", message: "Bu işlem geri alınamaz.",
                            confirmTitle: "Sil", cancelTitle: "Vazgeç", edge: edge,
                            onConfirm: {
                                if asyncConfirm { try? await Task.sleep(nanoseconds: 1_200_000_000) }
                                last = "confirmed"; flash("Popconfirm onaylandı")
                            },
                            onCancel: { last = "cancelled"; flash("Popconfirm iptal edildi") })
                .padding(80)
        } knobs: {
            Toggle("Async confirm (1.2s)", isOn: $asyncConfirm)
            Picker("Edge", selection: $edge) {
                Text("Top").tag(TooltipEdge.top)
                Text("Bottom").tag(TooltipEdge.bottom)
                Text("Leading").tag(TooltipEdge.leading)
                Text("Trailing").tag(TooltipEdge.trailing)
            }.pickerStyle(.segmented)
        }
    }
}

struct TreeSelectDemo: View {
    @State private var picks: Set<String> = ["ist"]
    @State private var cascade = true
    @State private var searchable = true
    @State private var loading = false
    @State private var disableIzmir = false
    private let tree = [
        TreeNode(id: "tr", "Türkiye", systemImage: "flag", children: [
            TreeNode(id: "ist", "İstanbul"), TreeNode(id: "ank", "Ankara"), TreeNode(id: "izm", "İzmir"),
        ]),
        TreeNode(id: "de", "Almanya", systemImage: "flag", children: [
            TreeNode(id: "ber", "Berlin"), TreeNode(id: "mun", "Münih"),
        ]),
    ]
    var body: some View {
        ComponentStage("TreeSelect", inspector: [("selected", "\(picks.count)"), ("cascade", "\(cascade)"), ("loading", "\(loading)")]) {
            TreeSelect(label: "Şehirler", nodes: tree, selection: $picks,
                       cascade: cascade, searchable: searchable, initiallyExpanded: ["tr", "de"],
                       isLoading: loading, isNodeEnabled: disableIzmir ? { $0.id != "izm" } : nil)
                .id("\(cascade)\(searchable)\(loading)\(disableIzmir)")
        } knobs: {
            Toggle("Cascade (parent ↔ child + indeterminate)", isOn: $cascade)
            Toggle("Searchable", isOn: $searchable)
            Toggle("Loading", isOn: $loading)
            Toggle("Disable “İzmir”", isOn: $disableIzmir)
            Button("Reset") { picks = ["ist"] }
        }
    }
}

struct TourDemo: View {
    @State private var tour = TourController()
    var body: some View {
        ComponentStage("Tour", inspector: [("active", "\(tour.isActive)"), ("step", "\(tour.index + 1)")]) {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    tourIcon("magnifyingglass", "search")
                    tourIcon("heart", "fav")
                    tourIcon("person.crop.circle", "profile")
                }
                ThemeButton("Turu başlat", systemImage: "play.fill", block: true) { tour.start(); flash("Tur başlatıldı") }
            }
            .tourHost(tour, steps: [
                TourStep("search", title: "Arama", message: "Buradan otel arayabilirsiniz."),
                TourStep("fav", title: "Favoriler", message: "Beğendiklerinizi kaydedin."),
                TourStep("profile", title: "Profil", message: "Hesabınızı buradan yönetin."),
            ])
        } knobs: {
            Button("Turu başlat") { tour.start() }
        }
        .onAppear {
            // Screenshot hook: launch with `-startTour YES`.
            if UserDefaults.standard.bool(forKey: "startTour") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { tour.start() }
            }
        }
    }

    private func tourIcon(_ symbol: String, _ id: String) -> some View {
        Image(systemName: symbol)
            .font(.title2)
            .foregroundStyle(Theme.shared.text(.textHero))
            .frame(width: 52, height: 52)
            .background(Theme.shared.background(.bgElevatorTertiary), in: Circle())
            .tourTarget(id)
    }
}

// MARK: - Form (aggregate validation: validate-on-submit + focus first error)

struct FormDemo: View {
    private enum Field { case email, password, plan, terms }

    @State private var form = FormValidator<Field>([
        .email: [.required("E-posta zorunlu"), .email()],
        .password: [.required("Şifre zorunlu"), .password(minLength: 8)],
        .plan: [.required("Bir paket seçin")],
        .terms: [.required("Devam etmek için kabul edin")],
    ])
    @State private var email = ""
    @State private var password = ""
    @State private var plan: String?
    @State private var terms = false
    @State private var submitted = false
    @State private var done = false

    // Map non-text controls to a value the validator understands.
    private var values: [Field: String] {
        [.email: email, .password: password, .plan: plan ?? "", .terms: terms ? "1" : ""]
    }

    var body: some View {
        ComponentStage("Form", inspector: [("valid", submitted ? "\(form.isValid)" : "—"), ("focused", "\(form.focusedField.map { "\($0)" } ?? "—")")]) {
            VStack(spacing: Theme.SpacingKey.md.value) {
                Fieldset("Hesap oluştur", helper: "Tüm alanlar zorunlu.") {
                    TextInput(TextInputModel(label: "E-posta", leadingSystemImage: "envelope",
                                             infoMessages: form.messages(for: .email)),
                              text: $email, externalFocus: form.focusBinding(.email))
                        .a11yID("form.email")
                    TextInput(TextInputModel(label: "Şifre (8+, büyük harf, rakam)", isSecure: true,
                                             infoMessages: form.messages(for: .password)),
                              text: $password, externalFocus: form.focusBinding(.password))
                        .a11yID("form.password")
                    RadioGroup(title: "Paket", options: ["Standart", "Pro"], selection: $plan,
                               infoMessages: form.messages(for: .plan)) { $0 }
                    .a11yID("form.plan")
                    Checkbox("Şartları ve koşulları kabul ediyorum", isChecked: $terms,
                             infoMessages: form.messages(for: .terms))
                    .a11yID("form.terms")
                }
                if done {
                    InfoBanner("Hesabınız oluşturuldu.", type: .success)
                }
                ThemeButton("Kayıt ol", block: true, accessibilityID: "form.submit") {
                    let firstInvalid = form.validateAll(values)
                    submitted = true
                    done = firstInvalid == nil
                }
            }
        } knobs: {
            Text("Boş submit → e-posta/şifre + RadioGroup + Checkbox hepsi hata gösterir; ilk hatalı text alan odaklanır.").font(.caption).foregroundStyle(.secondary)
            Button("Reset") { email = ""; password = ""; plan = nil; terms = false; submitted = false; done = false; form.reset() }
        }
        .onChange(of: values.description) { _, _ in if submitted { _ = form.validateAll(values) } }
        .onAppear {
            // Screenshot hook: launch with `-formSubmit YES` to validate empty form.
            if UserDefaults.standard.bool(forKey: "formSubmit") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    email = "bad"
                    _ = form.validateAll(values)
                    submitted = true
                }
            }
        }
    }
}

// MARK: - List container (Ant List)

struct ListDemo: View {
    private struct Row: Identifiable { let id = UUID(); let title: String; let subtitle: String; let icon: String }
    private let rows = [
        Row(title: "Hesabım", subtitle: "Profil ve güvenlik", icon: "person.circle"),
        Row(title: "Bildirimler", subtitle: "E-posta ve push", icon: "bell"),
        Row(title: "Dil", subtitle: "Türkçe", icon: "globe"),
    ]
    @State private var withHeader = true
    @State private var bordered = true
    @State private var split = true
    @State private var loading = false
    @State private var empty = false

    var body: some View {
        ComponentStage("List", inspector: [("count", "\(empty ? 0 : rows.count)"), ("bordered", "\(bordered)"), ("empty", "\(empty)")]) {
            ListView(empty ? [] : rows, header: withHeader ? "Ayarlar" : nil, footer: withHeader ? "\(empty ? 0 : rows.count) öğe" : nil,
                     bordered: bordered, loading: loading, split: split, emptyText: "Henüz ayar yok") { row in
                ListRow(row.title, subtitle: row.subtitle, leadingSystemImage: row.icon, action: { flash("List: \(row.title)") })
            }
        } knobs: {
            Toggle("Header + footer", isOn: $withHeader)
            Toggle("Bordered", isOn: $bordered)
            Toggle("Split (dividers)", isOn: $split)
            Toggle("Loading (skeleton)", isOn: $loading)
            Toggle("Empty (no items)", isOn: $empty)
        }
    }
}

// MARK: - Ref-logic: RemoteImage + AccordionGroup

struct RemoteImageDemo: View {
    @State private var ratio = 1   // 0:16:9, 1:1:1, 2:4:5
    @State private var circle = false
    @State private var gif = false
    private var ratioStr: String { ratio == 0 ? "16:9" : ratio == 2 ? "4:5" : "1:1" }
    private let gifURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/d3/Newtons_cradle_animation_book_2.gif")
    var body: some View {
        ComponentStage("RemoteImage", inspector: [("mode", gif ? "gif" : circle ? "circle" : ratioStr)]) {
            VStack(spacing: 16) {
                if gif {
                    RemoteImage(gifURL, ratio: "1:1", cornerRadius: 16)
                        .frame(width: 180, height: 180)
                } else if circle {
                    RemoteImage(URL(string: "https://picsum.photos/seed/gucomp/600/600"), aspectRatio: 1, circle: true)
                        .frame(width: 140, height: 140)
                } else {
                    RemoteImage(URL(string: "https://picsum.photos/seed/gucomp/600/600"), ratio: ratioStr, cornerRadius: 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }
                Text("Static via AsyncImage (AVIF/WebP native on iOS 16+); .gif/.apng animate via ImageIO — no dependency.").font(.caption).foregroundStyle(.secondary)
            }
        } knobs: {
            Toggle("Animated GIF (native)", isOn: $gif)
            Toggle("Circle clip (avatar)", isOn: $circle)
            Picker("Aspect", selection: $ratio) { Text("16:9").tag(0); Text("1:1").tag(1); Text("4:5").tag(2) }.pickerStyle(.segmented).disabled(circle || gif)
        }
    }
}

struct ImageCollageDemo: View {
    @State private var count = 6.0
    private var urls: [URL] {
        (1...Int(count)).compactMap { URL(string: "https://picsum.photos/seed/collage\($0)/400/300") }
    }
    var body: some View {
        ComponentStage("ImageCollage", inspector: [("images", "\(Int(count))")]) {
            ImageCollage(urls, height: 220, onTap: { flash("ImageCollage: \($0 + 1). görsel") })
        } knobs: {
            HStack { Text("Images"); SwiftUI.Slider(value: $count, in: 1...8, step: 1) }
            Text("Layouts adapt: 1 · 2 · 3 · 4+ with a +N overlay on the last tile.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AccordionGroupDemo: View {
    private struct FAQ: Identifiable { let id = UUID(); let q: String; let a: String }
    private let faqs = [
        FAQ(q: "İptal edebilir miyim?", a: "Evet, girişten 24 saat öncesine kadar ücretsiz iptal."),
        FAQ(q: "Ödeme seçenekleri neler?", a: "Kredi/banka kartı ve havale/EFT kabul edilir."),
        FAQ(q: "Evcil hayvan kabul ediliyor mu?", a: "Küçük ırk evcil hayvanlar ek ücretle kabul edilir."),
    ]
    @State private var multi = false

    var body: some View {
        ComponentStage("AccordionGroup", inspector: [("mode", multi ? "multiple" : "single")]) {
            AccordionGroup(faqs, mode: multi ? .multiple : .single, initiallyExpanded: []) { $0.q } content: {
                Text($0.a).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
            }
        } knobs: {
            Toggle("Multiple open", isOn: $multi)
            Text("single = opening one closes the others; multiple = independent.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Ref-logic D: PagingCarousel + RollingNumber + VideoPlayer

struct PagingCarouselDemo: View {
    private struct Slide: Identifiable { let id = UUID(); let color: Color; let title: String }
    private let slides = [Slide(color: .blue, title: "Bir"), Slide(color: .teal, title: "İki"),
                          Slide(color: .orange, title: "Üç"), Slide(color: .purple, title: "Dört")]
    @State private var autoplay = false
    @State private var peek = 36.0

    var body: some View {
        ComponentStage("PagingCarousel", inspector: [("peek", "\(Int(peek))"), ("autoplay", "\(autoplay)")]) {
            PagingCarousel(slides, peek: peek, autoplay: autoplay ? 2 : nil) { s in
                s.color.opacity(0.25).overlay(Text(s.title).textStyle(.headingSm))
            }
        } knobs: {
            HStack { Text("Peek"); SwiftUI.Slider(value: $peek, in: 0...64, step: 4) }
            Toggle("Autoplay (2s)", isOn: $autoplay)
            Text("Drag to page — previous/next peek at the edges.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct RollingNumberDemo: View {
    @State private var value = 1284
    @State private var size = 40.0
    var body: some View {
        ComponentStage("RollingNumber", inspector: [("value", "\(value)")]) {
            VStack(spacing: 16) {
                RollingNumber(value, size: size, color: Theme.shared.text(.textHero))
                ThemeButton("Roll", systemImage: "dice") { value = Int.random(in: 100...99999); flash("RollingNumber: \(value)") }
            }
        } knobs: {
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 24...64, step: 4) }
            Stepper("Value: \(value)", value: $value, in: 0...999999, step: 111)
        }
    }
}

struct VideoPlayerDemo: View {
    @State private var muted = true
    @State private var loop = true
    @State private var tapToToggle = true
    @State private var muteToggle = true
    @State private var progress: Double = 0
    private let url = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")
    var body: some View {
        ComponentStage("VideoPlayer", inspector: [("muted", "\(muted)"), ("progress", String(format: "%.0f%%", progress * 100))]) {
            VStack(spacing: 8) {
                VideoPlayerView(url, progress: $progress, isMuted: $muted)
                    .loop(loop)
                    .muted(muted)
                    .muteToggle(muteToggle)
                    .tapToToggle(tapToToggle)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                ProgressBar(value: progress)
            }
        } knobs: {
            Toggle("Muted", isOn: $muted)
            Toggle("Mute toggle button", isOn: $muteToggle)
            Toggle("Tap to play/pause", isOn: $tapToToggle)
            Toggle("Loop", isOn: $loop)
            Text("AVKit · resume from last position · progress binding · active-gated.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ChipsDemo: View {
    enum Kind: String, CaseIterable { case compact, chose, image, filter, group }
    @State private var kind: Kind = .compact
    @State private var a = true
    @State private var b = false
    @State private var multi: Set<String> = ["Wifi", "Havuz"]
    @State private var square = false

    private var imageURL: URL? { URL(string: "https://picsum.photos/seed/imgchip/200/300") }

    var body: some View {
        ComponentStage("Chips", inspector: [("variant", kind.rawValue)]) {
            Group {
                switch kind {
                case .compact:
                    HStack(spacing: 12) {
                        CompactChip(isSelected: $a, text: "Standart Oda", price: "₺399,90", rating: 4.6)
                        CompactChip(isSelected: $b, text: "Suit Oda", price: "₺899,90")
                    }
                case .chose:
                    ChoseChip(isSelected: $a, title: "Esnek Tarife", description: "Ücretsiz iptal",
                              rating: 4.8, showFree: true, systemImage: "wind")
                case .image:
                    HStack(spacing: 12) {
                        ImageChip(isSelected: $a, url: imageURL, size: .medium)
                        ImageChip(isSelected: $b, url: imageURL, size: .medium)
                    }
                case .filter:
                    HStack(spacing: 8) {
                        FilterChip("İstanbul", shape: square ? .square : .pill) { flash("FilterChip: İstanbul") }
                        FilterChip("4+ yıldız", shape: square ? .square : .pill) { flash("FilterChip: 4+ yıldız") }
                    }
                case .group:
                    ChipGroup(title: "Olanaklar", options: ["Wifi", "Havuz", "Spa", "Otopark", "Restoran"], selection: $multi) { $0 }
                }
            }
        } knobs: {
            Picker("Variant", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            if kind == .filter { Toggle("Square shape", isOn: $square) }
            if kind == .group { Text("Multi-select: \(multi.sorted().joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct DialogDemo: View {
    @State private var show = false
    @State private var accepted = false
    @State private var showConfirm = false
    @State private var deleted = false
    var body: some View {
        ComponentStage("Dialog", inspector: [("accepted", "\(accepted)"), ("deleted", "\(deleted)")]) {
            VStack(spacing: 12) {
                PrimaryButton("Sözleşmeyi aç") { show = true; flash("Dialog açıldı") }
                OutlineButton("Hesabı sil (async)") { deleted = false; showConfirm = true }
                Text(accepted ? "Kabul edildi ✓" : "Henüz onaylanmadı")
                    .textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textSecondary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .dialog(isPresented: $showConfirm, title: "Hesabı sil?", message: "Bu işlem geri alınamaz.",
                    primaryTitle: "Sil", onPrimary: {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)   // async work; OK spins
                        deleted = true; flash("Hesap silindi")
                    }, secondaryTitle: "Vazgeç", onSecondary: { flash("Vazgeçildi") }, kind: .error)
            .dialog(isPresented: $show, title: "Kullanım Koşulları", afterClose: {}) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(1...8, id: \.self) { i in
                        Text("\(i). Madde").textStyle(.labelBase700).foregroundStyle(Theme.shared.text(.textPrimary))
                        Text("Bu uzun metin, dialog içeriğinin kaydırılabilir olduğunu gösterir. Footer sabit kalır.")
                            .textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
            } footer: {
                HStack(spacing: 12) {
                    OutlineButton("Vazgeç") { show = false; flash("Dialog: Vazgeç") }
                    PrimaryButton("Kabul et") { accepted = true; show = false; flash("Dialog onaylandı") }
                }
            }
        } knobs: {
            Button("Reset") { accepted = false }
        }
    }
}

struct ProgressIndicatorDemo: View {
    enum Variant: String, CaseIterable { case carousel, video, progress }
    @State private var variant: Variant = .carousel
    @State private var current = 2.0
    @State private var videoProgress = 0.5
    @State private var stepText = true
    @State private var padded = false

    private var v: ProgressIndicatorVariant { variant == .video ? .video : variant == .progress ? .progress : .carousel }

    var body: some View {
        ComponentStage("ProgressIndicator", inspector: [("variant", variant.rawValue), ("step", "\(Int(current))/8")]) {
            ProgressIndicator(variant: v, current: Int(current), total: 8,
                              videoProgress: videoProgress,
                              stepText: stepText ? (padded ? .padded : .slash) : .none)
        } knobs: {
            Picker("Variant", selection: $variant) { ForEach(Variant.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
            HStack { Text("Current"); SwiftUI.Slider(value: $current, in: 0...8, step: 1) }
            if variant == .video { HStack { Text("Video fill"); SwiftUI.Slider(value: $videoProgress) } }
            Toggle("Step text", isOn: $stepText)
            if stepText { Toggle("Padded (01 | 08)", isOn: $padded) }
        }
    }
}

// MARK: - Micro-motion (system)

struct MicroMotionDemo: View {
    @State private var enabled = true
    @State private var on = false
    @State private var sel = 0
    var body: some View {
        ComponentStage("Micro-motion", inspector: [("microAnimations", "\(enabled)")]) {
            VStack(spacing: 18) {
                Text("Bu alt-ağaç: .microAnimations(\(enabled ? "true" : "false")) — basınca scale, seçimde kayma.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                PrimaryButton("Bana bas (micro press)") { flash("Tap") }
                SegmentedControl(["Gün", "Hafta", "Ay"], selection: $sel)
                ThemeToggle(isOn: $on)

                DividerView(size: .small)
                Text("Per-component override — bu buton her zaman kapalı:")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                SecondaryButton("Hareketsiz (.microAnimations(false))") { flash("Tap") }
                    .microAnimations(false)
            }
            .microAnimations(enabled)
        } knobs: {
            Toggle("Micro-animations (bu alt-ağaç)", isOn: $enabled)
            Text("Tema geneli için: Configurator → “Micro-animations”. Reduce Motion her zaman kazanır.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
