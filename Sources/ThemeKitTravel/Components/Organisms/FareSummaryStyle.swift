//
//  FareSummaryStyle.swift
//  ThemeKit
//
//  The styling hook for ``FareSummary`` (ADR-0004, Wave 3): the configuration
//  hands styles the *typed fare lines* (item / discount / total, already
//  currency-resolved), not pre-laid content, so a style owns the entire
//  arrangement. Three built-ins:
//
//    .list       labeled lines + a hero total under a divider — today's
//                breakdown, verbatim. Default.
//    .receipt    printed-receipt look: overline labels joined to their value
//                by a dotted leader, closed by a dashed rule + total.
//    .collapsed  total-first row that discloses the itemised lines on tap.
//
//      FareSummary([.item("Base fare", 1_100), .total("Total", 1_199)])
//          .fareSummaryStyle(.receipt)
//
//  Money colours stay semantic-fixed everywhere: discounts always read
//  success/green, the total is always the hero `PriceTag` emphasis the caller
//  picked with `.totalEmphasis(_:)` — there is no `accent(_:)` axis on this
//  configuration, on purpose (a fare breakdown is not brand chrome to retint).
//  Expansion state (`ControllableState`) and its Reduce-Motion-gated animation
//  both stay in the component — styles only ever read
//  ``FareSummaryConfiguration/isExpanded`` and call
//  ``FareSummaryConfiguration/toggleExpand``.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FareSummaryStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no ``total`` line → no total row; `onInfo == nil`
/// → no info affordance, even on lines carrying `info` text).
public struct FareSummaryConfiguration {
    /// Every line, in the order the caller supplied — items, discounts, and
    /// (usually) one total, unfiltered. Styles decide for themselves what to
    /// show while collapsed via ``isExpanded``.
    public let lines: [FareLine]
    /// The breakdown's total — the last `.total`-kind entry in ``lines``,
    /// hoisted for styles that render it apart from the itemised body (e.g.
    /// ``CollapsedFareSummaryStyle``'s total-first row). `nil` when no line
    /// was built with `.total(...)`.
    public let total: FareLine?
    /// Currency code — already resolved by the component through the
    /// FormatDefaults chain (explicit `.currency(_:)` → `formatDefaults` →
    /// `locale.currency` → `"USD"`).
    public let currencyCode: String
    /// Called when a line's info button is tapped; `nil` hides every info
    /// affordance (only lines created with `info:` show one, and only when
    /// this is set — mirrors `FareSummary.onInfo(_:)`).
    public let onInfo: ((FareLine) -> Void)?
    /// Replacement for the built-in header slot (`.header { }`); `nil` = none.
    public let header: AnyView?
    /// Replacement for the built-in footer slot (`.footer { }`); `nil` = none.
    public let footer: AnyView?
    /// Size of the total `PriceTag` (`.totalSize(_:)`, default `.large`).
    public let totalSize: PriceSize
    /// Colour emphasis of the total `PriceTag` (`.totalEmphasis(_:)`, default `.hero`).
    public let totalEmphasis: PriceEmphasis
    /// Draws the divider/rule above the total row (`.showsDivider(_:)`, default on).
    public let showsDivider: Bool
    /// `true` once `.expandable()` / `.expandable(_:)` was called — gates
    /// whether the disclosure affordance shows at all. Styles built around
    /// *always* disclosing (``CollapsedFareSummaryStyle``) read ``isExpanded``
    /// / ``toggleExpand`` directly and ignore this flag.
    public let isExpandable: Bool
    /// Expanded/collapsed read state (`ControllableState`, ADR-F4) — the
    /// component owns the storage; styles only read it.
    public let isExpanded: Bool
    /// Flips ``isExpanded`` (Reduce-Motion aware; resolved by the component,
    /// never by a style). Styles with a disclosure affordance call this.
    public let toggleExpand: () -> Void
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// currency string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// Every non-total line, in order — the itemised body most styles render
    /// separately from ``total``.
    public var itemLines: [FareLine] { lines.filter { $0.kind != .total } }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the breakdown.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// Locale + currency-formatted amount, matching the component's own formatting.
    public func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale))
    }

    /// A line's displayed value — discounts render with a leading minus,
    /// everything else renders the plain formatted amount.
    public func displayAmount(for line: FareLine) -> String {
        line.kind == .discount ? "-\(formatted(line.amount))" : formatted(line.amount)
    }
}

// MARK: - Protocol

