//
//  FareSummary.swift
//  ThemeKit
//
//  An itemised price breakdown — base fare, taxes/fees, discounts, and an emphasised
//  total. Token-bound; discounts read green, the total is a hero PriceTag. The entire
//  layout is a swappable ``FareSummaryStyle`` (ADR-0004) — the component owns the
//  fare *data*, the style owns the *arrangement*; see FareSummaryStyle.swift for the
//  three built-ins (`.list` default, `.receipt`, `.collapsed`).
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
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fareSummaryStyle) private var style

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
        currencyCode ?? formatDefaults.currencyCode ?? locale.themeKitCurrencyCode ?? "USD"
    }

    /// Reduce-Motion-gated toggle animation, resolved here (never by a style) and
    /// handed to ``FareSummaryConfiguration/toggleExpand`` as a plain closure.
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        style.makeBody(configuration: FareSummaryConfiguration(
            lines: lines,
            total: lines.last(where: { $0.kind == .total }),
            currencyCode: resolvedCurrency,
            onInfo: onInfoHandler,
            header: headerSlot,
            footer: footerSlot,
            totalSize: totalSize,
            totalEmphasis: totalEmphasis,
            showsDivider: showsDividerFlag,
            isExpandable: isExpandable,
            isExpanded: expandedState,
            toggleExpand: { withAnimation(motion) { expandedState.toggle() } },
            density: density,
            locale: locale))
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
    struct Demo: View {
        @State var expanded = true
        var body: some View {
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
    }
    return Demo()
}
