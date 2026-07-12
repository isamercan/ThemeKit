//
//  LayoverRowStyle.swift
//  ThemeKit
//
//  The styling hook for ``LayoverRow`` — promotes the former ``LayoverVariant``
//  enum (ADR-0004) so the connector's presentation is a swappable style,
//  settable once per screen via the environment. Three built-ins map 1:1 to
//  the old variant cases:
//
//    .line    the stock centered label flanked by connector lines — default
//    .pill    the label sits in a soft, tone-tinted capsule on the lines
//    .banner  a full-width tone-tinted band, no flanking lines
//
//      LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)")
//          .warning("Short connection")
//          .layoverRowStyle(.pill)
//
//  Component style arranges content; the token theme colors everything. The
//  flanking connector is drawn with a horizontal `Path`, which is symmetric
//  under mirroring, so no `.flipsForRightToLeftLayoutDirection(true)` is
//  needed (unlike an asymmetric arc/curve).
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``LayoverRowStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no warning → no warning line, no space reserved).
public struct LayoverRowConfiguration {
    /// Layover duration, already formatted by the caller ("2h 15m").
    public let duration: String
    /// Airport label, e.g. "Istanbul (IST)".
    public let airport: String
    /// A short/long-connection warning shown below; `nil` hides the line.
    public let warningText: String?
    /// The warning's semantic tone (`.warning(_:tone:)`); resolved against
    /// ``warningColor(_:)`` — falls back to `.warning` chrome, the theme's
    /// warning foreground for the raw color.
    public let warningTone: SemanticColor?
    /// Localised "layover" word (English default), re-resolved every body
    /// pass so a live language switch is never frozen at init.
    public let layoverLabel: String
    /// SF Symbol for the connector's centered glyph (`.icon(_:)`).
    public let systemImage: String
    /// Style of the flanking connector lines — `.dashed` (default), `.solid`,
    /// or `.hidden`. Stays a knob (not a preset): it composes with every style.
    public let lineStyle: LayoverLineStyle
    /// Brand-chrome accent (`.accent(_:)`), or `nil` for the neutral default.
    public let accent: SemanticColor?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component. No dates/numbers
    /// are formatted here today; carried for additive-safe future use and so
    /// custom styles can format against the caller's locale.
    public let locale: Locale

    /// "2h 15m layover · Istanbul (IST)" — the connector's centered label.
    public var label: String { "\(duration) \(layoverLabel) · \(airport)" }
    /// `true` when a connection warning was set.
    public var hasWarning: Bool { warningText != nil }
    /// The warning's resolved color — explicit tone, else the theme's warning
    /// foreground (the value the built-ins hardcoded before the tone axis
    /// existed).
    public func warningColor(_ theme: Theme) -> Color {
        warningTone?.base ?? theme.foreground(.systemcolorsFgWarning)
    }
    /// The connector icon/label tint: the warning color while warning, else
    /// the accent's base (neutral by default).
    public func accentColor(_ theme: Theme) -> Color {
        hasWarning ? warningColor(theme) : (accent ?? .neutral).base
    }
    /// Semantic tone that tints the pill / banner chrome.
    public var chromeTone: SemanticColor { hasWarning ? (warningTone ?? .warning) : (accent ?? .neutral) }
    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the row.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `LayoverRow`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's connector data. Set one with `.layoverRowStyle(_:)`;
/// the default is ``LineLayoverRowStyle``.
public protocol LayoverRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: LayoverRowConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// A flanking connector segment shared by `.line` and `.pill` — `.dashed`
/// (default), `.solid`, or `.hidden` (an invisible spacer, keeping the label
/// centered).
private struct LayoverRowConnectorLine: View {
    @Environment(\.theme) private var theme
    let lineStyle: LayoverLineStyle

