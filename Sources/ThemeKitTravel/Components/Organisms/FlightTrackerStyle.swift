//
//  FlightTrackerStyle.swift
//  ThemeKitTravel
//
//  The styling hook for ``FlightTracker`` (ADR-0004, Wave 4 — Class A). The
//  configuration hands styles the *typed live-status data* (status, gate/
//  terminal/belt facts, estimates, progress), not pre-laid content, so a style
//  owns the entire arrangement. Four built-ins:
//
//    .board     badge + route/progress + facts + phase timeline — today's
//               tracker, verbatim. Default.
//    .compact   one-row status strip for lists and widgets.
//    .timeline  phase-first vertical spine, each phase carrying its own fact
//               (check-in desk, gate + terminal, aircraft, baggage belt).
//    .banner    status-tone strip for push-style surfaces — no card shell.
//
//      FlightTracker(info)
//          .progress(0.62)
//          .updated(lastPoll)
//          .flightTrackerStyle(.timeline)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints *chrome* (card-shaped presets keep composing the neutral
//  `Card`, so `.cardStyle(_:)` still swaps its chrome independently); the
//  token theme colors everything. The status-change VoiceOver announcement
//  and the progress-motion animation stay on ``FlightTracker``'s card shell
//  (the component), not in any style, so both keep firing under every preset.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightTrackerStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no gate → no gate fact/description, no progress →
/// no progress treatment).
public struct FlightTrackerConfiguration {
    /// The live operational status snapshot — every style's primary subject.
    public let statusInfo: FlightStatusInfo
    /// En-route progress 0...1, already clamped; `nil` hides the progress
    /// treatment (`.board`/`.timeline`'s active-phase ring).
    public let progress: Double?
    /// Pre-formatted "Updated 2 minutes ago" caption; `nil` hides it.
    public let updatedText: String?
    /// Caller-supplied extra fact pairs (`FlightTracker/details(_:)`), e.g.
    /// `[("Meal", "Included")]` — resolve alongside ``statusInfo`` via
    /// ``detailRows()``, or on their own via ``extraDetailRows()``.
    public let details: [(String, String)]
    /// Show the Check-in → Boarding → Departed → Arrived phase timeline
    /// (`.board`/`.timeline` only).
    public let showsTimeline: Bool
    /// Show the gate/terminal/desk/belt/aircraft facts (`.board`/`.timeline`).
    public let showsFacts: Bool
    /// Show the schedule-vs-estimate rows (and the `.compact`/`.banner`
    /// estimate time) when estimates differ meaningfully from the schedule.
    public let showsEstimates: Bool
    /// Resolved phase-timeline titles (override, else the stock English-generic
    /// wording) — already localized, re-resolved every body pass.
    public let checkInTitle: String
    public let boardingTitle: String
    public let departedTitle: String
    public let arrivedTitle: String
    /// Inner content padding, as a spacing token — card-shaped presets feed
    /// the composed `Card`.
    public let contentPadding: Theme.SpacingKey
    /// Replaces the built-in route progress track, built per clamped 0...1
    /// fraction. The replacement must carry its own accessibility value.
    public let progressContent: ((Double) -> AnyView)?
    /// Replacement for the built-in airline/route/badge header
    /// (`.header { }`); `nil` = built-in.
    public let header: AnyView?
    /// Bottom-aligned accessory area (`.footer { }`), forwarded to the
    /// composed `Card`'s footer slot by card-shaped styles.
    public let footer: AnyView?
    /// Marker/label size of the phase timeline.
    public let timelineSize: StepsSize
    /// Semantic tint override; `nil` derives from the status
    /// (`FlightStatus.semantic`) — resolve via ``tone()``.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its own
    /// default (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Card shell elevation, fed to the active `CardStyle` by card-shaped styles.
    public let elevation: CardElevation
    /// Read-only surfaces disable the footer slot's hit-testing — the only
    /// tappable area a tracker style can host.
    public let isReadOnly: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the tracker.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The `accent(_:)` override, else the status's own semantic tone
    /// (`FlightStatus.semantic`) — the single source of truth for status
    /// colouring across the flight family.
    public func tone() -> SemanticColor { accent ?? statusInfo.status.semantic }

