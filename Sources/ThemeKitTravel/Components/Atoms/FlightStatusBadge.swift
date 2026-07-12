//
//  FlightStatusBadge.swift
//  ThemeKit
//
//  Atom. A flight status pill — on-time / boarding / delayed / gate-closed /
//  departed / arrived / cancelled, each with a token-fed semantic colour and icon,
//  plus an optional time. Token-bound. Presentation is style-driven
//  (``FlightStatusBadgeStyle``): `.soft` (default) / `.solid` / `.outline` /
//  `.dot`, settable once per screen via `.flightStatusBadgeStyle(_:)`.
//
//  ```swift
//  FlightStatusBadge(.delayed).time("+35m")
//      .flightStatusBadgeStyle(.solid)
//  ```
//

import SwiftUI
import ThemeKit

/// Fill emphasis of a ``FlightStatusBadge`` — the hue is always the status's
/// own semantic colour; emphasis only changes how loudly it's applied.
///
/// > Deprecated pathway (ADR-0004): each case now maps 1:1 to a
/// > ``FlightStatusBadgeStyle`` preset (`.soft`/`.solid`/`.outline`/`.dot`).
/// > Kept public for source compatibility; removed at the next major.
public enum FlightStatusEmphasis: Sendable {
    /// Soft tint fill (default).
    case soft
    /// Solid semantic fill.
    case solid
    /// Hairline outline, no fill.
    case outline
    /// A small status dot before plain text — no fill, no border.
    case dot
}

/// Size ramp of a ``FlightStatusBadge`` (internal heights 20/24/28 pt with
/// stepped text styles).
public enum FlightStatusBadgeSize: Sendable {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: 20
        case .medium: 24
        case .large: 28
        }
    }
    var labelStyle: TextStyle {
        switch self {
        case .small: .overline500
        case .medium: .labelSm700
        case .large: .labelBase700
        }
    }
    var timeStyle: TextStyle {
        switch self {
        case .small: .overline400
        case .medium: .labelSm600
        case .large: .labelBase600
        }
    }
    var iconStyle: TextStyle {
        switch self {
        case .small: .overline500
        case .medium: .labelSm600
        case .large: .labelBase600
        }
    }
}

/// Corner treatment of a ``FlightStatusBadge``: a full `.capsule` (default) or
/// a `.rounded` rectangle at the selector radius role.
public enum FlightStatusBadgeShape: Sendable { case capsule, rounded }

