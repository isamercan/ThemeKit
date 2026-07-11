//
//  PageHeaderStyle.swift
//  ThemeKit
//
//  The style system behind ``PageHeader`` — the design-system "Page Header"
//  organism. One component owns the *data* (title, a bound ``SearchSummary``,
//  back/leading, trailing actions, a primary pill, an optional tabs/progress/
//  stepper accessory, a brand logo); a swappable ``PageHeaderStyle`` owns the
//  *chrome*:
//
//      .plain     white bar + soft-blue hairline, dark content, 44pt row
//      .brand     accent fill (or no-bg) with a centered brand logo
//      .onImage   transparent overlay — 40pt circular buttons, white content,
//                 and (when a search summary is set) a floating map card
//
//  Every color, radius, spacing and type resolves from the active `Theme`, so a
//  preset/dark/brand change re-skins the whole header. Covers the common
//  "Page Header" variants (Header · Icon Buttons · Tab · Progress ·
//  Stepper · with Button · With Search Bar · On Image · On Map · brand/-no-bg ·
//  with search Input).
//

import SwiftUI

// MARK: - Shared geometry

/// One source of truth for the header's fixed metrics.
enum PHMetrics {
    /// Height of the main title/slot row (Figma `header-height`).
    static let rowHeight: CGFloat = 44
    /// Square footprint of an inline icon button.
    static let slot: CGFloat = 32
    /// Diameter of a circular overlay button (On Image / On Map).
    static let circle: CGFloat = 40
    /// Progress / stepper track height.
    static let track: CGFloat = 6
    /// Active tab underline height.
    static let tabBar: CGFloat = 4
}

// MARK: - Configuration

/// The typed inputs every ``PageHeaderStyle`` lays out. Data only — each chrome
/// decides its own colors.
public struct PageHeaderConfiguration {
    public let title: String
    public let subtitle: String?
    public let showTitle: Bool
    public let tags: [PageHeader.Tag]
    public let summary: SearchSummary?
    public let searchField: PageHeader.SearchField?
    public let logo: AnyView?
    public let onBack: (() -> Void)?
    public let leadingIcon: PageHeader.LeadingIcon?
    public let actions: [PageHeader.Action]
    public let primaryButton: PageHeader.PrimaryButton?
    public let filterButton: PageHeader.FilterButton?
    public let accessory: PageHeader.Accessory
    public let locale: Locale

    enum Center { case logo, searchField, summary, title }
    var center: Center {
        if logo != nil { return .logo }
        if searchField != nil { return .searchField }
        if summary != nil { return .summary }
        return .title
    }

    var hasLeading: Bool { leadingIcon != nil || onBack != nil }
    var hasTrailing: Bool { !actions.isEmpty || primaryButton != nil }
}

// MARK: - Style protocol

/// Defines a header's chrome. Set one with `.pageHeaderStyle(_:)`; default is
/// ``PlainPageHeaderStyle``.
public protocol PageHeaderStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PageHeaderConfiguration) -> Body
}

// MARK: - Shared building blocks

/// An inline (square, 32pt) or circular (40pt white, shadowed) icon button.
struct PHIconButton: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    let action: () -> Void
    var foreground: Color
    var circular = false
    var label: String?

    var body: some View {
        Button(action: action) {
            Icon(systemName: systemImage)
                .size(.lg)
                .colorOverride(circular ? theme.text(.textPrimary) : foreground)
                .frame(width: circular ? PHMetrics.circle : PHMetrics.slot,
                       height: circular ? PHMetrics.circle : PHMetrics.slot)
                .background {
                    if circular { Circle().fill(theme.background(.bgWhite)).themeShadow(.soft) }
                }
                .contentShape(circular ? AnyShape(Circle()) : AnyShape(Rectangle()))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "")
    }
}

/// A filled square action button (the On Map filter / edit).
struct PHFilterButton: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    let action: () -> Void
    var label: String?

    var body: some View {
        Button(action: action) {
            Icon(systemName: systemImage).size(.sm).colorOverride(SemanticColor.primary.onSolid)
                .frame(width: PHMetrics.slot, height: PHMetrics.slot)
                .background(SemanticColor.primary.solid,
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "")
    }
}

