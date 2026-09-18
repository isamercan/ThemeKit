//
//  SheetHeader.swift
//  ThemeKit
//
//  Organism. A modal / sheet navigation header — an optional back (‹) or custom
//  leading, a centered title (+ subtitle), an optional close (✕) or custom
//  trailing, and an optional bottom progress line for multi-step flows.
//  Token-bound. (Distinct from the bottom tab ``NavigationBar``.)
//
//  Two styling hooks, from the outside in:
//    • ``SheetHeaderStyle`` (`.sheetHeaderStyle(_:)`) draws the whole header —
//      where the title, the back and close buttons, the subtitle and the
//      progress line sit, and what type and colour each takes. A host design
//      system whose header is laid out differently owns it from here.
//    • ``BarStyle`` (`.barStyle(_:)`, default ``DefaultBarStyle``) draws the
//      surface, hairline and slot layout the *stock* header is built from. It
//      is what the header (and ``DefaultSheetHeaderStyle``) route through while
//      no `SheetHeaderStyle` is set.
//
//  ```swift
//  SheetHeader("Passengers").onBack { pop() }.onClose { dismiss() }.progress(0.4)
//  ```
//

import SwiftUI

public struct SheetHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.barStyle) private var barStyle
    @Environment(\.sheetHeaderStyle) private var chromeStyle
    @Environment(\.controlSize) private var controlSize

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

    public var body: some View {
        // `surface(_:)` / `showsDivider(_:)` must beat whatever fill/hairline
        // the style draws, without being part of the configuration. They ride
        // an internal environment value (`\.barChromeOverrides`) that the
        // built-in styles read; a progress line suppresses the hairline just
        // like the original divider rule. It is set on both chrome paths, so a
        // custom `SheetHeaderStyle` can read it too.
        chrome
            .environment(\.barChromeOverrides,
                         BarChromeOverrides(surface: surfaceOverride,
                                            showsHairline: showsDivider && progress == nil))
    }

    @ViewBuilder private var chrome: some View {
        if chromeStyle.isDefault {
            barStyle.makeBody(configuration: barConfiguration)
        } else {
            chromeStyle.makeBody(configuration: chromeConfiguration)
        }
    }

    // MARK: Built-in path

    private var barConfiguration: BarStyleConfiguration {
        BarStyleConfiguration(leading: leadingView,
                              content: AnyView(stockContent),
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
    /// ``DefaultSheetHeaderStyle`` composes the same view, so the two paths
    /// can't drift apart.
    private var stockContent: some View {
        SheetHeaderContent(title: titleContent, subtitle: subtitle, progress: progress, accent: accent)
    }

    private func iconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: SheetHeaderMetrics.glyphPoints, weight: .semibold))
                .foregroundStyle(theme.text(.textPrimary))
                .frame(width: BarMetrics.slotSize, height: BarMetrics.slotSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SheetHeaderAccessibility.label(forGlyph: icon))
    }

    // MARK: Style path

    /// The inputs handed to a custom ``SheetHeaderStyle``. The title and the
    /// two icon buttons' labels arrive with no font and no colour, so the
    /// style's own type and tokens take effect.
    private var chromeConfiguration: SheetHeaderStyleConfiguration {
        SheetHeaderStyleConfiguration(
            title: title,
            content: titleContent,
            subtitle: subtitle,
            backButton: wiredBackButton,
            onBack: onBack,
            closeButton: wiredCloseButton,
            onClose: onClose,
            progress: progress,
            leading: leadingSlot,
            trailing: trailingSlot,
            accent: accent,
            showsDivider: showsDivider,
            controlSize: controlSize)
    }

    /// The title as an unpainted `Text` carrying the header's VoiceOver
    /// heading. Built once and used on both paths, so the semantics and the
    /// text's identity are the same whichever chrome draws it.
    private var titleContent: AnyView {
        AnyView(Text(title).modifier(SheetHeaderHeading()))
    }

    /// ThemeKit's plain back button with an unpainted label and the stock
    /// chevron, already turned for RTL; `nil` when no handler is set.
    private var wiredBackButton: AnyView? {
        guard let onBack else { return nil }
        return AnyView(wiredIconButton("chevron.left", onBack).mirrorsInRTL())
    }

    /// ThemeKit's plain close button with an unpainted label; `nil` when no
    /// handler is set.
    private var wiredCloseButton: AnyView? {
        guard let onClose else { return nil }
        return AnyView(wiredIconButton("xmark", onClose))
    }

    private func wiredIconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(SheetHeaderAccessibility.label(forGlyph: icon))
    }
}

// MARK: - Accessibility (shared by both chrome paths)

/// The header's accessibility decisions, in one place so they can be tested
/// without an accessibility tree (a unit-test host builds none).
enum SheetHeaderAccessibility {
    /// A sheet header's title is a heading, whichever chrome draws it. The
    /// subtitle stays its own element, so a style that draws it is not read
    /// twice.
    static let traits: AccessibilityTraits = .isHeader

    /// What VoiceOver calls the stock back button.
    static var backLabel: String { String(themeKit: "Back") }
    /// What VoiceOver calls the stock close button.
    static var closeLabel: String { String(themeKit: "Close") }
    /// What VoiceOver calls the progress line.
    static var progressLabel: String { String(themeKit: "Progress") }

    /// The label for one of the two stock glyphs — the close cross names the
    /// close button, anything else the back button.
    static func label(forGlyph systemImage: String) -> String {
        systemImage == "xmark" ? closeLabel : backLabel
    }

    /// A progress value's meaning: a fraction of the flow, 0…1. Anything
    /// outside clamps rather than overflowing the line.
    static func clamped(_ value: Double) -> Double { max(0, min(1, value)) }

    /// The progress line's spoken value — locale-formatted, so VoiceOver
    /// speaks the percent sign of the reader's language (e.g. "75%").
    static func progressValue(_ value: Double, locale: Locale) -> String {
        clamped(value).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

/// Marks the header's title as its heading, on both chrome paths.
struct SheetHeaderHeading: ViewModifier {
    func body(content: Content) -> some View {
        content.accessibilityAddTraits(SheetHeaderAccessibility.traits)
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
    /// Proof of external implementability: a host-shaped header — the close
    /// button at the leading edge, the title centred between two 32 pt slots,
    /// and the description under the row.
    struct CenteredSheetHeaderStyle: SheetHeaderStyle {
        func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
            CenteredSheetHeaderBody(configuration: configuration)
        }
    }
    struct CenteredSheetHeaderBody: View {
        let configuration: SheetHeaderStyleConfiguration
        @Environment(\.theme) private var theme

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                ZStack {
                    configuration.content
                        .textStyle(.labelLg700)
                        .foregroundStyle(theme.text(.textPrimary))
                    HStack {
                        slot(configuration.closeButton)
                        Spacer(minLength: Theme.SpacingKey.sm.value)
                        slot(configuration.backButton)
                    }
                }
                .frame(height: 32)
                if let subtitle = configuration.subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
        }

        @ViewBuilder private func slot(_ button: AnyView?) -> some View {
            if let button {
                button
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text(.textSecondary))
                    .frame(width: 32, height: 32)
                    .background(theme.background(.bgSecondaryLight), in: Circle())
            }
        }
    }

    return PreviewMatrix("SheetHeader") {
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
        PreviewCase("Custom SheetHeaderStyle") {
            SheetHeader("Filters")
                .subtitle("Narrow the results down")
                .onBack { }
                .onClose { }
                .sheetHeaderStyle(CenteredSheetHeaderStyle())
        }
    }
}
