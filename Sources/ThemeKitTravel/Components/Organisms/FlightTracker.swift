//
//  FlightTracker.swift
//  ThemeKitTravel
//
//  Edition organism (F3.3 · ADR §9.9). The live status/gate screen — status
//  badge, route with an en-route progress treatment, schedule vs estimate,
//  gate/terminal/belt facts and a phase timeline. Composes ThemeKit's neutral
//  `Card`, `FlightStatusBadge`, `FlightRoute`, `KeyValueTable` and `Steps` —
//  nothing is re-implemented here.
//
//  Stateless by construction (house rule 1): the app polls or streams and
//  re-renders with a fresh `FlightStatusInfo` — no `Task`, no timers. Delay
//  rendering: when an estimate differs from the scheduled time, the scheduled
//  time strikes through in `textTertiary` and the estimate renders in the
//  status tone (`FlightStatus.semantic`).
//
//  ## Status-change announcement pattern (a11y live region)
//  The header is one combined VoiceOver element ("Skyline Air, IST to LHR,
//  Delayed, estimated departure 2:20 PM"). Because the tracker is stateless,
//  a *change* of status is just a re-render with a new `info` — the component
//  watches that transition with `.onChange(of: info.status)` and posts an
//  `AccessibilityNotification.Announcement`, gated to an actual value change,
//  so VoiceOver interrupts with "Delayed, estimated departure 2:20 PM" the
//  moment the poll flips the status. This only fires while the same
//  `FlightTracker` stays in the hierarchy (identity-preserving re-render); if
//  a host rebuilds the screen from scratch it should post its own announcement.
//
//  ```swift
//  FlightTracker(info)
//      .progress(0.62)
//      .updated(lastPoll)
//      .details([("Aircraft", "A321neo")])
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``FlightTracker``: the full status board (`.board`,
/// default) or a one-row status strip (`.compact`) for lists and widgets.
public enum FlightTrackerVariant: Sendable { case board, compact }

/// The live flight status board — badge, route + progress, schedule vs
/// estimate, gate/terminal/belt facts and a phase timeline, on a `Card` shell.
public struct FlightTracker: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let info: FlightStatusInfo

    // Appearance/config — mutated only through the modifiers below (R2).
    private var progressValue: Double?
    private var updatedDate: Date?
    private var extraDetails: [(String, String)] = []
    private var timelineVisible = true
    private var accentOverride: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var elevationValue: CardElevation = .soft
    private var footerSlot: AnyView?
    private var variantValue: FlightTrackerVariant = .board
    private var showsFactsValue = true
    private var showsEstimatesValue = true
    /// Replaces the built-in airline/route/badge header (`.board` only).
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

    /// Tone for the progress treatment and estimates: the explicit accent, or
    /// the status's own semantic colour (`FlightStatus.semantic`).
    private var tone: SemanticColor { accentOverride ?? info.status.semantic }

    private var motion: Animation? {
        MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion)
    }

    private var clampedProgress: Double? {
        progressValue.map { min(max($0, 0), 1) }
    }

    private var timeFormat: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
    }

    /// An estimate "counts" only when it moves the schedule by a minute or more.
    private func meaningfulEstimate(_ estimate: Date?, vs scheduled: Date) -> Date? {
        guard let estimate, abs(estimate.timeIntervalSince(scheduled)) >= 60 else { return nil }
        return estimate
    }

    private var departureEstimate: Date? { meaningfulEstimate(info.estimatedDeparture, vs: info.leg.departure) }
    private var arrivalEstimate: Date? { meaningfulEstimate(info.estimatedArrival, vs: info.leg.arrival) }

    /// "+35m" delay shown on the badge while the flight is delayed.
    private var delayText: String? {
        guard info.status == .delayed, let estimate = departureEstimate else { return nil }
        let minutes = Int(estimate.timeIntervalSince(info.leg.departure) / 60)
        guard minutes > 0 else { return nil }
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "+\(h)h \(m)m" : "+\(m)m"
    }

    // MARK: Body

    public var body: some View {
        let card = Card {
            switch variantValue {
            case .board: content
            case .compact: compactStrip
            }
        }
            .contentPadding(contentPaddingKey)
            .surface(surfaceKey)
            .elevation(elevationValue)
        Group {
            if let footerSlot {
                card.footer {
                    // Read-only surfaces block interaction in slot-hosted
                    // actions too — the only tappable area the tracker can host.
                    footerSlot.allowsHitTesting(!isReadOnly)
                }
            } else {
                card
            }
        }
        .animation(motion, value: clampedProgress)
        // Live-region pattern: announce the transition, gated to a real change.
        .onChange(of: info.status) { oldValue, newValue in
            guard oldValue != newValue else { return }
            AccessibilityNotification.Announcement(
                [newValue.label, estimateSummary].compactMap { $0 }.joined(separator: ", ")
            ).post()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let headerSlot { headerSlot } else { header }
            route
            if showsEstimatesValue, departureEstimate != nil || arrivalEstimate != nil {
                estimateRows
            }
            if showsFactsValue, !factRows.isEmpty {
                KeyValueTable(rows: factRows)
            }
            if timelineVisible {
                Steps(phases).size(timelineSizeValue)
            }
            if let updatedDate {
                updatedCaption(updatedDate)
            }
        }
    }

    // MARK: Compact variant — one-row status strip

    /// One combined VoiceOver element, like the board header; the status
    /// announcement `onChange` on the card shell covers this variant too.
    private var compactStrip: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            FlightStatusBadge(info.status).time(delayText)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.leg.origin) – \(info.leg.destination)")
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                Text(info.leg.airline)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            .lineLimit(1)
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if showsEstimatesValue, let estimate = departureEstimate ?? arrivalEstimate {
                Text(estimate.formatted(timeFormat))
                    .textStyle(.labelBase600)
                    .foregroundStyle(tone.base)
            } else {
                Text(info.leg.departure.formatted(timeFormat))
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textSecondary))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerSummary)
    }

    // MARK: Header — one combined VoiceOver element

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.leg.airline)
                    .textStyle(.labelLg600)
                    .foregroundStyle(theme.text(.textPrimary))
                Text("\(info.leg.origin) – \(info.leg.destination)")
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            FlightStatusBadge(info.status).time(delayText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerSummary)
    }

    /// "Skyline Air, IST to LHR, Delayed, estimated departure 2:20 PM".
    private var headerSummary: String {
        [
            info.leg.airline,
            String(themeKitTravel: "\(info.leg.origin) to \(info.leg.destination)"),
            info.status.label,
            estimateSummary,
        ].compactMap { $0 }.joined(separator: ", ")
    }

    private var estimateSummary: String? {
        if let estimate = departureEstimate {
            return String(themeKitTravel: "estimated departure \(estimate.formatted(timeFormat))")
        }
        if let estimate = arrivalEstimate {
            return String(themeKitTravel: "estimated arrival \(estimate.formatted(timeFormat))")
        }
        return nil
    }

    // MARK: Route + progress treatment

    @ViewBuilder
    private var route: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            FlightRoute(
                from: info.leg.origin, to: info.leg.destination,
                departure: info.leg.departure, arrival: info.leg.arrival
            )
            .stops(info.leg.stops)
            if let fraction = clampedProgress {
                if let progressSlot {
                    progressSlot(fraction)
                } else {
                    RouteProgressTrack(fraction: fraction, tone: tone)
                }
            }
        }
    }

    // MARK: Schedule vs estimate

    private var estimateRows: some View {
        VStack(spacing: 0) {
            if let estimate = departureEstimate {
                estimateRow(String(themeKitTravel: "Departure"), scheduled: info.leg.departure, estimate: estimate)
            }
            if departureEstimate != nil && arrivalEstimate != nil {
                DividerView().size(.small)
            }
            if let estimate = arrivalEstimate {
                estimateRow(String(themeKitTravel: "Arrival"), scheduled: info.leg.arrival, estimate: estimate)
            }
        }
    }

    private func estimateRow(_ label: String, scheduled: Date, estimate: Date) -> some View {
        HStack {
            Text(label)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textSecondary))
            Spacer(minLength: Theme.SpacingKey.md.value)
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Text(scheduled.formatted(timeFormat))
                    .textStyle(.bodyBase400)
                    .strikethrough()
                    .foregroundStyle(theme.text(.textTertiary))
                Text(estimate.formatted(timeFormat))
                    .textStyle(.labelBase600)
                    .foregroundStyle(tone.base)
            }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            themeKitTravel: "\(label): scheduled \(scheduled.formatted(timeFormat)), estimated \(estimate.formatted(timeFormat))"
        ))
    }

    // MARK: Facts — gate / terminal / desk / belt (+ caller details)

    private var factRows: [KeyValueTable.Row] {
        var rows: [KeyValueTable.Row] = []
        if let terminal = info.terminal { rows.append(.init(String(themeKitTravel: "Terminal"), value: terminal)) }
        if let gate = info.gate { rows.append(.init(String(themeKitTravel: "Gate"), value: gate)) }
        if let desk = info.checkInDesk { rows.append(.init(String(themeKitTravel: "Check-in desk"), value: desk)) }
        if let belt = info.baggageBelt { rows.append(.init(String(themeKitTravel: "Baggage belt"), value: belt)) }
        if let aircraft = info.aircraft { rows.append(.init(String(themeKitTravel: "Aircraft"), value: aircraft)) }
        rows.append(contentsOf: extraDetails.map { .init($0.0, value: $0.1) })
        return rows
    }

    // MARK: Phase timeline — Check-in → Boarding → Departed → Arrived

    private var phases: [Steps.Step] {
        let titles = (
            checkIn: checkInTitleOverride ?? String(themeKitTravel: "Check-in"),
            boarding: boardingTitleOverride ?? String(themeKitTravel: "Boarding"),
            departed: departedTitleOverride ?? String(themeKitTravel: "Departed"),
            arrived: arrivedTitleOverride ?? String(themeKitTravel: "Arrived")
        )
        let states: [StepState]
        switch info.status {
        case .onTime, .delayed: states = [.active, .todo, .todo, .todo]
        case .boarding:         states = [.done, .active, .todo, .todo]
        case .gateClosed:       states = [.done, .done, .active, .todo]
        case .departed:         states = [.done, .done, .done, .active]
        case .arrived:          states = [.done, .done, .done, .done]
        case .cancelled:        states = [.done, .error, .todo, .todo]
        }
        return [
            .init(titles.checkIn, state: states[0]),
            .init(titles.boarding, state: states[1]),
            .init(titles.departed, state: states[2]),
            // While en route, the Ant `percent` ring mirrors the route progress.
            .init(titles.arrived, state: states[3],
                  percent: states[3] == .active ? clampedProgress : nil),
        ]
    }

    // MARK: Updated caption

    private func updatedCaption(_ date: Date) -> some View {
        Text(String(themeKitTravel: "Updated \(date.formatted(.relative(presentation: .named).locale(locale)))"))
            .textStyle(.bodySm400)
            .foregroundStyle(theme.text(.textTertiary))
    }
}