    /// Shared time formatting, in the captured locale, so every style speaks
    /// one language.
    public func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    /// An estimate "counts" only when it moves the schedule by a minute or more.
    private func meaningfulEstimate(_ estimate: Date?, vs scheduled: Date) -> Date? {
        guard let estimate, abs(estimate.timeIntervalSince(scheduled)) >= 60 else { return nil }
        return estimate
    }
    /// Estimated departure, or `nil` when it doesn't differ meaningfully from schedule.
    public var departureEstimate: Date? { meaningfulEstimate(statusInfo.estimatedDeparture, vs: statusInfo.leg.departure) }
    /// Estimated arrival, or `nil` when it doesn't differ meaningfully from schedule.
    public var arrivalEstimate: Date? { meaningfulEstimate(statusInfo.estimatedArrival, vs: statusInfo.leg.arrival) }

    /// "+35m" delay text while the flight is delayed with a meaningful
    /// departure estimate — feeds `FlightStatusBadge.time(_:)`.
    public var delayText: String? {
        guard statusInfo.status == .delayed, let estimate = departureEstimate else { return nil }
        let minutes = Int(estimate.timeIntervalSince(statusInfo.leg.departure) / 60)
        guard minutes > 0 else { return nil }
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "+\(h)h \(m)m" : "+\(m)m"
    }

    /// "Skyline Air, IST to LHR, Delayed, estimated departure 2:20 PM" — the
    /// header/strip's combined VoiceOver label, shared by every preset that
    /// renders one accessibility element for its identity row.
    public func headerSummary() -> String {
        [
            statusInfo.leg.airline,
            String(themeKitTravel: "\(statusInfo.leg.origin) to \(statusInfo.leg.destination)"),
            statusInfo.status.label,
            estimateSummary(),
        ].compactMap { $0 }.joined(separator: ", ")
    }

    /// "estimated departure 2:20 PM" / "estimated arrival …", or `nil` when
    /// neither estimate differs meaningfully from schedule.
    public func estimateSummary() -> String? {
        if let estimate = departureEstimate {
            return String(themeKitTravel: "estimated departure \(time(estimate))")
        }
        if let estimate = arrivalEstimate {
            return String(themeKitTravel: "estimated arrival \(time(estimate))")
        }
        return nil
    }

    /// The gate/terminal/check-in-desk/baggage-belt/aircraft facts plus the
    /// caller's ``details`` pairs, merged into `KeyValueTable` rows — the
    /// `.board`/`.compact` facts grid.
    public func detailRows() -> [KeyValueTable.Row] {
        var rows: [KeyValueTable.Row] = []
        if let terminal = statusInfo.terminal { rows.append(.init(String(themeKitTravel: "Terminal"), value: terminal)) }
        if let gate = statusInfo.gate { rows.append(.init(String(themeKitTravel: "Gate"), value: gate)) }
        if let desk = statusInfo.checkInDesk { rows.append(.init(String(themeKitTravel: "Check-in desk"), value: desk)) }
        if let belt = statusInfo.baggageBelt { rows.append(.init(String(themeKitTravel: "Baggage belt"), value: belt)) }
        if let aircraft = statusInfo.aircraft { rows.append(.init(String(themeKitTravel: "Aircraft"), value: aircraft)) }
        rows.append(contentsOf: extraDetailRows())
        return rows
    }

    /// Only the caller-supplied ``details`` pairs, as `KeyValueTable` rows —
    /// for styles that already fold the statusInfo facts into another
    /// treatment (e.g. `.timeline`'s per-phase descriptions).
    public func extraDetailRows() -> [KeyValueTable.Row] { details.map { .init($0.0, value: $0.1) } }

