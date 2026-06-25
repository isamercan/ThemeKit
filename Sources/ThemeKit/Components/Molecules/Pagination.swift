//
//  Pagination.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Numbered pagination with prev / next, windowed around the current
//  page, plus a simple mode, an optional total label and a disabled state.
//  (Ant Pagination parity.) Selection owned by the caller.
//

import SwiftUI

public struct Pagination: View {
    @Binding private var current: Int   // 1-based
    private let total: Int
    private let simple: Bool
    private let isEnabled: Bool
    private let showTotal: ((Int, Int) -> String)?

    public init(
        current: Binding<Int>,
        total: Int,
        simple: Bool = false,
        isEnabled: Bool = true,
        showTotal: ((Int, Int) -> String)? = nil
    ) {
        self._current = current
        self.total = max(total, 1)
        self.simple = simple
        self.isEnabled = isEnabled
        self.showTotal = showTotal
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let showTotal {
                Text(showTotal(current, total))
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
                    .padding(.trailing, Theme.SpacingKey.xs.value)
            }

            arrow(systemName: "chevron.left", enabled: isEnabled && current > 1) { current = max(1, current - 1) }

            if simple {
                Text("\(current) / \(total)")
                    .textStyle(.labelBase600)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                    .frame(minWidth: 48)
            } else {
                ForEach(pages, id: \.self) { page in
                    if page == -1 {
                        Text("…").textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textTertiary)).frame(width: 36, height: 36)
                    } else {
                        pageButton(page)
                    }
                }
            }

            arrow(systemName: "chevron.right", enabled: isEnabled && current < total) { current = min(total, current + 1) }
        }
        .opacity(isEnabled ? 1 : 0.5)
    }

    /// Windowed page list with -1 sentinels for ellipses.
    private var pages: [Int] {
        if total <= 5 { return Array(1...total) }
        var result: [Int] = [1]
        let lower = max(2, current - 1)
        let upper = min(total - 1, current + 1)
        if lower > 2 { result.append(-1) }
        result.append(contentsOf: lower...upper)
        if upper < total - 1 { result.append(-1) }
        result.append(total)
        return result
    }

    private func pageButton(_ page: Int) -> some View {
        let isCurrent = page == current
        return Button { if isEnabled { current = page } } label: {
            Text("\(page)")
                .textStyle(.labelBase600)
                .foregroundStyle(isCurrent ? Theme.shared.foreground(.fgSecondary) : Theme.shared.text(.textPrimary))
                .frame(width: 36, height: 36)
                .background(isCurrent ? Theme.shared.background(.bgHero) : .clear, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: isCurrent ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func arrow(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName, size: .sm,
                 color: enabled ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textDisabled))
                .frame(width: 36, height: 36)
                .mirrorsInRTL()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    struct Demo: View {
        @State var page = 4
        var body: some View {
            VStack(spacing: 20) {
                Pagination(current: $page, total: 10)
                Pagination(current: $page, total: 10, simple: true)
                Pagination(current: $page, total: 10, showTotal: { _, t in "\(t) pages" })
            }
            .padding()
        }
    }
    return Demo()
}