// MARK: - Route progress track (private — the §9.9 "progress treatment")

/// A token-fed en-route bar under the `FlightRoute` path: a hairline track, a
/// status-tinted fill and an airplane glyph riding the fill's leading→trailing
/// edge. Built from leading-aligned layout so it mirrors under RTL; the glyph
/// flips with the layout direction.
private struct RouteProgressTrack: View {
    let fraction: Double
    let tone: SemanticColor
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.border(.borderPrimary))
                    .frame(height: 3)
                Capsule()
                    .fill(tone.solid)
                    .frame(width: max(6, geo.size.width * fraction), height: 3)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "airplane")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tone.base)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKitTravel: "Flight progress"))
        .accessibilityValue(String(themeKitTravel: "\(Int((fraction * 100).rounded())) percent"))
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

    /// Surface fill for the card shell (background token key, default `.bgWhite`)
    /// — threaded into the active `CardStyle` via the composed `Card`.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Card shell elevation: none / soft (default) / elevated.
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevationValue = e } }

    /// Bottom-aligned accessory area (canonical `.footer { }` slot, forwarded
    /// to the composed `Card`) — e.g. a "Share status" action or a disruption
    /// note. Hit-testing is disabled while the surface is `.readOnly()`.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.footerSlot = AnyView(content()) }
    }

    /// Layout archetype: `.board` (default, the full status card) or
    /// `.compact` — a one-row badge + route + time strip for lists/widgets.
    func variant(_ v: FlightTrackerVariant) -> Self { copy { $0.variantValue = v } }

    /// Show the gate/terminal/desk/belt facts grid (default on; `.board` only).
    func showsFacts(_ on: Bool = true) -> Self { copy { $0.showsFactsValue = on } }

    /// Show the schedule-vs-estimate rows (and the `.compact` estimate time)
    /// when estimates differ meaningfully from the schedule (default on).
    func showsEstimates(_ on: Bool = true) -> Self { copy { $0.showsEstimatesValue = on } }

    /// Replaces the built-in airline/route/badge header (canonical
    /// `.header { }` slot; `.board` variant). The status-change VoiceOver
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
                .variant(.compact)
            FlightTracker(.init(leg: leg, status: .delayed,
                                estimatedDeparture: dep.addingTimeInterval(45 * 60)))
                .variant(.compact)

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
