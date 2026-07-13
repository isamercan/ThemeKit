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
//  Style (ADR-0004, Class B): the component owns every live unit (selection,
//  page identity/transition/motion, dock wiring) — arrangement is delegated
//  to the active ``CheckInFlowStyle`` (`CheckInFlowStyle.swift`) via
//  `.checkInFlowStyle(_:)`. `.steps`/`.bar` are the former
//  ``CheckInProgressStyle`` cases, deprecate-forwarded through
//  `.progressStyle(_:)`; `.paged` is new. Navigation (advance/back/jump) and
//  the `canAdvance`/`onComplete` gates stay in the component — styles only
//  arrange the pre-wired `Steps` header, page and dock units.
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

/// Alignment of the built-in Back / Continue dock: trailing-packed (default)
/// or stretched full-width buttons.
public enum DockLayout: Sendable { case trailing, stretch }

/// How pages change: a directional slide (default, RTL-mirrored), a
/// cross-fade, or an instant swap. All of them respect `MicroMotion` /
/// Reduce Motion — when motion is off every transition applies instantly.
public enum PageTransition: Sendable { case slide, fade, none }

/// Where the progress chrome sits: above the page (default) or as a vertical
/// rail on the leading edge (wide/iPad hosts).
public enum StepperPlacement: Sendable { case top, leading }

/// The progress chrome itself: the `Steps` markers (default) or a thin
/// determinate `ProgressBar`. Superseded by ``CheckInFlowStyle`` (ADR-0004) —
/// `.steps` and `.bar` map 1:1 onto ``CheckInFlowStyle/steps`` and
/// ``CheckInFlowStyle/bar`` (plus the new ``CheckInFlowStyle/paged``); the
/// enum remains for source compatibility via the deprecated
/// ``CheckInFlow/progressStyle(_:)`` and is removed at the next major.
public enum CheckInProgressStyle: Sendable { case steps, bar }

