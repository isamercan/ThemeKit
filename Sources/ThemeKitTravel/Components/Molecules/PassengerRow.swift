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
    private var subtitle: String?
    private var seat: String?
    private var statusText: String?
    private var statusStyle: BadgeStyle = .success
    private var avatarContent: AvatarContent?
    private var systemImage = "person.crop.circle.fill"
    private var onEdit: (() -> Void)?
    private var accessory: PassengerAccessory = .none
    private var accent: SemanticColor?

    public init(_ name: String, action: @escaping () -> Void = {}) {   // R1
        self.name = name
        self.action = action
    }

    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                        if let typeText { Badge(typeText).badgeStyle(.neutral).variant(.soft).size(.small).fixedSize() }
                    }
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([name, typeText, seat.map { String(themeKit: "seat \($0)") }, statusText].compactMap { $0 }.joined(separator: ", "))
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
            if let onEdit {
                Button { onEdit() } label: {
                    Image(systemName: "pencil").font(.system(size: 14, weight: .semibold)).foregroundStyle(accentBase).frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Edit"))
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
    func accessory(_ a: PassengerAccessory) -> Self { copy { $0.accessory = a } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 4) {
        PassengerRow("İsa Mercan").type("Adult").subtitle("Passport · TR12345678").seat("14C").onEdit { }
        PassengerRow("Ada Mercan").type("Child").avatar(.initials("AM")).status("Checked in").accessory(.chevron)
    }
    .padding()
}
