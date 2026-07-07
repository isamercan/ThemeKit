//
//  SearchField.swift
//  ThemeKit
//
//  Molecule. The polymorphic search-form input from the design system — a white,
//  soft-blue-bordered card that renders any of: a placeholder, a location
//  (code pill + title + subtitle), a date range (two badge+day columns split by a
//  divider), a passenger summary (badge + icon counts), or **fully custom** content.
//
//  Every element is overridable through a modifier — and every override takes a
//  **theme token** (a colour key, a radius role, a text style), never a raw colour
//  or magic number — so a rebrand is a one-token change that re-themes cleanly.
//
//  ```swift
//  SearchField("From") { pick() }
//      .value(code: "IST", title: "Istanbul", subtitle: "All airports")
//      .background(.bgWhite).borderColor(.borderHero).cornerRadius(.field)   // all tokens
//      .chipColors(background: .bgHero, foreground: .textSecondaryInverse)
//      .titleStyle(.bodyBase500, color: .textHero)
//  ```
//

import SwiftUI

/// Trailing accessory of a ``SearchField``.
public enum SearchFieldTrailing: Sendable { case none, chevron, clear }

/// One side of a date-range ``SearchField`` — an optional pill + a label.
public struct SearchDate: Sendable {
    public let badge: String?
    public let label: String
    public init(badge: String? = nil, label: String) {
        self.badge = badge
        self.label = label
    }
}

/// One passenger tally in a passenger ``SearchField`` — an SF Symbol + a count.
public struct PassengerCount: Identifiable, Sendable {
    public var id: String { "\(icon):\(count)" }
    public let icon: String
    public let count: String
    public init(_ icon: String, _ count: String) {
        self.icon = icon
        self.count = count
    }
}

