//
//  SheetHeaderStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 18.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `SheetHeader`. The header's whole
//  layout — where the back and close buttons sit, whether the title is centred
//  or leading, the type and colour of the title and its description, and how
//  the progress line is drawn — lives in a `SheetHeaderStyle` you set with
//  `.sheetHeaderStyle(_:)`, so a host design system can lay its own sheet
//  header out while `SheetHeader` keeps the rest.
//
//      SheetHeader("Passengers")
//          .subtitle("Who is travelling?")
//          .onBack { pop() }
//          .onClose { dismiss() }
//          .sheetHeaderStyle(HostSheetHeaderStyle())
//
//  `SheetHeader` keeps: the content model (title, subtitle, back, close,
//  progress, the leading/trailing slots, the accent and the surface), the
//  progress value's meaning (a 0…1 fraction, clamped), and the accessibility —
//  the title is the header's heading, and back and close stay buttons with
//  their existing labels.
//
//  This is the outer of the two hooks. ``BarStyle`` draws the surface,
//  hairline and slot layout the *stock* header is built from; a
//  `SheetHeaderStyle` replaces the whole thing. ``DefaultSheetHeaderStyle``
//  routes back through the ambient `BarStyle`, so `.sheetHeaderStyle(.default)`
//  draws the stock header — a floating one under `.barStyle(.floating)`.
//

import SwiftUI

/// The inputs a ``SheetHeaderStyle`` renders: the header's raw strings, the
/// title ready to paint, the two wired icon buttons and their raw handlers, the
/// slots, the progress fraction and the axes.
///
/// The strings arrive raw, not as pre-styled `Text`, and ``content``,
/// ``backButton`` and ``closeButton`` carry no font and no colour, so a style
/// picks its own type style and colours. Fields a style doesn't use are simply
/// ignored; new fields may be added in a minor release.
public struct SheetHeaderStyleConfiguration {
    /// The title, as passed to ``SheetHeader/init(_:)``.
    public let title: String
    /// ``title`` as a `Text` with no font and no colour of its own, so
    /// `.textStyle(_:)` / `.font(_:)` and `.foregroundStyle(_:)` applied to it
    /// take effect. Use it (rather than `Text(configuration.title)`): it
    /// carries the header's VoiceOver heading and keeps the title's identity
    /// stable across renders.
    public let content: AnyView
    /// The description line under the title (``SheetHeader/subtitle(_:)``);
    /// `nil` when unset. It is its own VoiceOver element, so drawing it does
    /// not repeat the heading.
    public let subtitle: String?
    /// The back button, wired: ThemeKit's plain button around the stock
    /// chevron, calling the handler, carrying the "Back" VoiceOver label and
    /// already turned for a right-to-left layout. Its label has no font and no
    /// colour of its own, so `.font(_:)` and `.foregroundStyle(_:)` applied to
    /// it size and tint the glyph — the host's metrics on ThemeKit's button.
    /// `nil` when no handler is set (`SheetHeader` never draws a button it
    /// can't trigger).
    ///
    /// It is ThemeKit's SF Symbol. A style that wants its own icon font draws
    /// its own button from ``onBack`` instead, and gives it a VoiceOver label.
    public let backButton: AnyView?
    /// The back handler, for a style that draws its own button; `nil` when unset.
    public let onBack: (() -> Void)?
    /// The close button, wired: ThemeKit's plain button around the stock cross,
    /// carrying the "Close" VoiceOver label, with an unpainted label. `nil`
    /// when no handler is set. See ``backButton`` for drawing your own.
    public let closeButton: AnyView?
    /// The close handler, for a style that draws its own button; `nil` when unset.
    public let onClose: (() -> Void)?
    /// The multi-step flow's progress (``SheetHeader/progress(_:)``); `nil`
    /// when unset. It is a fraction of the flow — a style clamps it to 0…1, as
    /// the stock line does, and labels whatever it draws for it.
    public let progress: Double?
    /// The ``SheetHeader/leading(_:)`` slot, exactly as written; `nil` when
    /// unset. When it is set it *replaces* the back button, which is why
    /// ``backButton`` can be non-`nil` beside it: draw the slot when it's there.
    public let leading: AnyView?
    /// The ``SheetHeader/trailing(_:)`` slot, exactly as written; `nil` when
    /// unset. It replaces the close button the same way ``leading`` replaces
    /// the back button.
    public let trailing: AnyView?
    /// The tint the progress line fills with (``SheetHeader/accent(_:)``);
    /// `nil` means the stock `.primary`. Resolve it from the environment theme.
    public let accent: SemanticColor?
    /// ``SheetHeader/showsDivider(_:)`` exactly as it was set. The stock rule
    /// is that a progress line replaces the divider, so the stock header draws
    /// the hairline only while this is `true` *and* ``progress`` is `nil`.
    public let showsDivider: Bool
    /// The environment's control size (`.controlSize(_:)`), for a style with a
    /// size ramp. The stock style ignores it — the header has one size.
    public let controlSize: ControlSize
}

