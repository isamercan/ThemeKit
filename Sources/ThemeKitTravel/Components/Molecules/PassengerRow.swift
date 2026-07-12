//
//  PassengerRow.swift
//  ThemeKit
//
//  Molecule. A traveller summary row — an avatar or icon, a name with an optional
//  type badge (Adult / Child / Infant), a subtitle, an optional seat chip and status,
//  and a trailing edit / chevron. Presentation is style-driven
//  (``PassengerRowStyle``, ADR-0004) — set once per list via
//  `.passengerRowStyle(_:)`. Token-bound; the row of a passengers list.
//
//  ```swift
//  PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345").seat("14C").onEdit { }
//      .passengerRowStyle(.card)      // .row (default) / .card / .compact
//  ```
//

import SwiftUI
import ThemeKit

/// Trailing accessory of a ``PassengerRow`` (the ``RowPassengerRowStyle`` preset).
public enum PassengerAccessory: Sendable { case none, chevron }

public struct PassengerRow: View {
    @Environment(\.passengerRowStyle) private var style
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale

    private let name: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var typeText: String?
    private var typeStyle: BadgeStyle = .neutral
    private var subtitle: String?
    private var seat: String?
    private var statusText: String?
    private var statusStyle: BadgeStyle = .success
    private var avatarContent: AvatarContent?
    private var systemImage = "person.crop.circle.fill"
    private var onEdit: (() -> Void)?
    private var onRemove: (() -> Void)?
    private var accessory: PassengerAccessory = .none
    private var accent: SemanticColor?
    private var bordered = false
    private var surfaceKey: Theme.BackgroundColorKey?
    private var selectionBinding: Binding<Bool>?
    private var customTrailing: AnyView?

    public init(_ name: String, action: @escaping () -> Void = {}) {   // R1
        self.name = name
        self.action = action
    }

    public var body: some View {
        // The arrangement is owned by the active `PassengerRowStyle`; the
        // component only gathers its typed summary and composes the row's tap
        // handler (selection toggle + the caller's action, ADR-0004 §4).
        let configuration = PassengerRowConfiguration(
            name: name,
            type: typeText,
            typeStyle: typeStyle,
            subtitle: subtitle,
            seat: seat,
            status: statusText,
            statusStyle: statusStyle,
            avatar: avatarContent,
            systemImage: systemImage,
            accessory: accessory,
            isBordered: bordered,
            surfaceKey: surfaceKey,
            isSelected: selectionBinding?.wrappedValue ?? false,
            selectBinding: selectionBinding,
            trailing: customTrailing,
            onEdit: onEdit,
            onRemove: onRemove,
            accent: accent,
            action: { selectionBinding?.wrappedValue.toggle(); action() },
            density: density,
            locale: locale)
        style.makeBody(configuration: configuration)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PassengerRow {
    /// Passenger type badge, e.g. "Adult" / "Child" / "Infant".
    func type(_ text: String?) -> Self { copy { $0.typeText = text } }
    /// Passenger type badge in a custom badge style (default `.neutral`).
    func type(_ text: String, style: BadgeStyle = .neutral) -> Self {
        copy { $0.typeText = text; $0.typeStyle = style }
    }
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// A trailing seat chip, e.g. "14C".
    func seat(_ text: String?) -> Self { copy { $0.seat = text } }
    /// A trailing status badge, e.g. "Checked in".
    func status(_ text: String?, style: BadgeStyle = .success) -> Self { copy { $0.statusText = text; $0.statusStyle = style } }
    /// Use an ``Avatar`` (initials / image / symbol) instead of the default person icon.
    func avatar(_ content: AvatarContent) -> Self { copy { $0.avatarContent = content } }
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Adds a trailing edit (pencil) button.
    func onEdit(_ action: @escaping () -> Void) -> Self { copy { $0.onEdit = action } }
    /// Adds a trailing remove (✕) button (``onEdit(_:)`` takes precedence).
    func onRemove(_ action: @escaping () -> Void) -> Self { copy { $0.onRemove = action } }
    func accessory(_ a: PassengerAccessory) -> Self { copy { $0.accessory = a } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Wrap in a bordered card surface (default off — flush list row).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }
    /// Surface fill of the bordered card (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Selectable mode — a leading checkbox mirrors the binding and tapping the
    /// row toggles it (the row `action` still fires). Pair with an
    /// `@State`/`ControllableState` bool at the call site.
    func selectable(_ isSelected: Binding<Bool>) -> Self { copy { $0.selectionBinding = isSelected } }
    /// Replaces the built-in trailing accessory (edit / remove / chevron) with
    /// custom content; the seat chip and status badge stay.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customTrailing = AnyView(content()) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var selected = true
    PreviewMatrix("PassengerRow") {
        PreviewCase("Editable + seat") { PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345678").seat("14C").onEdit { } }
        PreviewCase("Avatar + status + chevron") { PassengerRow("Ada Mercan").type("Child").avatar(.initials("AM")).status("Checked in").accessory(.chevron) }
        PreviewCase("Bordered card + typed badge") {
            PassengerRow("Mia Doe").type("Infant", style: .info).subtitle("No seat required")
                .bordered().surface(.bgWhite)
        }
        PreviewCase("Selectable (row toggles)") {
            PassengerRow("John Doe").type("Adult").subtitle("Frequent flyer")
                .selectable($selected)
                .bordered()
        }
        PreviewCase("Removable") {
            PassengerRow("Sam Doe").type("Adult").onRemove { }
        }
        PreviewCase("Custom trailing slot") {
            PassengerRow("Alex Doe").type("Adult").trailing {
                Badge(String(themeKitTravel: "Visa required")).badgeStyle(.warning).variant(.soft).size(.small)
            }
        }
    }
}