/// Defines a `FareSummary`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's fare lines. Set one with `.fareSummaryStyle(_:)`;
/// the default is ``ListFareSummaryStyle``.
public protocol FareSummaryStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FareSummaryConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// A horizontal 1pt line path (dash-friendly) — mirrors the private `Line`
/// shape declared per-file across the suite (`FlightListItemStyle`,
/// `LayoverRow`); redeclared here rather than shared, per house convention.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// The `.receipt` leader — a tight dotted rule that fills the space between a
/// label and its value, like a printed price list. Flipped under RTL so the
/// dash phase stays anchored consistently with the row's mirrored order.
private struct DottedLeader: View {
    let color: Color
    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4]))
            .frame(height: 6)
            .frame(maxWidth: .infinity)
            .flipsForRightToLeftLayoutDirection(true)
    }
}

/// The `.receipt` / `.collapsed` info affordance — `.list` keeps its
/// byte-identical original rendering (a raw `Image`, sized to match its
/// existing body text), so it doesn't route through this helper.
private struct FareInfoButton: View {
    let line: FareLine
    let onInfo: (FareLine) -> Void

    var body: some View {
        Button { onInfo(line) } label: {
            Icon(systemName: "info.circle").size(.xs).accent(.neutral)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKit: "More about \(line.label)"))
    }
}

/// The `.receipt` / `.collapsed` disclosure chevron.
private struct FareDisclosureChevron: View {
    let isExpanded: Bool
    var body: some View {
        Icon(systemName: "chevron.down").size(.xs).accent(.neutral)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .accessibilityHidden(true)   // the row's own a11y label announces the state
    }
}

// MARK: - .list

/// Today's ``FareSummary`` look, extracted verbatim: labeled item/discount
/// lines, an optional per-line info button, and a divider-topped hero total —
/// collapsible behind the total row once `.expandable()` is set.
public struct ListFareSummaryStyle: FareSummaryStyle {
    public init() {}
    public func makeBody(configuration: FareSummaryConfiguration) -> some View {
        ListFareSummaryChrome(configuration: configuration)
    }
}

