//
//  Skeleton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SkeletonView. A shimmering
//  placeholder driven by the skeleton color tokens (which adapt to the dark
//  theme automatically), applied via `.skeleton(_:)` over any view, via
//  `.skeleton(_:shape:)` for a custom outline, or as a standalone `Skeleton`
//  primitive of an arbitrary shape and size.
//

import SwiftUI

/// The outline of a skeleton placeholder.
public enum SkeletonShape: Equatable {
    case rounded(CGFloat)
    case circle
    case capsule

    var anyShape: AnyShape {
        switch self {
        case .rounded(let r): return AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        case .circle: return AnyShape(Circle())
        case .capsule: return AnyShape(Capsule())
        }
    }
}

/// The shimmering fill, reused by the modifier and the standalone view.
struct SkeletonShimmer: View {
    let shape: SkeletonShape
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        shape.anyShape
            .fill(Theme.shared.background(.skeletonBgSkeletonBase))
            .overlay {
                // Honor Reduce Motion: a static placeholder, no traveling sweep.
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Theme.shared.background(.bgWhite).opacity(0.7), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: animate ? geo.size.width : -geo.size.width * 0.5)
                    }
                }
            }
            .clipShape(shape.anyShape)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

/// A standalone skeleton block of an arbitrary shape and size.
public struct Skeleton: View {
    private let shape: SkeletonShape
    private let width: CGFloat?
    private let height: CGFloat?

    public init(_ shape: SkeletonShape = .rounded(8), width: CGFloat? = nil, height: CGFloat? = nil) {
        self.shape = shape
        self.width = width
        self.height = height
    }

    public var body: some View {
        SkeletonShimmer(shape: shape)
            .frame(width: width, height: height)
    }
}

private struct SkeletonModifier: ViewModifier {
    let isLoading: Bool
    let shape: SkeletonShape

    func body(content: Content) -> some View {
        content
            .opacity(isLoading ? 0 : 1)
            .overlay { if isLoading { SkeletonShimmer(shape: shape) } }
    }
}

public extension View {
    /// Replaces the view with a shimmering rounded skeleton while `isLoading` is true.
    func skeleton(_ isLoading: Bool, cornerRadius: CGFloat = 8) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, shape: .rounded(cornerRadius)))
    }

    /// Replaces the view with a shimmering skeleton of a custom shape while loading.
    func skeleton(_ isLoading: Bool, shape: SkeletonShape) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, shape: shape))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("Loading title").font(.title).skeleton(true)
        Text("A line of body text that is being loaded.").skeleton(true)
        RoundedRectangle(cornerRadius: 12).frame(height: 120).skeleton(true, cornerRadius: 12)
        HStack {
            Skeleton(.circle, width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(.capsule, width: 160, height: 12)
                Skeleton(.capsule, width: 100, height: 12)
            }
        }
    }
    .padding()
}
