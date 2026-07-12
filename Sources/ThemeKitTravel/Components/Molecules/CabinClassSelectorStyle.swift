//
//  CabinClassSelectorStyle.swift
//  ThemeKit
//
//  The styling hook for ``CabinClassSelector`` — promotes the former
//  ``CabinClassVariant`` enum (ADR-0004) so the whole presentation is a
//  swappable style, settable once per screen via the environment. Four
//  built-ins map 1:1 to the old variant cases, and each keeps *delegating* to
//  the neutral kit exactly as the component always has — a style arranges, it
//  never re-implements a control:
//
//    .segmented  inline `SegmentedControl` (CabinClass ⇄ index) — default
//    .chips      `Chip` row — horizontal scroll, or a wrapping `FlowLayout`
//    .list       `RadioGroup` rows for sheet contexts
//    .cards      2×2 grid of selectable cards (glyph + label + description)
//
//      CabinClassSelector(selection: $draft.cabin)
//          .classes([.economy, .business])
//          .cabinClassSelectorStyle(.chips)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything. Selection state stays in the component
//  (`ControllableState`, ADR-F4) — styles read ``CabinClassSelectorConfiguration/selected``
//  and write through ``CabinClassSelectorConfiguration/select`` (or the derived
//  binding helpers), never owning state of their own.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``CabinClassSelectorStyle`` lays out. Fields a given
/// style doesn't use are simply ignored — every built-in degrades gracefully
/// (no glyphs requested → text-only, no description → two-line cards, no size
/// override → each wrapped control's stock ramp).
public struct CabinClassSelectorConfiguration {
    /// The offered cabins, in display order — already resolved by the component
    /// (`.classes(_:)`, with the empty-list → all-four fallback applied), so a
    /// style never renders an empty control.
    public let classes: [CabinClass]
    /// The current selection. A value outside ``classes`` displays as the first
    /// option until the user picks (the ``indexBinding`` rule).
    public let selected: CabinClass
    /// Commits a new selection — routes into the component's
    /// `ControllableState`, so controlled and uncontrolled call sites both work.
    public let select: (CabinClass) -> Void
    /// Show each cabin's SF Symbol next to its label (`.showsGlyphs()`).
    public let showsGlyphs: Bool
    /// Display label per cabin — the `.label(_:)` override already folded over
    /// the canonical ``CabinClass/label`` fallback.
    public let labelProvider: (CabinClass) -> String
    /// SF Symbol per cabin — the `.glyph(_:)` override already folded over the
    /// canonical ``CabinClass/glyph`` fallback.
    public let glyphProvider: (CabinClass) -> String
    /// Optional per-cabin description line (`.description(_:)`), rendered by
    /// `.cards` beneath the label; `nil` for no description on that cabin.
    public let descriptionProvider: (CabinClass) -> String?
    /// Control-size ramp (`.size(_:)`) forwarded to the wrapped
    /// `SegmentedControl` / `Chip` (and the `.cards` padding step);
    /// `nil` keeps each control's stock size.
    public let size: CabinClassSelectorSize?
    /// Lay chip-based styles out as a wrapping `FlowLayout` instead of a
    /// horizontal `ScrollView` (`.chipsWrap()`).
    public let chipsWrap: Bool
    /// Semantic tint (`.accent(_:)`); `nil` = the stock hero chroma. `.cards`
    /// resolves its selected-state tint via ``resolvedAccent``.
    public let accent: SemanticColor?
    /// The environment's component density, captured by the component — scale
    /// chrome gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for any
    /// formatted values a custom style renders (labels arrive pre-localized
    /// through ``labelProvider``).
    public let locale: Locale

    /// Whether `cabin` is the current selection.
    public func isSelected(_ cabin: CabinClass) -> Bool { selected == cabin }

    /// The `.accent(_:)` override, else `.primary` — the selected-state tint
    /// the `.cards` built-in hardcoded before the style axis existed.
    public var resolvedAccent: SemanticColor { accent ?? .primary }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the selector.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// `CabinClass` ⇄ index bridge for `SegmentedControl`-like styles. A
    /// selection outside ``classes`` displays as the first option until the
    /// user picks; writes always land on a real member.
    public var indexBinding: Binding<Int> {
        Binding(
            get: { classes.firstIndex(of: selected) ?? 0 },
            set: { index in
                guard classes.indices.contains(index) else { return }
                select(classes[index])
            }
        )
    }

    /// Per-cabin on/off bridge for `Chip`-like styles — radio semantics:
    /// selecting turns a cabin on, tapping the selected cabin again keeps it.
    public func chipBinding(for cabin: CabinClass) -> Binding<Bool> {
        Binding(
            get: { selected == cabin },
            set: { isOn in if isOn { select(cabin) } }
        )
    }

    /// Optional-selection bridge for `RadioGroup`-like styles — deselection
    /// writes (`nil`) are ignored, keeping the control single-select.
    public var radioBinding: Binding<CabinClass?> {
        Binding(
            get: { selected },
            set: { newValue in if let newValue { select(newValue) } }
        )
    }
}

// MARK: - Protocol

