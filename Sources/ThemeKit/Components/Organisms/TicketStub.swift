//
//  TicketStub.swift
//  ThemeKit
//
//  A boarding-pass / ticket container — a rounded surface with two semicircular
//  notches carved out of the side edges at a tear line, an optional dashed
//  perforation, and a `content` + `stub` slot split by that tear. Token-bound:
//  the surface, notch and perforation all come from the theme. The notches are
//  cut with a `destinationOut` composite, so they read correctly on any
//  background (solid, gradient or image).
//

import SwiftUI

/// A token-bound ticket / boarding-pass surface.
///
/// ```swift
/// TicketStub {
///     FlightCard(airline: "Emirates", from: "JFK", to: "DPS", departure: dep, arrival: arr)
/// }
/// .stub {
///     Barcode("BID12025BKG").height(52).showsValue()
/// }
/// .notchRadius(12).elevation(.elevated)
/// ```
public struct TicketStub<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    // Appearance/state — mutated only through the modifiers below (R2). Colours,
    // radius and padding are theme tokens (never raw values); notch is a bespoke geometry.
    private var stubSlot: AnyView?
    private var showsPerforation = true
    private var notchRadius: CGFloat = 10
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .soft
    private var surfaceKey: Theme.BackgroundColorKey = .bgElevatorPrimary
    private var dashKey: Theme.BorderColorKey = .borderPrimary
    private var paddingKey: Theme.SpacingKey = .md

    private var cornerRadius: CGFloat { radiusRole.value }
    private var padding: CGFloat { paddingKey.value }

    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {   // R1 — content
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(density.scale(padding))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let stubSlot {
                // A zero-height marker whose center is the tear line, reported up
                // so the background can carve its notches at exactly this y.
                Color.clear.frame(height: 0)
                    .anchorPreference(key: TearAnchorKey.self, value: .center) { $0 }
                stubSlot
                    .padding(density.scale(padding))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .backgroundPreferenceValue(TearAnchorKey.self) { anchor in
            GeometryReader { proxy in
                surface(tearY: anchor.map { proxy[$0].y }, size: proxy.size)
            }
        }
    }

    private func surface(tearY: CGFloat?, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape
                .fill(theme.background(surfaceKey))
                .overlay { if let tearY { notches(tearY: tearY, width: size.width) } }
                .compositingGroup()                       // scope the destinationOut cut
                .modifier(TicketElevation(elevation: elevation))
            if showsPerforation, let tearY {
                dashedLine(y: tearY, width: size.width)
            }
        }
    }

    /// Two circles centered on the side edges — half of each sits outside the card,
    /// so `destinationOut` erases a clean semicircular notch on each edge.
    private func notches(tearY: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Circle().frame(width: notchRadius * 2, height: notchRadius * 2).position(x: 0, y: tearY)
            Circle().frame(width: notchRadius * 2, height: notchRadius * 2).position(x: width, y: tearY)
        }
        .blendMode(.destinationOut)
    }

    private func dashedLine(y: CGFloat, width: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: notchRadius + 6, y: y))
            p.addLine(to: CGPoint(x: width - notchRadius - 6, y: y))
        }
        .stroke(theme.border(dashKey), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TicketStub {
    /// The detachable stub below the tear line — a barcode, QR, seat, gate…
    func stub<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.stubSlot = AnyView(content()) } }
    /// Draw the dashed perforation across the tear line (default on).
    func perforation(_ on: Bool = true) -> Self { copy { $0.showsPerforation = on } }
    /// Radius of the side notches (default 10).
    func notchRadius(_ r: CGFloat) -> Self { copy { $0.notchRadius = max(0, r) } }
    /// Outer corner radius (radius role token, default `.box`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Surface elevation: none / soft / elevated.
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Surface fill (background token key, default `.bgElevatorPrimary`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Perforation dash colour (border token key, default `.borderPrimary`).
    func dashColor(_ key: Theme.BorderColorKey) -> Self { copy { $0.dashKey = key } }
    /// Inner content padding (spacing token key, default `.md`).
    func contentPadding(_ key: Theme.SpacingKey) -> Self { copy { $0.paddingKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Reports the tear-line position up to the surface so the notches align to the
/// boundary between `content` and `stub`, whatever their heights.
private struct TearAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

private struct TicketElevation: ViewModifier {
    let elevation: CardElevation
    @ViewBuilder func body(content: Content) -> some View {
        switch elevation {
        case .none: content
        case .soft: content.themeShadow(.soft)
        case .elevated: content.themeShadow(.elevated)
        }
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    ScrollView {
        VStack(spacing: 24) {
            TicketStub {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EMIRATES").textStyle(.labelMd700)
                    HStack {
                        VStack(alignment: .leading) { Text("09:00").textStyle(.headingSm); Text("JFK").textStyle(.labelSm600) }
                        Spacer()
                        Image(systemName: "airplane").foregroundStyle(theme.foreground(.fgHero))
                        Spacer()
                        VStack(alignment: .trailing) { Text("08:00").textStyle(.headingSm); Text("DPS").textStyle(.labelSm600) }
                    }
                }
            }
            .stub {
                HStack { Text("Booking").textStyle(.bodySm400); Spacer(); Text("BID12025BKG").textStyle(.labelSm700) }
            }
            .elevation(.elevated)
        }
        .padding()
    }
    .background(theme.background(.bgSecondary))
}