/// A check-in journey scaffold — `Steps` header + the current page + a
/// Back / Continue dock. Pages are the app's content; the scaffold owns only
/// the progression chrome.
public struct CheckInFlow<Page: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.componentDensity) private var envDensity
    @Environment(\.locale) private var locale
    @Environment(\.checkInFlowStyle) private var envStyle

    private let steps: [Steps.Step]
    private let page: (Int) -> Page
    /// Current step index — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: Int
    /// Direction of the last progression, for the page slide. Set by the dock
    /// handlers (same transaction as the index change); `onChange` keeps it
    /// roughly right for externally-driven controlled changes.
    @State private var movesForward = true

    // Config — mutated only through the modifiers below (R2).
    private var nextTitleValueOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var nextTitleValue: String { nextTitleValueOverride ?? String(themeKitTravel: "Continue") }
    private var backTitleValueOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var backTitleValue: String { backTitleValueOverride ?? String(themeKitTravel: "Back") }
    private var doneTitleValueOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var doneTitleValue: String { doneTitleValueOverride ?? String(themeKitTravel: "Done") }
    private var canAdvancePredicate: ((Int) -> Bool)?
    private var onCompleteAction: (() -> Void)?
    private var showsStepperValue = true
    private var accent: SemanticColor?
    /// Replaces the built-in Back / Continue dock.
    private var dockSlot: AnyView?
    private var dockLayoutValue: DockLayout = .trailing
    private var buttonSizeValue: ButtonSize = .medium
    private var stepsTappableValue = false
    private var pageTransitionValue: PageTransition = .slide
    private var stepperSizeValue: StepsSize = .medium
    private var stepperPlacementValue: StepperPlacement = .top
    /// Style set by the deprecated ``progressStyle(_:)`` modifier — wins over
    /// the environment style (ADR-0004 §5 — source-behavior stability during
    /// the enum's deprecation window).
    private var explicitStyle: AnyCheckInFlowStyle?

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
            // ADR-0004 §5 — an explicit (deprecated `.progressStyle(_:)`) style
            // wins over the ancestor `.checkInFlowStyle(_:)` environment style.
            (explicitStyle ?? envStyle).makeBody(configuration: configuration)
        }
    }

    /// The pre-wired units + typed signals handed to the active
    /// ``CheckInFlowStyle``. Built unconditionally every render — styles
    /// arrange, they never re-wire (ADR-0004 §2.2).
    @MainActor
    private var configuration: CheckInFlowConfiguration {
        CheckInFlowConfiguration(
            stepsHeader: AnyView(header(axis: stepperPlacementValue == .leading ? .vertical : .horizontal)),
            page: AnyView(pageContainer),
            dock: dockUnit,
            currentIndex: currentIndex,
            stepCount: steps.count,
            canAdvance: advanceAllowed,
            showsStepper: showsStepperValue,
            placement: stepperPlacementValue,
            accent: accent,
            density: envDensity,
            locale: locale)
    }

    /// The wired dock unit: the caller's `.dock { }` replacement (read-only
    /// gated) or the built-in Back/Continue `ButtonGroup`.
    @MainActor
    private var dockUnit: AnyView {
        if let dockSlot {
            // Custom dock: the caller owns Back/Continue semantics —
            // canAdvance gating and onComplete become its job.
            return AnyView(dockSlot.allowsHitTesting(!isReadOnly))
        }
        return AnyView(dock)
    }

    @MainActor
    private func header(axis: Axis) -> some View {
        let base = Steps(derivedSteps, onSelect: stepsTappableValue ? { jump(to: $0) } : nil)
            .axis(axis)
            .size(stepperSizeValue)
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
        let resolved = theme.resolve(color)
        return ZStack {
            Circle().fill(isDone || isCurrent ? resolved.solid : theme.background(.bgWhite))
            Circle().strokeBorder(
                isDone || isCurrent ? resolved.solid : theme.border(.borderPrimary),
                lineWidth: 1.5
            )
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(resolved.onSolid)
            } else {
                Text("\(index + 1)")
                    .textStyle(.labelSm700)
                    .foregroundStyle(isCurrent ? resolved.onSolid : theme.text(.textTertiary))
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

    /// The `.pageTransition(_:)` switch. `.slide` (default) moves on
    /// leading/trailing edges — mirrored under RTL automatically; `.fade`
    /// cross-fades; `.none` swaps identity without motion. All are gated the
    /// same way: `motion == nil` (MicroMotion off / Reduce Motion) applies
    /// the change instantly.
    private var pageTransition: AnyTransition {
        switch pageTransitionValue {
        case .fade:
            return .opacity
        case .none:
            return .identity
        case .slide:
            return movesForward
                ? .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
                : .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                )
        }
    }

    @MainActor
    private var dock: some View {
        ButtonGroup(.horizontal) {
            SecondaryButton(backTitleValue) { goBack() }
                .size(buttonSizeValue)
                .fullWidth(dockLayoutValue == .stretch)
                .disabled(currentIndex == 0)
            PrimaryButton(isLastStep ? doneTitleValue : nextTitleValue) { advance() }
                .size(buttonSizeValue)
                .fullWidth(dockLayoutValue == .stretch)
                .disabled(!advanceAllowed)
        }
        .frame(maxWidth: .infinity, alignment: dockLayoutValue == .stretch ? .center : .trailing)
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

    /// `.stepsTappable` jump: only *backward*, to an already-done marker — a
    /// tap can never advance past the `canAdvance` gate because it can never
    /// advance at all.
    @MainActor
    private func jump(to index: Int) {
        guard !isReadOnly, index < currentIndex, steps.indices.contains(index) else { return }
        movesForward = false
        selection = index
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CheckInFlow {
    /// Title of the advancing dock button (default "Continue"); on the last
    /// step the button shows ``doneTitle(_:)`` instead.
    func nextTitle(_ text: String) -> Self { copy { $0.nextTitleValueOverride = text } }

    /// Title of the back dock button (default "Back"). Back is disabled on the
    /// first step.
    func backTitle(_ text: String) -> Self { copy { $0.backTitleValueOverride = text } }

    /// Title of the advancing button on the last step (default "Done") — the
    /// tap calls ``onComplete(_:)`` instead of advancing.
    func doneTitle(_ text: String) -> Self { copy { $0.doneTitleValueOverride = text } }

    /// Gate advancing (e.g. seat not yet chosen): called with the current step
    /// index; Continue / Done disables when it returns `false`.
    func canAdvance(_ predicate: @escaping (Int) -> Bool) -> Self {
        copy { $0.canAdvancePredicate = predicate }
    }

    /// Called when the advancing button is tapped on the last step.
    func onComplete(_ action: @escaping () -> Void) -> Self {
        copy { $0.onCompleteAction = action }
    }

    /// Show or hide the progress chrome — whichever ``CheckInFlowStyle`` is
    /// active (`Steps` header, bar or dot pager) — for compact hosts that
    /// provide their own.
    func showsStepper(_ on: Bool = true) -> Self { copy { $0.showsStepperValue = on } }

    /// Semantic tint for the done/active step markers; `nil` (default) keeps
    /// the stock theme-hero markers.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Replaces the built-in Back / Continue `ButtonGroup` with caller
    /// content (canonical `.dock { }` slot). With a custom dock the scaffold
    /// no longer drives progression: `canAdvance` gating, `onComplete` and
    /// the index changes become the caller's job (mutate the bound
    /// `selection`). Hit-testing still respects `.readOnly()`.
    func dock<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.dockSlot = AnyView(content()) }
    }

    /// Built-in dock alignment: `.trailing` (default, packed buttons) or
    /// `.stretch` (full-width buttons).
    func dockLayout(_ l: DockLayout) -> Self { copy { $0.dockLayoutValue = l } }

    /// Control size of the built-in dock buttons (default `.medium`).
    func buttonSize(_ s: ButtonSize) -> Self { copy { $0.buttonSizeValue = s } }

    /// Lets a tap on a *done* marker jump back to that step (markers gain the
    /// button trait). Forward taps are ignored, so a jump can never bypass
    /// the `canAdvance` gate. Default off.
    func stepsTappable(_ on: Bool = true) -> Self { copy { $0.stepsTappableValue = on } }

    /// Page-change motion: `.slide` (default, RTL-mirrored), `.fade`, or
    /// `.none` — all applied through the `MicroMotion` / Reduce-Motion gate.
    func pageTransition(_ t: PageTransition) -> Self { copy { $0.pageTransitionValue = t } }

    /// Marker/label size of the `Steps` header (default `.medium`).
    func stepperSize(_ s: StepsSize) -> Self { copy { $0.stepperSizeValue = s } }

    /// Progress-chrome placement: `.top` (default) or `.leading` — a vertical
    /// `Steps` rail beside the page. Only ``CheckInFlowStyle/steps`` honors a
    /// `.leading` rail; `.bar` and `.paged` always render their own chrome
    /// on top.
    func stepperPlacement(_ p: StepperPlacement) -> Self { copy { $0.stepperPlacementValue = p } }

    /// Progress chrome: `.steps` markers or `.bar` — superseded by the style
    /// axis: prefer `.checkInFlowStyle(.steps/.bar/.paged)`, settable once per
    /// screen via the environment. This modifier keeps working and, when
    /// called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .checkInFlowStyle(.steps/.bar/.paged) instead")
    func progressStyle(_ s: CheckInProgressStyle) -> Self {
        copy {
            switch s {
            case .steps: $0.explicitStyle = AnyCheckInFlowStyle(StepsCheckInFlowStyle())
            case .bar: $0.explicitStyle = AnyCheckInFlowStyle(BarCheckInFlowStyle())
            }
        }
    }

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

#Preview("Flexibility — dock · bar · leading rail · tappable steps") {
    struct Demo: View {
        @State private var custom = 1
        @State private var barStep = 1
        @State private var railStep = 1
        @State private var tappable = 2

        var body: some View {
            ScrollView {
                VStack(spacing: Theme.SpacingKey.lg.value) {
                    // Custom dock slot — caller drives progression.
                    CheckInFlow(steps: [
                        .init("Bags", state: .active), .init("Seats", state: .todo),
                    ], selection: $custom) { index in
                        Text("Page \(index + 1)").textStyle(.bodyBase400).padding()
                    }
                    .dock {
                        PrimaryButton("Skip to seats") { custom = 1 }.fullWidth()
                    }
                    .frame(height: 180)

                    // Progress bar chrome + stretched dock + fade transition.
                    CheckInFlow(steps: [
                        .init("Passengers", state: .todo), .init("Seats", state: .todo),
                        .init("Pass", state: .todo),
                    ], selection: $barStep) { index in
                        Text("Step \(index + 1)").textStyle(.bodyBase400).padding()
                    }
                    .pageTransition(.fade)
                    .dockLayout(.stretch)
                    .buttonSize(.large)
                    .frame(height: 200)
                    .checkInFlowStyle(.bar)

                    // Leading vertical rail + small tappable markers.
                    CheckInFlow(steps: [
                        .init("Bags", state: .todo), .init("Seats", state: .todo),
                        .init("Confirm", state: .todo),
                    ], selection: $railStep) { index in
                        Text("Rail page \(index + 1)").textStyle(.bodyBase400).padding()
                    }
                    .stepperPlacement(.leading)
                    .stepperSize(.small)
                    .stepsTappable()
                    .frame(height: 220)

                    // Tappable done markers jump back; forward taps are ignored.
                    CheckInFlow(steps: [
                        .init("A", state: .todo), .init("B", state: .todo), .init("C", state: .todo),
                    ], selection: $tappable) { index in
                        Text("Page \(index + 1)").textStyle(.bodyBase400).padding()
                    }
                    .stepsTappable()
                    .pageTransition(.none)
                    .frame(height: 160)
                }
                .padding()
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
