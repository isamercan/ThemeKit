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

public struct LayoverRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let duration: String
    private let airport: String
    // Appearance — mutated only through the modifiers below (R2).
    private var warningText: String?
    private var layoverLabel = "layover"
    private var systemImage = "clock.arrow.2.circlepath"
    private var accent: SemanticColor?

    public init(duration: String, airport: String) {   // R1
        self.duration = duration
        self.airport = airport
    }

    private var accentBase: Color { warningText != nil ? theme.foreground(.systemcolorsFgWarning) : ((accent ?? .neutral).base) }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                dashes
                HStack(spacing: 5) {
                    Image(systemName: systemImage).font(.system(size: 11)).foregroundStyle(accentBase)
                    Text("\(duration) \(layoverLabel) · \(airport)")
                        .textStyle(.overline500).foregroundStyle(theme.text(.textSecondary)).fixedSize()
                }
                dashes
            }
            if let warningText {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text(warningText).textStyle(.overline400)
                }
                .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
            }
        }
    }

    private var dashes: some View {
        Line().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1).frame(maxWidth: .infinity)
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
    }
}
