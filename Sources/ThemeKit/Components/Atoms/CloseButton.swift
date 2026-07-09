//
//  CloseButton.swift
//  ThemeKit
//
//  Atom. A circular dismiss button — the standard "×" affordance for sheets,
//  banners, tags and media overlays (HeroUI Native CloseButton parity: a
//  tertiary icon-only button with a muted glyph and a generous hit slop).
//  Action-only and token-bound; size rides the native `.controlSize(_:)`
//  cascade, disabled rides the native `.disabled(_:)` (R3).
//
//      CloseButton { dismiss() }
//          .tint(.error)               // semantic glyph tint
//          .plain()                    // bare glyph for image overlays
//          .controlSize(.small)        // native size
//          .disabled(isBusy)           // native — R3
//

import SwiftUI

private extension ControlSize {
    /// Circle diameter for the close button — maps the native control size to
    /// fixed atom metrics (mini 24 / small 28 / regular+ 32, the reference's
    /// `h-8` small icon-only button). The tap target stays >= 44pt regardless.
    var closeButtonDiameter: CGFloat {
        switch self {
        case .mini: return 24
        case .small: return 28
        default: return 32   // .regular (default) / .large / .extraLarge
        }
    }
}

/// A circular icon-only dismiss button. The glyph (default `xmark`) sits on a
/// tertiary elevator circle; `.plain()` drops the fill for use over images.
/// All chroma comes from theme tokens, so the atom re-skins with the theme.
public struct CloseButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var tint: SemanticColor?
    private var systemImage: String = "xmark"
    private var isPlain: Bool = false
    private var accessibilityID: String?

    /// Minimum tap side per the HIG; the visual circle floats centered inside it.
    private static let minimumHitSide: CGFloat = 44

    public init(action: @escaping () -> Void) {   // R1 — action only
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            glyph
                .frame(width: diameter, height: diameter)
                .background {
                    if !isPlain {
                        Circle().fill(theme.background(.bgElevatorTertiary))
                    }
                }
                .frame(minWidth: Self.minimumHitSide, minHeight: Self.minimumHitSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .a11y(A11yElement.Action.close, in: accessibilityID)
        .accessibilityLabel(String(themeKit: "Close"))
        .accessibilityAddTraits(.isButton)
    }

    private var diameter: CGFloat { controlSize.closeButtonDiameter }

    private var glyph: some View {
        Image(systemName: systemImage)
            .font(.system(size: diameter * 0.44, weight: .semibold))
            .foregroundStyle(glyphColor)
    }

    /// Disabled always wins; then the semantic tint; else the muted default.
    private var glyphColor: Color {
        guard isEnabled else { return theme.text(.textDisabled) }
        if let tint { return tint.accent }
        return theme.text(.textTertiary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CloseButton {
    /// Semantic glyph tint; `nil` (default) uses the muted `textTertiary` token.
    func tint(_ c: SemanticColor?) -> Self { copy { $0.tint = c } }

    /// Swaps the SF Symbol glyph (default `"xmark"`).
    func systemImage(_ name: String) -> Self { copy { $0.systemImage = name } }

    /// Drops the circle fill, leaving a bare ghost glyph — for image overlays
    /// and dense chrome where the elevator surface would be noise.
    func plain(_ on: Bool = true) -> Self { copy { $0.isPlain = on } }

    /// Stable accessibility-identifier namespace (the button gets `"<id>.close"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
        // Default across the native size cascade.
        HStack(spacing: Theme.SpacingKey.sm.value) {
            CloseButton {}.controlSize(.mini)
            CloseButton {}.controlSize(.small)
            CloseButton {}
        }
        // Semantic tint, glyph swap, disabled.
        HStack(spacing: Theme.SpacingKey.sm.value) {
            CloseButton {}.tint(.error)
            CloseButton {}.systemImage("chevron.down")
            CloseButton {}.disabled(true)
        }
        // Plain ghost glyph over a hero (image-like) surface.
        HStack(spacing: Theme.SpacingKey.sm.value) {
            CloseButton {}.plain().tint(.neutral)
            CloseButton {}.plain().tint(.error)
        }
        .padding(Theme.SpacingKey.sm.value)
        .background(Theme.shared.background(.bgHero),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        // Dark / themed case.
        HStack(spacing: Theme.SpacingKey.sm.value) {
            CloseButton {}
            CloseButton {}.tint(.error)
            CloseButton {}.disabled(true)
        }
        .padding(Theme.SpacingKey.sm.value)
        .environment(\.colorScheme, .dark)
        .background(Theme.shared.background(.bgTertiary),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
    }
    .padding()
}
