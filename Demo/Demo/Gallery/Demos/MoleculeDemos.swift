//
//  MoleculeDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Interactive demo pages + small stateful previews for molecule components.
//

import SwiftUI
import GlobalUIComponents

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

    private var helperText: String? { helper ? "KDV dahil fiyat" : nil }
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
                    case .primary: PrimaryButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, task: work)
                    case .secondary: SecondaryButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, task: work)
                    case .outline: OutlineButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, task: work)
                    case .ghost: GhostButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, task: work)
                    case .link: LinkButton(title, size: size, isEnabled: $enabled, action: tapped)
                    }
                } else {
                    switch style {
                    case .primary: PrimaryButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, isLoading: $loading, action: tapped)
                    case .secondary: SecondaryButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, isLoading: $loading, action: tapped)
                    case .outline: OutlineButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, isLoading: $loading, action: tapped)
                    case .ghost: GhostButton(title, size: size, isContentWidth: fullWidth, helperText: helperText, isEnabled: $enabled, isLoading: $loading, action: tapped)
                    case .link: LinkButton(title, size: size, isEnabled: $enabled, action: tapped)
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
    @State private var small = false
    @State private var enabled = true
    @State private var withLabel = true
    @State private var requiredError = true
    @State private var big = false
    @State private var typeIdx = 0   // 0 plain, 1 inner, 2 customInner

    private var type: CheckboxType {
        switch typeIdx {
        case 1: return .inner
        case 2: return .customInner(color: SemanticColor.primary.base)
        default: return .plain
        }
    }

    // Required-checkbox semantic: error only while unchecked (like reference shouldWarn).
    private var messages: [InfoMessage] {
        (requiredError && !checked) ? [InfoMessage("Devam etmek için kabul edin", kind: .error)] : []
    }

    var body: some View {
        ComponentStage("Checkbox", inspector: [("isChecked", "\(checked)"), ("type", typeIdx == 1 ? "inner" : typeIdx == 2 ? "customInner" : "plain")]) {
            Checkbox(withLabel ? "Şartları ve koşulları kabul ediyorum" : nil, isChecked: $checked,
                     size: small ? .small : .medium, customSize: big ? 32 : nil, type: type,
                     isIndeterminate: indeterminate, alignment: .top,
                     infoMessages: messages, isEnabled: enabled)
        } knobs: {
            Toggle("Checked", isOn: $checked)
            Toggle("Custom size (32)", isOn: $big)
            Picker("Type", selection: $typeIdx) { Text("Plain").tag(0); Text("Inner").tag(1); Text("Swatch").tag(2) }.pickerStyle(.segmented)
            Toggle("Required (error when unchecked)", isOn: $requiredError)
            Toggle("Inline label", isOn: $withLabel)
            Toggle("Indeterminate", isOn: $indeterminate)
            Toggle("Small", isOn: $small)
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

    var body: some View {
        ComponentStage("RadioButton", inspector: [("type", check ? "check" : "select"), ("style", inner ? "inner" : "plain")]) {
            RadioButton(inlineLabel ? "Hatırla beni" : nil, isSelected: $selected,
                        size: small ? .small : .medium, type: check ? .check : .select,
                        style: inner ? .inner : .plain, padding: .medium, isEnabled: enabled)
        } knobs: {
            Toggle("Selected", isOn: $selected)
            Toggle("Inline label", isOn: $inlineLabel)
            Toggle("Check type (toggles)", isOn: $check)
            Toggle("Inner style (check)", isOn: $inner)
            Toggle("Small", isOn: $small)
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

    var body: some View {
        ComponentStage("ThemeToggle", inspector: [("isOn", "\(on)"), ("isLoading", "\(loading)"), ("isEnabled", "\(enabled)")]) {
            ThemeToggle(isOn: $on, size: small ? .small : .medium, isEnabled: enabled, isLoading: loading,
                        onSystemImage: icons ? "checkmark" : nil, offSystemImage: icons ? "xmark" : nil)
        } knobs: {
            Toggle("On", isOn: $on)
            Toggle("Loading", isOn: $loading)
            Toggle("Inner icons", isOn: $icons)
            Toggle("Small", isOn: $small)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct TextInputDemo: View {
    private enum Mode: String, CaseIterable { case email, card, phone, currency, addons }
    @State private var text = ""
    @State private var mode: Mode = .email
    @State private var loggedIn = false

    private var model: TextInputModel {
        switch mode {
        case .email:
            var msgs = Validator.validate(text, [.required("E-posta zorunlu"), .email()], all: true)
            if msgs.isEmpty, !text.isEmpty {   // clickable info link (reference clickableParts)
                msgs = [InfoMessage("Bu e-posta kayıtlı. Giriş yap", kind: .info,
                                    links: [("Giriş yap", { loggedIn = true })])]
            }
            return TextInputModel(label: "E-posta", placeholder: "ad@sirket.com", leadingSystemImage: "envelope",
                                  allowClear: true, infoMessages: msgs, accessibilityID: "demoEmail")
        case .card:
            return TextInputModel(label: "Kart No", placeholder: "0000 0000 0000 0000", leadingSystemImage: "creditcard",
                                  formatter: .creditCard(), accessibilityID: "demoCard")
        case .phone:
            return TextInputModel(label: "Telefon", placeholder: "0### ### ## ##", leadingSystemImage: "phone",
                                  formatter: .phoneTR, accessibilityID: "demoPhone")
        case .currency:
            return TextInputModel(label: "Tutar", placeholder: "₺0", leadingSystemImage: "turkishlirasign.circle",
                                  formatter: .currency(), accessibilityID: "demoAmount")
        case .addons:
            return TextInputModel(label: "Alan adı", placeholder: "siteniz", addonBefore: "https://", addonAfter: ".com.tr",
                                  accessibilityID: "demoAddons")
        }
    }

    var body: some View {
        ComponentStage("TextInput", inspector: [("mode", mode.rawValue), ("value", "\"\(text)\""), ("login", "\(loggedIn)")]) {
            TextInput(model, text: $text)
        } knobs: {
            Text("email = .required + .email validation (with clickable link). card/phone/currency = format-as-you-type masks.").font(.caption).foregroundStyle(.secondary)
            Picker("Mode", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
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

struct SliderDemo: View {
    @State private var value = 4.0
    @State private var marks = false
    @State private var tooltip = true
    @State private var enabled = true
    @State private var vertical = false

    var body: some View {
        ComponentStage("Slider", inspector: [("value", "\(Int(value))"), ("axis", vertical ? "vertical" : "horizontal")]) {
            if vertical {
                GlobalUIComponents.Slider(value: $value, in: 0...8, step: 1, label: "Guests \(Int(value))",
                                          axis: .vertical, verticalHeight: 180, isEnabled: enabled)
            } else {
                GlobalUIComponents.Slider(value: $value, in: 0...8, step: 1, label: "Guests \(Int(value))",
                                          marks: marks ? [0: "0", 4: "4", 8: "8"] : [:],
                                          isEnabled: enabled, showValueTooltip: tooltip)
            }
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value, in: 0...8, step: 1) }
            Toggle("Vertical", isOn: $vertical)
            Toggle("Marks", isOn: $marks)
            Toggle("Value tooltip", isOn: $tooltip)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct RangeSliderDemo: View {
    @State private var lo = 200.0
    @State private var hi = 800.0
    @State private var inputs = false

    var body: some View {
        ComponentStage("RangeSlider", inspector: [("lower", "\(Int(lo))"), ("upper", "\(Int(hi))"), ("inputs", "\(inputs)")]) {
            if inputs {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50, showInputs: true, inputTitles: ("En az ₺", "En çok ₺"))
            } else {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50) { "\(Int($0)) ₺" }
            }
        } knobs: {
            Toggle("Linked inputs (validate-on-blur)", isOn: $inputs)
            HStack { Text("Lower"); SwiftUI.Slider(value: $lo, in: 0...hi, step: 50) }
            HStack { Text("Upper"); SwiftUI.Slider(value: $hi, in: lo...1000, step: 50) }
        }
    }
}

struct SegmentedControlDemo: View {
    @State private var selection = 0
    @State private var icons = false

    var body: some View {
        ComponentStage("SegmentedControl", inspector: [("selection", "\(selection)"), ("icons", "\(icons)")]) {
            if icons {
                SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                  SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                  SegmentItem("Map", systemImage: "map", isEnabled: false)], selection: $selection)
            } else {
                SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $selection)
            }
        } knobs: {
            Stepper("Selection: \(selection)", value: $selection, in: 0...2)
            Toggle("Icons + disabled option", isOn: $icons)
        }
    }
}

struct InputNumberDemo: View {
    @State private var value = 2
    @State private var large = true
    @State private var showError = false

    var body: some View {
        ComponentStage("InputNumber", inspector: [("value", "\(value)")]) {
            InputNumber(label: "Guests", value: $value, range: 1...9,
                        hint: showError ? nil : "Max 9 guests",
                        errorText: showError ? "Too many" : nil, large: large)
        } knobs: {
            Stepper("Value: \(value)", value: $value, in: 1...9)
            Toggle("Large", isOn: $large)
            Toggle("Error state", isOn: $showError)
        }
    }
}

struct QuantityStepperDemo: View {
    @State private var value = 1

    var body: some View {
        ComponentStage("QuantityStepper", inspector: [("value", "\(value)")]) {
            QuantityStepper(value: $value, range: 0...10)
        } knobs: {
            Stepper("Value: \(value)", value: $value, in: 0...10)
        }
    }
}

struct PaginationDemo: View {
    @State private var page = 4
    @State private var total = 10.0
    @State private var simple = false
    @State private var showTotal = true

    var body: some View {
        ComponentStage("Pagination", inspector: [("current", "\(page)"), ("total", "\(Int(total))"), ("simple", "\(simple)")]) {
            Pagination(current: $page, total: Int(total), simple: simple,
                       showTotal: showTotal ? { _, t in "\(t) sayfa" } : nil)
        } knobs: {
            Stepper("Current: \(page)", value: $page, in: 1...Int(total))
            HStack { Text("Total"); SwiftUI.Slider(value: $total, in: 3...20, step: 1) }
            Toggle("Simple mode", isOn: $simple)
            Toggle("Show total", isOn: $showTotal)
        }
    }
}
