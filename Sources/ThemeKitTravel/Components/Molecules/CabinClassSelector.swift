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
/// (default), a horizontally-scrolling `Chip` row, or `RadioGroup`-style rows
/// for sheet contexts.
public enum CabinClassVariant: Sendable { case segmented, chips, list }

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

    @ControllableState private var selection: CabinClass

    // Appearance/config — mutated only through the modifiers below (R2).
    private var classes: [CabinClass] = CabinClass.allCases
    private var variant: CabinClassVariant = .segmented
    private var showsGlyphs = false
    private var accent: SemanticColor? = nil

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
        Group {
            switch variant {
            case .segmented: segmented
            case .chips: chipRow
            case .list: radioList
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
        let control = SegmentedControl(
            displayedClasses.map { SegmentItem($0.label, systemImage: showsGlyphs ? $0.glyph : nil) },
            selection: indexBinding
        )
        // Spec mapping: accent → the thumbless `.tinted` selection style; the
        // stock raised thumb keeps its neutral chroma when no accent is set.
        if let accent { control.tinted(accent) } else { control }
    }

    // MARK: .chips — Chip row (radio semantics: tapping the selected chip keeps it)

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(displayedClasses, id: \.self) { cabin in
                    Chip(cabin.label, isSelected: Binding(
                        get: { selection == cabin },
                        set: { isOn in if isOn { selection = cabin } }
                    ))
                    .icon(showsGlyphs ? cabin.glyph : nil)
                }
            }
        }
        // Accent flows down the standard ComponentDefaults cascade so
        // accent-aware `ChipStyle`s resolve it; the built-in tonal/solid
        // chip chroma stays hero-tinted by design.
        .componentDefaults(accent: accent)
    }

    // MARK: .list — RadioGroup rows for sheet contexts

    private var radioList: some View {
        RadioGroup(
            options: displayedClasses,
            selection: Binding<CabinClass?>(
                get: { selection },
                set: { newValue in if let newValue { selection = newValue } }
            ),
            label: { $0.label }
        )
        .accent(accent)
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
    /// `.list` tints the radios, `.chips` feeds the subtree accent cascade.
    /// `nil` (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

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
                    Text(verbatim: "List (sheet contexts)")
                    CabinClassSelector(selection: $cabin).variant(.list).accent(.info)
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
            }
            .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}
