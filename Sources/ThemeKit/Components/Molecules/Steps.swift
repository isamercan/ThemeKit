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

/// Size tiers for ``Steps`` markers + labels — the kit's uniform size-enum
/// vocabulary (replaces the boolean `small()` toggle, C5).
public enum StepsSize: Sendable {
    case small, medium
}

/// A horizontal or vertical step / progress indicator with done / active / todo /
/// error states, an optional progress dot, and tap-to-navigate.
///
/// ```swift
/// Steps([.init("Cart", state: .done), .init("Pay", state: .active)]) { active = $0 }
/// ```
public struct Steps: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    public struct Step: Identifiable {
        public let id = UUID()
        let title: String
        /// Secondary title shown next to the main title in a lighter tone (Ant `subTitle`).
        let subTitle: String?
        let description: String?
        let systemImage: String?
        let state: StepState
        /// 0...1 ring drawn around the (active) marker — Ant Steps `percent`.
        let percent: Double?
        /// Blocks tapping and dims the step (Ant `items[].disabled`).
        let disabled: Bool
        public init(_ title: String, subTitle: String? = nil, description: String? = nil,
                    systemImage: String? = nil, state: StepState = .todo,
                    disabled: Bool = false, percent: Double? = nil) {
            self.title = title; self.subTitle = subTitle; self.description = description
            self.systemImage = systemImage; self.state = state
            self.disabled = disabled; self.percent = percent
        }
    }

    private let steps: [Step]
    private let onSelect: ((Int) -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var axis: Axis = .horizontal
    private var size: StepsSize = .medium
    private var progressDot = false
    /// Controlled current index (Ant `current`) — derives done/active/todo per
    /// step from position; `nil` keeps each step's own explicit `state`.
    private var currentOverride: Int?
    /// Custom per-step marker (`marker(_:)`); nil renders the stock circle/number.
    private var markerBuilder: ((Step, Int) -> AnyView)? = nil

    public init(_ steps: [Step], onSelect: ((Int) -> Void)? = nil) {   // R1
        self.steps = steps
        self.onSelect = onSelect
    }

    private var small: Bool { size == .small }
    private var dotSize: CGFloat { progressDot ? 12 : (small ? 22 : 28) }

    public var body: some View {
        // `.offset(x:)` doesn't auto-mirror: in RTL the next step sits to the
        // LEFT, so the connector's half-marker nudge toward it flips sign.
        let dir: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        if axis == .horizontal {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    let state = effectiveState(step, index)
                    VStack(spacing: Theme.SpacingKey.xs.value) {
                        ZStack {
                            if index < steps.count - 1 {
                                Rectangle().fill(connectorColor(index))
                                    .frame(height: 2)
                                    .offset(x: dir * dotSize * 0.57)
                            }
                            marker(step, index: index, state: state)
                        }
                        titleLabel(step, state: state).multilineTextAlignment(.center)
                        if let description = step.description {
                            Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(step.disabled ? 0.4 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { if !step.disabled { onSelect?(index) } }
                    .modifier(StepAccessibility(step: step, state: state, tappable: onSelect != nil && !step.disabled))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    let state = effectiveState(step, index)
                    HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                        VStack(spacing: 0) {
                            marker(step, index: index, state: state)
                            if index < steps.count - 1 {
                                Rectangle().fill(connectorColor(index)).frame(width: 2, height: 28)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            titleLabel(step, state: state)
                            if let description = step.description {
                                Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .opacity(step.disabled ? 0.4 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { if !step.disabled { onSelect?(index) } }
                    .modifier(StepAccessibility(step: step, state: state, tappable: onSelect != nil && !step.disabled))
                }
            }
        }
    }

    /// The step title plus its optional lighter `subTitle` (Ant `subTitle`).
    @ViewBuilder
    private func titleLabel(_ step: Step, state: StepState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            Text(step.title)
                .textStyle(small ? .labelSm600 : .labelBase600)
                .foregroundStyle(titleColor(state))
            if let subTitle = step.subTitle {
                Text(subTitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            }
        }
    }

    /// The controlled-`current` state for a step: explicit `.error` is preserved,
    /// otherwise position vs `current` gives done / active / todo. Without a
    /// `.current(_:)` override the step keeps its own declared `state`.
    private func effectiveState(_ step: Step, _ index: Int) -> StepState {
        guard let current = currentOverride else { return step.state }
        if step.state == .error { return .error }
        if index < current { return .done }
        if index == current { return .active }
        return .todo
    }

    @ViewBuilder
    private func marker(_ step: Step, index: Int, state: StepState) -> some View {
        ZStack {
            if let markerBuilder {
                // Custom marker replaces the stock circle/number (and the
                // progress-dot variant), centered in the same dotSize slot so
                // connectors and layout are unchanged. The Ant `percent` ring
                // is still drawn around it.
                markerBuilder(step, index)
                percentRing(step, state: state)
            } else if progressDot {
                Circle().fill(dotFill(state)).frame(width: 10, height: 10)
            } else {
                Circle().fill(fill(state)).frame(width: dotSize, height: dotSize)
                Circle().strokeBorder(stroke(state), lineWidth: 1.5).frame(width: dotSize, height: dotSize)
                glyph(step, number: index + 1, state: state)
                percentRing(step, state: state)
            }
        }
        .frame(width: dotSize, height: dotSize)
    }

    /// 0...1 ring around an active marker (Ant Steps `percent`) — shared by the
    /// stock and custom (`marker(_:)`) markers.
    @ViewBuilder
    private func percentRing(_ step: Step, state: StepState) -> some View {
        if let percent = step.percent, state == .active {
            Circle().trim(from: 0, to: CGFloat(min(max(percent, 0), 1)))
                .stroke(theme.background(.bgHero), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: dotSize + 7, height: dotSize + 7)
        }
    }

    private func dotFill(_ state: StepState) -> Color {
        switch state {
        case .done, .active: return theme.background(.bgHero)
        case .error: return theme.background(.systemcolorsBgError)
        case .todo: return theme.border(.borderPrimary)
        }
    }

    @ViewBuilder
    private func glyph(_ step: Step, number: Int, state: StepState) -> some View {
        let iconSize = small ? 10.0 : 12.0
        switch state {
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
        effectiveState(steps[index], index) == .done ? theme.background(.bgHero) : theme.border(.borderPrimary)
    }
}

/// One VoiceOver element per step — "title[, subtitle][, description]", value =
/// state, button trait when tappable, not-enabled when the step is disabled.
private struct StepAccessibility: ViewModifier {
    let step: Steps.Step
    /// The resolved (controlled-`current`-aware) state.
    let state: StepState
    let tappable: Bool

    private var stateText: String {
        switch state {
        case .done: return String(themeKit: "Completed")
        case .active: return String(themeKit: "Current")
        case .todo: return String(themeKit: "Not started")
        case .error: return String(themeKit: "Error")
        }
    }

    private var label: String {
        [step.title, step.subTitle, step.description].compactMap { $0 }.joined(separator: ", ")
    }

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(stateText)
            .accessibilityAddTraits(tappable ? .isButton : [])
            .accessibilityAddTraits(state == .active ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Steps {
    /// Layout orientation: horizontal / vertical.
    func axis(_ a: Axis) -> Self { copy { $0.axis = a } }

    /// Marker + label size: medium (default) / small — the kit's uniform
    /// size-enum axis.
    func size(_ s: StepsSize) -> Self { copy { $0.size = s } }

    /// Compact markers and labels — the boolean twin of `size(.small)`.
    @available(*, deprecated, message: "Use size(_:) with a StepsSize.")
    func small(_ on: Bool = true) -> Self { size(on ? .small : .medium) }

    /// Render minimal progress dots instead of numbered markers (Ant `progressDot`).
    func progressDot(_ on: Bool = true) -> Self { copy { $0.progressDot = on } }

    /// Drive the flow from a single controlled index (Ant `current`): steps
    /// before it read as done, the one at it as active, those after as todo —
    /// derived automatically, so steps can be declared without per-item state. A
    /// step explicitly built as `.error` keeps its error state. `nil` (default)
    /// honours each step's own `state`.
    func current(_ index: Int?) -> Self { copy { $0.currentOverride = index } }

    /// Replace the default circle/number marker with a custom view, built per
    /// step from the step and its zero-based index. The custom view is
    /// centered in the marker's slot (connectors and layout are unchanged),
    /// the Ant `percent` ring is still drawn around an active marker, and the
    /// per-step VoiceOver behavior (`StepAccessibility`) is untouched. Omit
    /// for the stock markers.
    func marker<V: View>(@ViewBuilder _ content: @escaping (Steps.Step, Int) -> V) -> Self {
        copy { $0.markerBuilder = { step, index in AnyView(content(step, index)) } }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension Steps.Step {
    /// A copy of this step with a different ``StepState`` — title, description,
    /// icon and percent are preserved. Lets flow scaffolds (e.g. an edition's
    /// `CheckInFlow`) derive header states from a selection index without
    /// re-declaring the steps.
    func with(state: StepState) -> Steps.Step {
        Steps.Step(title, subTitle: subTitle, description: description, systemImage: systemImage,
                   state: state, disabled: disabled, percent: percent)
    }
}

#Preview {
    PreviewMatrix("Steps") {
        PreviewCase("Done / error / todo") {
            Steps([.init("Cart", state: .done), .init("Address", description: "Shipping", state: .done), .init("Payment", state: .error), .init("Done", state: .todo)])
        }
        // C5 — the size-enum axis (compact markers + labels).
        PreviewCase("Small") {
            Steps([.init("Cart", state: .done), .init("Pay", state: .active), .init("Done", state: .todo)]).size(.small)
        }
        PreviewCase("Vertical") {
            Steps([.init("Account", description: "Your details", state: .done), .init("Profile", state: .active), .init("Confirm", state: .todo)]).axis(.vertical)
        }
        // Controlled `current` derives states; a disabled step can't be tapped.
        PreviewCase("current(1) + subTitle + disabled") {
            Steps([
                .init("Cart", subTitle: "2 items"),
                .init("Payment", subTitle: "Visa"),
                .init("Review", disabled: true),
                .init("Done"),
            ]) { _ in }
                .current(1)
                .axis(.vertical)
        }
        // Custom per-step markers; the percent ring still wraps the active step.
        PreviewCase("Custom markers + percent") {
            Steps([.init("Cart", state: .done), .init("Pay", state: .active, percent: 0.6), .init("Done", state: .todo)])
                .marker { step, index in
                    Image(systemName: step.state == .done ? "checkmark.seal.fill" : "\(index + 1).circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(step.state == .todo ? SemanticColor.neutral.solid : SemanticColor.primary.solid)
                }
        }
    }
}

#Preview("RTL — horizontal connector") {
    let steps: [Steps.Step] = [
        .init("Cart", state: .done), .init("Pay", state: .active), .init("Done", state: .todo),
    ]
    // Same data twice: the connector's half-marker nudge must point toward the
    // NEXT step in both directions (right in LTR, left in RTL).
    VStack(spacing: 40) {
        Steps(steps)
        Steps(steps)
            .environment(\.layoutDirection, .rightToLeft)
    }
    .padding()
}