/// Defines a `CabinClassSelector`'s entire presentation. Implement `makeBody`
/// to arrange the configuration's cabins. Set one with
/// `.cabinClassSelectorStyle(_:)`; the default is ``SegmentedCabinClassSelectorStyle``.
public protocol CabinClassSelectorStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: CabinClassSelectorConfiguration) -> Body
}

// MARK: - .segmented

/// Today's default look, extracted verbatim: the neutral `SegmentedControl`
/// wrapped over the cabin list (`CabinClass` ⇄ index), optional glyphs, the
/// thumbless `.tinted` selection style when an accent is set.
public struct SegmentedCabinClassSelectorStyle: CabinClassSelectorStyle {
    public init() {}
    public func makeBody(configuration: CabinClassSelectorConfiguration) -> some View {
        SegmentedCabinClassChrome(configuration: configuration)
    }
}

private struct SegmentedCabinClassChrome: View {
    let configuration: CabinClassSelectorConfiguration

    var body: some View {
        let base = SegmentedControl(
            configuration.classes.map {
                SegmentItem(configuration.labelProvider($0),
                            systemImage: configuration.showsGlyphs ? configuration.glyphProvider($0) : nil)
            },
            selection: configuration.indexBinding
        )
        let control = configuration.size.map { base.size($0.segmented) } ?? base
        // Spec mapping: accent → the thumbless `.tinted` selection style; the
        // stock raised thumb keeps its neutral chroma when no accent is set.
        if let accent = configuration.accent { control.tinted(accent) } else { control }
    }
}

// MARK: - .chips

/// A `Chip` row with radio semantics (tapping the selected chip keeps it) — a
/// horizontal `ScrollView`, or a wrapping RTL-aware `FlowLayout` when
/// ``CabinClassSelectorConfiguration/chipsWrap`` is set.
public struct ChipsCabinClassSelectorStyle: CabinClassSelectorStyle {
    public init() {}
    public func makeBody(configuration: CabinClassSelectorConfiguration) -> some View {
        ChipsCabinClassChrome(configuration: configuration)
    }
}

private struct ChipsCabinClassChrome: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let configuration: CabinClassSelectorConfiguration

    var body: some View {
        // Accent flows down the standard ComponentDefaults cascade so
        // accent-aware `ChipStyle`s resolve it; the built-in tonal/solid
        // chip chroma stays hero-tinted by design.
        if configuration.chipsWrap {
            // Wrapping FlowLayout — RTL-aware via the injected layout direction.
            FlowLayout(spacing: configuration.spacing(.sm),
                       lineSpacing: configuration.spacing(.sm),
                       layoutDirection: layoutDirection) {
                chipItems
            }
            .componentDefaults(accent: configuration.accent)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: configuration.spacing(.sm)) { chipItems }
            }
            .componentDefaults(accent: configuration.accent)
        }
    }

    private var chipItems: some View {
        ForEach(configuration.classes, id: \.self) { cabin in
            let chip = Chip(configuration.labelProvider(cabin), isSelected: configuration.chipBinding(for: cabin))
                .icon(configuration.showsGlyphs ? configuration.glyphProvider(cabin) : nil)
            if let size = configuration.size { chip.size(size.chip) } else { chip }
        }
    }
}

// MARK: - .list

/// `RadioGroup` rows for sheet contexts — the stock radio anatomy, text-only
/// labels, accent-tinted radios when an accent is set.
public struct ListCabinClassSelectorStyle: CabinClassSelectorStyle {
    public init() {}
    public func makeBody(configuration: CabinClassSelectorConfiguration) -> some View {
        RadioGroup(
            options: configuration.classes,
            selection: configuration.radioBinding,
            label: { configuration.labelProvider($0) }
        )
        .accent(configuration.accent)
    }
}

// MARK: - .cards

/// A 2×2 grid of selectable cards — glyph + label + optional description per
/// cabin, the selected card tinted with ``CabinClassSelectorConfiguration/resolvedAccent``.
public struct CardsCabinClassSelectorStyle: CabinClassSelectorStyle {
    public init() {}
    public func makeBody(configuration: CabinClassSelectorConfiguration) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: configuration.spacing(.sm)), count: 2),
            spacing: configuration.spacing(.sm)
        ) {
            ForEach(configuration.classes, id: \.self) { cabin in
                CabinClassCard(configuration: configuration, cabin: cabin)
            }
        }
    }
}

/// One selectable card of the `.cards` grid — glyph, label, optional
/// description, accent-tinted when selected (extracted verbatim from the
/// pre-style component body).
private struct CabinClassCard: View {
    @Environment(\.theme) private var theme
    let configuration: CabinClassSelectorConfiguration
    let cabin: CabinClass