private struct ListFareSummaryChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FareSummaryConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header }
            // Position-keyed: robust to duplicate labels (two "Fee" lines) which would
            // collide on the content-derived `id`. Fare lists are fixed-order, so index is stable.
            ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                switch line.kind {
                case .item:
                    itemRow(line, value: configuration.formatted(line.amount),
                            color: theme.text(.textSecondary), valueColor: theme.text(.textPrimary))
                case .discount:
                    itemRow(line, value: configuration.displayAmount(for: line),
                            color: theme.foreground(.systemcolorsFgSuccess),
                            valueColor: theme.foreground(.systemcolorsFgSuccess))
                case .total:
                    totalRow(line)
                }
            }
            if let footer = configuration.footer { footer }
        }
    }

    /// Collapsed (`.expandable…`, chevron up) shows only the total row(s);
    /// expanded — and the non-expandable default — shows every line in order.
    private var visibleLines: [FareLine] {
        (configuration.isExpandable && !configuration.isExpanded)
            ? configuration.lines.filter { $0.kind == .total }
            : configuration.lines
    }

    private func itemRow(_ line: FareLine, value: String, color: Color, valueColor: Color) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(line.label).textStyle(.bodyBase400).foregroundStyle(color)
            if line.info != nil, let onInfo = configuration.onInfo {
                Button { onInfo(line) } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "More about \(line.label)"))
            }
            Spacer()
            Text(value).textStyle(.bodyBase500).foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.label) \(value)")
    }

    @ViewBuilder private func totalRow(_ line: FareLine) -> some View {
        VStack(spacing: configuration.spacing(.sm)) {
            if configuration.showsDivider { Divider().overlay(theme.border(.borderPrimary)) }
            if configuration.isExpandable {
                Button(action: configuration.toggleExpand) {
                    totalContent(line)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(configuration.isExpanded
                    ? String(themeKit: "Hide fare breakdown")
                    : String(themeKit: "Show fare breakdown"))
            } else {
                totalContent(line)
            }
        }
    }

    private func totalContent(_ line: FareLine) -> some View {
        HStack {
            Text(line.label).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
            if configuration.isExpandable {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.text(.textTertiary))
                    .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                    .accessibilityHidden(true)   // the row's a11y label announces the state
            }
            Spacer()
            PriceTag(line.amount, currencyCode: configuration.currencyCode)
                .size(configuration.totalSize).emphasis(configuration.totalEmphasis).animatesValue()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - .receipt

/// A printed-receipt look: every item/discount line is an overline label
/// joined to its value by a dotted leader, closed by a dashed rule and the
/// total. Honours ``FareSummaryConfiguration/isExpandable``/`isExpanded`
/// exactly like `.list` — the leader/rule treatment is purely visual.
public struct ReceiptFareSummaryStyle: FareSummaryStyle {
    public init() {}
    public func makeBody(configuration: FareSummaryConfiguration) -> some View {
        ReceiptFareSummaryChrome(configuration: configuration)
    }
}

private struct ReceiptFareSummaryChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FareSummaryConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header }
            ForEach(Array(visibleItemLines.enumerated()), id: \.offset) { _, line in
                leaderRow(line)
            }
            if let total = configuration.total {
                if configuration.showsDivider { DividerView().dashed() }
                totalRow(total)
            }
            if let footer = configuration.footer { footer }
        }
    }

    /// Item/discount lines — hidden while collapsed, same gate as `.list`.
    private var visibleItemLines: [FareLine] {
        (configuration.isExpandable && !configuration.isExpanded) ? [] : configuration.itemLines
    }

    private func leaderRow(_ line: FareLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            Text(line.label.uppercased())
                .textStyle(.overline400)
                .foregroundStyle(line.kind == .discount
                    ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textSecondary))
                .lineLimit(1)
            DottedLeader(color: theme.border(.borderPrimary))
            if line.info != nil, let onInfo = configuration.onInfo {
                FareInfoButton(line: line, onInfo: onInfo)
            }
            Text(configuration.displayAmount(for: line))
                .textStyle(.labelSm600)
                .foregroundStyle(line.kind == .discount
                    ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textPrimary))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.label) \(configuration.displayAmount(for: line))")
    }

    @ViewBuilder private func totalRow(_ line: FareLine) -> some View {
        if configuration.isExpandable {
            Button(action: configuration.toggleExpand) { totalContent(line) }
                .buttonStyle(.plain)
                .accessibilityLabel(configuration.isExpanded
                    ? String(themeKit: "Hide fare breakdown")
                    : String(themeKit: "Show fare breakdown"))
        } else {
            totalContent(line)
        }
    }

    private func totalContent(_ line: FareLine) -> some View {
        HStack {
            Text(line.label.uppercased()).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
            if configuration.isExpandable { FareDisclosureChevron(isExpanded: configuration.isExpanded) }
            Spacer()
            PriceTag(line.amount, currencyCode: configuration.currencyCode)
                .size(configuration.totalSize).emphasis(configuration.totalEmphasis).animatesValue()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - .collapsed

/// A total-first row that always discloses the itemised lines on tap —
/// unlike `.list`/`.receipt`, this style reads ``FareSummaryConfiguration/isExpanded``
/// directly (it *is* the disclosure affordance, so `isExpandable` is
/// irrelevant to it); pair with `.expandable()`/`.expandable(_:)` only when
/// the caller needs to observe or drive the flag from outside.
public struct CollapsedFareSummaryStyle: FareSummaryStyle {
    public init() {}
    public func makeBody(configuration: FareSummaryConfiguration) -> some View {
        CollapsedFareSummaryChrome(configuration: configuration)
    }
}

private struct CollapsedFareSummaryChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FareSummaryConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            if let header = configuration.header { header }
            totalRow
            if configuration.isExpanded {
                VStack(spacing: configuration.spacing(.xs)) {
                    if configuration.showsDivider { Divider().overlay(theme.border(.borderPrimary)) }
                    ForEach(Array(configuration.itemLines.enumerated()), id: \.offset) { _, line in
                        itemRow(line)
                    }
                }
            }
            if let footer = configuration.footer { footer }
        }
    }

    private var totalRow: some View {
        Button(action: configuration.toggleExpand) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.total?.label ?? String(themeKit: "Total"))
                        .textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                    Text(configuration.isExpanded
                        ? String(themeKit: "Hide breakdown")
                        : String(themeKit: "Show breakdown"))
                        .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
                Spacer()
                if let total = configuration.total {
                    PriceTag(total.amount, currencyCode: configuration.currencyCode)
                        .size(configuration.totalSize).emphasis(configuration.totalEmphasis).animatesValue()
                }
                FareDisclosureChevron(isExpanded: configuration.isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isExpanded
            ? String(themeKit: "Hide fare breakdown")
            : String(themeKit: "Show fare breakdown"))
    }

    private func itemRow(_ line: FareLine) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(line.label).textStyle(.bodySm400).foregroundStyle(line.kind == .discount
                ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textSecondary))
            if line.info != nil, let onInfo = configuration.onInfo {
                FareInfoButton(line: line, onInfo: onInfo)
            }
            Spacer()
            Text(configuration.displayAmount(for: line))
                .textStyle(.bodySm500)
                .foregroundStyle(line.kind == .discount
                    ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textPrimary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.label) \(configuration.displayAmount(for: line))")
    }
}

