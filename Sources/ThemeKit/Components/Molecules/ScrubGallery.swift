//
//  ScrubGallery.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Touch-adapted hover gallery (daisyUI "Hover Gallery"): one visible page from
//  a set; scrubbing a finger horizontally across the view switches the visible
//  page by position — the pattern e-commerce cards use to flip through product
//  photos. A segment indicator at the bottom shows the position. Generic over
//  any content via a `(Int) -> Content` builder, with an `[Image]` convenience.
//

import SwiftUI

/// Molecule. Position-scrub gallery (daisyUI Hover Gallery, touch-adapted):
/// shows page `i` of `count`; a horizontal finger scrub maps touch position to
/// the visible page. Content is any view built per index; a segment indicator
/// sits at the bottom (`.indicator`, tinted via `.accent`).
public struct ScrubGallery<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount: Int
    private let content: (Int) -> Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var showsIndicator: Bool = true
    private var accentColor: SemanticColor = .primary
    private var radiusRole: Theme.RadiusRole = .box

    @State private var index = 0

    /// - Parameters:
    ///   - count: number of pages.
    ///   - content: builds the page for a given index (0-based).
    public init(count: Int, @ViewBuilder content: @escaping (Int) -> Content) {   // R1
        self.pageCount = max(count, 0)
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if pageCount > 0 {
                    content(min(index, pageCount - 1))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                if showsIndicator, pageCount > 1 {
                    segments
                }
            }
            .contentShape(Rectangle())
            .gesture(scrub(width: geo.size.width))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius(radiusRole), style: .continuous))
        // Position is conveyed only visually; speak it and make it adjustable.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(pageCount <= 0)
        .accessibilityLabel(Text(String(themeKit: "Gallery")))
        .accessibilityValue(Text(positionText))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: index = min(pageCount - 1, index + 1)
            case .decrement: index = max(0, index - 1)
            @unknown default: break
            }
        }
    }

    /// Maps the horizontal touch position to a page index (RTL-aware).
    private func scrub(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0, pageCount > 1 else { return }
                var fraction = value.location.x / width
                if layoutDirection == .rightToLeft { fraction = 1 - fraction }
                // The page swap itself is instant — that's the scrub feel;
                // only the indicator below animates.
                index = min(pageCount - 1, max(0, Int(fraction * CGFloat(pageCount))))
            }
    }

    /// Equal-width segment bars spanning the bottom edge (over-media styling,
    /// so the inactive tracks stay white-translucent like photo carousels).
    private var segments: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == index ? accentColor.solid : MediaScrim.onContentSecondary)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.bottom, Theme.SpacingKey.sm.value)
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: index)
        .allowsHitTesting(false)
    }

    /// Clamped "position of total"; empty when there are no pages.
    private var positionText: String {
        guard pageCount > 0 else { return "" }
        let position = min(max(index + 1, 1), pageCount)
        return String(themeKit: "\(position) of \(pageCount)")
    }
}

// MARK: - Image convenience

public extension ScrubGallery where Content == AnyView {
    /// Convenience: scrub across a set of images, fill-cropped to the frame.
    init(_ images: [Image]) {
        self.init(count: images.count) { i in
            AnyView(images[i].resizable().scaledToFill())
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ScrubGallery {
    /// Shows the segment position indicator at the bottom (default true).
    func indicator(_ visible: Bool = true) -> Self { copy { $0.showsIndicator = visible } }

    /// Semantic tint of the active indicator segment (default `.primary`).
    func accent(_ c: SemanticColor) -> Self { copy { $0.accentColor = c } }

    /// Corner radius role clipping the gallery (default `.box`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    let colors: [Color] = [.blue, .teal, .orange, .purple]
    VStack(spacing: 32) {
        ScrubGallery(count: colors.count) { i in
            LinearGradient(colors: [colors[i], colors[i].opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
                .overlay(Text("\(i + 1)").font(.largeTitle.bold()).foregroundStyle(.white))
        }
        .frame(height: 220)

        ScrubGallery(count: colors.count) { i in
            colors[i].opacity(0.6)
        }
        .accent(.turquoise)
        .radius(.field)
        .frame(height: 140)

        ScrubGallery(count: 3) { i in
            theme.background(.bgElevatorTertiary)
                .overlay(Icon(systemName: ["airplane", "bed.double", "car"][i]).size(.lg))
        }
        .indicator(false)
        .frame(height: 100)
    }
    .padding()
    .background(theme.background(.bgTertiary))
}