/// Draws a `SheetHeader`. Implement `makeBody` to lay out the configuration's
/// title, description, buttons, slots and progress line, and give each its type
/// and colour. Set one with `.sheetHeaderStyle(_:)`; the default is
/// ``DefaultSheetHeaderStyle``.
///
/// The style draws; `SheetHeader` keeps the behaviour. The two icon buttons
/// arrive wired (with their raw handlers beside them, for a style that draws
/// its own), the title carries the heading semantics, and the component's
/// `surface(_:)` / `showsDivider(_:)` overrides ride the public
/// `\.barChromeOverrides` environment value, which a style may read and honour.
///
/// **What reaches the style.** One body draws every header the component can
/// hold: title only, title + description, back and/or close, either replaced by
/// a ``SheetHeaderStyleConfiguration/leading`` or
/// ``SheetHeaderStyleConfiguration/trailing`` slot, and a progress line in
/// place of the divider.
///
/// **Relation to ``BarStyle``.** While no `SheetHeaderStyle` is set, the header
/// composes its stock centre block and slots and hands them to the ambient
/// `BarStyle`. A `SheetHeaderStyle` replaces that whole arrangement, so a
/// `BarStyle` set alongside it is not consulted — unless the style hands the
/// header back to ``DefaultSheetHeaderStyle``, which routes through it.
///
/// ```swift
/// struct HostSheetHeaderStyle: SheetHeaderStyle {
///     func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
///         HostSheetHeaderBody(configuration: configuration)
///     }
/// }
///
/// private struct HostSheetHeaderBody: View {
///     let configuration: SheetHeaderStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
///             HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
///                 configuration.backButton?
///                     .font(.system(size: 14, weight: .semibold))
///                     .foregroundStyle(theme.text(.textPrimary))
///                 configuration.content
///                     .textStyle(.headingSm)
///                     .foregroundStyle(theme.text(.textPrimary))
///                 Spacer(minLength: Theme.SpacingKey.sm.value)
///                 configuration.closeButton?
///                     .font(.system(size: 14, weight: .semibold))
///                     .foregroundStyle(theme.text(.textSecondary))
///             }
///             if let subtitle = configuration.subtitle {
///                 Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
///             }
///         }
///         .padding(Theme.SpacingKey.md.value)
///     }
/// }
/// ```
public protocol SheetHeaderStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SheetHeaderStyleConfiguration) -> Body
}

/// The stock header — exactly the look `SheetHeader` draws with no style set:
/// the title in `labelLg700` over an optional `bodySm400` description, centred
/// in a 56 pt row with the back and close buttons in their 44 pt slots, and the
/// progress line under it. It composes the same centre block the built-in path
/// composes and hands it to the ambient ``BarStyle``, so an injected theme —
/// and a `.barStyle(_:)` set alongside — re-skin it too.
public struct DefaultSheetHeaderStyle: SheetHeaderStyle, Sendable {
    public init() {}
    public func makeBody(configuration: SheetHeaderStyleConfiguration) -> some View {
        DefaultSheetHeaderChrome(configuration: configuration)
    }
}

/// Mirrors `SheetHeader`'s built-in body: the same centre block, the same
/// painted slots, the same `BarStyle`. `SheetHeaderStyleTests` renders both and
/// compares the pixels, so the two can't drift apart unnoticed.
private struct DefaultSheetHeaderChrome: View {
    let configuration: SheetHeaderStyleConfiguration
    @Environment(\.theme) private var theme
    @Environment(\.barStyle) private var barStyle

    var body: some View {
        barStyle.makeBody(configuration: BarStyleConfiguration(
            leading: configuration.leading ?? painted(configuration.backButton),
            content: AnyView(SheetHeaderContent(title: configuration.content,
                                                subtitle: configuration.subtitle,
                                                progress: configuration.progress,
                                                accent: configuration.accent)),
            trailing: configuration.trailing ?? painted(configuration.closeButton),
            edge: .top))
    }