/// The soft-blue primary pill (the "notify me" call-to-action).
struct PHPrimaryButton: View {
    @Environment(\.theme) private var theme
    let button: PageHeader.PrimaryButton

    var body: some View {
        Button(action: button.action) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let systemImage = button.systemImage {
                    Icon(systemName: systemImage).size(.sm).colorOverride(theme.text(.textHero))
                }
                Text(button.title).textStyle(.labelSm600).foregroundStyle(theme.text(.textHero))
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .frame(height: PHMetrics.slot)
            .background(theme.background(.bgElevatorTertiary),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The center search input pill — leading magnifier + a bound text field.
struct PHSearchField: View {
    @Environment(\.theme) private var theme
    let field: PageHeader.SearchField

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: "magnifyingglass").size(.sm).colorOverride(theme.text(.textTertiary))
            TextField(field.placeholder, text: field.text)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .submitLabel(.search)
                .onSubmit { field.onSubmit?() }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .frame(height: PHMetrics.slot, alignment: .center)
        .frame(maxWidth: .infinity)
        .background(theme.background(.bgElevatorPrimary),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                .strokeBorder(theme.background(.bgElevatorTertiary), lineWidth: 1)
        )
    }
}

/// The shared center block: title / bound search summary / search input.
struct PHCenter: View {
    @Environment(\.theme) private var theme
    let configuration: PageHeaderConfiguration
    var foreground: Color

    var body: some View {
        switch configuration.center {
        case .searchField:
            if let field = configuration.searchField { PHSearchField(field: field) }
        case .summary:
            if let summary = configuration.summary { summary.frame(maxWidth: .infinity) }
        case .title:
            if configuration.showTitle { titleText }
        case .logo:
            EmptyView()
        }
    }

    private var titleText: some View {
        VStack(alignment: configuration.hasLeading ? .center : .leading, spacing: 2) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Text(configuration.title).textStyle(.heading2xs).foregroundStyle(foreground)
                ForEach(configuration.tags) { tag in ThemeKit.Tag(tag.text).tagStyle(tag.style) }
            }
            if let subtitle = configuration.subtitle {
                Text(subtitle).textStyle(.bodySm400).foregroundStyle(foreground.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: configuration.hasLeading ? .center : .leading)
    }
}

/// The accessory band under the bar — tabs, a progress line, or a stepper.
struct PHAccessory: View {
    @Environment(\.theme) private var theme
    let accessory: PageHeader.Accessory

    var body: some View {
        switch accessory {
        case .none:
            EmptyView()
        case let .tabs(titles, selected, onSelect):
            PHTabsBar(titles: titles, selected: selected, onSelect: onSelect)
        case let .progress(fraction):
            progress(fraction)
        case let .stepper(current, total):
            stepper(current: current, total: total)
        }
    }

    /// A 6pt track with a hero fill of `fraction`, rounded at the leading cap.
    private func progress(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                theme.background(.bgSecondaryLight)
                Capsule().fill(theme.foreground(.fgHero))
                    .frame(width: max(0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: PHMetrics.track)
    }

    /// `total` rounded segments, `current` filled with the deep-hero token.
    private func stepper(current: Int, total: Int) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < current ? SemanticColor.primary.active : theme.background(.bgSecondaryLight))
                    .frame(height: PHMetrics.track)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
    }
}

/// The tab row: each tab is `Medium` dark when selected with a 4pt hero underline,
/// `Regular` secondary otherwise, over a shared soft-blue hairline.
struct PHTabsBar: View {
    @Environment(\.theme) private var theme
    let titles: [String]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    tab(title, index: index)
                }
            }
        }
        .overlay(alignment: .bottom) {
            theme.background(.bgElevatorTertiary).frame(height: 1)
        }
    }

    private func tab(_ title: String, index: Int) -> some View {
        let isOn = index == selected
        return Button { onSelect(index) } label: {
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title)
                    .textStyle(isOn ? .bodyBase500 : .bodyBase400)
                    .foregroundStyle(isOn ? theme.text(.textPrimary) : theme.text(.textSecondary))
                    .fixedSize()
                UnevenRoundedRectangle(topLeadingRadius: Theme.RadiusRole.field.value,
                                       topTrailingRadius: Theme.RadiusRole.field.value)
                    .fill(isOn ? theme.foreground(.fgHero) : Color.clear)
                    .frame(height: PHMetrics.tabBar)
            }
            .padding(.leading, index == 0 ? Theme.SpacingKey.md.value : Theme.SpacingKey.sm.value)
            .padding(.trailing, Theme.SpacingKey.sm.value)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chrome: the bar row (plain + brand)

