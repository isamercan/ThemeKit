//
//  PageHeader.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. The design-system **Page Header** — the top section of a screen:
/// a back / menu leading slot, a center block (title, a two-line *search summary*,
/// or a search input), trailing icon actions, and an optional accessory band
/// (tabs, a progress line, or a stepper) beneath the bar.
///
/// Chrome is **style-driven** — set a ``PageHeaderStyle`` with `.pageHeaderStyle(_:)`:
///
/// ```swift
/// PageHeader("Antalya Hotels")
///     .onBack { dismiss() }
///     .searchSummary(caption: "12 – 16 Jul",
///                    chips: [.init(systemImage: "person", value: "2"),
///                            .init(systemImage: "bed.double", value: "1")])
///     .actions([.init(systemImage: "arrow.left.arrow.right") { compare() },
///               .init(systemImage: "magnifyingglass") { search() }])
///     .tabs(["Overview", "Rooms", "Reviews"], selected: tab) { tab = $0 }
///     .pageHeaderStyle(.plain)     // .brand / .onImage
/// ```
///
/// Content + actions live in `init` / provider closures; every appearance knob is
/// a chainable modifier. All colors, radii, spacing and type resolve from the
/// active `Theme`, so a preset / dark / brand change re-skins it.
public struct PageHeader: View {
    @Environment(\.pageHeaderStyle) private var style
    @Environment(\.locale) private var locale

    // MARK: Public value types

    /// A trailing icon action.
    public struct Action: Identifiable {
        public let id = UUID()
        let systemImage: String
        let handler: () -> Void
        let accessibilityLabel: String?
        public init(systemImage: String, accessibilityLabel: String? = nil, handler: @escaping () -> Void) {
            self.systemImage = systemImage
            self.accessibilityLabel = accessibilityLabel
            self.handler = handler
        }
    }

    /// A status tag shown next to the title (Ant PageHeader `tags`).
    public struct Tag: Identifiable {
        public let id = UUID()
        let text: String
        let style: BadgeStyle?
        public init(_ text: String, style: BadgeStyle? = nil) {
            self.text = text
            self.style = style
        }
    }

    /// A brand-soft primary pill in the trailing area (a call-to-action).
    public struct PrimaryButton {
        let title: String
        let systemImage: String?
        let action: () -> Void
        public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.action = action
        }
    }

    /// A center search input bound to the caller's text.
    public struct SearchField {
        let text: Binding<String>
        let placeholder: String
        let onSubmit: (() -> Void)?
    }

    /// A filled square button inside the On Map search card (filter / edit).
    public struct FilterButton {
        let systemImage: String
        let accessibilityLabel: String?
        let action: () -> Void
    }

    /// A custom leading icon button (menu / hamburger) in place of the back arrow.
    public struct LeadingIcon {
        let systemImage: String
        let handler: () -> Void
    }

    /// The band under the bar.
    public enum Accessory {
        case none
        /// A row of tabs with a hero underline on the selected index.
        case tabs(titles: [String], selected: Int, onSelect: (Int) -> Void)
        /// A hero progress line (0…1) across the bottom of the bar.
        case progress(Double)
        /// A segmented stepper: `current` of `total` filled.
        case stepper(current: Int, total: Int)
    }

    // MARK: Storage

    private let title: String
    private var subtitle: String?
    private var showTitle = true
    private var tags: [Tag] = []
    /// Bound ``SearchSummary`` sub-component shown as the center block.
    private var summary: SearchSummary?
    private var searchField: SearchField?
    private var logo: AnyView?
    private var onBack: (() -> Void)?
    private var leadingIcon: LeadingIcon?
    private var actions: [Action] = []
    private var primaryButton: PrimaryButton?
    private var filterButton: FilterButton?
    private var accessory: Accessory = .none

    public init(_ title: String) { self.title = title }   // content only

    public var body: some View {
        style.makeBody(configuration: PageHeaderConfiguration(
            title: title, subtitle: subtitle, showTitle: showTitle, tags: tags, summary: summary,
            searchField: searchField, logo: logo, onBack: onBack, leadingIcon: leadingIcon,
            actions: actions, primaryButton: primaryButton, filterButton: filterButton,
            accessory: accessory, locale: locale
        ))
    }
}

// MARK: - Modifiers (copy-on-write · content = init, appearance = modifiers)

