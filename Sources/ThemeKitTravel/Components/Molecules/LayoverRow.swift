//
//  LayoverRow.swift
//  ThemeKit
//
//  Molecule. A connection / layover indicator between two flight segments — a
//  centered pill ("2h 15m layover · Istanbul (IST)") flanked by dashed lines, with
//  an optional short/long-connection warning. Token-bound.
//
//  ```swift
//  LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").warning("Short connection")
//  ```
//

import SwiftUI
import ThemeKit

/// Presentation of a ``LayoverRow``: the stock centered `.line` label, a soft
/// `.pill` capsule sitting on the lines, or a full-width tinted `.banner` band.
public enum LayoverVariant: Sendable { case line, pill, banner }

/// Style of the flanking connector lines: `.dashed` (default), `.solid`, or
/// `.hidden` (lines removed; the label stays centered).
public enum LayoverLineStyle: Sendable { case dashed, solid, hidden }

public struct LayoverRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let duration: String
    private let airport: String
    // Appearance — mutated only through the modifiers below (R2).
    private var warningText: String?
    private var warningTone: SemanticColor?
    private var layoverLabel = String(themeKit: "layover")
    private var systemImage = "clock.arrow.2.circlepath"
    private var accent: SemanticColor?
    private var variant: LayoverVariant = .line
    private var lineStyleValue: LayoverLineStyle = .dashed

    public init(duration: String, airport: String) {   // R1
        self.duration = duration
        self.airport = airport
    }

    private var warningColor: Color { warningTone?.base ?? theme.foreground(.systemcolorsFgWarning) }
    private var accentBase: Color { warningText != nil ? warningColor : ((accent ?? .neutral).base) }
    /// Semantic tone that tints the pill / banner chrome.
    private var chromeTone: SemanticColor { warningText != nil ? (warningTone ?? .warning) : (accent ?? .neutral) }

    public var body: some View {
        VStack(spacing: 4) {
            switch variant {
            case .line:
                HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                    lines
                    labelContent
                    lines
                }
            case .pill:
                HStack(spacing: 0) {
                    lines
                    labelContent
                        .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
                        .padding(.vertical, Theme.SpacingKey.xs.value)
                        .background(chromeTone.soft, in: Capsule(style: .continuous))
                    lines
                }
            case .banner:
                labelContent
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
                    .padding(.horizontal, Theme.SpacingKey.sm.value)
                    .background(chromeTone.bg,
                                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            }
            if let warningText {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").textStyle(.overline500)
                    Text(warningText).textStyle(.overline400)
                }
                .foregroundStyle(warningColor)
            }
        }
    }

    private var labelContent: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).textStyle(.labelSm600).foregroundStyle(accentBase)
            Text("\(duration) \(layoverLabel) · \(airport)")
                .textStyle(.overline500).foregroundStyle(theme.text(.textSecondary)).fixedSize()
        }
    }

    @ViewBuilder private var lines: some View {
        switch lineStyleValue {
        case .dashed:
            Line().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1).frame(maxWidth: .infinity)
        case .solid:
            Line().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1))
                .frame(height: 1).frame(maxWidth: .infinity)
        case .hidden:
            Color.clear.frame(height: 1).frame(maxWidth: .infinity)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.width, y: rect.midY)) }
        }
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
    /// Presentation: the stock centered `.line` label (default), a soft `.pill`
    /// capsule on the lines, or a full-width tinted `.banner` band.
    func variant(_ v: LayoverVariant) -> Self { copy { $0.variant = v } }
    /// Style of the flanking connector lines — `.dashed` (default), `.solid`,
    /// or `.hidden`.
    func lineStyle(_ s: LayoverLineStyle) -> Self { copy { $0.lineStyleValue = s } }
    /// Localise the "layover" word (English default).
    func layoverLabel(_ text: String) -> Self { copy { $0.layoverLabel = text } }
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
        PreviewCase("Pill") { LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").variant(.pill).accent(.info) }
        PreviewCase("Banner") { LayoverRow(duration: "5h 30m", airport: "Frankfurt (FRA)").variant(.banner).accent(.info) }
        PreviewCase("Solid + hidden lines") {
            VStack(spacing: 12) {
                LayoverRow(duration: "1h 05m", airport: "Vienna (VIE)").lineStyle(.solid)
                LayoverRow(duration: "1h 05m", airport: "Vienna (VIE)").lineStyle(.hidden)
            }
        }
        PreviewCase("Warning tone (error)") {
            LayoverRow(duration: "0h 35m", airport: "Ankara (ESB)")
                .variant(.pill)
                .warning("Very short connection — 35 min", tone: .error)
        }
    }
}
