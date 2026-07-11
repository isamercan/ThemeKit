//
//  CabinClassSelector.swift
//  ThemeKitTravel
//
//  Edition molecule (F2.1 · §9.5): economy / premium economy / business / first
//  selection. A pure wrapper — zero bespoke chrome — over the neutral kit's
//  `SegmentedControl` (default), `Chip` row, or `RadioGroup` (`.list`, for
//  sheet contexts), keyed by the canonical `CabinClass` model. Maps
//  `CabinClass` ⇄ index internally for the segmented control's `Binding<Int>`.
//

import SwiftUI
import ThemeKit

// MARK: - Variant

/// How ``CabinClassSelector`` renders its options: an inline `SegmentedControl`
/// (default), a horizontally-scrolling `Chip` row, `RadioGroup`-style rows
/// for sheet contexts, or a 2×2 grid of selectable `.cards` (glyph + label +
/// optional description).
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
///         .variant(.chips)
public struct CabinClassSelector: View {
    @Environment(\.isEnabled) private var isEnabled     // R3 — set natively by `.disabled(_:)`
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — normal chrome, selection blocked
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    @ControllableState private var selection: CabinClass

    // Appearance/config — mutated only through the modifiers below (R2).
    private var classes: [CabinClass] = CabinClass.allCases
    private var variant: CabinClassVariant = .segmented
    private var showsGlyphs = false
    private var accent: SemanticColor? = nil
    private var sizeOverride: CabinClassSelectorSize?
    private var chipsWrap = false
    private var labelOverride: ((CabinClass) -> String)?
    private var glyphOverride: ((CabinClass) -> String)?
    private var descriptionProvider: ((CabinClass) -> String?)?

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

    // Per-cabin content resolution — overrides win, the canonical model is the fallback.
    private func label(for cabin: CabinClass) -> String { labelOverride?(cabin) ?? cabin.label }
    private func glyph(for cabin: CabinClass) -> String { glyphOverride?(cabin) ?? cabin.glyph }
    private func description(for cabin: CabinClass) -> String? { descriptionProvider?(cabin) }

    public var body: some View {
        Group {
            switch variant {
            case .segmented: segmented
            case .chips: chipRow
            case .list: radioList
            case .cards: cardGrid
            }
        }
        .allowsHitTesting(!isReadOnly)   // E1 — read-only keeps chrome + VoiceOver value
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Cabin class"))
    }

    // MARK: .segmented — SegmentedControl wrap (CabinClass ⇄ index)

    /// A selection outside `classes` displays as the first option until the
    /// user picks; writes always land on a real member.
    private var indexBinding: Binding<Int> {
        Binding(
            get: { displayedClasses.firstIndex(of: selection) ?? 0 },
            set: { index in
                guard displayedClasses.indices.contains(index) else { return }
                selection = displayedClasses[index]
            }
        )
    }

    @ViewBuilder private var segmented: some View {
        let base = SegmentedControl(
            displayedClasses.map { SegmentItem(label(for: $0), systemImage: showsGlyphs ? glyph(for: $0) : nil) },
            selection: indexBinding
        )
        let control = sizeOverride.map { base.size($0.segmented) } ?? base
        // Spec mapping: accent → the thumbless `.tinted` selection style; the
        // stock raised thumb keeps its neutral chroma when no accent is set.
        if let accent { control.tinted(accent) } else { control }
    }

    // MARK: .chips — Chip row (radio semantics: tapping the selected chip keeps it)

