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
                DividerView(withText ? "OR" : nil).dashed(dashed).titleAlign(alignment)
                HStack(spacing: 16) {
                    Text("A"); DividerView().axis(.vertical).dashed(dashed); Text("B"); DividerView().axis(.vertical); Text("C")
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
            Icon(systemName: symbol).size(size).accent(.primary)
        } knobs: {
            TextField("SF Symbol", text: $symbol).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            Picker("Size", selection: $size) { ForEach(IconSize.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }
    }
}

struct InputLabelDemo: View {
    @State private var text = "Your name"
    @State private var required = true
    @State private var info = false
    @State private var tooltip = true
    @State private var error = false
    @State private var link = false

    var body: some View {
        ComponentStage("InputLabel", inspector: [("required", "\(required)"), ("tooltip", "\(tooltip)"), ("hasError", "\(error)")]) {
            label
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            Toggle("Inline tappable link", isOn: $link)
            Toggle("Required", isOn: $required)
            Toggle("Info glyph", isOn: $info)
            Toggle("Tooltip trigger", isOn: $tooltip)
            Toggle("Error", isOn: $error)
        }
    }

    // The tooltip trigger implies the info glyph, so it is applied last.
    private var label: some View {
        let base = InputLabel(link ? "Email (why do we ask?)" : text)
            .required(required).hasInfo(info).hasError(error)
            .links(link ? [("why do we ask?", { flash("InputLabel link") })] : [])
        return tooltip ? base.infoTooltip("Shown on your public profile.") : base
    }
}