    /// The stock glyph metrics on a wired icon button: the header's icon font,
    /// the primary text colour and the bar's square slot.
    private func painted(_ button: AnyView?) -> AnyView? {
        guard let button else { return nil }
        return AnyView(
            button
                .font(.system(size: SheetHeaderMetrics.glyphPoints, weight: .semibold))
                .foregroundStyle(theme.text(.textPrimary))
                .frame(width: BarMetrics.slotSize, height: BarMetrics.slotSize)
        )
    }
}

// MARK: - Shared stock pieces (both chrome paths)

/// The stock header's type ramp and fixed geometry, shared by `SheetHeader`'s
/// built-in body and ``DefaultSheetHeaderStyle`` so the two can't drift apart.
enum SheetHeaderMetrics {
    /// Gap between the title and its description.
    static let titleSpacing: CGFloat = 1
    /// Point size of the stock back / close glyph.
    static let glyphPoints: CGFloat = 16
    /// Thickness of the progress line.
    static let progressHeight: CGFloat = 3
    // Computed: `TextStyle` isn't `Sendable`, so these can't be stored globals.
    static var titleStyle: TextStyle { .labelLg700 }
    static var subtitleStyle: TextStyle { .bodySm400 }
}

/// The header's centre block — the title (+ description) row over the optional
/// full-width progress line. It reserves `BarMetrics.contentInset` on both
/// sides so the text never underlaps the slots a `BarStyle` overlays.
struct SheetHeaderContent: View {
    /// The title, unpainted — the same view the configuration carries.
    let title: AnyView
    let subtitle: String?
    let progress: Double?
    let accent: SemanticColor?

    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SheetHeaderMetrics.titleSpacing) {
                title
                    .textStyle(SheetHeaderMetrics.titleStyle)
                    .foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(SheetHeaderMetrics.subtitleStyle)
                        .foregroundStyle(theme.text(.textSecondary))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, BarMetrics.contentInset(density))
            .frame(maxWidth: .infinity)
            .frame(height: BarMetrics.rowHeight)

            if let progress {
                SheetHeaderProgressBar(value: progress, accent: accent)
            }
        }
    }
}

/// The header's multi-step progress line: the accent filling a
/// `borderPrimary` track, read to VoiceOver as one locale-formatted percentage.
struct SheetHeaderProgressBar: View {
    let value: Double
    let accent: SemanticColor?

    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    private var fraction: Double { SheetHeaderAccessibility.clamped(value) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.border(.borderPrimary))
                Rectangle()
                    .fill(theme.resolve(accent ?? .primary).base)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: SheetHeaderMetrics.progressHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SheetHeaderAccessibility.progressLabel)
        .accessibilityValue(SheetHeaderAccessibility.progressValue(value, locale: locale))
    }
}

public extension SheetHeaderStyle where Self == DefaultSheetHeaderStyle {
    /// The stock sheet header (today's `SheetHeader` look, through the ambient
    /// ``BarStyle``).
    static var `default`: DefaultSheetHeaderStyle { DefaultSheetHeaderStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySheetHeaderStyle: SheetHeaderStyle {
    /// `true` only for the environment key's stock default below. `SheetHeader`
    /// checks it: while the environment still carries the default it draws its
    /// own body through the ambient `BarStyle`, unchanged; any style set with
    /// `.sheetHeaderStyle(_:)` — including `.default` — is unmarked and goes
    /// through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (SheetHeaderStyleConfiguration) -> AnyView
    init<S: SheetHeaderStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SheetHeaderStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SheetHeaderStyleKey: EnvironmentKey {
    static let defaultValue = AnySheetHeaderStyle(DefaultSheetHeaderStyle(), isDefault: true)
}

extension EnvironmentValues {
    var sheetHeaderStyle: AnySheetHeaderStyle {
        get { self[SheetHeaderStyleKey.self] }
        set { self[SheetHeaderStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SheetHeaderStyle`` for the `SheetHeader`s in this view and its
    /// descendants.
    func sheetHeaderStyle<S: SheetHeaderStyle>(_ style: sending S) -> some View {
        environment(\.sheetHeaderStyle, AnySheetHeaderStyle(style))
    }
}
