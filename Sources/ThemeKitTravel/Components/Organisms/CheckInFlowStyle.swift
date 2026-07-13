//
//  CheckInFlowStyle.swift
//  ThemeKit
//
//  The styling hook for ``CheckInFlow`` — a Class B protocol of ADR-0004
//  (per-component style protocols). The component owns the live progression
//  state (`ControllableState` selection, page identity, motion, dock wiring)
//  — the configuration hands styles **pre-wired, type-erased units** (the
//  `Steps` header, the current page, the wired Back/Continue dock) plus typed
//  signals (current index, step count, the advance gate, accent, density,
//  locale). Styles ARRANGE the units; they never rebuild the `Steps` markers,
//  the page transition or the dock buttons. Three built-ins:
//
//    .steps   `Steps` header (top, or a leading rail via `.stepperPlacement(.leading)`)
//             + the page + the docked Back/Continue run — today's flow. Default.
//    .bar     promotes ``CheckInProgressStyle/bar``: a thin determinate
//             `ProgressBar` announcing "Step N of M" instead of the `Steps` markers.
//    .paged   a minimal page-dot pager (the stock `StepIndicator` atom) above
//             the page — the lightest-weight progress chrome.
//
//      CheckInFlow(steps: steps, selection: $step) { index in page(index) }
//          .canAdvance { $0 == 1 ? !seats.isEmpty : true }
//          .onComplete { finishCheckIn() }
//          .checkInFlowStyle(.paged)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything (there is no shell chrome to delegate — the
//  scaffold has no surface/card of its own). Motion is resolved in the
//  component (`MicroMotion` ∧ ¬Reduce Motion): the page unit already carries
//  its transition + animation, and the dock unit already carries its
//  enablement/titles — styles never read the motion environment or rebuild
//  either.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The pre-wired inputs a ``CheckInFlowStyle`` arranges. The `AnyView` unit
/// fields are fully interactive/wired by the component — place them, never
/// rebuild them. The typed fields are read-only signals for arrangement
/// decisions; a preset that doesn't need one simply ignores it (e.g. `.bar`
/// and `.paged` build their own progress chrome from ``currentIndex``/
/// ``stepCount`` and never touch ``stepsHeader``).
public struct CheckInFlowConfiguration {
    // MARK: Pre-wired units — fully interactive; styles arrange, never re-wire.

    /// The wired `Steps` header: axis (`.top` → horizontal, `.leading` → a
    /// vertical rail — see ``placement``), the tappable-jump callback
    /// (`.stepsTappable(_:)`), marker size (`.stepperSize(_:)`) and the
    /// accent-tinted marker (`.accent(_:)`) are already applied. `.steps`-
    /// shaped presets place it; other presets build their own chrome instead.
    public let stepsHeader: AnyView
    /// The current step's page content: identity (`.id(_:)`), the directional
    /// slide/fade/none transition (`.pageTransition(_:)`) and the
    /// `MicroMotion`-gated animation are already wired. Every preset places
    /// it as-is.
    public let page: AnyView
    /// The wired Back / Continue dock: either the built-in `ButtonGroup`
    /// (titles, the last-step "Done" swap, the `canAdvance` gate, size and
    /// layout are already resolved) or the caller's `.dock { }` replacement.
    /// Read-only hit-testing is already applied.
    public let dock: AnyView

    // MARK: Typed signals for arrangement decisions.

    /// Zero-based index of the step currently on screen.
    public let currentIndex: Int
    /// Total step count.
    public let stepCount: Int
    /// `true` when the dock's advancing button is enabled (the
    /// ``CheckInFlow/canAdvance(_:)`` gate) — exposed for a custom style that
    /// wants to reflect the gate outside the dock itself; the built-ins don't
    /// need it since ``dock`` already disables its own button.
    public let canAdvance: Bool
    /// `false` hides the progress chrome entirely, whichever preset is active
    /// (`Steps` header, bar or dot pager) — for compact hosts that supply
    /// their own (``CheckInFlow/showsStepper(_:)``). The page and dock still
    /// render.
    public let showsStepper: Bool
    /// Where ``stepsHeader`` sits relative to the page:
    /// (``CheckInFlow/stepperPlacement(_:)``). Only `.steps`-shaped presets
    /// honor a `.leading` rail; `.bar` and `.paged` always render their own
    /// chrome above the page, matching their pre-style behavior.
    public let placement: StepperPlacement
    /// Semantic tint for the active/done markers (``CheckInFlow/accent(_:)``);
    /// `nil` keeps the theme's hero tokens. Already baked into ``stepsHeader``;
    /// exposed here for a custom bar/pager-shaped style that wants to tint its
    /// own chrome the same way.
    public let accent: SemanticColor?
    /// The environment's component density, captured by the component — scale
    /// a preset's own chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale

