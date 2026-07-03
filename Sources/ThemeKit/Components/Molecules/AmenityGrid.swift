//
//  AmenityGrid.swift
//  ThemeKit
//
//  A grid of icon + label amenities (wifi · pool · breakfast). Token-bound: the icon
//  tint comes from the theme's accent, so it re-skins with the brand.
//

import SwiftUI

/// One amenity — an SF Symbol and a label.
public struct Amenity: Identifiable, Sendable, Hashable {
    public let id: String
    public let systemImage: String
    public let label: String

    public init(_ label: String, systemImage: String) {
        self.id = label
        self.label = label
        self.systemImage = systemImage
    }
}

public enum AmenitySize {
    case small, medium, large

    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        }
    }
    var textStyle: TextStyle {
        switch self {
        case .small: return .bodySm400
        case .medium: return .bodyBase400
        case .large: return .bodyBase500
        }
    }
}

/// A token-bound amenity grid.
///
/// ```swift
/// AmenityGrid([Amenity("Free Wi-Fi", systemImage: "wifi"),
///              Amenity("Pool", systemImage: "figure.pool.swim")])
///     .columns(2)
/// ```
public struct AmenityGrid: View {
    @Environment(\.theme) private var theme

    private let amenities: [Amenity]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var columns: Int = 2
    private var size: AmenitySize = .medium
    private var tint: Color?

    public init(_ amenities: [Amenity]) {   // R1 — content
        self.amenities = amenities
    }

    public var body: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            ForEach(amenities) { amenity in
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Image(systemName: amenity.systemImage)
                        .font(.system(size: size.iconSize))
                        .foregroundStyle(tint ?? theme.foreground(.fgHero))
                        .frame(width: size.iconSize + 4)
                    Text(amenity.label)
                        .textStyle(size.textStyle)
                        .foregroundStyle(theme.text(.textPrimary))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(amenity.label)
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .leading), count: max(1, columns))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AmenityGrid {
    /// Number of columns (default 2).
    func columns(_ count: Int) -> Self { copy { $0.columns = max(1, count) } }
    /// Size tier: small / medium / large.
    func size(_ s: AmenitySize) -> Self { copy { $0.size = s } }
    /// Overrides the icon tint (otherwise the theme accent).
    func tint(_ color: Color?) -> Self { copy { $0.tint = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    AmenityGrid([
        Amenity("Free Wi-Fi", systemImage: "wifi"),
        Amenity("Pool", systemImage: "figure.pool.swim"),
        Amenity("Breakfast", systemImage: "fork.knife"),
        Amenity("Parking", systemImage: "parkingsign"),
        Amenity("Gym", systemImage: "dumbbell"),
        Amenity("Pet friendly", systemImage: "pawprint"),
    ])
    .columns(2)
    .padding()
}
