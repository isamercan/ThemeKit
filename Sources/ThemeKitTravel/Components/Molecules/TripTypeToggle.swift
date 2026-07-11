//
//  TripTypeToggle.swift
//  ThemeKit
//
//  Molecule. A compact pill-segmented control — the selected option is an
//  accent-filled pill inside a soft container. Generic (one-way / round-trip /
//  multi-city, or any options), with optional per-option icons. Token-bound.
//
//  ```swift
//  TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip)
//      .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
//  ```
//

import SwiftUI
import ThemeKit

/// Size ramp of a ``TripTypeToggle`` — steps the minimum option height
/// (internal 28/36/44 pt) together with the icon + label text styles.
public enum TripTypeToggleSize: Sendable {
    case compact, regular, large

    var minHeight: CGFloat {
        switch self {
        case .compact: 28
        case .regular: 36
        case .large: 44
        }
    }
    var textStyle: TextStyle {
        switch self {
        case .compact: .labelSm600
        case .regular: .labelSm700
        case .large: .labelBase700
        }
    }
    var iconStyle: TextStyle {
        switch self {
        case .compact: .overline500
        case .regular: .labelSm600
        case .large: .labelBase600
        }
    }
}

/// Look of a ``TripTypeToggle``: the stock accent-filled `.pill` inside a soft
/// track, or a borderless `.underline` tab row with an indicator bar.
public enum TripTypeToggleVariant: Sendable { case pill, underline }

/// Corner treatment of the pill variant's track and thumb: a full `.capsule`
/// (default) or a `.rounded(_:)` rectangle at a radius role.
public enum TripTypeToggleShape {
    case capsule
    case rounded(Theme.RadiusRole)
}

public struct TripTypeToggle: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [String]
    @ControllableState private var selection: Int
    // Appearance — mutated only through the modifiers below (R2).
    private var icons: [String] = []
    private var accent: SemanticColor?
    private var fullWidth = true
    private var surface: Theme.BackgroundColorKey = .bgBase
    private var size: TripTypeToggleSize = .regular
    private var variant: TripTypeToggleVariant = .pill
    private var shape: TripTypeToggleShape = .capsule

    /// Controlled — reads and writes flow through the caller's binding (ADR-4).
    public init(_ options: [String], selection: Binding<Int>) {   // R1
        self.options = options
        self._selection = ControllableState(wrappedValue: selection.wrappedValue, external: selection)
    }

    /// Uncontrolled — the component owns its selection state.
    public init(_ options: [String], initiallySelected: Int = 0) {   // R1
        self.options = options
        self._selection = ControllableState(wrappedValue: initiallySelected)
    }

    private var accentSemantic: SemanticColor { accent ?? .primary }
    /// Selection slide, gated by `microAnimations` + Reduce Motion.
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private var trackShape: AnyShape {
        switch shape {
        case .capsule: AnyShape(Capsule(style: .continuous))
        case .rounded(let role): AnyShape(RoundedRectangle(cornerRadius: role.value, style: .continuous))
        }
    }

    public var body: some View {
        switch variant {
        case .pill:
            HStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in pill(i, option) }
            }
            .padding(4)
            .background(theme.background(surface), in: trackShape)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        case .underline:
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in underlineTab(i, option) }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
    }

    private func pill(_ i: Int, _ option: String) -> some View {
        let isOn = i == selection
        return Button {
            withAnimation(motion) { selection = i }
        } label: {
            optionLabel(i, option)
                .foregroundStyle(isOn ? accentSemantic.onSolid : theme.text(.textSecondary))
                .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: size.minHeight)
                .background(isOn ? accentSemantic.solid : .clear, in: trackShape)
                .contentShape(trackShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Borderless tab look — no track, a 2pt accent indicator bar under the
    /// selected option.
    private func underlineTab(_ i: Int, _ option: String) -> some View {
        let isOn = i == selection
        return Button {
            withAnimation(motion) { selection = i }
        } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                optionLabel(i, option)
                    .foregroundStyle(isOn ? accentSemantic.base : theme.text(.textSecondary))
                Rectangle()
                    .fill(isOn ? accentSemantic.base : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, density.scale(Theme.SpacingKey.xs.value))
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: size.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func optionLabel(_ i: Int, _ option: String) -> some View {
        HStack(spacing: 5) {
            if i < icons.count { Image(systemName: icons[i]).textStyle(size.iconStyle) }
            Text(option).textStyle(size.textStyle).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TripTypeToggle {
    /// Per-option leading SF Symbols (aligned to `options` by index).
    func icons(_ symbols: [String]) -> Self { copy { $0.icons = symbols } }
    /// Token-fed accent for the selected pill (default primary).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Stretch pills to fill the width (default on); off = intrinsic width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.fullWidth = on } }
    /// Token-fed track fill behind the pills (default `.bgBase` — a soft,
    /// low-contrast track that reads well on a white card). Pass `.bgWhite` for a
    /// flush track or `.bgSecondary` for the stronger grey.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surface = key } }
    /// Size ramp — steps the option height and the icon + label styles
    /// (default `.regular`).
    func size(_ s: TripTypeToggleSize) -> Self { copy { $0.size = s } }
    /// Look: the stock accent-filled `.pill` (default) or the borderless
    /// `.underline` tab row with an indicator bar.
    func variant(_ v: TripTypeToggleVariant) -> Self { copy { $0.variant = v } }
    /// Corner treatment of the pill track + thumb: `.capsule` (default) or
    /// `.rounded(_:)` at a radius role.
    func shape(_ s: TripTypeToggleShape) -> Self { copy { $0.shape = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var sel = 1
    PreviewMatrix("TripTypeToggle") {
        PreviewCase("Icons") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
        }
        PreviewCase("Accent") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .accent(.success)
        }
        PreviewCase("Intrinsic width") {
            TripTypeToggle(["One way", "Round trip"], selection: .constant(0))
                .fullWidth(false)
        }
        PreviewCase("Uncontrolled") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], initiallySelected: 2)
        }
        PreviewCase("Compact / large") {
            VStack(spacing: 12) {
                TripTypeToggle(["One way", "Round trip"], selection: $sel).size(.compact)
                TripTypeToggle(["One way", "Round trip"], selection: $sel).size(.large)
            }
        }
        PreviewCase("Rounded shape") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .shape(.rounded(.field))
        }
        PreviewCase("Underline tabs") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .variant(.underline)
                .accent(.info)
        }
    }
}