    /// Density-scaled spacing — use for a preset's own chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the flow (the pre-wired units
    /// already scale their own internals).
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `CheckInFlow`'s entire presentation. Implement `makeBody` to
/// arrange the configuration's pre-wired units. Set one with
/// `.checkInFlowStyle(_:)`; the default is ``StepsCheckInFlowStyle``.
public protocol CheckInFlowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CheckInFlowConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

private extension View {
    /// The dock-pinned, accessibility-contained shell every built-in preset
    /// wraps its arrangement in — the scaffold has no surface of its own, so
    /// this is the entire "chrome" a preset needs beyond its own layout.
    func checkInFlowShell(dock: AnyView) -> some View {
        buttonDock { dock }
            .accessibilityElement(children: .contain)
    }
}

// MARK: - .steps (default)

/// Today's `CheckInFlow` look, extracted verbatim: the `Steps` header — on
/// top, or as a leading vertical rail beside the page when
/// `.stepperPlacement(.leading)` is set — the current page, and the docked
/// Back/Continue run.
public struct StepsCheckInFlowStyle: CheckInFlowStyle {
    public init() {}
    public func makeBody(configuration: CheckInFlowConfiguration) -> some View {
        StepsCheckInFlowChrome(configuration: configuration)
    }
}

private struct StepsCheckInFlowChrome: View {
    let configuration: CheckInFlowConfiguration

    var body: some View {
        Group {
            if configuration.showsStepper, configuration.placement == .leading {
                HStack(alignment: .top, spacing: 0) {
                    configuration.stepsHeader
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                    configuration.page
                }
            } else {
                VStack(spacing: 0) {
                    if configuration.showsStepper {
                        configuration.stepsHeader
                            .padding(.horizontal, Theme.SpacingKey.md.value)
                            .padding(.vertical, Theme.SpacingKey.sm.value)
                    }
                    configuration.page
                }
            }
        }
        .checkInFlowShell(dock: configuration.dock)
    }
}

// MARK: - .bar

/// A thin determinate `ProgressBar` ("Step N of M") instead of the `Steps`
/// markers — promotes the former ``CheckInProgressStyle/bar`` knob. Always
/// renders on top; it never honors ``CheckInFlowConfiguration/placement``.
public struct BarCheckInFlowStyle: CheckInFlowStyle {
    public init() {}
    public func makeBody(configuration: CheckInFlowConfiguration) -> some View {
        BarCheckInFlowChrome(configuration: configuration)
    }
}

private struct BarCheckInFlowChrome: View {
    let configuration: CheckInFlowConfiguration

    /// Step titles are internal to the neutral `Steps.Step`, so the
    /// announcement is positional ("Step 2 of 3").
    private var fraction: Double {
        Double(configuration.currentIndex + 1) / Double(max(configuration.stepCount, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            if configuration.showsStepper {
                ProgressBar(value: fraction)
                    .progressLabel(String(
                        themeKitTravel: "Step \(configuration.currentIndex + 1) of \(configuration.stepCount)"))
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
            }
            configuration.page
        }
        .checkInFlowShell(dock: configuration.dock)
    }
}

// MARK: - .paged

/// A minimal page-dot pager above the page — the lightest-weight progress
/// chrome, composed from the stock ``StepIndicator`` atom (never
/// re-implemented). No titles, no leading-rail variant.
public struct PagedCheckInFlowStyle: CheckInFlowStyle {
    public init() {}
    public func makeBody(configuration: CheckInFlowConfiguration) -> some View {
        PagedCheckInFlowChrome(configuration: configuration)
    }
}

private struct PagedCheckInFlowChrome: View {
    let configuration: CheckInFlowConfiguration

