//
//  ThemeButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Fully configurable button (daisyUI-style): semantic color × variant × size ×
//  shape × full-width × icon × loading × disabled. Per the modifier-based
//  architecture (COMPONENT_REFACTOR_RULES R1–R7) the init takes only its
//  content + action; every appearance/state axis is a chainable, order-free
//  modifier. `disabled` is native (`@Environment(\.isEnabled)`, R3). The named
//  PrimaryButton / SecondaryButton / … remain as ergonomic presets.
//
//      ThemeButton("Book") { book() }
//          .variant(.soft).color(.success).size(.large)
//          .icon(leading: "calendar").fullWidth().loading(isBooking)
//          .disabled(!formValid)            // native — R3
//

import SwiftUI

public enum ButtonVariant: String, CaseIterable {
    case solid, soft, outline, ghost, link
}

public enum ButtonShape: String, CaseIterable {
    case rounded, pill, circle, square
}

public struct ThemeButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    // Appearance/state — mutated only through the modifiers below (R2).
    private var color: SemanticColor = .primary
    private var variant: ButtonVariant = .solid
    private var size: ButtonSize = .medium
    private var shape: ButtonShape = .rounded
    private var isFullWidth = false
    private var isLoading = false
    private var leadingSystemImage: String?
    private var trailingSystemImage: String?
    private var accessibilityID: String?

    private let title: String?
    private let action: () -> Void
    /// Caller-provided label content (HeroUI `Button` custom-children parity).
    /// Set only by the `init(action:label:)` overload — the label is *content*,
    /// so per R1 it lives in the init, not in an appearance modifier.
    private var customLabel: AnyView?

    /// Scales the button's footprint with Dynamic Type, in lock-step with its
    /// label (which scales via `textStyle`), so the height/text ratio is
    /// preserved and large-text labels never clip. 1.0 at the default text size.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public init(_ title: String? = nil, action: @escaping () -> Void) {   // R1
        self.title = title
        self.action = action
    }

    /// Custom label slot: replaces the built-in title/icon `HStack` with
    /// caller-provided content (compose icons, text, badges, …) while keeping
    /// every other axis — variant/color fill, size footprint, shape, loading,
    /// press feedback, haptics. The slot inherits the size's `textStyle` and the
    /// variant's token foreground exactly like the built-in label, so plain
    /// `Text`/`Image(systemName:)` children pick up the right type ramp & tint.
    ///
    ///     ThemeButton {
    ///         checkout()
    ///     } label: {
    ///         HStack { Image(systemName: "cart"); Text("Checkout"); Badge("3") }
    ///     }
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> some View) {   // R1
        self.title = nil
        self.action = action
        self.customLabel = AnyView(label())
    }

    private var isIconOnly: Bool { shape == .circle || shape == .square }

    public var body: some View {
        let button = Button {
            guard !isLoading else { return }
            Haptics.tap()
            action()
        } label: {
            content
                // minHeight (not a fixed height) so a label that wraps to two
                // lines at large Dynamic Type sizes grows the button instead of
                // being clipped. Icon-only buttons pin width == height (min==max)
                // to keep a square footprint.
                .frame(
                    minWidth: isIconOnly ? size.height * typeScale : nil,
                    maxWidth: isIconOnly ? size.height * typeScale : nil,
                    minHeight: size.height * typeScale
                )
                .frame(maxWidth: isFullWidth && !isIconOnly ? .infinity : nil)
                .padding(.horizontal, isIconOnly ? 0 : size.horizontalPadding)
                .foregroundStyle(foreground)
                .contentShape(Rectangle())
        }
        .buttonStyle(FillButtonStyle(
            shape: shapeStyle,
            resting: background,
            pressed: pressedBackground,
            stroke: variant == .outline ? (isEnabled ? color.border : theme.border(.borderPrimary)) : nil
        ))
        .disabled(!isEnabled)
        .a11y(A11yElement.Action.button, in: accessibilityID)
        .accessibilityValue(isLoading ? String(themeKit: "Loading") : "")

        // A custom label speaks for itself — overriding it with the (nil) title
        // would silence the slot's text for VoiceOver.
        if customLabel == nil {
            button.accessibilityLabel(title ?? "")
        } else {
            button
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(foreground)
        } else if let customLabel {
            // Slot content gets the same environment the built-in label gets:
            // the size's type ramp (child Texts inherit the font) and — via the
            // shared `.foregroundStyle(foreground)` applied in `body` — the
            // variant's token foreground.
            customLabel
                .textStyle(size.textStyle)
        } else if isIconOnly {
            // Icon-only: render the single provided glyph (leading takes
            // precedence), no label.
            if let glyph = leadingSystemImage ?? trailingSystemImage {
                Image(systemName: glyph).font(.system(size: size.fontSize, weight: .semibold))
            }
        } else {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage).font(.system(size: size.fontSize, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .textStyle(size.textStyle)
                        .underline(variant == .link)
                        .lineLimit(1)              // a single-word label never wraps; a ButtonGroup flows instead
                }
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage).font(.system(size: size.fontSize, weight: .semibold))
                }
            }
        }
    }

    private var foreground: Color {
        guard isEnabled else { return theme.text(.textDisabled) }
        switch variant {
        case .solid: return color.onSolid
        case .soft, .outline, .ghost, .link: return color.accent
        }
    }

    private var background: Color {
        guard isEnabled else { return variant == .solid ? theme.background(.bgSecondary) : .clear }
        switch variant {
        case .solid: return color.solid
        case .soft: return color.soft
        case .outline, .ghost, .link: return .clear
        }
    }

    /// Pressed-state fill — the iOS analog of Ant's hover/active, sourced from the
    /// color's primitive ladder. Solid darkens (`active`), soft strengthens
    /// (`bgHover`), bordered/ghost wash in a faint tint (`bg`).
    private var pressedBackground: Color {
        guard isEnabled else { return background }
        switch variant {
        case .solid: return color == .neutral ? background : color.active
        case .soft: return color.bgHover
        case .outline, .ghost, .link: return color.bg
        }
    }

    private var shapeStyle: AnyShape {
        switch shape {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous))
        case .square: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        case .pill, .circle: return AnyShape(Capsule())
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ThemeButton {
    /// Visual treatment: solid / soft / outline / ghost / link.
    func variant(_ v: ButtonVariant) -> Self { copy { $0.variant = v } }

    /// Semantic color token driving the fill/accent ladder (R4).
    func color(_ c: SemanticColor) -> Self { copy { $0.color = c } }

    /// Control size: xxsmall … large.
    func size(_ s: ButtonSize) -> Self { copy { $0.size = s } }

    /// Corner treatment: rounded / pill / circle / square (circle & square are icon-only).
    func shape(_ s: ButtonShape) -> Self { copy { $0.shape = s } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isFullWidth = on } }

    /// Swap the label for a spinner and block taps while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Leading and/or trailing SF Symbol. On a circle/square button the leading
    /// glyph (or the trailing one if no leading) becomes the icon.
    func icon(leading: String? = nil, trailing: String? = nil) -> Self {
        copy { $0.leadingSystemImage = leading; $0.trailingSystemImage = trailing }
    }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Tactile press/active feedback (the iOS equivalent of Ant Design's hover/active
/// interaction states). Used by the preset button family in `Buttons.swift`.
/// The press *scale* + its tween are gated by `microAnimations` + Reduce Motion;
/// the opacity dim (a state, not motion) stays as a press affordance.
public struct PressFeedbackStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        PressFeedbackBody(configuration: configuration)
    }
}

