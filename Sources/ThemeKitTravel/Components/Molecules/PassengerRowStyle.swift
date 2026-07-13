//
//  PassengerRowStyle.swift
//  ThemeKit
//
//  The styling hook for ``PassengerRow`` (ADR-0004): the configuration hands
//  styles the *typed traveller summary* (name, type, seat, status, avatar…),
//  not pre-laid content, so a style owns the entire arrangement. Three built-ins:
//
//    .row      leading avatar/icon, name + type badge, subtitle, and a trailing
//              seat chip / status badge / edit·remove·chevron — today's row,
//              flush by default, optionally bordered. Default.
//    .card     bordered card: avatar, name + type + subtitle, seat/status
//              trailing, and prominent circular edit/remove affordances.
//    .compact  a dense single line: name, seat, chevron — no avatar, type
//              badge, subtitle or status.
//
//      PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345678")
//          .seat("14C").onEdit { }
//          .passengerRowStyle(.card)
//
//  Component style arranges content; token theme colors everything. Selection
//  is ``ControllableState`` per ADR-0004 §4 — the configuration exposes the
//  read state (`isSelected`) and the mirrored `selectBinding` for rendering the
//  checkbox, but the actual toggle write happens through `action`, composed
//  once by the component so no style duplicates the toggle mechanics.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``PassengerRowStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no type → no badge, no seat → no chip, no
/// edit/remove → a plain chevron or nothing).
public struct PassengerRowConfiguration {
    /// The traveller's display name.
    public let name: String
    /// Passenger type badge text, e.g. "Adult" / "Child" / "Infant"; `nil` hides it.
    public let type: String?
    /// The type badge's style (default `.neutral`).
    public let typeStyle: BadgeStyle
    /// A secondary line under the name, e.g. "Passport · TR12345678".
    public let subtitle: String?
    /// Trailing seat text, e.g. "14C"; `nil` hides it.
    public let seat: String?
    /// Trailing status badge text, e.g. "Checked in"; `nil` hides it.
    public let status: String?
    /// The status badge's style (default `.success`).
    public let statusStyle: BadgeStyle
    /// Custom avatar content; `nil` falls back to ``systemImage``.
    public let avatar: AvatarContent?
    /// SF Symbol used when no ``avatar`` is set.
    public let systemImage: String
    /// Trailing disclosure affordance drawn when no edit/remove/custom trailing
    /// content is present (``.row`` only — ``.compact`` always shows a chevron).
    public let accessory: PassengerAccessory
    /// Wrap in a bordered/surfaced shell (``PassengerRow/bordered(_:)``).
    /// ``.card`` always renders bordered and ignores this flag.
    public let isBordered: Bool
    /// Explicit surface fill, or `nil` to let the style choose its own default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Selection state — mirrors ``selectBinding``'s value, `false` when the
    /// row isn't selectable.
    public let isSelected: Bool
    /// Selection-checkbox binding; `nil` = not selectable (no checkbox drawn).
    /// Visual only — styles never write to it; the toggle happens through
    /// ``action``, already composed by the component.
    public let selectBinding: Binding<Bool>?
    /// Replacement for the built-in trailing accessory (``.row``/``.card``);
    /// `nil` = built-in edit/remove/chevron precedence.
    public let trailing: AnyView?
    /// Edit action; takes precedence over ``onRemove`` in the built-in trailing area.
    public let onEdit: (() -> Void)?
    /// Remove action; drawn when ``onEdit`` is `nil`.
    public let onRemove: (() -> Void)?
    /// Brand-chrome accent, or `nil` for the theme's primary semantic.
    public let accent: SemanticColor?
    /// The row's whole-row tap handler — already composed with the selection
    /// toggle by the component (ADR-0004 §4); styles call it directly and
    /// never write to ``selectBinding`` themselves.
    public let action: () -> Void
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component. The built-ins render
    /// preformatted strings, but custom styles that format dates/numbers must
    /// use it so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The `accent(_:)` override's base, else the primary semantic's base — the
    /// value the built-ins hardcoded before the accent axis existed.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use accentBase(_ theme:)")
    public var accentBase: Color { accentBase(.shared) }
    /// Theme-parameterized twin of ``accentBase`` — resolves against the
    /// environment theme (ADR-0006), honoring per-subtree `.theme(_:)`.
    public func accentBase(_ theme: Theme) -> Color { theme.resolve(accent ?? .primary).base }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the row.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The row's spoken summary — name, type, seat, status. Every built-in
    /// applies it to the row's combined `accessibilityElement`.
    public var accessibilityLabel: String {
        [name, type, seat.map { String(themeKit: "seat \($0)") }, status]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Protocol

/// Defines a `PassengerRow`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's traveller summary. Set one with
/// `.passengerRowStyle(_:)`; the default is ``RowPassengerRowStyle``.
public protocol PassengerRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PassengerRowConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The leading avatar/icon shared by `.row` and `.card` — the custom
/// ``PassengerRowConfiguration/avatar`` when set, else a person-glyph icon
/// tinted with ``PassengerRowConfiguration/accentBase``.
private struct PassengerRowAvatar: View {
    @Environment(\.theme) private var theme
    let configuration: PassengerRowConfiguration
    var size: AvatarSize = .md

    var body: some View {
        if let avatar = configuration.avatar {
            Avatar(avatar).size(size)
        } else {
            Image(systemName: configuration.systemImage)
                .font(.system(size: size.rawValue * 0.75))
                .foregroundStyle(configuration.accentBase(theme))
        }
    }
}

/// The selection checkbox mirrored by every selectable preset — visual only;
/// the actual toggle happens through ``PassengerRowConfiguration/action``,
/// composed once by the component (ADR-0004 §4).
private struct PassengerRowSelectionCheckbox: View {
    let configuration: PassengerRowConfiguration

    var body: some View {
        if let binding = configuration.selectBinding {
            Checkbox(isChecked: binding)
                .accent(configuration.accent)
                .allowsHitTesting(false)
        }
    }
}

/// The passenger-type badge next to the name; draws nothing when unset.
private struct PassengerRowTypeBadge: View {
    let configuration: PassengerRowConfiguration
    var body: some View {
        if let type = configuration.type {
            Badge(type).badgeStyle(configuration.typeStyle).variant(.soft).size(.small).fixedSize()
        }
    }
}

/// The trailing seat chip; draws nothing when unset.
private struct PassengerRowSeatChip: View {
    @Environment(\.theme) private var theme
    let seat: String

    var body: some View {
        Text(seat).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
            .padding(.horizontal, 8).frame(height: 24)
            .background(theme.background(.bgElevatorTertiary),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }
}

/// The trailing status badge; draws nothing when unset.
private struct PassengerRowStatusBadge: View {
    let configuration: PassengerRowConfiguration
    var body: some View {
        if let status = configuration.status {
            Badge(status).badgeStyle(configuration.statusStyle).variant(.soft).size(.small)
        }
    }
}

// MARK: - .row

/// Today's ``PassengerRow`` look, extracted verbatim: leading avatar/icon,
/// name + type badge, subtitle, and a trailing seat chip / status badge /
/// edit·remove·chevron — flush by default, optionally bordered. Default.
public struct RowPassengerRowStyle: PassengerRowStyle {
    public init() {}
    public func makeBody(configuration: PassengerRowConfiguration) -> some View {
        RowPassengerRowChrome(configuration: configuration)
    }
}

private struct RowPassengerRowChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PassengerRowConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    var body: some View {
        Button(action: configuration.action) {
            HStack(spacing: configuration.spacing(.sm)) {
                PassengerRowSelectionCheckbox(configuration: configuration)
                PassengerRowAvatar(configuration: configuration)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(configuration.name).textStyle(.labelBase700)
                            .foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                        PassengerRowTypeBadge(configuration: configuration)
                    }
                    if let subtitle = configuration.subtitle {
                        Text(subtitle).textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(.vertical, configuration.spacing(.sm))
            .padding(.horizontal, configuration.isBordered ? configuration.spacing(.sm) : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isBordered ? theme.background(configuration.surface(default: .bgBase)) : .clear,
                        in: shape)
            .overlay { if configuration.isBordered { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityLabel)
        .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    @ViewBuilder private var trailing: some View {
        HStack(spacing: 8) {
            if let seat = configuration.seat { PassengerRowSeatChip(seat: seat) }
            PassengerRowStatusBadge(configuration: configuration)
            if let custom = configuration.trailing {
                custom
            } else if let onEdit = configuration.onEdit {
                Button { onEdit() } label: {
                    Image(systemName: "pencil").textStyle(.labelBase600).foregroundStyle(configuration.accentBase(theme))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Edit"))
            } else if let onRemove = configuration.onRemove {
                Button { onRemove() } label: {
                    Image(systemName: "xmark").textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Remove"))
            } else if configuration.accessory == .chevron {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
                    .accessibilityHidden(true)   // decorative disclosure indicator
            }
        }
    }
}

// MARK: - .card

/// A bordered card: avatar, name + type badge, subtitle, seat chip + status
/// badge trailing, and prominent circular edit/remove affordances — a
/// standalone passenger tile (e.g. a review-step summary list).
public struct CardPassengerRowStyle: PassengerRowStyle {
    public init() {}
    public func makeBody(configuration: PassengerRowConfiguration) -> some View {
        CardPassengerRowChrome(configuration: configuration)
    }
}

private struct CardPassengerRowChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PassengerRowConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    var body: some View {
        Button(action: configuration.action) {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                HStack(alignment: .top, spacing: configuration.spacing(.sm)) {
                    PassengerRowSelectionCheckbox(configuration: configuration)
                    PassengerRowAvatar(configuration: configuration, size: .lg)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(configuration.name).textStyle(.labelBase700)
                                .foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                            PassengerRowTypeBadge(configuration: configuration)
                        }
                        if let subtitle = configuration.subtitle {
                            Text(subtitle).textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary)).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 4) {
                        if let seat = configuration.seat { PassengerRowSeatChip(seat: seat) }
                        PassengerRowStatusBadge(configuration: configuration)
                    }
                }
                if let custom = configuration.trailing {
                    custom
                } else if configuration.onEdit != nil || configuration.onRemove != nil {
                    actionsRow
                }
            }
            .padding(configuration.spacing(.md))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(configuration.surface(default: .bgWhite)), in: shape)
            .overlay { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityLabel)
        .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    /// The prominent edit (soft-filled circle) / remove (``CloseButton``) pair —
    /// composed from existing ThemeKit atoms/molecules, not hand-rolled glyphs.
    private var actionsRow: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            Spacer(minLength: 0)
            if let onEdit = configuration.onEdit {
                ThemeButton(action: onEdit)
                    .icon(leading: "pencil")
                    .shape(.circle)
                    .variant(.soft)
                    .color(configuration.accent ?? .primary)
                    .size(.small)
                    .accessibilityLabel(String(themeKit: "Edit"))
            }
            if let onRemove = configuration.onRemove {
                CloseButton(action: onRemove)
                    .tint(.error)
                    .controlSize(.small)
                    .accessibilityLabel(String(themeKit: "Remove"))
            }
        }
    }
}

// MARK: - .compact

/// A dense single line — name, seat, chevron — no avatar, type badge,
/// subtitle or status. Long passenger rosters with little vertical room.
public struct CompactPassengerRowStyle: PassengerRowStyle {
    public init() {}
    public func makeBody(configuration: PassengerRowConfiguration) -> some View {
        CompactPassengerRowChrome(configuration: configuration)
    }
}

private struct CompactPassengerRowChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PassengerRowConfiguration

    var body: some View {
        Button(action: configuration.action) {
            HStack(spacing: configuration.spacing(.sm)) {
                PassengerRowSelectionCheckbox(configuration: configuration)
                Text(configuration.name).textStyle(.labelBase700)
                    .foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                Spacer(minLength: 6)
                if let seat = configuration.seat {
                    Text(seat).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
                Icon(systemName: "chevron.right").size(.xs).color(theme.text(.textTertiary))
                    .mirrorsInRTL()
                    .accessibilityHidden(true)   // decorative disclosure indicator
            }
            .padding(.vertical, configuration.spacing(.xs))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(configuration.accessibilityLabel)
        .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }
}

// MARK: - Static accessors

public extension PassengerRowStyle where Self == RowPassengerRowStyle {
    /// Leading avatar/icon, name + type badge, subtitle, trailing seat chip /
    /// status badge / edit·remove·chevron — today's row. The default.
    static var row: RowPassengerRowStyle { RowPassengerRowStyle() }
}
public extension PassengerRowStyle where Self == CardPassengerRowStyle {
    /// Bordered card with prominent circular edit/remove affordances.
    static var card: CardPassengerRowStyle { CardPassengerRowStyle() }
}
public extension PassengerRowStyle where Self == CompactPassengerRowStyle {
    /// Dense single line: name, seat, chevron.
    static var compact: CompactPassengerRowStyle { CompactPassengerRowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPassengerRowStyle: PassengerRowStyle {
    private let _makeBody: @MainActor (PassengerRowConfiguration) -> AnyView
    init<S: PassengerRowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PassengerRowConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PassengerRowStyleKey: EnvironmentKey {
    static let defaultValue = AnyPassengerRowStyle(RowPassengerRowStyle())
}

extension EnvironmentValues {
    var passengerRowStyle: AnyPassengerRowStyle {
        get { self[PassengerRowStyleKey.self] }
        set { self[PassengerRowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PassengerRowStyle`` for `PassengerRow`s in this view and its
    /// descendants — a passengers list sets it once for every row.
    func passengerRowStyle<S: PassengerRowStyle>(_ style: sending S) -> some View {
        environment(\.passengerRowStyle, AnyPassengerRowStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a soft accent capsule row with the name and seat only.
private struct CapsulePassengerRowStyle: PassengerRowStyle {
    func makeBody(configuration: PassengerRowConfiguration) -> some View {
        CapsuleChrome(configuration: configuration)
    }

    private struct CapsuleChrome: View {
        @Environment(\.theme) private var theme
        let configuration: PassengerRowConfiguration

        var body: some View {
            Button(action: configuration.action) {
                HStack(spacing: configuration.spacing(.sm)) {
                    Text(configuration.name).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                    if let seat = configuration.seat {
                        Text(seat).textStyle(.overline500).foregroundStyle(configuration.accentBase(theme))
                    }
                }
                .padding(.vertical, configuration.spacing(.xs))
                .padding(.horizontal, configuration.spacing(.sm))
                .background(theme.resolve(configuration.accent ?? .primary).soft, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.accessibilityLabel)
        }
    }
}

#Preview("PassengerRowStyle — presets × light/dark") {
    PreviewMatrix("PassengerRowStyle") {
        PreviewCase("Row (default)") {
            PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345678").seat("14C").onEdit { }
        }
        PreviewCase("Row · bordered + status") {
            PassengerRow("Ada Mercan").type("Child").status("Checked in").accessory(.chevron)
                .bordered().surface(.bgWhite)
        }
        PreviewCase("Card") {
            PassengerRow("Mia Doe").type("Infant", style: .info).subtitle("No seat required").seat("—")
                .status("Pending").onEdit { }.onRemove { }
                .passengerRowStyle(.card)
        }
        PreviewCase("Card · accent") {
            PassengerRow("John Doe").type("Adult").subtitle("Frequent flyer").seat("2A")
                .onRemove { }.accent(.success)
                .passengerRowStyle(.card)
        }
        PreviewCase("Compact") {
            VStack(spacing: 4) {
                PassengerRow("Sam Doe").seat("11C").passengerRowStyle(.compact)
                PassengerRow("Alex Doe").seat("11D").passengerRowStyle(.compact)
            }
        }
        PreviewCase("Custom (in-preview)") {
            PassengerRow("Kate Lin").seat("7A").accent(.info)
                .passengerRowStyle(CapsulePassengerRowStyle())
        }
    }
}
