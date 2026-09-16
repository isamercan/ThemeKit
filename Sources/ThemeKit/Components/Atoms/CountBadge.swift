//
//  CountBadge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Ant "Badge": a small count / dot overlaid on the corner of any view, plus a
//  corner Ribbon. (Our `Badge` atom is Ant's "Tag"; this fills the real Ant
//  Badge role.) `CountBadge` is the bubble itself, usable on its own; the
//  `countBadge(_:)` overlay places one on a view's corner.
//

import SwiftUI

public extension View {
    /// Overlays a count bubble in the top-trailing corner (Ant `Badge count`).
    /// The bubble is a ``CountBadge`` nudged 9pt outward, so a
    /// ``CountBadgeStyle`` set on an ancestor restyles it too; place a
    /// `CountBadge` yourself for a different position.
    func countBadge(_ count: Int, overflowCount: Int = 99, showZero: Bool = false, color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) {
            CountBadge(count)
                .overflowCount(overflowCount)
                .showsZero(showZero)
                .accent(color)
                .offset(x: 9, y: -9)
        }
    }

    /// Overlays a status dot in the top-trailing corner (Ant `Badge dot`).
    func dotBadge(color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) { DotBadge(color: color) }
    }
}

/// A count bubble (Ant `Badge count`): a small solid capsule holding a
/// number, a short host string such as `"+1"`, or a glyph. Place it anywhere,
/// or overlay one on a view's corner with `countBadge(_:)`.
///
/// ```swift
/// CountBadge(5)                                   // "5", locale-formatted
/// CountBadge(128).overflowCount(99)               // "99+"
/// CountBadge("+1").accent(.primary)
/// CountBadge { Image(systemName: "checkmark") }.halo(false)
/// ```
///
/// The chrome is drawn by the active ``CountBadgeStyle`` when one is set with
/// `.countBadgeStyle(_:)`; the badge keeps the content model, the count
/// formatting and overflow cap, the zero rule, and accessibility (on the style
/// path the bubble reads as one VoiceOver element). It hands the style the
/// environment's enabled state and control size — the default chrome ignores
/// both.
public struct CountBadge: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.countBadgeStyle) private var style

    private enum Source {
        case count(Int)
        case text(String)
        case glyph(AnyView)
    }

    private let source: Source
    // Appearance — mutated only through the modifiers below (R2).
    private var accent: SemanticColor = .error
    private var overflowCount: Int = 99
    private var showsZero: Bool = false
    private var showsHalo: Bool = true

    /// A locale-formatted count. A count of zero or below renders nothing
    /// unless ``showsZero(_:)`` is on, which shows it as formatted — a
    /// negative count too (e.g. `-2`), as the `countBadge(_:)` overlay always
    /// has. Counts above ``overflowCount(_:)`` render as the cap plus `+`.
    public init(_ count: Int) {   // R1
        self.source = .count(count)
    }

    /// Host text shown as-is (e.g. `"+1"`, `"New"`); always visible.
    public init(_ text: String) {   // R1
        self.source = .text(text)
    }

    /// A glyph in the bubble — a host icon font, an SF Symbol. Un-fonted
    /// glyphs pick up the bubble's type size and foreground; always visible.
    public init<Glyph: View>(@ViewBuilder glyph: () -> Glyph) {   // R1
        self.source = .glyph(AnyView(glyph()))
    }

    public var body: some View {
        if isVisible {
            if style.isDefault {
                bubble
            } else {
                style.makeBody(configuration: configuration)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private var isVisible: Bool {
        guard case .count(let count) = source else { return true }
        return count > 0 || showsZero
    }

    private var bubble: some View {
        label
            .font(.system(size: CountBadgeMetrics.fontSize, weight: .bold))
            .foregroundStyle(theme.resolve(accent).onSolid)
            .padding(.horizontal, CountBadgeMetrics.horizontalPadding)
            .frame(minWidth: CountBadgeMetrics.minSide, minHeight: CountBadgeMetrics.minSide)
            .background(theme.resolve(accent).solid, in: Capsule())
            .modifier(CountBadgeHalo(on: showsHalo))
    }

    @ViewBuilder private var label: some View {
        switch source {
        case .count(let count): Text(formatted(count))
        case .text(let text): Text(text)
        case .glyph(let glyph): glyph
        }
    }

    private func formatted(_ count: Int) -> String {
        count > overflowCount
            ? "\(overflowCount.formatted(.number.locale(locale)))+"
            : count.formatted(.number.locale(locale))
    }

    private var configuration: CountBadgeStyleConfiguration {
        let content: CountBadgeStyleConfiguration.Content
        let count: Int?
        switch source {
        case .count(let value):
            content = .text(formatted(value))
            count = value
        case .text(let text):
            content = .text(text)
            count = nil
        case .glyph(let glyph):
            content = .glyph(glyph)
            count = nil
        }
        return CountBadgeStyleConfiguration(
            content: content,
            count: count,
            accent: accent,
            showsHalo: showsHalo,
            isEnabled: isEnabled,
            controlSize: controlSize)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CountBadge {
    /// Semantic fill of the bubble; `nil` restores the default (`.error`).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color ?? .error } }
    /// The largest count shown as a number; larger counts read as the cap
    /// plus `+` (default 99). Applies to `init(_ count:)` only.
    func overflowCount(_ cap: Int) -> Self { copy { $0.overflowCount = cap } }
    /// Whether a count of zero or below still renders the bubble (default
    /// `false`); a negative count then shows as formatted. Applies to
    /// `init(_ count:)` only.
    func showsZero(_ on: Bool = true) -> Self { copy { $0.showsZero = on } }
    /// The ring in the page's surface colour that separates the bubble from
    /// what it overlaps (default on).
    func halo(_ on: Bool = true) -> Self { copy { $0.showsHalo = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// The stock bubble's fixed geometry (no semantic token), shared by
/// `CountBadge`'s default path and ``DefaultCountBadgeStyle``.
enum CountBadgeMetrics {
    static let fontSize: CGFloat = 11
    static let horizontalPadding: CGFloat = 5
    static let minSide: CGFloat = 18
    static let haloWidth: CGFloat = 1.5
}

/// The white separating ring. A `View` modifier so the stroke resolves the
/// injected `\.theme`.
struct CountBadgeHalo: ViewModifier {
    let on: Bool
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        if on {
            content.overlay(Capsule().strokeBorder(theme.background(.bgWhite), lineWidth: CountBadgeMetrics.haloWidth))
        } else {
            content
        }
    }
}

private struct DotBadge: View {
    let color: SemanticColor
    @Environment(\.theme) private var theme

    var body: some View {
        Circle().fill(theme.resolve(color).solid).frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 1.5))
            .offset(x: 4, y: -4)
            // Color-only status dot — decorative to VoiceOver; the host view
            // carries the semantic (e.g. an "unread" label).
            .accessibilityHidden(true)
    }
}

/// A corner ribbon wrapping any content (Ant `Badge.Ribbon`).
public struct Ribbon<Content: View>: View {
    private let text: String
    private let content: Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var color: SemanticColor = .primary

    public init(_ text: String, @ViewBuilder content: () -> Content) {   // R1 — content only
        self.text = text
        self.content = content()
    }

    @Environment(\.theme) private var theme

    public var body: some View {
        content.overlay(alignment: .topTrailing) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolve(color).onSolid)
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, 3)
                .background(theme.resolve(color).solid)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: 6, y: 8)
                .themeShadow(.soft)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Ribbon {
    /// Semantic color of the ribbon; `nil` restores the default (`.primary`).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.color = color ?? .primary } }

    /// Semantic color of the ribbon (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: SemanticColor) -> Self { copy { $0.color = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    /// Proof of external implementability: a host number tag that maps the
    /// environment control size onto its own heights and greys out when disabled.
    struct TagCountBadgeStyle: CountBadgeStyle {
        func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
            TagCountBadgeBody(configuration: configuration)
        }
    }
    struct TagCountBadgeBody: View {
        let configuration: CountBadgeStyleConfiguration
        @Environment(\.theme) private var theme

        private var side: CGFloat {
            switch configuration.controlSize {
            case .mini: return 14
            case .small: return 16
            case .regular: return 20
            default: return 24   // .large and up
            }
        }

        var body: some View {
            let hue = theme.resolve(configuration.accent)
            Group {
                switch configuration.content {
                case .text(let text): Text(text).textStyle(.labelSm700)
                case .glyph(let glyph): glyph.font(.system(size: side * 0.6))
                }
            }
            .foregroundStyle(configuration.isEnabled ? hue.onSolid : theme.text(.textDisabled))
            .padding(.horizontal, Theme.SpacingKey.xs.value)
            .frame(minWidth: side, minHeight: side)
            .background(configuration.isEnabled ? hue.solid : theme.background(.bgSecondaryLight),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        }
    }

    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("CountBadge") {
                PreviewCase("Count") {
                    Image(systemName: "bell.fill").font(.title).countBadge(5).padding(12)
                }
                PreviewCase("Overflow (99+)") {
                    Image(systemName: "envelope.fill").font(.title).countBadge(128).padding(12)
                }
                PreviewCase("Dot") {
                    Image(systemName: "cart.fill").font(.title).dotBadge(color: .success).padding(12)
                }
                PreviewCase("Standalone: text / glyph / no halo") {
                    HStack {
                        CountBadge(7)
                        CountBadge("+1").accent(.primary)
                        CountBadge { Image(systemName: "checkmark") }.accent(.success).halo(false)
                        CountBadge(0).showsZero()
                    }
                }
                PreviewCase("Custom style: sizes + disabled") {
                    HStack {
                        CountBadge(3).controlSize(.mini)
                        CountBadge("+1").accent(.primary).controlSize(.small)
                        CountBadge(128)
                        CountBadge { Image(systemName: "star.fill") }.accent(.warning).controlSize(.large)
                        CountBadge(5).disabled(true)
                        Image(systemName: "bell.fill").font(.title).countBadge(12).padding(12)
                    }
                    .countBadgeStyle(TagCountBadgeStyle())
                }
                PreviewCase("Ribbon") {
                    Ribbon("New") {
                        RoundedRectangle(cornerRadius: 12).fill(theme.background(.bgElevatorTertiary)).frame(width: 100, height: 70)
                    }
                    .accent(.error)
                    .padding(12)
                }
            }
        }
    }
    return Demo()
}