/// Lays leading · center · trailing into the 44pt row. Shared by plain + brand.
struct PHBarRow: View {
    let configuration: PageHeaderConfiguration
    var foreground: Color

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            leading
            center
            trailing
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .frame(height: PHMetrics.rowHeight)
    }

    @ViewBuilder private var leading: some View {
        if let leadingIcon = configuration.leadingIcon {
            PHIconButton(systemImage: leadingIcon.systemImage, action: leadingIcon.handler,
                         foreground: foreground, label: "Menu")
        } else if let onBack = configuration.onBack {
            PHIconButton(systemImage: "arrow.left", action: onBack, foreground: foreground, label: "Back")
        }
    }

    @ViewBuilder private var center: some View {
        if configuration.center == .logo, let logo = configuration.logo {
            logo.frame(maxWidth: .infinity)
        } else {
            PHCenter(configuration: configuration, foreground: foreground)
        }
    }

    @ViewBuilder private var trailing: some View {
        if configuration.hasTrailing {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let primary = configuration.primaryButton { PHPrimaryButton(button: primary) }
                ForEach(configuration.actions) { action in
                    PHIconButton(systemImage: action.systemImage, action: action.handler,
                                 foreground: foreground, label: action.accessibilityLabel)
                }
            }
        }
    }
}

// MARK: - Plain chrome

/// White bar + soft-blue bottom hairline + dark content. Covers Header · Icon
/// Buttons · Tab · Progress · Stepper · with Button · with search Input.
public struct PlainPageHeaderStyle: PageHeaderStyle {
    public init() {}
    public func makeBody(configuration: PageHeaderConfiguration) -> some View {
        PlainChrome(configuration: configuration)
    }
}

private struct PlainChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PageHeaderConfiguration

    var body: some View {
        VStack(spacing: 0) {
            PHBarRow(configuration: configuration, foreground: theme.text(.textPrimary))
            accessoryBand
        }
        .background(theme.background(.bgWhite))
        .overlay(alignment: .bottom) {
            theme.background(.bgElevatorTertiary).frame(height: 1)
        }
    }

    @ViewBuilder private var accessoryBand: some View {
        switch configuration.accessory {
        case .none:
            EmptyView()
        case .tabs:
            PHAccessory(accessory: configuration.accessory)
        case .progress, .stepper:
            PHAccessory(accessory: configuration.accessory)
                .padding(.bottom, Theme.SpacingKey.sm.value)
        }
    }
}

// MARK: - Brand chrome

/// A centered brand logo on an accent fill (or no background). Covers Brand ·
/// brand-no bg.
public struct BrandPageHeaderStyle: PageHeaderStyle {
    let color: SemanticColor
    let filled: Bool
    public init(color: SemanticColor = .primary, filled: Bool = true) {
        self.color = color
        self.filled = filled
    }
    public func makeBody(configuration: PageHeaderConfiguration) -> some View {
        BrandChrome(configuration: configuration, color: color, filled: filled)
    }
}

private struct BrandChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PageHeaderConfiguration
    let color: SemanticColor
    let filled: Bool

    private var foreground: Color { filled ? color.onSolid : theme.text(.textPrimary) }

    var body: some View {
        PHBarRow(configuration: configuration, foreground: foreground)
            .background(filled ? color.solid : theme.background(.bgWhite))
    }
}

// MARK: - On-image / On-map chrome