    var body: some View {
        switch lineStyle {
        case .dashed:
            LayoverRowConnectorShape()
                .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1).frame(maxWidth: .infinity)
        case .solid:
            LayoverRowConnectorShape()
                .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1))
                .frame(height: 1).frame(maxWidth: .infinity)
        case .hidden:
            Color.clear.frame(height: 1).frame(maxWidth: .infinity)
        }
    }
}

/// A single horizontal segment — symmetric under mirroring, so no RTL flip
/// is required.
private struct LayoverRowConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.width, y: rect.midY)) }
    }
}

/// Icon + "2h 15m layover · Istanbul (IST)" — the connector's centered label,
/// shared verbatim (raw `Image` + `.textStyle`, matching the pre-style render
/// exactly — `Icon`'s fixed size ramp has no 12pt-semibold tier) by every
/// built-in.
private struct LayoverRowLabel: View {
    @Environment(\.theme) private var theme
    let configuration: LayoverRowConfiguration

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: configuration.systemImage)
                .textStyle(.labelSm600)
                .foregroundStyle(configuration.accentColor(theme))
            Text(configuration.label)
                .textStyle(.overline500).foregroundStyle(theme.text(.textSecondary)).fixedSize()
        }
    }
}

/// The short/long-connection warning line shown below the connector, in every
/// built-in — verbatim raw `Image` + `.textStyle`, same reasoning as
/// ``LayoverRowLabel``.
private struct LayoverRowWarningLine: View {
    @Environment(\.theme) private var theme
    let configuration: LayoverRowConfiguration

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill").textStyle(.overline500)
            if let warningText = configuration.warningText {
                Text(warningText).textStyle(.overline400)
            }
        }
        .foregroundStyle(configuration.warningColor(theme))
    }
}

// MARK: - .line (default)

/// Today's ``LayoverRow`` look, extracted verbatim: the centered label
/// flanked by connector lines on both sides.
public struct LineLayoverRowStyle: LayoverRowStyle {
    public init() {}
    public func makeBody(configuration: LayoverRowConfiguration) -> some View {
        LineLayoverRowChrome(configuration: configuration)
    }
}

private struct LineLayoverRowChrome: View {
    let configuration: LayoverRowConfiguration

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: configuration.spacing(.sm)) {
                LayoverRowConnectorLine(lineStyle: configuration.lineStyle)
                LayoverRowLabel(configuration: configuration)
                LayoverRowConnectorLine(lineStyle: configuration.lineStyle)
            }
            if configuration.hasWarning { LayoverRowWarningLine(configuration: configuration) }
        }
    }
}

// MARK: - .pill

/// The label sits in a soft, tone-tinted capsule on the connector lines.
public struct PillLayoverRowStyle: LayoverRowStyle {
    public init() {}
    public func makeBody(configuration: LayoverRowConfiguration) -> some View {
        PillLayoverRowChrome(configuration: configuration)
    }
}

private struct PillLayoverRowChrome: View {
    let configuration: LayoverRowConfiguration

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                LayoverRowConnectorLine(lineStyle: configuration.lineStyle)
                LayoverRowLabel(configuration: configuration)
                    .padding(.horizontal, configuration.spacing(.sm))
                    .padding(.vertical, Theme.SpacingKey.xs.value)
                    .background(configuration.chromeTone.soft, in: Capsule(style: .continuous))
                LayoverRowConnectorLine(lineStyle: configuration.lineStyle)
            }
            if configuration.hasWarning { LayoverRowWarningLine(configuration: configuration) }
        }
    }
}

// MARK: - .banner

/// A full-width, tone-tinted band — no flanking connector lines.
public struct BannerLayoverRowStyle: LayoverRowStyle {
    public init() {}
    public func makeBody(configuration: LayoverRowConfiguration) -> some View {
        BannerLayoverRowChrome(configuration: configuration)
    }
}

private struct BannerLayoverRowChrome: View {
    let configuration: LayoverRowConfiguration