    /// Check-in → Boarding → Departed → Arrived phase timeline. The active
    /// phase's percent ring mirrors ``progress`` while en route (Ant Steps
    /// `percent`). With `showsDescriptions` on, each phase carries its own
    /// fact — check-in desk, gate + terminal, aircraft, baggage belt — the
    /// `.timeline` preset's per-phase detail.
    public func phases(showsDescriptions: Bool = false) -> [Steps.Step] {
        let states: [StepState]
        switch statusInfo.status {
        case .onTime, .delayed: states = [.active, .todo, .todo, .todo]
        case .boarding:         states = [.done, .active, .todo, .todo]
        case .gateClosed:       states = [.done, .done, .active, .todo]
        case .departed:         states = [.done, .done, .done, .active]
        case .arrived:          states = [.done, .done, .done, .done]
        case .cancelled:        states = [.done, .error, .todo, .todo]
        }
        let gateAndTerminal = [statusInfo.gate, statusInfo.terminal].compactMap { $0 }.joined(separator: " · ")
        let descriptions: [String?] = showsDescriptions
            ? [statusInfo.checkInDesk, gateAndTerminal.isEmpty ? nil : gateAndTerminal,
               statusInfo.aircraft, statusInfo.baggageBelt]
            : [nil, nil, nil, nil]
        return [
            .init(checkInTitle, description: descriptions[0], state: states[0]),
            .init(boardingTitle, description: descriptions[1], state: states[1]),
            .init(departedTitle, description: descriptions[2], state: states[2]),
            // While en route, the Ant `percent` ring mirrors the route progress.
            .init(arrivedTitle, description: descriptions[3], state: states[3],
                  percent: states[3] == .active ? progress : nil),
        ]
    }
}

// MARK: - Protocol

/// Defines a `FlightTracker`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's live-status data. Set one with
/// `.flightTrackerStyle(_:)`; the default is ``BoardFlightTrackerStyle``.
public protocol FlightTrackerStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightTrackerConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The neutral `Card` shell every card-shaped preset composes (ADR-0004 §6):
/// content padding, surface fill and elevation come from the configuration,
/// the footer slot forwards to `Card`'s own footer with read-only-aware hit
/// testing, and the active `CardStyle` keeps painting the chrome underneath.
private struct TrackerCardShell<Content: View>: View {
    let configuration: FlightTrackerConfiguration
    let content: () -> Content

    init(configuration: FlightTrackerConfiguration, @ViewBuilder content: @escaping () -> Content) {
        self.configuration = configuration
        self.content = content
    }

    var body: some View {
        let card = Card(content: content)
            .contentPadding(configuration.contentPadding)
            .surface(configuration.surface(default: .bgWhite))
            .elevation(configuration.elevation)
        if let footer = configuration.footer {
            card.footer { footer.allowsHitTesting(!configuration.isReadOnly) }
        } else {
            card
        }
    }
}

/// One combined VoiceOver element: airline/route + status badge. Shared by
/// `.board` and `.timeline`.
private struct TrackerHeader: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTrackerConfiguration

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: configuration.spacing(.sm)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.statusInfo.leg.airline)
                    .textStyle(.labelLg600).foregroundStyle(theme.text(.textPrimary))
                Text("\(configuration.statusInfo.leg.origin) – \(configuration.statusInfo.leg.destination)")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            }
            Spacer(minLength: configuration.spacing(.sm))
            FlightStatusBadge(configuration.statusInfo.status).time(configuration.delayText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(configuration.headerSummary())
    }
}

/// The `FlightRoute` path plus the en-route progress treatment underneath —
/// the built-in track, or the caller's `progressContent(_:)` replacement.
private struct TrackerRouteProgress: View {
    let configuration: FlightTrackerConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            FlightRoute(from: configuration.statusInfo.leg.origin, to: configuration.statusInfo.leg.destination,
                        departure: configuration.statusInfo.leg.departure, arrival: configuration.statusInfo.leg.arrival)
                .stops(configuration.statusInfo.leg.stops)
            if let fraction = configuration.progress {
                if let progressContent = configuration.progressContent {
                    progressContent(fraction)
                } else {
                    RouteProgressTrack(fraction: fraction, tone: configuration.tone())
                }
            }
        }
    }
}

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
                    .fill(theme.resolve(tone).solid)
                    .frame(width: max(6, geo.size.width * fraction), height: 3)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "airplane")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.resolve(tone).base)
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

/// Schedule-vs-estimate rows for departure and/or arrival. Shared by `.board`
/// and `.timeline`.
private struct TrackerEstimateRows: View {
    let configuration: FlightTrackerConfiguration

