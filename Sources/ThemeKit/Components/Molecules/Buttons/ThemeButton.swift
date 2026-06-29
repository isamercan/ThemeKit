//
//  ThemeButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Fully configurable button (daisyUI-style): semantic color × variant × size ×
//  shape × block × icon × loading × disabled. The named PrimaryButton /
//  SecondaryButton / … remain as ergonomic presets.
//

import SwiftUI

public enum ButtonVariant: String, CaseIterable {
    case solid, soft, outline, ghost, link
}

public enum ButtonShape: String, CaseIterable {
    case rounded, pill, circle, square
}

public enum ButtonIconPosition { case leading, trailing }

public struct ThemeButton: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let systemImage: String?
    private let iconPosition: ButtonIconPosition
    private let color: SemanticColor
    private let variant: ButtonVariant
    private let size: ButtonSize
    private let shape: ButtonShape
    private let block: Bool
    private let accessibilityID: String?
    @Binding private var isEnabled: Bool
    @Binding private var isLoading: Bool
    private let action: () -> Void

    /// Scales the button's footprint with Dynamic Type, in lock-step with its
    /// label (which scales via `textStyle`), so the height/text ratio is
    /// preserved and large-text labels never clip. 1.0 at the default text size.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public init(
        _ title: String? = nil,
        systemImage: String? = nil,
        iconPosition: ButtonIconPosition = .leading,
        color: SemanticColor = .primary,
        variant: ButtonVariant = .solid,
        size: ButtonSize = .medium,
        shape: ButtonShape = .rounded,
        block: Bool = false,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconPosition = iconPosition
        self.color = color
        self.variant = variant
        self.size = size
        self.shape = shape
        self.block = block
        self.accessibilityID = accessibilityID
        self._isEnabled = isEnabled
        self._isLoading = isLoading
        self.action = action
    }

    private var isIconOnly: Bool { shape == .circle || shape == .square }

    public var body: some View {
        Button {
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
                .frame(maxWidth: block && !isIconOnly ? .infinity : nil)
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
        .accessibilityLabel(title ?? "")
        .accessibilityValue(isLoading ? String(themeKit: "Loading") : "")
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(foreground)
        } else {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let systemImage, iconPosition == .leading {
                    Image(systemName: systemImage).font(.system(size: size.fontSize, weight: .semibold))
                }
                if let title, !isIconOnly {
                    Text(title)
                        .textStyle(size.textStyle)
                        .underline(variant == .link)
                        .lineLimit(1)              // a single-word label never wraps; a ButtonGroup flows instead
                }
                if let systemImage, iconPosition == .trailing, !isIconOnly {
                    Image(systemName: systemImage).font(.system(size: size.fontSize, weight: .semibold))
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
    public init(cornerRadius: CGFloat = 0) { self.cornerRadius = cornerRadius }
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
                    ThemeButton("Solid", color: c, variant: .solid, size: .small) {}
                    ThemeButton("Soft", color: c, variant: .soft, size: .small) {}
                    ThemeButton("Outline", color: c, variant: .outline, size: .small) {}
                }
            }
            HStack {
                ThemeButton(systemImage: "heart", color: .error, shape: .circle) {}
                ThemeButton(systemImage: "plus", color: .primary, shape: .square) {}
                ThemeButton("Pill", color: .success, shape: .pill) {}
                ThemeButton("Link", variant: .link) {}
            }
            ThemeButton("Block button", color: .primary, block: true) {}
            ThemeButton("Loading", color: .primary, block: true, isLoading: .constant(true)) {}
        }
        .padding()
    }
}
