//
//  LayoverRow.swift
//  ThemeKit
//
//  Molecule. A connection / layover indicator between two flight segments — a
//  centered pill ("2h 15m layover · Istanbul (IST)") flanked by dashed lines, with
//  an optional short/long-connection warning. Presentation is style-driven
//  (``LayoverRowStyle``, ADR-0004) — set once per screen via
//  `.layoverRowStyle(_:)`. Token-bound.
//
//  ```swift
//  LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").warning("Short connection")
//      .layoverRowStyle(.pill)   // .line (default) / .pill / .banner
//  ```
//

import SwiftUI
import ThemeKit

/// Presentation of a ``LayoverRow`` — superseded by ``LayoverRowStyle`` (each
/// case maps 1:1 to a preset — `.line`/`.pill`/`.banner`); kept for source
/// compatibility until the next major, together with the deprecated
/// ``LayoverRow/variant(_:)`` modifier.
public enum LayoverVariant: Sendable { case line, pill, banner }

/// Style of the flanking connector lines: `.dashed` (default), `.solid`, or
/// `.hidden` (lines removed; the label stays centered). Stays a knob — it
/// composes with every ``LayoverRowStyle`` preset rather than being one.
public enum LayoverLineStyle: Sendable { case dashed, solid, hidden }

public struct LayoverRow: View {
    @Environment(\.layoverRowStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale

    private let duration: String
    private let airport: String
    // Appearance — mutated only through the modifiers below (R2).
    private var warningText: String?
    private var warningTone: SemanticColor?
    private var layoverLabelOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var layoverLabel: String { layoverLabelOverride ?? String(themeKit: "layover") }
    private var systemImage = "clock.arrow.2.circlepath"
    private var accent: SemanticColor?
    private var lineStyleValue: LayoverLineStyle = .dashed
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's `.layoverRowStyle(_:)`
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyLayoverRowStyle?

    public init(duration: String, airport: String) {   // R1
        self.duration = duration
        self.airport = airport
    }

    public var body: some View {
        let configuration = LayoverRowConfiguration(
            duration: duration, airport: airport,
            warningText: warningText, warningTone: warningTone,
            layoverLabel: layoverLabel, systemImage: systemImage,
            lineStyle: lineStyleValue, accent: accent,
            density: density, locale: locale
        )
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary(configuration))
    }

    private func accessibilitySummary(_ configuration: LayoverRowConfiguration) -> String {
        guard let warningText else { return configuration.label }
        return "\(configuration.label). \(warningText)"
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LayoverRow {
    /// A short/long-connection warning shown below (in warning colour).
    func warning(_ text: String?) -> Self { copy { $0.warningText = text } }
    /// A short/long-connection warning shown below, in a custom semantic tone
    /// (default `.warning`) — the tone also tints the icon and pill/banner chrome.
    func warning(_ text: String?, tone: SemanticColor = .warning) -> Self {
        copy { $0.warningText = text; $0.warningTone = tone }
    }
    /// Presentation — superseded by the style axis: prefer
    /// `.layoverRowStyle(.line/.pill/.banner)`, settable once per screen via
    /// the environment. This modifier keeps working and, when called, wins
    /// over an ancestor's environment style.
    @available(*, deprecated, message: "Use .layoverRowStyle(.line/.pill/.banner) instead")
    func variant(_ v: LayoverVariant) -> Self {
        copy {
            switch v {
            case .line: $0.explicitStyle = AnyLayoverRowStyle(LineLayoverRowStyle())
            case .pill: $0.explicitStyle = AnyLayoverRowStyle(PillLayoverRowStyle())
            case .banner: $0.explicitStyle = AnyLayoverRowStyle(BannerLayoverRowStyle())
            }
        }
    }
    /// Style of the flanking connector lines — `.dashed` (default), `.solid`,
    /// or `.hidden`.
    func lineStyle(_ s: LayoverLineStyle) -> Self { copy { $0.lineStyleValue = s } }
    /// Localise the "layover" word (English default).
    func layoverLabel(_ text: String) -> Self { copy { $0.layoverLabelOverride = text } }
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("LayoverRow") {
        PreviewCase("Default") { LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)") }
        PreviewCase("Warning") { LayoverRow(duration: "0h 45m", airport: "Ankara (ESB)").warning("Short connection — 45 min") }
        PreviewCase("Accent + icon") { LayoverRow(duration: "5h 30m", airport: "Frankfurt (FRA)").accent(.info).icon("airplane.arrival") }
        PreviewCase("Pill") {
            LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").accent(.info).layoverRowStyle(.pill)
        }
        PreviewCase("Banner") {
            LayoverRow(duration: "5h 30m", airport: "Frankfurt (FRA)").accent(.info).layoverRowStyle(.banner)
        }
        PreviewCase("Solid + hidden lines") {
            VStack(spacing: 12) {
                LayoverRow(duration: "1h 05m", airport: "Vienna (VIE)").lineStyle(.solid)
                LayoverRow(duration: "1h 05m", airport: "Vienna (VIE)").lineStyle(.hidden)
            }
        }
        PreviewCase("Warning tone (error)") {
            LayoverRow(duration: "0h 35m", airport: "Ankara (ESB)")
                .warning("Very short connection — 35 min", tone: .error)
                .layoverRowStyle(.pill)
        }
        PreviewCase("Deprecated .variant(_:) still works") {
            LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").variant(.banner).accent(.success)
        }
    }
}
