//
//  MoleculeDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Interactive demo pages + small stateful previews for molecule components.
//

import SwiftUI
import ThemeKit

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
                    case .primary: PrimaryButton(title, size: size, block: fullWidth, helperText: helperText, task: work).disabled(!enabled)
                    case .secondary: SecondaryButton(title, size: size, block: fullWidth, helperText: helperText, task: work).disabled(!enabled)
                    case .outline: OutlineButton(title, size: size, block: fullWidth, helperText: helperText, task: work).disabled(!enabled)
                    case .ghost: GhostButton(title, size: size, block: fullWidth, helperText: helperText, task: work).disabled(!enabled)
                    case .link: LinkButton(title, size: size, action: tapped).disabled(!enabled)
                    }
                } else {
                    switch style {
                    case .primary: PrimaryButton(title, size: size, block: fullWidth, helperText: helperText, isLoading: $loading, action: tapped).disabled(!enabled)
                    case .secondary: SecondaryButton(title, size: size, block: fullWidth, helperText: helperText, isLoading: $loading, action: tapped).disabled(!enabled)
                    case .outline: OutlineButton(title, size: size, block: fullWidth, helperText: helperText, isLoading: $loading, action: tapped).disabled(!enabled)
                    case .ghost: GhostButton(title, size: size, block: fullWidth, helperText: helperText, isLoading: $loading, action: tapped).disabled(!enabled)
                    case .link: LinkButton(title, size: size, action: tapped).disabled(!enabled)
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
        (requiredError && !checked) ? [InfoMessage("Accept to continue", kind: .error)] : []
    }

    var body: some View {
        ComponentStage("Checkbox", inspector: [("isChecked", "\(checked)"), ("type", typeIdx == 1 ? "inner" : typeIdx == 2 ? "customInner" : "plain")]) {
            Checkbox(withLabel ? "I accept the terms and conditions" : nil, isChecked: $checked,
                     customSize: big ? 32 : nil, type: type,
                     isIndeterminate: indeterminate, alignment: .top,
                     infoMessages: messages)
                    .controlSize(small ? .small : .regular)
                    .disabled(!enabled)
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
            RadioButton(inlineLabel ? "Remember me" : nil, isSelected: $selected,
                        type: check ? .check : .select,
                        style: inner ? .inner : .plain, padding: .medium)
                    .controlSize(small ? .small : .regular)
                    .disabled(!enabled)
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
            ThemeToggle(isOn: $on, isLoading: loading,
                        onSystemImage: icons ? "checkmark" : nil, offSystemImage: icons ? "xmark" : nil)
                .controlSize(small ? .small : .regular)
                .disabled(!enabled)
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
    private enum Mode: String, CaseIterable { case email, password, bio, card, phone, currency, addons }
    @State private var text = ""
    @State private var mode: Mode = .email
    @State private var loggedIn = false

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
        ComponentStage("TextInput", inspector: [("mode", mode.rawValue), ("value", "\"\(text)\""), ("login", "\(loggedIn)")]) {
            TextInput(model, text: $text).a11yID(demoA11yID)
        } knobs: {
            Text("email = keyboard/autofill + validation. password = password-manager autofill. bio = soft limit (exceed 80 → red counter). card/phone/currency = format-as-you-type masks.").font(.caption).foregroundStyle(.secondary)
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
    @State private var committed = "—"

    var body: some View {
        ComponentStage("Slider", inspector: [("value", "\(Int(value))"), ("axis", vertical ? "vertical" : "horizontal"), ("onChangeEnd", committed)]) {
            if vertical {
                ThemeKit.Slider(value: $value, in: 0...8, step: 1, label: "Guests \(Int(value))")
                    .axis(.vertical, height: 180)
                    .onChangeEnd { committed = "\(Int($0))" }
                    .disabled(!enabled)
            } else {
                ThemeKit.Slider(value: $value, in: 0...8, step: 1, label: "Guests \(Int(value))")
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
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50)
                    .inputs(titles: ("Min $", "Max $"))
                    .onChangeEnd { l, u in lastCommit = "\(Int(l))–\(Int(u))" }
                    .disabled(!enabled)
            } else {
                RangeSlider(lowerValue: $lo, upperValue: $hi, in: 0...1000, step: 50)
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

struct SegmentedControlDemo: View {
    @State private var selection = 0
    @State private var icons = false
    @State private var block = true
    @State private var enabled = true
    @State private var sizeIdx = 1   // 0 small, 1 medium, 2 large
    private var size: SegmentedSize { sizeIdx == 0 ? .small : sizeIdx == 2 ? .large : .medium }

    var body: some View {
        ComponentStage("SegmentedControl", inspector: [("selection", "\(selection)"), ("block", "\(block)"), ("size", sizeIdx == 0 ? "small" : sizeIdx == 2 ? "large" : "medium")]) {
            if icons {
                SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                  SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                  SegmentItem("Map", systemImage: "map", isEnabled: false)],
                                 selection: $selection, block: block, size: size)
                    .disabled(!enabled)
            } else {
                SegmentedControl(["Daily", "Weekly", "Monthly"], selection: $selection, block: block, size: size)
                    .disabled(!enabled)
            }
        } knobs: {
            Stepper("Selection: \(selection)", value: $selection, in: 0...2)
            Toggle("Icons + disabled option", isOn: $icons)
            Toggle("Block (full width)", isOn: $block)
            Toggle("Enabled", isOn: $enabled)
            Picker("Size", selection: $sizeIdx) { Text("S").tag(0); Text("M").tag(1); Text("L").tag(2) }.pickerStyle(.segmented)
        }
    }
}

struct InputNumberDemo: View {
    @State private var value = 2
    @State private var large = true
    @State private var showError = false
    @State private var editable = true
    @State private var priceMode = false   // toggles a step:50 + "$" unit config

    var body: some View {
        ComponentStage("InputNumber", inspector: [("value", "\(value)"), ("editable", "\(editable)")]) {
            if priceMode {
                InputNumber(label: "Max price", value: $value, range: 0...10000, step: 50, unit: "$",
                            hint: "Type or step by 50", large: large)
                    .editable(editable)
            } else {
                InputNumber(label: "Guests", value: $value, range: 1...9, unit: "guests",
                            hint: showError ? nil : "Type a number or use ± ",
                            errorText: showError ? "Too many" : nil, large: large)
                    .editable(editable)
            }
        } knobs: {
            Text("editable = type the value directly (Ant InputNumber); ± steps by `step`.").font(.caption).foregroundStyle(.secondary)
            Stepper("Value: \(value)", value: $value, in: 0...10000)
            Toggle("Editable (type to enter)", isOn: $editable)
            Toggle("Price mode (step 50, $)", isOn: $priceMode)
            Toggle("Large", isOn: $large)
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
            QuantityStepper(value: $value, range: 0...100, step: bigStep ? 5 : 1)
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