    @ViewBuilder private var chipRow: some View {
        // Accent flows down the standard ComponentDefaults cascade so
        // accent-aware `ChipStyle`s resolve it; the built-in tonal/solid
        // chip chroma stays hero-tinted by design.
        if chipsWrap {
            // Wrapping FlowLayout — RTL-aware via the injected layout direction.
            FlowLayout(spacing: Theme.SpacingKey.sm.value,
                       lineSpacing: Theme.SpacingKey.sm.value,
                       layoutDirection: layoutDirection) {
                chipItems
            }
            .componentDefaults(accent: accent)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.sm.value) { chipItems }
            }
            .componentDefaults(accent: accent)
        }
    }

    private var chipItems: some View {
        ForEach(displayedClasses, id: \.self) { cabin in
            let chip = Chip(label(for: cabin), isSelected: Binding(
                get: { selection == cabin },
                set: { isOn in if isOn { selection = cabin } }
            ))
            .icon(showsGlyphs ? glyph(for: cabin) : nil)
            if let sizeOverride { chip.size(sizeOverride.chip) } else { chip }
        }
    }

    // MARK: .list — RadioGroup rows for sheet contexts

    private var radioList: some View {
        RadioGroup(
            options: displayedClasses,
            selection: Binding<CabinClass?>(
                get: { selection },
                set: { newValue in if let newValue { selection = newValue } }
            ),
            label: { label(for: $0) }
        )
        .accent(accent)
    }

    // MARK: .cards — 2×2 grid of selectable cards (glyph + label + optional description)

    private var cardGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.SpacingKey.sm.value), count: 2),
            spacing: Theme.SpacingKey.sm.value
        ) {
            ForEach(displayedClasses, id: \.self) { cabin in card(cabin) }
        }
    }

    private func card(_ cabin: CabinClass) -> some View {
        let isOn = selection == cabin
        let tint = accent ?? .primary
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        return Button { selection = cabin } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Image(systemName: glyph(for: cabin))
                    .textStyle(.headingXs)
                    .foregroundStyle(isOn ? tint.base : theme.text(.textSecondary))
                Text(label(for: cabin))
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                if let description = description(for: cabin) {
                    Text(description)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, (sizeOverride ?? .medium).cardPadding)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .background(isOn ? tint.soft : theme.background(.bgElevatorPrimary), in: shape)
            .overlay { shape.strokeBorder(isOn ? tint.base : theme.border(.borderPrimary), lineWidth: isOn ? 1.5 : 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([label(for: cabin), description(for: cabin)].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CabinClassSelector {
    /// Subset + order of the offered cabins (default: all four).
    /// E.g. a domestic network: `[.economy, .business]`. An empty list falls
    /// back to all four so the control never renders empty.
    func classes(_ list: [CabinClass]) -> Self { copy { $0.classes = list } }
    /// Presentation: `.segmented` (default), a `.chips` row, or `.list`
    /// (RadioGroup-style rows for sheet contexts).
    func variant(_ v: CabinClassVariant) -> Self { copy { $0.variant = v } }
    /// Show each cabin's SF Symbol next to its label (`.segmented` / `.chips`;
    /// the `.list` rows stay text-only, matching `RadioGroup` anatomy).
    func showsGlyphs(_ on: Bool = true) -> Self { copy { $0.showsGlyphs = on } }
    /// Semantic tint: `.segmented` switches to the tinted selection style,
    /// `.list` tints the radios, `.chips` feeds the subtree accent cascade,
    /// `.cards` tints the selected card. `nil` (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Control-size ramp forwarded to the wrapped `SegmentedControl` / `Chip`
    /// (and the `.cards` padding step). Unset keeps each control's stock size.
    func size(_ s: CabinClassSelectorSize) -> Self { copy { $0.sizeOverride = s } }
    /// Lay `.chips` out as a wrapping ``FlowLayout`` (RTL-aware) instead of a
    /// horizontal `ScrollView` — every option visible at once.
    func chipsWrap(_ on: Bool = true) -> Self { copy { $0.chipsWrap = on } }
    /// Override the display label per cabin (default: the canonical
    /// ``CabinClass/label``), e.g. shortened labels for tight segmented rows.
    func label(_ f: @escaping (CabinClass) -> String) -> Self { copy { $0.labelOverride = f } }
    /// Override the SF Symbol per cabin (default: the canonical ``CabinClass/glyph``).
    func glyph(_ f: @escaping (CabinClass) -> String) -> Self { copy { $0.glyphOverride = f } }
    /// Per-cabin description line, rendered by the `.cards` variant beneath the
    /// label (`nil` for no description on that card). Other variants ignore it.
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
                    CabinClassSelector(selection: $cabin).variant(.chips).showsGlyphs()
                    Text(verbatim: "Chips · wrapping + small")
                    CabinClassSelector(selection: $cabin).variant(.chips).chipsWrap().size(.small)
                    Text(verbatim: "List (sheet contexts)")
                    CabinClassSelector(selection: $cabin).variant(.list).accent(.info)
                    Text(verbatim: "Cards (glyph + label + description)")
                    CabinClassSelector(selection: $cabin)
                        .variant(.cards)
                        .description { cabin in
                            cabin == .economy ? String(themeKitTravel: "Best value") : nil
                        }
                        .accent(.success)
                    Text(verbatim: "Label + glyph overrides · large")
                    CabinClassSelector(selection: $cabin)
                        .showsGlyphs()
                        .size(.large)
                        .label { $0 == .premiumEconomy ? String(themeKitTravel: "Premium") : $0.label }
                        .glyph { $0 == .first ? "star" : $0.glyph }
                    Text(verbatim: "Uncontrolled · read-only · disabled")
                    CabinClassSelector(initiallySelected: .business)
                    CabinClassSelector(selection: $cabin).variant(.chips).readOnly()
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
                CabinClassSelector(selection: $cabin).variant(.chips)
                CabinClassSelector(selection: $cabin).variant(.list).accent(.success)
                CabinClassSelector(selection: $cabin).variant(.cards)
            }
            .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}
