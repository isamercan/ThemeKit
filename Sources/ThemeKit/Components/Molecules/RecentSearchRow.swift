//
//  RecentSearchRow.swift
//  ThemeKit
//
//  Molecule. A recent / saved search summary — the route (from → to, one-way or
//  round-trip), a dates + passengers caption, and a trailing chevron or remove
//  button. Tap to re-run. Token-bound.
//
//  ```swift
//  RecentSearchRow(from: "IST", to: "AYT") { rerun() }
//      .roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { remove() }
//  ```
//

import SwiftUI

public struct RecentSearchRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let from: String
    private let to: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var roundTrip = false
    private var dates: String?
    private var passengers: String?
    private var systemImage = "clock.arrow.circlepath"
    private var onRemove: (() -> Void)?
    private var accent: SemanticColor?
    private var bordered = false
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase

    public init(from: String, to: String, action: @escaping () -> Void = {}) {   // R1
        self.from = from
        self.to = to
        self.action = action
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }
    private var caption: String? {
        [dates, passengers].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                IconTile(systemImage).size(40).iconSize(16).accent(accent)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(from).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                        Image(systemName: roundTrip ? "arrow.left.arrow.right" : "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary))
                        Text(to).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                    }
                    if let caption { Text(caption).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(density.scale(Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bordered ? theme.background(surfaceKey) : .clear, in: shape)
            .overlay { if bordered { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(from) to \(to)\(caption.map { ", " + $0 } ?? "")")
    }

    @ViewBuilder private var trailing: some View {
        if let onRemove {
            Button { onRemove() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Remove"))
        } else {
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RecentSearchRow {
    /// Round-trip route (⇄ arrow) instead of one-way (→).
    func roundTrip(_ on: Bool = true) -> Self { copy { $0.roundTrip = on } }
    func dates(_ text: String?) -> Self { copy { $0.dates = text } }
    func passengers(_ text: String?) -> Self { copy { $0.passengers = text } }
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Adds a trailing remove (✕) button instead of the chevron.
    func onRemove(_ action: @escaping () -> Void) -> Self { copy { $0.onRemove = action } }
    /// Brand-tints the leading icon tile (default: neutral tile).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Wrap in a bordered surface (default off — flush list row).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }
    /// Surface fill of the bordered variant (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 4) {
        RecentSearchRow(from: "IST", to: "AYT") { }.roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy")
        RecentSearchRow(from: "SAW", to: "ESB") { }.dates("2 Aug").passengers("1 adult").onRemove { }
    }
    .padding()
}
