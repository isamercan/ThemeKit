//
//  ToggleChromeStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The styling door for `ThemeToggle`'s chrome, a sibling of
//  ``CheckboxChromeStyle``. ThemeToggle keeps the behaviour — the tap that
//  flips the binding, the slide animation, the loading and read-only gates, the
//  native `.disabled(_:)` gate and the accessibility value and traits. A
//  `ToggleChromeStyle` draws the rest: the track, the knob and whatever sits in
//  or beside them.
//
//      SettingsScreen()
//          .toggleChromeStyle(MyToggleChrome())   // every ThemeToggle inside
//
//  It exists because a brand can disagree with the stock track. The off track
//  is `bg-secondary`, which some brands paint in a colour a switch shouldn't
//  wear, and `accent(_:)` only reaches the *on* track — there was no way to
//  repaint the rest without redrawing the control.
//
//  While nobody sets a style, ThemeToggle draws its built-in chrome exactly as
//  before. ``DefaultToggleChromeStyle`` (`.default`) draws that same look, so a
//  custom chrome can hand some cases back to it; setting `.default` explicitly
//  restores the built-in path for a subtree.
//

import SwiftUI

/// The inputs a ``ToggleChromeStyle`` renders: ThemeToggle's resolved state,
/// its metrics and the slots the caller filled.
///
/// Fields a style doesn't use are simply ignored; new fields may be added in a
/// minor release.
public struct ToggleChromeStyleConfiguration {
    /// Whether the switch is on. ThemeToggle owns the flip; a chrome only draws
    /// the state.
    public let isOn: Bool
    /// Whether the switch is enabled (native `.disabled(_:)`); `false` draws the
    /// disabled chrome. ThemeToggle already blocks the taps.
    public let isEnabled: Bool
    /// Whether the switch is being pressed — the live `ButtonStyle` state.
    public let isPressed: Bool
    /// Whether the subtree is read-only (`.readOnly(_:)`). ThemeToggle already
    /// ignores taps; the built-in chrome looks the same as when editable.
    public let isReadOnly: Bool
    /// Whether ``ThemeToggle/loading(_:)`` is on. The stock chrome puts a
    /// spinner in the knob and the control takes no taps.
    public let isLoading: Bool
    /// The ``ThemeToggle/thumbContent(_:)`` slot for the current state, when the
    /// caller set one. It goes inside the knob, under the loading spinner.
    public let thumb: AnyView?
    /// The ``ThemeToggle/symbols(on:off:)`` glyph for the current state — an SF
    /// Symbol name drawn in the knob; `nil` when none applies.
    public let knobSymbol: String?
    /// The ``ThemeToggle/trackSymbols(on:off:)`` glyph for the current state,
    /// drawn in the track on the side the knob vacated; `nil` when none applies.
    public let trackSymbol: String?
    /// ``ThemeToggle/accent(_:)``; `nil` means the hero tokens.
    public let accent: SemanticColor?
    /// The native `.controlSize(_:)` in effect. Prefer ``trackSize`` and
    /// ``knobSide``, which are the metrics ThemeToggle itself resolves.
    public let controlSize: ControlSize
    /// The slide animation, resolved by ThemeToggle (`microAnimations` ∧ ¬Reduce
    /// Motion); `nil` when motion is off. Use it for the state change and never
    /// read the motion environment yourself.
    public let animation: Animation?

    /// The track as ThemeToggle sizes it — Figma "Control Items": 32×20 for the
    /// compact control sizes, 40×24 otherwise.
    public var trackSize: CGSize {
        let compact = controlSize == .mini || controlSize == .small
        return CGSize(width: compact ? 32 : 40, height: compact ? 20 : 24)
    }

    /// The knob's diameter — the track's height less its 2pt inset on each side.
    public var knobSide: CGFloat { trackSize.height - 4 }

    /// This configuration with the live `ButtonStyle` press state filled in.
    func pressing(_ isPressed: Bool) -> Self {
        Self(isOn: isOn, isEnabled: isEnabled, isPressed: isPressed, isReadOnly: isReadOnly,
             isLoading: isLoading, thumb: thumb, knobSymbol: knobSymbol, trackSymbol: trackSymbol,
             accent: accent, controlSize: controlSize, animation: animation)
    }
}

/// Defines ``ThemeToggle``'s chrome. Implement `makeBody` to draw the track and
/// the knob. Set one with `.toggleChromeStyle(_:)` on a switch or any ancestor;
/// without one, ThemeToggle draws its built-in chrome.
///
/// The style draws; ThemeToggle keeps the rest. A tap still flips the binding,
/// read-only still ignores taps, `.disabled(_:)` still blocks them, and the
/// accessibility value and traits stay on the control. ThemeToggle adds no
/// dimming or press effect on this path, so the style draws the disabled and
/// pressed looks. The style's output is the hit area, so give it a size.
///
/// The style reaches every ``ThemeToggle`` in the subtree, including those
/// ThemeKit components compose — the switches inside ``ToggleGroup``,
/// ``ControlRow`` (`.control(.toggle)`) and ``ListRow`` (`.toggle`).
///
///     struct BrandToggleChrome: ToggleChromeStyle {
///         func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
///             BrandToggleChromeBody(configuration: configuration)
///         }
///     }
///
///     private struct BrandToggleChromeBody: View {
///         let configuration: ToggleChromeStyleConfiguration
///         @Environment(\.theme) private var theme
///
///         var body: some View {
///             let c = configuration
///             Capsule()
///                 .fill(c.isOn ? theme.resolve(c.accent ?? .primary).solid : theme.border(.borderPrimary))
///                 .frame(width: c.trackSize.width, height: c.trackSize.height)
///                 .overlay(
///                     Circle()
///                         .fill(theme.background(.bgWhite))
///                         .frame(width: c.knobSide, height: c.knobSide)
///                         .padding(2)
///                         .frame(maxWidth: .infinity, alignment: c.isOn ? .trailing : .leading)
///                 )
///                 .animation(c.animation, value: c.isOn)
///                 .opacity(c.isEnabled ? 1 : 0.6)
///         }
///     }
public protocol ToggleChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ToggleChromeStyleConfiguration) -> Body
}