    var body: some View {
        VStack(spacing: 4) {
            LayoverRowLabel(configuration: configuration)
                .frame(maxWidth: .infinity)
                .padding(.vertical, configuration.spacing(.sm))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .background(configuration.chromeTone.bg,
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            if configuration.hasWarning { LayoverRowWarningLine(configuration: configuration) }
        }
    }
}

// MARK: - Static accessors

public extension LayoverRowStyle where Self == LineLayoverRowStyle {
    /// The centered label flanked by connector lines. The default.
    static var line: LineLayoverRowStyle { LineLayoverRowStyle() }
}
public extension LayoverRowStyle where Self == PillLayoverRowStyle {
    /// The label in a soft, tone-tinted capsule sitting on the connector lines.
    static var pill: PillLayoverRowStyle { PillLayoverRowStyle() }
}
public extension LayoverRowStyle where Self == BannerLayoverRowStyle {
    /// A full-width, tone-tinted band — no flanking lines.
    static var banner: BannerLayoverRowStyle { BannerLayoverRowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyLayoverRowStyle: LayoverRowStyle {
    private let _makeBody: @MainActor (LayoverRowConfiguration) -> AnyView
    init<S: LayoverRowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: LayoverRowConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct LayoverRowStyleKey: EnvironmentKey {
    static let defaultValue = AnyLayoverRowStyle(LineLayoverRowStyle())
}

extension EnvironmentValues {
    var layoverRowStyle: AnyLayoverRowStyle {
        get { self[LayoverRowStyleKey.self] }
        set { self[LayoverRowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``LayoverRowStyle`` for `LayoverRow`s in this view and its
    /// descendants — one itinerary screen can restyle every connection at once.
    func layoverRowStyle<S: LayoverRowStyle>(_ style: sending S) -> some View {
        environment(\.layoverRowStyle, AnyLayoverRowStyle(style))
    }
}

// MARK: - Previews

/// Proves external implementability: a compact one-line summary built purely
/// on the public configuration + theme tokens — no lines, no chrome.
private struct MinimalLayoverRowStyle: LayoverRowStyle {
    func makeBody(configuration: LayoverRowConfiguration) -> some View {
        MinimalLayoverRowChrome(configuration: configuration)
    }

    private struct MinimalLayoverRowChrome: View {
        @Environment(\.theme) private var theme
        let configuration: LayoverRowConfiguration

        var body: some View {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: configuration.systemImage).size(.xs).color(configuration.accentColor(theme))
                Text(configuration.label).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
                if configuration.hasWarning {
                    Icon(systemName: "exclamationmark.triangle.fill")
                        .size(.xs)
                        .color(configuration.warningColor(theme))
                }
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(theme.background(.bgSecondaryLight), in: Capsule(style: .continuous))
        }
    }
}

#Preview("LayoverRowStyle — presets × light/dark") {
    PreviewMatrix("LayoverRowStyle") {
        PreviewCase("Line (default)") {
            LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)")
        }
        PreviewCase("Line · warning") {
            LayoverRow(duration: "0h 45m", airport: "Ankara (ESB)")
                .warning("Short connection — 45 min")
        }
        PreviewCase("Pill") {
            LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)")
                .accent(.info)
                .layoverRowStyle(.pill)
        }
        PreviewCase("Banner") {
            LayoverRow(duration: "5h 30m", airport: "Frankfurt (FRA)")
                .accent(.info)
                .layoverRowStyle(.banner)
        }
        PreviewCase("Banner · warning tone (error)") {
            LayoverRow(duration: "0h 35m", airport: "Ankara (ESB)")
                .warning("Very short connection — 35 min", tone: .error)
                .layoverRowStyle(.banner)
        }
        PreviewCase("Custom (in-preview)") {
            LayoverRow(duration: "1h 05m", airport: "Vienna (VIE)")
                .layoverRowStyle(MinimalLayoverRowStyle())
        }
    }
}
