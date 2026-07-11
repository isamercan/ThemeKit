//
//  FlightStatusBadge.swift
//  ThemeKit
//
//  Atom. A flight status pill — on-time / boarding / delayed / gate-closed /
//  departed / arrived / cancelled, each with a token-fed semantic colour and icon,
//  plus an optional time. Token-bound.
//
//  ```swift
//  FlightStatusBadge(.delayed).time("+35m")
//  ```
//

import SwiftUI

public struct FlightStatusBadge: View {
    @Environment(\.theme) private var theme

    private let status: FlightStatus
    // Appearance — mutated only through the modifiers below (R2).
    private var time: String?
    private var customLabel: String?
    private var showsIcon = true
    private var solid = false

    public init(_ status: FlightStatus) { self.status = status }   // R1

    private var color: SemanticColor { status.semantic }

    public var body: some View {
        HStack(spacing: 4) {
            if showsIcon { Image(systemName: status.icon).font(.system(size: 11, weight: .semibold)) }
            Text(customLabel ?? status.label).textStyle(.labelSm700)
            if let time { Text(time).textStyle(.labelSm600).opacity(0.9) }
        }
        .foregroundStyle(solid ? color.onSolid : color.base)
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: 24)
        .background(solid ? color.solid : color.bg, in: Capsule())
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
    /// Solid fill (vs the default soft tint).
    func solid(_ on: Bool = true) -> Self { copy { $0.solid = on } }

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
            FlightStatusBadge(.delayed).time("+35m").solid()
        }
        PreviewCase("No icon, custom label") {
            FlightStatusBadge(.boarding).showsIcon(false).label("Now boarding")
        }
    }
}
