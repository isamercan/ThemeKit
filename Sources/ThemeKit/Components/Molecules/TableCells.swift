//
//  TableCells.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Compact inline editors for `DataTable`'s existing custom-cell `@ViewBuilder`
//  slot — a toggle, a select, a slider and a color well sized to sit in a table
//  row. (HeroUI Pro "Cell Switch / Select / Slider / Color Picker".) They wrap
//  the shipped controls and bind straight into the caller's row store; DataTable
//  itself is untouched. Each takes a `label` for its VoiceOver identity.
//

import SwiftUI

/// A row-height boolean toggle.
public struct TableToggleCell: View {
    @Binding private var isOn: Bool
    private let label: String
    public init(isOn: Binding<Bool>, label: String) {
        self._isOn = isOn
        self.label = label
    }
    public var body: some View {
        ThemeToggle(isOn: $isOn)
            .accessibilityLabel(label)
    }
}

/// A compact menu picker over string options.
public struct TableSelectCell: View {
    @Environment(\.theme) private var theme
    private let options: [String]
    @Binding private var selection: String
    private let label: String
    public init(_ options: [String], selection: Binding<String>, label: String) {
        self.options = options
        self._selection = selection
        self.label = label
    }
    public var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection).textStyle(.bodyBase400).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                Icon(systemName: "chevron.up.chevron.down").size(.sm).color(theme.text(.textTertiary))
            }
        }
        .accessibilityLabel(label)
    }
}

/// A compact value slider, tinted with the hero token.
public struct TableSliderCell: View {
    @Environment(\.theme) private var theme
    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let label: String
    public init(value: Binding<Double>, in bounds: ClosedRange<Double>, label: String) {
        self._value = value
        self.bounds = bounds
        self.label = label
    }
    public var body: some View {
        // The native compact slider — the kit `Slider` molecule carries label /
        // tooltip chrome too tall for a table row.
        SwiftUI.Slider(value: $value, in: bounds)
            .tint(theme.foreground(.fgHero))
            .controlSize(.small)
            .accessibilityLabel(label)
    }
}

/// A system color well for editing a `Color` in place.
public struct TableColorCell: View {
    @Binding private var selection: Color
    private let label: String
    public init(selection: Binding<Color>, label: String) {
        self._selection = selection
        self.label = label
    }
    public var body: some View {
        ColorPicker("", selection: $selection)
            .labelsHidden()
            .accessibilityLabel(label)
    }
}

#Preview {
    @Previewable @State var on = true
    @Previewable @State var pick = "Medium"
    @Previewable @State var amount = 0.4
    @Previewable @State var color = Color.blue
    PreviewMatrix("Table cells") {
        PreviewCase("Toggle") { TableToggleCell(isOn: $on, label: "Active") }
        PreviewCase("Select") { TableSelectCell(["Low", "Medium", "High"], selection: $pick, label: "Priority") }
        PreviewCase("Slider") { TableSliderCell(value: $amount, in: 0...1, label: "Amount") }
        PreviewCase("Color") { TableColorCell(selection: $color, label: "Color") }
    }
}