    var body: some View {
        VStack(spacing: 0) {
            if configuration.showsStepper {
                StepIndicator(current: configuration.currentIndex, total: configuration.stepCount)
                    .padding(.vertical, configuration.spacing(.sm))
            }
            configuration.page
        }
        .checkInFlowShell(dock: configuration.dock)
    }
}

// MARK: - Static accessors

public extension CheckInFlowStyle where Self == StepsCheckInFlowStyle {
    /// `Steps` header (top, or a leading rail) + page + docked Back/Continue
    /// — today's flow. The default.
    static var steps: StepsCheckInFlowStyle { StepsCheckInFlowStyle() }
}
public extension CheckInFlowStyle where Self == BarCheckInFlowStyle {
    /// A thin determinate `ProgressBar` ("Step N of M") instead of `Steps` markers.
    static var bar: BarCheckInFlowStyle { BarCheckInFlowStyle() }
}
public extension CheckInFlowStyle where Self == PagedCheckInFlowStyle {
    /// A minimal page-dot pager (`StepIndicator`) above the page.
    static var paged: PagedCheckInFlowStyle { PagedCheckInFlowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCheckInFlowStyle: CheckInFlowStyle {
    private let _makeBody: @MainActor (CheckInFlowConfiguration) -> AnyView
    init<S: CheckInFlowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CheckInFlowConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CheckInFlowStyleKey: EnvironmentKey {
    static let defaultValue = AnyCheckInFlowStyle(StepsCheckInFlowStyle())
}

extension EnvironmentValues {
    var checkInFlowStyle: AnyCheckInFlowStyle {
        get { self[CheckInFlowStyleKey.self] }
        set { self[CheckInFlowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CheckInFlowStyle`` for `CheckInFlow`s in this view and its
    /// descendants — a compact host can run `.paged` while a full-screen
    /// check-in keeps `.steps`.
    func checkInFlowStyle<S: CheckInFlowStyle>(_ style: sending S) -> some View {
        environment(\.checkInFlowStyle, AnyCheckInFlowStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — a plain "Step N of M"
/// label instead of `Steps`, a bar or a pager. Proves external
/// implementability: it only reads typed signals and places the pre-wired
/// units, never rebuilds them.
private struct LabelCheckInFlowStyle: CheckInFlowStyle {
    func makeBody(configuration: CheckInFlowConfiguration) -> some View {
        LabelCheckInFlowChrome(configuration: configuration)
    }

    private struct LabelCheckInFlowChrome: View {
        @Environment(\.theme) private var theme
        let configuration: CheckInFlowConfiguration

        var body: some View {
            VStack(spacing: 0) {
                if configuration.showsStepper {
                    Text("Step \(configuration.currentIndex + 1) of \(configuration.stepCount)")
                        .textStyle(.overline500)
                        .foregroundStyle(configuration.accent.map { theme.resolve($0).base } ?? theme.text(.textSecondary))
                        .padding(.vertical, configuration.spacing(.sm))
                }
                configuration.page
            }
            .checkInFlowShell(dock: configuration.dock)
        }
    }
}

private let previewStepTitles = ["Passengers", "Seats", "Boarding pass"]

private func previewSteps() -> [Steps.Step] {
    previewStepTitles.map { Steps.Step($0, state: .todo) }
}

@MainActor private func previewPage(_ index: Int) -> some View {
    VStack(spacing: Theme.SpacingKey.sm.value) {
        Text(previewStepTitles[index]).textStyle(.headingSm)
        Text("Review the details, then continue.").textStyle(.bodyBase400)
    }
    .padding(Theme.SpacingKey.md.value)
}

#Preview("CheckInFlowStyle — presets × light/dark") {
    PreviewMatrix("CheckInFlowStyle") {
        PreviewCase(".steps (default)") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .frame(height: 260)
                .checkInFlowStyle(.steps)
        }
        PreviewCase(".bar") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .frame(height: 220)
                .checkInFlowStyle(.bar)
        }
        PreviewCase(".paged") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .frame(height: 220)
                .checkInFlowStyle(.paged)
        }
        PreviewCase("Custom (in-preview) — label chrome") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .accent(.success)
                .frame(height: 220)
                .checkInFlowStyle(LabelCheckInFlowStyle())
        }
    }
}

#Preview("Leading rail (.steps) & .paged — XL type / RTL") {
    PreviewMatrix("CheckInFlow — leading rail & paged", schemes: [.light], dynamicType: true, rtl: true) {
        PreviewCase(".steps — leading rail") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .stepperPlacement(.leading)
                .frame(height: 260)
                .checkInFlowStyle(.steps)
        }
        PreviewCase(".paged") {
            CheckInFlow(steps: previewSteps(), initiallyAt: 1) { previewPage($0) }
                .frame(height: 220)
                .checkInFlowStyle(.paged)
        }
    }
}