public extension PageHeader {
    /// Secondary line under the title (plain-title center only).
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Hide the title (per-style `Show Title` toggle).
    func showTitle(_ show: Bool = true) -> Self { copy { $0.showTitle = show } }

    /// Status tags shown next to the title.
    func tags(_ tags: [Tag]) -> Self { copy { $0.tags = tags } }

    /// Bind a ``SearchSummary`` sub-component as the center block (date/guests,
    /// optionally with a location title and the boxed pill presentation).
    func searchSummary(_ summary: SearchSummary) -> Self { copy { $0.summary = summary } }

    /// Replace the center with a bound search input pill.
    func searchField(text: Binding<String>,
                     placeholder: String = "",
                     onSubmit: (() -> Void)? = nil) -> Self {
        copy { $0.searchField = SearchField(text: text, placeholder: placeholder, onSubmit: onSubmit) }
    }

    /// Replace the center with a brand logo (any view) — used by `.brand` chrome.
    func logo(_ view: some View) -> Self { copy { $0.logo = AnyView(view) } }

    /// Show a leading back button invoking `action`.
    func onBack(_ action: (() -> Void)?) -> Self { copy { $0.onBack = action } }

    /// A custom leading icon button (menu / hamburger) instead of the back arrow.
    func leading(systemImage: String, action: @escaping () -> Void) -> Self {
        copy { $0.leadingIcon = LeadingIcon(systemImage: systemImage, handler: action) }
    }

    /// Trailing icon actions.
    func actions(_ actions: [Action]) -> Self { copy { $0.actions = actions } }

    /// A trailing brand-soft primary pill (call-to-action).
    func primaryButton(_ title: String, systemImage: String? = nil,
                       action: @escaping () -> Void) -> Self {
        copy { $0.primaryButton = PrimaryButton(title, systemImage: systemImage, action: action) }
    }

    /// A filled square filter/edit button inside the On Map search card
    /// (`.onImage` chrome + a bound ``SearchSummary``).
    func mapFilter(systemImage: String, accessibilityLabel: String? = nil,
                   action: @escaping () -> Void) -> Self {
        copy { $0.filterButton = FilterButton(systemImage: systemImage,
                                              accessibilityLabel: accessibilityLabel, action: action) }
    }

    /// Accessory band: a tab row with a hero underline on `selected`.
    func tabs(_ titles: [String], selected: Int, onSelect: @escaping (Int) -> Void) -> Self {
        copy { $0.accessory = .tabs(titles: titles, selected: selected, onSelect: onSelect) }
    }

    /// Accessory band: a hero progress line across the bottom (0…1).
    func progress(_ fraction: Double) -> Self { copy { $0.accessory = .progress(fraction) } }

    /// Accessory band: a segmented stepper — `current` of `total` filled.
    func stepper(current: Int, total: Int) -> Self {
        copy { $0.accessory = .stepper(current: current, total: total) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Plain — variants") {
    VStack(spacing: 20) {
        PageHeader("Antalya Hotels")
            .onBack {}
            .searchSummary(SearchSummary(time: "12 – 16 Jul", adults: 2).title("Antalya Hotels").children(1).rooms(1))
            .actions([.init(systemImage: "square.on.square") {},
                      .init(systemImage: "magnifyingglass") {}])

        PageHeader("Title")
            .onBack {}
            .tabs(["Tab 1", "Tab 2", "Tab 3", "Tab 4"], selected: 0) { _ in }
            .actions([.init(systemImage: "magnifyingglass") {}])

        PageHeader("Title").onBack {}.progress(0.4)
            .actions([.init(systemImage: "magnifyingglass") {}])

        PageHeader("Title").onBack {}.stepper(current: 1, total: 4)

        PageHeader("Title")
            .primaryButton("Set alert", systemImage: "bell.fill") {}
            .actions([.init(systemImage: "magnifyingglass") {}])
    }
    .padding(.vertical)
    .environment(Theme.shared)
}

#Preview("Brand + On-image") {
    VStack(spacing: 20) {
        PageHeader("Brand")
            .logo(Text("etstur").font(.system(size: 22, weight: .heavy)).foregroundStyle(SemanticColor.primary.onSolid))
            .pageHeaderStyle(.brand)

        PageHeader("Hotel Details")
            .onBack {}
            .actions([.init(systemImage: "heart") {}, .init(systemImage: "xmark") {}])
            .pageHeaderStyle(.onImage)
            .background(SemanticColor.primary.solid)
    }
    .padding(.vertical)
    .environment(Theme.shared)
}
