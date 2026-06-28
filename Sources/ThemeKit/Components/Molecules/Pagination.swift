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
    private let simple: Bool
    private let siblingCount: Int
    private let boundaryCount: Int
    private let showJumper: Bool
    private let jumperTitle: String
    private let isEnabled: Bool
    private let showTotal: ((Int, Int) -> String)?

    @State private var jumpText = ""

    public init(
        current: Binding<Int>,
        total: Int,
        simple: Bool = false,
        siblingCount: Int = 1,
        boundaryCount: Int = 1,
        showJumper: Bool = false,
        jumperTitle: String = String(themeKit: "Go to"),
        isEnabled: Bool = true,
        showTotal: ((Int, Int) -> String)? = nil
    ) {
        self._current = current
        self.total = max(total, 1)
        self.simple = simple
        self.siblingCount = siblingCount
        self.boundaryCount = boundaryCount
        self.showJumper = showJumper
        self.jumperTitle = jumperTitle
        self.isEnabled = isEnabled
        self.showTotal = showTotal
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let showTotal {
                Text(showTotal(current, total))
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .padding(.trailing, Theme.SpacingKey.xs.value)
            }

            arrow(systemName: "chevron.left", enabled: isEnabled && current > 1) { current = max(1, current - 1) }

            if simple {
                Text("\(current) / \(total)")
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                    .frame(minWidth: 48)
            } else {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                    if page == -1 {
                        Text("…").textStyle(.labelBase600).foregroundStyle(theme.text(.textTertiary)).frame(width: 36, height: 36)
                    } else {
                        pageButton(page)
                    }
                }
            }

            arrow(systemName: "chevron.right", enabled: isEnabled && current < total) { current = min(total, current + 1) }

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
        .disabled(!isEnabled)
        .accessibilityLabel(String(themeKit: "Page \(page)"))
    }

    private func arrow(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName, size: .sm,
                 color: enabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                .frame(width: 36, height: 36)
                .mirrorsInRTL()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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

#Preview {
    struct Demo: View {
        @State var page = 4
        var body: some View {
            VStack(spacing: 20) {
                Pagination(current: $page, total: 10)
                Pagination(current: $page, total: 20, siblingCount: 2)
                Pagination(current: $page, total: 10, simple: true)
                Pagination(current: $page, total: 50, showJumper: true, showTotal: { _, t in "\(t) pages" })
            }
            .padding()
        }
    }
    return Demo()
}
