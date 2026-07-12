//
//  SeatMapStyle.swift
//  ThemeKit
//
//  The styling hook for ``SeatMap`` — a Class B protocol of ADR-0004
//  (per-component style protocols). Unlike Class A (typed data the style lays
//  out itself), this component owns *live interactive controls* — selection,
//  pinch-to-zoom, deck filtering, passenger assignment — so the configuration
//  hands styles **pre-wired, type-erased units**: the built cabin grid, the
//  passenger rail, the deck selector, the legend and the summary bar. Styles
//  ARRANGE these units; they never re-wire them. Three built-ins:
//
//    .cabin      rail + deck selector + grid + legend + summary — today's
//                arrangement. Default.
//    .grid       the bare seat grid, chrome-less — no rail, deck selector,
//                legend or summary, even when the component built them
//                (venue-picker style).
//    .schematic  the grid framed in a fuselage silhouette with wing and
//                exit-door markers along its sides.
//
//      SeatMap(columns: "ABC DEF", rows: Array(1...30), selection: $picked) { … }
//          .legend().showsSeatInfo()
//          .seatMapStyle(.schematic)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything (there is no delegated shell here — SeatMap draws
//  its own chrome, so a style that wants chrome, like `.schematic`, draws it
//  itself). Selection, zoom and deck state stay in the component — a style
//  never touches them, it only decides where the pre-built units go.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The pre-wired units + typed signals a ``SeatMapStyle`` arranges. The
/// `AnyView` fields are fully interactive (selection, zoom and deck-filtering
/// are already wired) — place them, never rebuild them. The typed fields are
/// read-only signals for arrangement decisions; the component's `@State`
/// (zoom, focused seat, active passenger/deck) never leaves the component.
public struct SeatMapConfiguration {
    // Pre-wired units — fully interactive; styles arrange, never re-wire.
    /// The built cabin grid — sections, rows, seats — with selection,
    /// pinch-to-zoom and deck filtering already wired. Every built-in style
    /// renders this; ``GridSeatMapStyle`` renders *only* this.
    public let cabinGrid: AnyView
    /// The passenger-assignment rail (initials pills, active traveller);
    /// `nil` unless the component was given `SeatMap.passengers(_:assignment:)`.
    public let passengerRail: AnyView?
    /// The deck-switch pill row; `nil` for single-deck cabins.
    public let deckSelector: AnyView?
    /// The fare-tier legend, already matched to the map's seat shape and
    /// palette; `nil` unless `SeatMap.legend()` is on and
    /// ``legendPlacement`` isn't `.hidden`.
    public let legend: AnyView?
    /// The seat-detail + running-total bar — the `SeatMap.summaryBar { }`
    /// slot when provided, else the built-in bar; `nil` unless
    /// `SeatMap.showsSeatInfo()` or a custom summary slot was set.
    public let summaryBar: AnyView?

    // Typed signals for arrangement decisions.
    /// How many seats are currently selected (or assigned, in passenger mode).
    public let selectedCount: Int
    /// Accent for the rail's/deck selector's active pill
    /// (`SeatMap.accent(_:)`), or `nil` for the theme's hero default.
    public let accent: SemanticColor?
    /// Explicit surface fill (`SeatMap.surface(_:)`), or `nil` to let the
    /// style choose its own default (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The silhouette every seat in ``cabinGrid`` is drawn with — forwarded
    /// so a custom style building its own legend keeps swatches matching.
    public let seatShape: SeatShape
    /// Where ``legend`` belongs relative to ``cabinGrid``
    /// (`SeatMap.legendPlacement(_:)`) — `.cabin`/`.schematic` read this to
    /// place it top or bottom; `.hidden` already renders as `legend == nil`.
    public let legendPlacement: LegendPlacement
    /// The environment's component density, captured by the component —
    /// scale chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — pass through to
    /// any locale-sensitive content a custom style adds of its own.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the arrangement.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `SeatMap`'s entire presentation. Implement `makeBody` to arrange
/// the configuration's pre-wired units. Set one with `.seatMapStyle(_:)`; the
/// default is ``CabinSeatMapStyle``.
public protocol SeatMapStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SeatMapConfiguration) -> Body
}

// MARK: - .cabin (default)

/// Today's arrangement, extracted verbatim: passenger rail, deck selector,
/// the legend (top or bottom per ``SeatMapConfiguration/legendPlacement``),
/// the cabin grid, and the summary bar.
public struct CabinSeatMapStyle: SeatMapStyle {
    public init() {}
    public func makeBody(configuration: SeatMapConfiguration) -> some View {
        VStack(spacing: configuration.spacing(.md)) {
            if let passengerRail = configuration.passengerRail { passengerRail }
            if let deckSelector = configuration.deckSelector { deckSelector }
            if let legend = configuration.legend, configuration.legendPlacement == .top { legend }
            configuration.cabinGrid
            if let legend = configuration.legend, configuration.legendPlacement == .bottom { legend }
            if let summaryBar = configuration.summaryBar { summaryBar }
        }
    }
}

