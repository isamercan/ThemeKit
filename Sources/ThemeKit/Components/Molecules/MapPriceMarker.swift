//
//  MapPriceMarker.swift
//  ThemeKit
//
//  Molecule. A price pin for a map — a rounded pill (with an optional downward
//  pointer) showing a price or label, with a selected state. Map-agnostic: drop it
//  into any `Map` annotation (MapKit not required). Token-bound.
//
//  ```swift
//  Annotation("", coordinate: c) { MapPriceMarker("₺1.250").selected(isActive) }
//  ```
//

import SwiftUI

/// Chroma: while the environment carries the default ``ChipStyle`` the pill
/// draws its own accent fill + border (pixel-identical to the pre-ChipStyle
/// look — the built-ins don't know the marker's accent tokens). A style set
/// with `.chipStyle(_:)` takes over the pill via `makeBody(configuration:)`.
/// The pointer triangle, soft shadow, and selection scale/spring are marker
/// anatomy, not chip chroma — they stay outside the style in both paths (the
/// pointer keeps the default accent-based fill even under a custom style).
public struct MapPriceMarker: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.chipStyle) private var environmentChipStyle

    private let text: String
    // Appearance — mutated only through the modifiers below (R2).
    private var isSelected = false
    private var accent: SemanticColor?
    private var systemImage: String?
    private var showsPointer = true

    public init(_ text: String) { self.text = text }   // R1

    private var accentBg: Color { (accent ?? .primary).solid }
    private var accentFg: Color { (accent ?? .primary).onSolid }
    private var bg: Color { isSelected ? accentBg : theme.background(.bgWhite) }
    private var fg: Color { isSelected ? accentFg : theme.text(.textPrimary) }

    public var body: some View {
        VStack(spacing: 0) {
            pill
                .themeShadow(.soft)
            if showsPointer {
                Triangle().fill(bg).frame(width: 10, height: 6)
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel(text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Default environment style → today's own chroma; custom style → its
    /// `makeBody`. `ChipSize` mapping: the compact 30pt pill maps to `.small`
    /// density (MapPriceMarker has no `ChipSize` of its own).
    @ViewBuilder private var pill: some View {
        if environmentChipStyle.isDefault {
            labelContent
                .foregroundStyle(fg)
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .frame(height: 30)
                .background(bg, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : theme.border(.borderPrimary), lineWidth: 1))
        } else {
            environmentChipStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(labelContent),
                isSelected: isSelected,
                isEnabled: isEnabled,
                size: .small))
        }
    }

    /// The pill's content (chroma-free): optional icon + price label.
    private var labelContent: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
            Text(text).textStyle(.labelSm700)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension MapPriceMarker {
    /// Selected/active state (accent fill + slight scale-up).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Token-fed accent for the selected fill (default primary).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// A leading SF Symbol (e.g. "heart.fill" for a favourite).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// Show the downward pointer under the pill (default on).
    func pointer(_ on: Bool) -> Self { copy { $0.showsPointer = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            MapPriceMarker("₺1.250")
            MapPriceMarker("₺2.100").selected()
            MapPriceMarker("Sold out").icon("xmark").pointer(false)
        }
        // Custom ChipStyle via the environment: the pill routes through
        // `SolidChipStyle.makeBody`; the pointer/shadow/scale stay the marker's.
        HStack(spacing: 16) {
            MapPriceMarker("₺1.250")
            MapPriceMarker("₺2.100").selected()
        }
        .chipStyle(.solid)
    }
    .padding()
}
