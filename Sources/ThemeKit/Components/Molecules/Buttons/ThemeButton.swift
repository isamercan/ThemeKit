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
    @Environment(\.componentDefaults) private var componentDefaults
    @Environment(\.buttonGroupControlSize) private var groupSize   // set by an enclosing sized `ButtonGroup`

    // Appearance/state — mutated only through the modifiers below (R2).
    /// Explicit `.color(_:)`; `nil` defers to the subtree `componentDefaults`
    /// accent, then `.primary` (provider cascade, F3).
    private var explicitColor: SemanticColor?
    private var variant: ButtonVariant = .solid
    /// Explicit `.size(_:)`; `nil` defers to an enclosing sized ``ButtonGroup``,
    /// then `.medium` — the same explicit-wins cascade as `.color`.
    private var explicitSize: ButtonSize?
    private var shape: ButtonShape = .rounded
    private var isFullWidth = false
    private var isLoading = false
    /// When set, `.loading(_:)` keeps the label and shows the spinner on this
    /// edge instead of replacing the content (A7).
    private var spinnerEdge: HorizontalEdge?
    private var leadingSystemImage: String?
    private var trailingSystemImage: String?
    private var accessibilityID: String?
    /// Web/HeroUI density (compact heights); default is the touch ramp.
    private var density: ButtonDensity = .regular
    /// Forces a square-footprint icon button at the current shape's corner —
    /// decoupled from `.circle`/`.square` (HeroUI `iconOnly` property).
    private var iconOnlyOverride = false
    /// Prefix/suffix element slots (Figma "Prefix"/"Suffix" — any view). Each
    /// wins over the SF-Symbol `icon(leading:trailing:)` on its side.
    private var prefixView: AnyView?
    private var suffixView: AnyView?
    /// Drives the visible focus ring (Figma focus state · accessibility).
    @FocusState private var isFocused: Bool

    /// The resolved semantic color: explicit modifier ?? subtree
    /// `componentDefaults.accent` ?? `.primary`.
    private var color: SemanticColor { explicitColor ?? componentDefaults.accent ?? .primary }
    /// The resolved control size: explicit modifier ?? enclosing `ButtonGroup`
    /// size ?? `.medium`.
    private var size: ButtonSize { explicitSize ?? groupSize ?? .medium }
    /// Bound once per body read — resolves `color` against the environment
    /// theme (ADR-0006), honoring per-subtree `.theme(_:)`.
    private var resolvedColor: SemanticColor.Resolved { theme.resolve(color) }

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

    private var isIconOnly: Bool { iconOnlyOverride || shape == .circle || shape == .square }

    // Density-aware size resolution (regular touch ramp vs compact web ramp).
    private var sizeHeight: CGFloat { density == .compact ? size.compactHeight : size.height }
    private var sizePadding: CGFloat { density == .compact ? size.compactHorizontalPadding : size.horizontalPadding }
    private var sizeTextStyle: TextStyle { density == .compact ? size.compactTextStyle : size.textStyle }
    private var sizeFontSize: CGFloat { density == .compact ? size.compactFontSize : size.fontSize }

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
                    minWidth: isIconOnly ? sizeHeight * typeScale : nil,
                    maxWidth: isIconOnly ? sizeHeight * typeScale : nil,
                    minHeight: sizeHeight * typeScale
                )
                .frame(maxWidth: isFullWidth && !isIconOnly ? .infinity : nil)
                .padding(.horizontal, isIconOnly ? 0 : sizePadding)
                .foregroundStyle(foreground)
                .contentShape(Rectangle())
        }
        .buttonStyle(FillButtonStyle(
            shape: shapeStyle,
            resting: background,
            pressed: pressedBackground,
            stroke: variant == .outline ? (isEnabled ? resolvedColor.border : theme.border(.borderPrimary)) : nil
        ))
        .disabled(!isEnabled)
        .a11y(A11yElement.Action.button, in: accessibilityID)
        .accessibilityValue(isLoading ? String(themeKit: "Loading") : "")
        .focused($isFocused)
        .overlay { focusRing }

        // A custom label speaks for itself — overriding it with the (nil) title
        // would silence the slot's text for VoiceOver.
        if customLabel == nil {
            button.accessibilityLabel(title ?? "")
        } else {
            button
        }
    }

    /// `true` while the spinner should render *alongside* the label
    /// (`spinnerPlacement` set) instead of replacing it. Icon-only buttons
    /// always replace — there is no label to keep.
    private var spinnerInline: Bool { isLoading && spinnerEdge != nil && !isIconOnly }

    /// The inline loading spinner, sized down to sit next to the label text.
    private var inlineSpinner: some View {
        ProgressView().tint(foreground).controlSize(.small)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && !spinnerInline {
            ProgressView().tint(foreground)
        } else if let customLabel {
            // Slot content gets the same environment the built-in label gets:
            // the size's type ramp (child Texts inherit the font) and — via the
            // shared `.foregroundStyle(foreground)` applied in `body` — the
            // variant's token foreground.
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if spinnerInline && spinnerEdge == .leading { inlineSpinner }
                customLabel
                    .textStyle(sizeTextStyle)
                if spinnerInline && spinnerEdge == .trailing { inlineSpinner }
            }
        } else if isIconOnly {
            // Icon-only: a single glyph — prefix slot ▸ suffix slot ▸ the
            // leading/trailing SF Symbol. No label.
            if let prefixView {
                prefixView
            } else if let suffixView {
                suffixView
            } else if let glyph = leadingSystemImage ?? trailingSystemImage {
                Image(systemName: glyph).font(.system(size: sizeFontSize, weight: .semibold))
            }
        } else {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if spinnerInline && spinnerEdge == .leading { inlineSpinner }
                // Leading: the prefix element slot wins over the SF-Symbol icon.
                if let prefixView {
                    prefixView
                } else if let leadingSystemImage {
                    Image(systemName: leadingSystemImage).font(.system(size: sizeFontSize, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .underline(variant == .link)   // Text-level: before .textStyle (View form is iOS 16+)
                        .textStyle(sizeTextStyle)
                        .lineLimit(1)              // a single-word label never wraps; a ButtonGroup flows instead
                }
                // Trailing: the suffix element slot wins over the SF-Symbol icon.
                if let suffixView {
                    suffixView
                } else if let trailingSystemImage {
                    Image(systemName: trailingSystemImage).font(.system(size: sizeFontSize, weight: .semibold))
                }
                if spinnerInline && spinnerEdge == .trailing { inlineSpinner }
            }
        }
    }

    private var foreground: Color {
        guard isEnabled else { return theme.text(.textDisabled) }
        switch variant {
        case .solid: return resolvedColor.onSolid
        case .soft, .outline, .ghost, .link: return resolvedColor.accent
        }
    }

    private var background: Color {
        guard isEnabled else { return variant == .solid ? theme.background(.bgSecondary) : .clear }
        switch variant {
        case .solid: return resolvedColor.solid
        case .soft: return resolvedColor.soft
        case .outline, .ghost, .link: return .clear
        }
    }

    /// Pressed-state fill — the iOS analog of Ant's hover/active, sourced from the
    /// color's primitive ladder. Solid darkens (`active`), soft strengthens
    /// (`bgHover`), bordered/ghost wash in a faint tint (`bg`).
    private var pressedBackground: Color {
        guard isEnabled else { return background }
        switch variant {
        case .solid: return color == .neutral ? background : resolvedColor.active
        case .soft: return resolvedColor.bgHover
        case .outline, .ghost, .link: return resolvedColor.bg
        }
    }

    private var shapeStyle: AnyShape {
        switch shape {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous))
        case .square: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        case .pill, .circle: return AnyShape(Capsule())
        }
    }

    /// Visible focus ring drawn just outside the button on keyboard / hardware
    /// focus (Figma focus state · accessibility). Offset outward via negative
    /// padding so it reads as a ring, tinted with the button's own accent.
    @ViewBuilder
    private var focusRing: some View {
        shapeStyle
            .stroke(resolvedColor.accent, lineWidth: 2)
            .padding(-3)
            .opacity(isFocused && isEnabled ? 1 : 0)
            .allowsHitTesting(false)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ThemeButton {
    /// Visual treatment: solid / soft / outline / ghost / link.
    func variant(_ v: ButtonVariant) -> Self { copy { $0.variant = v } }

    /// Semantic color token driving the fill/accent ladder (R4). When not set,
    /// the button reads the subtree ``ComponentDefaults`` accent (set once with
    /// `.componentDefaults(accent:)`), falling back to `.primary`.
    func color(_ c: SemanticColor) -> Self { copy { $0.explicitColor = c } }

    /// Control size: xxsmall … large. When unset, an enclosing sized
    /// ``ButtonGroup`` supplies it, else `.medium`.
    func size(_ s: ButtonSize) -> Self { copy { $0.explicitSize = s } }

    /// Corner treatment: rounded / pill / circle / square (circle & square are icon-only).
    func shape(_ s: ButtonShape) -> Self { copy { $0.shape = s } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isFullWidth = on } }

    /// Show the loading spinner and block taps while `on`. By default the
    /// spinner replaces the label; combine with ``spinnerPlacement(_:)`` to
    /// keep the label and show the spinner alongside it.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Keep the label while loading and render the spinner beside it on the
    /// given edge (HeroUI `spinnerPlacement="start"/"end"`; Ant Button
    /// `loading: { icon }`). Without it, `.loading(_:)` swaps the whole label
    /// for the spinner. Icon-only (circle/square) buttons always swap.
    /// RTL-safe — `HorizontalEdge` follows the layout direction.
    func spinnerPlacement(_ edge: HorizontalEdge) -> Self { copy { $0.spinnerEdge = edge } }

    /// Leading and/or trailing SF Symbol. On a circle/square button the leading
    /// glyph (or the trailing one if no leading) becomes the icon.
    func icon(leading: String? = nil, trailing: String? = nil) -> Self {
        copy { $0.leadingSystemImage = leading; $0.trailingSystemImage = trailing }
    }

    /// Height/padding density: `.regular` (touch, default) or `.compact`
    /// (web/HeroUI — sm/md/lg == compact small/medium/large). Pair with `.size(_:)`.
    func density(_ d: ButtonDensity) -> Self { copy { $0.density = d } }

    /// Render as a square-footprint icon-only button at the current shape's
    /// corner — decoupled from `.circle`/`.square` (HeroUI `iconOnly`). The
    /// glyph comes from `prefix`/`suffix` or `icon(leading:trailing:)`.
    func iconOnly(_ on: Bool = true) -> Self { copy { $0.iconOnlyOverride = on } }

    /// Prefix element slot rendered before the label — any view (icon, spinner,
    /// badge, avatar). Wins over the leading `icon(_:)` symbol (Figma "Prefix").
    func prefix<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.prefixView = AnyView(content()) }
    }

    /// Suffix element slot rendered after the label — any view. Wins over the
    /// trailing `icon(_:)` symbol (Figma "Suffix").
    func suffix<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.suffixView = AnyView(content()) }
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

