//
//  FilterRow.swift
//  ThemeKit
//
//  Molecule. One selectable filter row — a checkbox + title + an optional result
//  count "(12)" and an optional leading icon, with an optional bottom separator.
//  Composed from the ``Checkbox`` atom. Token-bound. Stack several (see
//  ``FilterList``) to build a filter panel section.
//
//  ```swift
//  FilterRow("Direct", isOn: $direct).count(128)
//  ```
//

import SwiftUI

public struct FilterRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let title: String
    @Binding private var isOn: Bool
    // Appearance/state — mutated only through the modifiers below (R2).
    private var count: Int?
    private var systemImage: String?
    private var showsSeparator = false

    public init(_ title: String, isOn: Binding<Bool>) {   // R1
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        Button { isOn.toggle() } label: {
            VStack(spacing: 0) {
                HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                    Checkbox(isChecked: .constant(isOn))
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: 15)).foregroundStyle(theme.text(.textSecondary)).frame(width: 20)
                    }
                    Text(title).textStyle(.bodyBase400).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    Spacer(minLength: 4)
                    if let count, count > 0 {
                        Text("(\(count))").textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
                .frame(minHeight: 44)
                if showsSeparator { DividerView().size(.small) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterRow {
    /// A trailing result count — hidden when nil or zero.
    func count(_ value: Int?) -> Self { copy { $0.count = value } }
    /// An optional leading category icon (after the checkbox).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// Draw a hairline separator under the row.
    func showsSeparator(_ on: Bool = true) -> Self { copy { $0.showsSeparator = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var a = true
    @Previewable @State var b = false
    PreviewMatrix("FilterRow") {
        PreviewCase("Stacked · count + separator") {
            VStack(spacing: 0) {
                FilterRow("Direct", isOn: $a).count(128).showsSeparator()
                FilterRow("1 stop", isOn: $b).count(64)
            }
        }
        PreviewCase("Leading icon") {
            FilterRow("Free Wi-Fi", isOn: $a).icon("wifi").count(42)
        }
    }
}
