//
//  TripTypeToggleStyle.swift
//  ThemeKit
//
//  The styling hook for ``TripTypeToggle`` — promotes the former
//  ``TripTypeToggleVariant`` enum (ADR-0004) so the whole selector is a
//  swappable style, settable once per screen via the environment. Three
//  built-ins:
//
//    .pill       accent-filled pill inside a soft track — today's look. Default.
//    .underline  borderless tab row with a 2pt accent indicator bar.
//    .menu       a Dropdown-composed selector for dense headers: the current
//                option is the trigger, the alternatives open in a floating menu.
//
//      TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip)
//          .tripTypeToggleStyle(.underline)
//
//  Component style arranges content; token theme colors everything. Selection
//  motion is resolved by the component (`MicroMotion` ∧ ¬Reduce Motion) and
//  baked into ``TripTypeToggleConfiguration/select`` — styles call it, never
//  read the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``TripTypeToggleStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no icons → text-only options, no surface override
/// → the style's own default track fill).
public struct TripTypeToggleConfiguration {
    /// The selectable option titles, in display order.
    public let options: [String]
    /// Index of the currently selected option (``ControllableState`` lives in
    /// the component — styles only read this and call ``select``).
    public let selectedIndex: Int
    /// Selects the option at an index. The selection animation is already
    /// resolved by the component (`MicroMotion` + Reduce Motion), so styles
    /// call this directly and never wrap it in `withAnimation`.
    public let select: (Int) -> Void
    /// Per-option leading SF Symbols, aligned to ``options`` by index; shorter
    /// arrays leave the remaining options text-only. Prefer ``icon(at:)``.
    public let icons: [String]
    /// Size ramp — steps the option height and the icon + label text styles.
    public let size: TripTypeToggleSize
    /// Corner treatment of tracks and thumbs (`.capsule` or `.rounded(_:)` at
    /// a radius role). Resolve via ``trackShape``.
    public let shape: TripTypeToggleShape
    /// Semantic accent for the selected option (`.accent(_:)`); `nil` = the
    /// stock primary. Resolve via ``resolvedAccent``.
    public let accent: SemanticColor?
    /// Explicit track fill (`.surface(_:)`), or `nil` to let the style choose
    /// its own default (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Stretch options to fill the available width (default on); off =
    /// intrinsic width.
    public let fullWidth: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component (ADR-0004 §4). The
    /// built-ins render caller-supplied titles verbatim; custom styles that
    /// format dates/numbers around the options must use it.
    public let locale: Locale

    /// The SF Symbol for the option at `index`, or `nil` past the end of ``icons``.
    public func icon(at index: Int) -> String? {
        icons.indices.contains(index) ? icons[index] : nil
    }

    /// The title of the selected option — empty when ``options`` is empty.
    public var selectedTitle: String {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : ""
    }

    /// The `accent(_:)` override, else the stock primary — the value the
    /// built-ins hardcoded before the style axis existed.
    public var resolvedAccent: SemanticColor { accent ?? .primary }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the control.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The ``shape`` resolved to a fillable/clippable shape — the pill track,
    /// the selected thumb and the menu trigger all draw with it.
    public var trackShape: AnyShape {
        switch shape {
        case .capsule: AnyShape(Capsule(style: .continuous))
        case .rounded(let role): AnyShape(RoundedRectangle(cornerRadius: role.value, style: .continuous))
        }
    }
}

// MARK: - Protocol

/// Defines a `TripTypeToggle`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's options. Set one with `.tripTypeToggleStyle(_:)`;
/// the default is ``PillTripTypeToggleStyle``.
public protocol TripTypeToggleStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: TripTypeToggleConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// One option's icon + title pair, shared by `.pill` and `.underline` —
/// the former `optionLabel(_:_:)`, verbatim.
private struct TripTypeOptionLabel: View {
    let configuration: TripTypeToggleConfiguration
    let index: Int
    let option: String

