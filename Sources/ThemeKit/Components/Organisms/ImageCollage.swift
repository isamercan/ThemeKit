//
//  ImageCollage.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A gallery collage of remote images with count-aware layouts (1 / 2 / 3 / 4+)
/// and a "+N" overlay on the last visible tile. Brand-neutral, token-bound; uses
/// `RemoteImage` (native AsyncImage), no asset/Kingfisher dependency.
public struct ImageCollage: View {
    @Environment(\.theme) private var theme

    private let urls: [URL]
    private let onTap: ((Int) -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var height: CGFloat = 220
    private var spacing: CGFloat = 4
    private var cornerRadius: CGFloat = 12

    public init(_ urls: [URL], onTap: ((Int) -> Void)? = nil) {   // R1
        self.urls = urls
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            switch urls.count {
            case 0:
                placeholder
            case 1:
                tile(0)
            case 2:
                HStack(spacing: spacing) { tile(0); tile(1) }
            case 3:
                HStack(spacing: spacing) {
                    tile(0)
                    VStack(spacing: spacing) { tile(1); tile(2) }
                }
            default:
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) { tile(0); tile(1) }
                    HStack(spacing: spacing) { tile(2); tile(3, overlayExtra: urls.count - 4) }
                }
            }
        }
        .frame(height: height)
    }

    private func tile(_ index: Int, overlayExtra: Int = 0) -> some View {
        ZStack {
            RemoteImage(urls[index]).contentMode(.fill).cornerRadius(cornerRadius)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if overlayExtra > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MediaScrim.solid)
                Text("+\(overlayExtra)")
                    .textStyle(.headingBase)
                    .foregroundStyle(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?(index) }
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .accessibilityLabel(overlayExtra > 0
            ? String(themeKit: "View more photos")
            : String(themeKit: "Photo"))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.background(.bgSecondaryLight))
            .overlay(Icon(systemName: "photo.on.rectangle").size(.lg).color(theme.text(.textTertiary)))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ImageCollage {
    /// Overall collage height.
    func height(_ h: CGFloat) -> Self { copy { $0.height = h } }

    /// Gap between tiles.
    func spacing(_ s: CGFloat) -> Self { copy { $0.spacing = s } }

    /// Gap between tiles from a theme spacing token.
    func spacing(_ key: Theme.SpacingKey) -> Self { spacing(key.value) }

    /// Tile corner radius.
    func cornerRadius(_ r: CGFloat) -> Self { copy { $0.cornerRadius = r } }

    /// Tile corner radius from a theme radius role (box / field / selector).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { cornerRadius(role.value) }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let urls = (1...6).compactMap { URL(string: "https://picsum.photos/seed/collage\($0)/400/300") }
    return VStack(spacing: 16) {
        ImageCollage(Array(urls.prefix(3))).height(180)
        ImageCollage(urls).height(220)
    }
    .padding()
}