public struct FlightStatusBadge: View {
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.componentDensity) private var density
    @Environment(\.flightStatusBadgeStyle) private var envStyle
    @State private var pulsePhase = false

    private let status: FlightStatus
    // Appearance — mutated only through the modifiers below (R2).
    private var time: String?
    private var customLabel: String?
    private var showsIcon = true
    /// Set only by the deprecated `.emphasis(_:)`/`.solid(_:)` pathway — when
    /// non-nil it wins over any ancestor `.flightStatusBadgeStyle(_:)`
    /// (source-behavior stability during migration, ADR-0004 §5).
    private var explicitEmphasis: FlightStatusEmphasis?
    private var size: FlightStatusBadgeSize = .medium
    private var shape: FlightStatusBadgeShape = .capsule
    private var pulses = false
    private var iconSetting: IconSetting = .automatic

    /// Tri-state icon override: the status glyph, a custom symbol, or hidden.
    private enum IconSetting { case automatic, custom(String), hidden }

    public init(_ status: FlightStatus) { self.status = status }   // R1

    /// The deprecated explicit emphasis mapped to its preset, else the
    /// environment's style (default ``SoftFlightStatusBadgeStyle``).
    private var resolvedStyle: AnyFlightStatusBadgeStyle {
        guard let explicitEmphasis else { return envStyle }
        switch explicitEmphasis {
        case .soft: return AnyFlightStatusBadgeStyle(SoftFlightStatusBadgeStyle())
        case .solid: return AnyFlightStatusBadgeStyle(SolidFlightStatusBadgeStyle())
        case .outline: return AnyFlightStatusBadgeStyle(OutlineFlightStatusBadgeStyle())
        case .dot: return AnyFlightStatusBadgeStyle(DotFlightStatusBadgeStyle())
        }
    }

    /// The tri-state icon setting flattened for the configuration.
    private var resolvedIcon: (shows: Bool, override: String?) {
        guard showsIcon else { return (false, nil) }
        switch iconSetting {
        case .automatic: return (true, nil)
        case .custom(let name): return (true, name)
        case .hidden: return (false, nil)
        }
    }

    /// Whether the opt-in urgency pulse actually plays — the `microAnimations`
    /// switch and the system Reduce Motion setting both gate it.
    private var pulseActive: Bool { pulses && micro && !reduceMotion }

    public var body: some View {
        let icon = resolvedIcon
        let configuration = FlightStatusBadgeConfiguration(
            status: status,
            timeText: time,
            labelOverride: customLabel,
            showsIcon: icon.shows,
            iconOverride: icon.override,
            size: size,
            shape: shape,
            isPulsing: pulseActive,
            density: density
        )
        // The pulse and the accessibility label wrap the style's output, so
        // every style — including custom ones — gets both for free.
        resolvedStyle.makeBody(configuration: configuration)
            .opacity(pulseActive && pulsePhase ? 0.55 : 1)
            .animation(pulseActive ? Motion.slower.animation.repeatForever(autoreverses: true) : nil, value: pulsePhase)
            .onAppear { pulsePhase = pulseActive }
            .onChange(of: pulseActive) { _, active in pulsePhase = active }
            .accessibilityLabel([customLabel ?? status.label, time].compactMap { $0 }.joined(separator: " "))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightStatusBadge {
    /// A trailing time, e.g. "+35m" (delay) or "13:15".
    func time(_ text: String?) -> Self { copy { $0.time = text } }
    /// Override the label text.
    func label(_ text: String?) -> Self { copy { $0.customLabel = text } }
    /// Show the leading icon (default on).
    func showsIcon(_ on: Bool) -> Self { copy { $0.showsIcon = on } }
    /// Solid fill (vs the default soft tint). Sugar for the deprecated
    /// `.emphasis(.solid)` — prefer `.flightStatusBadgeStyle(.solid)`.
    @available(*, deprecated, message: "Use .flightStatusBadgeStyle(.solid)")
    func solid(_ on: Bool = true) -> Self { copy { $0.explicitEmphasis = on ? .solid : .soft } }
    /// Fill emphasis — `.soft` tint (default), `.solid`, hairline `.outline`,
    /// or a chrome-free `.dot` indicator. The hue stays the status's own
    /// semantic colour. An explicit emphasis wins over an ancestor
    /// `.flightStatusBadgeStyle(_:)` for source-behavior stability.
    @available(*, deprecated,
               message: "Use .flightStatusBadgeStyle(_:) — e.g. .emphasis(.solid) becomes .flightStatusBadgeStyle(.solid)")
    func emphasis(_ e: FlightStatusEmphasis) -> Self { copy { $0.explicitEmphasis = e } }
    /// Size ramp (default `.medium`, 24 pt).
    func size(_ s: FlightStatusBadgeSize) -> Self { copy { $0.size = s } }
    /// Corner treatment — `.capsule` (default) or `.rounded` at the selector
    /// radius role.
    func shape(_ s: FlightStatusBadgeShape) -> Self { copy { $0.shape = s } }
    /// Opt-in gentle opacity pulse for urgent statuses (boarding, gate closing).
    /// Gated by `microAnimations` and the system Reduce Motion setting; never on
    /// by default.
    func pulses(_ on: Bool = true) -> Self { copy { $0.pulses = on } }
    /// Per-instance glyph override; `nil` hides the icon (≡ `showsIcon(false)`).
    func icon(_ systemName: String?) -> Self {
        copy { $0.iconSetting = systemName.map { .custom($0) } ?? .hidden }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("FlightStatusBadge") {
        for status in FlightStatus.allCases {
            PreviewCase(status.label) { FlightStatusBadge(status) }
        }
        PreviewCase("Solid + time") {
            FlightStatusBadge(.delayed).time("+35m").flightStatusBadgeStyle(.solid)
        }
        PreviewCase("No icon, custom label") {
            FlightStatusBadge(.boarding).showsIcon(false).label("Now boarding")
        }
        PreviewCase("Style ramp") {
            HStack(spacing: 8) {
                FlightStatusBadge(.onTime).flightStatusBadgeStyle(.soft)
                FlightStatusBadge(.onTime).flightStatusBadgeStyle(.solid)
                FlightStatusBadge(.onTime).flightStatusBadgeStyle(.outline)
                FlightStatusBadge(.onTime).flightStatusBadgeStyle(.dot)
            }
        }
        PreviewCase("Sizes") {
            HStack(spacing: 8) {
                FlightStatusBadge(.delayed).size(.small)
                FlightStatusBadge(.delayed).size(.medium)
                FlightStatusBadge(.delayed).size(.large)
            }
        }
        PreviewCase("Rounded + icon override") {
            FlightStatusBadge(.cancelled).shape(.rounded).icon("xmark.octagon.fill")
        }
        PreviewCase("Pulsing (urgency, Reduce-Motion gated)") {
            FlightStatusBadge(.boarding).pulses().flightStatusBadgeStyle(.solid)
        }
    }
}