// MARK: - .grid

/// The bare seat grid, chrome-less — no rail, deck selector, legend or
/// summary bar, even when the component built them. A venue-picker style:
/// drop a `SeatMap` into a sheet, a form field or a larger layout that
/// supplies its own surrounding chrome.
public struct GridSeatMapStyle: SeatMapStyle {
    public init() {}
    public func makeBody(configuration: SeatMapConfiguration) -> some View {
        configuration.cabinGrid
    }
}

// MARK: - .schematic

/// The grid framed in the fuselage silhouette shared with
/// `SeatMap.fuselage()`, plus wing and exit-door markers along its sides —
/// still arranges rail/deck selector/legend/summary around it, so it stays a
/// drop-in replacement for `.cabin`.
public struct SchematicSeatMapStyle: SeatMapStyle {
    public init() {}
    public func makeBody(configuration: SeatMapConfiguration) -> some View {
        SchematicSeatMapChrome(configuration: configuration)
    }
}

private struct SchematicSeatMapChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SeatMapConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.md)) {
            if let passengerRail = configuration.passengerRail { passengerRail }
            if let deckSelector = configuration.deckSelector { deckSelector }
            if let legend = configuration.legend, configuration.legendPlacement == .top { legend }
            silhouette
            if let legend = configuration.legend, configuration.legendPlacement == .bottom { legend }
            if let summaryBar = configuration.summaryBar { summaryBar }
        }
    }

    /// The cabin grid framed in ``FuselageView`` (shared with
    /// `SeatMap.fuselage()`) plus wing and exit-door markers — a schematic
    /// illustration, not a functional exit map (the real exit rows already
    /// draw their own `EXIT` band inside the grid).
    private var silhouette: some View {
        configuration.cabinGrid
            .padding(Self.fuselageInsets)
            .background { FuselageView(surfaceKey: configuration.surface(default: .bgSecondaryLight)) }
            .overlay(alignment: .leading) { wing(pointsLeading: true) }
            .overlay(alignment: .trailing) { wing(pointsLeading: false) }
            .overlay(alignment: .topLeading) { exitMarker.padding(.top, Self.exitInset).padding(.leading, Self.exitInset) }
            .overlay(alignment: .topTrailing) { exitMarker.padding(.top, Self.exitInset).padding(.trailing, Self.exitInset) }
    }

    /// A small triangular wing blade pointing away from the fuselage. Purely
    /// illustrative — the offset that pushes it outward is applied *before*
    /// `.flipsForRightToLeftLayoutDirection(true)` so the whole picture
    /// (shape + offset) mirrors together, keeping it pointing outward when
    /// `.leading`/`.trailing` swap physical sides under RTL.
    private func wing(pointsLeading: Bool) -> some View {
        FuselageWingShape(pointsLeading: pointsLeading)
            .fill(theme.background(configuration.surface(default: .bgSecondaryLight)))
            .overlay(FuselageWingShape(pointsLeading: pointsLeading).stroke(theme.border(.borderPrimary), lineWidth: 1.5))
            .frame(width: Self.wingSpan, height: Self.wingChord)
            .offset(x: pointsLeading ? -Self.wingSpan * 0.55 : Self.wingSpan * 0.55)
            .flipsForRightToLeftLayoutDirection(true)
            .accessibilityHidden(true)
    }

    /// A small forward exit-door glyph — decorative, echoing `SeatTier.exit`'s
    /// glyph so the schematic reads as an aircraft at a glance.
    private var exitMarker: some View {
        Image(systemName: "door.left.hand.open")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            .padding(Theme.SpacingKey.xs.value)   // 4pt == SpacingKey.xs
            .background(theme.background(.bgWhite), in: Circle())
            .overlay(Circle().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private static let fuselageInsets = EdgeInsets(top: 46, leading: 18, bottom: 26, trailing: 18)
    private static let wingSpan: CGFloat = 30
    private static let wingChord: CGFloat = 44
    private static let exitInset: CGFloat = 10
}

/// A small triangular wing blade for ``SchematicSeatMapStyle`` — points away
/// from the fuselage. `pointsLeading` selects which way it tapers; the host
/// view applies `.flipsForRightToLeftLayoutDirection(true)` (the SKILL's
/// Path rule) so it still points outward once RTL swaps which physical side
/// `.leading`/`.trailing` land on.
private struct FuselageWingShape: Shape {
    var pointsLeading: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointsLeading {
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Static accessors

public extension SeatMapStyle where Self == CabinSeatMapStyle {
    /// Rail + deck selector + grid + legend + summary — today's arrangement. The default.
    static var cabin: CabinSeatMapStyle { CabinSeatMapStyle() }
}
public extension SeatMapStyle where Self == GridSeatMapStyle {
    /// The bare seat grid, chrome-less — a venue-picker style.
    static var grid: GridSeatMapStyle { GridSeatMapStyle() }
}
public extension SeatMapStyle where Self == SchematicSeatMapStyle {
    /// The grid framed in a fuselage silhouette with wing and exit-door markers.
    static var schematic: SchematicSeatMapStyle { SchematicSeatMapStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySeatMapStyle: SeatMapStyle {
    private let _makeBody: @MainActor (SeatMapConfiguration) -> AnyView
    init<S: SeatMapStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SeatMapConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SeatMapStyleKey: EnvironmentKey {
    static let defaultValue = AnySeatMapStyle(CabinSeatMapStyle())
}

extension EnvironmentValues {
    var seatMapStyle: AnySeatMapStyle {
        get { self[SeatMapStyleKey.self] }
        set { self[SeatMapStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SeatMapStyle`` for `SeatMap`s in this view and its
    /// descendants — a compact review sheet can run `.grid` while the
    /// booking flow keeps `.schematic`.
    func seatMapStyle<S: SeatMapStyle>(_ style: sending S) -> some View {
        environment(\.seatMapStyle, AnySeatMapStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — a minimal "N selected"
/// caption above the bare grid, no rail/deck/legend/summary chrome at all.
/// Proves external implementability.
private struct CaptionedSeatMapStyle: SeatMapStyle {
    func makeBody(configuration: SeatMapConfiguration) -> some View {
        CaptionedSeatMapChrome(configuration: configuration)
    }

    private struct CaptionedSeatMapChrome: View {
        @Environment(\.theme) private var theme
        let configuration: SeatMapConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                Text(configuration.selectedCount == 1
                     ? String(themeKitTravel: "1 seat selected")
                     : String(themeKitTravel: "\(configuration.selectedCount) seats selected"))
                    .textStyle(.labelSm600)
                    .foregroundStyle(configuration.accent?.base ?? theme.text(.textSecondary))
                configuration.cabinGrid
            }
        }
    }
}

/// Preview-only harness: owns the `@State` selection each interactive case binds to.
private struct SeatMapStyleHarness<Content: View>: View {
    @State private var selection: Set<String>
    private let content: (Binding<Set<String>>) -> Content

    init(_ initial: Set<String> = [], @ViewBuilder content: @escaping (Binding<Set<String>>) -> Content) {
        self._selection = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($selection) }
}

private func styleSections() -> [SeatSection] {
    [SeatSection(nil, columns: "ABC DEF", rows: Array(1...6)) { id, row, _ in
        SeatInfo(available: !["3B", "4E"].contains(id),
                 price: row <= 2 ? 220 : 90,
                 tier: row == 1 ? .business : .standard)
    }]
}

#Preview("SeatMapStyle — presets × light/dark") {
    PreviewMatrix("SeatMapStyle") {
        PreviewCase(".cabin (default)") {
            SeatMapStyleHarness(["3C"]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .showsLabels().legend().showsSeatInfo()
            }
        }
        PreviewCase(".grid — bare, chrome-less") {
            SeatMapStyleHarness(["3C"]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .showsLabels().legend().showsSeatInfo()
                    .seatMapStyle(.grid)
            }
        }
        PreviewCase(".schematic — fuselage silhouette") {
            SeatMapStyleHarness(["3C"]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .showsLabels().legend().showsSeatInfo()
                    .seatMapStyle(.schematic)
            }
        }
        PreviewCase(".schematic — custom surface") {
            SeatMapStyleHarness([]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .surface(.bgWhite)
                    .seatMapStyle(.schematic)
            }
        }
        PreviewCase("Custom (in-preview)") {
            SeatMapStyleHarness(["3C"]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .seatMapStyle(CaptionedSeatMapStyle())
            }
        }
    }
}

#Preview("SeatMapStyle — .schematic RTL (wing/exit markers mirror)") {
    PreviewMatrix(".schematic", schemes: [.light], rtl: true) {
        PreviewCase(".schematic") {
            SeatMapStyleHarness(["3C"]) { selection in
                SeatMap(sections: styleSections(), selection: selection)
                    .legend()
                    .seatMapStyle(.schematic)
            }
        }
    }
}
