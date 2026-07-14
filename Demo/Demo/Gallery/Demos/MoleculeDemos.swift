// REGISTER: LanguageSwitcher · deep-link "LanguageSwitcher" · molecule · isNew
//
//  MoleculeDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Interactive demo pages + small stateful previews for molecule components.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct ButtonDemo: View {
    enum Style: String, CaseIterable { case primary, secondary, outline, ghost, link }
    @State private var style: Style = .primary
    @State private var size: ButtonSize = .medium
    @State private var title = "Button"
    @State private var enabled = true
    @State private var loading = false
    @State private var fullWidth = true
    @State private var helper = false
    @State private var asyncMode = false

    private var helperText: String? { helper ? "VAT included" : nil }
    private func tapped() { flash("\(style.rawValue.capitalized) button tapped") }
    // Simulates a 1.2s network call; the button auto-shows a spinner then a checkmark.
    private func work() async {
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        flash("Async task finished ✓")
    }

    var body: some View {
        ComponentStage("Button", inspector: [
            ("style", style.rawValue), ("async", "\(asyncMode)"), ("helperText", "\(helper)"),
        ]) {
            Group {
                if asyncMode {
                    switch style {
                    case .primary: PrimaryButton(title, task: work).size(size).fullWidth(fullWidth).helperText(helperText).disabled(!enabled)
                    case .secondary: SecondaryButton(title, task: work).size(size).fullWidth(fullWidth).helperText(helperText).disabled(!enabled)
                    case .outline: OutlineButton(title, task: work).size(size).fullWidth(fullWidth).helperText(helperText).disabled(!enabled)
                    case .ghost: GhostButton(title, task: work).size(size).fullWidth(fullWidth).helperText(helperText).disabled(!enabled)
                    case .link: LinkButton(title, action: tapped).size(size).disabled(!enabled)
                    }
                } else {
                    switch style {
                    case .primary: PrimaryButton(title, action: tapped).size(size).fullWidth(fullWidth).helperText(helperText).loading(loading).disabled(!enabled)
                    case .secondary: SecondaryButton(title, action: tapped).size(size).fullWidth(fullWidth).helperText(helperText).loading(loading).disabled(!enabled)
                    case .outline: OutlineButton(title, action: tapped).size(size).fullWidth(fullWidth).helperText(helperText).loading(loading).disabled(!enabled)
                    case .ghost: GhostButton(title, action: tapped).size(size).fullWidth(fullWidth).helperText(helperText).loading(loading).disabled(!enabled)
                    case .link: LinkButton(title, action: tapped).size(size).disabled(!enabled)
                    }
                }
            }
        } knobs: {
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $style) { ForEach(Style.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Size", selection: $size) {
                Text("XXS").tag(ButtonSize.xxsmall); Text("XS").tag(ButtonSize.xsmall); Text("S").tag(ButtonSize.small); Text("M").tag(ButtonSize.medium); Text("L").tag(ButtonSize.large)
            }.pickerStyle(.segmented)
            Toggle("Async task (auto-loading + ✓ confirm)", isOn: $asyncMode)
            Toggle("Helper text (sub-label)", isOn: $helper)
            Toggle("Enabled", isOn: $enabled)
            if !asyncMode { Toggle("Loading", isOn: $loading) }
            Toggle("Full width", isOn: $fullWidth)
        }
    }
}

struct CheckboxDemo: View {
    @State private var checked = false
    @State private var indeterminate = false
    @State private var sizeIdx = 1   // 0 small (20pt), 1 regular (24pt), 2 large (28pt glyph)
    @State private var enabled = true
    @State private var withLabel = true
    @State private var requiredError = true
    @State private var big = false
    @State private var typeIdx = 0   // 0 plain, 1 inner, 2 customInner
    @State private var trailing = false
    @State private var strike = false
    @State private var readOnly = false

    private var type: CheckboxType {
        switch typeIdx {
        case 1: return .inner
        case 2: return .customInner(color: SemanticColor.primary.base)
        default: return .plain
        }
    }

    // Required-checkbox semantic: error only while unchecked (like reference shouldWarn).
    private var messages: [InfoMessage] {
        (requiredError && !checked) ? [InfoMessage("Accept to continue", kind: .error)] : []
    }

