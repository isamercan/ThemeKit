//
//  TripTypeToggle.swift
//  ThemeKit
//
//  Molecule. A compact trip-type selector — generic (one-way / round-trip /
//  multi-city, or any options), with optional per-option icons. Presentation
//  is style-driven (``TripTypeToggleStyle``, ADR-0004) — set once per screen
//  via `.tripTypeToggleStyle(_:)`. Token-bound.
//
//  ```swift
//  TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip)
//      .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
//      .tripTypeToggleStyle(.underline)   // .pill (default) / .underline / .menu
//  ```
//

import SwiftUI
import ThemeKit

/// Size ramp of a ``TripTypeToggle`` — steps the minimum option height
/// (internal 28/36/44 pt) together with the icon + label text styles.
public enum TripTypeToggleSize: Sendable {
    case compact, regular, large

    /// Minimum option height at this step — styles apply it per option.
    public var minHeight: CGFloat {
        switch self {
        case .compact: 28
        case .regular: 36
        case .large: 44
        }
    }
    /// The option label's text style at this step.
    public var textStyle: TextStyle {
        switch self {
        case .compact: .labelSm600
        case .regular: .labelSm700
        case .large: .labelBase700
        }
    }
    /// The option icon's text style at this step.
    public var iconStyle: TextStyle {
        switch self {
        case .compact: .overline500
        case .regular: .labelSm600
        case .large: .labelBase600
        }
    }
}

/// Look of a ``TripTypeToggle``: the stock accent-filled `.pill` inside a soft
/// track, or a borderless `.underline` tab row with an indicator bar.
///
/// Superseded by ``TripTypeToggleStyle`` (each case maps 1:1 to a preset —
/// `.pill`/`.underline`, plus the new `.menu`); kept for source compatibility
/// until the next major, together with the deprecated
/// ``TripTypeToggle/variant(_:)`` modifier.
public enum TripTypeToggleVariant: Sendable { case pill, underline }

/// Corner treatment of the pill variant's track and thumb: a full `.capsule`
/// (default) or a `.rounded(_:)` rectangle at a radius role.
public enum TripTypeToggleShape {
    case capsule
    case rounded(Theme.RadiusRole)
}

public struct TripTypeToggle: View {
    @Environment(\.tripTypeToggleStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [String]
    @ControllableState private var selection: Int
    // Appearance — mutated only through the modifiers below (R2).
    private var icons: [String] = []
    private var accent: SemanticColor?
    private var fullWidth = true
    private var surfaceKey: Theme.BackgroundColorKey?
    private var size: TripTypeToggleSize = .regular
    private var shape: TripTypeToggleShape = .capsule
    /// Set by the deprecated ``variant(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's `.tripTypeToggleStyle(_:)`
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyTripTypeToggleStyle?

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

    public var body: some View {
        // Selection slide, gated by `microAnimations` + Reduce Motion and baked
        // into `select` — styles call it, never read the motion environment.
        let motion = MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
        let configuration = TripTypeToggleConfiguration(
            options: options,
            selectedIndex: selection,
            select: { index in withAnimation(motion) { selection = index } },
            icons: icons,
            size: size,
            shape: shape,
            accent: accent,
            surfaceKey: surfaceKey,
            fullWidth: fullWidth,
            density: density,
            locale: locale
        )
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
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
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Size ramp — steps the option height and the icon + label styles
    /// (default `.regular`).
    func size(_ s: TripTypeToggleSize) -> Self { copy { $0.size = s } }
    /// Look — superseded by the style axis: prefer
    /// `.tripTypeToggleStyle(.pill/.underline/.menu)`, settable once per screen
    /// via the environment. This modifier keeps working and, when called,
    /// wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .tripTypeToggleStyle(.pill/.underline) instead")
    func variant(_ v: TripTypeToggleVariant) -> Self {
        copy {
            switch v {
            case .pill: $0.explicitStyle = AnyTripTypeToggleStyle(PillTripTypeToggleStyle())
            case .underline: $0.explicitStyle = AnyTripTypeToggleStyle(UnderlineTripTypeToggleStyle())
            }
        }
    }
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
    struct Demo: View {
        @State var sel = 1
        var body: some View {
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
                        .accent(.info)
                        .tripTypeToggleStyle(.underline)
                }
                PreviewCase("Menu (tap in live preview)") {
                    TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                        .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
                        .fullWidth(false)
                        .tripTypeToggleStyle(.menu)
                }
            }
        }
    }
    return Demo()
}
