//
//  FareSummary.swift
//  ThemeKit
//
//  An itemised price breakdown — base fare, taxes/fees, discounts, and an emphasised
//  total. Token-bound; discounts read green, the total is a hero PriceTag.
//
//  Flexible: per-line info buttons (.onInfo), a footer slot (a note or CTA), an
//  animated total, and density-aware spacing. Honours `.redacted(.placeholder)`.
//

import SwiftUI
import ThemeKit

/// A token-bound fare breakdown.
///
/// ```swift
/// FareSummary([
///     .item("Base fare", 1_100),
///     .item("Taxes & fees", 199, info: "Airport tax + carrier surcharge"),
///     .discount("Member discount", 100),
///     .total("Total", 1_199),
/// ]).onInfo { line in showSheet(line.info) } footer: { TermsLink() }
/// ```
public struct FareSummary: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lines: [FareLine]
    private var currencyCode: String?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var onInfoHandler: ((FareLine) -> Void)?
    private var footerSlot: AnyView?
    private var headerSlot: AnyView?
    private var showsDividerFlag = true
    private var totalSize: PriceSize = .large
    private var totalEmphasis: PriceEmphasis = .hero
    /// Expanded/collapsed — dual-mode via `ControllableState` (ADR-F4). Inert
    /// until `isExpandable`; the uncontrolled form starts collapsed.
    @ControllableState private var expandedState = true
    private var isExpandable = false

    public init(_ lines: [FareLine], currencyCode: String = "USD") {   // R1 — content
        self.lines = lines
        self.currencyCode = currencyCode
    }

    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    public init(_ lines: [FareLine]) {   // R1 — content
        self.lines = lines
        self.currencyCode = nil
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let headerSlot { headerSlot }
            // Position-keyed: robust to duplicate labels (two "Fee" lines) which would
            // collide on the content-derived `id`. Fare lists are fixed-order, so index is stable.
            ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                switch line.kind {
                case .item:
                    itemRow(line, value: formatted(line.amount),
                            color: theme.text(.textSecondary), valueColor: theme.text(.textPrimary))
                case .discount:
                    itemRow(line, value: "-\(formatted(line.amount))",
                            color: theme.foreground(.systemcolorsFgSuccess),
                            valueColor: theme.foreground(.systemcolorsFgSuccess))
                case .total:
                    totalRow(line)
                }
            }
            if let footerSlot { footerSlot }
        }
    }

    /// Collapsed (`.expandable…`, chevron up) shows only the total row(s);
    /// expanded — and the non-expandable default — shows every line in order.
    @MainActor private var visibleLines: [FareLine] {
        (isExpandable && !expandedState) ? lines.filter { $0.kind == .total } : lines
    }

    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private func itemRow(_ line: FareLine, value: String, color: Color, valueColor: Color) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(line.label).textStyle(.bodyBase400).foregroundStyle(color)
            if line.info != nil, let onInfoHandler {
                Button { onInfoHandler(line) } label: {
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

    @MainActor
    @ViewBuilder private func totalRow(_ line: FareLine) -> some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if showsDividerFlag { Divider().overlay(theme.border(.borderPrimary)) }
            if isExpandable {
                Button {
                    withAnimation(motion) { expandedState.toggle() }
                } label: {
                    totalContent(line)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expandedState
                    ? String(themeKit: "Hide fare breakdown")
                    : String(themeKit: "Show fare breakdown"))
            } else {
                totalContent(line)
            }
        }
    }

    @MainActor
    private func totalContent(_ line: FareLine) -> some View {
        HStack {
            Text(line.label).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
            if isExpandable {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.text(.textTertiary))
                    .rotationEffect(.degrees(expandedState ? 180 : 0))
                    .accessibilityHidden(true)   // the row's a11y label announces the state
            }
            Spacer()
            PriceTag(line.amount, currencyCode: resolvedCurrency)
                .size(totalSize).emphasis(totalEmphasis).animatesValue()
        }
        .contentShape(Rectangle())
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareSummary {
    /// Called when a line's info button is tapped (only lines created with `info:` show one).
    func onInfo(_ handler: @escaping (FareLine) -> Void) -> Self { copy { $0.onInfoHandler = handler } }
    /// A footer slot under the total — a terms link, a CTA, a note.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }
    /// A header slot above the breakdown — a title, a route recap, a caption.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// Makes the breakdown collapsible behind the total row, bound to the
    /// caller's expansion flag (controlled). Collapsed, only the total row and
    /// a chevron show; tapping the row toggles (Reduce-Motion aware).
    func expandable(_ isExpanded: Binding<Bool>) -> Self {
        copy {
            $0.isExpandable = true
            $0._expandedState = ControllableState(wrappedValue: true, external: isExpanded)
        }
    }
    /// A self-managed collapsible breakdown (uncontrolled) — starts collapsed
    /// on the total row. Use ``expandable(_:)`` when the flag must persist.
    func expandable() -> Self {
        copy {
            $0.isExpandable = true
            $0._expandedState = ControllableState(wrappedValue: false)
        }
    }
    /// Size of the total `PriceTag` (default `.large`).
    func totalSize(_ s: PriceSize) -> Self { copy { $0.totalSize = s } }
    /// Emphasis of the total `PriceTag` (default `.hero`).
    func totalEmphasis(_ e: PriceEmphasis) -> Self { copy { $0.totalEmphasis = e } }
    /// Draw the divider above the total row (default on).
    func showsDivider(_ on: Bool) -> Self { copy { $0.showsDividerFlag = on } }
    /// Currency code for every line. Unset, the init parameter wins, then
    /// `\.formatDefaults`, the locale's currency, and "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var expanded = true
    ScrollView {
        VStack(spacing: 28) {
            FareSummary([
                .item("Base fare", 1_100),
                .item("Taxes & fees", 199, info: "Airport tax + carrier surcharge"),
                .discount("Member discount", 100),
                .total("Total", 1_199),
            ])
            .onInfo { _ in }
            // Header slot + EUR override + smaller, standard-emphasis total, no divider.
            FareSummary([
                .item("Base fare", 480),
                .item("Seat selection", 24),
                .total("Total", 504),
            ])
            .header { Text("Price details").textStyle(.labelBase700) }
            .currency("EUR")
            .totalSize(.medium).totalEmphasis(.standard)
            .showsDivider(false)
            // Uncontrolled expandable — starts collapsed on the total row.
            FareSummary([
                .item("Base fare", 1_100),
                .item("Taxes & fees", 199),
                .total("Total", 1_299),
            ])
            .expandable()
            // Controlled expandable, initially open.
            FareSummary([
                .item("Base fare", 2_050),
                .discount("Promo", 150),
                .total("Total", 1_900),
            ])
            .expandable($expanded)
        }
        .padding()
    }
}
