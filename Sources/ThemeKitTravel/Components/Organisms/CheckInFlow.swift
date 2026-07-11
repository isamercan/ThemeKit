//
//  CheckInFlow.swift
//  ThemeKitTravel
//
//  Edition organism (F3.4 · ADR §9.11). A stepper *scaffold* for the check-in
//  journey — a neutral `Steps` header, the current page, and a Back / Continue
//  dock (`buttonDock`). Deliberately thin: pages are the app's content (a
//  generic `Page` view built per index); the component owns progression chrome
//  only. Nothing is re-implemented here — the header is ThemeKit's `Steps`,
//  the dock is `buttonDock` + `ButtonGroup` + the stock button molecules.
//
//  State follows ADR-F4: controlled-first (`selection: Binding<Int>`) plus an
//  uncontrolled convenience (`initiallyAt:`), both funneled through
//  `ControllableState`. Header step states derive from the selection
//  (before = `.done`, current = `.active`, after = `.todo`) — callers pass
//  initial states only. Page transitions slide directionally on leading /
//  trailing edges (mirrored under RTL automatically), gated by `MicroMotion`.
//
//  ```swift
//  CheckInFlow(steps: [.init("Passengers", state: .active),
//                      .init("Seats", state: .todo),
//                      .init("Boarding pass", state: .todo)],
//              selection: $step) { index in
//      switch index {
//      case 0: PassengerReviewPage()
//      case 1: SeatMap(sections: cabin, selection: $seats)
//      default: BoardingPass(passenger: name, from: "IST", to: "LHR").qr(code)
//      }
//  }
//  .canAdvance { $0 == 1 ? !seats.isEmpty : true }
//  .onComplete { finishCheckIn() }
//  ```
//

import SwiftUI
import ThemeKit

