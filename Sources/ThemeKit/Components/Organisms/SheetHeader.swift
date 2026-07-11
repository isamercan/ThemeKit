//
//  SheetHeader.swift
//  ThemeKit
//
//  Organism. A modal / sheet navigation header — an optional back (‹) or custom
//  leading, a centered title (+ subtitle), an optional close (✕) or custom
//  trailing, and an optional bottom progress line for multi-step flows.
//  Token-bound. (Distinct from the bottom tab ``NavigationBar``.)
//
//  Chrome (surface fill, hairline, slot layout) is drawn by the ambient
//  ``BarStyle`` (`.barStyle(_:)`, default ``DefaultBarStyle`` — pixel-identical
//  to the original header). The component composes the content and accessories
//  and hands them to the style as a ``BarStyleConfiguration``.
//
//  ```swift
//  SheetHeader("Passengers").onBack { pop() }.onClose { dismiss() }.progress(0.4)
//  ```
//

import SwiftUI

public struct SheetHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.barStyle) private var barStyle
    @Environment(\.locale) private var locale

    private let title: String
    // Content/appearance — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var onBack: (() -> Void)?
    private var onClose: (() -> Void)?
    private var progress: Double?
    private var leadingSlot: AnyView?
    private var trailingSlot: AnyView?
    private var showsDivider = true
    private var accent: SemanticColor?
    /// `nil` = the active `BarStyle` picks its own fill; set via `surface(_:)`.
    private var surfaceOverride: Theme.BackgroundColorKey?

    public init(_ title: String) { self.title = title }   // R1

    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        // `surface(_:)` / `showsDivider(_:)` must beat whatever fill/hairline
        // the style draws, without being part of the configuration. They ride
        // an internal environment value (`\.barChromeOverrides`) that the
        // built-in styles read; a progress line suppresses the hairline just
        // like the original divider rule.
        barStyle.makeBody(configuration: configuration)
            .environment(\.barChromeOverrides,
                         BarChromeOverrides(surface: surfaceOverride,
                                            showsHairline: showsDivider && progress == nil))
    }

    private var configuration: BarStyleConfiguration {
        BarStyleConfiguration(leading: leadingView,
                              content: AnyView(contentStack),
                              trailing: trailingView,
                              edge: .top)
    }

    /// Custom leading slot if set, else the back button, else empty.
    private var leadingView: AnyView? {
        if let leadingSlot { return leadingSlot }
        if let onBack { return AnyView(iconButton("chevron.left", onBack).mirrorsInRTL()) }
        return nil
    }

    /// Custom trailing slot if set, else the close button, else empty.
    private var trailingView: AnyView? {
        if let trailingSlot { return trailingSlot }
        if let onClose { return AnyView(iconButton("xmark", onClose)) }
        return nil
    }

    /// The bar's center block: title + subtitle row, then the optional
    /// full-width progress line. Reserves `BarMetrics.contentInset` on both
    /// sides so the text never underlaps the slots the style overlays —
    /// geometrically identical to the original spacer-based HStack.
    private var contentStack: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(title).textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
            }
            .padding(.horizontal, BarMetrics.contentInset(density))
            .frame(maxWidth: .infinity)
            .frame(height: BarMetrics.rowHeight)

            if let progress {
                progressBar(progress)
            }
        }
    }

    private func iconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.text(.textPrimary)).frame(width: BarMetrics.slotSize, height: BarMetrics.slotSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "xmark" ? String(themeKit: "Close") : String(themeKit: "Back"))
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.border(.borderPrimary))
                Rectangle().fill(accentBase).frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKit: "Progress"))
        // Locale-formatted fraction (e.g. "75%") — VoiceOver speaks the percent sign.
        .accessibilityValue(max(0, min(1, value)).formatted(.percent.precision(.fractionLength(0)).locale(locale)))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SheetHeader {
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// Adds a leading back (‹) button.
    func onBack(_ action: @escaping () -> Void) -> Self { copy { $0.onBack = action } }
    /// Adds a trailing close (✕) button.
    func onClose(_ action: @escaping () -> Void) -> Self { copy { $0.onClose = action } }
    /// A bottom progress line (0…1) for a multi-step flow (replaces the divider).
    func progress(_ value: Double?) -> Self { copy { $0.progress = value } }
    /// A fully custom leading accessory (replaces the back button).
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.leadingSlot = AnyView(content()) } }
    /// A fully custom trailing accessory (replaces the close button).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    /// Draw the bottom hairline divider (default on; ignored when a progress
    /// bar is shown). Wins over the hairline the active `BarStyle` would draw.
    func showsDivider(_ on: Bool) -> Self { copy { $0.showsDivider = on } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Surface fill (background token key). Wins over the fill the active
    /// `BarStyle` would draw; when unset, the style picks its own (the default
    /// style uses `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceOverride = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("SheetHeader") {
        PreviewCase("Back + close") {
            SheetHeader("Passengers").onBack { }.onClose { }
        }
        PreviewCase("Subtitle + progress line") {
            SheetHeader("Payment").subtitle("Step 3 of 4").onBack { }.onClose { }.progress(0.75)
        }
        PreviewCase("Close only") {
            SheetHeader("Filters").onClose { }
        }
        PreviewCase("Floating bar style") {
            SheetHeader("Floating").subtitle("BarStyle demo").onBack { }.onClose { }
                .barStyle(.floating)
        }
    }
}
