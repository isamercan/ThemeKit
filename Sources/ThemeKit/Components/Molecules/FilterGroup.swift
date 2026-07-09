//
//  FilterGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A single-select chip filter with a reset control. (daisyUI "Filter".)
public struct FilterGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var chipSize: ChipSize = .small
    private var selectionStyle: ChipSelectionStyle = .solid
    private var fillsWidth = false
    private var isOptionEnabled: ((Option) -> Bool)?
    private var infoMessages: [InfoMessage] = []

    public init(title: String? = nil, options: [Option], selection: Binding<Option?>, label: @escaping (Option) -> String) {
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
    }

    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    /// The most severe message tints the group title (RadioGroup convention).
    private var titleColor: Color {
        switch infoMessages.dominantKind {
        case .error: return theme.foreground(.systemcolorsFgError)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        default: return theme.text(.textPrimary)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(titleColor)
            }
            if fillsWidth {
                chips
            } else {
                ScrollView(.horizontal, showsIndicators: false) { chips }
            }
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages)
            }
        }
        // Animate message rows in/out (their `.transition` lives in
        // `InfoMessageList`); gated by `microAnimations` + Reduce Motion.
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: infoMessages)
    }

    private var chips: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if selection != nil {
                Button { selection = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.text(.textTertiary))
                        .frame(width: 32, height: 32)
                        .background(theme.background(.bgElevatorPrimary), in: Circle())
                        .overlay(Circle().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            ForEach(options, id: \.self) { option in
                let enabled = optionEnabled(option)
                Chip(label(option),
                     isSelected: Binding(get: { selection == option }, set: { isOn in selection = isOn ? option : nil }))
                    .chipStyle(selectionStyle)
                    .size(chipSize)
                    .expands(fillsWidth)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterGroup {
    /// Chip control size: small / large (default small).
    func size(_ s: ChipSize) -> Self { copy { $0.chipSize = s } }
    /// How the selected chip is filled: tonal / solid (default solid).
    func chipStyle(_ s: ChipSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// Stretch the chips edge-to-edge instead of scrolling horizontally —
    /// for option sets known to fit the row.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.fillsWidth = on } }
    /// Per-option enablement predicate (nil enables every option).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }
    /// Validation / info messages rendered under the chips (drive the title color).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var sel: String? = "Hotels"
        @State var stops: String? = "Direct"
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                FilterGroup(title: "Category", options: ["Hotels", "Flights", "Cars", "Tours"], selection: $sel) { $0 }
                FilterGroup(title: "Stops", options: ["Direct", "1 stop", "2+"], selection: $stops) { $0 }
                    .chipStyle(.tonal)
                    .fullWidth()
                // Per-option disabled: "Cars" renders dimmed + non-interactive.
                FilterGroup(title: "Per-option disabled", options: ["Hotels", "Flights", "Cars", "Tours"], selection: $sel) { $0 }
                    .optionEnabled { $0 != "Cars" }
                // Invalid state: messages under the chips + error-tinted title.
                FilterGroup(title: "With error", options: ["Direct", "1 stop", "2+"], selection: .constant(nil)) { $0 }
                    .infoMessages([InfoMessage("Choose a stop filter", kind: .error)])
            }
            .padding()
        }
    }
    return Demo()
}