    var body: some View {
        let isOn = configuration.isSelected(cabin)
        let tint = configuration.resolvedAccent
        let description = configuration.descriptionProvider(cabin)
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        Button { configuration.select(cabin) } label: {
            VStack(spacing: configuration.spacing(.xs)) {
                Image(systemName: configuration.glyphProvider(cabin))
                    .textStyle(.headingXs)
                    .foregroundStyle(isOn ? tint.base : theme.text(.textSecondary))
                Text(configuration.labelProvider(cabin))
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                if let description {
                    Text(description)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, (configuration.size ?? .medium).cardPadding)
            .padding(.horizontal, configuration.spacing(.sm))
            .background(isOn ? tint.soft : theme.background(.bgElevatorPrimary), in: shape)
            .overlay { shape.strokeBorder(isOn ? tint.base : theme.border(.borderPrimary), lineWidth: isOn ? 1.5 : 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([configuration.labelProvider(cabin), description].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Static accessors

public extension CabinClassSelectorStyle where Self == SegmentedCabinClassSelectorStyle {
    /// Inline `SegmentedControl` over the cabin list. The default.
    static var segmented: SegmentedCabinClassSelectorStyle { SegmentedCabinClassSelectorStyle() }
}
public extension CabinClassSelectorStyle where Self == ChipsCabinClassSelectorStyle {
    /// A `Chip` row — horizontal scroll, or a wrapping `FlowLayout` with `.chipsWrap()`.
    static var chips: ChipsCabinClassSelectorStyle { ChipsCabinClassSelectorStyle() }
}
public extension CabinClassSelectorStyle where Self == ListCabinClassSelectorStyle {
    /// `RadioGroup` rows for sheet contexts.
    static var list: ListCabinClassSelectorStyle { ListCabinClassSelectorStyle() }
}
public extension CabinClassSelectorStyle where Self == CardsCabinClassSelectorStyle {
    /// A 2×2 grid of selectable cards (glyph + label + optional description).
    static var cards: CardsCabinClassSelectorStyle { CardsCabinClassSelectorStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyCabinClassSelectorStyle: CabinClassSelectorStyle {
    private let _makeBody: @MainActor (CabinClassSelectorConfiguration) -> AnyView
    init<S: CabinClassSelectorStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: CabinClassSelectorConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct CabinClassSelectorStyleKey: EnvironmentKey {
    static let defaultValue = AnyCabinClassSelectorStyle(SegmentedCabinClassSelectorStyle())
}

extension EnvironmentValues {
    var cabinClassSelectorStyle: AnyCabinClassSelectorStyle {
        get { self[CabinClassSelectorStyleKey.self] }
        set { self[CabinClassSelectorStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``CabinClassSelectorStyle`` for `CabinClassSelector`s in this
    /// view and its descendants — one screen can mix archetypes per section.
    func cabinClassSelectorStyle<S: CabinClassSelectorStyle>(_ style: sending S) -> some View {
        environment(\.cabinClassSelectorStyle, AnyCabinClassSelectorStyle(style))
    }
}

// MARK: - Previews

/// Proves external implementability: a vertical checklist built purely from
/// the public configuration + theme tokens — what an app target would write.
private struct ChecklistCabinClassSelectorStyle: CabinClassSelectorStyle {
    func makeBody(configuration: CabinClassSelectorConfiguration) -> some View {
        ChecklistChrome(configuration: configuration)
    }

    private struct ChecklistChrome: View {
        @Environment(\.theme) private var theme
        let configuration: CabinClassSelectorConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                ForEach(configuration.classes, id: \.self) { cabin in
                    let isOn = configuration.isSelected(cabin)
                    Button { configuration.select(cabin) } label: {
                        HStack(spacing: configuration.spacing(.sm)) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .textStyle(.labelBase600)
                                .foregroundStyle(isOn ? configuration.resolvedAccent.base : theme.text(.textTertiary))
                            Text(configuration.labelProvider(cabin))
                                .textStyle(.labelBase600)
                                .foregroundStyle(theme.text(.textPrimary))
                            Spacer()
                        }
                        .padding(.vertical, configuration.spacing(.xs))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

#Preview("CabinClassSelectorStyle — presets × light/dark") {
    PreviewMatrix("CabinClassSelectorStyle") {
        PreviewCase("Segmented (default)") {
            CabinClassSelector(initiallySelected: .economy).showsGlyphs()
        }
        PreviewCase("Segmented · subset + accent") {
            CabinClassSelector(initiallySelected: .business)
                .classes([.economy, .business])
                .accent(.success)
        }
        PreviewCase("Chips") {
            CabinClassSelector(initiallySelected: .premiumEconomy)
                .showsGlyphs()
                .cabinClassSelectorStyle(.chips)
        }
        PreviewCase("Chips · wrapping + small") {
            CabinClassSelector(initiallySelected: .first)
                .chipsWrap()
                .size(.small)
                .cabinClassSelectorStyle(.chips)
        }
        PreviewCase("List (sheet contexts)") {
            CabinClassSelector(initiallySelected: .economy)
                .accent(.info)
                .cabinClassSelectorStyle(.list)
        }
        PreviewCase("Cards · description + accent") {
            CabinClassSelector(initiallySelected: .business)
                .description { $0 == .economy ? String(themeKitTravel: "Best value") : nil }
                .accent(.success)
                .cabinClassSelectorStyle(.cards)
        }
        PreviewCase("Custom (in-preview checklist)") {
            CabinClassSelector(initiallySelected: .economy)
                .cabinClassSelectorStyle(ChecklistCabinClassSelectorStyle())
        }
    }
}