private struct PressFeedbackBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var on: Bool { micro && !reduceMotion }

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(on && configuration.isPressed ? 0.97 : 1)
            .animation(on ? Motion.instant.animation : nil, value: configuration.isPressed)
    }
}

/// Press feedback for full-width tappable surfaces (rows, cards, menu items)
/// where a scale would look wrong — highlights the background instead. The iOS
/// analog of Ant's row hover state. Reusable by any `Button`-based component.
public struct RowPressStyle: ButtonStyle {
    private let cornerRadius: CGFloat

    /// Raw-CGFloat corner. Prefer `init(radius:)` with a `Theme.RadiusRole` so a
    /// theme can re-round every row from one token. Not (yet) deprecated: the
    /// zero-radius default (`RowPressStyle()`) and in-kit callers passing size
    /// keys (`ListRow`) still route through here without a token equivalent.
    public init(cornerRadius: CGFloat = 0) { self.cornerRadius = cornerRadius }

    /// Token-fed corner: resolves the semantic radius *role* (box / field /
    /// selector) from the active theme — the preferred initializer (R4).
    public init(radius: Theme.RadiusRole) { self.cornerRadius = radius.value }
    public func makeBody(configuration: Configuration) -> some View {
        RowPressBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct RowPressBody: View {
    @Environment(\.theme) private var theme

    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var on: Bool { micro && !reduceMotion }

    var body: some View {
        configuration.label
            .background(
                configuration.isPressed ? theme.background(.bgElevatorTertiary) : .clear,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .animation(on ? Motion.instant.animation : nil, value: configuration.isPressed)
    }
}

/// Fill-aware press style: swaps the background to a darker/stronger ladder shade
/// while pressed (Ant active), paints the optional outline stroke, and adds a
/// subtle scale. This is what gives `ThemeButton` real interaction states.
struct FillButtonStyle: ButtonStyle {
    let shape: AnyShape
    let resting: Color
    let pressed: Color
    let stroke: Color?

    func makeBody(configuration: Configuration) -> some View {
        FillButtonBody(configuration: configuration, shape: shape, resting: resting, pressed: pressed, stroke: stroke)
    }
}

private struct FillButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let shape: AnyShape
    let resting: Color
    let pressed: Color
    let stroke: Color?
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var on: Bool { micro && !reduceMotion }

    var body: some View {
        configuration.label
            .background(configuration.isPressed ? pressed : resting, in: shape)
            .overlay { if let stroke { shape.stroke(stroke, lineWidth: 1.5) } }
            .scaleEffect(on && configuration.isPressed ? 0.97 : 1)
            .animation(on ? Motion.instant.animation : nil, value: configuration.isPressed)
    }
}

extension ButtonSize {
    var fontSize: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return 12
        case .small: return 14
        case .medium, .large: return 16
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SemanticColor.allCases, id: \.self) { c in
                HStack {
                    ThemeButton("Solid") {}.color(c).variant(.solid).size(.small)
                    ThemeButton("Soft") {}.color(c).variant(.soft).size(.small)
                    ThemeButton("Outline") {}.color(c).variant(.outline).size(.small)
                }
            }
            HStack {
                ThemeButton { }.icon(leading: "heart").color(.error).shape(.circle)
                ThemeButton { }.icon(leading: "plus").color(.primary).shape(.square)
                ThemeButton("Pill") {}.color(.success).shape(.pill)
                ThemeButton("Link") {}.variant(.link)
            }
            ThemeButton("Block button") {}.color(.primary).fullWidth()
            ThemeButton("Loading") {}.color(.primary).fullWidth().loading()
        }
        .padding()
    }
}
