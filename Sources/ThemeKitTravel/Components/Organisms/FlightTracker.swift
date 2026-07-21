//
//  FlightTracker.swift
//  ThemeKitTravel
//
//  Edition organism (F3.3 · ADR §9.9). The live status/gate screen — status
//  badge, route with an en-route progress treatment, schedule vs estimate,
//  gate/terminal/belt facts and a phase timeline. The arrangement is owned by
//  the active ``FlightTrackerStyle`` from the environment (ADR-0004): the
//  component gathers its typed live-status data into a
//  ``FlightTrackerConfiguration`` and hands it to the style — `.board`
//  (default) is today's tracker verbatim, `.compact`/`.timeline`/`.banner`
//  swap the whole layout, and apps can implement their own. Card-shaped
//  presets keep composing the neutral `Card`, so `.cardStyle(_:)` still swaps
//  the chrome independently.
//
//  Stateless by construction (house rule 1): the app polls or streams and
//  re-renders with a fresh `FlightStatusInfo` — no `Task`, no timers. Delay
//  rendering: when an estimate differs from the scheduled time, the scheduled
//  time strikes through in `textTertiary` and the estimate renders in the
//  status tone (`FlightStatus.semantic`) — see `FlightTrackerConfiguration`.
//
//  ## Status-change announcement pattern (a11y live region)
//  The header is one combined VoiceOver element ("Skyline Air, IST to LHR,
//  Delayed, estimated departure 2:20 PM"). Because the tracker is stateless,
//  a *change* of status is just a re-render with a new `info` — the component
//  watches that transition with `.onChange(of: info.status)` and posts an
//  `AccessibilityNotification.Announcement`, gated to an actual value change,
//  so VoiceOver interrupts with "Delayed, estimated departure 2:20 PM" the
//  moment the poll flips the status. This lives on the component's card
//  shell — not in any style — so it keeps firing under every preset. This
//  only fires while the same `FlightTracker` stays in the hierarchy
//  (identity-preserving re-render); if a host rebuilds the screen from
//  scratch it should post its own announcement.
//
//  ```swift
//  FlightTracker(info)
//      .progress(0.62)
//      .updated(lastPoll)
//      .details([("Aircraft", "A321neo")])
//      .flightTrackerStyle(.timeline)
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``FlightTracker``. Superseded by ``FlightTrackerStyle``
/// (ADR-0004) — every case maps 1:1 to a preset (`.board` →
/// `.flightTrackerStyle(.board)`, `.compact` → `.flightTrackerStyle(.compact)`,
/// plus the new `.timeline`/`.banner`); the enum remains for source
/// compatibility and is removed at the next major.
public enum FlightTrackerVariant: Sendable { case board, compact }

