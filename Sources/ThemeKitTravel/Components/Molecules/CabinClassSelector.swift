//
//  CabinClassSelector.swift
//  ThemeKitTravel
//
//  Edition molecule (F2.1 · §9.5): economy / premium economy / business / first
//  selection. A pure wrapper — zero bespoke chrome — over the neutral kit's
//  `SegmentedControl` (default), `Chip` row, or `RadioGroup` (`.list`, for
//  sheet contexts), keyed by the canonical `CabinClass` model. Presentation is
//  style-driven (``CabinClassSelectorStyle``, ADR-0004) — set once per screen
//  via `.cabinClassSelectorStyle(_:)`.
//

import SwiftUI
import ThemeKit

// MARK: - Variant

/// How ``CabinClassSelector`` renders its options: an inline `SegmentedControl`
/// (default), a horizontally-scrolling `Chip` row, `RadioGroup`-style rows
/// for sheet contexts, or a 2×2 grid of selectable `.cards` (glyph + label +
/// optional description).
///
/// Superseded by ``CabinClassSelectorStyle`` (each case maps 1:1 to a preset —
/// `.segmented`/`.chips`/`.list`/`.cards`); kept for source compatibility until
/// the next major, together with the deprecated ``CabinClassSelector/variant(_:)``
/// modifier.
public enum CabinClassVariant: Sendable { case segmented, chips, list, cards }

/// Control-size ramp forwarded to the wrapped kit controls (`SegmentedControl`
/// / `Chip`); `.cards` steps its padding on the same ramp. `.list` keeps the
/// stock `RadioGroup` anatomy.
public enum CabinClassSelectorSize: Sendable {
    case small, medium, large