    var body: some View {
        VStack(spacing: 0) {
            if let estimate = configuration.departureEstimate {
                TrackerEstimateRow(configuration: configuration, label: String(themeKitTravel: "Departure"),
                                    scheduled: configuration.statusInfo.leg.departure, estimate: estimate)
            }
            if configuration.departureEstimate != nil && configuration.arrivalEstimate != nil {
                DividerView().size(.small)
            }
            if let estimate = configuration.arrivalEstimate {
                TrackerEstimateRow(configuration: configuration, label: String(themeKitTravel: "Arrival"),
                                    scheduled: configuration.statusInfo.leg.arrival, estimate: estimate)
            }
        }
    }
}

private struct TrackerEstimateRow: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTrackerConfiguration
    let label: String
    let scheduled: Date
    let estimate: Date

    var body: some View {
        HStack {
            Text(label).textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
            Spacer(minLength: configuration.spacing(.md))
            HStack(spacing: configuration.spacing(.xs)) {
                Text(configuration.time(scheduled))
                    .textStyle(.bodyBase400).strikethrough().foregroundStyle(theme.text(.textTertiary))
                Text(configuration.time(estimate))
                    .textStyle(.labelBase600).foregroundStyle(theme.resolve(configuration.tone()).base)
            }
        }
        .padding(.vertical, configuration.spacing(.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            themeKitTravel: "\(label): scheduled \(configuration.time(scheduled)), estimated \(configuration.time(estimate))"
        ))
    }
}

/// "Updated 2 minutes ago" caption. Shared by every preset.
private struct TrackerUpdatedCaption: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
    }
}

/// The one-row status strip: badge, identity, trailing time. Shared by
/// `.compact` (inside the `Card` shell) and `.banner` (bare).
private struct TrackerCompactStrip: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTrackerConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            FlightStatusBadge(configuration.statusInfo.status).time(configuration.delayText)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(configuration.statusInfo.leg.origin) – \(configuration.statusInfo.leg.destination)")
                    .textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                Text(configuration.statusInfo.leg.airline)
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            }
            .lineLimit(1)
            Spacer(minLength: configuration.spacing(.sm))
            trailingTime
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(configuration.headerSummary())
    }

    @ViewBuilder private var trailingTime: some View {
        if configuration.showsEstimates, let estimate = configuration.departureEstimate ?? configuration.arrivalEstimate {
            Text(configuration.time(estimate)).textStyle(.labelBase600).foregroundStyle(theme.resolve(configuration.tone()).base)
        } else {
            Text(configuration.time(configuration.statusInfo.leg.departure))
                .textStyle(.labelBase600).foregroundStyle(theme.text(.textSecondary))
        }
    }
}

// MARK: - .board (default — badge + route/progress + facts + phase timeline)

/// Today's ``FlightTracker`` look, extracted verbatim: header (airline, route,
/// status badge), the route with its en-route progress treatment, schedule vs
/// estimate, the gate/terminal/desk/belt facts grid and the phase timeline —
/// all inside the composed `Card` shell.
public struct BoardFlightTrackerStyle: FlightTrackerStyle {
    public init() {}
    public func makeBody(configuration: FlightTrackerConfiguration) -> some View {
        BoardChrome(configuration: configuration)
    }
}

private struct BoardChrome: View {
    let configuration: FlightTrackerConfiguration

    var body: some View {
        TrackerCardShell(configuration: configuration) {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                if let header = configuration.header { header } else { TrackerHeader(configuration: configuration) }
                TrackerRouteProgress(configuration: configuration)
                if configuration.showsEstimates,
                   configuration.departureEstimate != nil || configuration.arrivalEstimate != nil {
                    TrackerEstimateRows(configuration: configuration)
                }
                if configuration.showsFacts, !configuration.detailRows().isEmpty {
                    KeyValueTable(rows: configuration.detailRows())
                }
                if configuration.showsTimeline {
                    Steps(configuration.phases()).size(configuration.timelineSize)
                }
                if let updatedText = configuration.updatedText {
                    TrackerUpdatedCaption(text: updatedText)
                }
            }
        }
    }
}

// MARK: - .compact (one-row status strip)

