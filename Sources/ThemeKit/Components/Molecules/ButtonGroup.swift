//
//  ButtonGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ButtonGroupAxis {
    case vertical, horizontal
}

/// Group size (HeroUI ButtonGroup `size`). Every button in the group inherits
/// the selected size for visual consistency — a button that sets its own
/// `.size(_:)` still wins (the same explicit-wins cascade as `.color`).
public enum ButtonGroupSize: CaseIterable {
    case sm, md, lg

    /// The ``ButtonSize`` the group's buttons inherit.
    var buttonSize: ButtonSize {
        switch self {
        case .sm: return .small
        case .md: return .medium
        case .lg: return .large
        }
    }

    /// Length of the between-button divider hairline, scaled per size — a
    /// vertical line's height in a horizontal group, a horizontal line's width
    /// in a vertical one (HeroUI: 16 / 20 / 24 and 16 / 18 / 20). A fixed ramp
    /// with no matching spacing token, so it lives as an in-view constant.
    func dividerLength(axis: ButtonGroupAxis) -> CGFloat {
        switch (self, axis) {
        case (.sm, _):            return 16
        case (.md, .horizontal):  return 20
        case (.md, .vertical):    return 18
        case (.lg, .horizontal):  return 24
        case (.lg, .vertical):    return 20
        }
    }
}

/// Group width (HeroUI ButtonGroup `width`).
/// - `hug`: the group wraps tightly around its content — a horizontal group
///   flows overflowing buttons onto the next line instead of squeezing them.
/// - `fill`: the group expands to the available width, distributing its buttons
///   evenly (equal widths in a row, full-width in a stack).
public enum ButtonGroupWidth {
    case hug, fill
}

/// Molecule. Lays out related buttons in a vertical stack or a side-by-side row,
/// mirroring HeroUI's **Button Group** axes: a shared ``size(_:)`` every button
/// inherits, a ``width(_:)`` mode (`hug` / `fill`) and optional ``dividers(_:)``
/// between adjacent buttons.
///
/// Buttons are content-width by default (ideal for a horizontal row); give the
/// group `.width(.fill)` (or the buttons `.fullWidth()`) for a full-width CTA
/// stack.
///
/// A horizontal `hug` group **wraps**: each button keeps its single-line label
/// at its natural width and overflowing buttons flow to the next line, instead
/// of being squeezed until the text wraps onto two lines. Turning on `.fill`
/// or `.dividers()` switches to a single, non-wrapping row/column so the widths
/// stay even and the hairlines line up.
public struct ButtonGroup<Content: View>: View {
    @Environment(\.theme) private var theme
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection

    // Appearance — mutated only through the modifiers below (R2).
    private var axis: ButtonGroupAxis
    private var size: ButtonGroupSize?
    private var width: ButtonGroupWidth = .hug
    private var showsDividers = false
    /// Explicit `.dividerColor(_:)`; `nil` keeps the neutral theme border.
    private var dividerColor: SemanticColor?
    private let spacing: CGFloat
    private let content: () -> Content

    public init(_ axis: ButtonGroupAxis = .vertical, @ViewBuilder content: @escaping () -> Content) {
        self.axis = axis
        self.spacing = Theme.SpacingKey.sm.value
        self.content = content
    }

    /// The button size children inherit — `nil` until `.size(_:)` is set, so an
    /// un-sized group leaves its buttons at their own default.
    private var inheritedButtonSize: ButtonSize? { size?.buttonSize }

    public var body: some View {
        layout
            .environment(\.buttonGroupControlSize, inheritedButtonSize)
    }

    @ViewBuilder private var layout: some View {
        // The wrap-friendly FlowLayout / plain VStack only survive for the
        // original hug, divider-free case; dividers or `.fill` need per-child
        // access (equal widths, interleaved hairlines), so they route through
        // the variadic separated container.
        if showsDividers || width == .fill {
            _VariadicView.Tree(separatedRoot) { content() }
        } else {
            switch axis {
            case .vertical:
                VStack(spacing: spacing) { content() }
            case .horizontal:
                // FlowLayout (not HStack) so buttons wrap to the next line rather
                // than compressing — hugs content when it fits, wraps when it doesn't.
                FlowLayout(spacing: spacing, lineSpacing: spacing, layoutDirection: layoutDirection) { content() }
            }
        }
    }

    private var separatedRoot: SeparatedButtons {
        SeparatedButtons(
            axis: axis,
            spacing: spacing,
            fill: width == .fill,
            showsDividers: showsDividers,
            dividerLength: (size ?? .md).dividerLength(axis: axis),
            dividerColor: resolvedDividerColor
        )
    }

    /// A `.dividerColor(_:)` resolves to that color's border shade so the line
    /// matches the surrounding button context (HeroUI Divider `variant`); the
    /// default is the neutral theme border.
    private var resolvedDividerColor: Color {
        if let dividerColor { return theme.resolve(dividerColor).border }
        return theme.border(.borderPrimary)
    }
}

// MARK: - Separated container (dividers + even fill)