    var segmented: SegmentedSize {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
    var chip: ChipSize {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
    /// Vertical padding step for the `.cards` grid.
    var cardPadding: CGFloat {
        switch self {
        case .small: Theme.SpacingKey.sm.value
        case .medium: Theme.SpacingKey.md.value
        case .large: Theme.SpacingKey.base.value
        }
    }
}

// MARK: - CabinClassSelector

/// Molecule. Single-select cabin-class control over the ``CabinClass`` model.
///
/// Works **uncontrolled** by default (`initiallySelected:` seeds internal
/// state) and **controlled** on demand (`selection:` binding — the caller owns
/// the state); the `Binding` is the change channel (ADR-4, `ControllableState`).
///
///     CabinClassSelector(selection: $draft.cabin)
///         .classes([.economy, .business])   // e.g. domestic network
///         .cabinClassSelectorStyle(.chips)
public struct CabinClassSelector: View {
    @Environment(\.isEnabled) private var isEnabled     // R3 — set natively by `.disabled(_:)`
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — normal chrome, selection blocked
    @Environment(\.cabinClassSelectorStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale

    @ControllableState private var selection: CabinClass

    // Appearance/config — mutated only through the modifiers below (R2).
    private var classes: [CabinClass] = CabinClass.allCases
    private var showsGlyphs = false
    private var accent: SemanticColor? = nil
    private var sizeOverride: CabinClassSelectorSize?
    private var chipsWrap = false
    private var labelOverride: ((CabinClass) -> String)?
    private var glyphOverride: ((CabinClass) -> String)?
    private var descriptionProvider: ((CabinClass) -> String?)?
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's `.cabinClassSelectorStyle(_:)`
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyCabinClassSelectorStyle?

    /// Controlled — reads and writes flow through the caller's binding.
    public init(selection: Binding<CabinClass>) {   // R1
        self._selection = ControllableState(wrappedValue: selection.wrappedValue, external: selection)
    }

    /// Uncontrolled — the component owns its selection state.
    public init(initiallySelected: CabinClass = .economy) {   // R1
        self._selection = ControllableState(wrappedValue: initiallySelected)
    }

    /// Never render an empty control: an empty `classes` list falls back to all four.
    private var displayedClasses: [CabinClass] { classes.isEmpty ? CabinClass.allCases : classes }

    public var body: some View {
        // Capture the projected binding, not `self` — writes route through
        // `ControllableState` to whichever storage (internal / caller's) is live.
        let selectionBinding = $selection
        let labelOverride = labelOverride
        let glyphOverride = glyphOverride
        let configuration = CabinClassSelectorConfiguration(
            classes: displayedClasses,
            selected: selection,
            select: { selectionBinding.wrappedValue = $0 },
            showsGlyphs: showsGlyphs,
            labelProvider: { labelOverride?($0) ?? $0.label },
            glyphProvider: { glyphOverride?($0) ?? $0.glyph },
            descriptionProvider: descriptionProvider ?? { _ in nil },
            size: sizeOverride,
            chipsWrap: chipsWrap,
            accent: accent,
            density: density,
            locale: locale
        )
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            .allowsHitTesting(!isReadOnly)   // E1 — read-only keeps chrome + VoiceOver value
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(themeKitTravel: "Cabin class"))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CabinClassSelector {
    /// Subset + order of the offered cabins (default: all four).
    /// E.g. a domestic network: `[.economy, .business]`. An empty list falls
    /// back to all four so the control never renders empty.
    func classes(_ list: [CabinClass]) -> Self { copy { $0.classes = list } }
    /// Presentation — superseded by the style axis: prefer
    /// `.cabinClassSelectorStyle(.segmented/.chips/.list/.cards)`, settable once
    /// per screen via the environment. This modifier keeps working and, when
    /// called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .cabinClassSelectorStyle(.segmented/.chips/.list/.cards) instead")
    func variant(_ v: CabinClassVariant) -> Self {
        copy {
            switch v {
            case .segmented: $0.explicitStyle = AnyCabinClassSelectorStyle(SegmentedCabinClassSelectorStyle())
            case .chips: $0.explicitStyle = AnyCabinClassSelectorStyle(ChipsCabinClassSelectorStyle())
            case .list: $0.explicitStyle = AnyCabinClassSelectorStyle(ListCabinClassSelectorStyle())
            case .cards: $0.explicitStyle = AnyCabinClassSelectorStyle(CardsCabinClassSelectorStyle())
            }
        }
    }
    /// Show each cabin's SF Symbol next to its label (the `.segmented` /
    /// `.chips` styles; the `.list` rows stay text-only, matching `RadioGroup`
    /// anatomy).
    func showsGlyphs(_ on: Bool = true) -> Self { copy { $0.showsGlyphs = on } }
    /// Semantic tint: `.segmented` switches to the tinted selection style,
    /// `.list` tints the radios, `.chips` feeds the subtree accent cascade,
    /// `.cards` tints the selected card. `nil` (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Control-size ramp forwarded to the wrapped `SegmentedControl` / `Chip`
    /// (and the `.cards` padding step). Unset keeps each control's stock size.
    func size(_ s: CabinClassSelectorSize) -> Self { copy { $0.sizeOverride = s } }
    /// Lay the `.chips` style out as a wrapping ``FlowLayout`` (RTL-aware)
    /// instead of a horizontal `ScrollView` — every option visible at once.
    func chipsWrap(_ on: Bool = true) -> Self { copy { $0.chipsWrap = on } }
    /// Override the display label per cabin (default: the canonical
    /// ``CabinClass/label``), e.g. shortened labels for tight segmented rows.
    func label(_ f: @escaping (CabinClass) -> String) -> Self { copy { $0.labelOverride = f } }
    /// Override the SF Symbol per cabin (default: the canonical ``CabinClass/glyph``).
    func glyph(_ f: @escaping (CabinClass) -> String) -> Self { copy { $0.glyphOverride = f } }
    /// Per-cabin description line, rendered by the `.cards` style beneath the
    /// label (`nil` for no description on that card). Other styles ignore it.
    func description(_ f: @escaping (CabinClass) -> String?) -> Self { copy { $0.descriptionProvider = f } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Variants") {
    struct Demo: View {
        @State private var cabin: CabinClass = .economy
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(verbatim: "Segmented (default · controlled)")
                    CabinClassSelector(selection: $cabin)
                    CabinClassSelector(selection: $cabin).showsGlyphs()
                    Text(verbatim: "Subset + tinted accent")
                    CabinClassSelector(selection: $cabin).classes([.economy, .business]).accent(.success)
                    Text(verbatim: "Chips")
                    CabinClassSelector(selection: $cabin).showsGlyphs().cabinClassSelectorStyle(.chips)
                    Text(verbatim: "Chips · wrapping + small")
                    CabinClassSelector(selection: $cabin).chipsWrap().size(.small).cabinClassSelectorStyle(.chips)
                    Text(verbatim: "List (sheet contexts)")
                    CabinClassSelector(selection: $cabin).accent(.info).cabinClassSelectorStyle(.list)
                    Text(verbatim: "Cards (glyph + label + description)")
                    CabinClassSelector(selection: $cabin)
                        .description { cabin in
                            cabin == .economy ? String(themeKitTravel: "Best value") : nil
                        }
                        .accent(.success)
                        .cabinClassSelectorStyle(.cards)
                    Text(verbatim: "Label + glyph overrides · large")
                    CabinClassSelector(selection: $cabin)
                        .showsGlyphs()
                        .size(.large)
                        .label { $0 == .premiumEconomy ? String(themeKitTravel: "Premium") : $0.label }
                        .glyph { $0 == .first ? "star" : $0.glyph }
                    Text(verbatim: "Uncontrolled · read-only · disabled")
                    CabinClassSelector(initiallySelected: .business)
                    CabinClassSelector(selection: $cabin).readOnly().cabinClassSelectorStyle(.chips)
                    CabinClassSelector(selection: $cabin).disabled(true)
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Dark") {
    struct Demo: View {
        @State private var cabin: CabinClass = .business
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                CabinClassSelector(selection: $cabin).showsGlyphs()
                CabinClassSelector(selection: $cabin).cabinClassSelectorStyle(.chips)
                CabinClassSelector(selection: $cabin).accent(.success).cabinClassSelectorStyle(.list)
                CabinClassSelector(selection: $cabin).cabinClassSelectorStyle(.cards)
            }
            .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}
