//
//  MapCallout.swift
//  ThemeKit
//
//  Organism. The info bubble shown when a map marker is tapped — a compact card
//  (thumbnail + name + subtitle + score + price + CTA) with an optional downward
//  pointer. Map-agnostic (no MapKit dependency); place it over your map. Token-bound.
//
//  ```swift
//  MapCallout(title: "Mirage Park Resort").image(url).score(8.9).price(9_600).onSelect { }
//  ```
//

import SwiftUI

public struct MapCallout: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let title: String
    // Content — mutated only through the modifiers below (R2).
    private var imageURL: URL?
    private var subtitle: String?
    private var score: Double?
    private var price: Decimal?
    private var currencyCode = "TRY"
    private var onSelect: (() -> Void)?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var showsPointer = true

    public init(title: String) { self.title = title }   // R1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous) }

    public var body: some View {
        VStack(spacing: 0) {
            card
            if showsPointer { Triangle().fill(theme.background(surfaceKey)).frame(width: 14, height: 8).themeShadow(.soft) }
        }
        .frame(maxWidth: 280)
    }

    private var card: some View {
        Button { onSelect?() } label: {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                if let imageURL {
                    RemoteImage(imageURL).contentMode(.fill).frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                    HStack(spacing: 6) {
                        if let score { ScoreBadge(score) }
                        if let price { PriceTag(price, currencyCode: currencyCode).size(.small).emphasis(.hero).fractionDigits(0) }
                    }
                }
                Spacer(minLength: 4)
                if onSelect != nil {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
                }
            }
            .padding(density.scale(Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(surfaceKey), in: shape)
            .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
            .themeShadow(.soft)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityElement(children: .combine)
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

public extension MapCallout {
    func image(_ url: URL?) -> Self { copy { $0.imageURL = url } }
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func score(_ value: Double?) -> Self { copy { $0.score = value } }
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    func onSelect(_ action: @escaping () -> Void) -> Self { copy { $0.onSelect = action } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func pointer(_ on: Bool) -> Self { copy { $0.showsPointer = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    MapCallout(title: "Mirage Park Resort")
        .subtitle("Kemer, Antalya").score(8.9).price(9_600).onSelect { }
        .padding()
}