/// A one-row badge + identity + time strip for lists and widgets, inside the
/// composed `Card` shell. The status-change VoiceOver announcement on the
/// component's card shell covers this preset too.
public struct CompactFlightTrackerStyle: FlightTrackerStyle {
    public init() {}
    public func makeBody(configuration: FlightTrackerConfiguration) -> some View {
        CompactChrome(configuration: configuration)
    }
}

private struct CompactChrome: View {
    let configuration: FlightTrackerConfiguration

    var body: some View {
        TrackerCardShell(configuration: configuration) {
            TrackerCompactStrip(configuration: configuration)
        }
    }
}

// MARK: - .timeline (phase-first vertical spine w/ per-phase facts)

/// The Check-in → Boarding → Departed → Arrived spine leads the layout, each
/// phase carrying its own fact (check-in desk, gate + terminal, aircraft,
/// baggage belt) as a `Steps` description — a tracker-app detail view, inside
/// the composed `Card` shell. Caller-supplied ``FlightTrackerConfiguration/details``
/// (not already folded into a phase) still render as a small facts table.
public struct TimelineFlightTrackerStyle: FlightTrackerStyle {
    public init() {}
    public func makeBody(configuration: FlightTrackerConfiguration) -> some View {
        TimelineChrome(configuration: configuration)
    }
}

private struct TimelineChrome: View {
    let configuration: FlightTrackerConfiguration

    var body: some View {
        TrackerCardShell(configuration: configuration) {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                if let header = configuration.header { header } else { TrackerHeader(configuration: configuration) }
                if configuration.showsTimeline {
                    Steps(configuration.phases(showsDescriptions: true))
                        .axis(.vertical)
                        .size(configuration.timelineSize)
                }
                if configuration.showsEstimates,
                   configuration.departureEstimate != nil || configuration.arrivalEstimate != nil {
                    TrackerEstimateRows(configuration: configuration)
                }
                if configuration.showsFacts, !configuration.extraDetailRows().isEmpty {
                    KeyValueTable(rows: configuration.extraDetailRows())
                }
                if let updatedText = configuration.updatedText {
                    TrackerUpdatedCaption(text: updatedText)
                }
            }
        }
    }
}

// MARK: - .banner (status-tone strip for push-style surfaces)

/// A chrome-free, status-tone-tinted strip for push-style surfaces (an in-app
/// notification, a home-screen widget row) — no `Card` shell, so
/// `.cardStyle(_:)`/``FlightTrackerConfiguration/surfaceKey`` don't apply
/// here; the fill comes from the status tone itself.
public struct BannerFlightTrackerStyle: FlightTrackerStyle {
    public init() {}
    public func makeBody(configuration: FlightTrackerConfiguration) -> some View {
        BannerChrome(configuration: configuration)
    }
}

private struct BannerChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightTrackerConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
            HStack(spacing: configuration.spacing(.sm)) {
                FlightStatusBadge(configuration.statusInfo.status)
                    .time(configuration.delayText)
                    .flightStatusBadgeStyle(.dot)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(configuration.statusInfo.leg.origin) – \(configuration.statusInfo.leg.destination)")
                        .textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    Text(configuration.statusInfo.leg.airline)
                        .textStyle(.overline400).foregroundStyle(theme.text(.textSecondary))
                }
                .lineLimit(1)
                Spacer(minLength: configuration.spacing(.sm))
                trailingTime
            }
            if let updatedText = configuration.updatedText {
                TrackerUpdatedCaption(text: updatedText)
            }
        }
        .padding(configuration.spacing(.sm))
        .background(theme.resolve(configuration.tone()).soft,
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(configuration.headerSummary())
    }

    @ViewBuilder private var trailingTime: some View {
        if configuration.showsEstimates, let estimate = configuration.departureEstimate ?? configuration.arrivalEstimate {
            Text(configuration.time(estimate)).textStyle(.labelBase600).foregroundStyle(theme.resolve(configuration.tone()).accent)
        } else {
            Text(configuration.time(configuration.statusInfo.leg.departure))
                .textStyle(.labelBase600).foregroundStyle(theme.text(.textSecondary))
        }
    }
}

// MARK: - Static accessors