public struct SearchField: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private enum Content {
        case placeholder
        case value(code: String?, title: String, subtitle: String?)
        case dateRange(SearchDate, SearchDate?)
        case passengers(badge: String, items: [PassengerCount])
        case custom(AnyView)
    }

    private let placeholder: String
    private let action: () -> Void
    private var content: Content = .placeholder
    private var systemImage: String?
    private var accessorySlot: AnyView?
    private var trailing: SearchFieldTrailing = .none
    private var onClear: (() -> Void)?
    // Per-element overrides — all TOKEN KEYS (never raw colours / numbers).
    private var backgroundKey: Theme.BackgroundColorKey?
    private var borderKey: Theme.BorderColorKey?
    private var radiusRole: Theme.RadiusRole?
    private var chipBackgroundKey: Theme.BackgroundColorKey?
    private var chipForegroundKey: Theme.TextColorKey?
    private var titleStyle: TextStyle = .bodyBase500
    private var titleColorKey: Theme.TextColorKey?
    private var subtitleStyle: TextStyle = .bodyBase400
    private var subtitleColorKey: Theme.TextColorKey?
    private var placeholderColorKey: Theme.TextColorKey?
    private var iconColorKey: Theme.ForegroundColorKey?
    private var isFocused = false
    private var showsShadow = false

    /// Fixed card height from the design (64pt) — a layout constant, not a theme knob.
    private let cardHeight: CGFloat = 64

    public init(_ placeholder: String, action: @escaping () -> Void = {}) {   // R1
        self.placeholder = placeholder
        self.action = action
    }

    // MARK: Resolved tokens (defaults match the design; each override is a token key)

    private var cornerRadius: CGFloat { (radiusRole ?? .field).value }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    private var resolvedBackground: Color { theme.background(backgroundKey ?? .bgWhite) }
    private var resolvedBorder: Color {
        isFocused ? theme.foreground(.fgHero) : (borderKey.map { theme.border($0) } ?? theme.background(.bgElevatorTertiary))
    }
    private var resolvedTitleColor: Color { theme.text(titleColorKey ?? .textPrimary) }
    private var resolvedSubtitleColor: Color { theme.text(subtitleColorKey ?? .textSecondary) }
    private var resolvedPlaceholderColor: Color { theme.text(placeholderColorKey ?? .textSecondary) }
    private var resolvedIconColor: Color { iconColorKey.map { theme.foreground($0) } ?? theme.foreground(.fgHero) }
    private var dividerColor: Color { borderKey.map { theme.border($0) } ?? theme.background(.bgElevatorTertiary) }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                contentView
                Spacer(minLength: 0)
                if let accessorySlot { accessorySlot }
                trailingView
            }
            .padding(.horizontal, density.scale(Theme.SpacingKey.md.value))
            .frame(minHeight: cardHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(resolvedBackground, in: shape)
            .overlay(shape.stroke(resolvedBorder, lineWidth: isFocused ? 1.5 : 1))
            .modifier(OptionalSoftShadow(on: showsShadow))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Content

    @ViewBuilder private var contentView: some View {
        switch content {
        case .placeholder:
            HStack(spacing: 6) {
                leadingIcon
                Text(placeholder).textStyle(.bodyBase400).foregroundStyle(resolvedPlaceholderColor)
            }
        case .value(let code, let title, let subtitle):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                    if let code { pill(code) } else { leadingIcon }
                    Text(title).textStyle(titleStyle).foregroundStyle(resolvedTitleColor).lineLimit(1)
                }
                if let subtitle {
                    Text(subtitle).textStyle(subtitleStyle).foregroundStyle(resolvedSubtitleColor).lineLimit(1)
                }
            }
        case .dateRange(let start, let end):
            HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                dateColumn(start)
                if let end {
                    Rectangle().fill(dividerColor).frame(width: 1).frame(maxHeight: .infinity)
                    dateColumn(end)
                }
            }
        case .passengers(let badge, let items):
            VStack(alignment: .leading, spacing: 4) {
                pill(badge)
                HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                    ForEach(items) { item in
                        HStack(spacing: 2) {
                            Image(systemName: item.icon).font(.system(size: 13)).foregroundStyle(theme.text(.textTertiary))
                            Text(item.count).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
                        }
                    }
                }
            }
        case .custom(let view):
            view
        }
    }

    private func dateColumn(_ date: SearchDate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let badge = date.badge { pill(badge) }
            Text(date.label)
                .textStyle(date.badge != nil ? titleStyle : .bodyBase400)
                .foregroundStyle(date.badge != nil ? resolvedTitleColor : resolvedPlaceholderColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(_ text: String) -> some View {
        SearchBadge(text).colors(background: chipBackgroundKey, foreground: chipForegroundKey)
    }

    @ViewBuilder private var leadingIcon: some View {
        if let systemImage {
            Image(systemName: systemImage).font(.system(size: 16)).foregroundStyle(resolvedIconColor).frame(width: 22)
        }
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
        case .clear:
            Button { onClear?() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(theme.foreground(.fgHero))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear")
        }
    }

    private var accessibilityText: String {
        switch content {
        case .placeholder: return placeholder
        case .value(_, let title, let subtitle): return "\(title)\(subtitle.map { ", " + $0 } ?? "")"
        case .dateRange(let s, let e): return "\(s.label)\(e.map { " to " + $0.label } ?? "")"
        case .passengers(let badge, _): return badge
        case .custom: return placeholder
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary) — every override is a token

public extension SearchField {
    // Content
    /// A location value — an optional leading code pill + title + subtitle.
    func value(code: String? = nil, title: String, subtitle: String? = nil) -> Self {
        copy { $0.content = .value(code: code, title: title, subtitle: subtitle) }
    }
    /// A date range — two badge + day columns split by a divider (pass `end: nil` for a single date).
    func dateRange(_ start: SearchDate, _ end: SearchDate? = nil) -> Self { copy { $0.content = .dateRange(start, end) } }
    /// A passenger summary — a badge + a row of icon + count tallies.
    func passengers(badge: String, _ items: [PassengerCount]) -> Self { copy { $0.content = .passengers(badge: badge, items: items) } }
    /// Fully custom content — replaces the built-in layouts entirely.
    func content<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.content = .custom(AnyView(content())) } }

    // Leading / trailing
    /// A leading SF Symbol (shown when there's no code pill).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// Colour of the leading icon (foreground token key).
    func iconColor(_ key: Theme.ForegroundColorKey) -> Self { copy { $0.iconColorKey = key } }
    /// Trailing accessory: none (default) / chevron / clear.
    func trailing(_ t: SearchFieldTrailing) -> Self { copy { $0.trailing = t } }
    /// Adds a clear (✕) button with its handler.
    func onClear(_ action: @escaping () -> Void) -> Self { copy { $0.trailing = .clear; $0.onClear = action } }
    /// A fully custom trailing accessory (a moon+nights, quick-date chips…).
    func accessory<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.accessorySlot = AnyView(content()) } }

    // Card chrome — token keys / roles, never raw values
    /// Card background (background token key, default `.bgWhite`).
    func background(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.backgroundKey = key } }
    /// Border colour (border token key, default soft blue). Overridden by ``focused(_:)``.
    func borderColor(_ key: Theme.BorderColorKey) -> Self { copy { $0.borderKey = key } }
    /// Corner radius (radius role, default `.field`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Focused/active state (hero border).
    func focused(_ on: Bool = true) -> Self { copy { $0.isFocused = on } }
    /// Adds a soft elevation shadow.
    func showsShadow(_ on: Bool = true) -> Self { copy { $0.showsShadow = on } }

    // Per-element text/pill styling — token keys / styles
    /// Recolour the code/date/count pills (background + text token keys).
    func chipColors(background: Theme.BackgroundColorKey? = nil, foreground: Theme.TextColorKey? = nil) -> Self {
        copy { if let background { $0.chipBackgroundKey = background }; if let foreground { $0.chipForegroundKey = foreground } }
    }
    /// Title text style + colour token.
    func titleStyle(_ style: TextStyle? = nil, color: Theme.TextColorKey? = nil) -> Self {
        copy { if let style { $0.titleStyle = style }; if let color { $0.titleColorKey = color } }
    }
    /// Subtitle text style + colour token.
    func subtitleStyle(_ style: TextStyle? = nil, color: Theme.TextColorKey? = nil) -> Self {
        copy { if let style { $0.subtitleStyle = style }; if let color { $0.subtitleColorKey = color } }
    }
    /// Placeholder text colour token.
    func placeholderColor(_ key: Theme.TextColorKey) -> Self { copy { $0.placeholderColorKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

private struct OptionalSoftShadow: ViewModifier {
    let on: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.themeShadow(.soft) } else { content }
    }
}

#Preview {
    VStack(spacing: 12) {
        SearchField("From") { }.value(code: "SAW", title: "Istanbul", subtitle: "Sabiha Gökçen Havalimanı")
        SearchField("Dates") { }
            .dateRange(SearchDate(badge: "23 Jul '24", label: "Monday"), SearchDate(badge: "27 Jul '24", label: "Friday"))
        SearchField("Passengers") { }
            .passengers(badge: "4 Guests", [PassengerCount("person.fill", "2"), PassengerCount("figure.child", "1")])
        SearchField("From") { }.value(code: "IST", title: "Istanbul", subtitle: "All airports")
            .chipColors(background: .bgHero, foreground: .textSecondaryInverse).borderColor(.borderHero).titleStyle(color: .textHero)
    }
    .padding()
    .background(Theme.shared.background(.bgSecondary))
}
