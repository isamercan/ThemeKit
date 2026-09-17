//
//  TooltipPlacementTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  `.tooltip` draws its bubble BESIDE the anchor, on the edge it's given — not
//  over it. Through 1.5.0 the placement's alignment guide sat on conditional
//  content (`if isPresented` in the overlay, a `switch` in the placement), which
//  SwiftUI drops, so the bubble lined up with the anchor's own edge and hid it.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class TooltipPlacementTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    private static let edges: [TooltipEdge] = [.top, .bottom, .leading, .trailing]
    private let stageSize = CGSize(width: 320, height: 240)
    private let anchorSide: CGFloat = 24
    /// Pure sRGB red: the system red differs per platform and appearance.
    private let red = Color(.sRGB, red: 1, green: 0, blue: 0)

    /// The anchor stays visible under every edge, for the binding-driven and the
    /// rich form, left to right and right to left.
    func testTheAnchorStaysVisible() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for edge in Self.edges {
                for rich in [false, true] {
                    let image = try XCTUnwrap(render(stage(edge: edge, rich: rich), direction: direction))
                    let centre = try XCTUnwrap(rgba(image, at: CGPoint(x: stageSize.width / 2, y: stageSize.height / 2)))
                    XCTAssertTrue(isRed(centre), "\(direction) \(edge) rich:\(rich): the bubble covers its anchor")
                }
            }
        }
    }

    /// The bubble is drawn on its edge's side: just past the anchor and the gap,
    /// the stage shows the bubble, not the white page. In right-to-left layouts
    /// leading is on the right.
    func testTheBubbleSitsOnItsEdge() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for edge in Self.edges {
                let image = try XCTUnwrap(render(stage(edge: edge, rich: false), direction: direction))
                let point = probe(edge, direction: direction)
                let pixel = try XCTUnwrap(rgba(image, at: point))
                XCTAssertFalse(isWhite(pixel), "\(direction) \(edge): nothing drawn at \(point)")
                XCTAssertFalse(isRed(pixel), "\(direction) \(edge): the anchor reaches \(point)")
            }
        }
    }

    /// Control: without a tooltip the probe points are the white page, so the
    /// check above can fail.
    func testTheProbesAreBlankWithoutATooltip() throws {
        let plain = red.frame(width: anchorSide, height: anchorSide)
            .frame(width: stageSize.width, height: stageSize.height)
            .background(Color.white)
        let image = try XCTUnwrap(render(plain, direction: .leftToRight))
        for edge in Self.edges {
            let pixel = try XCTUnwrap(rgba(image, at: probe(edge, direction: .leftToRight)))
            XCTAssertTrue(isWhite(pixel), "\(edge): the probe isn't blank")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stage(edge: TooltipEdge, rich: Bool) -> some View {
        let anchor = red.frame(width: anchorSide, height: anchorSide)
        Group {
            if rich {
                anchor.tooltip(isPresented: .constant(true), edge: edge) { Text("Hint") }
            } else {
                anchor.tooltip("Hint", isPresented: .constant(true), edge: edge)
            }
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .background(Color.white)
    }

    /// A point 12pt past the anchor's edge plus the placement gap and the arrow:
    /// inside any bubble drawn beside it on that edge.
    private func probe(_ edge: TooltipEdge, direction: LayoutDirection) -> CGPoint {
        let centre = CGPoint(x: stageSize.width / 2, y: stageSize.height / 2)
        let reach = anchorSide / 2 + Theme.SpacingKey.sm.value + 6 + 4
        let flip: CGFloat = direction == .rightToLeft ? -1 : 1
        switch edge {
        case .top: return CGPoint(x: centre.x, y: centre.y - reach)
        case .bottom: return CGPoint(x: centre.x, y: centre.y + reach)
        case .leading: return CGPoint(x: centre.x - reach * flip, y: centre.y)
        case .trailing: return CGPoint(x: centre.x + reach * flip, y: centre.y)
        }
    }

    private func render<V: View>(_ view: V, direction: LayoutDirection) -> CGImage? {
        let renderer = ImageRenderer(content: view.environment(\.layoutDirection, direction))
        renderer.scale = 1
        return renderer.cgImage
    }

    private func rgba(_ image: CGImage, at point: CGPoint) -> [UInt8]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            // Core Graphics counts rows from the bottom; the point counts them from the top.
            context.draw(image, in: CGRect(x: -point.x, y: point.y - CGFloat(image.height) + 1,
                                           width: CGFloat(image.width), height: CGFloat(image.height)))
            return true
        }
        return drawn ? pixel : nil
    }

    private func isRed(_ pixel: [UInt8]) -> Bool { pixel[0] > 200 && pixel[1] < 60 && pixel[2] < 60 }
    private func isWhite(_ pixel: [UInt8]) -> Bool { pixel[0] > 245 && pixel[1] > 245 && pixel[2] > 245 }
}