/// The stock chrome — the look ThemeToggle draws when no style is set: a track
/// filled with the accent (or hero) solid while on and `bg-secondary`
/// otherwise, a `fg-secondary` knob inset by 2pt carrying the spinner, the
/// thumb slot or the glyph, and the track glyph on the side the knob vacated.
/// Fades to 60% opacity when disabled, as the built-in path does. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct DefaultToggleChromeStyle: ToggleChromeStyle, Sendable {
    public init() {}
    public func makeBody(configuration: ToggleChromeStyleConfiguration) -> some View {
        DefaultToggleChrome(configuration: configuration)
    }
}

/// Mirrors ThemeToggle's built-in body. `ToggleChromeStyleTests` renders both
/// and compares the pixels, so the two can't drift apart unnoticed.
private struct DefaultToggleChrome: View {
    let configuration: ToggleChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        Capsule()
            .fill(track)
            .frame(width: configuration.trackSize.width, height: configuration.trackSize.height)
            .overlay(trackSymbol)   // under the knob so it never overlaps it mid-slide
            .overlay(
                knob
                    .padding(2)   // intentional: 2pt, no token — the knob's inset scales off the track
                    .frame(maxWidth: .infinity, alignment: configuration.isOn ? .trailing : .leading)
            )
            .opacity(configuration.isEnabled ? 1 : 0.6)
    }

    private var side: CGFloat { configuration.knobSide }

    private var knob: some View {
        Circle()
            .fill(theme.foreground(.fgSecondary))
            .frame(width: side, height: side)
            .overlay {
                if configuration.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(theme.foreground(.fgHero))
                } else if let thumb = configuration.thumb {
                    thumb
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                } else if let glyph = configuration.knobSymbol {
                    Image(systemName: glyph)
                        .font(.system(size: side * 0.55, weight: .bold))
                        .foregroundStyle(configuration.isOn ? theme.text(.textHero) : theme.text(.textTertiary))
                }
            }
    }

    @ViewBuilder private var trackSymbol: some View {
        if let glyph = configuration.trackSymbol {
            Image(systemName: glyph)
                .font(.system(size: side * 0.55, weight: .bold))
                .foregroundStyle(trackSymbolColor)
                .frame(width: side, height: side)   // centered in the knob-sized vacated zone
                .padding(2)
                .frame(maxWidth: .infinity, alignment: configuration.isOn ? .leading : .trailing)
                .transition(.opacity)
                .id(glyph)
        }
    }

    private var trackSymbolColor: Color {
        guard configuration.isOn, configuration.isEnabled else { return theme.text(.textTertiary) }
        return configuration.accent.map { theme.resolve($0).onSolid } ?? theme.text(.textHero)
    }

    private var track: Color {
        guard configuration.isEnabled, configuration.isOn else { return theme.background(.bgSecondary) }
        return configuration.accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero)
    }
}

public extension ToggleChromeStyle where Self == DefaultToggleChromeStyle {
    /// The stock chrome — ThemeToggle's built-in look. Setting it with
    /// `.toggleChromeStyle(.default)` restores the built-in path.
    static var `default`: DefaultToggleChromeStyle { DefaultToggleChromeStyle() }
}

// MARK: - ButtonStyle bridge

/// Hands ThemeToggle's chrome to the environment ``ToggleChromeStyle`` through
/// a real SwiftUI `ButtonStyle`, so `isPressed` is the live press state. Draws
/// nothing of its own: no dimming when disabled, no press scale. Used only on
/// the custom-style path; the built-in chrome keeps `PressFeedbackStyle`.
struct ToggleChromeBridge: ButtonStyle {
    let style: AnyToggleChromeStyle
    /// Everything but the press state, resolved by ThemeToggle.
    let template: ToggleChromeStyleConfiguration

    func makeBody(configuration: Configuration) -> some View {
        style.makeBody(configuration: template.pressing(configuration.isPressed))
    }
}

// MARK: - Type erasure + environment plumbing

struct AnyToggleChromeStyle: ToggleChromeStyle {
    /// `true` for the environment key's stock default below, and for
    /// ``DefaultToggleChromeStyle`` set explicitly. While it is set, ThemeToggle
    /// draws its built-in path (unchanged from before this door existed), press
    /// scale and disabled fade included. Any other style routes through
    /// `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (ToggleChromeStyleConfiguration) -> AnyView
    init<S: ToggleChromeStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault || S.self == DefaultToggleChromeStyle.self
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: ToggleChromeStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct ToggleChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyToggleChromeStyle(DefaultToggleChromeStyle(), isDefault: true)
}

extension EnvironmentValues {
    var toggleChromeStyle: AnyToggleChromeStyle {
        get { self[ToggleChromeStyleKey.self] }
        set { self[ToggleChromeStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``ToggleChromeStyle`` for `ThemeToggle`s in this view and its
    /// descendants — including the switches inside ThemeKit components.
    func toggleChromeStyle<S: ToggleChromeStyle>(_ style: sending S) -> some View {
        environment(\.toggleChromeStyle, AnyToggleChromeStyle(style))
    }
}
