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
#if canImport(UIKit)
import UIKit
private typealias SnapshotImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias SnapshotImage = NSImage
#endif

/// A token-bound location preview card.
///
/// ```swift
/// LocationCard(title: "Marina Bay Hotel", coordinate: coord)
///     .subtitle("Kordon Cd. No:12, İzmir").distance("1.2 km to center") { openMaps() }
/// ```
/// An extra point of interest to pin on a ``LocationCard``.
public struct LocationPin: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let coordinate: CLLocationCoordinate2D
    public init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
    }
    public init(title: String, latitude: Double, longitude: Double) {
        self.init(title: title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
}

public struct LocationCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @State private var snapshotImage: SnapshotImage?

    // Required content (R1).
    private let title: String
    private let coordinate: CLLocationCoordinate2D
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var subtitle: String?
    private var distance: String?
    private var mapHeight: CGFloat = 140
    private var spanMeters: CLLocationDistance = 800
    private var onTap: (() -> Void)?
    private var pois: [LocationPin] = []
    private var showsDirections: Bool = false
    private var onDirectionsHandler: (() -> Void)?
    private var useSnapshot: Bool = false

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
            mapPreview

            HStack(alignment: .bottom) {
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
                Spacer()
                if showsDirections {
                    Button {
                        if let onDirectionsHandler { onDirectionsHandler() } else { openInMaps() }
                    } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .textStyle(.labelSm600)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.foreground(.fgHero))
                    .accessibilityLabel("Directions to \(title)")
                }
            }
            .padding(density.scale(Theme.SpacingKey.md.value))
        }
        .background(theme.background(surfaceKey))
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    @ViewBuilder private var mapPreview: some View {
        if useSnapshot {
            ZStack {
                if let snapshotImage {
                    #if canImport(UIKit)
                    Image(uiImage: snapshotImage).resizable().scaledToFill()
                    #elseif canImport(AppKit)
                    Image(nsImage: snapshotImage).resizable().scaledToFill()
                    #endif
                } else {
                    Rectangle().fill(theme.background(.bgSecondary)).overlay(ProgressView())
                }
                Image(systemName: "mappin").font(.title2)
                    .foregroundStyle(theme.foreground(.fgHero)).shadow(radius: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: mapHeight)
            .clipped()
            .task(id: snapshotKey) { await generateSnapshot() }
        } else {
            Map(initialPosition: .region(region)) {
                Marker(title, coordinate: coordinate)
                ForEach(pois) { pin in
                    Marker(pin.title, coordinate: pin.coordinate).tint(theme.text(.textSecondary))
                }
            }
            .frame(height: mapHeight)
            .allowsHitTesting(false)
        }
    }

    private var snapshotKey: String {
        "\(coordinate.latitude),\(coordinate.longitude),\(spanMeters),\(mapHeight)"
    }

    @MainActor private func generateSnapshot() async {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 800, height: max(1, mapHeight * 3))
        let snapshotter = MKMapSnapshotter(options: options)
        if let snapshot = try? await snapshotter.start() {
            snapshotImage = snapshot.image
        }
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
    }

    /// Opens the location in Apple Maps with driving directions.
    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LocationCard {
    /// Surface fill (background token key, default `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
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
    /// Extra points of interest pinned on the map (nearby landmarks, transit…).
    func pois(_ pins: [LocationPin]) -> Self { copy { $0.pois = pins } }
    /// Shows a "Directions" button. Without `.onDirections`, it opens Apple Maps.
    func directions(_ on: Bool = true) -> Self { copy { $0.showsDirections = on } }
    /// Custom handler for the Directions button (overrides the default Apple Maps launch).
    func onDirections(_ action: @escaping () -> Void) -> Self { copy { $0.showsDirections = true; $0.onDirectionsHandler = action } }
    /// Renders a static MKMapSnapshotter image instead of a live `Map` — far cheaper
    /// in long scrolling lists (a live Map per row is expensive).
    func snapshot(_ on: Bool = true) -> Self { copy { $0.useSnapshot = on } }

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
