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
        renders(Cascader([CascaderOption("a", label: "A", children: [CascaderOption("b", label: "B")])], selection: .constant([String]())), "Cascader")
        renders(Transfer([TransferItem("a", title: "A"), TransferItem("b", title: "B")], target: .constant(["a"])), "Transfer")
        renders(Mentions(text: .constant("hi @a"), options: [MentionOption("ada")]), "Mentions")
        renders(Masonry { ForEach(0..<4) { _ in Color.clear.frame(height: 30) } }, "Masonry")
        renders(TreeView([TreeNode(id: "a", "A", children: [TreeNode(id: "b", "B")])], selection: .constant([])).checkable(), "TreeView")
        renders(ColumnsGrid { ForEach(0..<4) { _ in Color.clear.frame(height: 20) } }.columns(2), "ColumnsGrid")
        renders(Affix(offsetTop: 0) { Text("Toolbar") }, "Affix")
    }

    // InputGroup + InputAffix must render across the Figma axes (variant ×
    // type × affix positioning × gapSpace) and with real-world affix content.
    @MainActor
    func testInputGroupComponentsRender() {
        Theme.shared.loadTheme(named: "defaultTheme")
        // Standalone affix content (mute / active, icon / label / arrow, button).
        renders(InputAffix("USD").arrow().emphasis(.active), "InputAffix/selector")
        renders(InputAffix(action: {}).icon("doc.on.doc"), "InputAffix/icon-button")
        // Both affixes, primary/text — the base variant.
        renders(InputGroup("heroui.com", text: .constant("heroui.com"))
            .prefix { InputAffix().icon("globe") }
            .suffix { InputAffix(action: {}).icon("doc.on.doc").emphasis(.active) }, "InputGroup/text-both")
        // Secondary + number + gapSpaced divider + prefix/suffix.
        renders(InputGroup("0", text: .constant("10"))
            .variant(.secondary).type(.number).gapSpaced()
            .prefix { InputAffix("$") }
            .suffix { InputAffix("USD", action: {}).arrow().emphasis(.active) }, "InputGroup/number-secondary-gap")
        // Password + suffix-only reveal affix.
        renders(InputGroup("Password", text: .constant("secret"))
            .type(.password)
            .suffix { InputAffix(action: {}).icon("eye") }, "InputGroup/password-suffix")
        // Prefix-only.
        renders(InputGroup("(000) 000 - 0000", text: .constant(""))
            .type(.number).gapSpaced()
            .prefix { InputAffix("+1", action: {}).icon("phone").arrow().emphasis(.active) }, "InputGroup/prefix-only")
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

    // The HeroUI catalog-gap components (Waves 1-3) must render too.
    @MainActor
    func testHeroUIGapComponentsRender() {
        struct SmokeTask: Identifiable, Equatable { let id: Int; let title: String }
        Theme.shared.loadTheme(named: "defaultTheme")
        let hsba = HSBAColor(hue: 0.55, saturation: 0.8, brightness: 0.9)
        let swatches = [ColorSwatchItem(.red, label: "Red"), ColorSwatchItem(.blue, label: "Blue")]
        let series = [ChartSeries("A", [ChartPoint("Jan", 3), ChartPoint("Feb", 6), ChartPoint("Mar", 4)])]
        let slices = [ChartSlice("X", 60), ChartSlice("Y", 40)]

        // Wave 1
        renders(TrendChip(.up("+12%")), "TrendChip")
        renders(ColorSwatch(.red, label: "Red").selected(), "ColorSwatch")
        renders(ColorSwatchPicker(swatches, selection: .constant(nil)), "ColorSwatchPicker")
        renders(ColorSlider(.hue, color: .constant(hsba)), "ColorSlider")
        renders(ColorArea(color: .constant(hsba)), "ColorArea")
        renders(CalendarYearPicker(selection: .constant(2026)), "CalendarYearPicker")
        renders(Text("Anchor").themePopover(isPresented: .constant(true)) { Text("Popover") }, "Popover")

        // Wave 2
        renders(LineChart(series), "LineChart")
        renders(AreaChart(series), "AreaChart")
        renders(BarChart(series), "BarChart")
        renders(DonutChart(slices), "DonutChart")
        renders(Text("Hover").hoverCard { Text("Preview") }, "HoverCard")
        renders(Color.clear.commandPalette(isPresented: .constant(false), sections: [CommandSection("A", items: [CommandItem("Go") {}])]), "CommandPalette")

        // Wave 3
        renders(EmojiReactionButton("👍", count: 12), "EmojiReactionButton")
        renders(Text("Menu").themeContextMenu([MenuAction("Open") {}]), "ThemeContextMenu")
        renders(TableToggleCell(isOn: .constant(true), label: "Active"), "TableToggleCell")
        renders(TableSelectCell(["Low", "High"], selection: .constant("Low"), label: "Priority"), "TableSelectCell")
        renders(TableSliderCell(value: .constant(0.5), in: 0...1, label: "Amount"), "TableSliderCell")
        renders(TableColorCell(selection: .constant(.blue), label: "Color"), "TableColorCell")
        renders(ActionBar(count: 3, actions: [ActionBarAction("Delete", systemImage: "trash", role: .destructive) {}], onClear: {}), "ActionBar")
        renders(Agenda([AgendaEvent("Standup", start: .now, end: .now, accent: .primary)]), "Agenda")
        renders(ColorPickerPanel(color: .constant(hsba)).swatches(swatches), "ColorPickerPanel")
        renders(KanbanBoard(columns: .constant([KanbanColumn("To do", items: [SmokeTask(id: 1, title: "Card")], accent: .primary)])) { Text($0.title) }, "KanbanBoard")

        Theme.shared.loadTheme(named: "defaultTheme")
    }
}
