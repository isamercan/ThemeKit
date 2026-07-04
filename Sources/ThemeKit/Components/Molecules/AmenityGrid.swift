//
//  AmenityGrid.swift
//  ThemeKit
//
//  A grid of icon + label amenities (wifi · pool · breakfast). Token-bound: the icon
//  tint comes from the theme's accent, so it re-skins with the brand.
//
//  Flexible: progressive disclosure (`.limit(6)` → "+N more"), highlighted amenities,
//  density-aware spacing, and Dynamic-Type-scaling icons.
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
/// AmenityGrid(amenities).columns(2).limit(6).highlighted(["Free Wi-Fi"])
/// ```
public struct AmenityGrid: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private let amenities: [Amenity]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var columns: Int = 2
    private var size: AmenitySize = .medium
    private var tint: Color?
    private var limit: Int?
    private var highlighted: Set<String> = []

    public init(_ amenities: [Amenity]) {   // R1 — content
        self.amenities = amenities
    }

    private var visible: [Amenity] {
        guard let limit, !expanded, amenities.count > limit else { return amenities }
        return Array(amenities.prefix(limit))
    }
    private var hiddenCount: Int {
        guard let limit, !expanded else { return 0 }
        return max(0, amenities.count - limit)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.md.value)) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: density.scale(Theme.SpacingKey.md.value)) {
                ForEach(visible) { amenity in item(amenity) }
            }
            if hiddenCount > 0 {
                Button {
                    withAnimation(Animation.snappy.ifMotionAllowed(reduceMotion)) { expanded = true }
                } label: {
                    Text("+\(hiddenCount) more")
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func item(_ amenity: Amenity) -> some View {
        let isHighlighted = highlighted.contains(amenity.id)
        return HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Image(systemName: amenity.systemImage)
                .font(size.textStyle.font)
                .foregroundStyle(tint ?? theme.foreground(.fgHero))
                .frame(width: size.iconSize + 4)
            Text(amenity.label)
                .textStyle(size.textStyle)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .foregroundStyle(isHighlighted ? theme.foreground(.fgHero) : theme.text(.textPrimary))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(amenity.label)
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
    /// Shows only the first `count`, with a "+N more" expander for the rest.
    func limit(_ count: Int) -> Self { copy { $0.limit = max(1, count) } }
    /// Amenities (by label) to emphasise in the accent colour.
    func highlighted(_ labels: Set<String>) -> Self { copy { $0.highlighted = labels } }

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
        Amenity("Spa", systemImage: "sparkles"),
        Amenity("Bar", systemImage: "wineglass"),
    ])
    .columns(2).limit(6).highlighted(["Free Wi-Fi", "Pool"])
    .padding()
}
