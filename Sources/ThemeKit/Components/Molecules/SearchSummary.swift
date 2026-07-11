//
//  SearchSummary.swift
//  ThemeKit
//
//  Molecule. A compact travel search summary — an optional location title over a
//  `date · guests` line: the date range, then `adults · children · rooms` chips
//  separated from the date by a soft hairline. Mirrors the design-system
//  "Search summary" element used inside ``PageHeader`` (and reusable on its own).
//
//  Two independent axes (the design-system Selected × Bg matrix):
//    • content — the filled guest summary, or a hero **prompt** empty state
//      ("select dates") via `.prompt(_:)`
//    • container — flush/inline, or a soft **boxed** pill via `.boxed()`
//
//      SearchSummary(time: "12 – 16 Jul", adults: 2)
//          .title("Antalya Hotels").children(1).rooms(1)
//          .boxed()                     // the pill presentation
//          .onTap { editSearch() }      // tappable to re-open the search
//
//  Token-bound and brand-neutral: numbers + a preformatted date string in, no
//  domain model. Icons are configurable SF Symbols with travel defaults.
//

import SwiftUI

public struct SearchSummary: View {
    @Environment(\.theme) private var theme

    private let time: String?
    private let adults: Int
    // Content/appearance — mutated only through the modifiers below.
    private var title: String?
    private var children: Int?
    private var rooms: Int?
    private var boxed = false
    private var showsPrompt = false
    private var promptText: String?
    private var onTap: (() -> Void)?
    private var adultIcon = "person.fill"
    private var childIcon = "figure.child"
    private var roomIcon = "bed.double.fill"

    public init(time: String?, adults: Int) {
        self.time = time
        self.adults = adults
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { container }.buttonStyle(.plain)
        } else {
            container
        }
    }

    private var container: some View {
        content
            .padding(.horizontal, boxed ? Theme.SpacingKey.sm.value : 0)
            .padding(.vertical, boxed ? Theme.SpacingKey.xs.value : 0)
            .frame(maxWidth: boxed ? .infinity : nil)
            .frame(minHeight: boxed ? Theme.SpacingKey.lg.value : nil)   // 32pt pill
            .background {
                if boxed {
                    shape.fill(theme.background(.bgElevatorPrimary))
                        .overlay(shape.strokeBorder(theme.background(.bgElevatorTertiary), lineWidth: 1))
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var content: some View {
        if showsPrompt {
            // Empty state — a hero call-to-action instead of the guest summary.
            Text(promptText ?? String(themeKit: "Select dates for price"))
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textHero))
                .lineLimit(1)
        } else if let title {
            VStack(spacing: 0) {
                Text(title)
                    .textStyle(.bodyMd500)
                    .foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                summaryLine
            }
        } else {
            summaryLine
        }
    }

    /// `date · | · adults · children · rooms`.
    private var summaryLine: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let time {
                Text(time)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .opacity(0.9)
                    .fixedSize(horizontal: true, vertical: false)
            }
            if time != nil {
                Rectangle().fill(theme.background(.bgElevatorTertiary)).frame(width: 1, height: 12)
            }
            HStack(spacing: Theme.SpacingKey.xs.value) {
                paxChip(adultIcon, adults)
                if let children { paxChip(childIcon, children) }
                if let rooms { paxChip(roomIcon, rooms) }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func paxChip(_ systemImage: String, _ value: Int) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Icon(systemName: systemImage).size(.xs).colorOverride(theme.text(.textTertiary))
            Text("\(value)")
                .textStyle(.bodySm400)
                .foregroundStyle(theme.text(.textTertiary))
                .opacity(0.9)
        }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension SearchSummary {
    /// Location title shown above the date/guests line.
    func title(_ text: String?) -> Self { copy { $0.title = text } }
    /// Children count chip (hidden when `nil`).
    func children(_ count: Int?) -> Self { copy { $0.children = count } }
    /// Rooms count chip (hidden when `nil`).
    func rooms(_ count: Int?) -> Self { copy { $0.rooms = count } }
    /// Wrap in the soft pill surface (bg + hairline) — the search-bar presentation.
    func boxed(_ on: Bool = true) -> Self { copy { $0.boxed = on } }
    /// Empty state — replace the guest summary with a hero call-to-action (e.g.
    /// "select dates"); pass a custom message or use the default.
    func prompt(_ text: String? = nil) -> Self { copy { $0.showsPrompt = true; $0.promptText = text } }
    /// Make the whole summary tappable (re-open the search).
    func onTap(_ action: @escaping () -> Void) -> Self { copy { $0.onTap = action } }
    /// Override the guest icons (defaults: person / child / bed).
    func icons(adult: String? = nil, child: String? = nil, room: String? = nil) -> Self {
        copy {
            if let adult { $0.adultIcon = adult }
            if let child { $0.childIcon = child }
            if let room { $0.roomIcon = room }
        }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview("States: data/prompt × inline/boxed") {
    PreviewMatrix("SearchSummary") {
        PreviewCase("data · inline") { SearchSummary(time: "12 – 16 Jul", adults: 2).children(1).rooms(1) }
        PreviewCase("data · boxed") { SearchSummary(time: "12 – 16 Jul", adults: 2).children(1).rooms(1).boxed() }
        PreviewCase("prompt · inline") { SearchSummary(time: nil, adults: 0).prompt() }
        PreviewCase("prompt · boxed") { SearchSummary(time: nil, adults: 0).prompt().boxed() }
        PreviewCase("with title") { SearchSummary(time: "12 – 16 Jul", adults: 2).title("Antalya Hotels").children(1).rooms(1) }
    }
    .environment(Theme.shared)
}
