//
//  RenderSmokeTests.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Smoke test: render a representative set of components through `ImageRenderer`
//  to prove their view bodies build and lay out without crashing under the
//  default theme. (Not a pixel-snapshot test — just a liveness check.)
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
final class RenderSmokeTests: XCTestCase {

    @MainActor
    private func renders<V: View>(_ view: V, _ label: String) {
        let renderer = ImageRenderer(content: view.frame(width: 220, height: 90))
        #if canImport(UIKit)
        XCTAssertNotNil(renderer.uiImage, "\(label) failed to render")
        #else
        XCTAssertNotNil(renderer.nsImage, "\(label) failed to render")
        #endif
    }

    @MainActor
    func testRepresentativeComponentsRender() {
        Theme.shared.loadTheme(named: "defaultTheme")
        renders(Spinner(), "Spinner")
        renders(ProgressBar(value: 0.5).showsPercentage(), "ProgressBar")
        renders(StatusDot(.online, label: "Online").pulse(), "StatusDot")
        renders(Badge("New"), "Badge")
        renders(Skeleton().size(width: 120, height: 16), "Skeleton")
        renders(Rating(value: 4.3).layout(.rateNumberText), "Rating")
        renders(ThemeButton("Tap") {}, "ThemeButton")
        renders(Callout("Heads up").variant(.warning), "Callout")
        renders(TimeField("Time", time: .constant(.now)).hourCycle(.h24).minuteInterval(15), "TimeField")
        renders(Sidebar(items: [
            .init(tag: "home", "Home", systemImage: "house"),
            .init(tag: "fav", "Favorites", systemImage: "heart", badge: 2),
        ], selection: .constant("home")).width(200), "Sidebar")
    }

    // The Ant-parity additions (layout, navigation, data-entry) must render too.
    @MainActor
    func testAntParityComponentsRender() {
        Theme.shared.loadTheme(named: "defaultTheme")
        renders(Text("Card").padding().watermark("SPECIMEN"), "Watermark")
        renders(Space { Tag("A"); Tag("B") }, "Space")
        renders(Flex { Tag("A"); Tag("B") }.justify(.spaceBetween), "Flex")
        renders(AnchorNav([AnchorItem("a", title: "Intro"), AnchorItem("b", title: "API")], active: .constant("a")), "AnchorNav")
        renders(Splitter(.horizontal) { Color.clear } second: { Color.clear }, "Splitter")
        renders(Cascader([CascaderOption("a", label: "A", children: [CascaderOption("b", label: "B")])], selection: .constant([])), "Cascader")
        renders(Transfer([TransferItem("a", title: "A"), TransferItem("b", title: "B")], target: .constant(["a"])), "Transfer")
        renders(Mentions(text: .constant("hi @a"), options: [MentionOption("ada")]), "Mentions")
        renders(Masonry { ForEach(0..<4) { _ in Color.clear.frame(height: 30) } }, "Masonry")
        renders(TreeView([TreeNode(id: "a", "A", children: [TreeNode(id: "b", "B")])], selection: .constant([])).checkable(), "TreeView")
        renders(ColumnsGrid { ForEach(0..<4) { _ in Color.clear.frame(height: 20) } }.columns(2), "ColumnsGrid")
        renders(Affix(offsetTop: 0) { Text("Toolbar") }, "Affix")
    }

    // Components must also render under a runtime-generated theme + dark mode.
    @MainActor
    func testComponentsRenderUnderGeneratedTheme() {
        Theme.shared.apply(ThemeConfig(primaryHex: "7C3AED", dark: true))
        renders(ProgressBar(value: 0.75), "ProgressBar/generated")
        renders(Badge("Pro"), "Badge/generated")
        renders(Rating(value: 3.0), "Rating/generated")
        Theme.shared.loadTheme(named: "defaultTheme")   // restore
    }
}
