//
//  Icon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum IconSize: String, CaseIterable {
    case xs, sm, md, lg, xl

    /// Point size, aligned with the type scale.
    public var value: CGFloat {
        switch self {
        case .xs: return 12
        case .sm: return 16
        case .md: return 20
        case .lg: return 24
        case .xl: return 32
        }
    }

    /// Font for a Font-Awesome glyph at this size (when the FA font is bundled).
    public func font(weight: Font.Weight = .regular) -> Font {
        Font.system(size: value, weight: weight)
    }
}

/// Icon system. The Figma design system uses Font Awesome Pro, which is a
/// licensed font and cannot be bundled here. `Icon` renders an SF Symbol by
/// default; to switch to Font Awesome, bundle the FA Pro `.ttf` and render a
/// glyph with `IconSize.font` instead.
public struct Icon: View {
    @Environment(\.theme) private var theme
    private let systemName: String
    // Appearance/config — mutated only through the modifiers below (R2).
    private var size: IconSize = .md
    // ADR-0006 (Class M): store the SEMANTIC token, not a resolved `Color` — a
    // COW modifier runs before `body`, outside any environment, so resolving
    // eagerly here would freeze the `.accent(_:)` tint to `Theme.shared` and
    // ignore a subtree's `.theme(_:)` override. Resolution happens in `body`,
    // where `@Environment(\.theme)` is reachable. `rawColorOverride` (from the
    // raw-`Color` escape hatch) always wins over `accentColor` when both are
    // set — the two are kept mutually exclusive by the modifiers below, which
    // matches the historical "last modifier wins" behavior of the single
    // stored property this replaces.
    private var accentColor: SemanticColor?
    private var rawColorOverride: Color?

    /// Renders an SF Symbol at a token size.
    public init(systemName: String) {   // R1 — content only
        self.systemName = systemName
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size.value))
            .foregroundStyle(resolvedColor)
    }

    private var resolvedColor: Color {
        if let rawColorOverride { return rawColorOverride }
        if let accentColor { return theme.resolve(accentColor).base }
        return Color.primary
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Icon {
    /// Size tier: xs / sm / md / lg / xl (12/16/20/24/32 pt).
    func size(_ s: IconSize) -> Self { copy { $0.size = s } }

    /// Semantic tint; `nil` (default) inherits the surrounding `foregroundStyle`.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color; $0.rawColorOverride = nil } }

    /// Raw tint override (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: Color?) -> Self { colorOverride(c) }

    /// Module-internal raw tint, so in-package call sites stay off the
    /// deprecated `color(_:)` without changing behavior.
    internal func colorOverride(_ c: Color?) -> Self { copy { $0.rawColorOverride = c; $0.accentColor = nil } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Icon") {
        PreviewCase("Sizes") {
            HStack(spacing: 12) {
                ForEach(IconSize.allCases, id: \.self) { s in
                    Icon(systemName: "star.fill").size(s).accent(.primary)
                }
            }
        }
        PreviewCase("Inherited tint") { Icon(systemName: "star.fill").size(.lg) }
        PreviewCase("Semantic accents") {
            HStack(spacing: 12) {
                Icon(systemName: "checkmark.circle").size(.lg).accent(.success)
                Icon(systemName: "exclamationmark.triangle").size(.lg).accent(.warning)
                Icon(systemName: "xmark.octagon").size(.lg).accent(.error)
            }
        }
    }
}