/// A transparent overlay for hero images and maps: 40pt circular white buttons
/// (dark glyph), white title — or, when a search summary is set, a floating white
/// map card holding the summary and a filled filter button. Covers On Image ·
/// With Search Bar_On Image · On Map.
public struct OnImagePageHeaderStyle: PageHeaderStyle {
    public init() {}
    public func makeBody(configuration: PageHeaderConfiguration) -> some View {
        OnImageChrome(configuration: configuration)
    }
}

private struct OnImageChrome: View {
    @Environment(\.theme) private var theme
    let configuration: PageHeaderConfiguration

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            leading
            if let summary = configuration.summary {
                if let filter = configuration.filterButton {
                    mapCard(summary, filter: filter)          // On Map
                } else {
                    summary.boxed().frame(maxWidth: .infinity) // With Search Bar · On Image
                    trailingButtons
                }
            } else {
                title                                          // On Image
                trailingButtons
            }
        }
        .padding(Theme.SpacingKey.md.value)
    }

    @ViewBuilder private var leading: some View {
        if let leadingIcon = configuration.leadingIcon {
            PHIconButton(systemImage: leadingIcon.systemImage, action: leadingIcon.handler,
                         foreground: MediaScrim.onContent, circular: true, label: "Menu")
        } else if let onBack = configuration.onBack {
            PHIconButton(systemImage: "arrow.left", action: onBack, foreground: MediaScrim.onContent, circular: true, label: "Back")
        }
    }

    private var title: some View {
        Group {
            if configuration.showTitle {
                Text(configuration.title).textStyle(.heading2xs).foregroundStyle(MediaScrim.onContent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var trailingButtons: some View {
        if configuration.hasTrailing {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(configuration.actions) { action in
                    PHIconButton(systemImage: action.systemImage, action: action.handler,
                                 foreground: MediaScrim.onContent, circular: true, label: action.accessibilityLabel)
                }
            }
        }
    }

    /// On Map: a white card holding the summary + a filled filter button, floated.
    private func mapCard(_ summary: SearchSummary, filter: PageHeader.FilterButton) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            summary.frame(maxWidth: .infinity)
            PHFilterButton(systemImage: filter.systemImage, action: filter.action,
                           label: filter.accessibilityLabel)
        }
        .padding(.leading, Theme.SpacingKey.sm.value)
        .padding(.trailing, Theme.SpacingKey.xs.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .frame(maxWidth: .infinity)
        .background(theme.background(.bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        .themeShadow(.soft)
    }
}

// MARK: - Static accessors

public extension PageHeaderStyle where Self == PlainPageHeaderStyle {
    /// White bar + soft hairline, dark content (the default).
    static var plain: PlainPageHeaderStyle { PlainPageHeaderStyle() }
}

public extension PageHeaderStyle where Self == BrandPageHeaderStyle {
    /// A centered brand logo on an accent fill.
    static var brand: BrandPageHeaderStyle { BrandPageHeaderStyle() }
    /// A brand logo with no background fill.
    static var brandNoBackground: BrandPageHeaderStyle { BrandPageHeaderStyle(filled: false) }
    /// A brand logo on a custom accent fill.
    static func brand(_ color: SemanticColor, filled: Bool = true) -> BrandPageHeaderStyle {
        BrandPageHeaderStyle(color: color, filled: filled)
    }
}

public extension PageHeaderStyle where Self == OnImagePageHeaderStyle {
    /// Transparent overlay with circular buttons + white content, for hero
    /// images and maps.
    static var onImage: OnImagePageHeaderStyle { OnImagePageHeaderStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPageHeaderStyle: PageHeaderStyle {
    private let _makeBody: @MainActor (PageHeaderConfiguration) -> AnyView
    init<S: PageHeaderStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PageHeaderConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PageHeaderStyleKey: EnvironmentKey {
    static let defaultValue = AnyPageHeaderStyle(PlainPageHeaderStyle())
}

extension EnvironmentValues {
    var pageHeaderStyle: AnyPageHeaderStyle {
        get { self[PageHeaderStyleKey.self] }
        set { self[PageHeaderStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PageHeaderStyle`` for headers in this view and its descendants.
    func pageHeaderStyle<S: PageHeaderStyle>(_ style: sending S) -> some View {
        environment(\.pageHeaderStyle, AnyPageHeaderStyle(style))
    }
}