/// Composed scale + highlight press feedback for pressable *surfaces* (cards,
/// tiles, list rows) — the analog of HeroUI's default `scale-highlight`
/// PressableFeedback, so a tappable card gets the platform-standard press
/// affordance without hand-rolling `PressFeedbackStyle` + `RowPressStyle`.
/// While pressed it washes the background in the tint's `soft` surface (or the
/// theme's elevated wash token when no tint is given) and gently scales down.
/// Scale + tween are gated by `microAnimations` + Reduce Motion; the highlight
/// (a state, not motion) always shows. Ripple feedback (HeroUI `scale-ripple`)
/// is deliberately deferred — see HEROUI_NATIVE_AUDIT.md.
///
///     Button { open(item) } label: { ItemCard(item) }
///         .buttonStyle(SurfacePressStyle())                      // default wash
///         .buttonStyle(SurfacePressStyle(radius: .field,
///                                        tint: .success))        // tinted row
public struct SurfacePressStyle: ButtonStyle {
    private let cornerRadius: CGFloat
    private let tint: SemanticColor?

    public init(radius: Theme.RadiusRole = .box, tint: SemanticColor? = nil) {
        self.cornerRadius = radius.value
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        SurfacePressBody(configuration: configuration, cornerRadius: cornerRadius, tint: tint)
    }
}