// MARK: - Static accessors

public extension FareSummaryStyle where Self == ListFareSummaryStyle {
    /// Labeled item/discount lines + a divider-topped hero total. The default.
    static var list: ListFareSummaryStyle { ListFareSummaryStyle() }
}
public extension FareSummaryStyle where Self == ReceiptFareSummaryStyle {
    /// Printed-receipt look: overline labels joined to their value by a
    /// dotted leader, closed by a dashed rule + total.
    static var receipt: ReceiptFareSummaryStyle { ReceiptFareSummaryStyle() }
}
public extension FareSummaryStyle where Self == CollapsedFareSummaryStyle {
    /// Total-first row that discloses the itemised lines on tap.
    static var collapsed: CollapsedFareSummaryStyle { CollapsedFareSummaryStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFareSummaryStyle: FareSummaryStyle {
    private let _makeBody: @MainActor (FareSummaryConfiguration) -> AnyView
    init<S: FareSummaryStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FareSummaryConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FareSummaryStyleKey: EnvironmentKey {
    static let defaultValue = AnyFareSummaryStyle(ListFareSummaryStyle())
}

extension EnvironmentValues {
    var fareSummaryStyle: AnyFareSummaryStyle {
        get { self[FareSummaryStyleKey.self] }
        set { self[FareSummaryStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FareSummaryStyle`` for `FareSummary`s in this view and its
    /// descendants — one screen can mix archetypes per section.
    func fareSummaryStyle<S: FareSummaryStyle>(_ style: sending S) -> some View {
        environment(\.fareSummaryStyle, AnyFareSummaryStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a compact single-line "N items · Total" summary that expands to the
/// full breakdown, no divider chrome at all.
private struct OneLineFareSummaryStyle: FareSummaryStyle {
    func makeBody(configuration: FareSummaryConfiguration) -> some View {
        OneLineChrome(configuration: configuration)
    }

    private struct OneLineChrome: View {
        @Environment(\.theme) private var theme
        let configuration: FareSummaryConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                Button(action: configuration.toggleExpand) {
                    HStack {
                        Text(String(themeKit: "\(configuration.itemLines.count) items"))
                            .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                        Spacer()
                        if let total = configuration.total {
                            PriceTag(total.amount, currencyCode: configuration.currencyCode)
                                .size(.medium).emphasis(.hero)
                        }
                    }
                }
                .buttonStyle(.plain)
                if configuration.isExpanded {
                    ForEach(Array(configuration.itemLines.enumerated()), id: \.offset) { _, line in
                        HStack {
                            Text(line.label).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                            Spacer()
                            Text(configuration.displayAmount(for: line))
                                .textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                        }
                    }
                }
            }
        }
    }
}

#Preview("FareSummaryStyle — presets × light/dark") {
    struct Demo: View {
        @State var collapsedOpen = true
        var body: some View {
            let lines: [FareLine] = [
                .item("Base fare", 1_100),
                .item("Taxes & fees", 199, info: "Airport tax + carrier surcharge"),
                .discount("Member discount", 100),
                .total("Total", 1_199),
            ]
            return PreviewMatrix("FareSummaryStyle") {
                PreviewCase("List (default)") { FareSummary(lines).onInfo { _ in } }
                PreviewCase("List · expandable") { FareSummary(lines).onInfo { _ in }.expandable() }
                PreviewCase("Receipt") { FareSummary(lines).onInfo { _ in }.fareSummaryStyle(.receipt) }
                PreviewCase("Receipt · expandable") {
                    FareSummary(lines).onInfo { _ in }.expandable().fareSummaryStyle(.receipt)
                }
                // `.collapsed` reads isExpanded/toggleExpand directly; pair with `.expandable()`
                // to start closed (its own uncontrolled default is otherwise `true` — the same
                // idle value `.list`/`.receipt` carry when expansion was never requested).
                PreviewCase("Collapsed") { FareSummary(lines).onInfo { _ in }.expandable().fareSummaryStyle(.collapsed) }
                PreviewCase("Collapsed · open") {
                    FareSummary(lines).onInfo { _ in }.expandable($collapsedOpen).fareSummaryStyle(.collapsed)
                }
                PreviewCase("Custom (in-preview)") {
                    FareSummary(lines).expandable().fareSummaryStyle(OneLineFareSummaryStyle())
                }
            }
        }
    }
    return Demo()
}