/// A check-in journey scaffold — `Steps` header + the current page + a
/// Back / Continue dock. Pages are the app's content; the scaffold owns only
/// the progression chrome.
public struct CheckInFlow<Page: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [Steps.Step]
    private let page: (Int) -> Page
    /// Current step index — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: Int
    /// Direction of the last progression, for the page slide. Set by the dock
    /// handlers (same transaction as the index change); `onChange` keeps it
    /// roughly right for externally-driven controlled changes.
    @State private var movesForward = true

    // Config — mutated only through the modifiers below (R2).
    private var nextTitleValue = String(themeKitTravel: "Continue")
    private var backTitleValue = String(themeKitTravel: "Back")
    private var doneTitleValue = String(themeKitTravel: "Done")
    private var canAdvancePredicate: ((Int) -> Bool)?
    private var onCompleteAction: (() -> Void)?
    private var showsStepperValue = true
    private var accent: SemanticColor?

    /// R1 — the step definitions + controlled index + per-step page builder.
    /// The binding is the change channel; observe with `.onChange(of:)` at the
    /// call site.
    public init(steps: [Steps.Step], selection: Binding<Int>,
                @ViewBuilder page: @escaping (Int) -> Page) {
        self.steps = steps
        self.page = page
        self._selection = ControllableState(wrappedValue: 0, external: selection)
    }

    /// Uncontrolled — self-paced; the component owns the index
    /// (`ControllableState`).
    public init(steps: [Steps.Step], initiallyAt index: Int = 0,
                @ViewBuilder page: @escaping (Int) -> Page) {
        self.steps = steps
        self.page = page
        self._selection = ControllableState(wrappedValue: index)
    }

    // MARK: Derived state

    /// `selection` clamped into the valid step range, so an out-of-range
    /// controlled value can never crash the page builder.
    @MainActor
    private var currentIndex: Int {
        min(max(selection, 0), max(steps.count - 1, 0))
    }
    @MainActor
    private var isLastStep: Bool { currentIndex >= steps.count - 1 }
    @MainActor
    private var advanceAllowed: Bool { canAdvancePredicate?(currentIndex) ?? true }

    private var motion: Animation? {
        MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion)
    }

    /// Header steps re-stated from the selection: before = `.done`,
    /// current = `.active`, after = `.todo` (callers pass initial states only).
    @MainActor
    private var derivedSteps: [Steps.Step] {
        steps.enumerated().map { index, step in
            if index < currentIndex { return step.with(state: .done) }
            if index == currentIndex { return step.with(state: .active) }
            return step.with(state: .todo)
        }
    }

    // MARK: Body

    public var body: some View {
        if steps.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                if showsStepperValue {
                    header
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                }
                pageContainer
            }
            .buttonDock { dock }
            .accessibilityElement(children: .contain)
        }
    }

    @MainActor
    private var header: some View {
        let base = Steps(derivedSteps)
        return Group {
            if let accent {
                base.marker { _, index in accentMarker(index: index, color: accent) }
            } else {
                base
            }
        }
    }

    /// Accent-tinted marker (drawn only when `accent(_:)` is set): done /
    /// active fill with the semantic solid, todo stays neutral — glyphs mirror
    /// the stock `Steps` markers.
    @MainActor
    private func accentMarker(index: Int, color: SemanticColor) -> some View {
        let isDone = index < currentIndex
        let isCurrent = index == currentIndex
        return ZStack {
            Circle().fill(isDone || isCurrent ? color.solid : theme.background(.bgWhite))
            Circle().strokeBorder(
                isDone || isCurrent ? color.solid : theme.border(.borderPrimary),
                lineWidth: 1.5
            )
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color.onSolid)
            } else {
                Text("\(index + 1)")
                    .textStyle(.labelSm700)
                    .foregroundStyle(isCurrent ? color.onSolid : theme.text(.textTertiary))
            }
        }
    }

    @MainActor
    private var pageContainer: some View {
        ZStack {
            page(currentIndex)
                .id(currentIndex)   // page identity per step → insert/remove transition
                .transition(pageTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()   // slides stay inside the page area, not over header/dock
        .animation(motion, value: currentIndex)
        .onChange(of: selection) { old, new in
            movesForward = new >= old
        }
    }

    /// Directional slide on leading/trailing edges — mirrored under RTL
    /// automatically; `motion == nil` (MicroMotion off / Reduce Motion)
    /// applies the change instantly.
    private var pageTransition: AnyTransition {
        if movesForward {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    @MainActor
    private var dock: some View {
        ButtonGroup(.horizontal) {
            SecondaryButton(backTitleValue) { goBack() }
                .disabled(currentIndex == 0)
            PrimaryButton(isLastStep ? doneTitleValue : nextTitleValue) { advance() }
                .disabled(!advanceAllowed)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .allowsHitTesting(!isReadOnly)   // E1 — read-only blocks progression
    }

    // MARK: Progression

    @MainActor
    private func advance() {
        guard !isReadOnly, advanceAllowed else { return }
        if isLastStep {
            onCompleteAction?()
        } else {
            movesForward = true
            selection = currentIndex + 1
        }
    }

    @MainActor
    private func goBack() {
        guard !isReadOnly, currentIndex > 0 else { return }
        movesForward = false
        selection = currentIndex - 1
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CheckInFlow {
    /// Title of the advancing dock button (default "Continue"); on the last
    /// step the button shows ``doneTitle(_:)`` instead.
    func nextTitle(_ text: String) -> Self { copy { $0.nextTitleValue = text } }

    /// Title of the back dock button (default "Back"). Back is disabled on the
    /// first step.
    func backTitle(_ text: String) -> Self { copy { $0.backTitleValue = text } }

    /// Title of the advancing button on the last step (default "Done") — the
    /// tap calls ``onComplete(_:)`` instead of advancing.
    func doneTitle(_ text: String) -> Self { copy { $0.doneTitleValue = text } }

    /// Gate advancing (e.g. seat not yet chosen): called with the current step
    /// index; Continue / Done disables when it returns `false`.
    func canAdvance(_ predicate: @escaping (Int) -> Bool) -> Self {
        copy { $0.canAdvancePredicate = predicate }
    }

    /// Called when the advancing button is tapped on the last step.
    func onComplete(_ action: @escaping () -> Void) -> Self {
        copy { $0.onCompleteAction = action }
    }

    /// Show or hide the `Steps` header — hide for compact hosts that provide
    /// their own progress chrome.
    func showsStepper(_ on: Bool = true) -> Self { copy { $0.showsStepperValue = on } }

    /// Semantic tint for the done/active step markers; `nil` (default) keeps
    /// the stock theme-hero markers.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Controlled · gated seats · onComplete") {
    struct Demo: View {
        @State private var step = 0
        @State private var seats: Set<String> = []
        @State private var completed = false

        private func placeholder(_ title: String, detail: String) -> some View {
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title).textStyle(.headingSm)
                Text(detail).textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                if title == "Seats" {
                    Toggle("Seat 12A chosen", isOn: Binding(
                        get: { !seats.isEmpty },
                        set: { seats = $0 ? ["12A"] : [] }
                    ))
                }
            }
            .padding(Theme.SpacingKey.md.value)
        }

        var body: some View {
            VStack(spacing: Theme.SpacingKey.sm.value) {
                CheckInFlow(steps: [
                    .init("Passengers", state: .active),
                    .init("Seats", state: .todo),
                    .init("Boarding pass", state: .todo),
                ], selection: $step) { index in
                    switch index {
                    case 0: placeholder("Passengers", detail: "Review traveler details.")
                    case 1: placeholder("Seats", detail: "Pick a seat to continue.")
                    default: placeholder("Boarding pass", detail: "You are all set.")
                    }
                }
                .canAdvance { $0 == 1 ? !seats.isEmpty : true }
                .onComplete { completed = true }
                .frame(height: 380)

                if completed {
                    Text("Check-in complete").textStyle(.labelSm600)
                }
            }
        }
    }
    return Demo()
}

#Preview("Uncontrolled · accent · custom labels · no stepper · read-only · dark") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return VStack(spacing: Theme.SpacingKey.lg.value) {
        CheckInFlow(steps: [
            .init("Bags", state: .active),
            .init("Seats", state: .todo),
            .init("Confirm", state: .todo),
        ], initiallyAt: 1) { index in
            Text("Page \(index + 1)").textStyle(.bodyBase400).padding()
        }
        .accent(.success)
        .nextTitle("Next")
        .backTitle("Previous")
        .doneTitle("Finish check-in")
        .frame(height: 200)

        CheckInFlow(steps: [
            .init("Seats", state: .todo),
            .init("Confirm", state: .todo),
        ], initiallyAt: 1) { index in
            Text("Compact host page \(index + 1)").textStyle(.bodyBase400).padding()
        }
        .showsStepper(false)
        .readOnly()
        .frame(height: 140)
    }
    .padding()
    .background(dark.background(.bgBase))
    .theme(dark)
}