/// The live flight status board — badge, route + progress, schedule vs
/// estimate, gate/terminal/belt facts and a phase timeline, on a `Card` shell.
public struct FlightTracker: View {
    @Environment(\.locale) private var locale
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.componentDensity) private var density
    @Environment(\.flightTrackerStyle) private var envStyle

    private let info: FlightStatusInfo

    // Appearance/config — mutated only through the modifiers below (R2).
    private var progressValue: Double?
    private var updatedDate: Date?
    private var extraDetails: [(String, String)] = []
    private var timelineVisible = true
    private var accentOverride: SemanticColor?
    /// `nil` → the style's own default surface (the built-ins use `.bgWhite`).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var elevationValue: CardElevation = .soft
    private var footerSlot: AnyView?
    /// Style set by the deprecated `.variant(_:)`; wins over the environment
    /// style (ADR-0004 §5 — source-behavior stability during migration).
    private var explicitStyle: AnyFlightTrackerStyle?
    private var showsFactsValue = true
    private var showsEstimatesValue = true
    /// Replaces the built-in airline/route/badge header (`.board`/`.timeline`).
    private var headerSlot: AnyView?
    private var checkInTitleOverride: String?
    private var boardingTitleOverride: String?
    private var departedTitleOverride: String?
    private var arrivedTitleOverride: String?
    private var contentPaddingKey: Theme.SpacingKey = .md
    /// Replaces the built-in route progress track, built per clamped fraction.
    private var progressSlot: ((Double) -> AnyView)?
    private var timelineSizeValue: StepsSize = .small

    /// R1 — the canonical live-status model (ADR-F3). Everything else is a modifier.
    public init(_ info: FlightStatusInfo) {
        self.info = info
    }

    // MARK: Derived

    /// The active style: the deprecated `.variant(_:)`'s explicit choice wins
    /// over the ancestor `.flightTrackerStyle(_:)` (ADR-0004 §5).
    private var resolvedStyle: AnyFlightTrackerStyle { explicitStyle ?? envStyle }

    private var motion: Animation? {
        MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion)
    }

    private var clampedProgress: Double? {
        progressValue.map { min(max($0, 0), 1) }
    }

    /// "Updated 2 minutes ago" — formatted with the environment locale.
    private var updatedText: String? {
        updatedDate.map {
            String(themeKitTravel: "Updated \($0.formatted(.relative(presentation: .named).locale(locale)))")
        }
    }

    // MARK: Body

    public var body: some View {
        // The arrangement is owned by the active `FlightTrackerStyle`; the
        // status-change announcement and the progress-motion animation stay
        // *here*, wrapping the style's output, so both keep firing under
        // every preset (see the header doc's a11y note).
        let configuration = FlightTrackerConfiguration(
            statusInfo: info,
            progress: clampedProgress,
            updatedText: updatedText,
            details: extraDetails,
            showsTimeline: timelineVisible,
            showsFacts: showsFactsValue,
            showsEstimates: showsEstimatesValue,
            checkInTitle: checkInTitleOverride ?? String(themeKitTravel: "Check-in"),
            boardingTitle: boardingTitleOverride ?? String(themeKitTravel: "Boarding"),
            departedTitle: departedTitleOverride ?? String(themeKitTravel: "Departed"),
            arrivedTitle: arrivedTitleOverride ?? String(themeKitTravel: "Arrived"),
            contentPadding: contentPaddingKey,
            progressContent: progressSlot,
            header: headerSlot,
            footer: footerSlot,
            timelineSize: timelineSizeValue,
            accent: accentOverride,
            surfaceKey: surfaceKey,
            elevation: elevationValue,
            isReadOnly: isReadOnly,
            density: density,
            locale: locale)
        resolvedStyle.makeBody(configuration: configuration)
            .animation(motion, value: clampedProgress)
            // Live-region pattern: announce the transition, gated to a real change.
            .onChangeCompat(of: info.status) { oldValue, newValue in
                guard oldValue != newValue else { return }
                AccessibilityAnnouncement.post(
                    [newValue.label, configuration.estimateSummary()].compactMap { $0 }.joined(separator: ", ")
                )
            }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightTracker {
    /// En-route progress 0…1 drawn along the route path (clamped; `nil` hides
    /// it). Movement animates through the `MicroMotion` gate.
    func progress(_ fraction: Double?) -> Self { copy { $0.progressValue = fraction } }

    /// "Updated 2 minutes ago" caption — formatted with the environment locale.
    func updated(_ date: Date?) -> Self { copy { $0.updatedDate = date } }

    /// Extra fact rows appended to the facts grid, e.g. `[("Meal", "Included")]`.
    func details(_ pairs: [(String, String)]) -> Self { copy { $0.extraDetails = pairs } }

    /// Show the Check-in → Boarding → Departed → Arrived phase timeline (default on).
    func showsTimeline(_ on: Bool = true) -> Self { copy { $0.timelineVisible = on } }

    /// Semantic tint for the progress treatment and estimate emphasis;
    /// `nil` (default) derives from the status (`FlightStatus.semantic`).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentOverride = color } }

    /// Surface fill for the card shell (background token key). When unset,
    /// the active ``FlightTrackerStyle`` picks its own default (`.board`/
    /// `.compact`/`.timeline` use `.bgWhite`) — threaded into the active
    /// `CardStyle` via the composed `Card`.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Card shell elevation: none / soft (default) / elevated.
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevationValue = e } }

    /// Bottom-aligned accessory area (canonical `.footer { }` slot, forwarded
    /// to the composed `Card`) — e.g. a "Share status" action or a disruption
    /// note. Hit-testing is disabled while the surface is `.readOnly()`.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.footerSlot = AnyView(content()) }
    }

    /// Layout archetype. Maps 1:1 onto the ``FlightTrackerStyle`` presets and,
    /// when called, wins over the environment style (source-behavior
    /// stability during migration — ADR-0004 §5).
    @available(*, deprecated,
               message: "Use .flightTrackerStyle(_:) — e.g. .variant(.compact) becomes .flightTrackerStyle(.compact)")
    func variant(_ v: FlightTrackerVariant) -> Self {
        copy {
            switch v {
            case .board: $0.explicitStyle = AnyFlightTrackerStyle(BoardFlightTrackerStyle())
            case .compact: $0.explicitStyle = AnyFlightTrackerStyle(CompactFlightTrackerStyle())
            }
        }
    }

    /// Show the gate/terminal/desk/belt facts grid (default on; `.board`/`.timeline`).
    func showsFacts(_ on: Bool = true) -> Self { copy { $0.showsFactsValue = on } }

    /// Show the schedule-vs-estimate rows (and the `.compact`/`.banner`
    /// estimate time) when estimates differ meaningfully from the schedule (default on).
    func showsEstimates(_ on: Bool = true) -> Self { copy { $0.showsEstimatesValue = on } }

    /// Replaces the built-in airline/route/badge header (canonical
    /// `.header { }` slot; `.board`/`.timeline`). The status-change VoiceOver
    /// announcement lives on the card shell, not the header — it keeps firing
    /// with a custom header.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.headerSlot = AnyView(content()) }
    }

    /// Overrides the phase-timeline titles; `nil` keeps the stock
    /// English-generic titles ("Check-in" / "Boarding" / "Departed" / "Arrived").
    func phaseTitles(checkIn: String? = nil, boarding: String? = nil,
                     departed: String? = nil, arrived: String? = nil) -> Self {
        copy {
            $0.checkInTitleOverride = checkIn
            $0.boardingTitleOverride = boarding
            $0.departedTitleOverride = departed
            $0.arrivedTitleOverride = arrived
        }
    }

    /// Inner padding of the card shell as a spacing token (default `.md`) —
    /// forwarded to the composed `Card`.
    func contentPadding(_ key: Theme.SpacingKey) -> Self { copy { $0.contentPaddingKey = key } }

    /// Replaces the built-in route progress track, built per clamped 0…1
    /// fraction. The replacement must carry its own accessibility value —
    /// the stock track's "NN percent" read-out is part of what it replaces.
    func progressContent(@ViewBuilder _ content: @escaping (Double) -> some View) -> Self {
        copy { $0.progressSlot = { AnyView(content($0)) } }
    }

    /// Marker/label size of the phase timeline (default `.small`).
    func timelineSize(_ s: StepsSize) -> Self { copy { $0.timelineSizeValue = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("On time · boarding · delayed") {
    let dep = Date().addingTimeInterval(2 * 3600)
    let leg = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                        departure: dep, arrival: dep.addingTimeInterval(4 * 3600))
    return ScrollView {
        VStack(spacing: Theme.SpacingKey.lg.value) {
            FlightTracker(.init(leg: leg, status: .onTime, gate: "B12", terminal: "1", checkInDesk: "34–38"))
                .updated(Date().addingTimeInterval(-120))

            FlightTracker(.init(leg: leg, status: .boarding, gate: "B12", terminal: "1"))
                .details([("Aircraft", "A321neo")])
                .footer {
                    Text("Boarding closes 20 minutes before departure.")
                        .textStyle(.bodySm400)
                }

            FlightTracker(.init(leg: leg, status: .delayed, gate: "B12", terminal: "1",
                                estimatedDeparture: dep.addingTimeInterval(35 * 60),
                                estimatedArrival: dep.addingTimeInterval(4 * 3600 + 35 * 60),
                                aircraft: "A321neo"))
                .updated(Date().addingTimeInterval(-60))
        }
        .padding()
    }
    .background(Theme.shared.background(.bgBase))
}

#Preview("En route · arrived · cancelled · read-only") {
    let dep = Date().addingTimeInterval(-3 * 3600)
    let leg = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                        departure: dep, arrival: dep.addingTimeInterval(4 * 3600))
    return ScrollView {
        VStack(spacing: Theme.SpacingKey.lg.value) {
            FlightTracker(.init(leg: leg, status: .departed, aircraft: "A321neo"))
                .progress(0.62)
                .updated(Date().addingTimeInterval(-300))

            FlightTracker(.init(leg: leg, status: .arrived, terminal: "2", baggageBelt: "7"))
                .progress(1)

            FlightTracker(.init(leg: leg, status: .cancelled))
                .showsTimeline(false)
                .footer {
                    Text("Rebooking options are available at the transfer desk.")
                        .textStyle(.bodySm400)
                }
                .readOnly()
        }
        .padding()
    }
    .background(Theme.shared.background(.bgBase))
}

