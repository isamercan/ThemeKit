//
//  LocationCard.swift
//  ThemeKit
//
//  A map preview + location info card — a non-interactive MapKit snapshot with a pin,
//  a title, an address and an optional distance. Token-bound (info + surface). MapKit
//  is a system framework, so this stays in the dependency-free core.
//
//  The outer shell (surface fill, corner clipping, border, elevation shadow) is drawn
//  by the active `CardStyle` from the environment — `.surface()` feeds the
//  `CardStyleConfiguration`, so `.cardStyle(_:)` can swap in a completely different
//  shell. `.media {}` replaces the map/snapshot region; `.overlay {}` layers over it.
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
    @Environment(\.cardStyle) private var cardStyle
    @State private var snapshotImage: SnapshotImage?

    // Required content (R1).
    private let title: String
    private let coordinate: CLLocationCoordinate2D
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var subtitle: String?
    private var distance: String?
    private var mapHeight: CGFloat = 140
    private var spanMeters: CLLocationDistance = 800
    private var onTap: (() -> Void)?
    private var pois: [LocationPin] = []
    private var showsDirections: Bool = false
    private var onDirectionsHandler: (() -> Void)?
    private var useSnapshot: Bool = false
    private var mediaSlot: AnyView?
    private var overlaySlot: AnyView?

    public init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
    }

    /// Convenience — build from latitude/longitude without importing CoreLocation.
    public init(title: String, latitude: Double, longitude: Double) {
        self.init(title: title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        // `.none` elevation reproduces today's flat look: the default style's 1pt
        // hairline border and no shadow.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: .none,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: .box))
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaArea

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
                        Label(String(themeKit: "Directions"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .textStyle(.labelSm600)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.foreground(.fgHero))
                    .accessibilityLabel(String(themeKit: "Directions to \(title)"))
                }
            }
            .padding(density.scale(Theme.SpacingKey.md.value))
        }
    }

    // MARK: Media

    /// The media region: the `.media {}` slot when set, else the built-in map, with
    /// the custom overlay layered on top.
    private var mediaArea: some View {
        media
            .frame(maxWidth: .infinity)
            .frame(height: mapHeight)
            .clipped()
            .overlay { if let overlaySlot { overlaySlot } }
    }

    @ViewBuilder private var media: some View {
        if let mediaSlot { mediaSlot } else { mapPreview }
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
    /// Surface fill (background token key, default `.bgBase`).
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
    /// Replace the map/snapshot region with custom media content (a photo, a custom
    /// map renderer…). The view is sized to `mapHeight` and clipped. Omit to keep
    /// the built-in map preview.
    func media<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.mediaSlot = AnyView(content()) } }
    /// Layer custom content over the media region (a scrim, a "tap to expand" hint…).
    func overlay<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.overlaySlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let coordinate = CLLocationCoordinate2D(latitude: 38.4237, longitude: 27.1428)
    PreviewMatrix("LocationCard") {
        PreviewCase("Default") {
            LocationCard(title: "Marina Bay Hotel", coordinate: coordinate)
                .subtitle("Kordon Cd. No:12, İzmir")
                .distance("1.2 km to center")
        }
        PreviewCase("Directions + POI pins") {
            LocationCard(title: "Marina Bay Hotel", coordinate: coordinate)
                .subtitle("Kordon Cd. No:12, İzmir")
                .directions()
                .pois([LocationPin(title: "Clock Tower", latitude: 38.4189, longitude: 27.1287)])
        }
        PreviewCase("Snapshot mode (static image)") {
            LocationCard(title: "Marina Bay Hotel", coordinate: coordinate)
                .subtitle("Kordon Cd. No:12, İzmir")
                .snapshot()
        }
    }
}

#Preview("Outlined style + media slot") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            LocationCard(title: "Marina Bay Hotel", latitude: 38.4237, longitude: 27.1428)
                .media {
                    LinearGradient(colors: [theme.background(.bgHero), theme.background(.bgTurquoise)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .overlay {
                    Text("Map preview unavailable").textStyle(.labelSm700)
                        .foregroundStyle(theme.text(.textSecondaryInverse))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(MediaScrim.solid, in: Capsule())
                }
                .subtitle("Kordon Cd. No:12, İzmir")
                .distance("1.2 km to center")
                .cardStyle(.outlined)
                .padding()
        }
    }
    return Demo()
}
