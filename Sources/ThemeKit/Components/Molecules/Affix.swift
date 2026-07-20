//
//  Affix.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Affix** — pins its content to the top (or bottom) of
//  the viewport once it would scroll past a given offset, then releases it when it
//  scrolls back. A placeholder holds the content's slot in the scroll flow, and
//  the content is offset to stay fixed. Best used inside a vertical `ScrollView`.
//
//      ScrollView {
//          Affix(offsetTop: 0) { Toolbar() }     // sticks to the top on scroll
//          … long content …
//      }
//
//  `.onChange { affixed in … }` fires when the pinned state flips.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct Affix<Content: View>: View {
    private let content: Content
    // One of the two offsets is set by the initializer.
    private var offsetTop: CGFloat?
    private var offsetBottom: CGFloat?
    private var spaceName: String?
    private var onChange: ((Bool) -> Void)?

    @State private var pinOffset: CGFloat = 0
    @State private var affixed = false
    @State private var contentSize: CGSize = .zero

    /// Pin to the top once the content scrolls within `offsetTop` of the viewport top.
    public init(offsetTop: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.offsetTop = offsetTop
        self.content = content()
    }

    /// Pin to the bottom once the content scrolls within `offsetBottom` of the viewport bottom.
    public init(offsetBottom: CGFloat, @ViewBuilder content: () -> Content) {
        self.offsetBottom = offsetBottom
        self.content = content()
    }

    /// The space the offset is measured in — a named scroll container (Ant `target`)
    /// or the whole screen.
    private var coordinateSpace: CoordinateSpace {
        spaceName.map { CoordinateSpace.named($0) } ?? .global
    }

    public var body: some View {
        // The placeholder reserves the content's slot in the scroll flow and is
        // measured (in-flow, so no feedback loop with the offset content).
        Color.clear
            .frame(width: contentSize.width, height: contentSize.height)
            .background(alignment: .topLeading) {
                GeometryReader { geo in
                    Color.clear.preference(key: AffixMinYKey.self, value: geo.frame(in: coordinateSpace).minY)
                }
            }
            .overlay(alignment: .topLeading) {
                content
                    .background(GeometryReader { geo in
                        Color.clear
                            .onAppear { contentSize = geo.size }
                            .onChangeCompat(of: geo.size) { contentSize = $1 }
                    })
                    .offset(y: pinOffset)
            }
            .onPreferenceChange(AffixMinYKey.self) { minY in update(placeholderMinY: minY) }
    }

    private func update(placeholderMinY minY: CGFloat) {
        var offset: CGFloat = 0
        if let offsetTop {
            offset = minY < offsetTop ? (offsetTop - minY) : 0
        } else if let offsetBottom {
            let placeholderMaxY = minY + contentSize.height
            let threshold = AffixMetrics.viewportHeight - offsetBottom
            offset = placeholderMaxY > threshold ? (threshold - placeholderMaxY) : 0
        }
        if offset != pinOffset { pinOffset = offset }
        let isAffixed = offset != 0
        if isAffixed != affixed {
            affixed = isAffixed
            onChange?(isAffixed)
        }
    }
}

// MARK: - Modifiers

public extension Affix {
    /// Fires when the pinned state changes (Ant Affix `onChange`).
    func onChange(_ action: @escaping (Bool) -> Void) -> Self {
        var c = self; c.onChange = action; return c
    }
    /// Measure the offset within a named scroll container instead of the screen
    /// (Ant Affix `target`) — set the same name via `.coordinateSpace(name:)` on
    /// the enclosing `ScrollView`.
    func target(_ name: String) -> Self {
        var c = self; c.spaceName = name; return c
    }
}

// MARK: - Support

private struct AffixMinYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private enum AffixMetrics {
    /// Best-effort viewport height for bottom-affix (full-screen contexts).
    static var viewportHeight: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.height
        #else
        return 800
        #endif
    }
}

#Preview {
    // Affix is scroll-driven; each cell shows a single unpinned frame inside a
    // short ScrollView — live pinning needs interactive scrolling (see the demo).
    PreviewMatrix("Affix") {
        PreviewCase("Top affix in scroll flow") {
            ScrollView {
                VStack(spacing: 12) {
                    Affix(offsetTop: 8) {
                        HStack { ThemeButton("Pinned toolbar") {}; Spacer() }
                            .padding(8)
                            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: 12))
                            .themeShadow(.soft)
                    }
                    ForEach(0..<6) { Text("Row \($0)").frame(maxWidth: .infinity).padding().background(Theme.shared.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: 8)) }
                }
                .padding()
            }
            .frame(height: 260)
        }
    }
    .environment(\.theme, Theme.shared)
}
