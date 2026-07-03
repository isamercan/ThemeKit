//
//  LocationCard.swift
//  ThemeKit
//
//  A map preview + location info card — a non-interactive MapKit snapshot with a pin,
//  a title, an address and an optional distance. Token-bound (info + surface). MapKit
//  is a system framework, so this stays in the dependency-free core.
//

import SwiftUI
import MapKit

/// A token-bound location preview card.
///
/// ```swift
/// LocationCard(title: "Marina Bay Hotel", coordinate: coord)
///     .subtitle("Kordon Cd. No:12, İzmir").distance("1.2 km to center") { openMaps() }
/// ```
public struct LocationCard: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let title: String
    private let coordinate: CLLocationCoordinate2D
    // Appearance/state — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var distance: String?
    private var mapHeight: CGFloat = 140
    private var spanMeters: CLLocationDistance = 800
    private var onTap: (() -> Void)?

    public init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
    }

    /// Convenience — build from latitude/longitude without importing CoreLocation.
    public init(title: String, latitude: Double, longitude: Double) {
        self.init(title: title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(region)) {
                Marker(title, coordinate: coordinate)
            }
            .frame(height: mapHeight)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                if let subtitle {
                    Label { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)) }
                    icon: { Image(systemName: "mappin.and.ellipse").foregroundStyle(theme.foreground(.fgHero)) }
                        .labelStyle(.titleAndIcon)
                }
                if let distance {
                    Label { Text(distance).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
                    icon: { Image(systemName: "location.fill").foregroundStyle(theme.text(.textTertiary)) }
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(Theme.SpacingKey.md.value)
        }
        .background(theme.background(.bgElevatorPrimary))
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LocationCard {
    /// An address line under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// A distance line, e.g. `"1.2 km to center"`.
    func distance(_ text: String?) -> Self { copy { $0.distance = text } }
    /// Map preview height in points (default 140).
    func mapHeight(_ height: CGFloat) -> Self { copy { $0.mapHeight = height } }
    /// The map's visible span in meters (default 800).
    func spanMeters(_ meters: CLLocationDistance) -> Self { copy { $0.spanMeters = meters } }
    /// Called when the card is tapped (e.g. open in Maps).
    func onTap(_ action: (() -> Void)?) -> Self { copy { $0.onTap = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    LocationCard(title: "Marina Bay Hotel", coordinate: CLLocationCoordinate2D(latitude: 38.4237, longitude: 27.1428))
        .subtitle("Kordon Cd. No:12, İzmir")
        .distance("1.2 km to center")
        .padding()
}