private struct SurfacePressBody: View {
    @Environment(\.theme) private var theme

    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let tint: SemanticColor?
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var on: Bool { micro && !reduceMotion }

    /// Wide surfaces scale less than compact controls (HeroUI adjusts its press
    /// scale by container width for the same reason), so 0.985 here vs the 0.97
    /// used by the button-sized styles above.
    private static let pressedScale: CGFloat = 0.985

    private var wash: Color { tint.map { theme.resolve($0).soft } ?? theme.background(.bgElevatorTertiary) }

    var body: some View {
        configuration.label
            .background(
                configuration.isPressed ? wash : .clear,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .scaleEffect(on && configuration.isPressed ? Self.pressedScale : 1)
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

#Preview {
    PreviewMatrix("ThemeButton") {
        PreviewCase("Variants × colors") {
            VStack(spacing: 12) {
                ForEach(SemanticColor.allCases, id: \.self) { c in
                    HStack {
                        ThemeButton("Solid") {}.color(c).variant(.solid).size(.small)
                        ThemeButton("Soft") {}.color(c).variant(.soft).size(.small)
                        ThemeButton("Outline") {}.color(c).variant(.outline).size(.small)
                    }
                }
            }
        }
        PreviewCase("Shapes + link") {
            HStack {
                ThemeButton { }.icon(leading: "heart").color(.error).shape(.circle)
                ThemeButton { }.icon(leading: "plus").color(.primary).shape(.square)
                ThemeButton("Pill") {}.color(.success).shape(.pill)
                ThemeButton("Link") {}.variant(.link)
            }
        }
        // Prefix/suffix element slots (Figma "Prefix"/"Suffix" — any view).
        PreviewCase("Prefix + suffix slots") {
            VStack(spacing: 12) {
                ThemeButton("Continue") {}
                    .color(.primary)
                    .prefix { Icon(systemName: "sparkles").size(.sm) }
                    .suffix { Icon(systemName: "arrow.right").size(.sm) }
                ThemeButton("Cart") {}
                    .variant(.soft).color(.primary)
                    .suffix { Badge("3").badgeStyle(.error).size(.small) }
            }
        }
        // Compact (web/HeroUI) density — small/medium/large == 32/36/40.
        PreviewCase("Compact density") {
            HStack {
                ThemeButton("Small") {}.color(.primary).density(.compact).size(.small)
                ThemeButton("Medium") {}.color(.primary).density(.compact).size(.medium)
                ThemeButton("Large") {}.color(.primary).density(.compact).size(.large)
            }
        }
        // Icon-only decoupled from shape — a rounded (not circle) icon button.
        PreviewCase("Icon-only (rounded)") {
            HStack {
                ThemeButton { }.icon(leading: "square.and.arrow.up").color(.primary).iconOnly()
                ThemeButton { }.icon(leading: "trash").color(.error).variant(.soft).iconOnly()
                ThemeButton { }.icon(leading: "ellipsis").variant(.ghost).iconOnly().density(.compact).size(.small)
            }
        }
        PreviewCase("Full width") { ThemeButton("Block button") {}.color(.primary).fullWidth() }
        PreviewCase("Loading") { ThemeButton("Loading") {}.color(.primary).fullWidth().loading() }
        // spinnerPlacement: the label stays while loading (HeroUI
        // spinnerPlacement / Ant loading.icon).
        PreviewCase("Spinner placement") {
            HStack {
                ThemeButton("Saving") {}.loading().spinnerPlacement(.leading)
                ThemeButton("Uploading") {}.variant(.soft).loading().spinnerPlacement(.trailing)
            }
        }
        // ComponentDefaults cascade: no explicit .color(_:) → the subtree
        // accent re-tints the button; an explicit color still wins.
        PreviewCase("Defaults cascade") {
            HStack {
                ThemeButton("Subtree accent") {}
                ThemeButton("Explicit wins") {}.color(.error)
            }
            .componentDefaults(accent: .turquoise)
        }
        // Custom label slot — icon + text + badge composition; inherits the
        // size's textStyle and the variant's foreground like the built-in label.
        PreviewCase("Custom label slot") {
            ThemeButton {
            } label: {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Image(systemName: "cart")
                    Text("Checkout")
                    Badge("3").badgeStyle(.error).size(.small)
                }
            }
            .variant(.soft)
            .color(.primary)
            .fullWidth()
        }
        // SurfacePressStyle — scale + highlight wash on a card-like row.
        PreviewCase("SurfacePressStyle") {
            VStack(spacing: 12) {
                Button {
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Image(systemName: "airplane.departure")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pressable card").textStyle(.labelMd700)
                            Text("Scale + highlight, token wash").textStyle(.bodySm400)
                                .foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                    }
                    .padding(Theme.SpacingKey.md.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                            .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
                    )
                }
                .buttonStyle(SurfacePressStyle())

                Button {
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Image(systemName: "checkmark.circle")
                        Text("Tinted press wash").textStyle(.labelMd700)
                        Spacer()
                    }
                    .padding(Theme.SpacingKey.md.value)
                }
                .buttonStyle(SurfacePressStyle(radius: .field, tint: .success))
            }
        }
    }
}
