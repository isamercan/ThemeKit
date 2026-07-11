//
//  CalendarYearPicker.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A paged 12-year grid for jumping across years. (HeroUI `calendar-year-picker`.)
//  Standalone here; `CalendarView.yearPicker()` embeds the same idea into the
//  month calendar's header. Controlled-only — it edits a value (the year).
//

import SwiftUI

/// Molecule. A 3×4 grid of years, paged by twelve, driving a bound year number
/// in the active calendar (Gregorian-agnostic — reads/writes through the
/// locale's calendar, never hardcoded ranges).
///
///     @State private var year = 2026
///     CalendarYearPicker(selection: $year).range(2000...2030).accent(.success)
public struct CalendarYearPicker: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    @Binding private var selection: Int

    // Appearance/config — mutated only through the modifiers below (R2).
    private var yearRange: ClosedRange<Int>?
    private var accent: SemanticColor?

    /// Top-left year of the visible page; `nil` derives it from the selection.
    @State private var pageStart: Int?

    public init(selection: Binding<Int>) {   // R1 — content + binding
        self._selection = selection
    }

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = locale
        return c
    }
    private var currentYear: Int { calendar.component(.year, from: Date.now) }
    private var effectiveRange: ClosedRange<Int> { yearRange ?? ((currentYear - 100)...(currentYear + 20)) }

    private var resolvedPageStart: Int { pageStart ?? pageStart(containing: selection) }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            header
            grid
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    private var header: some View {
        HStack {
            navButton("chevron.left", label: String(themeKit: "Previous years"), delta: -12)
            Spacer()
            Text(rangeTitle)
                .textStyle(.labelMd700)
                .foregroundStyle(theme.text(.textPrimary))
            Spacer()
            navButton("chevron.right", label: String(themeKit: "Next years"), delta: 12)
        }
    }

    private func navButton(_ name: String, label: String, delta: Int) -> some View {
        let start = resolvedPageStart
        let target = start + delta
        // Page only while some part of the destination page falls in range.
        let enabled = effectiveRange.contains(target) || effectiveRange.contains(target + 11)
        return Button {
            withAnimation(Motion.base.animation) { pageStart = target }
        } label: {
            Icon(systemName: name).size(.sm).color(theme.text(.textPrimary))
                .frame(width: 32, height: 32)
                .mirrorsInRTL()
                .frame(minWidth: 44, minHeight: 44)   // A11y: ≥44pt tap target (glyph stays 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private var grid: some View {
        let start = resolvedPageStart
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Theme.SpacingKey.sm.value) {
            ForEach(0..<12, id: \.self) { offset in
                yearCell(start + offset)
            }
        }
    }

    private func yearCell(_ year: Int) -> some View {
        let inRange = effectiveRange.contains(year)
        let isSelected = year == selection
        let isCurrent = year == currentYear
        return Button {
            selection = year
        } label: {
            Text(yearLabel(year))
                .textStyle(.bodyBase400)
                .foregroundStyle(isSelected ? selectedContent : (isCurrent ? todayText : theme.text(.textPrimary)))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isSelected ? selectedFill : .clear, in: Capsule())
                .overlay { if isCurrent && !isSelected { Capsule().stroke(todayRing, lineWidth: 1) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!inRange)
        .opacity(inRange ? 1 : 0.3)
        .accessibilityLabel(yearLabel(year))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Accent resolution (defaults keep the hero tokens, R4 — CalendarView parity)

    private var selectedFill: Color { accent?.solid ?? theme.background(.bgHero) }
    private var selectedContent: Color { accent?.onSolid ?? theme.foreground(.fgSecondary) }
    private var todayText: Color { accent?.accent ?? theme.text(.textHero) }
    private var todayRing: Color { accent?.border ?? theme.border(.borderHero) }

    // MARK: - Paging math

    private func pageStart(containing year: Int) -> Int {
        // Align pages to the range start so paging lands on stable boundaries.
        let lo = effectiveRange.lowerBound
        let page = (year - lo) / 12
        return lo + page * 12
    }

    /// Localized so non-Latin digit systems render correctly; grouping off so a
    /// year never gets a thousands separator ("2,026").
    private func yearLabel(_ year: Int) -> String {
        year.formatted(.number.grouping(.never).locale(locale))
    }

    private var rangeTitle: String {
        let start = resolvedPageStart
        return "\(yearLabel(start)) – \(yearLabel(start + 11))"
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CalendarYearPicker {
    /// Selectable year range; years outside it are dimmed and disabled. Default
    /// spans a century back and two decades forward from the current year.
    func range(_ years: ClosedRange<Int>) -> Self { copy { $0.yearRange = years } }

    /// Token-fed accent for the selected year (the current-year ring/text
    /// follows the same ladder); `nil` (default) keeps the hero tokens.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    // Paging is interactive; each cell is a single 12-year page frame.
    PreviewMatrix("CalendarYearPicker") {
        PreviewCase("Default") { CalendarYearPicker(selection: .constant(2026)) }
        PreviewCase("Ranged + success accent") {
            CalendarYearPicker(selection: .constant(2020)).range(2015...2030).accent(.success)
        }
    }
}