#Preview("Compact · header slot · custom progress · phase titles") {
    let dep = Date().addingTimeInterval(-2 * 3600)
    let leg = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                        departure: dep, arrival: dep.addingTimeInterval(4 * 3600))
    return ScrollView {
        VStack(spacing: Theme.SpacingKey.lg.value) {
            // Compact strips — delayed shows the estimate in the status tone.
            FlightTracker(.init(leg: leg, status: .departed))
                .flightTrackerStyle(.compact)
            FlightTracker(.init(leg: leg, status: .delayed,
                                estimatedDeparture: dep.addingTimeInterval(45 * 60)))
                .flightTrackerStyle(.compact)

            // Header slot + custom progress content + renamed phases.
            FlightTracker(.init(leg: leg, status: .departed, gate: "B12", terminal: "1"))
                .progress(0.4)
                .header {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Icon(systemName: "airplane.circle.fill").size(.md)
                        Text("SK 1893 · Live").textStyle(.headingSm)
                        Spacer()
                    }
                }
                .progressContent { fraction in
                    ProgressBar(value: fraction)
                }
                .phaseTitles(checkIn: "Bag drop", arrived: "Landed")
                .timelineSize(.medium)
                .contentPadding(.lg)

            // Facts/estimates toggled off.
            FlightTracker(.init(leg: leg, status: .boarding, gate: "B12", terminal: "1",
                                estimatedDeparture: dep.addingTimeInterval(20 * 60)))
                .showsFacts(false)
                .showsEstimates(false)
        }
        .padding()
    }
    .background(Theme.shared.background(.bgBase))
}

#Preview("Dark · accent override") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    let dep = Date().addingTimeInterval(-90 * 60)
    let leg = FlightLeg(airline: "Skyline Air", from: "JFK", to: "SFO",
                        departure: dep, arrival: dep.addingTimeInterval(6 * 3600))
    return ScrollView {
        FlightTracker(.init(leg: leg, status: .departed, gate: "22", terminal: "4"))
            .progress(0.3)
            .accent(.accent)
            .updated(Date().addingTimeInterval(-45))
            .padding()
    }
    .background(dark.background(.bgBase))
    .theme(dark)
}