struct ScoreBadgeDemo: View {
    @State private var score = 9.0
    @State private var large = false
    var body: some View {
        ComponentStage("ScoreBadge", inspector: [("score", String(format: "%.1f", score)), ("size", large ? "large" : "small")]) {
            ScoreBadge(score).size(large ? .large : .small)
        } knobs: {
            HStack { Text("Score"); SwiftUI.Slider(value: $score, in: 0...10, step: 0.1) }
            Toggle("Large (size axis)", isOn: $large)
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
                    Skeleton(.circle).size(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        Skeleton(.capsule).size(width: 160, height: 12)
                        Skeleton(.capsule).size(width: 110, height: 12)
                        Skeleton(.rounded(6)).size(width: 200, height: 12)
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
            Title("Popular destinations")
                .subtitle(subtitle ? "Where travellers go" : nil)
                .eyebrow(eyebrow ? "Limited time" : nil)
                .action(action ? "See all" : nil,
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
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    @State private var recent = ["Istanbul", "Bursa"]

    private let cities = ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa", "Adana"]
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }

    var body: some View {
        ComponentStage("SearchBar", inspector: [("text", "\"\(text)\""), ("suggestions", "\(typeahead)"), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            {
                let base = SearchBar(text: $text)
                    .suggestions(typeahead ? cities : [])
                    .recent(typeahead ? recent : [], onClear: typeahead ? { recent = []; flash("Recent cleared") } : nil)
                    .onSelect { flash("Selected: \($0)") }
                    .onCommit { flash("Submit: \($0)") }
                    .backButton(back)
                    .trailingIcon(trailing ? "barcode.viewfinder" : nil)
                return explicitSize.map { base.size($0) } ?? base
            }()
        } knobs: {
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
            Toggle("Back button", isOn: $back)
            Toggle("Trailing icon", isOn: $trailing)
            Toggle("Suggestions + recent", isOn: $typeahead)
        }
    }
}

struct InputGroupDemo: View {
    @State private var value = "heroui.com"
    @State private var variant: InputGroupVariant = .primary
    @State private var type: InputGroupType = .text
    @State private var affix = 0            // 0 both · 1 prefix · 2 suffix
    @State private var gap = false
    @State private var reveal = false
    // Standalone example fields.
    @State private var phone = ""
    @State private var command = ""
    @State private var email = ""

    private var showPrefix: Bool { affix == 0 || affix == 1 }
    private var showSuffix: Bool { affix == 0 || affix == 2 }
    private var placeholder: String {
        switch type { case .text: return "heroui.com"; case .number: return "0"; case .password: return "Password" }
    }
    /// Password reveals as plain text while the eye toggle is on.
    private var effectiveType: InputGroupType { type == .password && reveal ? .text : type }

    /// Built imperatively so the prefix/suffix slots stay conditional on the knob.
    private var live: InputGroup {
        var g = InputGroup(placeholder, text: $value).variant(variant).type(effectiveType).gapSpaced(gap)
        if showPrefix { g = g.prefix { prefixAffix } }
        if showSuffix { g = g.suffix { suffixAffix } }
        return g
    }

    @ViewBuilder private var prefixAffix: some View {
        switch type {
        case .text:     InputAffix().icon("globe")
        case .number:   InputAffix("$")
        case .password: InputAffix().icon("lock")
        }
    }

    @ViewBuilder private var suffixAffix: some View {
        switch type {
        case .text:
            InputAffix(action: { flash("Copied") }).icon("doc.on.doc").emphasis(.active).accessibilityLabel("Copy")
        case .number:
            InputAffix("USD", action: { flash("Currency") }).arrow().emphasis(.active)
        case .password:
            InputAffix(action: { reveal.toggle() })
                .icon(reveal ? "eye.slash" : "eye")
                .accessibilityLabel(reveal ? "Hide password" : "Show password")
        }
    }

    var body: some View {
        ComponentStage("InputGroup",
                       inspector: [("value", "\"\(value)\""), ("variant", variant.rawValue),
                                   ("type", type.rawValue), ("gapSpace", "\(gap)")]) {
            VStack(alignment: .leading, spacing: 20) {
                live.frame(width: 280)

                Text("Examples").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                // Country selector prefix (phone).
                InputGroup("(000) 000 - 0000", text: $phone)
                    .variant(variant).type(.number).gapSpaced()
                    .prefix { InputAffix("+1", action: { flash("Country") }).icon("phone").arrow().emphasis(.active) }
                    .frame(width: 280)
                // Keyboard-shortcut hint suffix.
                InputGroup("Command", text: $command)
                    .variant(variant)
                    .suffix { InputAffix("⌘ K") }
                    .frame(width: 280)
                // Badge suffix.
                InputGroup("Email address", text: $email)
                    .variant(variant)
                    .suffix { Badge("PRO").badgeStyle(.info) }
                    .frame(width: 280)
            }
        } knobs: {
            Picker("Variant", selection: $variant) {
                ForEach(InputGroupVariant.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Type", selection: $type) {
                ForEach(InputGroupType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Affix", selection: $affix) {
                Text("Both").tag(0); Text("Prefix").tag(1); Text("Suffix").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Gap spaced (divider)", isOn: $gap)
        }
    }
}

struct SelectDemo: View {
    @State private var city: String?
    @State private var clearable = true
    @State private var searchable = false
    @State private var loading = false
    @State private var disableSoldOut = false   // marks "Konya" disabled
    @State private var required = false
    @State private var filled = false

    private var selectView: some View {
        Select("City", sections: [
            .init("Marmara", ["Istanbul", "Bursa", "Kocaeli"]),
            .init("Aegean", ["Izmir", "Aydin", "Mugla"]),
            .init("Central Anatolia", ["Ankara", "Konya"]),
        ], selection: $city) { $0 }
        .clearable(clearable)
        .searchable(searchable)
        .loading(loading)
        .required(required)
        .optionEnabled(disableSoldOut ? { $0 != "Konya" } : nil)
    }

    var body: some View {
        ComponentStage("Select", inspector: [("style", filled ? "filled" : "default"), ("selection", city ?? "nil")]) {
            if filled {
                selectView.fieldStyle(.muted)   // filled chrome via the shared .fieldStyle(_:) axis
            } else {
                selectView
            }
        } knobs: {
            Toggle("Filled style (.fieldStyle)", isOn: $filled)
            Toggle("Searchable (inline panel + sections)", isOn: $searchable)
            Toggle("Required indicator", isOn: $required)
            Toggle("Allow clear", isOn: $clearable)
            Toggle("Loading (async)", isOn: $loading)
            Toggle("Disable \"Konya\"", isOn: $disableSoldOut)
            Text(searchable ? "Tap → expanding panel: search, loading & \"No results\" states." : "Tap → native Menu (grouped Sections).").font(.caption).foregroundStyle(.secondary)
            Button("Clear") { city = nil }
        }
    }
}

struct MultiSelectDemo: View {
    @State private var picks: Set<String> = ["Istanbul", "Ankara", "Izmir", "Bursa"]
    @State private var searchable = true
    @State private var clearable = true
    @State private var capTags = true
    @State private var capSelection = false
    @State private var enabled = true
    @State private var loading = false
    @State private var disableSoldOut = false   // marks "Adana" disabled
    private let cities = ["Istanbul", "Ankara", "Izmir", "Antalya", "Bursa", "Adana", "Konya"]

    var body: some View {
        ComponentStage("MultiSelect", inspector: [("count", "\(picks.count)"), ("maxSelection", capSelection ? "5" : "—")]) {
            MultiSelect("Cities", options: cities, selection: $picks) { $0 }
            .optionEnabled(disableSoldOut ? { $0 != "Adana" } : nil)
            .searchable(searchable)
            .clearable(clearable)
            .maxTags(capTags ? 2 : nil)
            .maxSelection(capSelection ? 5 : nil)
            .loading(loading)
            .disabled(!enabled)
        } knobs: {
            Toggle("Searchable", isOn: $searchable)
            Toggle("Allow clear", isOn: $clearable)
            Toggle("Max 2 tags (+N)", isOn: $capTags)
            Toggle("Max 5 selections (cap)", isOn: $capSelection)
            Toggle("Loading (async)", isOn: $loading)
            Toggle("Disable \"Adana\"", isOn: $disableSoldOut)
            Toggle("Enabled", isOn: $enabled)
            Button("Reset") { picks = ["Istanbul", "Ankara", "Izmir", "Bursa"] }
        }
    }
}

struct SelectBoxDemo: View {
    @State private var country: String? = "Turkey"
    @State private var error = false
    @State private var enabled = true
    @State private var required = false
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }
    var body: some View {
        ComponentStage("SelectBox", inspector: [("selection", country ?? "nil"), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            {
                let base = SelectBox("Country", options: ["Turkey", "Germany", "France"], selection: $country) { $0 }
                    .hint(error ? nil : "Pick your country")
                    .errorText(error ? "Required" : nil)
                    .required(required)
                return explicitSize.map { base.size($0) } ?? base
            }()
            .disabled(!enabled)
        } knobs: {
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
            Toggle("Required indicator", isOn: $required)
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
    @State private var helper = false
    @State private var warning = false
    @State private var autosize = false
    // All modifiers return `Self`, so the autosize toggle is a plain ternary.
    private var field: MultiLineTextInput {
        let base = MultiLineTextInput("Notes", text: $text)
            .placeholder("Write something…")
            .characterLimit(limit ? 200 : nil)
            .helperText(helper ? "Visible to the support team only." : nil)
            .warningText(warning ? "Avoid sharing personal data." : nil)
            .errorText(error ? "Required" : nil)
        return autosize ? base.autosize(minRows: 2, maxRows: 6) : base
    }
    var body: some View {
        ComponentStage("MultiLineTextInput", inspector: [("count", "\(text.count)"), ("autosize", "\(autosize)")]) {
            field
        } knobs: {
            Toggle("Autosize (2…6 rows)", isOn: $autosize)
            Toggle("Character limit", isOn: $limit)
            Toggle("Helper text", isOn: $helper)
            Toggle("Warning text", isOn: $warning)
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
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    @State private var lastComplete = "—"
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }
    var body: some View {
        ComponentStage("OTPInput", inspector: [("code", "\"\(code)\""), ("completed", lastComplete), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            {
                var base = OTPInput(code: $code, onComplete: { lastComplete = $0 })
                    .digitCount(six ? 6 : 4)
                    .secure(secure)
                    .errorText(error ? "Invalid code" : nil)
                if let explicitSize { base = base.size(explicitSize) }
                return resend ? base.resend(interval: 30, onResend: { lastComplete = "resent" }) : base
            }()
        } knobs: {
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
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
    @State private var rich = false
    var body: some View {
        ComponentStage("Tooltip", inspector: [("isPresented", "\(shown)"), ("edge", "\(edge)"), ("content", rich ? "custom view" : "text")]) {
            if rich {
                Icon(systemName: "info.circle").size(.lg).accent(.primary)
                    .tooltip(isPresented: $shown, edge: edge, style: colored ? .info : nil) {
                        HStack(spacing: 6) { Image(systemName: "wifi"); Text("Free Wi-Fi") }
                    }
                    .padding(60)
            } else {
                Icon(systemName: "info.circle").size(.lg).accent(.primary)
                    .tooltip("Helpful hint", isPresented: $shown, edge: edge, style: colored ? .info : nil)
                    .padding(60)
            }
        } knobs: {
            Toggle("Presented", isOn: $shown)
            Toggle("Custom content (icon + text)", isOn: $rich)
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
    // The group size is the kit's ButtonSize token — the full control-size ramp,
    // not a fixed sm/md/lg, so new sizes flow through automatically.
    private let sizes: [(label: String, size: ButtonSize?)] = [
        ("Default", nil), ("xxsmall", .xxsmall), ("xsmall", .xsmall),
        ("small", .small), ("medium", .medium), ("large", .large),
        ("xlarge", .xlarge), ("xxlarge", .xxlarge),
    ]

    @State private var horizontal = true
    @State private var sizeSel = 0
    @State private var fill = false
    @State private var dividers = false

    private var groupSize: ButtonSize? { sizes[sizeSel].size }
    private var sizeLabel: String { sizes[sizeSel].label }

    var body: some View {
        ComponentStage(
            "ButtonGroup",
            inspector: [("axis", horizontal ? "horizontal" : "vertical"),
                        ("size", sizeLabel),
                        ("width", fill ? "fill" : "hug"),
                        ("dividers", dividers ? "on" : "off")]
        ) {
            group
        } knobs: {
            Toggle("Horizontal", isOn: $horizontal)
            Toggle("Fill width", isOn: $fill)
            Toggle("Dividers", isOn: $dividers)
            Picker("Size", selection: $sizeSel) {
                ForEach(Array(sizes.enumerated()), id: \.offset) { index, item in
                    Text(item.label).tag(index)
                }
            }.pickerStyle(.menu)
        }
    }

    @ViewBuilder private var group: some View {
        let base = ButtonGroup(horizontal ? .horizontal : .vertical) {
            SecondaryButton("Cancel") { flash("Cancel") }
            PrimaryButton("Confirm") { flash("Confirm") }
        }
        .width(fill ? .fill : .hug)
        .dividers(dividers)

        if let groupSize {
            base.size(groupSize)
        } else {
            base
        }
    }
}

struct CheckboxGroupDemo: View {
    @State private var sel: Set<String> = ["Wifi"]
    @State private var selectAll = true
    @State private var enabled = true
    @State private var disableParking = false
    @State private var horizontal = false
    @State private var trailingControl = false
    @State private var description = false
    private let options = ["Wifi", "Pool", "Parking", "Breakfast"]
    var body: some View {
        ComponentStage("CheckboxGroup", inspector: [("selected", sel.sorted().joined(separator: ", ")), ("axis", horizontal ? "horizontal" : "vertical")]) {
            CheckboxGroup(title: "Amenities", options: options, selection: $sel) { $0 }
                .description(description ? "Included with every room." : nil)
                .selectAll(selectAll ? "Select all" : nil)
                .optionEnabled(disableParking ? { $0 != "Parking" } : nil)
                .axis(horizontal ? .horizontal : .vertical)
                .controlPlacement(trailingControl ? .trailing : .leading)
                .disabled(!enabled)
        } knobs: {
            Toggle("Horizontal axis", isOn: $horizontal)
            Toggle("Trailing control placement", isOn: $trailingControl)
            Toggle("Group description", isOn: $description)
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
    @State private var trailingControl = false
    @State private var description = false
    private var optionEnabled: ((String) -> Bool)? { disableFirst ? { $0 != "First" } : nil }

    var body: some View {
        ComponentStage("RadioGroup", inspector: [("selection", sel ?? "nil"), ("style", styleIdx == 0 ? "stacked" : styleIdx == 1 ? "button/solid" : "button/outline"), ("enabled", "\(enabled)")]) {
            switch styleIdx {
            case 1:
                RadioButtonGroup(options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .groupStyle(.solid).fullWidth().optionEnabled(optionEnabled)
                    .disabled(!enabled)
            case 2:
                RadioButtonGroup(options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .groupStyle(.outline).fullWidth().optionEnabled(optionEnabled)
                    .disabled(!enabled)
            default:
                RadioGroup(title: "Class", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .description(description ? "Fares differ by cabin class." : nil)
                    .controlPlacement(trailingControl ? .trailing : .leading)
                    .optionEnabled(optionEnabled)
                    .disabled(!enabled)
            }
        } knobs: {
            Picker("Style", selection: $styleIdx) { Text("Stacked").tag(0); Text("Button solid").tag(1); Text("Button outline").tag(2) }.pickerStyle(.segmented)
            if styleIdx == 0 {
                Toggle("Trailing control placement", isOn: $trailingControl)
                Toggle("Group description", isOn: $description)
            }
            Toggle("Enabled (whole group)", isOn: $enabled)
            Toggle("Disable “First” option", isOn: $disableFirst)
            Button("Clear") { sel = nil }
        }
    }
}

struct ToggleGroupDemo: View {
    @State private var sel: Set<String> = ["push"]
    @State private var horizontal = false
    @State private var accented = false
    @State private var disableSms = false
    var body: some View {
        ComponentStage("ToggleGroup", inspector: [("on", sel.sorted().joined(separator: ", ")), ("axis", horizontal ? "horizontal" : "vertical")]) {
            ToggleGroup(title: "Notifications", options: ["push", "email", "sms"], selection: $sel,
                        label: { ["push": "Push", "email": "Email", "sms": "SMS"][$0] ?? $0 })
                .optionDescription { _ in horizontal ? nil : "Supporting text." }
                .optionEnabled(disableSms ? { $0 != "sms" } : nil)
                .accent(accented ? .success : nil)
                .axis(horizontal ? .horizontal : .vertical)
        } knobs: {
            Toggle("Horizontal axis", isOn: $horizontal)
            Toggle("Accent (success)", isOn: $accented)
            Toggle("Disable “SMS”", isOn: $disableSms)
            Button("Enable all") { sel = ["push", "email", "sms"] }
        }
    }
}

struct AutocompleteDemo: View {
    @State private var text = ""
    @State private var asyncMode = false
    @State private var disableSoldOut = false
    @State private var clearable = false
    @State private var externalLoading = false
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    private let cities = ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa"]
    private var enabledPredicate: ((String) -> Bool)? {
        disableSoldOut ? { $0 != "Izmit" } : nil
    }
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }
    var body: some View {
        ComponentStage("Autocomplete", inspector: [("text", "\"\(text)\""), ("mode", asyncMode ? "async" : "static"), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            if asyncMode {
                {
                    let base = Autocomplete("Destination", text: $text, suggest: { query in
                        try? await Task.sleep(nanoseconds: 400_000_000)   // simulate network
                        return cities.filter { $0.localizedCaseInsensitiveContains(query) }
                    })
                    .suggestionEnabled(enabledPredicate)
                    .clearable(clearable)
                    .loading(externalLoading)
                    return explicitSize.map { base.size($0) } ?? base
                }()
            } else {
                {
                    let base = Autocomplete("Destination", text: $text, suggestions: cities)
                        .suggestionEnabled(enabledPredicate)
                        .clearable(clearable)
                        .loading(externalLoading)
                    return explicitSize.map { base.size($0) } ?? base
                }()
            }
        } knobs: {
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
            Toggle("Async (remote-style)", isOn: $asyncMode)
            Toggle("Clearable", isOn: $clearable)
            Toggle("Loading (external)", isOn: $externalLoading)
            Toggle("Disable “Izmit”", isOn: $disableSoldOut)
            Text("Type to filter suggestions.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Organisms

struct CardDemo: View {
    private enum Kind: String, CaseIterable { case text = "Text", form = "Form", image = "Image", overlay = "Overlay" }
    @State private var kind: Kind = .text
    @State private var variantIdx = 0   // 0 default (shadow), 1 outlined (bordered), 2 flat
    @State private var elevation: CardElevation = .soft
    @State private var radius: Theme.RadiusRole = .box     // corner size axis
    @State private var surfaceIdx = 0   // 0 white, 1 secondary, 2 tertiary
    @State private var padding: Theme.SpacingKey = .base
    @State private var tappable = false
    @State private var header = true
    @State private var loading = false
    @State private var selected = false
    @State private var email = ""
    @State private var taps = 0

    private var surfaceKey: Theme.BackgroundColorKey {
        switch surfaceIdx {
        case 1: return .bgSecondaryLight
        case 2: return .bgTertiary
        default: return .bgWhite
        }
    }

    /// A placeholder "photo" standing in for a cover image in the demo.
    private var coverImage: some View {
        LinearGradient(colors: [.pink.opacity(0.55), .orange.opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "photo").font(.title).foregroundStyle(.white))
    }

    @ViewBuilder
    private var cardBody: some View {
        switch kind {
        case .text:
            Card(header ? "Reservation" : nil,
                 action: tappable ? { taps += 1; flash("Card tapped") } : nil) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tappable ? "Tappable card" : "Card body").textStyle(.headingSm)
                    Text(tappable ? "Press me — scales with feedback." : "Supporting body text inside a card surface.")
                        .textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
            }
            .overline(header ? "NEW" : nil)
            .subtitle(header ? "2 nights · 2 guests" : nil)
            .extraAction(header ? "Details" : nil, action: header ? { flash("Details") } : nil)
            .loading(loading)
            .elevation(elevation).radius(radius).surface(surfaceKey).selected(selected).contentPadding(padding)
        case .form:
            Card(header ? "Log in" : nil) {
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    TextInput("Email", text: $email)
                    ThemeButton("Sign in") { flash("Sign in") }.fullWidth()
                }
            }
            .subtitle(header ? "Welcome back" : nil)
            .elevation(elevation).radius(radius).surface(surfaceKey).selected(selected).contentPadding(padding)
            .frame(maxWidth: 280)
        case .image:
            Card { EmptyView() }
                .cover { coverImage.frame(height: 140) }
                .footer {
                    HStack {
                        Text("Fruits").textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary))
                        Spacer(minLength: 0)
                        Text("18 pictures").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
                .elevation(elevation).radius(radius).surface(surfaceKey).selected(selected)
                .frame(width: 220)
        case .overlay:
            Card { EmptyView() }
                .cover(.fill) { coverImage.frame(width: 220, height: 260) }
                .header {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEO").textStyle(.labelSm600).foregroundStyle(.white.opacity(0.85))
                        Text("Home Robot").textStyle(.labelLg600).foregroundStyle(.white)
                    }
                }
                .footer {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available soon").textStyle(.labelMd600).foregroundStyle(.white)
                            Text("Get notified").textStyle(.bodySm400).foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                        ThemeButton("Notify me") { flash("Notify me") }.size(.small)
                    }
                }
                .elevation(elevation).radius(radius).selected(selected)
        }
    }

    // Distinct return types per style, so branch through the `.cardStyle(_:)` modifier.
    @ViewBuilder private var styledCard: some View {
        switch variantIdx {
        case 1: cardBody.cardStyle(.outlined)
        case 2: cardBody.cardStyle(.flat)
        default: cardBody.cardStyle(.default)
        }
    }

    private var variantName: String { variantIdx == 1 ? "outlined" : variantIdx == 2 ? "flat" : "default" }

    var body: some View {
        ComponentStage("Card", inspector: [("kind", kind.rawValue), ("variant", variantName), ("elevation", "\(elevation)"), ("radius", radius.rawValue), ("selected", "\(selected)")]) {
            styledCard
        } knobs: {
            Picker("Content", selection: $kind) {
                ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Variant", selection: $variantIdx) { Text("Default").tag(0); Text("Outlined").tag(1); Text("Flat").tag(2) }.pickerStyle(.segmented)
            Picker("Elevation", selection: $elevation) { Text("None").tag(CardElevation.none); Text("Soft").tag(CardElevation.soft); Text("Elevated").tag(CardElevation.elevated) }.pickerStyle(.segmented)
            Picker("Radius (size)", selection: $radius) { Text("Selector").tag(Theme.RadiusRole.selector); Text("Field").tag(Theme.RadiusRole.field); Text("Box").tag(Theme.RadiusRole.box) }.pickerStyle(.segmented)
            Picker("Surface", selection: $surfaceIdx) { Text("White").tag(0); Text("Secondary").tag(1); Text("Tertiary").tag(2) }.pickerStyle(.segmented)
            Toggle("Selected (hero border)", isOn: $selected)
            Toggle("Header (title + overline + extra)", isOn: $header)
            Toggle("Loading (skeleton)", isOn: $loading)
            Toggle("Tappable (press feedback)", isOn: $tappable)
            Picker("Padding", selection: $padding) {
                ForEach([Theme.SpacingKey.none, .xs, .sm, .md, .base, .lg], id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
    }
}

struct EmptyStateDemo: View {
    @State private var hasButton = true
    @State private var secondary = false
    @State private var customImage = false
    @State private var tintIcon = false
    @State private var animated = false
    @State private var inlineLink = false
    @State private var actionsSlot = false
    private let gifURL = URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/d3/Newtons_cradle_animation_book_2.gif")
    var body: some View {
        ComponentStage("EmptyState", inspector: [("media", animated ? "gif" : customImage ? "custom" : "symbol"), ("actions", actionsSlot ? "slot" : "stock")]) {
            if animated {
                EmptyState(animatedURL: gifURL, title: "Loading")
                    .imageMaxHeight(140)
                    .message("Preparing content…")
                    .primaryAction(hasButton ? "Refresh" : nil, action: hasButton ? { flash("EmptyState: Refresh") } : nil)
            } else if customImage {
                EmptyState(image: Image(systemName: "sailboat.fill"), title: "Your cart is empty")
                    .imageMaxHeight(120)
                    .message("You haven't added anything yet.")
                    .primaryAction(hasButton ? "Explore" : nil, action: hasButton ? { flash("EmptyState: Explore") } : nil)
            } else {
                {
                    var base = EmptyState("No results found")
                        .icon("magnifyingglass")
                        .iconCircleSize(tintIcon ? 104 : 88)
                    if tintIcon {
                        base = base.iconForeground(.systemcolorsFgWarning).iconBackground(.systemcolorsBgWarningLight)
                    }
                    base = inlineLink
                        ? base.message("Try adjusting your filters or read the search tips.",
                                       links: [("search tips", { flash("EmptyState: search tips") })])
                        : base.message("Try adjusting your search or filters.")
                    if actionsSlot {
                        return base.actions {
                            ButtonGroup(.horizontal) {
                                SecondaryButton("Learn more") { flash("EmptyState: Learn more") }.size(.small)
                                PrimaryButton("Clear filters") { flash("EmptyState: Clear filters") }.size(.small)
                            }
                        }
                    }
                    return base
                        .primaryAction(hasButton ? "Clear filters" : nil, action: hasButton ? { flash("EmptyState: Clear filters") } : nil)
                        .secondaryAction(secondary ? "Learn more" : nil, action: secondary ? { flash("EmptyState: Learn more") } : nil)
                }()
            }
        } knobs: {
            Toggle("Animated illustration (GIF, native)", isOn: $animated)
            Toggle("Custom illustration", isOn: $customImage)
            Toggle("Tinted + larger icon", isOn: $tintIcon)
            Toggle("Inline tappable link (symbol)", isOn: $inlineLink)
            Toggle("Actions slot (ButtonGroup)", isOn: $actionsSlot)
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
        case .button: return .button("Edit", action: { flash("ListRow: Edit") })
        case .price: return .price(.init(total: "$14,400", each: "$1,200", unit: "/ month"))
        case .status: return .status("Available", systemImage: "checkmark.seal.fill")
        case .none: return .none
        }
    }

    private var imageURL: URL? { URL(string: "https://picsum.photos/seed/listrow/120") }
    private var meta: ListRowMeta? { withMeta ? ListRowMeta(rating: 8.4, sentiment: "Excellent", commentLabel: "1,284 reviews") : nil }
    private var infos: [ListRowInfo] {
        moreInfo ? [ListRowInfo(systemImage: "checkmark", "Free cancellation"),
                    ListRowInfo(systemImage: "wifi", "Free wifi"),
                    ListRowInfo("No payment on arrival")] : []
    }

    var body: some View {
        ComponentStage("ListRow", inspector: [("trailing", kind.rawValue), ("leading", lead.rawValue)]) {
            VStack(spacing: 0) {
                ListSectionHeader("Accommodation")
                ListRow("Grand Hotel Istanbul", action: { flash("ListRow tapped") })
                    .subtitle(subtitle ? "Sea view · Breakfast included" : nil)
                    .number(lead == .number ? 1 : nil)
                    .icon(lead == .icon ? "building.2" : nil)
                    .leadingImage(lead == .image ? imageURL : nil)
                    .leadingSelection(lead == .radio ? $picked : nil)
                    .alertCount(alert ? 3 : nil)
                    .meta(meta).infos(infos).selected(selected)
                    .multilineTitle(moreInfo)
                    .onInfo(kind == .price ? { flash("ListRow: price info") } : nil)
                    .trailing(trailing)
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
    @State private var inlineAction = false
    @State private var closable = false
    @State private var typed = false
    private var type: FeedbackKind? { typed ? .success : nil }
    var body: some View {
        ComponentStage("NotificationCard", inspector: [("isUnread", "\(unread)"), ("action", actions ? "slot" : inlineAction ? "inline" : "—")]) {
            if actions {
                NotificationCard(title: "We Have a Suggestion for Your Holiday") {
                    ButtonGroup(.horizontal) {
                        SecondaryButton("Later") { flash("Notification: Later") }.size(.small)
                        PrimaryButton("View") { flash("Notification: View") }.size(.small)
                    }
                }
                .message("24 days left until your Hilton Istanbul reservation.")
                .date("December 5, 2024")
                .unread(unread)
                .variant(type)
                .onClose(closable ? { flash("Notification dismissed") } : nil)
            } else {
                {
                    let base = NotificationCard(title: "We Have a Suggestion for Your Holiday")
                        .message("24 days left until your Hilton Istanbul reservation.")
                        .date("December 5, 2024")
                        .unread(unread)
                        .variant(type)
                        .onClose(closable ? { flash("Notification dismissed") } : nil)
                    return inlineAction ? base.action("View") { flash("Notification: View") } : base
                }()
            }
        } knobs: {
            Toggle("Unread", isOn: $unread)
            Toggle("Actions (custom slot)", isOn: $actions)
            if !actions { Toggle("Inline action (View)", isOn: $inlineAction) }
            Toggle("Type (success icon)", isOn: $typed)
            Toggle("Closable", isOn: $closable)
        }
    }
}

struct PageHeaderDemo: View {
    enum Variant: String, CaseIterable, Identifiable {
        case iconButtons = "Header · Icon Buttons"
        case header = "Header"
        case tabs = "Tab"
        case progress = "Progress"
        case stepper = "Stepper"
        case withButton = "with Button"
        case withSearchBar = "With Search Bar"
        case searchInput = "with search Input"
        case brand = "Brand"
        case brandNoBg = "brand-no bg"
        case onImage = "On Image"
        case wsbOnImage = "With Search Bar · On Image"
        case onMap = "On Map"
        var id: String { rawValue }

        // Which of the design-system variables this style exposes (mirrors Figma).
        var hasBackNav: Bool { ![.withButton, .brand, .brandNoBg].contains(self) }
        var hasActions: Bool { ![.brand, .brandNoBg, .searchInput].contains(self) }
        var hasShowTitle: Bool { [.header, .tabs, .progress, .stepper, .withButton, .onImage, .onMap].contains(self) }
        var hasTitleField: Bool { hasShowTitle || self == .iconButtons }
        var hasSummary: Bool { [.iconButtons, .withSearchBar, .wsbOnImage, .onMap].contains(self) }
    }

    @State private var variant: Variant = .iconButtons
    // Common variables
    @State private var backNav = true
    @State private var firstAction = true
    @State private var secAction = true
    @State private var showTitle = true
    @State private var titleText = "Title"
    // Style-specific
    @State private var progressValue = 0.5
    @State private var tab = 0
    @State private var query = ""
    // Search summary variables
    @State private var summarySelected = false
    @State private var summaryBg = false
    @State private var timeText = "12 – 16 Jul"
    @State private var adults = 2
    @State private var showChild = true
    @State private var childCount = 1
    @State private var showRoom = true
    @State private var roomCount = 1

    /// Builds the bound ``SearchSummary`` sub-component from the live knobs.
    private func makeSummary(title: String? = nil, forceBoxed: Bool = false) -> SearchSummary {
        var s = SearchSummary(time: timeText, adults: adults)
        if let title { s = s.title(title) }
        if showChild { s = s.children(childCount) }
        if showRoom { s = s.rooms(roomCount) }
        s = s.boxed(forceBoxed || summaryBg)
        if summarySelected { s = s.prompt("Select dates for price") }   // Figma "Selected" = empty prompt
        return s
    }

    /// Trailing actions gated by the First/Sec Action toggles (Figma order: sec, first).
    private func actions(sec: PageHeader.Action, first: PageHeader.Action) -> [PageHeader.Action] {
        var a: [PageHeader.Action] = []
        if secAction { a.append(sec) }
        if firstAction { a.append(first) }
        return a
    }
    private var onBackAction: (() -> Void)? { backNav ? { flash("Back") } : nil }

    var body: some View {
        ComponentStage("PageHeader", inspector: [("style", variant.rawValue)]) {
            headerView(variant)
        } knobs: {
            Picker("Variant", selection: $variant) {
                ForEach(Variant.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            if variant.hasShowTitle { Toggle("Show Title", isOn: $showTitle) }
            if variant.hasTitleField && (!variant.hasShowTitle || showTitle) {
                HStack { Text("Title"); TextField("Title", text: $titleText).multilineTextAlignment(.trailing) }
            }
            if variant.hasBackNav { Toggle("Back Navigation Icon", isOn: $backNav) }
            if variant.hasActions {
                Toggle("First Action Items", isOn: $firstAction)
                Toggle("Sec Action Item", isOn: $secAction)
            }
            if variant == .progress {
                HStack { Text("Progress Value"); SwiftUI.Slider(value: $progressValue, in: 0...1) }
            }
            if variant.hasSummary {
                Text("Search summary").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Toggle("Selected", isOn: $summarySelected)
                Toggle("Bg", isOn: $summaryBg)
                HStack { Text("Time"); TextField("Time", text: $timeText).multilineTextAlignment(.trailing) }
                Stepper("Adult Number: \(adults)", value: $adults, in: 1...30)
                Toggle("Show child", isOn: $showChild)
                if showChild { Stepper("Child Number: \(childCount)", value: $childCount, in: 0...20) }
                Toggle("Show room", isOn: $showRoom)
                if showRoom { Stepper("Room Number: \(roomCount)", value: $roomCount, in: 1...20) }
            }
        }
    }

    @ViewBuilder private func headerView(_ variant: Variant) -> some View {
        let compare = PageHeader.Action(systemImage: "square.on.square", accessibilityLabel: "Compare") { flash("Compare") }
        let search = PageHeader.Action(systemImage: "magnifyingglass", accessibilityLabel: "Search") { flash("Search") }
        let save = PageHeader.Action(systemImage: "heart", accessibilityLabel: "Save") { flash("Save") }
        let share = PageHeader.Action(systemImage: "square.and.arrow.up", accessibilityLabel: "Share") { flash("Share") }
        let close = PageHeader.Action(systemImage: "xmark", accessibilityLabel: "Close") { flash("Close") }
        switch variant {
        case .iconButtons:
            PageHeader(titleText)
                .onBack(onBackAction)
                .searchSummary(makeSummary(title: titleText))
                .actions(actions(sec: compare, first: search))
        case .header:
            PageHeader(titleText).showTitle(showTitle)
                .onBack(onBackAction)
                .actions(actions(sec: compare, first: search))
        case .tabs:
            PageHeader(titleText).showTitle(showTitle)
                .onBack(onBackAction)
                .tabs(["Tab 1", "Tab 2", "Tab 3", "Tab 4", "Tab 5"], selected: tab) { tab = $0 }
                .actions(actions(sec: compare, first: search))
        case .progress:
            PageHeader(titleText).showTitle(showTitle).onBack(onBackAction).progress(progressValue)
                .actions(actions(sec: compare, first: search))
        case .stepper:
            PageHeader(titleText).showTitle(showTitle).onBack(onBackAction).stepper(current: 1, total: 3)
                .actions(actions(sec: compare, first: search))
        case .withButton:
            withButtonHeader(search: search)
        case .withSearchBar:
            PageHeader(titleText)
                .onBack(onBackAction)
                .searchSummary(makeSummary(forceBoxed: true))
                .actions(actions(sec: save, first: share))
        case .searchInput:
            PageHeader("Search").onBack(onBackAction)
                .searchField(text: $query, placeholder: "Search") { flash("Submit: \(query)") }
        case .brand:
            PageHeader("Brand")
                .logo(Text("etstur").font(.system(size: 22, weight: .heavy)).foregroundStyle(SemanticColor.primary.onSolid))
                .pageHeaderStyle(.brand)
        case .brandNoBg:
            PageHeader("Brand")
                .logo(Text("etstur").font(.system(size: 22, weight: .heavy)).foregroundStyle(SemanticColor.primary.accent))
                .pageHeaderStyle(.brandNoBackground)
        case .onImage:
            PageHeader(titleText).showTitle(showTitle)
                .onBack(onBackAction)
                .actions(actions(sec: save, first: close))
                .pageHeaderStyle(.onImage)
                .padding(.vertical, 24)
                .background(Color(white: 0.75))
        case .wsbOnImage:
            PageHeader(titleText)
                .onBack(onBackAction)
                .searchSummary(makeSummary(forceBoxed: true))
                .actions(actions(sec: save, first: share))
                .pageHeaderStyle(.onImage)
                .padding(.vertical, 24)
                .background(Color(white: 0.75))
        case .onMap:
            PageHeader(titleText)
                .onBack(onBackAction)
                .searchSummary(makeSummary(title: showTitle ? titleText : nil))
                .mapFilter(systemImage: "line.3.horizontal.decrease", accessibilityLabel: "Filter") { flash("Filter") }
                .pageHeaderStyle(.onImage)
                .padding(.vertical, 24)
                .background(Color(white: 0.8))
        }
    }

    /// with Button: sec = the brand pill, first = the search icon (Figma order).
    @ViewBuilder private func withButtonHeader(search: PageHeader.Action) -> some View {
        let base = PageHeader(titleText).showTitle(showTitle)
            .actions(firstAction ? [search] : [])
        if secAction {
            base.primaryButton("Notify me", systemImage: "megaphone.fill") { flash("Notify me") }
        } else {
            base
        }
    }
}

struct RatingSummaryDemo: View {
    @State private var score = 9.0
    @State private var reviews = true
    var body: some View {
        ComponentStage("RatingSummary", inspector: [("score", String(format: "%.1f", score))]) {
            RatingSummary(score: score).label("Excellent").reviews(count: reviews ? 1200 : nil, onTap: reviews ? { flash("Reviews tapped") } : nil)
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
            BlogCard(title: "How About Exploring Cappadocia on Your Own?") {
                Theme.shared.background(.bgTertiary)
            }
            .excerpt("To some a miracle of nature, to others a fairyland…")
            .compact(compact)
            .readMore { flash("BlogCard: read more") }
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
            Gallery(photos) { $0.color.opacity(0.3) }.columns(Int(columns)).aspect(aspect)
        } knobs: {
            Stepper("Columns: \(Int(columns))", value: $columns, in: 1...4, step: 1)
            Picker("Aspect", selection: $aspect) {
                Text("1:1").tag(AspectRatioToken.square); Text("4:3").tag(AspectRatioToken.landscape4x3); Text("16:9").tag(AspectRatioToken.landscape16x9); Text("3:4").tag(AspectRatioToken.portrait3x4)
            }.pickerStyle(.segmented)
        }
    }
}

struct UploadDemo: View {
    private struct DemoUploadError: LocalizedError { var errorDescription: String? { "File too large" } }

    @StateObject private var uploads = UploadController()
    @State private var counter = 0
    @State private var picked: [UploadFile] = []

    var body: some View {
        ComponentStage("Upload", inspector: [("files", "\(uploads.files.count)"), ("picked", "\(picked.count)/3")]) {
            VStack(spacing: 20) {
                UploadList(controller: uploads) { start(fail: false) }
                Upload(prompt: "You can upload up to 3 photos.",
                       files: picked,
                       onPick: { picked.append(.init(name: "img-\(picked.count + 1).jpg", status: .done)) },
                       onRemove: { file in picked.removeAll { $0.id == file.id } })
                    .buttonTitle("Add photo").maxCount(3)
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

// MARK: - Additional components

struct RadialProgressDemo: View {
    @State private var value = 0.6
    @State private var label = true
    @State private var dashboard = false
    @State private var statusIdx = 0
    private var status: ProgressStatus { statusIdx == 1 ? .success : statusIdx == 2 ? .exception : .normal }
    var body: some View {
        ComponentStage("RadialProgress", inspector: [("value", String(format: "%.2f", value)), ("dashboard", "\(dashboard)")]) {
            RadialProgress(value).size(96).lineWidth(8).showsLabel(label).status(status).dashboard(dashboard)
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
                    Icon(systemName: "bell").size(.xl).accent(.neutral).indicatorDot(position: position)
                } else {
                    Icon(systemName: "envelope").size(.xl).accent(.neutral).indicator(position) { Badge("3").badgeStyle(.error).size(.small) }
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
            Stat(title: "Total bookings", value: count)
                .suffix("$").loading(loading).description("this month")
                .icon(figure ? "ticket" : nil).trend(statTrend)
        } else {
            Stat(title: "Total bookings", value: "1,284")
                .suffix("$").loading(loading).description("this month")
                .icon(figure ? "ticket" : nil).trend(statTrend)
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
    @State private var subtitles = false
    @State private var controlled = false
    @State private var disableReview = false
    private let titles = ["Cart", "Address", "Payment", "Done"]
    private let subs = ["2 items", "Istanbul", "Card ••42", "Confirm"]
    private let subtitleTexts = ["2 items", "Home", "Visa", "Ready"]
    private var steps: [Steps.Step] {
        titles.enumerated().map { i, t in
            // With `controlled`, leave state at its default and let `.current(_:)`
            // derive it; otherwise derive it here as before.
            let state: StepState = (error && i == active) ? .error
                : controlled ? .todo
                : i < active ? .done : i == active ? .active : .todo
            return .init(t, subTitle: subtitles ? subtitleTexts[i] : nil,
                         description: descriptions ? subs[i] : nil, state: state,
                         disabled: disableReview && i == 2,
                         percent: (percent && state == .active) ? 0.6 : nil)
        }
    }
    @State private var small = false
    var body: some View {
        ComponentStage("Steps", inspector: [("active", "\(active)"),
                                            ("current", controlled ? "\(active)" : "—")]) {
            Steps(steps) { active = $0; flash("Step \($0 + 1) selected") }
                .axis(vertical ? .vertical : .horizontal)
                .progressDot(progressDot)
                .size(small ? .small : .medium)
                .current(controlled ? active : nil)
        } knobs: {
            Stepper("Active: \(active)", value: $active, in: 0...3)
            Text("Tip: tap a step to jump to it.").font(.caption).foregroundStyle(.secondary)
            Toggle("Controlled .current(active)", isOn: $controlled)
            Toggle("Subtitles", isOn: $subtitles)
            Toggle("Disable “Payment” step", isOn: $disableReview)
            Toggle("Small size", isOn: $small)
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
    private let all = ["Home", "Hotels", "Turkey", "Marmara", "Istanbul", "Grand Hotel"]
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
    @State private var customMarkers = false
    private var modeLabel: String {
        switch mode { case .left: return "left"; case .right: return "right"; case .alternate: return "alternate" }
    }
    var body: some View {
        ComponentStage("Timeline", inspector: [("active", "\(Int(step))"), ("axis", horizontal ? "horizontal" : "vertical"), ("mode", modeLabel), ("marker", customMarkers ? "custom" : "stock")]) {
            {
                let base = Timeline([
                    .init(title: "Order", time: "09:24", systemImage: "cart", state: .done, color: .success),
                    .init(title: "Preparing", time: "09:40", systemImage: "shippingbox", state: Int(step) > 1 ? .done : .active),
                    failed
                        ? .init(title: "Error", time: "09:45", description: horizontal ? nil : "Try your card again.", state: .error)
                        : .init(title: "On the way", time: "—", systemImage: "truck.box", state: Int(step) > 2 ? .done : Int(step) == 2 ? .active : .todo),
                ])
                .axis(horizontal ? .horizontal : .vertical).mode(mode).reversed(reverse)
                .pending((!horizontal && pending) ? "Waiting for courier…" : nil)
                if customMarkers {
                    return base.marker { _, index in
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.shared.foreground(.fgHero)))
                    }
                }
                return base
            }()
        } knobs: {
            Stepper("Active: \(Int(step))", value: $step, in: 0...3)
            Toggle("Custom markers (numbered)", isOn: $customMarkers)
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
            ChatBubble("Hello! Your reservation is confirmed.",
                       author: meta ? "Support" : nil, time: meta ? "09:24" : nil)
                .side(outgoing ? .outgoing : .incoming)
                .icon(avatar ? "person.fill" : nil)
        } knobs: {
            Toggle("Outgoing", isOn: $outgoing)
            Toggle("Avatar", isOn: $avatar)
            Toggle("Author / time", isOn: $meta)
        }
    }
}

struct DrawerDemo: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var drawer: DrawerPresenter
    @State private var open = false
    @State private var edge: Edge = .bottom
    @State private var showClose = true
    @State private var name = ""
    @State private var email = ""

    private var edgeLabel: String {
        switch edge {
        case .bottom: return "bottom"
        case .top: return "top"
        case .leading: return "leading"
        case .trailing: return "trailing"
        }
    }

    /// The Figma "Edit Profile" panel — a slotted drawer reused by both entry points.
    @ViewBuilder private func editProfile(dismiss: @escaping () -> Void) -> some View {
        Drawer {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                TextInput("Name", text: $name)
                TextInput("Email", text: $email)
            }
        }
        .heading { Text("Edit Profile") }
        .showsCloseButton(showClose)
        .footer {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ThemeButton("Cancel") { dismiss() }.variant(.ghost).size(.small)
                ThemeButton("Done") { dismiss(); flash("Saved") }.size(.small)
            }
        }
    }

    var body: some View {
        ComponentStage("Drawer", inspector: [("isPresented", "\(open)"), ("edge", edgeLabel)]) {
            PrimaryButton("Open \(edgeLabel) drawer") { open = true; flash("Drawer opened") }
                .frame(maxWidth: .infinity, minHeight: 160)
                .drawer(isPresented: $open, edge: edge) {
                    editProfile(dismiss: { open = false })
                }
        } knobs: {
            Picker("Edge", selection: $edge) {
                Text("Bottom").tag(Edge.bottom)
                Text("Top").tag(Edge.top)
                Text("Leading").tag(Edge.leading)
                Text("Trailing").tag(Edge.trailing)
            }
            .pickerStyle(.segmented)
            Toggle("Close button", isOn: $showClose)
            Button("Open (imperative host)") {
                drawer.present(edge: edge) {
                    editProfile(dismiss: { drawer.dismiss() })
                }
            }
            Text("Drag the panel toward its edge to dismiss; the handle grabs bottom/top sheets.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Additional components (batch 2)

struct StatusDotDemo: View {
    @State private var kind: StatusKind = .online
    @State private var pulse = true
    var body: some View {
        ComponentStage("Status", inspector: [("kind", "\(kind)")]) {
            StatusDot(kind, label: "Status").size(14).pulse(pulse)
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
                if pair == .menu { Swap(isOn: $on).symbols(on: "xmark", off: "line.3.horizontal").size(32) }
                else { Swap(isOn: $on).symbols(on: "moon.fill", off: "sun.max.fill").size(32) }
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
            TextLink("Forgot password?") {}.underline(underline)
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
            Hero(title: dark ? "Summer Sale" : "Discover Istanbul")
                .subtitle(subtitle ? "Hand-picked stays at the best prices." : nil)
                .cta(cta ? "Explore" : nil, action: cta ? { flash("Hero: Explore") } : nil)
                .dark(dark)
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
            ] : [], action: { flash("FAB tapped") })
            .shape(square ? .square : .circle).accent(color).badge(badge ? 3 : nil)
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
    @State private var multiDates: Set<Date> = []
    @State private var yearPicker = false
    @State private var multiple = false
    @State private var noWeekends = false
    var body: some View {
        ComponentStage("Calendar", inspector: [
            ("selection", multiple ? "\(multiDates.count) day(s)"
                : (date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "nil")),
            ("multiple", "\(multiple)"),
            ("disabledWeekends", "\(noWeekends)")
        ]) {
            calendar
        } knobs: {
            Toggle("Multiple selection", isOn: $multiple)
            Toggle("Disable weekends", isOn: $noWeekends)
            Toggle("Tappable header (.yearPicker)", isOn: $yearPicker)
            Button("Clear") { date = nil; multiDates = [] }
        }
    }

    // Both selection inits return `CalendarView`, so the shared modifiers apply
    // uniformly regardless of single/multiple mode.
    @ViewBuilder private var calendar: some View {
        if multiple {
            configured(CalendarView(selection: $multiDates))
        } else {
            configured(CalendarView(selection: $date))
        }
    }

    private func configured(_ view: CalendarView) -> CalendarView {
        var view = view
        if yearPicker { view = view.yearPicker() }
        if noWeekends { view = view.disabledDates { Calendar.current.isDateInWeekend($0) } }
        return view
    }
}

// MARK: - HeroUI catalog-gap components (Wave 1)

struct TrendChipDemo: View {
    enum Dir: String, CaseIterable { case up, down }
    @State private var dir: Dir = .up
    @State private var size: TrendChipSize = .medium
    @State private var showsIcon = true
    @State private var positiveIsUp = true
    private var trend: StatTrend { dir == .up ? .up("+12%") : .down("-8%") }
    var body: some View {
        ComponentStage("TrendChip", inspector: [("dir", dir.rawValue), ("positiveIsUp", "\(positiveIsUp)")]) {
            TrendChip(trend).size(size).showsIcon(showsIcon).positiveIsUp(positiveIsUp)
        } knobs: {
            Picker("Direction", selection: $dir) { ForEach(Dir.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Picker("Size", selection: $size) { Text("Small").tag(TrendChipSize.small); Text("Medium").tag(TrendChipSize.medium) }.pickerStyle(.segmented)
            Toggle("Shows icon", isOn: $showsIcon)
            Toggle("Positive is up (down = red)", isOn: $positiveIsUp)
        }
    }
}

struct ColorSwatchDemo: View {
    enum Shape: String, CaseIterable { case square, circle }
    @State private var shape: Shape = .square
    @State private var size: ColorSwatchSize = .medium
    @State private var selected = true
    private var swatchShape: ColorSwatchShape { shape == .square ? .square : .circle }
    var body: some View {
        ComponentStage("ColorSwatch", inspector: [("shape", shape.rawValue), ("selected", "\(selected)")]) {
            HStack(spacing: 16) {
                ColorSwatch(.red, label: "Red").shape(swatchShape).size(size).selected(selected)
                ColorSwatch(.blue, label: "Blue").shape(swatchShape).size(size)
                ColorSwatch(.green.opacity(0.4), label: "Faded green").shape(swatchShape).size(size)
            }
        } knobs: {
            Picker("Shape", selection: $shape) { ForEach(Shape.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Picker("Size", selection: $size) { Text("S").tag(ColorSwatchSize.small); Text("M").tag(ColorSwatchSize.medium); Text("L").tag(ColorSwatchSize.large) }.pickerStyle(.segmented)
            Toggle("First selected", isOn: $selected)
        }
    }
}

struct ColorSwatchPickerDemo: View {
    private let palette: [ColorSwatchItem] = [
        .init(.red, label: "Red"), .init(.orange, label: "Orange"), .init(.yellow, label: "Yellow"),
        .init(.green, label: "Green"), .init(.mint, label: "Mint"), .init(.teal, label: "Teal"),
        .init(.blue, label: "Blue"), .init(.indigo, label: "Indigo"), .init(.purple, label: "Purple"),
        .init(.pink, label: "Pink"), .init(.brown, label: "Brown"), .init(.gray, label: "Gray"),
    ]
    @State private var selection: ColorSwatchItem?
    @State private var circle = false
    @State private var useGrid = true
    var body: some View {
        ComponentStage("ColorSwatchPicker", inspector: [("selection", selection?.label ?? "nil")]) {
            Group {
                if useGrid {
                    ColorSwatchPicker(palette, selection: $selection).columns(6).swatchShape(circle ? .circle : .square)
                } else {
                    ColorSwatchPicker(palette, selection: $selection).swatchShape(circle ? .circle : .square)
                }
            }
        } knobs: {
            Toggle("Circle swatches", isOn: $circle)
            Toggle("Fixed 6-column grid", isOn: $useGrid)
            Button("Clear") { selection = nil }
        }
    }
}

struct ColorSliderDemo: View {
    @State private var color = HSBAColor(hue: 0.58, saturation: 0.85, brightness: 0.9)
    @State private var compactAlpha = true
    var body: some View {
        ComponentStage("ColorSlider", inspector: [("hue", "\(Int(color.hue * 360))°"), ("alpha", "\(Int(color.alpha * 100))%")]) {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12).fill(color.color).frame(height: 56)
                ColorSlider(.hue, color: $color)
                ColorSlider(.saturation, color: $color)
                ColorSlider(.brightness, color: $color)
                ColorSlider(.alpha, color: $color).trackHeight(compactAlpha ? .compact : .regular)
            }
        } knobs: {
            Toggle("Compact alpha track", isOn: $compactAlpha)
        }
    }
}

struct ColorAreaDemo: View {
    @State private var color = HSBAColor(hue: 0.08, saturation: 0.9, brightness: 0.95)
    var body: some View {
        ComponentStage("ColorArea", inspector: [("sat", "\(Int(color.saturation * 100))%"), ("bri", "\(Int(color.brightness * 100))%")]) {
            VStack(spacing: 16) {
                ColorArea(color: $color).cornerRadius(.box)
                ColorSlider(.hue, color: $color)
                RoundedRectangle(cornerRadius: 12).fill(color.color).frame(height: 44)
            }
        }
    }
}

struct CalendarYearPickerDemo: View {
    @State private var year = 2026
    @State private var success = false
    var body: some View {
        ComponentStage("Calendar Year Picker", inspector: [("year", "\(year)")]) {
            CalendarYearPicker(selection: $year).accent(success ? .success : nil)
        } knobs: {
            Toggle("Success accent", isOn: $success)
            Stepper("Year: \(year)", value: $year, in: 1900...2100)
        }
    }
}

struct PopoverDemo: View {
    @State private var show = false
    @State private var showsArrow = true
    @State private var nonstop = true
    @State private var freeCancel = false
    var body: some View {
        ComponentStage("Popover", inspector: [("open", "\(show)")]) {
            ThemeButton("Quick filters") { show.toggle() }.variant(.outline)
                .themePopover(isPresented: $show, edge: .bottom, showsArrow: showsArrow) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filters").textStyle(.labelBase600)
                        Toggle("Nonstop only", isOn: $nonstop)
                        Toggle("Free cancellation", isOn: $freeCancel)
                    }
                }
                .padding(.vertical, 80)
        } knobs: {
            Text(".themePopover(isPresented:content:) — the anchored card with fully custom content.").font(.caption).foregroundStyle(.secondary)
            Toggle("Shows arrow", isOn: $showsArrow)
            Button(show ? "Hide" : "Show") { show.toggle() }
        }
    }
}

// MARK: - HeroUI catalog-gap components (Wave 2 — charts & surfaces)

private let demoChartSeries: [ChartSeries] = [
    ChartSeries("2025", [ChartPoint("Jan", 12), ChartPoint("Feb", 18), ChartPoint("Mar", 15), ChartPoint("Apr", 22), ChartPoint("May", 19), ChartPoint("Jun", 26)]),
    ChartSeries("2026", [ChartPoint("Jan", 20), ChartPoint("Feb", 16), ChartPoint("Mar", 24), ChartPoint("Apr", 21), ChartPoint("May", 28), ChartPoint("Jun", 30)]),
]

struct LineChartDemo: View {
    @State private var selected: String?
    @State private var curved = true
    @State private var points = true
    @State private var grid = true
    @State private var single = false
    var body: some View {
        ComponentStage("LineChart", inspector: [("selected", selected ?? "—")]) {
            LineChart(single ? [demoChartSeries[0]] : demoChartSeries, selection: $selected)
                .curved(curved).showsPoints(points).showsGrid(grid)
        } knobs: {
            Toggle("Curved", isOn: $curved)
            Toggle("Show points", isOn: $points)
            Toggle("Show grid", isOn: $grid)
            Toggle("Single series (no legend)", isOn: $single)
        }
    }
}

struct AreaChartDemo: View {
    @State private var stacked = false
    @State private var curved = true
    var body: some View {
        ComponentStage("AreaChart", inspector: [("stacked", "\(stacked)")]) {
            AreaChart(demoChartSeries).stacked(stacked).curved(curved)
        } knobs: {
            Toggle("Stacked", isOn: $stacked)
            Toggle("Curved", isOn: $curved)
        }
    }
}

struct BarChartDemo: View {
    @State private var stacked = false
    @State private var selected: String?
    private let series = [
        ChartSeries("Revenue", [ChartPoint("Q1", 120), ChartPoint("Q2", 150), ChartPoint("Q3", 138), ChartPoint("Q4", 172)]),
        ChartSeries("Cost", [ChartPoint("Q1", 80), ChartPoint("Q2", 95), ChartPoint("Q3", 90), ChartPoint("Q4", 110)]),
    ]
    var body: some View {
        ComponentStage("BarChart", inspector: [("mode", stacked ? "stacked" : "grouped")]) {
            BarChart(series, selection: $selected).mode(stacked ? .stacked : .grouped)
        } knobs: {
            Toggle("Stacked", isOn: $stacked)
        }
    }
}

struct DonutChartDemo: View {
    private enum Ratio: String, CaseIterable { case pie, ring, thin }
    @State private var ratioSel: Ratio = .ring
    private var ratio: DonutRatio { ratioSel == .pie ? .pie : (ratioSel == .ring ? .ring : .thin) }
    private let slices = [ChartSlice("Direct", 42), ChartSlice("Search", 30), ChartSlice("Social", 18), ChartSlice("Referral", 10)]
    var body: some View {
        ComponentStage("DonutChart", inspector: [("hole", ratioSel.rawValue)]) {
            DonutChart(slices).innerRadius(ratio).label {
                VStack(spacing: 0) { Text("100").textStyle(.headingSm); Text("visits").textStyle(.overline400) }
            }
        } knobs: {
            Picker("Hole", selection: $ratioSel) { ForEach(Ratio.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }
    }
}

struct HoverCardDemo: View {
    var body: some View {
        ComponentStage("HoverCard", inspector: [("trigger", "long-press / hover")]) {
            VStack(spacing: 44) {
                Text("Long-press or hover me").textStyle(.labelBase600)
                    .hoverCard(edge: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ada Byron").textStyle(.labelBase600)
                            Text("Product designer · Online").textStyle(.bodySm400)
                        }
                    }
                Icon(systemName: "info.circle").size(.lg)
                    .hoverCard(edge: .top) { Text("A contextual preview card.").textStyle(.bodySm400) }
            }
            .padding(.vertical, 44)
        }
    }
}

struct CommandPaletteDemo: View {
    @State private var show = false
    private var sections: [CommandSection] {
        [
            CommandSection("Actions", items: [
                CommandItem("New booking", systemImage: "plus.circle", keywords: ["create", "add"], shortcut: ["⌘", "N"]) {},
                CommandItem("Search flights", systemImage: "airplane", keywords: ["find"], shortcut: ["⌘", "F"]) {},
            ]),
            CommandSection("Navigation", items: [
                CommandItem("Go to trips", systemImage: "suitcase", keywords: ["bookings"]) {},
                CommandItem("Settings", systemImage: "gearshape", shortcut: ["⌘", ","]) {},
            ]),
        ]
    }
    var body: some View {
        ComponentStage("CommandPalette", inspector: [("open", "\(show)")]) {
            ThemeButton("Open ⌘K palette") { show = true }.variant(.outline)
                .frame(maxWidth: .infinity, minHeight: 220)
                .commandPalette(isPresented: $show, sections: sections)
        } knobs: {
            Text("⌘K palette: type to filter, arrow keys to navigate, Kbd shortcut chips.").font(.caption).foregroundStyle(.secondary)
            Button("Open") { show = true }
        }
    }
}

// MARK: - HeroUI catalog-gap components (Wave 3 — organisms & conveniences)

struct EmojiReactionButtonDemo: View {
    @State private var liked = false
    @State private var size: ChipSize = .small
    @State private var accented = false
    var body: some View {
        ComponentStage("EmojiReactionButton", inspector: [("reacted", "\(liked)"), ("size", "\(size)"), ("accent", accented ? "success" : "default")]) {
            HStack(spacing: 10) {
                EmojiReactionButton("👍", count: 12, isReacted: $liked)
                    .size(size).accent(accented ? .success : nil)
                EmojiReactionButton("🎉", count: 4, initiallyReacted: true)
                    .size(size).accent(accented ? .success : nil)
                EmojiReactionButton("🔥", count: 0)
                    .size(size).accent(accented ? .success : nil)
            }
        } knobs: {
            Toggle("First reacted", isOn: $liked)
            Picker("Size", selection: $size) {
                Text("S").tag(ChipSize.small); Text("M").tag(ChipSize.medium); Text("L").tag(ChipSize.large)
            }.pickerStyle(.segmented)
            Toggle("Accent (success)", isOn: $accented)
        }
    }
}

struct ThemeContextMenuDemo: View {
    var body: some View {
        ComponentStage("ThemeContextMenu", inspector: [("trigger", "long-press / right-click")]) {
            Text("Long-press me for a menu")
                .textStyle(.labelBase600)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .themeContextMenu([
                    MenuAction("Share", systemImage: "square.and.arrow.up") {},
                    MenuAction("Move", systemImage: "folder", children: [
                        MenuAction("To Inbox") {}, MenuAction("To Archive") {},
                    ]),
                    MenuAction("Rename", systemImage: "pencil", isDisabled: true) {},
                    MenuAction("Delete", systemImage: "trash", role: .destructive) {},
                ]) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview").textStyle(.labelBase600)
                        Text("A token-styled preview card.").textStyle(.bodySm400)
                    }
                    .padding()
                }
        } knobs: {
            Text("Native menu chrome (not token-stylable) + a data model + styled preview.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TableCellsDemo: View {
    @State private var on = true
    @State private var pick = "Medium"
    @State private var amount = 0.4
    @State private var color = Color.blue
    var body: some View {
        ComponentStage("Table Cells", inspector: [("toggle", "\(on)"), ("select", pick)]) {
            VStack(alignment: .leading, spacing: 14) {
                cellRow("Active") { TableToggleCell(isOn: $on, label: "Active") }
                cellRow("Priority") { TableSelectCell(["Low", "Medium", "High"], selection: $pick, label: "Priority") }
                cellRow("Amount") { TableSliderCell(value: $amount, in: 0...1, label: "Amount") }
                cellRow("Color") { TableColorCell(selection: $color, label: "Color") }
            }
        } knobs: {
            Text("Drop these into a DataTable.Column's cell builder.").font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func cellRow<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        HStack { Text(label).font(.subheadline).frame(width: 90, alignment: .leading); content(); Spacer() }
    }
}

struct ActionBarDemo: View {
    @State private var selected: Set<Int> = [1, 2, 3]
    var body: some View {
        ComponentStage("ActionBar", inspector: [("selected", "\(selected.count)")]) {
            VStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    HStack {
                        Image(systemName: selected.contains(i) ? "checkmark.circle.fill" : "circle")
                        Text("Item \(i)")
                        Spacer()
                    }
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture { if selected.contains(i) { selected.remove(i) } else { selected.insert(i) } }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .top)
            .actionBar(selection: $selected, actions: [
                ActionBarAction("Archive", systemImage: "archivebox") {},
                ActionBarAction("Share", systemImage: "square.and.arrow.up") {},
                ActionBarAction("Delete", systemImage: "trash", role: .destructive) { selected.removeAll() },
            ])
        } knobs: {
            Button("Select all") { selected = Set(1...5) }
            Button("Clear") { selected.removeAll() }
        }
    }
}

struct AgendaDemo: View {
    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 0) -> Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: day, to: .now) ?? .now
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
    var body: some View {
        ComponentStage("Agenda", inspector: [("events", "5")]) {
            ScrollView {
                Agenda([
                    AgendaEvent("Team standup", start: at(9, 30), end: at(10), location: "Zoom", accent: .primary),
                    AgendaEvent("Design review", start: at(13), end: at(14), subtitle: "New components", accent: .purple),
                    AgendaEvent("Lunch with Ada", start: at(12), end: at(13)),
                    AgendaEvent("Company offsite", start: at(0, day: 1), isAllDay: true, accent: .success),
                    AgendaEvent("1:1 sync", start: at(11, day: 1), end: at(11, 30)),
                ])
            }
            .frame(maxHeight: 380)
        }
    }
}

struct ColorPickerPanelDemo: View {
    @State private var color = HSBAColor(hue: 0.55, saturation: 0.8, brightness: 0.9)
    var body: some View {
        ComponentStage("ColorPickerPanel", inspector: [("hue", "\(Int(color.hue * 360))°"), ("alpha", "\(Int(color.alpha * 100))%")]) {
            ColorPickerPanel(color: $color).swatches([
                .init(.red, label: "Red"), .init(.orange, label: "Orange"), .init(.green, label: "Green"),
                .init(.blue, label: "Blue"), .init(.purple, label: "Purple"), .init(.black, label: "Ink"),
            ])
        }
    }
}

struct KanbanBoardDemo: View {
    struct Task: Identifiable, Equatable { let id: Int; let title: String }
    @State private var columns: [KanbanColumn<Task>] = [
        .init("To do", items: [Task(id: 1, title: "Design tokens"), Task(id: 2, title: "Write docs")], accent: .neutral),
        .init("In progress", items: [Task(id: 3, title: "Build charts")], accent: .primary, limit: 2),
        .init("Done", items: [Task(id: 4, title: "Ship colors")], accent: .success),
    ]
    @State private var width: KanbanColumnWidth = .regular
    @State private var spacingIdx = 1   // 0 sm, 1 md, 2 lg
    private var spacingKey: Theme.SpacingKey { spacingIdx == 0 ? .sm : spacingIdx == 2 ? .lg : .md }
    var body: some View {
        ComponentStage("KanbanBoard", inspector: [("columns", "\(columns.count)"), ("width", "\(width)"), ("spacing", "\(spacingKey)")]) {
            KanbanBoard(columns: $columns) { task in
                Text(task.title)
                    .font(.callout.weight(.semibold))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            }
            .columnWidth(width)
            .spacing(spacingKey)
            .frame(height: 380)
        } knobs: {
            Picker("Column width", selection: $width) {
                Text("Compact").tag(KanbanColumnWidth.compact); Text("Regular").tag(KanbanColumnWidth.regular); Text("Wide").tag(KanbanColumnWidth.wide)
            }.pickerStyle(.segmented)
            Picker("Column spacing", selection: $spacingIdx) {
                Text("sm").tag(0); Text("md").tag(1); Text("lg").tag(2)
            }.pickerStyle(.segmented)
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
    @State private var required = false
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }

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
    private var messages: [InfoMessage] { error ? [InfoMessage("Date is required", kind: .error)] : [] }

    var body: some View {
        ComponentStage("DateField", inspector: [("style", styleSel.rawValue), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            {
                let base = DateField("Date", date: $date)
                    .style(style)
                    .components(withTime ? .dateAndTime : .date)
                    .infoMessages(messages)
                    .clearable(clearable)
                    .required(required)
                    .icon("calendar")
                    .a11yID("demoDate")
                return explicitSize.map { base.size($0) } ?? base
            }()
            .disabled(!enabled)
        } knobs: {
            Text("style = display format (custom = \"EEE, d MMM\"). Tap the field to open the themed picker.").font(.caption).foregroundStyle(.secondary)
            Picker("Style", selection: $styleSel) { ForEach(Style.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
            Toggle("With time", isOn: $withTime)
            Toggle("Required indicator", isOn: $required)
            Toggle("Clearable", isOn: $clearable)
            Toggle("Error message", isOn: $error)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct TimeFieldDemo: View {
    private enum Cycle: String, CaseIterable { case locale, h12, h24 }
    @State private var time: Date? = .now
    @State private var cycleSel: Cycle = .locale
    @State private var interval = 5
    @State private var clearable = true
    @State private var enabled = true
    @State private var error = false
    @State private var required = false
    @State private var sizeIdx = 0   // 0 auto, then the TextInputSize ramp
    private var explicitSize: TextInputSize? {
        switch sizeIdx { case 1: return .xsmall; case 2: return .small; case 3: return .medium; case 4: return .large; default: return nil }
    }

    private var cycle: TimeFieldHourCycle {
        switch cycleSel {
        case .locale: return .locale
        case .h12: return .h12
        case .h24: return .h24
        }
    }
    private var messages: [InfoMessage] { error ? [InfoMessage("Time is required", kind: .error)] : [] }

    var body: some View {
        ComponentStage("TimeField", inspector: [("hourCycle", cycleSel.rawValue), ("size", explicitSize.map { "\($0)" } ?? "auto")]) {
            {
                let base = TimeField("Time", time: $time)
                    .hourCycle(cycle)
                    .minuteInterval(interval)
                    .infoMessages(messages)
                    .clearable(clearable)
                    .required(required)
                    .icon("clock")
                    .a11yID("demoTime")
                return explicitSize.map { base.size($0) } ?? base
            }()
            .disabled(!enabled)
        } knobs: {
            Text("hourCycle = locale / 12h / 24h. minuteInterval snaps the wheel. Tap the field to open the themed picker.").font(.caption).foregroundStyle(.secondary)
            Picker("Hour cycle", selection: $cycleSel) { ForEach(Cycle.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Size", selection: $sizeIdx) {
                Text("Auto").tag(0); Text("XS").tag(1); Text("S").tag(2); Text("M").tag(3); Text("L").tag(4)
            }.pickerStyle(.segmented)
            Stepper("Minute interval: \(interval)", value: $interval, in: 1...30, step: 5)
            Toggle("Required indicator", isOn: $required)
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
                .init("Price", align: .trailing, sortKey: { .number($0.price) }) { "$\(Int($0.price))" },
            ], rows: rows, selection: selectable ? $selected : nil)
            .striped(striped)
            .pageSize(paged ? 4 : nil)
            .loading(loading)
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
    @EnvironmentObject private var sheet: SheetPresenter
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
                ThemeButton("Declarative sheet") { showDeclarative = true }.variant(.outline)
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
            Fieldset("Contact details") {
                TextInput("Full name", text: $name)
                HStack { Checkbox(isChecked: $subscribe); Text("Subscribe to newsletter").textStyle(.bodyBase400); Spacer() }
            }
            .helper(helper ? "We'll only use this to confirm your booking." : nil)
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
        error ? [InfoMessage("File must be smaller than 5 MB", kind: .error)] : []
    }
    var body: some View {
        ComponentStage("FileInput", inspector: [("fileName", picked ? "passport-scan.jpg" : "nil"), ("error", "\(error)")]) {
            FileInput("Passport", onPick: { picked = true; flash("FileInput: file selected") })
                .fileName(picked ? "passport-scan.jpg" : nil)
                .infoMessages(messages)
                .onClear(clearable ? { picked = false; flash("FileInput: cleared") } : nil)
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
                PrimaryButton("Sample button") { flash("Sample button tapped") }
            }
        } knobs: {
            Text("Switches Theme.shared live.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Configurable components

struct ThemeButtonDemo: View {
    @State private var color: SemanticColor = .primary
    @State private var variant: ButtonVariant = .solid
    @State private var size: ButtonSize = .medium
    @State private var shape: ButtonShape = .rounded
    @State private var block = true
    @State private var icon = false
    @State private var trailingIcon = false
    @State private var loading = false
    @State private var spinnerIdx = 0   // 0 replace label, 1 leading, 2 trailing
    @State private var compact = false
    @State private var iconOnlyForce = false
    @State private var prefixSuffix = false

    private var iconOnly: Bool { iconOnlyForce || shape == .circle || shape == .square }

    var body: some View {
        ComponentStage("ThemeButton", inspector: [
            ("color", color.rawValue), ("variant", variant.rawValue), ("shape", shape.rawValue), ("size", "\(size)"), ("density", compact ? "compact" : "regular"),
        ]) {
            {
                var base = ThemeButton(iconOnly ? nil : "Button") { flash("ThemeButton tapped") }
                    .icon(leading: ((icon || iconOnly) && !trailingIcon && !prefixSuffix) ? "star.fill" : nil,
                          trailing: ((icon || iconOnly) && trailingIcon && !prefixSuffix) ? "star.fill" : nil)
                    .color(color).variant(variant).size(size).shape(shape)
                    .density(compact ? .compact : .regular)
                    .iconOnly(iconOnlyForce)
                    .fullWidth(block && !iconOnly).loading(loading)
                // Prefix/suffix element slots (Figma "Prefix"/"Suffix").
                if prefixSuffix {
                    base = base.prefix { Icon(systemName: "sparkles").size(.sm) }
                        .suffix { Icon(systemName: "arrow.right").size(.sm) }
                }
                if spinnerIdx != 0 { base = base.spinnerPlacement(spinnerIdx == 1 ? .leading : .trailing) }
                return base
            }()
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
            Picker("Spinner placement", selection: $spinnerIdx) {
                Text("Replace").tag(0); Text("Start").tag(1); Text("End").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Compact density (sm/md/lg 32·36·40)", isOn: $compact)
            Toggle("Icon-only (force, rounded)", isOn: $iconOnlyForce)
            Toggle("Prefix + suffix slots", isOn: $prefixSuffix)
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
    @EnvironmentObject private var feedback: FeedbackPresenter
    @State private var kind: FeedbackKind = .success
    @State private var last = "—"

    var body: some View {
        ComponentStage("Feedback", inspector: [("level", "global"), ("last action", last)]) {
            VStack(spacing: 12) {
                ThemeButton("Show toast") {
                    feedback.toast("\(kind.rawValue.capitalized) message",
                                   message: "This is a \(kind.rawValue) notification.", kind: kind)
                    last = "toast: \(kind.rawValue)"
                }
                .color(kind.semanticColor).fullWidth()
                ThemeButton("Stack (3 toast)") {
                    for i in 1 ... 3 { feedback.toast("Toast #\(i)", kind: kind) }
                    last = "stack: 3"
                }
                .color(kind.semanticColor).variant(.soft).fullWidth()
                ThemeButton("Undo (action + sticky)") {
                    feedback.toast("Message deleted", kind: .info,
                                   action: ToastAction("Undo") { feedback.toast("Undone", kind: .success) },
                                   duration: nil)
                    last = "undo toast"
                }
                .variant(.outline).fullWidth()
                ThemeButton("Async task (task)") {
                    Task {
                        await feedback.toastTask(loading: "Saving…", success: "Saved") {
                            try await Task.sleep(nanoseconds: 1_500_000_000)
                        }
                    }
                    last = "async task"
                }
                .variant(.outline).fullWidth()
                ThemeButton("Show notification (notification)") {
                    feedback.notify("\(kind.rawValue.capitalized)", message: "A notification from the top.", kind: kind)
                    last = "notify: \(kind.rawValue)"
                }
                .color(kind.semanticColor).variant(.soft).fullWidth()
                ThemeButton("Loading (loading)") {
                    feedback.loading("Saving…")
                    last = "loading"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        feedback.dismissLoading(); feedback.toast("Saved", kind: .success)
                    }
                }
                .icon(leading: "arrow.clockwise").variant(.outline).fullWidth()
                ThemeButton("Ask for confirmation (confirm)") {
                    feedback.confirm(
                        title: "Cancel reservation?",
                        message: "This action cannot be undone.",
                        primaryTitle: "Cancel reservation", primaryKind: .error,
                        onPrimary: { last = "confirmed"; feedback.toast("Cancelled", kind: .success); flash("Confirmed") },
                        secondaryTitle: "Cancel", onSecondary: { last = "dismissed"; flash("Dismissed") }
                    )
                }
                .color(.error).variant(.outline).fullWidth()

                // Subtree house style: `.feedbackDefaults(...)` wrapped around a
                // local host — default edge/duration with per-call overrides.
                FeedbackDefaultsPlayground()
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
            case "toast": feedback.toast("Saved", message: "Your changes have been saved.", kind: .success)
            case "notify": feedback.notify("New message", message: "Your reservation has been confirmed.", kind: .info)
            case "confirm": feedback.confirm(title: "Cancel reservation?", message: "This action cannot be undone.",
                                             primaryTitle: "Cancel reservation", primaryKind: .error, secondaryTitle: "Cancel")
            default: break
            }
        }
    }
}

/// FeedbackDefaults playground: a *locally hosted* subtree (its own
/// `.feedbackHost()`) wrapped in `.feedbackDefaults(...)` so the toggles
/// re-apply live. Omitted-argument calls follow the defaults; explicit
/// `duration:` / `position:` arguments still win.
private struct FeedbackDefaultsPlayground: View {
    @State private var top = true
    @State private var slow = false
    private var duration: Double { slow ? 6 : 1.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback Defaults").font(.caption.bold()).foregroundStyle(.secondary)
            Text(".feedbackDefaults(toastPosition: \(top ? ".top" : ".bottom"), toastDuration: \(duration, specifier: "%.1f"))")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            FeedbackDefaultsButtons()
            Toggle("Top edge default", isOn: $top)
            Toggle("Slow dismiss default (6s)", isOn: $slow)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .feedbackHost()   // local host — reads the defaults applied around it
        .feedbackDefaults(toastPosition: top ? .top : .bottom, toastDuration: duration)
    }
}

private struct FeedbackDefaultsButtons: View {
    /// The *local* presenter injected by the playground's own `.feedbackHost()`.
    @EnvironmentObject private var feedback: FeedbackPresenter

    var body: some View {
        VStack(spacing: 8) {
            ThemeButton("Toast (uses defaults)") {
                feedback.toast("Follows the subtree defaults", kind: .accent)   // no duration/position args
            }
            .fullWidth()
            ThemeButton("Explicit sticky (duration: nil)") {
                feedback.toast("Explicit wins — sticky", kind: .info, duration: nil)
            }
            .variant(.outline).fullWidth()
            ThemeButton("Explicit bottom (position:)") {
                feedback.toast("Explicit wins — bottom", kind: .neutral, position: .bottom)
            }
            .variant(.outline).fullWidth()
        }
    }
}

// MARK: - Result / Exception templates

struct ResultDemo: View {
    @State private var status: ResultStatus = .success
    @State private var customSlots = false

    private var copy: (String, String) {
        switch status {
        case .success: return ("Reservation confirmed", "A confirmation email has been sent.")
        case .info: return ("Information", "Your request has been queued.")
        case .warning: return ("Payment pending", "Waiting for bank approval.")
        case .error: return ("Payment failed", "Check your card details and try again.")
        case .notFound: return ("Page not found", "The page you're looking for may have been moved or deleted.")
        case .forbidden: return ("Access denied", "You don't have permission to view this page.")
        case .serverError: return ("Something went wrong", "A server error occurred, please try again.")
        }
    }

    var body: some View {
        ComponentStage("Result", inspector: [("status", status.rawValue), ("code", status.codeText)]) {
            if customSlots {
                // Ant `icon` / children / `extra` slots.
                ResultView(status, title: copy.0)
                    .subtitle(copy.1)
                    .icon {
                        Icon(systemName: "gift.fill").size(.xl).accent(.turquoise)
                            .padding(22).background(SemanticColor.turquoise.soft, in: Circle())
                    }
                    .content {
                        HStack(spacing: 16) {
                            Text("Order").font(.caption).foregroundStyle(.secondary)
                            Text("#A-1029").font(.caption.bold())
                        }
                        .padding(12).frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .extra {
                        HStack(spacing: 8) {
                            ThemeButton("Buy again") { flash("Buy again") }.color(.primary)
                            OutlineButton("Invoice") { flash("Invoice") }
                        }
                    }
            } else {
                ResultView(status, title: copy.0)
                    .message(copy.1)
                    .primaryAction("Try again", action: { flash("Result: Try again") })
                    .secondaryAction("Home", action: { flash("Result: Home") })
            }
        } knobs: {
            Picker("Status", selection: $status) {
                ForEach(ResultStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Custom icon / content / extra slots", isOn: $customSlots)
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
    @State private var reverse = false
    @State private var outset = 0.0
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
                .borderBeam(cornerRadius: pill ? 100 : 20, lineWidth: lineWidth, duration: duration,
                            outset: outset, reverse: reverse, glow: glow, colors: colors)
        } knobs: {
            HStack { Text("Width"); SwiftUI.Slider(value: $lineWidth, in: 1...6, step: 1) }
            HStack { Text("Speed"); SwiftUI.Slider(value: $duration, in: 1.5...8) }
            HStack { Text("Outset"); SwiftUI.Slider(value: $outset, in: 0...8) }
            Picker("Colors", selection: $paletteIdx) { Text("Accent").tag(0); Text("Purple→Pink").tag(1); Text("Sunset").tag(2) }.pickerStyle(.segmented)
            Toggle("Glow halo", isOn: $glow)
            Toggle("Reverse", isOn: $reverse)
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
            ThemeButton("Delete") { show.toggle() }
                .icon(leading: "trash").color(.error).variant(.soft)
                .popconfirm(isPresented: $show, title: "Delete this item?", message: "This action cannot be undone.",
                            confirmTitle: "Delete", cancelTitle: "Cancel", edge: edge,
                            onConfirm: {
                                if asyncConfirm { try? await Task.sleep(nanoseconds: 1_200_000_000) }
                                last = "confirmed"; flash("Popconfirm confirmed")
                            },
                            onCancel: { last = "cancelled"; flash("Popconfirm cancelled") })
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
        TreeNode(id: "tr", "Turkey", systemImage: "flag", children: [
            TreeNode(id: "ist", "Istanbul"), TreeNode(id: "ank", "Ankara"), TreeNode(id: "izm", "Izmir"),
        ]),
        TreeNode(id: "de", "Germany", systemImage: "flag", children: [
            TreeNode(id: "ber", "Berlin"), TreeNode(id: "mun", "Munich"),
        ]),
    ]
    var body: some View {
        ComponentStage("TreeSelect", inspector: [("selected", "\(picks.count)"), ("cascade", "\(cascade)"), ("loading", "\(loading)")]) {
            TreeSelect("Cities", nodes: tree, selection: $picks, initiallyExpanded: ["tr", "de"])
                .cascade(cascade).searchable(searchable)
                .loading(loading).nodeEnabled(disableIzmir ? { $0.id != "izm" } : nil)
                .id("\(cascade)\(searchable)\(loading)\(disableIzmir)")
        } knobs: {
            Toggle("Cascade (parent ↔ child + indeterminate)", isOn: $cascade)
            Toggle("Searchable", isOn: $searchable)
            Toggle("Loading", isOn: $loading)
            Toggle("Disable “Izmir”", isOn: $disableIzmir)
            Button("Reset") { picks = ["ist"] }
        }
    }
}

struct TourDemo: View {
    @StateObject private var tour = TourController()
    var body: some View {
        ComponentStage("Tour", inspector: [("active", "\(tour.isActive)"), ("step", "\(tour.index + 1)")]) {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    tourIcon("magnifyingglass", "search")
                    tourIcon("heart", "fav")
                    tourIcon("person.crop.circle", "profile")
                }
                ThemeButton("Start tour") { tour.start(); flash("Tour started") }.icon(leading: "play.fill").fullWidth()
            }
            .tourHost(tour, steps: [
                TourStep("search", title: "Search", message: "Search for hotels here."),
                TourStep("fav", title: "Favorites", message: "Save the ones you like."),
                TourStep("profile", title: "Profile", message: "Manage your account here."),
            ])
        } knobs: {
            Button("Start tour") { tour.start() }
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

    @StateObject private var form = FormValidator<Field>([
        .email: [.required("Email is required"), .email()],
        .password: [.required("Password is required"), .password(minLength: 8)],
        .plan: [.required("Select a plan")],
        .terms: [.required("Accept to continue")],
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
                Fieldset("Create account") {
                    TextInput(TextInputModel(label: "Email", leadingSystemImage: "envelope",
                                             infoMessages: form.messages(for: .email)),
                              text: $email, externalFocus: form.focusBinding(.email))
                        .a11yID("form.email")
                    TextInput(TextInputModel(label: "Password (8+, uppercase, number)", isSecure: true,
                                             infoMessages: form.messages(for: .password)),
                              text: $password, externalFocus: form.focusBinding(.password))
                        .a11yID("form.password")
                    RadioGroup(title: "Plan", options: ["Standard", "Pro"], selection: $plan) { $0 }
                    .infoMessages(form.messages(for: .plan))
                    .a11yID("form.plan")
                    Checkbox("I accept the terms and conditions", isChecked: $terms)
                    .infoMessages(form.messages(for: .terms))
                    .a11yID("form.terms")
                }
                .helper("All fields are required.")
                if done {
                    InfoBanner("Your account has been created.").variant(.success)
                }
                ThemeButton("Sign up") {
                    let firstInvalid = form.validateAll(values)
                    submitted = true
                    done = firstInvalid == nil
                }
                .fullWidth().a11yID("form.submit")
            }
        } knobs: {
            Text("Empty submit → email/password + RadioGroup + Checkbox all show errors; focus jumps to the first invalid text field.").font(.caption).foregroundStyle(.secondary)
            Button("Reset") { email = ""; password = ""; plan = nil; terms = false; submitted = false; done = false; form.reset() }
        }
        .onChange(of: values.description) { _ in if submitted { _ = form.validateAll(values) } }
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
        Row(title: "My account", subtitle: "Profile and security", icon: "person.circle"),
        Row(title: "Notifications", subtitle: "Email and push", icon: "bell"),
        Row(title: "Language", subtitle: "English", icon: "globe"),
    ]
    @State private var withHeader = true
    @State private var bordered = true
    @State private var split = true
    @State private var loading = false
    @State private var empty = false

    var body: some View {
        ComponentStage("List", inspector: [("count", "\(empty ? 0 : rows.count)"), ("bordered", "\(bordered)"), ("empty", "\(empty)")]) {
            ListView(empty ? [] : rows) { row in
                ListRow(row.title, action: { flash("List: \(row.title)") }).subtitle(row.subtitle).icon(row.icon)
            }
            .header(withHeader ? "Settings" : nil)
            .footer(withHeader ? "\(empty ? 0 : rows.count) items" : nil)
            .bordered(bordered)
            .loading(loading)
            .split(split)
            .emptyText("No settings yet")
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
                    RemoteImage(gifURL, ratio: "1:1").cornerRadius(16)
                        .frame(width: 180, height: 180)
                } else if circle {
                    RemoteImage(URL(string: "https://picsum.photos/seed/gucomp/600/600")).ratio(1).circle()
                        .frame(width: 140, height: 140)
                } else {
                    RemoteImage(URL(string: "https://picsum.photos/seed/gucomp/600/600"), ratio: ratioStr).cornerRadius(16)
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
            ImageCollage(urls, onTap: { flash("ImageCollage: image \($0 + 1)") }).height(220)
        } knobs: {
            HStack { Text("Images"); SwiftUI.Slider(value: $count, in: 1...8, step: 1) }
            Text("Layouts adapt: 1 · 2 · 3 · 4+ with a +N overlay on the last tile.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AccordionGroupDemo: View {
    private struct FAQ: Identifiable { let id = UUID(); let q: String; let a: String }
    private let faqs = [
        FAQ(q: "Can I cancel?", a: "Yes, free cancellation up to 24 hours before check-in."),
        FAQ(q: "What are the payment options?", a: "Credit/debit cards and bank transfers are accepted."),
        FAQ(q: "Are pets allowed?", a: "Small-breed pets are allowed for an extra fee."),
    ]
    @State private var multi = false
    @State private var prefixIdx = 0   // 0 none, 1 icon, 2 number
    @State private var secondary = true
    @State private var customTrailing = false

    var body: some View {
        ComponentStage("AccordionGroup", inspector: [("mode", multi ? "multiple" : "single"), ("variant", secondary ? "secondary" : "default")]) {
            {
                var group = AccordionGroup(faqs, initiallyExpanded: []) { $0.q } content: {
                    Text($0.a).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
                .mode(multi ? .multiple : .single)
                .surface(secondary)   // secondary = surface card · default = flat rows
                // Leading prefix (Figma "Prefix" instance swap) — icon or number.
                if prefixIdx == 1 {
                    group = group.icon { _ in "questionmark.circle" }
                } else if prefixIdx == 2 {
                    group = group.number { item in faqs.firstIndex { $0.id == item.id }.map { $0 + 1 } }
                }
                // Per-item custom trailing view — replaces the indicator glyph.
                if customTrailing {
                    group = group.trailing { _, isOpen in
                        Icon(systemName: isOpen ? "chevron.up.circle.fill" : "chevron.down.circle").size(.sm).accent(.primary)
                    }
                }
                return group.id("\(multi)\(prefixIdx)\(secondary)\(customTrailing)")
            }()
        } knobs: {
            Toggle("Multiple open", isOn: $multi)
            Toggle("Secondary (surface card)", isOn: $secondary)
            Toggle("Custom trailing", isOn: $customTrailing)
            Picker("Prefix", selection: $prefixIdx) { Text("None").tag(0); Text("Icon").tag(1); Text("Number").tag(2) }.pickerStyle(.segmented)
            Text("single = opening one closes the others; multiple = independent.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Ref-logic D: PagingCarousel + RollingNumber + VideoPlayer

struct PagingCarouselDemo: View {
    private struct Slide: Identifiable { let id = UUID(); let color: Color; let title: String }
    private let slides = [Slide(color: .blue, title: "One"), Slide(color: .teal, title: "Two"),
                          Slide(color: .orange, title: "Three"), Slide(color: .purple, title: "Four")]
    @State private var autoplay = false
    @State private var peek = 36.0

    var body: some View {
        ComponentStage("PagingCarousel", inspector: [("peek", "\(Int(peek))"), ("autoplay", "\(autoplay)")]) {
            PagingCarousel(slides) { s in
                s.color.opacity(0.25).overlay(Text(s.title).textStyle(.headingSm))
            }
            .peek(peek)
            .autoplay(autoplay ? 2 : nil)
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
                RollingNumber(value).size(size).accent(.primary)
                ThemeButton("Roll") { value = Int.random(in: 100...99999); flash("RollingNumber: \(value)") }.icon(leading: "dice")
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
    @State private var multi: Set<String> = ["Wifi", "Pool"]
    @State private var square = false

    private var imageURL: URL? { URL(string: "https://picsum.photos/seed/imgchip/200/300") }

    var body: some View {
        ComponentStage("Chips", inspector: [("variant", kind.rawValue)]) {
            Group {
                switch kind {
                case .compact:
                    HStack(spacing: 12) {
                        CompactChip("Standard Room", price: "$399.90", isSelected: $a).rating(4.6)
                        CompactChip("Suite Room", price: "$899.90", isSelected: $b)
                    }
                case .chose:
                    ChoseChip("Flexible rate", isSelected: $a)
                        .description("Free cancellation")
                        .rating(4.8)
                        .free()
                        .icon("wind")
                case .image:
                    HStack(spacing: 12) {
                        ImageChip(isSelected: $a, url: imageURL).size(.medium)
                        ImageChip(isSelected: $b, url: imageURL).size(.medium)
                    }
                case .filter:
                    HStack(spacing: 8) {
                        FilterChip("Istanbul") { flash("FilterChip: Istanbul") }.shape(square ? .square : .pill)
                        FilterChip("4+ stars") { flash("FilterChip: 4+ stars") }.shape(square ? .square : .pill)
                    }
                case .group:
                    ChipGroup(title: "Amenities", options: ["Wifi", "Pool", "Spa", "Parking", "Restaurant"], selection: $multi) { $0 }
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
    @State private var backdrop: BackdropStyle = .dim
    @State private var size: DialogSize = .md
    @State private var placement: DialogPlacement = .center
    var body: some View {
        ComponentStage("Dialog",
                       inspector: [("backdrop", backdrop.rawValue), ("size", size.rawValue),
                                   ("placement", placement.rawValue), ("deleted", "\(deleted)")]) {
            VStack(spacing: 12) {
                PrimaryButton("Open agreement") { show = true; flash("Dialog opened") }
                OutlineButton("Delete account (async)") { deleted = false; showConfirm = true }
                Text(accepted ? "Accepted ✓" : "Not yet accepted")
                    .textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textSecondary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .dialog(isPresented: $showConfirm, title: "Delete account?", message: "This action cannot be undone.",
                    primaryTitle: "Delete", onPrimary: {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)   // async work; OK spins
                        deleted = true; flash("Account deleted")
                    }, secondaryTitle: "Cancel", onSecondary: { flash("Dismissed") }, kind: .error,
                    backdrop: backdrop, size: size, placement: placement)
            .dialog(isPresented: $show, title: "Terms of Use",
                    backdrop: backdrop, size: size, placement: placement, afterClose: {}) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(1...8, id: \.self) { i in
                        Text("Article \(i)").textStyle(.labelBase700).foregroundStyle(Theme.shared.text(.textPrimary))
                        Text("This long text shows that the dialog content is scrollable. The footer stays pinned.")
                            .textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
            } footer: {
                HStack(spacing: 12) {
                    OutlineButton("Cancel") { show = false; flash("Dialog: Cancel") }
                    PrimaryButton("Accept") { accepted = true; show = false; flash("Dialog accepted") }
                }
            }
        } knobs: {
            Picker("Backdrop", selection: $backdrop) {
                ForEach(BackdropStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Size", selection: $size) {
                ForEach(DialogSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Placement", selection: $placement) {
                ForEach(DialogPlacement.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
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
            ProgressIndicator(variant: v, current: Int(current), total: 8)
                .videoProgress(videoProgress)
                .stepText(stepText ? (padded ? .padded : .slash) : .none)
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
                Text("This subtree: .microAnimations(\(enabled ? "true" : "false")) — scale on press, slide on selection.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                PrimaryButton("Press me (micro press)") { flash("Tap") }
                SegmentedControl(["Day", "Week", "Month"], selection: $sel)
                ThemeToggle(isOn: $on)

                DividerView().size(.small)
                Text("Per-component override — this button is always off:")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                SecondaryButton("Static (.microAnimations(false))") { flash("Tap") }
                    .microAnimations(false)
            }
            .microAnimations(enabled)
        } knobs: {
            Toggle("Micro-animations (this subtree)", isOn: $enabled)
            Text("Theme-wide: Configurator → “Micro-animations”. Reduce Motion always wins.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - AlertDialog

struct AlertDialogDemo: View {
    @State private var show = false
    @State private var async = false
    @State private var align: AlertHeaderAlignment = .leading
    @State private var layout: AlertFooterLayout = .auto
    @State private var size: AlertDialogSize = .sm
    @State private var destructive = true
    @State private var closable = true
    @State private var longLabels = false
    @State private var showIcon = true
    @State private var showTitle = true
    @State private var result = "—"

    private var primaryLabel: String { longLabels ? "Save and continue editing" : (destructive ? "Delete" : "Confirm") }
    private var secondaryLabel: String { longLabels ? "Discard all my recent changes" : "Cancel" }
    private var iconName: String? { showIcon ? (destructive ? "trash" : "externaldrive") : nil }

    /// The dialog card, driven entirely by the knobs so the same declaration can
    /// render inline (below) and as a modal (via `.alertDialog`).
    private func card(dismiss: @escaping () -> Void) -> AlertDialog {
        AlertDialog(showTitle ? "Delete product" : nil,
                    message: "Are you sure you want to delete this product? This action cannot be undone.")
            .icon(iconName)
            .tone(destructive ? .error : .neutral)
            .headerAlignment(align)
            .footerLayout(layout)
            .size(size)
            .primaryAction(primaryLabel) { result = primaryLabel; dismiss(); flash("AlertDialog: \(primaryLabel)") }
            .secondaryAction(secondaryLabel) { result = secondaryLabel; dismiss(); flash("AlertDialog: \(secondaryLabel)") }
            .closable(closable ? { dismiss(); flash("AlertDialog closed") } : { })
    }

    var body: some View {
        ComponentStage("AlertDialog", inspector: [("last action", result), ("footer", "\(layout.rawValue)")]) {
            VStack(spacing: 16) {
                // Live inline card — reshapes as the knobs change (Figma "Composition" board).
                card(dismiss: {})
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 12) {
                    OutlineButton("Present as modal") { show = true; flash("AlertDialog opened") }
                    OutlineButton("Async confirm") { async = true; flash("AlertDialog (async) opened") }
                }
            }
            .frame(maxWidth: .infinity)
            .alertDialog(isPresented: $show, swipeToDismiss: true) {
                card(dismiss: { show = false })
            }
            // Param convenience: spinner + auto-dismiss once the async work resolves.
            .alertDialog(isPresented: $async, title: showTitle ? "Delete product" : nil,
                         message: "Are you sure you want to delete this product? This action cannot be undone.",
                         icon: iconName, tone: destructive ? .error : .neutral,
                         headerAlignment: align, footerLayout: layout, size: size,
                         primaryTitle: primaryLabel,
                         onPrimary: { try? await Task.sleep(nanoseconds: 1_200_000_000); result = "\(primaryLabel) (async)"; flash("AlertDialog: \(primaryLabel) done") },
                         secondaryTitle: secondaryLabel, onSecondary: { result = secondaryLabel },
                         closable: closable)
        } knobs: {
            Picker("Header", selection: $align) {
                Text("Leading").tag(AlertHeaderAlignment.leading); Text("Center").tag(AlertHeaderAlignment.center)
            }.pickerStyle(.segmented)
            Picker("Footer", selection: $layout) {
                ForEach(AlertFooterLayout.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Picker("Size", selection: $size) {
                ForEach(AlertDialogSize.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Show icon", isOn: $showIcon)
            Toggle("Show title", isOn: $showTitle)
            Toggle("Destructive tone", isOn: $destructive)
            Toggle("Long labels (footer auto-stacks)", isOn: $longLabels)
            Toggle("Closable (✕)", isOn: $closable)
        }
    }
}
