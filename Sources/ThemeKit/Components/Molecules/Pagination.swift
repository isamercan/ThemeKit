//
//  Pagination.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Numbered pagination with prev / next, windowed around the current
/// page, plus a simple mode, an optional total label and a disabled state.
/// (Ant Pagination / MUI Pagination parity.) Selection owned by the caller.
/// The window is configurable: `boundaryCount` pages always show at each end and
/// `siblingCount` pages on each side of the current page; gaps collapse to an
/// ellipsis. An optional quick-jumper field jumps straight to a page.
public struct Pagination: View {
    @Environment(\.theme) private var theme

    @Binding private var current: Int   // 1-based
    private let total: Int
    @Environment(\.isEnabled) private var isEnabled
    // Layout config — set via chainable modifiers, keeping the common call site
    // to `Pagination(current: $page, total: n)`.
    private var simple: Bool = false
    private var siblingCount: Int = 1
    private var boundaryCount: Int = 1
    private var showJumper: Bool = false
    private var jumperTitle: String = String(themeKit: "Go to")
    private var showTotal: ((Int, Int) -> String)? = nil

    @State private var jumpText = ""

    public init(
        current: Binding<Int>,
        total: Int
    ) {
        self._current = current
        self.total = max(total, 1)
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let showTotal {
                Text(showTotal(current, total))
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .padding(.trailing, Theme.SpacingKey.xs.value)
            }

            arrow(systemName: "chevron.left", label: String(themeKit: "Previous page"), enabled: isEnabled && current > 1) { current = max(1, current - 1) }

            if simple {
                Text("\(current) / \(total)")
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                    .frame(minWidth: 48)
                    .accessibilityLabel(String(themeKit: "Page"))
                    .accessibilityValue(String(themeKit: "\(current) of \(total)"))
            } else {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                    if page == -1 {
                        Text("…").textStyle(.labelBase600).foregroundStyle(theme.text(.textTertiary)).frame(width: 36, height: 36)
                    } else {
                        pageButton(page)
                    }
                }
            }

            arrow(systemName: "chevron.right", label: String(themeKit: "Next page"), enabled: isEnabled && current < total) { current = min(total, current + 1) }

            if showJumper { jumper }
        }
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var pages: [Int] {
        Self.pageWindow(current: current, total: total, siblingCount: siblingCount, boundaryCount: boundaryCount)
    }

    // MARK: - Quick jumper

    private var jumper: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(jumperTitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            TextField("", text: $jumpText)
                .multilineTextAlignment(.center)
                .textStyle(.labelBase600)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(width: 44, height: 36)
                .background(theme.background(.bgWhite),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
                )
                .jumperKeyboard()
                .submitLabel(.go)
                .disabled(!isEnabled)
                .onSubmit(jump)
                .accessibilityLabel(jumperTitle)
        }
        .padding(.leading, Theme.SpacingKey.xs.value)
    }

    private func jump() {
        defer { jumpText = "" }
        guard let parsed = Int(jumpText.filter(\.isNumber)) else { return }
        current = min(max(1, parsed), total)
    }

    private func pageButton(_ page: Int) -> some View {
        let isCurrent = page == current
        return Button { if isEnabled { current = page } } label: {
            Text("\(page)")
                .textStyle(.labelBase600)
                .foregroundStyle(isCurrent ? theme.foreground(.fgSecondary) : theme.text(.textPrimary))
                .frame(width: 36, height: 36)
                .background(isCurrent ? theme.background(.bgHero) : .clear,
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(theme.border(.borderPrimary), lineWidth: isCurrent ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)   // >=44pt hit area (WCAG 2.5.5); glyph stays 36pt
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .accessibilityLabel(String(themeKit: "Page \(page)"))
        .accessibilityValue(isCurrent ? String(themeKit: "\(current) of \(total)") : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func arrow(systemName: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName)
                .size(.sm)
                .color(enabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                .frame(width: 36, height: 36)
                .mirrorsInRTL()
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)   // >=44pt hit area (WCAG 2.5.5); glyph stays 36pt
        .contentShape(Rectangle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Pure windowing (extracted for testing)

    /// Page list with `-1` ellipsis sentinels. Always shows `boundaryCount` pages
    /// at each end and `siblingCount` pages either side of `current`; a gap of a
    /// single page is filled rather than hidden behind an ellipsis (MUI behavior).
    static func pageWindow(current: Int, total: Int, siblingCount: Int = 1, boundaryCount: Int = 1) -> [Int] {
        guard total > 0 else { return [] }
        let cur = min(max(current, 1), total)
        let sib = max(0, siblingCount)
        let bound = max(1, boundaryCount)

        var wanted = Set<Int>()
        for page in 1...min(bound, total) { wanted.insert(page) }
        for page in max(total - bound + 1, 1)...total { wanted.insert(page) }
        for page in max(cur - sib, 1)...min(cur + sib, total) { wanted.insert(page) }

        var result: [Int] = []
        var previous = 0
        for page in wanted.sorted() {
            if previous != 0 && page - previous > 1 {
                if page - previous == 2 { result.append(previous + 1) }   // fill a lone gap
                else { result.append(-1) }
            }
            result.append(page)
            previous = page
        }
        return result
    }
}

private extension View {
    /// Number-pad keyboard for the jumper field (iOS only).
    @ViewBuilder
    func jumperKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

public extension Pagination {
    /// Compact "current / total" mode instead of the numbered page buttons.
    func simple(_ on: Bool = true) -> Self { var copy = self; copy.simple = on; return copy }
    /// Window size: `sibling` pages each side of the current page, `boundary`
    /// pages pinned at each end (gaps collapse to an ellipsis).
    func window(sibling: Int = 1, boundary: Int = 1) -> Self {
        var copy = self; copy.siblingCount = sibling; copy.boundaryCount = boundary; return copy
    }
    /// Shows a quick-jumper field that jumps straight to a typed page number.
    func jumper(_ on: Bool = true, title: String = String(themeKit: "Go to")) -> Self {
        var copy = self; copy.showJumper = on; copy.jumperTitle = title; return copy
    }
    /// A leading summary label built from `(current, total)` — e.g. "50 pages".
    func showTotal(_ format: ((Int, Int) -> String)?) -> Self { var copy = self; copy.showTotal = format; return copy }
}

#Preview {
    struct Demo: View {
        @State var page = 4
        var body: some View {
            VStack(spacing: 20) {
                Pagination(current: $page, total: 10)
                Pagination(current: $page, total: 20).window(sibling: 2)
                Pagination(current: $page, total: 10).simple()
                Pagination(current: $page, total: 50).jumper().showTotal { _, t in "\(t) pages" }
            }
            .padding()
        }
    }
    return Demo()
}
