//
//  FlightStatusBadgeStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightStatusBadge`` (ADR-0004, Wave 1). An atom has
//  no layout anatomy to swap — these presets are the fill-emphasis looks the
//  badge always owned, promoted from ``FlightStatusEmphasis`` so the whole
//  suite answers to one mental model (`.xStyle(_:)`, settable once per screen
//  via the environment). The hue is **never** a style decision: every preset
//  draws with the status's own semantic colour (``FlightStatus/semantic``) —
//  presets vary presentation only.
//
//    .soft     soft tint fill (default)
//    .solid    solid semantic fill
//    .outline  hairline outline, no fill
//    .dot      a small status dot before plain text — no pill chrome
//
//      FlightStatusBadge(.delayed).time("+35m")
//          .flightStatusBadgeStyle(.solid)
//
//  Size ramp, shape, icon and time stay *configuration* knobs (not presets):
//  they compose with any style, including custom ones.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightStatusBadgeStyle`` renders. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no time → no trailing text, hidden icon → text only).
public struct FlightStatusBadgeConfiguration {
    /// The status being announced — also the single source of truth for hue
    /// (via ``tone``); styles must not invent their own status colours.
    public let status: FlightStatus
    /// Trailing time text, e.g. `"+35m"` (delay) or `"13:15"`; `nil` hides it.
    public let timeText: String?
    /// Label override (`FlightStatusBadge.label(_:)`); resolve via ``label``.
    public let labelOverride: String?
    /// Whether a leading glyph was requested at all (`.showsIcon(false)` /
    /// `.icon(nil)` both turn this off); resolve via ``icon``.
    public let showsIcon: Bool
    /// Per-instance glyph override (`FlightStatusBadge.icon(_:)`); `nil` means
    /// the status's own symbol. Resolve via ``icon``.
    public let iconOverride: String?
    /// The size ramp tier — resolve type via ``labelTextStyle`` /
    /// ``timeTextStyle`` / ``iconTextStyle`` and height via ``controlHeight``.
    public let size: FlightStatusBadgeSize
    /// Corner treatment; resolve via ``badgeShape``.
    public let shape: FlightStatusBadgeShape
    /// Whether the opt-in urgency pulse is *actively* playing — the component
    /// already gated `.pulses()` by `microAnimations` + Reduce Motion and it
    /// applies the opacity pulse itself around the style's output, so built-ins
    /// ignore this; custom styles may add extra (already-gated) urgency chrome.
    public let isPulsing: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding with ``spacing(_:)``.
    public let density: ComponentDensity

    init(status: FlightStatus, timeText: String?, labelOverride: String?,
         showsIcon: Bool, iconOverride: String?, size: FlightStatusBadgeSize,
         shape: FlightStatusBadgeShape, isPulsing: Bool, density: ComponentDensity) {
        self.status = status
        self.timeText = timeText
        self.labelOverride = labelOverride
        self.showsIcon = showsIcon
        self.iconOverride = iconOverride
        self.size = size
        self.shape = shape
        self.isPulsing = isPulsing
        self.density = density
    }

    /// The status's semantic tone — the badge's one true hue. Deliberately
    /// computed (not stored): there is no way to feed a style a foreign accent.
    public var tone: SemanticColor { status.semantic }

    /// The display label — the override, or the status's canonical wording.
    public var label: String { labelOverride ?? status.label }

    /// The resolved leading glyph — the override, or the status's own symbol;
    /// `nil` when the icon is hidden.
    public var icon: String? { showsIcon ? (iconOverride ?? status.icon) : nil }

    /// Type ramp for the label at the configured ``size``.
    public var labelTextStyle: TextStyle { size.labelStyle }
    /// Type ramp for the trailing time at the configured ``size``.
    public var timeTextStyle: TextStyle { size.timeStyle }
    /// Type ramp for the leading glyph at the configured ``size``.
    public var iconTextStyle: TextStyle { size.iconStyle }
    /// Fixed control height of the configured ``size`` (20/24/28 pt).
    public var controlHeight: CGFloat { size.height }

    /// The clip/stroke shape for pill-chrome styles: a continuous capsule, or
    /// a rounded rectangle at the selector radius role.
    public var badgeShape: AnyShape {
        shape == .capsule
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }

    /// Density-scaled spacing — use for chrome padding so `.componentDensity`
    /// compacts or airs out the badge.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `FlightStatusBadge`'s entire presentation. Implement `makeBody`
/// to render the configuration's status; keep the hue on ``FlightStatusBadgeConfiguration/tone``.
/// Set one with `.flightStatusBadgeStyle(_:)`; the default is ``SoftFlightStatusBadgeStyle``.
public protocol FlightStatusBadgeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightStatusBadgeConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The dot-or-glyph + label + time content row every built-in shares.
private struct StatusContent: View {
    @Environment(\.theme) private var theme
    let configuration: FlightStatusBadgeConfiguration
    /// `.dot` swaps the glyph for a small plain status dot.
    var showsDot = false

    var body: some View {
        HStack(spacing: 4) {
            if showsDot {
                Circle().fill(theme.resolve(configuration.tone).base).frame(width: 6, height: 6)
            } else if let icon = configuration.icon {
                Image(systemName: icon).textStyle(configuration.iconTextStyle)
            }
            Text(configuration.label).textStyle(configuration.labelTextStyle)
            if let time = configuration.timeText {
                Text(time).textStyle(configuration.timeTextStyle).opacity(0.9)
            }
        }
    }
}

/// The `StatusPill` fill/foreground/stroke treatment — a role, not a resolved
/// `Color`, so the pill can resolve `configuration.tone` against its own
/// environment theme in `body` (ADR-0006) instead of the caller baking colors
/// at `makeBody`-call time (`FlightStatusBadgeStyle` conformers are plain
/// structs with no `@Environment` access of their own).
private enum PillTreatment { case soft, solid, outline }

/// The pill chrome shared by `.soft`/`.solid`/`.outline`: content row, side
/// padding, fixed control height, shaped fill and optional hairline stroke.
private struct StatusPill: View {
    @Environment(\.theme) private var theme
    let configuration: FlightStatusBadgeConfiguration
    let treatment: PillTreatment

    private var resolved: SemanticColor.Resolved { theme.resolve(configuration.tone) }
    private var fill: Color {
        switch treatment {
        case .soft: return resolved.bg
        case .solid: return resolved.solid
        case .outline: return .clear
        }
    }
    private var foreground: Color {
        switch treatment {
        case .soft, .outline: return resolved.base
        case .solid: return resolved.onSolid
        }
    }
    private var stroke: Color? { treatment == .outline ? resolved.border : nil }

    var body: some View {
        StatusContent(configuration: configuration)
            .foregroundStyle(foreground)
            .padding(.horizontal, configuration.spacing(.sm))
            .frame(height: configuration.controlHeight)
            .background(fill, in: configuration.badgeShape)
            .overlay {
                if let stroke { configuration.badgeShape.stroke(stroke, lineWidth: 1) }
            }
    }
}

// MARK: - 1. Soft — soft tint fill (default)

/// Soft tint fill with the tone's base foreground — today's default look.
public struct SoftFlightStatusBadgeStyle: FlightStatusBadgeStyle {
    public init() {}
    public func makeBody(configuration: FlightStatusBadgeConfiguration) -> some View {
        StatusPill(configuration: configuration, treatment: .soft)
    }
}

// MARK: - 2. Solid — solid semantic fill

/// Solid semantic fill with on-solid foreground — the loud variant for
/// departure boards and urgent states.
public struct SolidFlightStatusBadgeStyle: FlightStatusBadgeStyle {
    public init() {}
    public func makeBody(configuration: FlightStatusBadgeConfiguration) -> some View {
        StatusPill(configuration: configuration, treatment: .solid)
    }
}

// MARK: - 3. Outline — hairline stroke, tinted text

/// Hairline tone-tinted outline, no fill — the quiet variant for dense lists.
public struct OutlineFlightStatusBadgeStyle: FlightStatusBadgeStyle {
    public init() {}
    public func makeBody(configuration: FlightStatusBadgeConfiguration) -> some View {
        StatusPill(configuration: configuration, treatment: .outline)
    }
}

// MARK: - 4. Dot — bare status dot + text, no pill

/// A small status dot before plain primary text — no fill, no border, no side
/// padding: the chrome-free indicator for inline copy and table cells.
public struct DotFlightStatusBadgeStyle: FlightStatusBadgeStyle {
    public init() {}
    public func makeBody(configuration: FlightStatusBadgeConfiguration) -> some View {
        DotChrome(configuration: configuration)
    }
}

private struct DotChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightStatusBadgeConfiguration

