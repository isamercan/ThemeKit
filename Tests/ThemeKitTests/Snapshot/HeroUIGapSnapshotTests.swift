//
//  HeroUIGapSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the HeroUI catalog-gap components (Waves 1-3),
//  with dark-mode and RTL variants where the layout is direction-sensitive
//  (trend arrows, color-slider drag axis, calendar chevrons, action bar, agenda
//  time rail, kanban column order). iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

private struct SnapTask: Identifiable, Equatable { let id: Int; let title: String }

@MainActor
final class HeroUIGapSnapshotTests: SnapshotTestCase {

    private let hsba = HSBAColor(hue: 0.55, saturation: 0.8, brightness: 0.9)
    private var swatches: [ColorSwatchItem] {
        [.init(.red, label: "Red"), .init(.orange, label: "Orange"), .init(.green, label: "Green"), .init(.blue, label: "Blue")]
    }
    private var series: [ChartSeries] {
        [
            ChartSeries("2025", [ChartPoint("Jan", 12), ChartPoint("Feb", 18), ChartPoint("Mar", 15)]),
            ChartSeries("2026", [ChartPoint("Jan", 20), ChartPoint("Feb", 16), ChartPoint("Mar", 24)]),
        ]
    }

    // MARK: Wave 1

    func testTrendChip() {
        assertComponentSnapshot(HStack(spacing: 10) { TrendChip(.up("+12%")); TrendChip(.down("-3%")) })
    }
    func testTrendChip_dark() {
        assertComponentSnapshot(HStack(spacing: 10) { TrendChip(.up("+12%")); TrendChip(.down("-3%")) }, colorScheme: .dark)
    }
    func testTrendChip_rtl() {
        assertComponentSnapshot(HStack(spacing: 10) { TrendChip(.up("+12%")); TrendChip(.down("-3%")) }, layoutDirection: .rightToLeft)
    }

    func testColorSwatch() {
        assertComponentSnapshot(HStack(spacing: 12) {
            ColorSwatch(.red, label: "Red").selected()
            ColorSwatch(.green, label: "Green").shape(.circle)
            ColorSwatch(.purple.opacity(0.4), label: "Faded")
        })
    }

    func testColorSwatchPicker() {
        assertComponentSnapshot(ColorSwatchPicker(swatches, selection: .constant(swatches[1])).columns(4))
    }

    func testColorSlider() {
        assertComponentSnapshot(VStack(spacing: 12) {
            ColorSlider(.hue, color: .constant(hsba))
            ColorSlider(.alpha, color: .constant(hsba)).trackHeight(.compact)
        })
    }
    func testColorSlider_rtl() {
        assertComponentSnapshot(ColorSlider(.hue, color: .constant(hsba)), layoutDirection: .rightToLeft)
    }

    func testColorArea() {
        assertComponentSnapshot(ColorArea(color: .constant(hsba)).frame(width: 240))
    }

    func testCalendarYearPicker() {
        assertComponentSnapshot(CalendarYearPicker(selection: .constant(2026)).accent(.success))
    }
    func testCalendarYearPicker_rtl() {
        assertComponentSnapshot(CalendarYearPicker(selection: .constant(2026)), layoutDirection: .rightToLeft)
    }

    // MARK: Wave 2

    func testLineChart() { assertComponentSnapshot(LineChart(series).curved()) }
    func testLineChart_dark() { assertComponentSnapshot(LineChart(series).curved(), colorScheme: .dark) }
    func testAreaChart() { assertComponentSnapshot(AreaChart(series).stacked()) }
    func testBarChart() { assertComponentSnapshot(BarChart(series)) }
    func testDonutChart() {
        assertComponentSnapshot(DonutChart([ChartSlice("Direct", 42), ChartSlice("Search", 30), ChartSlice("Social", 28)]).innerRadius(.thin))
    }

    // MARK: Wave 3

    func testEmojiReactionButton() {
        assertComponentSnapshot(HStack(spacing: 10) {
            EmojiReactionButton("👍", count: 12, initiallyReacted: true)
            EmojiReactionButton("🎉", count: 4)
        })
    }

    func testTableCells() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 12) {
            TableToggleCell(isOn: .constant(true), label: "Active")
            TableSelectCell(["Low", "Medium", "High"], selection: .constant("Medium"), label: "Priority")
            TableSliderCell(value: .constant(0.5), in: 0...1, label: "Amount")
        })
    }

    func testActionBar() {
        assertComponentSnapshot(ActionBar(count: 3, actions: [
            ActionBarAction("Archive", systemImage: "archivebox") {},
            ActionBarAction("Delete", systemImage: "trash", role: .destructive) {},
        ], onClear: {}))
    }
    func testActionBar_rtl() {
        assertComponentSnapshot(ActionBar(count: 3, actions: [
            ActionBarAction("Archive", systemImage: "archivebox") {},
        ], onClear: {}), layoutDirection: .rightToLeft)
    }

    func testAgenda() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        assertComponentSnapshot(Agenda([
            AgendaEvent("Standup", start: start, end: start.addingTimeInterval(1800), location: "Zoom", accent: .primary),
            AgendaEvent("Review", start: start.addingTimeInterval(7200), accent: .purple),
        ]).locale(Locale(identifier: "en_US")))
    }
    func testAgenda_rtl() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        assertComponentSnapshot(Agenda([
            AgendaEvent("Standup", start: start, accent: .primary),
        ]).locale(Locale(identifier: "ar")), layoutDirection: .rightToLeft)
    }

    func testColorPickerPanel() {
        assertComponentSnapshot(ColorPickerPanel(color: .constant(hsba)).swatches(swatches).frame(width: 300))
    }

    func testKanbanBoard() {
        let columns: [KanbanColumn<SnapTask>] = [
            .init("To do", items: [SnapTask(id: 1, title: "Tokens"), SnapTask(id: 2, title: "Docs")], accent: .neutral),
            .init("Done", items: [SnapTask(id: 3, title: "Colors")], accent: .success),
        ]
        assertComponentSnapshot(
            KanbanBoard(columns: .constant(columns)) { task in
                Text(task.title).textStyle(.labelBase600).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: 600, height: 200),
            width: 600
        )
    }
    func testKanbanBoard_rtl() {
        let columns: [KanbanColumn<SnapTask>] = [
            .init("To do", items: [SnapTask(id: 1, title: "Tokens")], accent: .neutral),
            .init("Done", items: [SnapTask(id: 3, title: "Colors")], accent: .success),
        ]
        assertComponentSnapshot(
            KanbanBoard(columns: .constant(columns)) { task in
                Text(task.title).textStyle(.labelBase600).padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: 600, height: 200),
            width: 600,
            layoutDirection: .rightToLeft
        )
    }
}
#endif