public extension FlightTrackerStyle where Self == BoardFlightTrackerStyle {
    /// Badge + route/progress + facts + phase timeline — today's tracker. The default.
    static var board: BoardFlightTrackerStyle { BoardFlightTrackerStyle() }
}
public extension FlightTrackerStyle where Self == CompactFlightTrackerStyle {
    /// A one-row status strip for lists and widgets.
    static var compact: CompactFlightTrackerStyle { CompactFlightTrackerStyle() }
}
public extension FlightTrackerStyle where Self == TimelineFlightTrackerStyle {
    /// Phase-first vertical spine, each phase carrying its own fact.
    static var timeline: TimelineFlightTrackerStyle { TimelineFlightTrackerStyle() }
}
public extension FlightTrackerStyle where Self == BannerFlightTrackerStyle {
    /// A status-tone strip for push-style surfaces — no card shell.
    static var banner: BannerFlightTrackerStyle { BannerFlightTrackerStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightTrackerStyle: FlightTrackerStyle {
    private let _makeBody: @MainActor (FlightTrackerConfiguration) -> AnyView
    init<S: FlightTrackerStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightTrackerConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightTrackerStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightTrackerStyle(BoardFlightTrackerStyle())
}

extension EnvironmentValues {
    var flightTrackerStyle: AnyFlightTrackerStyle {
        get { self[FlightTrackerStyleKey.self] }
        set { self[FlightTrackerStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightTrackerStyle`` for `FlightTracker`s in this view and
    /// its descendants — one screen can mix archetypes per section.
    func flightTrackerStyle<S: FlightTrackerStyle>(_ style: sending S) -> some View {
        environment(\.flightTrackerStyle, AnyFlightTrackerStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a status dot + route one-liner, no card shell at all.
private struct DotRowFlightTrackerStyle: FlightTrackerStyle {
    func makeBody(configuration: FlightTrackerConfiguration) -> some View {
        DotRowChrome(configuration: configuration)
    }

    private struct DotRowChrome: View {
        @Environment(\.theme) private var theme
        let configuration: FlightTrackerConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                Circle().fill(theme.resolve(configuration.tone()).solid).frame(width: 8, height: 8)
                Text("\(configuration.statusInfo.leg.origin) → \(configuration.statusInfo.leg.destination)")
                    .textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                Text(configuration.statusInfo.status.label)
                    .textStyle(.overline500).foregroundStyle(theme.resolve(configuration.tone()).base)
            }
            .padding(configuration.spacing(.sm))
            .background(theme.background(configuration.surface(default: .bgSecondaryLight)),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        }
    }
}

#Preview("FlightTrackerStyle — presets × light/dark") {
    let dep = Date().addingTimeInterval(2 * 3_600)
    let leg = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                        departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))
    let onTime = FlightStatusInfo(leg: leg, status: .onTime, gate: "B12", terminal: "1", checkInDesk: "34–38")
    let delayed = FlightStatusInfo(leg: leg, status: .delayed, gate: "B12", terminal: "1",
                                   estimatedDeparture: dep.addingTimeInterval(35 * 60),
                                   estimatedArrival: dep.addingTimeInterval(4 * 3_600 + 35 * 60),
                                   aircraft: "A321neo")
    let boarding = FlightStatusInfo(leg: leg, status: .boarding, gate: "B12", terminal: "1", baggageBelt: "7")

    return PreviewMatrix("FlightTrackerStyle") {
        PreviewCase(".board (default)") {
            FlightTracker(onTime).updated(Date().addingTimeInterval(-120)).flightTrackerStyle(.board)
        }
        PreviewCase(".compact") {
            FlightTracker(delayed).flightTrackerStyle(.compact)
        }
        PreviewCase(".timeline") {
            FlightTracker(boarding).updated(Date().addingTimeInterval(-60)).flightTrackerStyle(.timeline)
        }
        PreviewCase(".banner") {
            FlightTracker(delayed).flightTrackerStyle(.banner)
        }
        PreviewCase("Custom (in-preview)") {
            FlightTracker(delayed).flightTrackerStyle(DotRowFlightTrackerStyle())
        }
    }
}
