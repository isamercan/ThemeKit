//
//  PassengerRow.swift
//  ThemeKit
//
//  Molecule. A traveller summary row — an avatar or icon, a name with an optional
//  type badge (Adult / Child / Infant), a subtitle, an optional seat chip and status,
//  and a trailing edit / chevron. Token-bound; the row of a passengers list.
//
//  ```swift
//  PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345").seat("14C").onEdit { }
//  ```
//

import SwiftUI
import ThemeKit

/// Trailing accessory of a ``PassengerRow``.
public enum PassengerAccessory: Sendable { case none, chevron }

public struct PassengerRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

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
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var selectionBinding: Binding<Bool>?
    private var customTrailing: AnyView?

    public init(_ name: String, action: @escaping () -> Void = {}) {   // R1
        self.name = name
        self.action = action
    }

    private var accentBase: Color { (accent ?? .primary).base }
    private var isSelected: Bool { selectionBinding?.wrappedValue ?? false }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    public var body: some View {
        Button {
            selectionBinding?.wrappedValue.toggle()
            action()
        } label: {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                if let selectionBinding {
                    // Visual-only — the whole row is the toggle target.
                    Checkbox(isChecked: selectionBinding)
                        .accent(accent)
                        .allowsHitTesting(false)
                }
                leading
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                        if let typeText { Badge(typeText).badgeStyle(typeStyle).variant(.soft).size(.small).fixedSize() }
                    }
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .padding(.horizontal, bordered ? density.scale(Theme.SpacingKey.sm.value) : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bordered ? theme.background(surfaceKey) : .clear, in: rowShape)
            .overlay { if bordered { rowShape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([name, typeText, seat.map { String(themeKit: "seat \($0)") }, statusText].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var leading: some View {
        if let avatarContent {
            Avatar(avatarContent).size(.md)
        } else {
            Image(systemName: systemImage).font(.system(size: 30)).foregroundStyle(accentBase)
        }
    }

    @ViewBuilder private var trailing: some View {
        HStack(spacing: 8) {
            if let seat {
                Text(seat).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(theme.background(.bgElevatorTertiary), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            }
            if let statusText { Badge(statusText).badgeStyle(statusStyle).variant(.soft).size(.small) }
            if let customTrailing {
                customTrailing
            } else if let onEdit {
                Button { onEdit() } label: {
                    Image(systemName: "pencil").textStyle(.labelBase600).foregroundStyle(accentBase)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Edit"))
            } else if let onRemove {
                Button { onRemove() } label: {
                    Image(systemName: "xmark").textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Remove"))
            } else if accessory == .chevron {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
                    .accessibilityHidden(true)   // decorative disclosure indicator
            }
        }
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
