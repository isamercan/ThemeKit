//
//  Steps.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Numbered, labeled progress steps with done / active / todo / error
//  states, optional per-step description + icon, an optional clickable callback
//  and a small size. (Ant Steps parity.)
//

import SwiftUI

public enum StepState {
    case done, active, todo, error
}

/// A horizontal or vertical step / progress indicator with done / active / todo /
/// error states, an optional progress dot, and tap-to-navigate.
///
/// ```swift
/// Steps([.init("Cart", state: .done), .init("Pay", state: .active)]) { active = $0 }
/// ```
public struct Steps: View {
    @Environment(\.theme) private var theme

    public struct Step: Identifiable {
        public let id = UUID()
        let title: String
        let description: String?
        let systemImage: String?
        let state: StepState
        /// 0...1 ring drawn around the (active) marker — Ant Steps `percent`.
        let percent: Double?
        public init(_ title: String, description: String? = nil, systemImage: String? = nil, state: StepState, percent: Double? = nil) {
            self.title = title; self.description = description; self.systemImage = systemImage
            self.state = state; self.percent = percent
        }
    }

    private let steps: [Step]
    private let onSelect: ((Int) -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var axis: Axis = .horizontal
    private var small = false
    private var progressDot = false

    public init(_ steps: [Step], onSelect: ((Int) -> Void)? = nil) {   // R1
        self.steps = steps
        self.onSelect = onSelect
    }

    private var dotSize: CGFloat { progressDot ? 12 : (small ? 22 : 28) }

    public var body: some View {
        if axis == .horizontal {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    VStack(spacing: Theme.SpacingKey.xs.value) {
                        ZStack {
                            if index < steps.count - 1 {
                                Rectangle().fill(connectorColor(index))
                                    .frame(height: 2)
                                    .offset(x: dotSize * 0.57)
                            }
                            marker(step, number: index + 1)
                        }
                        Text(step.title)
                            .textStyle(small ? .labelSm600 : .labelSm600)
                            .foregroundStyle(titleColor(step.state))
                            .multilineTextAlignment(.center)
                        if let description = step.description {
                            Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(index) }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                        VStack(spacing: 0) {
                            marker(step, number: index + 1)
                            if index < steps.count - 1 {
                                Rectangle().fill(connectorColor(index)).frame(width: 2, height: 28)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .textStyle(.labelBase600)
                                .foregroundStyle(titleColor(step.state))
                            if let description = step.description {
                                Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(index) }
                }
            }
        }
    }

    @ViewBuilder
    private func marker(_ step: Step, number: Int) -> some View {
        ZStack {
            if progressDot {
                Circle().fill(dotFill(step.state)).frame(width: 10, height: 10)
            } else {
                Circle().fill(fill(step.state)).frame(width: dotSize, height: dotSize)
                Circle().strokeBorder(stroke(step.state), lineWidth: 1.5).frame(width: dotSize, height: dotSize)
                glyph(step, number: number)
                if let percent = step.percent, step.state == .active {
                    Circle().trim(from: 0, to: CGFloat(min(max(percent, 0), 1)))
                        .stroke(theme.background(.bgHero), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: dotSize + 7, height: dotSize + 7)
                }
            }
        }
        .frame(width: dotSize, height: dotSize)
    }

    private func dotFill(_ state: StepState) -> Color {
        switch state {
        case .done, .active: return theme.background(.bgHero)
        case .error: return theme.background(.systemcolorsBgError)
        case .todo: return theme.border(.borderPrimary)
        }
    }

    @ViewBuilder
    private func glyph(_ step: Step, number: Int) -> some View {
        let iconSize = small ? 10.0 : 12.0
        switch step.state {
        case .done:
            Image(systemName: step.systemImage ?? "checkmark").font(.system(size: iconSize, weight: .bold)).foregroundStyle(theme.foreground(.fgSecondary))
        case .error:
            Image(systemName: "xmark").font(.system(size: iconSize, weight: .bold)).foregroundStyle(theme.foreground(.fgSecondary))
        case .active:
            if let icon = step.systemImage {
                Image(systemName: icon).font(.system(size: iconSize, weight: .bold)).foregroundStyle(theme.foreground(.fgSecondary))
            } else {
                Text("\(number)").textStyle(.labelSm700).foregroundStyle(theme.foreground(.fgSecondary))
            }
        case .todo:
            Text("\(number)").textStyle(.labelSm700).foregroundStyle(theme.text(.textTertiary))
        }
    }

    private func fill(_ state: StepState) -> Color {
        switch state {
        case .done, .active: return theme.background(.bgHero)
        case .error: return theme.background(.systemcolorsBgError)
        case .todo: return theme.background(.bgWhite)
        }
    }
    private func stroke(_ state: StepState) -> Color {
        switch state {
        case .todo: return theme.border(.borderPrimary)
        case .error: return theme.background(.systemcolorsBgError)
        case .done, .active: return theme.background(.bgHero)
        }
    }
    private func titleColor(_ state: StepState) -> Color {
        switch state {
        case .todo: return theme.text(.textTertiary)
        case .error: return theme.foreground(.systemcolorsFgError)
        case .done, .active: return theme.text(.textPrimary)
        }
    }
    private func connectorColor(_ index: Int) -> Color {
        steps[index].state == .done ? theme.background(.bgHero) : theme.border(.borderPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Steps {
    /// Layout orientation: horizontal / vertical.
    func axis(_ a: Axis) -> Self { copy { $0.axis = a } }

    /// Compact markers and labels.
    func small(_ on: Bool = true) -> Self { copy { $0.small = on } }

    /// Render minimal progress dots instead of numbered markers (Ant `progressDot`).
    func progressDot(_ on: Bool = true) -> Self { copy { $0.progressDot = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 40) {
        Steps([.init("Cart", state: .done), .init("Address", description: "Shipping", state: .done), .init("Payment", state: .error), .init("Done", state: .todo)])
        Steps([.init("Account", description: "Your details", state: .done), .init("Profile", state: .active), .init("Confirm", state: .todo)]).axis(.vertical)
    }
    .padding()
}