    var body: some View {
        StatusContent(configuration: configuration, showsDot: true)
            .foregroundStyle(theme.text(.textPrimary))
            .frame(height: configuration.controlHeight)
    }
}

// MARK: - Static accessors

public extension FlightStatusBadgeStyle where Self == SoftFlightStatusBadgeStyle {
    /// Soft tint fill (the default) — the status hue applied quietly.
    static var soft: SoftFlightStatusBadgeStyle { SoftFlightStatusBadgeStyle() }
}
public extension FlightStatusBadgeStyle where Self == SolidFlightStatusBadgeStyle {
    /// Solid semantic fill — the loud variant for boards and urgent states.
    static var solid: SolidFlightStatusBadgeStyle { SolidFlightStatusBadgeStyle() }
}
public extension FlightStatusBadgeStyle where Self == OutlineFlightStatusBadgeStyle {
    /// Hairline tone outline, no fill — the quiet variant for dense lists.
    static var outline: OutlineFlightStatusBadgeStyle { OutlineFlightStatusBadgeStyle() }
}
public extension FlightStatusBadgeStyle where Self == DotFlightStatusBadgeStyle {
    /// Bare status dot + plain text — chrome-free, for inline copy and cells.
    static var dot: DotFlightStatusBadgeStyle { DotFlightStatusBadgeStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightStatusBadgeStyle: FlightStatusBadgeStyle {
    private let _makeBody: @MainActor (FlightStatusBadgeConfiguration) -> AnyView
    init<S: FlightStatusBadgeStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightStatusBadgeConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightStatusBadgeStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightStatusBadgeStyle(SoftFlightStatusBadgeStyle())
}

extension EnvironmentValues {
    var flightStatusBadgeStyle: AnyFlightStatusBadgeStyle {
        get { self[FlightStatusBadgeStyleKey.self] }
        set { self[FlightStatusBadgeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightStatusBadgeStyle`` for `FlightStatusBadge`s in this view
    /// and its descendants — a departure board sets it once for every row.
    func flightStatusBadgeStyle<S: FlightStatusBadgeStyle>(_ style: sending S) -> some View {
        environment(\.flightStatusBadgeStyle, AnyFlightStatusBadgeStyle(style))
    }
}

// MARK: - Preview

#Preview {
    /// Proof of external implementability: a custom underline look. Note it
    /// still colours from `configuration.tone` — hue is never a style decision.
    struct UnderlineFlightStatusBadgeStyle: FlightStatusBadgeStyle {
        func makeBody(configuration: FlightStatusBadgeConfiguration) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let icon = configuration.icon {
                        Image(systemName: icon).textStyle(configuration.iconTextStyle)
                    }
                    Text(configuration.label).textStyle(configuration.labelTextStyle)
                    if let time = configuration.timeText {
                        Text(time).textStyle(configuration.timeTextStyle).opacity(0.9)
                    }
                }
                .foregroundStyle(configuration.tone.base)
                Capsule().fill(configuration.tone.base).frame(height: 2)
            }
            .fixedSize()
        }
    }

    let statuses: [FlightStatus] = [.onTime, .boarding, .delayed, .cancelled]

    func row(_ time: String?) -> some View {
        HStack(spacing: 8) {
            ForEach(statuses, id: \.self) { status in
                FlightStatusBadge(status).time(status == .delayed ? time : nil)
            }
        }
    }

    return PreviewMatrix("FlightStatusBadgeStyle") {
        PreviewCase("Soft (default)") { row("+35m") }
        PreviewCase("Soft via env") { row("+35m").flightStatusBadgeStyle(.soft) }
        PreviewCase("Solid") { row("+35m").flightStatusBadgeStyle(.solid) }
        PreviewCase("Outline") { row("+35m").flightStatusBadgeStyle(.outline) }
        PreviewCase("Dot") { row("+35m").flightStatusBadgeStyle(.dot) }
        PreviewCase("Knobs compose with a style") {
            HStack(spacing: 8) {
                FlightStatusBadge(.gateClosed).size(.small)
                FlightStatusBadge(.gateClosed).shape(.rounded)
                FlightStatusBadge(.gateClosed).icon("lock.badge.clock").time("13:15")
            }
            .flightStatusBadgeStyle(.solid)
        }
        PreviewCase("Custom style (underline)") {
            row("+35m").flightStatusBadgeStyle(UnderlineFlightStatusBadgeStyle())
        }
    }
}