    var body: some View {
        HStack(spacing: 5) {
            if let symbol = configuration.icon(at: index) {
                Image(systemName: symbol).textStyle(configuration.size.iconStyle)
            }
            Text(option).textStyle(configuration.size.textStyle).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

// MARK: - 1. Pill — accent thumb in a soft track (default)

/// The stock look, extracted verbatim: the selected option is an accent-filled
/// pill inside a soft track (`.bgBase` unless overridden by `.surface(_:)`).
public struct PillTripTypeToggleStyle: TripTypeToggleStyle {
    public init() {}
    public func makeBody(configuration: TripTypeToggleConfiguration) -> some View {
        PillTripTypeToggleChrome(configuration: configuration)
    }
}

private struct PillTripTypeToggleChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TripTypeToggleConfiguration

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(configuration.options.enumerated()), id: \.offset) { index, option in
                pill(index, option)
            }
        }
        .padding(Theme.SpacingKey.xs.value)   // 4pt == SpacingKey.xs
        .background(theme.background(configuration.surface(default: .bgBase)), in: configuration.trackShape)
        .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
    }

    private func pill(_ index: Int, _ option: String) -> some View {
        let isOn = index == configuration.selectedIndex
        return Button {
            configuration.select(index)
        } label: {
            TripTypeOptionLabel(configuration: configuration, index: index, option: option)
                .foregroundStyle(isOn ? configuration.resolvedAccent.onSolid : theme.text(.textSecondary))
                .padding(.horizontal, configuration.spacing(.sm))
                .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
                .frame(minHeight: configuration.size.minHeight)
                .background(isOn ? configuration.resolvedAccent.solid : .clear, in: configuration.trackShape)
                .contentShape(configuration.trackShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 2. Underline — borderless tab indicator bar

/// Borderless tab look, extracted verbatim — no track, a 2pt accent indicator
/// bar under the selected option.
public struct UnderlineTripTypeToggleStyle: TripTypeToggleStyle {
    public init() {}
    public func makeBody(configuration: TripTypeToggleConfiguration) -> some View {
        UnderlineTripTypeToggleChrome(configuration: configuration)
    }
}

private struct UnderlineTripTypeToggleChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TripTypeToggleConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            ForEach(Array(configuration.options.enumerated()), id: \.offset) { index, option in
                tab(index, option)
            }
        }
        .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
    }

    private func tab(_ index: Int, _ option: String) -> some View {
        let isOn = index == configuration.selectedIndex
        return Button {
            configuration.select(index)
        } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                TripTypeOptionLabel(configuration: configuration, index: index, option: option)
                    .foregroundStyle(isOn ? configuration.resolvedAccent.base : theme.text(.textSecondary))
                Rectangle()
                    .fill(isOn ? configuration.resolvedAccent.base : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, configuration.spacing(.xs))
            .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
            .frame(minHeight: configuration.size.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 3. Menu — Dropdown-composed for dense headers

/// The current option as a compact trigger; the alternatives open in a
/// floating ``Dropdown`` menu with a checkmark on the selected row. For
/// headers and toolbars too dense for a segmented track.
public struct MenuTripTypeToggleStyle: TripTypeToggleStyle {
    public init() {}
    public func makeBody(configuration: TripTypeToggleConfiguration) -> some View {
        MenuTripTypeToggleChrome(configuration: configuration)
    }
}

private struct MenuTripTypeToggleChrome: View {
    @Environment(\.theme) private var theme
    let configuration: TripTypeToggleConfiguration

    var body: some View {
        Dropdown(items: items) { trigger }
            .indicator(.checkmark)
            .accent(configuration.resolvedAccent)
    }

    private var items: [DropdownItem] {
        configuration.options.enumerated().map { index, option in
            DropdownItem(option,
                         systemImage: configuration.icon(at: index),
                         isSelected: index == configuration.selectedIndex) {
                configuration.select(index)
            }
        }
    }

    private var trigger: some View {
        HStack(spacing: configuration.spacing(.xs)) {
            if let symbol = configuration.icon(at: configuration.selectedIndex) {
                Image(systemName: symbol)
                    .textStyle(configuration.size.iconStyle)
                    .foregroundStyle(configuration.resolvedAccent.base)
            }
            Text(configuration.selectedTitle)
                .textStyle(configuration.size.textStyle)
                .foregroundStyle(theme.text(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Icon(systemName: "chevron.down").size(.xs).color(theme.text(.textTertiary))
        }
        .padding(.horizontal, configuration.spacing(.sm))
        .frame(maxWidth: configuration.fullWidth ? .infinity : nil)
        .frame(minHeight: configuration.size.minHeight)
        .background(theme.background(configuration.surface(default: .bgSecondaryLight)),
                    in: configuration.trackShape)
        .contentShape(configuration.trackShape)
        .accessibilityLabel(configuration.selectedTitle)
    }
}

// MARK: - Static accessors

public extension TripTypeToggleStyle where Self == PillTripTypeToggleStyle {
    /// Accent-filled pill inside a soft track — today's look. The default.
    static var pill: PillTripTypeToggleStyle { PillTripTypeToggleStyle() }
}
public extension TripTypeToggleStyle where Self == UnderlineTripTypeToggleStyle {
    /// Borderless tab row with a 2pt accent indicator bar.
    static var underline: UnderlineTripTypeToggleStyle { UnderlineTripTypeToggleStyle() }
}
public extension TripTypeToggleStyle where Self == MenuTripTypeToggleStyle {
    /// Dropdown-composed selector for dense headers — the current option is
    /// the trigger, the alternatives open in a floating menu.
    static var menu: MenuTripTypeToggleStyle { MenuTripTypeToggleStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyTripTypeToggleStyle: TripTypeToggleStyle {
    private let _makeBody: @MainActor (TripTypeToggleConfiguration) -> AnyView
    init<S: TripTypeToggleStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: TripTypeToggleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct TripTypeToggleStyleKey: EnvironmentKey {
    static let defaultValue = AnyTripTypeToggleStyle(PillTripTypeToggleStyle())
}

extension EnvironmentValues {
    var tripTypeToggleStyle: AnyTripTypeToggleStyle {
        get { self[TripTypeToggleStyleKey.self] }
        set { self[TripTypeToggleStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``TripTypeToggleStyle`` for `TripTypeToggle`s in this view and
    /// its descendants — one search header can restyle every toggle at once.
    func tripTypeToggleStyle<S: TripTypeToggleStyle>(_ style: sending S) -> some View {
        environment(\.tripTypeToggleStyle, AnyTripTypeToggleStyle(style))
    }
}

// MARK: - Previews

/// Proves external implementability: a vertical radio list built purely from
/// the public configuration + theme tokens — what an app target would write.
private struct RadioListTripTypeToggleStyle: TripTypeToggleStyle {
    func makeBody(configuration: TripTypeToggleConfiguration) -> some View {
        RadioListChrome(configuration: configuration)
    }

    private struct RadioListChrome: View {
        @Environment(\.theme) private var theme
        let configuration: TripTypeToggleConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                ForEach(Array(configuration.options.enumerated()), id: \.offset) { index, option in
                    row(index, option)
                }
            }
        }

        private func row(_ index: Int, _ option: String) -> some View {
            let isOn = index == configuration.selectedIndex
            return Button {
                configuration.select(index)
            } label: {
                HStack(spacing: configuration.spacing(.sm)) {
                    Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                        .textStyle(configuration.size.iconStyle)
                        .foregroundStyle(isOn ? configuration.resolvedAccent.base : theme.text(.textTertiary))
                    Text(option)
                        .textStyle(configuration.size.textStyle)
                        .foregroundStyle(isOn ? theme.text(.textPrimary) : theme.text(.textSecondary))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(option)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

#Preview("TripTypeToggleStyle — presets × light/dark") {
    @Previewable @State var sel = 1
    let options = ["One way", "Round trip", "Multi-city"]
    let icons = ["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"]
    PreviewMatrix("TripTypeToggleStyle") {
        PreviewCase("Pill (default)") {
            TripTypeToggle(options, selection: $sel).icons(icons)
        }
        PreviewCase("Underline") {
            TripTypeToggle(options, selection: $sel)
                .icons(icons)
                .accent(.info)
                .tripTypeToggleStyle(.underline)
        }
        PreviewCase("Menu (tap in live preview)") {
            TripTypeToggle(options, selection: $sel)
                .icons(icons)
                .tripTypeToggleStyle(.menu)
        }
        PreviewCase("Menu · intrinsic width · rounded") {
            TripTypeToggle(options, selection: $sel)
                .fullWidth(false)
                .shape(.rounded(.field))
                .tripTypeToggleStyle(.menu)
        }
        PreviewCase("Custom (in-preview radio list)") {
            TripTypeToggle(options, selection: $sel)
                .tripTypeToggleStyle(RadioListTripTypeToggleStyle())
        }
    }
}