/// Lays the group's buttons out with optional hairline dividers between them,
/// and (for `fill`) stretches each to an equal share of the width. Uses
/// `_VariadicView` because inserting a view *between* composed children — and
/// sizing each one — needs per-subview access, which SwiftUI only exposes
/// publicly from iOS 18 (`Group(subviews:)`); the kit targets iOS 17.
private struct SeparatedButtons: _VariadicView.MultiViewRoot {
    let axis: ButtonGroupAxis
    let spacing: CGFloat
    let fill: Bool
    let showsDividers: Bool
    let dividerLength: CGFloat
    let dividerColor: Color

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        switch axis {
        case .horizontal:
            HStack(spacing: spacing) {
                ForEach(children) { child in
                    child.frame(maxWidth: fill ? .infinity : nil)
                    if showsDividers, child.id != lastID { divider }
                }
            }
        case .vertical:
            VStack(spacing: spacing) {
                ForEach(children) { child in
                    child.frame(maxWidth: fill ? .infinity : nil)
                    if showsDividers, child.id != lastID { divider }
                }
            }
        }
    }

    @ViewBuilder private var divider: some View {
        switch axis {
        case .horizontal:
            Rectangle().fill(dividerColor).frame(width: 1, height: dividerLength)
        case .vertical:
            Rectangle().fill(dividerColor).frame(width: dividerLength, height: 1)
        }
    }
}

// MARK: - Size inheritance (read by ThemeButton / the preset buttons)

/// Set by a sized ``ButtonGroup`` so its child buttons adopt the group size when
/// they didn't set their own — the same explicit-wins cascade as the accent in
/// ``ComponentDefaults``.
struct ButtonGroupControlSizeKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ButtonSize? = nil   // immutable `nil` — safe (see ``ComponentDefaultsKey``)
}

extension EnvironmentValues {
    var buttonGroupControlSize: ButtonSize? {
        get { self[ButtonGroupControlSizeKey.self] }
        set { self[ButtonGroupControlSizeKey.self] = newValue }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension ButtonGroup {
    /// Layout axis — a vertical stack or a wrapping side-by-side row.
    /// Preferred over the `axis:` init argument (orientation is a reskin, so it
    /// chains): `ButtonGroup { … }.axis(.horizontal)`.
    func axis(_ axis: ButtonGroupAxis) -> Self { copy { $0.axis = axis } }

    /// Group size (HeroUI ButtonGroup `size`) — every button inherits it unless
    /// it set its own `.size(_:)`: `ButtonGroup { … }.size(.lg)`.
    func size(_ size: ButtonGroupSize) -> Self { copy { $0.size = size } }

    /// Width behavior (HeroUI ButtonGroup `width`) — `.hug` (default) wraps
    /// tightly around the buttons; `.fill` stretches the group to the available
    /// width and distributes the buttons evenly.
    func width(_ width: ButtonGroupWidth) -> Self { copy { $0.width = width } }

    /// Draw a hairline between adjacent buttons (HeroUI ButtonGroup dividers).
    /// Switches the group to a single, non-wrapping row/column so the lines
    /// stay aligned.
    func dividers(_ on: Bool = true) -> Self { copy { $0.showsDividers = on } }

    /// Tint the between-button dividers to match the buttons' context
    /// (HeroUI Divider `variant`) — pass a semantic color token; `nil` keeps the
    /// neutral theme border. Pairs with ``dividers(_:)``.
    func dividerColor(_ color: SemanticColor?) -> Self { copy { $0.dividerColor = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ButtonGroup") {
        PreviewCase("Vertical CTA stack (full-width)") {
            ButtonGroup {
                PrimaryButton("Continue") {}.fullWidth()
                SecondaryButton("Not now") {}.fullWidth()
            }
        }
        PreviewCase("Horizontal (content-width)") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Cancel") {}
                PrimaryButton("Confirm") {}
            }
        }
        PreviewCase("Horizontal overflow wraps") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Back") {}
                SecondaryButton("Save draft") {}
                PrimaryButton("Continue to payment") {}
            }
        }
        // Sizes — every button inherits the group size (sm / md / lg).
        PreviewCase("Sizes (sm · md · lg)") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ButtonGroupSize.allCases, id: \.self) { s in
                    ButtonGroup(.horizontal) {
                        SecondaryButton("Cancel") {}
                        PrimaryButton("Confirm") {}
                    }
                    .size(s)
                }
            }
        }
        // Width — fill distributes the buttons evenly across the row.
        PreviewCase("Width fill (even split)") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Back") {}
                PrimaryButton("Continue") {}
            }
            .width(.fill)
        }
        // Dividers — hairlines between adjacent buttons.
        PreviewCase("Dividers") {
            VStack(spacing: 12) {
                ButtonGroup(.horizontal) {
                    GhostButton("Day") {}
                    GhostButton("Week") {}
                    GhostButton("Month") {}
                }
                .dividers()
                ButtonGroup(.horizontal) {
                    PrimaryButton("Save") {}
                    PrimaryButton("Save & new") {}
                }
                .width(.fill).dividers().dividerColor(.primary).size(.md)
            }
        }
    }
}