    var body: some View {
        ComponentStage("Checkbox", inspector: [("isChecked", "\(checked)"), ("type", typeIdx == 1 ? "inner" : typeIdx == 2 ? "customInner" : "plain")]) {
            Checkbox(withLabel ? "I accept the terms and conditions" : nil, isChecked: $checked)
                    .infoMessages(messages)
                    .customSize(big ? 32 : nil)
                    .type(type)
                    .indeterminate(indeterminate)
                    .alignment(.top)
                    .controlPlacement(trailing ? .trailing : .leading)
                    .lineThrough(strike)
                    .controlSize(sizeIdx == 0 ? .small : sizeIdx == 2 ? .large : .regular)
                    .disabled(!enabled)
                    .readOnly(readOnly)
        } knobs: {
            Toggle("Checked", isOn: $checked)
            Toggle("Custom size (32)", isOn: $big)
            Picker("Type", selection: $typeIdx) { Text("Plain").tag(0); Text("Inner").tag(1); Text("Swatch").tag(2) }.pickerStyle(.segmented)
            Picker("Size", selection: $sizeIdx) { Text("S (20)").tag(0); Text("M (24)").tag(1); Text("L (28)").tag(2) }.pickerStyle(.segmented)
            Toggle("Trailing control (.controlPlacement)", isOn: $trailing)
            Toggle("Line-through when checked", isOn: $strike)
            Toggle("Required (error when unchecked)", isOn: $requiredError)
            Toggle("Inline label", isOn: $withLabel)
            Toggle("Indeterminate", isOn: $indeterminate)
            Toggle("Read-only (blocks toggling, normal chrome)", isOn: $readOnly)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct RadioButtonDemo: View {
    @State private var selected = true
    @State private var small = false
    @State private var enabled = true
    @State private var check = false
    @State private var inner = false
    @State private var inlineLabel = true
    @State private var trailing = false
    @State private var readOnly = false

    var body: some View {
        ComponentStage("RadioButton", inspector: [("type", check ? "check" : "select"), ("style", inner ? "inner" : "plain")]) {
            RadioButton(inlineLabel ? "Remember me" : nil, isSelected: $selected)
                    .type(check ? .check : .select)
                    .radioStyle(inner ? .inner : .plain)
                    .gap(.medium)
                    .controlPlacement(trailing ? .trailing : .leading)
                    .controlSize(small ? .small : .regular)
                    .disabled(!enabled)
                    .readOnly(readOnly)
        } knobs: {
            Toggle("Selected", isOn: $selected)
            Toggle("Inline label", isOn: $inlineLabel)
            Toggle("Trailing control (.controlPlacement)", isOn: $trailing)
            Toggle("Check type (toggles)", isOn: $check)
            Toggle("Inner style (check)", isOn: $inner)
            Toggle("Small", isOn: $small)
            Toggle("Read-only (blocks toggling, normal chrome)", isOn: $readOnly)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct ToggleDemo: View {
    @State private var on = true
    @State private var small = false
    @State private var enabled = true
    @State private var loading = false
    @State private var icons = false
    @State private var readOnly = false

    var body: some View {
        ComponentStage("ThemeToggle", inspector: [("isOn", "\(on)"), ("isLoading", "\(loading)"), ("readOnly", "\(readOnly)")]) {
            ThemeToggle(isOn: $on)
                .loading(loading)
                .symbols(on: icons ? "checkmark" : nil, off: icons ? "xmark" : nil)
                .controlSize(small ? .small : .regular)
                .disabled(!enabled)
                .readOnly(readOnly)
        } knobs: {
            Toggle("On", isOn: $on)
            Toggle("Loading", isOn: $loading)
            Toggle("Inner icons", isOn: $icons)
            Toggle("Small", isOn: $small)
            Toggle("Read-only (blocks toggling, normal chrome)", isOn: $readOnly)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct TextInputDemo: View {
    private enum Mode: String, CaseIterable { case email, password, bio, card, phone, currency, addons }
    @State private var text = ""
    @State private var mode: Mode = .email
    @State private var loggedIn = false
    @State private var readOnly = false
    @State private var sizeIdx = 1   // 0 small, 1 medium, 2 large (TextInputSize ramp)

    private var model: TextInputModel {
        switch mode {
        case .email:
            var msgs = Validator.validate(text, [.required("Email is required"), .email()], all: true)
            if msgs.isEmpty, !text.isEmpty {   // clickable info link (reference clickableParts)
                msgs = [InfoMessage("This email is already registered. Log in", kind: .info,
                                    links: [("Log in", { loggedIn = true })])]
            }
            return TextInputModel(label: "Email", placeholder: "name@company.com", leadingSystemImage: "envelope",
                                  allowClear: true, infoMessages: msgs,
                                  keyboardType: .emailAddress, textContentType: .emailAddress,
                                  submitLabel: .next, autocapitalization: .never, autocorrectionDisabled: true)
        case .password:
            return TextInputModel(label: "Password", isSecure: true, maxLength: 24, showCount: true, textContentType: .password, submitLabel: .go)
        case .bio:
            // Soft limit: typing past 80 is allowed; the counter turns red instead of truncating.
            return TextInputModel(label: "About me", placeholder: "Tell us a bit about yourself", maxLength: 80,
                                  showCount: true, hardLimit: false, countStyle: .remaining)
        case .card:
            return TextInputModel(label: "Card number", placeholder: "0000 0000 0000 0000", leadingSystemImage: "creditcard",
                                  formatter: .creditCard())
        case .phone:
            return TextInputModel(label: "Phone", placeholder: "0### ### ## ##", leadingSystemImage: "phone",
                                  formatter: .phoneTR)
        case .currency:
            return TextInputModel(label: "Amount", placeholder: "$0", leadingSystemImage: "dollarsign.circle",
                                  formatter: .currency())
        case .addons:
            return TextInputModel(label: "Domain name", placeholder: "yoursite", addonBefore: "https://", addonAfter: ".com")
        }
    }

    private var demoA11yID: String {
        switch mode {
        case .email: return "demoEmail"
        case .password: return "demoPassword"
        case .bio: return "demoBio"
        case .card: return "demoCard"
        case .phone: return "demoPhone"
        case .currency: return "demoAmount"
        case .addons: return "demoAddons"
        }
    }

    var body: some View {
        ComponentStage("TextInput", inspector: [("mode", mode.rawValue), ("value", "\"\(text)\""), ("readOnly", "\(readOnly)")]) {
            TextInput(model, text: $text)
                .size([.small, .medium, .large][sizeIdx])
                .a11yID(demoA11yID)
                .readOnly(readOnly)
        } knobs: {
            Text("email = keyboard/autofill + validation. password = password-manager autofill. bio = soft limit (exceed 80 → red counter). card/phone/currency = format-as-you-type masks.").font(.caption).foregroundStyle(.secondary)
            Picker("Mode", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
            Toggle("Read-only (keeps chrome, blocks editing)", isOn: $readOnly)
            Button("Reset") { text = ""; loggedIn = false }
        }
        .onChange(of: mode) { _, _ in text = ""; loggedIn = false }
        .onAppear {
            // Screenshot hook: launch with `-textInputMask card|phone|currency`.
            if let raw = UserDefaults.standard.string(forKey: "textInputMask"),
               let m = Mode(rawValue: raw) {
                mode = m
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    text = m == .currency ? "1234567" : "4242424242424242"
                }
            }
        }
    }
}

struct PhoneFieldDemo: View {
    @State private var number = ""
    @State private var dial = DialCode(regionCode: "TR", code: "+90")
    @State private var shortList = false
    @State private var searchIdx = 0   // 0 auto (>8 → searchable), 1 searchable, 2 menu
    @State private var formats = true
    @State private var required = false

    private var codes: [DialCode] { shortList ? Array(DialCode.common.prefix(5)) : DialCode.common }
    private var resolvedPicker: String {
        switch searchIdx {
        case 1: return "sheet"
        case 2: return "menu"
        default: return codes.count > 8 ? "sheet (auto)" : "menu (auto)"
        }
    }

    var body: some View {
        ComponentStage("PhoneField", inspector: [
            ("dialCode", dial.code), ("codes", "\(codes.count)"),
            ("picker", resolvedPicker), ("value", "\"\(number)\""),
        ]) {
            let field = PhoneField("Phone", number: $number, dialCode: $dial)
                .dialCodes(codes)
                .formatsNumber(formats)
                .required(required)
                .a11yID("demoPhoneField")
            switch searchIdx {
            case 1: field.searchablePicker()
            case 2: field.searchablePicker(false)
            default: field
            }
        } knobs: {
            Text("Dial code is controlled here (inspector shows it live); the plain init seeds it from the device locale instead. More than 8 codes → searchable sheet by default; 8 or fewer → plain menu.").font(.caption).foregroundStyle(.secondary)
            Toggle("Short list (5 codes → menu picker)", isOn: $shortList)
            Picker("Picker", selection: $searchIdx) { Text("Auto").tag(0); Text("Searchable").tag(1); Text("Menu").tag(2) }.pickerStyle(.segmented)
            Toggle("Group digits (formatsNumber)", isOn: $formats)
            Toggle("Required", isOn: $required)
            Button("Reset") { number = ""; dial = DialCode(regionCode: "TR", code: "+90") }
        }
    }
}

struct SliderDemo: View {
    @State private var value = 4.0
    @State private var marks = false
    @State private var tooltip = true
    @State private var enabled = true
    @State private var vertical = false
    @State private var committed = "—"

    var body: some View {
        ComponentStage("Slider", inspector: [("value", "\(Int(value))"), ("axis", vertical ? "vertical" : "horizontal"), ("onChangeEnd", committed)]) {
            if vertical {
                ThemeKit.Slider(value: $value, in: 0...8, label: "Guests \(Int(value))")
                    .axis(.vertical, height: 180)
                    .onChangeEnd { committed = "\(Int($0))" }
                    .disabled(!enabled)
            } else {
                ThemeKit.Slider(value: $value, in: 0...8, label: "Guests \(Int(value))")
                    .marks(marks ? [0: "0", 4: "4", 8: "8"] : [:])
                    .showsValueTooltip(tooltip)
                    .onChangeEnd { committed = "\(Int($0))" }
                    .disabled(!enabled)
            }
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value, in: 0...8, step: 1) }
            Toggle("Vertical", isOn: $vertical)
            Toggle("Marks", isOn: $marks)
            Toggle("Value tooltip", isOn: $tooltip)
            Toggle("Enabled", isOn: $enabled)
            Text("Drag & release → onChangeEnd fires.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct RangeSliderDemo: View {
    @State private var lo = 200.0
    @State private var hi = 800.0
    @State private var inputs = false
    @State private var marks = true
    @State private var enabled = true
    @State private var lastCommit = "—"

    var body: some View {
        ComponentStage("RangeSlider", inspector: [("range", "\(Int(lo))–\(Int(hi))"), ("onChangeEnd", lastCommit)]) {
            if inputs {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .inputs(titles: ("Min $", "Max $"))
                    .onChangeEnd { l, u in lastCommit = "\(Int(l))–\(Int(u))" }
                    .disabled(!enabled)
            } else {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000)
                    .step(50)
                    .marks(marks ? [0, 250, 500, 750, 1000] : [])
                    .onChangeEnd { l, u in lastCommit = "\(Int(l))–\(Int(u))" }
                    .valueLabel { "$\(Int($0))" }
                    .disabled(!enabled)
            }
        } knobs: {
            Text("onChangeEnd fires on release / blur — drive the search there, not on every tick.").font(.caption).foregroundStyle(.secondary)
            Toggle("Linked inputs (validate-on-blur)", isOn: $inputs)
            Toggle("Marks (labeled ticks)", isOn: $marks)
            Toggle("Enabled", isOn: $enabled)
            HStack { Text("Lower"); SwiftUI.Slider(value: $lo, in: 0...hi, step: 50) }
            HStack { Text("Upper"); SwiftUI.Slider(value: $hi, in: lo...1000, step: 50) }
        }
    }
}

/// Storybook — every Ant Segmented variant at a glance.
struct SegmentedControlDemo: View {
    @State private var basic = 0
    @State private var round = 1
    @State private var icons = 0
    @State private var iconOnly = 0
    @State private var sS = 0
    @State private var sM = 1
    @State private var sL = 2
    @State private var vert = 0
    @State private var custom = 0
    @State private var outline = 2
    @State private var tinted = 0
    private let period = ["Daily", "Weekly", "Monthly"]

    var body: some View {
        ComponentStage("SegmentedControl") {
            VStack(alignment: .leading, spacing: 18) {
                section("Basic") { SegmentedControl(period, selection: $basic) }
                section("Round shape") { SegmentedControl(period, selection: $round).shape(.round) }
                section("Sizes — small / medium / large") {
                    VStack(alignment: .leading, spacing: 6) {
                        SegmentedControl(period, selection: $sS).size(.small).fullWidth(false)
                        SegmentedControl(period, selection: $sM).size(.medium).fullWidth(false)
                        SegmentedControl(period, selection: $sL).size(.large).fullWidth(false)
                    }
                }
                section("Icon + label (Map disabled)") {
                    SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                      SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                      SegmentItem("Map", systemImage: "map", isEnabled: false)], selection: $icons)
                }
                section("Icon-only") {
                    SegmentedControl([SegmentItem(icon: "list.bullet"), SegmentItem(icon: "square.grid.2x2"),
                                      SegmentItem(icon: "map")], selection: $iconOnly).fullWidth(false)
                }
                section("Vertical") {
                    SegmentedControl(["Recommended", "Price", "Rating"], selection: $vert).vertical().fullWidth(false)
                }
                section("Custom content (avatar over name)") {
                    SegmentedControl([
                        SegmentItem { avatarTab("A", "Ada") },
                        SegmentItem { avatarTab("B", "Bo") },
                        SegmentItem { avatarTab("C", "Cy") },
                    ], selection: $custom).fullWidth(false)
                }
                section("Disabled (whole control)") {
                    SegmentedControl(period, selection: .constant(0)).disabled(true)
                }
                section("selectionStyle .outline — the DatePriceStrip look") {
                    SegmentedControl(["17 Jul", "18 Jul", "19 Jul", "20 Jul"], selection: $outline)
                        .selectionStyle(.outline).shape(.round).fullWidth(false)
                }
                section(".tinted() + .dividers() — icon toggle, with a base color") {
                    VStack(alignment: .leading, spacing: 8) {
                        SegmentedControl([SegmentItem(icon: "chart.bar.fill"), SegmentItem(icon: "square.grid.2x2.fill"),
                                          SegmentItem(icon: "map.fill")], selection: $tinted)
                            .tinted().dividers().shape(.round).fullWidth(false)
                        SegmentedControl([SegmentItem(icon: "chart.bar.fill"), SegmentItem(icon: "square.grid.2x2.fill"),
                                          SegmentItem(icon: "map.fill")], selection: $tinted)
                            .tinted(.turquoise).dividers().shape(.round).fullWidth(false)
                    }
                }
            }
        }
    }

    @ViewBuilder private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func avatarTab(_ initial: String, _ name: String) -> some View {
        VStack(spacing: 4) {
            Text(initial).font(.system(size: 13, weight: .bold)).foregroundStyle(SemanticColor.primary.onSolid)
                .frame(width: 28, height: 28).background(Circle().fill(SemanticColor.primary.solid))
            Text(name).textStyle(.labelSm600)
        }
        .padding(.vertical, 2)
    }
}

struct InputNumberDemo: View {
    @State private var value = 2
    @State private var sizeIdx = 2   // 0 small, 1 medium, 2 large (TextInputSize ramp)
    @State private var showError = false
    @State private var editable = true
    @State private var priceMode = false   // toggles a step:50 + "$" unit config
    @State private var readOnly = false

    private var size: TextInputSize { [.small, .medium, .large][sizeIdx] }

    var body: some View {
        ComponentStage("InputNumber", inspector: [("value", "\(value)"), ("editable", "\(editable)"), ("readOnly", "\(readOnly)")]) {
            if priceMode {
                InputNumber("Max price", value: $value, range: 0...10000).step(50).unit("$")
                    .hint("Type or step by 50").size(size)
                    .editable(editable)
                    .readOnly(readOnly)
            } else {
                InputNumber("Guests", value: $value, range: 1...9).unit("guests")
                    .hint(showError ? nil : "Type a number or use ± ")
                    .errorText(showError ? "Too many" : nil).size(size)
                    .editable(editable)
                    .readOnly(readOnly)
            }
        } knobs: {
            Text("editable = type the value directly (Ant InputNumber); ± steps by `step`.").font(.caption).foregroundStyle(.secondary)
            Stepper("Value: \(value)", value: $value, in: 0...10000)
            Toggle("Editable (type to enter)", isOn: $editable)
            Toggle("Price mode (step 50, $)", isOn: $priceMode)
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
            Toggle("Read-only (keeps chrome, blocks stepping)", isOn: $readOnly)
            Toggle("Error state", isOn: $showError)
        }
        .onChange(of: priceMode) { _, price in value = price ? 500 : 2 }
    }
}

struct QuantityStepperDemo: View {
    @State private var value = 0
    @State private var bigStep = false

    var body: some View {
        ComponentStage("QuantityStepper", inspector: [("value", "\(value)"), ("step", bigStep ? "5" : "1")]) {
            QuantityStepper(value: $value, range: 0...100).step(bigStep ? 5 : 1)
        } knobs: {
            Toggle("Step 5", isOn: $bigStep)
            Stepper("Value: \(value)", value: $value, in: 0...100)
        }
    }
}

struct PaginationDemo: View {
    @State private var page = 4
    @State private var total = 20.0
    @State private var simple = false
    @State private var showTotal = true
    @State private var wideWindow = false
    @State private var jumper = true

    var body: some View {
        ComponentStage("Pagination", inspector: [("current", "\(page)"), ("total", "\(Int(total))"), ("siblings", wideWindow ? "2" : "1")]) {
            Pagination(current: $page, total: Int(total))
                .simple(simple)
                .window(sibling: wideWindow ? 2 : 1)
                .jumper(jumper && !simple, title: "Go")
                .showTotal(showTotal ? { _, t in "\(t) pages" } : nil)
        } knobs: {
            Stepper("Current: \(page)", value: $page, in: 1...Int(total))
            HStack { Text("Total"); SwiftUI.Slider(value: $total, in: 3...50, step: 1) }
            Toggle("Simple mode", isOn: $simple)
            Toggle("Wide window (siblingCount 2)", isOn: $wideWindow)
            Toggle("Quick jumper", isOn: $jumper)
            Toggle("Show total", isOn: $showTotal)
        }
    }
}

struct SpaceDemo: View {
    @State private var vertical = false
    @State private var sizeIdx = 0
    @State private var wrap = false
    @State private var alignIdx = 1
    private var size: SpaceSize { [.small, .medium, .large][sizeIdx] }
    private var align: SpaceAlign { [.start, .center, .end, .baseline][alignIdx] }

    var body: some View {
        ComponentStage("Space", inspector: [("dir", vertical ? "vertical" : "horizontal")]) {
            Space {
                ForEach(0..<6) { Tag("Item \($0)") }
            }
            .vertical(vertical).size(size).wrap(wrap).align(align)
            .frame(maxWidth: wrap ? 280 : nil, alignment: .leading)
        } knobs: {
            Toggle("Vertical", isOn: $vertical)
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
            Toggle("Wrap (horizontal)", isOn: $wrap)
            Picker("Align", selection: $alignIdx) { Text("start").tag(0); Text("center").tag(1); Text("end").tag(2); Text("base").tag(3) }.pickerStyle(.segmented)
            Text("Even spacing between children — direction, size, wrap, cross-align.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AffixDemo: View {
    @Environment(\.theme) private var theme
    @State private var affixed = false

    var body: some View {
        ComponentStage("Affix", inspector: [("affixed", "\(affixed)")]) {
            ScrollView {
                VStack(spacing: 10) {
                    Affix(offsetTop: 0) {
                        HStack {
                            Text("Pinned toolbar").textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                            Spacer()
                            if affixed { Tag("affixed").tagStyle(.info) }
                        }
                        .padding(10)
                        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 12))
                        .themeShadow(.soft)
                    }
                    .target("affixDemo")
                    .onChange { affixed = $0 }
                    ForEach(0..<20) { i in
                        Text("Row \(i)").frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(theme.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(10)
            }
            .coordinateSpace(name: "affixDemo")
            .frame(height: 300)
            .background(theme.background(.bgBase), in: RoundedRectangle(cornerRadius: 16))
        } knobs: {
            Text("Scroll the inner list → the toolbar pins to the top and 'affixed' flips.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FlexDemo: View {
    @Environment(\.theme) private var theme
    @State private var justifyIdx = 3   // spaceBetween
    @State private var alignIdx = 1     // center
    @State private var vertical = false
    @State private var wrap = false

    private let justifies: [(String, FlexJustify)] = [
        ("start", .start), ("center", .center), ("end", .end),
        ("space-between", .spaceBetween), ("space-around", .spaceAround), ("space-evenly", .spaceEvenly),
    ]
    private let aligns: [(String, FlexAlign)] = [("start", .start), ("center", .center), ("end", .end), ("stretch", .stretch)]

    var body: some View {
        ComponentStage("Flex", inspector: [("justify", justifies[justifyIdx].0), ("align", aligns[alignIdx].0)]) {
            Flex {
                ForEach(0..<4) { Tag("Item \($0)").color(.info) }
            }
            .direction(vertical ? .vertical : .horizontal)
            .justify(justifies[justifyIdx].1)
            .align(aligns[alignIdx].1)
            .wrap(wrap)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(10)
            .background(theme.background(.bgBase), in: RoundedRectangle(cornerRadius: 12))
        } knobs: {
            Picker("Justify", selection: $justifyIdx) {
                ForEach(Array(justifies.enumerated()), id: \.offset) { i, j in Text(j.0).tag(i) }
            }
            Picker("Align", selection: $alignIdx) {
                ForEach(Array(aligns.enumerated()), id: \.offset) { i, a in Text(a.0).tag(i) }
            }.pickerStyle(.segmented)
            Toggle("Vertical", isOn: $vertical)
            Toggle("Wrap", isOn: $wrap)
        }
    }
}

private struct AnchorSectionYKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct AnchorNavDemo: View {
    @Environment(\.theme) private var theme
    @State private var active = "s0"
    private let sections = (0..<5).map { AnchorItem("s\($0)", title: "Section \($0)") }

    var body: some View {
        ComponentStage("Anchor", inspector: [("active", active)]) {
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 16) {
                    AnchorNav(sections, active: $active)
                        .onSelect { id in withAnimation { proxy.scrollTo(id, anchor: .top) } }
                        .frame(width: 110)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sections) { s in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.title).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                                    Text("Body content for \(s.title.lowercased()).").textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                                }
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                                .padding(12)
                                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 12))
                                .id(s.id)
                                .background(GeometryReader { g in
                                    Color.clear.preference(key: AnchorSectionYKey.self,
                                                           value: [s.id: g.frame(in: .named("anchorScroll")).minY])
                                })
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .coordinateSpace(name: "anchorScroll")
                    .frame(height: 300)
                    .onPreferenceChange(AnchorSectionYKey.self) { ys in
                        let current = sections.last { (ys[$0.id] ?? .infinity) <= 40 } ?? sections.first
                        if let current, current.id != active { active = current.id }
                    }
                }
            }
        } knobs: {
            Text("Tap a link to scroll; scrolling updates the active link (scroll-spy).").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SplitterDemo: View {
    @Environment(\.theme) private var theme
    @State private var vertical = false

    var body: some View {
        ComponentStage("Splitter", inspector: [("axis", vertical ? "vertical" : "horizontal")]) {
            Splitter(initialFraction: 0.4) {
                pane("Pane A", .bgElevatorPrimary)
            } second: {
                pane("Pane B", .bgWhite)
            }
            .vertical(vertical)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border(.borderPrimary), lineWidth: 1))
        } knobs: {
            Toggle("Vertical (.vertical())", isOn: $vertical)
            Text("Drag the divider to resize the panes.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func pane(_ title: String, _ bg: Theme.BackgroundColorKey) -> some View {
        Text(title)
            .textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background(bg))
    }
}

struct CascaderDemo: View {
    @State private var path: [String] = []
    @State private var multiPaths: [[String]] = []
    @State private var searchable = false
    @State private var clearable = false
    @State private var readOnly = false
    @State private var multiple = false
    @State private var size: TextInputSize = .medium
    private let options = [
        CascaderOption("tr", label: "Türkiye", children: [
            CascaderOption("34", label: "İstanbul", children: [
                CascaderOption("kadikoy", label: "Kadıköy"), CascaderOption("besiktas", label: "Beşiktaş")]),
            CascaderOption("06", label: "Ankara", children: [
                CascaderOption("cankaya", label: "Çankaya"), CascaderOption("kecioren", label: "Keçiören")])]),
        CascaderOption("de", label: "Deutschland", children: [
            CascaderOption("be", label: "Berlin", children: [CascaderOption("mitte", label: "Mitte")]),
            CascaderOption("by", label: "Bayern", children: [CascaderOption("muc", label: "München")])]),
    ]

    var body: some View {
        ComponentStage("Cascader", inspector: [
            ("selection", multiple ? "\(multiPaths.count) path(s)" : (path.isEmpty ? "—" : path.joined(separator: "/"))),
            ("multiple", "\(multiple)"),
        ]) {
            cascader
        } knobs: {
            Toggle("Multiple (checkbox leaves)", isOn: $multiple)
            Picker("Size", selection: $size) {
                Text("S").tag(TextInputSize.small); Text("M").tag(TextInputSize.medium); Text("L").tag(TextInputSize.large)
            }.pickerStyle(.segmented)
            Toggle("Searchable (filter across levels)", isOn: $searchable)
            Toggle("Clearable (x when selected)", isOn: $clearable)
            Toggle("Read-only (keeps chrome, blocks opening)", isOn: $readOnly)
            Text("Pick through the columns; a leaf commits (single) or toggles (multiple).").font(.caption).foregroundStyle(.secondary)
        }
    }

    // Both selection inits return `Cascader`, so shared modifiers apply uniformly.
    @ViewBuilder private var cascader: some View {
        if multiple {
            configured(Cascader(options, selection: $multiPaths))
        } else {
            configured(Cascader(options, selection: $path))
        }
    }

    private func configured(_ view: Cascader) -> some View {
        // Cascader's own modifiers first (they return `Cascader`); the kit-wide
        // `.readOnly(_:)` returns `some View`, so it must come last.
        view.placeholder("Select region")
            .searchable(searchable)
            .clearable(clearable)
            .size(size)
            .readOnly(readOnly)
    }
}

struct TransferDemo: View {
    @State private var target: Set<String> = ["wifi"]
    @State private var searchable = false
    @State private var lockSpa = false
    private let items = [TransferItem("wifi", title: "Wi-Fi"), TransferItem("bkfst", title: "Breakfast"),
                         TransferItem("pool", title: "Pool"), TransferItem("gym", title: "Gym"),
                         TransferItem("spa", title: "Spa"), TransferItem("park", title: "Parking")]

    var body: some View {
        ComponentStage("Transfer", inspector: [("target", "\(target.count) items"), ("searchable", "\(searchable)")]) {
            Transfer(items, target: $target).titles("Available", "Included")
                .searchable(searchable)
                .itemEnabled(lockSpa ? { $0.key != "spa" } : nil)
        } knobs: {
            Toggle("Searchable (per-list filter)", isOn: $searchable)
            Toggle("Disable Spa (.itemEnabled)", isOn: $lockSpa)
            Text("Check items, then move them across with the arrows.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MentionsDemo: View {
    @State private var text = "Nice work "
    @State private var sizeIdx = 1   // 0 small, 1 medium, 2 large (TextInputSize ramp)
    @State private var readOnly = false
    private let people = [MentionOption("ada", label: "Ada Lovelace"), MentionOption("alan", label: "Alan Turing"),
                          MentionOption("grace", label: "Grace Hopper"), MentionOption("linus", label: "Linus Torvalds")]

    var body: some View {
        ComponentStage("Mentions", inspector: [("chars", "\(text.count)"), ("readOnly", "\(readOnly)")]) {
            Mentions(text: $text, options: people).placeholder("Type @ to mention someone…")
                .size([.small, .medium, .large][sizeIdx])
                .readOnly(readOnly)
        } knobs: {
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
            Toggle("Read-only (keeps chrome, blocks editing)", isOn: $readOnly)
            Text("Type '@' then a name → pick a suggestion; it inserts @value.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MasonryDemo: View {
    @Environment(\.theme) private var theme
    @State private var cols = 2
    private let heights: [CGFloat] = [90, 140, 70, 120, 100, 160, 80, 110, 95, 130]

    var body: some View {
        ComponentStage("Masonry", inspector: [("columns", "\(cols)")]) {
            ScrollView {
                Masonry {
                    ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                        RoundedRectangle(cornerRadius: 12).fill(SemanticColor.primary.soft).frame(height: h)
                            .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textHero)))
                    }
                }
                .columns(cols)
                .padding(4)
            }
            .frame(height: 320)
        } knobs: {
            Stepper("Columns: \(cols)", value: $cols, in: 1...4)
        }
    }
}

struct TreeViewDemo: View {
    @State private var checked: Set<String> = []
    @State private var checkable = true
    private let nodes = [
        TreeNode(id: "docs", "Documents", systemImage: "folder", children: [
            TreeNode(id: "cv", "Resume.pdf", systemImage: "doc"),
            TreeNode(id: "img", "Images", systemImage: "folder", children: [
                TreeNode(id: "a", "beach.jpg", systemImage: "photo"),
                TreeNode(id: "b", "city.jpg", systemImage: "photo")])]),
        TreeNode(id: "music", "Music", systemImage: "folder", children: [
            TreeNode(id: "s1", "song.mp3", systemImage: "music.note"),
            TreeNode(id: "s2", "album.zip", systemImage: "doc.zipper")]),
    ]

    var body: some View {
        ComponentStage("Tree", inspector: [("checked", "\(checked.count)")]) {
            TreeView(nodes, selection: $checked).checkable(checkable)
                .frame(maxWidth: .infinity, alignment: .leading)
        } knobs: {
            Toggle("Checkable", isOn: $checkable)
        }
    }
}

struct ColumnsGridDemo: View {
    @Environment(\.theme) private var theme
    @State private var cols = 3
    @State private var adaptive = false

    var body: some View {
        ComponentStage("Grid", inspector: [("mode", adaptive ? "adaptive ≥100" : "\(cols) cols")]) {
            ScrollView {
                Group {
                    if adaptive {
                        ColumnsGrid { cells }.adaptive(minWidth: 100).gutter(.medium)
                    } else {
                        ColumnsGrid { cells }.columns(cols).gutter(.medium)
                    }
                }
                .padding(4)
            }
            .frame(height: 260)
        } knobs: {
            Stepper("Columns: \(cols)", value: $cols, in: 1...4).disabled(adaptive)
            Toggle("Adaptive (min 100pt)", isOn: $adaptive)
        }
    }

    private var cells: some View {
        ForEach(0..<9) { i in
            RoundedRectangle(cornerRadius: 12).fill(SemanticColor.info.soft).frame(height: 60)
                .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)))
        }
    }
}

struct ControlRowDemo: View {
    @State private var accepted = false
    @State private var controlIdx = 1   // 0 toggle, 1 checkbox, 2 radio
    @State private var description = true
    @State private var required = true
    @State private var validate = true
    @State private var custom = false
    @State private var enabled = true
    @State private var leading = false

    private var control: ControlRowControl { controlIdx == 0 ? .toggle : controlIdx == 2 ? .radio : .checkbox }
    private var error: Bool { validate && !accepted }

    var body: some View {
        ComponentStage("ControlRow", inspector: [
            ("isOn", "\(accepted)"), ("control", controlIdx == 0 ? "toggle" : controlIdx == 2 ? "radio" : "checkbox"), ("hasError", "\(error)"),
        ]) {
            if custom {
                // Custom trailing indicator — the whole row still toggles isOn.
                ControlRow("Star this trip", isOn: $accepted)
                    .description("Saved trips appear on your profile.")
                    .indicator {
                        Image(systemName: accepted ? "star.fill" : "star")
                            .foregroundStyle(Theme.shared.foreground(.fgHero))
                    }
            } else {
                ControlRow("I agree to the terms", isOn: $accepted)
                    .control(control)
                    .description(description ? "By checking this box, you agree to our Terms of Service." : nil)
                    .required(required)
                    .hasError(error)
                    .errorText("This field is required.")
                    .controlPlacement(leading ? .leading : .trailing)
                    .disabled(!enabled)
            }
        } knobs: {
            Picker("Control", selection: $controlIdx) { Text("Toggle").tag(0); Text("Checkbox").tag(1); Text("Radio").tag(2) }.pickerStyle(.segmented)
            Toggle("Leading control (.controlPlacement)", isOn: $leading)
            Toggle("Description", isOn: $description)
            Toggle("Required asterisk", isOn: $required)
            Toggle("Validate (error until on)", isOn: $validate)
            Toggle("Custom indicator (star)", isOn: $custom)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct ScrollShadowDemo: View {
    @State private var horizontal = false
    @State private var visibility: ScrollShadowVisibility = .auto
    @State private var long = false

    var body: some View {
        ComponentStage("ScrollShadow", inspector: [
            ("axis", horizontal ? "horizontal" : "vertical"), ("visibility", visibility.rawValue),
        ]) {
            if horizontal {
                ScrollShadow {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Nonstop", "1 stop", "Morning", "Evening", "Refundable", "Baggage included", "Window seat"], id: \.self) { title in
                                Chip(title, isSelected: .constant(false))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .axis(.horizontal)
                .visibility(visibility)
                .length(long ? .lg : .md)
                .fadeColor(.bgWhite)
            } else {
                ScrollShadow {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(1..<21) { line in
                                Text("Terms & conditions, clause \(line)")
                                    .textStyle(.bodySm400)
                                    .foregroundStyle(Theme.shared.text(.textPrimary))
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .visibility(visibility)
                .length(long ? .xl : .lg)
                .fadeColor(.bgWhite)
                .frame(height: 200)
            }
        } knobs: {
            Picker("Visibility", selection: $visibility) {
                ForEach(ScrollShadowVisibility.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Horizontal chip row", isOn: $horizontal)
            Toggle("Longer fade", isOn: $long)
            Text(".auto follows the scroll position (iOS 18+); explicit modes are always-on.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LanguageSwitcherDemo: View {
    enum Variant: String, CaseIterable { case menu, list, inline }
    @State private var variant: Variant = .menu
    @State private var code = "en"
    @State private var flags = true
    @State private var native = true
    @State private var accented = false
    @State private var enabled = true
    @State private var readOnly = false

    private var languages: [AppLanguage] {
        [AppLanguage(code: "en"), AppLanguage(code: "de"), AppLanguage(code: "fr"), AppLanguage(code: "ar")]
    }
    private var switcherVariant: LanguageSwitcherVariant {
        switch variant { case .menu: return .menu; case .list: return .list; case .inline: return .inline }
    }

    var body: some View {
        ComponentStage("LanguageSwitcher", inspector: [
            ("variant", variant.rawValue), ("selection", code),
            ("nativeNames", "\(native)"), ("readOnly", "\(readOnly)"),
        ]) {
            LanguageSwitcher(variant == .inline ? Array(languages.prefix(3)) : languages, selection: $code)
                .variant(switcherVariant)
                .showsFlags(flags)
                .nativeNames(native)
                .accent(accented ? .success : nil)
                .readOnly(readOnly)
                .disabled(!enabled)
        } knobs: {
            Picker("Variant", selection: $variant) {
                ForEach(Variant.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Flags", isOn: $flags)
            Toggle("Native names (endonyms)", isOn: $native)
            Toggle("Success accent", isOn: $accented)
            Toggle("Enabled", isOn: $enabled)
            Toggle("Read-only", isOn: $readOnly)
            Text("Names derive from Locale — endonyms by default, exonyms in the environment locale when off.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
